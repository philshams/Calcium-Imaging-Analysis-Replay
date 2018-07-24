function [rois, bg_rois] = stackscnmf(stacks, varargin)
    % STACKSCNMF extract ROIs using Pnevmatikakis et al. (2016) algorithm
    %
    % [rois, bg_rois] = stackscnmf(stacks, xyshifts, ...)
    %
    % This function uses Pnevmatikakis's code to factorize data into a product
    % of 2 matrices, representing the spatial footprints of ROIs and their
    % related temporal traces. The field of view is decomposed in overlapping
    % patches, each patch being processed in parallel.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   tmp_filename - default: []
    %       temporary file to load data into and share between workers (if
    %       empty, data are load into memory and copied accross workers)
    %   patch_size - default: 50
    %       side length of the patches
    %   ncomps - default: 10
    %       number of components used by CNMF for each patch
    %   p - default: []
    %       order of autoregressive process for deconvolution (see remarks)
    %   verbosity - default: 1
    %       level of verbosity
    %       - 0 to disable all messages
    %       - 1 to get progress messages
    %       - 2 to get detailed messages from CNMF
    %
    %   and any other parameter recognized by the CNMFSetParms function, i.e.
    %   'merge_thr', 'fudge_factor'...
    %
    % OUTPUTS
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': CNMF spatial filter, as a [X Y] array
    %       - 'activity': activity reconstructed by CNMF, as [Time] vector
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %   bg_rois - TODO
    %
    % REMARKS
    %   Final traces are not computed using deconvolution, only intermediate
    %   patch processing uses deconvolution. Hence this function doesn't return
    %   any estimation of spikes.
    %
    % SEE ALSO CNMFSetParms, run_CNMF_patches

    warning('This function is deprecated and will be removed in next release.')

    % TODO option to apply on one channel
    % TODO option to exclude borders? implement another function?
    % TODO what about tau parameter of run_CNMF_patches?
    % TODO return CNMF results in their own format
    % TODO ensure returned traces are correctly offset and background subtracted
    % TODO add back concatenation of multiple stacks

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    elseif ~iscell(stacks)
        stacks = {stacks};
    end

    % parse optional inputs
    parser = inputParser;
    parser.KeepUnmatched = true;
    parser.addOptional('xyshifts', []);
    parser.addParameter('tmp_filename', [], @ischar);
    parser.addParameter('patch_size', 50, @isnumeric);
    parser.addParameter('ncomps', 10, @isnumeric);
    parser.addParameter('p', [], @isnumeric);
    parser.addParameter('verbosity', 1, @isnumeric);

    parser.parse(varargin{:});
    xyshifts = parser.Results.xyshifts;
    tmp_filename = parser.Results.tmp_filename;
    patch_size = parser.Results.patch_size;
    ncomps = parser.Results.ncomps;
    p = parser.Results.p;
    verbosity = parser.Results.verbosity;
    cnmf_opts = parser.Unmatched;

    % check stacks and (x,y)-shifts
    [stacks, xyshifts] = stackscheck(stacks, xyshifts);
    nstacks = numel(stacks);

    % CNMF on each stack
    rois = cell(1, nstacks);
    bg_rois = cell(1, nstacks);
    for ii = 1:nstacks
        if verbosity >= 1
            fprintf('CNMF for stack %d/%d started (%s)\n', ...
                ii, nstacks, datestr(now()));
        end

        [rois{ii}, bg_rois{ii}] = stackcnmf( ...
            stacks{ii}, xyshifts{ii}, patch_size, ncomps, p, verbosity, ...
            tmp_filename, cnmf_opts);

        if verbosity >= 1
            fprintf('CNMF for stack %d/%d completed (%s)\n', ...
                ii, nstacks, datestr(now()));
        end
    end

    % remove temporary file
    delete(tmp_filename);
    if ~isempty(tmp_filename) && verbosity >= 1
        fprintf('%s has been removed.\n', tmp_filename);
    end

    % concatenate new ROIs
    rois = concat_rois(rois);
    bg_rois = concat_rois(bg_rois);
end

function [rois, bg_rois] = stackcnmf(stack, xyshifts, ...
        patch_size, ncomps, p, verbosity, tmp_filename, cnmf_opts)
    % apply CNMF to all slices of a stack

    % verbosity for CNMF and for progress report
    verbose_cnmf = verbosity >= 2;
    verbose_stack = verbosity >= 1;

    % create patches
    [nx, ny, nz, nc, ~] = size(stack);
    patches = construct_patches([nx, ny], [patch_size, patch_size]);

    % refine each z-plane and channel
    rois = cell(nz, nc);
    bg_rois = cell(nz, nc);
    for ii = 1:nz
        for jj = 1:nc
            % retrieve a slice of the stack and apply CNMF on it
            Y = retrieve_slice(stack, xyshifts, ii, jj, tmp_filename);
            if verbose_cnmf
                [A, b, C, f] = run_CNMF_patches( ...
                    Y, ncomps, patches, [], p, cnmf_opts);
            else
                % capture the output to avoid displaying it
                [~, A, b, C, f] = evalc( ...
                    'run_CNMF_patches(Y, ncomps, patches, [], p, cnmf_opts);');
            end

            % transform components into ROI structure
            rois{ii, jj} = cnmf_to_rois(A, C, nx, ny, ii, jj);
            bg_rois{ii, jj} = cnmf_to_rois(b, f, nx, ny, ii, jj);

            if verbose_stack
                fprintf('z-plane %d/%d done, channel %d/%d done\n', ...
                    ii, nz, jj, nc)
            end
        end
    end

    % concatenate new ROIs
    rois = cat(2, rois{:});
    bg_rois = cat(2, bg_rois{:});
end

function Y = retrieve_slice(stack, xyshifts, zplane, channel, filename)
    % retrieve a slice of a stack, register it and possibly store it in a file

    Y = stack(:, :, zplane, channel, :);
    if ~isempty(xyshifts)
        Y = stacktranslate(Y, xyshifts(:, zplane, :));
    end
    Y = squeeze(Y);

    if ~isempty(filename)
        sizY = size(Y);
        Yr = reshape(Y, [], sizY(end));
        F_dark = min(Yr(:));
        save(filename, 'Yr', 'Y', 'F_dark', 'sizY', '-v7.3');
        Y = matfile(filename, 'Writable', false);
    end
end

function rois = cnmf_to_rois(A, C, nx, ny, zplane, channel)
    % convert CNMF results into ROIs structure

    nrois = size(A, 2);
    for rid = nrois:-1:1
        rois(rid).footprint = reshape(A(:, rid), nx, ny);
        rois(rid).activity = C(rid, :);
    end

    % add z-plane and channel information
    [rois.zplane] = deal(zplane);
    [rois.channel] = deal(channel);
end

function rois = concat_rois(rois)
    % concatenate a cellarray of ROIs, removing empty ones

    % add a dummy ROI at the end to make sure that ROIs can be concatenated
    nrois = max(cellfun(@numel, rois));
    for ii = 1:numel(rois)
        rois{ii}(nrois + 1).footprint = [];
    end
    rois = cat(1, rois{:});

    % remove columns with only empty ROIs (i.e. empty footprint)
    empty_rois = cellfun(@isempty, {rois.footprint});
    empty_rois = reshape(empty_rois, size(rois));
    rois = rois(:, ~all(empty_rois, 1));
end