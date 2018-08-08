function [stacks, resultspath] = pipeline_register(varargin)
    % PIPELINE_REGISTER register stacks and save results in a .mat file
    %
    % [stacks, resultspath] = pipeline_register(resultspath, stackspath, varargin)
    %
    % This function performs all steps to register stacks (template definition,
    % registration as 1 or 2 passes, averaging and projections). Furthermore, it
    % saves all intermediate results so that one can interrupt and restart
    % computation if necessary.
    %
    % INPUTS
    %   resultspath - results file path, open a dialog if empty
    %   stackspath - (optional) default: re-use saved paths or open a dialog
    %       stacks paths, as either
    %       1) a file path for a TIFF file
    %       2) a folder path containing images (TIFF files)
    %       3) a file path for binary stack (from IRIS)
    %       4) a cellarray of the previous types
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   extract_si_metadata - default: false
    %       load and extract ScanImage metadata from TIFF headers (very slow)
    %   n_batches - default: 15 (see stackstemplate documentation)
    %       number of batches to sample in a stack
    %   batch_size - defualt: 20 (see stackstemplate documentation)
    %       number of frames in each batch
    %   filterfcn - default: @(x) x (see stackstemplate documentation)
    %       function used to filter each batch before averaging
    %   margins - default: 0
    %       number of pixels to remove from borders before registering images,
    %       as either
    %       1) a scalar (same margins for X and Y)
    %       2) a vector of two scalars (separate margins for X and Y)
    %   maxshift - default: []
    %       maximum shift allowed, restraining the search space
    %   refchannel - default: []
    %       index of channel(s) to use instead of all of them
    %   win_size - default: []
    %       window size used to median filter (x,y)-shifts to extract a trend
    %   chunksize - default: 10
    %       number of frames to load at once, which accelerates computation but
    %       consumes more memory
    %   useparfor - default: false
    %       turn on use of 'parfor' loop to distribute computations over a pool
    %       of workers (might not accelerate computations)
    %   verbose - default: true
    %       boolean flag to display extra informations  
    %
    % OUTPUTS
    %   stacks - image sequences as a cellarray of [X Y Z Channels Time]
    %       array-like objects, each of them being either
    %       1) a TIFFStack object
    %       2) a TensorStack object made of TIFFStack objects
    %       3) a MappedTensor object
    %   resultspath - results file path, as a string
    %
    % REMARKS
    %   Results are saved in a .mat file (v7.3) as follows:
    %   - stackspath: path of stacks, as a cellarray of paths
    %   - opts: optional inputs of the function, as a structure
    %   - avg_refs: reference images (templates), as a cellarray of 4D arrays
    %   - avg_regs: registered averages, as a cellarray of 4D arrays
    %   - max_projs: maximum intensity projections, as a cellarray of 4D arrays
    %   - min_projs: minimum intensity projections, as a cellarray of 4D arrays
    %   - xyshifts: (x,y)-shifts for each frame, as a cellarray of 3D arrays
    %
    % EXAMPLES
    %   % run registration, using dialogs to select stacks and default options
    %   resultspath = 'processed.mat';
    %   stacks = pipeline_register(resultspath);
    %   % use GUIs for quality control
    %   result = load(resultspath);
    %   xysshow(result.xyshifts);
    %   stacksgui(stacks, result.xyshifts, ...
    %       'avg_refs', result.avg_refs, 'avg_regs', result.avg_regs, ...
    %       'min_projs', result.min_projs, 'max_projs', result.max_projs);
    %
    %   % run registration, using a dialog for results file and setting options
    %   [stacks, resultspath] = ...
    %       pipeline_register([], 'margins', [50, 10], 'useparfor', true);
    %
    % SEE ALSO stacksload, basic_example, pipeline_segment

    % parse optional inputs
    parser = inputParser;
    parser.addRequired('resultspath', @(x) isempty(x) || ischar(x));
    parser.addOptional('stackspath', [], @(x) isempty(x) || validatepaths(x));
    parser.addParameter('extract_si_metadata', false);
    parser.addParameter('n_batches', 15);
    parser.addParameter('batch_size', 20);
    parser.addParameter('filterfcn', @(x) x);
    parser.addParameter('margins', 0);
    parser.addParameter('maxshift', []);
    parser.addParameter('refchannel', []);
    parser.addParameter('win_size', []);
    parser.addParameter('verbose', true);
    parser.addParameter('chunksize', 10);
    parser.addParameter('useparfor', false);

    parser.parse(varargin{:});
    resultspath = parser.Results.resultspath;
    stackspath = parser.Results.stackspath;
    opts = rmfield(parser.Results, {'resultspath', 'stackspath'});

    % ask for results file path if none is given
    if isempty(resultspath)
        [resultsfile, resultsdir] = uiputfile();
        resultspath = fullfile(resultsdir, resultsfile);
        if isequal(resultsfile, 0) || isequal(resultsdir, 0)
            error('No results file selected.');
        end
    end

    % try to load results if file already exists, or create new results file
    if exist(resultspath, 'file')
