function [stacks, resultspath] = pipeline_segment(varargin)
    % PIPELINE_SEGMENT align stacks, make ROIs and save results in a .mat file
    %
    % [stacks, resultspath] = pipeline_segment(resultspath, registerpath, forcerois, varargin)
    %
    % This function performs all steps to register stacks together, create ROIs
    % and extract corresponding time series. Furthermore, it saves all
    % intermediate results so that one can interrupt and restart computation if
    % necessary.
    %
    % INPUTS
    %   resultspath - results file path, open a dialog if empty
    %   registerpath - (optional) default: re-use saved paths or open a dialog
    %       registration result paths, as either
    %       1) a file path for a .mat file
    %       2) a cellarray of the previous type
    %   forcerois - (optional) default: false
    %       force (re-)edition of ROIs and traces extraction
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   zcorrection - default: false
    %       enable manual z-plane correction (integer offsets)
    %   margins - default: 0
    %       number of pixels to remove from borders before registering images,
    %       as either
    %       1) a scalar (same margins for X and Y)
    %       2) a vector of two scalars (separate margins for X and Y)
    %   refchannel - default: []
    %       index of channel to use instead of all of them
    %   tformtype - default: 'similarity'
    %       geometric transform used ('rigid', 'similiarity' or 'affine')
    %   maxiter_affine - default: 1000
    %       maximum number of iterations for registration algorithm
    %   nframes - default: 20 (see stacksoffsets_gmm documentation)
    %       number of frames (per channel) to sample
    %   npixels - default: 2000 (see stacksoffsets_gmm documentation)
    %       number of pixels to sample in each sampled frame
    %   maxiter - default: 1000 (see stacksoffsets_gmm documentation)
    %       maximum number of iterations to fit the GMM
    %   ncomps - default: 2 (see stacksoffsets_gmm documentation)
    %       number of mixture components
    %   perc - default: 40
    %       percentile of each trace used as F0 baseline
    %   half_win - default: []
    %       half-width of a sliding window, in frames, for time-varying F0
    %       baseline estimation
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
    %
    % REMARKS
    %   Results are saved in a .mat file (v7.3) as follows:
    %   - registerpath: path of registration results, as a cellarray of paths
    %   - opts: optional inputs of the function, as a structure
    %   - zshifts (if 'zcorrection'): z-plane integer shifts, as a vector
    %   - ref_id: index of the reference stack, as a integer
    %   - tforms: geometric transforms, as a cellarray of affine2d objects
    %   - avg_regs_tf: transformed averages, as a cellarray of 4D arrays
    %   - max_projs_tf: transformed maximum intensity projections, as a
    %                   cellarray of 4D arrays
    %   - offsets: stacks intensity offsets, as a cellarray of vectors
    %   - rois_tf: ROIs in transformed space, as a 2D structure array
    %   - rois: ROIs in original stacks space, as a 2D structure array
    %   - ts: ROIs with traces (original stacks space), as a 2D structure array
    %   - dff: ROIs with dF/F0 (original stacks space), as a 2D structure array
    %   - f0: F0 baselines, as a cellarray of 2D arrays
    %   and copied from registration results
    %   - avg_regs: registered averages, as a cellarray of 4D arrays
    %   - max_projs: maximum intensity projections, as a cellarray of 4D arrays
    %   - min_projs: minimum intensity projections, as a cellarray of 4D arrays
    %   - xyshifts: (x,y)-shifts for each frame, as a cellarray of 3D arrays
    %
    % EXAMPLES
    %   % run pipeline, using dialogs to select .mat files and default options
    %   resultspath = 'processed_all.mat';
    %   stacks = pipeline_segment(registerpath);
    %   % use GUIs for quality control
    %   result = load(resultspath);
    %   offsetsshow(stacks, result.offsets);
    %   roisgui(result.avg_regs_tf, [], result.rois, ...
    %           'max_projs_tf', result.max_projs_tf);
    %
    %   % run pipeline, using a dialog for results file and setting options
    %   [stacks, resultspath] = ...
    %       pipeline_segment([], 'margins', [20, 10], 'useparfor', true);
    %
    % SEE ALSO stacksload, basic_example, pipeline_register
    
    % rois and rois_tf switched, Philip Shamash 16.07.18

    % parse optional inputs
    parser = inputParser;
    parser.addRequired('resultspath', @(x) isempty(x) || ischar(x));
    parser.addOptional('registerpath', [], @(x) isempty(x) || validatepaths(x));
    parser.addOptional('forcerois', false, @(x) islogical(x) && isscalar(x));
    parser.addParameter('verbose', true);
    parser.addParameter('margins', 0);
    parser.addParameter('tformtype', 'affine');
    parser.addParameter('refchannel', []);
    parser.addParameter('maxiter_affine', 1000);
    parser.addParameter('nframes', 20);
    parser.addParameter('npixels', 2000);
    parser.addParameter('maxiter_gmm', 1000);
    parser.addParameter('ncomps', 2);
    parser.addParameter('chunksize', 10);
    parser.addParameter('useparfor', false);
    parser.addParameter('perc', 40);
    parser.addParameter('half_win', []);
    parser.addParameter('zcorrection', false);
    parser.addParameter('time_series', true);

    parser.parse(varargin{:});
    resultspath = parser.Results.resultspath;
    registerpath = parser.Results.registerpath;
    forcerois = parser.Results.forcerois;
    opts = rmfield(parser.Results, ...
        {'resultspath', 'registerpath', 'forcerois'});

    % ask for results file path if none is given
    if isempty(resultspath)
        [resultsfile, resultsdir] = uiputfile();
        resultspath = fullfile(resultsdir, resultsfile);
        if isequal(resultsfile, 0) || isequal(resultsdir, 0)
            error('No results file selected.');
        end
    end

    % try to load result if file already exists, or create new result file
    if exist(resultspath, 'file')
