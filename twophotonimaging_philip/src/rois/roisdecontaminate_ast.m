function ts = roisdecontaminate_ast(ts_raw, ts_neighbors)
    % ROISDECONTAMINATE_AST decontaminate ROIs using Asymmetric Student-t model
    %
    % ts = roisdecontaminate_ast(ts_raw, ts_neighbors)
    %
    % INPUTS
    %   TODO
    %
    % OUTPUTS
    %   TODO
    %
    % EXAMPLES
    %   % create a set of neighborhood ROIs from existing ROIS
    %   neighbors = roisneighbors(rois, 25, 2);
    %
    %   % extract all ROIS together, for efficiency
    %   rois_all = cat(2, rois, neighbors);
    %   ts_all = stacksextract(stacks, rois_all, xyshifts, 'verbose', true);
    %   ts_raw = ts_all(:, 1:size(rois, 2));
    %   ts_neighbors = ts_all(:, 1+size(rois, 2):end);
    %
    %   % decontaminate all ROIS
    %   ts_clean = roisdecontaminate_ast(ts_raw, ts_neighbors)
    %
    % SEE ALSO stacksextract, roisneighbors

    % TODO documentation
    % TODO input checks

    maxiter = 5000;
    verbose = true;
    fcn_name = 'decontamination';
    pool = gcp();

    [nstacks, nrois] = size(ts_raw);

    ts = ts_raw;
    for ii = 1:nstacks
        if verbose
            fprintf('%s for stack %d/%d started (%s)\n', ...
                    fcn_name, ii, nstacks, datestr(now()));
        end

        % queue all decontamination task on the worker pool
        for jj = nrois:-1:1
            funcs(jj) = parfeval(pool, ...
                @roiclean, 1, ts_raw(ii, jj), ts_neighbors(ii, jj), maxiter);
        end

        % init progress display: percent increment, first milestone and start time
        perc_increment = 10;
        nextperc = perc_increment;
        timer = tic;

        % retrieve results as soon as they are available
        for jj = 1:nrois
            [idx, ts_clean] = fetchNext(funcs);
            ts(idx) = ts_clean;

            % display progress every few percent
            perc = jj / nrois * 100;
            if verbose && perc > nextperc
                fprintf('%s progress: %.0f%%', fcn_name, perc)

                % estimated remaining time
                elapsed = toc(timer);
                remaining = elapsed * (100 / perc - 1);
                eta = addtodate(now, round(remaining), 'second');
                fprintf(' (ETA: %s)\n', datestr(eta));

                % next percent milestone
                nextperc = nextperc + perc_increment;
            end
        end

        if verbose
            fprintf('%s for stack %d/%d completed (%s)\n', ...
                    fcn_name, ii, nstacks, datestr(now()));
        end
    end
end

function ts = roiclean(ts_raw, ts_neighbors, maxiter)
    % helper function to decontaminate one ROI
    ts = ts_raw;

    % skip empty ROI
    if isempty(ts_raw.footprint)
        return;
    end

    traces = [ts_raw.activity; ts_neighbors.activity];
    n_sectors = [nnz(ts_raw.footprint), nnz(ts_neighbors.footprint)];
    cleaned_trace = fit_ast_model(traces, n_sectors, 'maxiter', maxiter);
    ts.activity = cleaned_trace;
end