%         load(resultspath);
        % warn user about usage of saved options
        warning('Not ignoring current options, not re-using saved options.');
        disp(opts);
    else
        save(resultspath, 'opts', '-v7.3');
    end

    common_opts.verbose = opts.verbose;
    common_opts.chunksize = opts.chunksize;
    common_opts.useparfor = opts.useparfor;
    register_opts.margins = opts.margins;
    register_opts.refchannel = opts.refchannel;

    % ask for stacks paths if none is given
    if isempty(stackspath)
        stackspath = uipickfiles('REFilter', '\.tiff?$|\.bin$', ...
            'Prompt', 'Select stacks files and/or folders');
    end
    if ~iscell(stackspath)
        stackspath = {stackspath};
    end
    save(resultspath, 'stackspath', '-append');

    % load data, optionally with metadata
    fprintf('%s - ', datestr(now()));
    if ~exist('si_metadata', 'var') && opts.extract_si_metadata
        fprintf('loading stacks and metadata...\n');
        [stacks, metadata] = stacksload(stackspath, 'forcecell', true);

        % parse ScanImage headers and save them
        si_metadata = cellfun(@parse_si_header, metadata, 'un', false);
        save(resultspath, si_metadata, '-append');

    else
        fprintf('loading stacks...\n');
        stacks = stacksload(stackspath, 'forcecell', true);
    end

    % templates for registration
    fprintf('%s - ', datestr(now()));
    if ~exist('avg_refs', 'var')
        fprintf('computing templates...\n');
        avg_refs = stackstemplate(stacks, opts.n_batches, opts.batch_size, ...
            'filterfcn', opts.filterfcn, register_opts);
        save(resultspath, 'avg_refs', '-append');
    else
        fprintf('computing templates... [skipped]\n');
    end

    % if 'win_size' is not specified, simple registration
    if isempty(opts.win_size) || isempty(opts.maxshift)
        fprintf('%s - ', datestr(now()));
        if ~exist('xyshifts', 'var')
            fprintf('registering stacks...\n');
            xyshifts = stacksregister_dft(stacks, avg_refs, ...
                'maxshift', opts.maxshift, register_opts, common_opts);
            save(resultspath, 'xyshifts', '-append');
        else
            fprintf('registering stacks... [skipped]\n');
        end

    % otherwise, 2 passes registration
    else
        fprintf('%s - ', datestr(now()));
        if ~exist('xyshifts_raw', 'var')
            fprintf('registering stacks (1st pass)...\n');
            xyshifts_raw = stacksregister_dft(stacks, avg_refs, ...
                register_opts, common_opts);
            save(resultspath, 'xyshifts_raw', '-append');
        else
            fprintf('registering stacks (1st pass)... [skipped]\n');
        end

        if ~exist('xyshifts_trend', 'var')
            xyshifts_trend = cellfun(@(x) medfilt1(x, opts.win_size, [], 3), ...
                xyshifts_raw, 'un', false);
        end

        fprintf('%s - ', datestr(now()));
        if ~exist('xyshifts', 'var')
            fprintf('registering stacks (2nd pass)...\n');
            xyshifts = stacksregister_dft(stacks, avg_refs, xyshifts_trend, ...
                'maxshift', opts.maxshift, register_opts, common_opts);
            save(resultspath, 'xyshifts_trend', 'xyshifts', '-append');
        else
            fprintf('registering stacks (2nd pass)... [skipped]\n');
        end
    end

    % registered average image
    fprintf('%s - ', datestr(now()));
    if ~exist('avg_regs', 'var')
        fprintf('averaging stacks...\n');
        avg_regs = stacksmean(stacks, xyshifts, common_opts);  %#ok<NASGU>
        save(resultspath, 'avg_regs', '-append');
    else
        fprintf('averaging stacks... [skipped]\n');
    end

    % min- and max-projections
    fprintf('%s - ', datestr(now()));
    if ~exist('min_projs', 'var') || ~exist('max_projs', 'var')
        fprintf('projecting stacks (min/max)...\n');
        [min_projs, max_projs] = stacksminmax(stacks, xyshifts, common_opts);  %#ok<ASGLU>
        save(resultspath, 'min_projs', 'max_projs', '-append');
    else
        fprintf('projecting stacks (min/max)... [skipped]\n');
    end

    fprintf('%s - pipeline_register finished\n', datestr(now()));
end

function x = validatepaths(paths)
    % helper function to validate file/folder paths
    if ischar(paths)
        x = exist(paths, 'file');
    elseif iscell(paths)
        x = all(cellfun(@(y) exist(y, 'file'), paths));
    else
        x = false;
    end
end