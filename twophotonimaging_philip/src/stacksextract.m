function ts = stacksextract(stacks, rois, varargin)
    % STACKSEXTRACT extract time series of ROIs from stacks
    %
    % ts = stacksextract(stacks, rois, xyshifts, ...)
    %
    % This function extracts ROIs traces from stacks given masks associated with
    % the ROIs. Pixels values contained within a mask are reduced to scalar
    % values using a given function (averaging by default).
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %                      or an empty scalar if the ROI is missing
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   offsets - default: []
    %       offsets to subtract from each ROI, as either
    %       1) a [Channels] vector
    %       2) a cellarray of the previous type
    %   extractfcn - default: @(x) mean(x, 1)
    %       function handle, to convert pixels values of a ROI to a scalar value
    %   ... - other name-value pair arguments accepted by stacksreduce (indices,
    %       chunksize, useparfor, verbose, etc.)
    %
    % OUTPUTS
    %   ts - ROIs + activity timeseries, as a structure array with the same
    %       fields as 'rois' input, with an additional 'activity' field
    %
    % REMARKS
    %   If the footprint of a ROI is not a mask, i.e a logical array, non-zero
    %   values are used to delineate the ROI.
    %
    %   'extractfcn' parameter is a function that accepts a multidimensional
    %   array and reduce it over the first dimension (pixels).
    %
    %   If only one set of ROIs is provided, i.e. a row vector, for several
    %   stacks, the set is duplicated for each stack.
    %
    %   If only one set of offsets is provided, i.e a vector, for several
    %   stacks, the set is duplicated for each stack.
    %
    % EXAMPLES
    %   % take the median of ROIs on registered stacks
    %   ts = stackextract(stacks, rois, xyshifts, 'extractfcn', @median);
    %
    %   % extract traces using chunks of 100 frames and displaying messages
    %   ts = stackextract(stacks, rois, 'chunksize', 100, 'verbose', true);
    %
    %   % estimate offsets before extracting timeseries
    %   offsets = stacksoffsets_gmm(stacks);
    %   ts = stackextract(stacks, rois, 'offsets', offsets);
    %
    % SEE ALSO celldetect_donut, cellsegment, stacksoffsets_gmm, stacksreduce

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    stacks = stackscheck(stacks);
    nstacks = numel(stacks);
    stacks_dims = cellfun(@size, stacks, 'un', false);

    if ~exist('rois', 'var')
        error('Missing rois argument.');
    end
    rois = roischeck(rois, stacks_dims);
    rois_cell = arrayfun(@(x) rois(x, :), 1:nstacks, 'un', false);

    % function to validate 'extractfcn' argument
    function valid_extractfcn(x)
        if ~isa(x, 'function_handle')
            error('Expected ''extractfcn'' to be a function handle.');
        end
    end

    % function to validate 'offsets' argument
    function valid_offsets(x)
        if ~iscell(x)
            x = repmat({x}, 1, nstacks);
        elseif numel(x) ~= nstacks
            error('Number of offsets is different from number of stacks.');
        end
        for istack = 1:nstacks
            nc_stack = size(stacks{istack}, 4);
            x_attr = {'vector', 'numel', nc_stack};
            validateattributes(x{istack}, {'numeric'}, x_attr, '', 'offsets');
        end
    end

    % parse optional inputs
    parser = inputParser;
    parser.KeepUnmatched = true;  % keep extra inputs
    parser.addOptional('xyshifts', []);
    parser.addParameter('extractfcn', @(x) mean(x, 1), @valid_extractfcn);
    parser.addParameter('offsets', [], @valid_offsets);

    parser.parse(varargin{:});
    xyshifts = parser.Results.xyshifts;
    extractfcn = parser.Results.extractfcn;
    offsets = parser.Results.offsets;

    % duplicate offsets if necessary
    if ~isempty(offsets) && ~iscell(offsets)
        offsets = {offsets};
        offsets = repmat(offsets, 1, nstacks);
    end

    % extract ROIs traces in each stack with a map/reduce operation
    map_fcn = @(x, r) extract_traces(x, r, extractfcn);
    traces = stacksreduce(stacks, map_fcn, @reduce_traces, xyshifts, ...
        'unpack', false, 'fcn_name', 'ROIs extraction', 'rois', rois_cell, ...
        parser.Unmatched);

    % copy traces into ROIs structure
    ts = rois;
    for ii = 1:nstacks
        [ts(ii, :).activity] = deal(traces{ii}{:});
    end

    % remove offsets if some where provided
    if ~isempty(offsets)
        nrois = size(ts, 2);
        for ii = 1:nstacks
            for jj = 1:nrois
                ts_offset = offsets{ii}(ts(ii, jj).channel);
                ts(ii, jj).activity = ts(ii, jj).activity - ts_offset;
            end
        end
    end
end

function traces = extract_traces(chunk, rois, extractfcn)
    % extract ROIs traces for a given chunk of a stack

    % flatten first two dimensions of the chunk to ease retrieval after
    [nx, ny, nz, nc, ~] = size(chunk);
    chunk = reshape(chunk, nx * ny, nz, nc, []);

    % preallocate results
    nrois = numel(rois);
    traces = cell(1, nrois);

    % extract ROIs
    for ii = 1:nrois
        if isempty(rois(ii).footprint)
            continue;
        end
        mask = rois(ii).footprint ~= 0;
        vals = chunk(mask(:), rois(ii).zplane, rois(ii).channel, :);
        vals = reshape(vals, nnz(mask), []);
        traces{ii} = extractfcn(vals);
    end
end

function traces = reduce_traces(traces1, traces2)
    % merge traces extracted from 2 consecutive chunks
    ntraces = numel(traces1);
    traces = ...
        arrayfun(@(x) cat(2, traces1{x}, traces2{x}), 1:ntraces, 'un', false);
end