%         load(resultspath);
        % warn user about usage of saved options
        answer = questdlg('File already exists -- proceed anyway?','Overwrite warning');
        assert(strcmp(answer,'Yes'))        
        warning('Not ignoring current options, nor re-using saved options.');
        disp(opts);
    end
	try
        save(resultspath, 'opts', '-append');
    catch
        save(resultspath, 'opts', '-v7.3');
    end
    

    % ask for registration results paths if none is given
    if isempty(registerpath)
        registerpath = uipickfiles('REFilter', '\.mat', ...
            'Prompt', 'Select registration results .mat files');
    end
    if ~iscell(registerpath)
        registerpath = {registerpath};
    end
    save(resultspath, 'registerpath', '-append');

    % load relevant parts of saved results
    fprintf('%s - ', datestr(now()));
    if ~exist('avg_regs', 'var')
        fprintf('load registration results...\n')
        reg_results = cellfun(@load, registerpath,'UniformOutput',false);
%         avg_regs = cat(2, reg_results.avg_regs);
        avg_regs = cellfun(@(x) x.avg_regs, reg_results);
%         max_projs = cat(2, reg_results.max_projs);
        max_projs = cellfun(@(x) x.max_projs, reg_results);
%         stackspath = cat(2, reg_results.stackspath);
        stackspath = cellfun(@(x) x.stackspath, reg_results);
