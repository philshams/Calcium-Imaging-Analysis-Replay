function [minprojs, maxprojs] = stacksminmax(stacks, varargin)
    % STACKSMINMAX return min and max projections of stacks over time axis
    %
    % [minprojs, maxprojs] = stacksminmax(stacks, xyshifts, ...)
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
    %   ... - name-value pair arguments accepted by stacksreduce (indices,
    %       chunksize, useparfor, verbose, etc.)
    %
    % OUTPUTS
    %   minproj - min projections, as either
    %       1) a [X Y Z Channels Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %   maxproj - max projections, as either
    %       1) a [X Y Z Channels Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % EXAMPLES
    %   % min and max projections over the few first frames of a stack
    %   [minproj, maxproj] = stacksminmax(stack, 'indices', [1, 10])
    %
    % SEE ALSO stacksload, stacksmean, stacksreduce

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    unpack = ~iscell(stacks);

    % retrieve min and max projections for each stack
    stacks_proj = stacksreduce(stacks, @accum_stack, @reduce_stack, ...
        varargin{:}, 'unpack', false, 'fcn_name', 'min/max projections');

    % unpacking projections
    nstacks = numel(stacks_proj);
    minprojs = cellfun(@(x) x{1}, stacks_proj, 'un', false);
    maxprojs = cellfun(@(x) x{2}, stacks_proj, 'un', false);

    % return one projection of each kind if one input stack
    if unpack && nstacks == 1
        minprojs = minprojs{1};
        maxprojs = maxprojs{1};
    end
end

function chunk_minmax = accum_stack(chunk)
    % min/max projections over time for a chunk of a stack
    chunk_minmax = {min(chunk, [], 5), max(chunk, [], 5)};
end

function chunks_minmax = reduce_stack(chunk_minmax1, chunk_minmax2)
    % combine min/max projections from 2 different chunks
    minproj = min(chunk_minmax1{1}, chunk_minmax2{1});
    maxproj = max(chunk_minmax1{2}, chunk_minmax2{2});
    chunks_minmax = {minproj, maxproj};
end
