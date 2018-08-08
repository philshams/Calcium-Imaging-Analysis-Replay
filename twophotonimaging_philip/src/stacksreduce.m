function rstacks = stacksreduce(stacks, mapfcn, reducefcn, varargin)
    % STACKSREDUCE perform a map/reduce operation over time axis of stacks
    %
    % rstacks = stacksreduce(stacks, mapfcn, reducefcn, xyshifts, ...)
    %
    % This function iterates over chunks of data, applying a user-defined
    % function on each of them ("map" step), and using a second user-defined
    % function to aggregate these results ("reduce" step).
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   mapfcn - function to apply on each chunk of data, as a function handle,
    %       taking one input (a 5D array)
    %   reducefcn - function to aggregate current result with next chunk result,
    %       as a function handle, taking two inputs
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   indices - default: []
    %       start/stop indices over which the map/reducte operation is applied,
    %       as either
    %       1) a start index
    %       2) a vector with [start, stop] indices
    %       3) a cellarray of the previous type (if several stacks)
    %   chunksize - default: 1
    %       number of frames to load at once, which accelerates computation but
    %       consumes more memory
    %   useparfor - default: false
    %       turn on use of 'parfor' loop to distribute computations over a pool
    %       of workers (might not accelerate computations, see remarks)
    %   verbose - default: false
    %       boolean flag to display extra informations
    %   fct_name - default: 'map/reduce operation'
    %       string used to qualify the current operation in verbose mode
    %   unpack - default: true
    %       flag to indicate if results should be returned in a cellarray or
    %       directly unboxed, in case only one stack has been given
    %   ... - additional name-value pair argument, passed to 'mapfcn' after
    %       replication for each input stack (see remarks)
    %
    % OUTPUTS
    %   rstacks - results from the map/reduce operation, as either
    %       1) the output type of 'reducefcn' function
    %       2) a cellarray of the previous type (if several stacks or unpack is
    %          false)
    %
    % REMARKS
    %   Turning on 'parfor' use might not improve the speed if you don't have
    %   enough workers available on your machine. Indeed, without 'parfor',
    %   user provided functions might use multithreaded functions that already
    %   accelerate some operations but don't perform as well with 'parfor'
    %   enabled.
    %
    %   For additional name-value pair arguments, only values are passed to
    %   'mapfcn', after sorting pairs by name. Arguments that are not cellarrays
    %   of the same number of elements as the stacks are copied for each stack.
    %
    % EXAMPLES
    %   % sum over the few first frames of a stack
    %   summed_stack = stacksreduce(stack, @(x) sum(x, 5), @(x, y) x + y, ...
    %       'indices', [2, 10]);
    %
    %   % get the maximum, loading data in chunks of 100 frames, in verbose mode
    %   m_stack = stacksreduce(stack, @(x) max(x, [], 5), @(x, y) max(x, y), ...
    %       'chunksize', 100, 'verbose', true);
    %
    %   % get the maximum of averaged chunks, in verbose mode
    %   m_stack = stacksreduce(stack, @(x) mean(x, 5), @(x, y) max(x, y), ...
    %       'chunksize', 50, 'verbose', true);
    %
    % SEE ALSO stacksmean, stacksminmax, stacksregister_dft, stacksextract

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end

    if ~exist('mapfcn', 'var')
        error('Missing mapfcn argument.')
    elseif ~isa(mapfcn, 'function_handle')
        error('Expected mapfcn to be a function handle.');
    end

    if ~exist('reducefcn', 'var')
        error('Missing reducefcn argument.')
    elseif ~isa(reducefcn, 'function_handle')
        error('Expected reducefcn to be a function handle.');
    end

    % parse optional inputs
    parser = inputParser;
    parser.KeepUnmatched = true;  % keep extra inputs
    parser.addOptional('xyshifts', []);
    parser.addParameter('indices', []);
    chunk_attr = {'scalar', 'integer', 'positive'};
    parser.addParameter('chunksize', 1, ...
        @(x) validateattributes(x, {'numeric'}, chunk_attr, '', 'chunksize'));
    parser.addParameter('useparfor', false, ...
        @(x) validateattributes(x, {'logical'}, {'scalar'}, '', 'useparfor'));
    parser.addParameter('verbose', false, ...
        @(x) validateattributes(x, {'logical'}, {'scalar'}, '', 'verbose'));
    parser.addParameter('fcn_name', 'map/reduce operation', @ischar);
    parser.addParameter('unpack', true, ...
        @(x) validateattributes(x, {'logical'}, {'scalar'}, '', 'unpack'));

    parser.parse(varargin{:});
    xyshifts = parser.Results.xyshifts;
    indices = parser.Results.indices;
    chunksize = parser.Results.chunksize;
    useparfor = parser.Results.useparfor;
    verbose = parser.Results.verbose;
    fcn_name = parser.Results.fcn_name;
    unpack = parser.Results.unpack;

    % check stacks and (x,y)-shifts
    [stacks, xyshifts] = stackscheck(stacks, xyshifts);
    nstacks = numel(stacks);

    % check input indices
    if ~iscell(indices)
        indices = repmat({indices}, 1, nstacks);
    end
    [start, stop] = cellfun(@checkindices, stacks, indices, 'un', false);

    % deal with extra inputs
    other_inputs = repeat_extra_inputs(parser.Unmatched, nstacks);

    % map/reduce function with/without parfor loop
    if useparfor
        mapreduce_fcn = @parallel_reduce;
    else
        mapreduce_fcn = @stackreduce;
    end

    % apply map/reduce to each stack
    rstacks = cell(1, nstacks);
    for ii = 1:nstacks
        if verbose
            fprintf('%s for stack %d/%d started (%s)\n', ...
                    fcn_name, ii, nstacks, datestr(now()));
        end

        try
            rstacks{ii} = mapreduce_fcn( ...
                stacks{ii}, xyshifts{ii}, mapfcn, reducefcn, ...
                other_inputs{ii}, start{ii}, stop{ii}, ...
                chunksize, verbose, fcn_name);

        % make misspelled named parameter error (quite usual) more explicit
        catch err
            if ~strcmp(err.identifier, 'MATLAB:TooManyInputs')
                rethrow(err);
            end
            fnames = fieldnames(parser.Unmatched);
            error([ ...
                '''%s'' is not a recognized parameter. For a list of ', ...
                'valid name-value pair arguments, see the documentation ', ...
                'for this function.'], fnames{end});
        end

        if verbose
            fprintf('%s for stack %d/%d completed (%s)\n', ...
                    fcn_name, ii, nstacks, datestr(now()));
        end
    end

    % return one result if only one input stack
    if unpack && nstacks == 1
        rstacks = rstacks{1};
    end
end

function other_inputs = repeat_extra_inputs(unmatched, nstacks)
    % helper function to retrieve and duplicate extra inputs for each stack

    extra_inputs = sort(fieldnames(unmatched));
    n_extras = numel(extra_inputs);
    other_inputs = repmat({cell(1, n_extras)}, 1, nstacks);

    % return a cellarray of empty cellarrays if no extra inputs
    if isempty(extra_inputs)
        return;
    end

    % otherwise duplicate (if necessary) extra inputs for each stack
    for ii = 1:nstacks
        for jj = 1:n_extras
            field = extra_inputs{jj};
            values = unmatched.(field);
            if iscell(values) && numel(values) == nstacks
                other_inputs{ii}{jj} = values{ii};
            else
                other_inputs{ii}{jj} = values;
            end
        end
    end
end

function rstack = stackreduce(stack, xyshifts, mapfcn, reducefcn, other_inputs, ...
                              start, stop, chunksize, verbose, fcn_name)
    % apply a map/reduce operation over a stack

    % init progress display: percent increment, first milestone and start time
    perc_increment = 10;
    nextperc = perc_increment;
    timer = tic;

    % get the first chunk
    next = start + chunksize - 1;
    if next > stop
        next = stop;
    end

    chunk = stack(:, :, :, :, start:next);
    if ~isempty(xyshifts)
        chunk = stacktranslate(chunk, xyshifts(:, :, start:next));
    end

    % use the first chunk to initialize returned map/reduced stack
    rstack = mapfcn(chunk, other_inputs{:});

    % iterate over chunk of data
    for ii = (next+1):chunksize:stop
        last = ii + chunksize - 1;
        if last > stop
            last = stop;
        end

        chunk = stack(:, :, :, :, ii:last);
        % translate image if necessary
        if ~isempty(xyshifts)
            chunk = stacktranslate(chunk, xyshifts(:, :, ii:last));
        end

        % transform chunk and aggregate with previous results
        rchunk = mapfcn(chunk, other_inputs{:});
        rstack = reducefcn(rstack, rchunk);

        % display progress every few percent
        perc = (ii - start) / (stop - start + 1) * 100;
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
end

function rstack = parallel_reduce(stack, xyshifts, mapfcn, reducefcn, other_inputs, ...
                                  start, stop, chunksize, verbose, fcn_name)
    % apply a map/reduce operation over a stack with several workers in parallel

    nframes = stop - start + 1;

    % retrieve big chunks in parallel
    pool = gcp();

    bigchunksize = floor(nframes / pool.NumWorkers);
    rbigchunks = cell(1, pool.NumWorkers);

    parfor ii=1:pool.NumWorkers
        % start/stop indices for the big chunk
        bcstart = start + (ii - 1) * bigchunksize;
        bcstop = bcstart + bigchunksize - 1;

        % make sure only the first worker speaks
        chatty = verbose && ii == 1;

        % map/reduce the big chunk
        rbigchunks{ii} = stackreduce( ...
            stack, xyshifts, mapfcn, reducefcn, other_inputs, ...
            bcstart, bcstop, chunksize, chatty, fcn_name);
    end

    % aggregate together map/reduced bichunks
    rstack = rbigchunks{1};
    for ii = 2:pool.NumWorkers
        rstack = reducefcn(rstack, rbigchunks{ii});
    end

    % last few frames if any
    last_frame = start + pool.NumWorkers * bigchunksize - 1;
    if last_frame < stop
        rchunk = stackreduce( ...
            stack, xyshifts, mapfcn, reducefcn, other_inputs, ...
            last_frame + 1, stop, chunksize, false, fcn_name);
        rstack = reducefcn(rstack, rchunk);
    end
end