%         xyshifts = cat(2, reg_results.xyshifts);
        xyshifts = cellfun(@(x) x.xyshifts, reg_results);
        save(resultspath, 'avg_regs', 'max_projs', 'stackspath', 'xyshifts', ...
             '-append');
    else
        fprintf('load registration results... [skipped]\n')
    end
    nstacks = numel(avg_regs);

    % adjust Z-planes (optional)
    fprintf('%s - ', datestr(now()));
    if opts.zcorrection && ~exist('zshifts', 'var')
        fprintf('selecting z-shifts...\n');
        fig1 = stacksgui(avg_regs, [], 'max proj.', max_projs);
        fig2 = stacksgui(avg_regs, [], 'max proj.', max_projs);
        zshifts = inputdlg( ...
            'Enter z-shifts', ...
            'z-shifts', 1, {''}, struct('WindowStyle','normal'));
        zshifts = str2num(zshifts{1});  %#ok<ST2NM>
        close(fig1);
        close(fig2);
        zshifts_attr = {'vector', 'integer', 'numel', nstacks};
        validateattributes(zshifts, {'numeric'}, zshifts_attr, '', 'zshifts');
        save(resultspath, 'zshifts', '-append');
    else
        fprintf('selecting z-shifts... [skipped]\n');
    end

    % apply z-shifts
    if opts.zcorrection
        % TODO fix that
        avg_regs = stackszshift(avg_regs, zshifts);
        avg_regs = cellfun(@(x) reshape(x(:), size(x)), avg_regs, 'un', false);
        max_projs = stackszshift(max_projs, zshifts);
        max_projs = cellfun(@(x) reshape(x(:), size(x)), max_projs, 'un', false);
    end

    % pick a reference stack
    fprintf('%s - ', datestr(now()));
    if ~exist('ref_id', 'var')
        fprintf('selecting reference stack...\n');
        if nstacks == 1
            ref_id = 1;
        else
            fig = stacksgui(avg_regs, [], 'max proj.', max_projs);
            ref_id = inputdlg( ...
                'Enter reference stack index', ...
                'reference stack', 1, {''}, struct('WindowStyle','normal'));
            ref_id = str2num(ref_id{1});  %#ok<ST2NM>
            close(fig);
        end

        ref_id_attr = {'scalar', 'integer', 'positive', '<=', nstacks};
        validateattributes(ref_id, {'numeric'}, ref_id_attr, '', ...
                           'reference stack index');

        save(resultspath, 'ref_id', '-append');
    else
        fprintf('selecting reference stack... [skipped]\n');
    end

    % register stacks together with geometric transform
    fprintf('%s - ', datestr(now()));
    if ~exist('tforms', 'var')
        fprintf('registering stacks together...\n');
        [tforms, avg_regs_tf] = stacksregister_affine( ...
            avg_regs, avg_regs{ref_id}, ...
            'tformtype', opts.tformtype, 'refchannel', opts.refchannel, ...
            'margins', opts.margins, 'maxiter', opts.maxiter_affine, ...
            'verbose', opts.verbose);
        max_projs_tf = cellfun(@stacktransform, max_projs, tforms, 'un', false);
        save(resultspath, 'tforms', 'avg_regs_tf', 'max_projs_tf', '-append');
    else
        fprintf('registering stacks together... [skipped]\n');
    end

    % open GUI to work on ROIs
    fprintf('%s - ', datestr(now()));
    if ~exist('rois', 'var') || forcerois
        fprintf('editing ROIs...\n');
        if ~exist('rois', 'var')
            rois = [];
        end
        rois = roisgui(avg_regs_tf, [], rois, 'avg regs','max proj.', max_projs_tf);
        if isempty(rois)
            error('Stopping, no ROI has been created.');
        else
            rois_tf = roistransform(rois, tforms);
        end
        save(resultspath, 'rois', 'rois_tf', '-append');
    else
        fprintf('editing ROIs... [skipped]\n');
    end

    if opts.time_series
        % load stacks, and apply z-shifts if necessary
        fprintf('%s - loading stacks...\n', datestr(now()));
        stacks = stacksload(stackspath, 'forcecell', true);
        if opts.zcorrection
            [stacks, xyshifts] = stackszshift(stacks, zshifts, xyshifts);
        end

        % extract ROIS traces
        fprintf('%s - ', datestr(now()));
        if ~exist('offsets', 'var')
            fprintf('estimating stacks offsets...\n');
            offsets = stacksoffsets_gmm(stacks, ...
                'nframes', opts.nframes, 'npixels', opts.npixels, ...
                'maxiter', opts.maxiter_gmm, 'ncomps', opts.ncomps);
            save(resultspath, 'offsets', '-append');
        else
            fprintf('estimating stacks offsets... [skipped]\n');
        end

        % extract ROIs time series
        fprintf('%s - ', datestr(now()));
        if ~exist('ts', 'var') || forcerois
            fprintf('extracting ROIs time series...\n');
%             rois_tf = roistransform(rois, tforms);
            ts = stacksextract(stacks, rois_tf, xyshifts, ...
                'offsets', offsets, 'chunksize', opts.chunksize, ...
                'verbose', opts.verbose, 'useparfor', opts.useparfor);
            save(resultspath, 'ts', '-append');
        else
            fprintf('extracting ROIs time series... [skipped]\n');
        end

        % compute deltaF/FO
        fprintf('%s - ', datestr(now()));
        if ~exist('dff', 'var') || forcerois
            fprintf('estimating dF/F0...\n');
            extractfcn = @(x) extractdff_prc(x, opts.perc, opts.half_win);
            [dff, f0] = roisfilter(ts, extractfcn);  %#ok<ASGLU>
            save(resultspath, 'dff', 'f0', '-append');
        else
            fprintf('estimating dF/F0... [skipped]\n');
        end
    else
        disp('skipping time series and df/f')
    end

    fprintf('%s - pipeline_segment finished\n', datestr(now()));
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