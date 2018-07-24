function [start, stop] = checkindices(stack, indices)
    % CHECKINDICES clean input indices for slicing a stack over its time axis
    % 
    % [start, stop] = checkindices(stack, indices)
    %
    % This function is an helper function to clean other functions inputs.
    %
    % INPUTS
    %   stack - a stack of frames, as a [X Y Z Channels Time] array-like object
    %   indices - start/stop indices over which the stack will be sliced as
    %       either
    %       1) empty vector (to get the largest possible range)
    %       2) start index, as a scalar
    %       3) a vector with [start, stop] indices
    %
    % OUTPUTS
    %   start - first frame index, as an integer
    %   stop - last frame index, as an integer
    %
    % SEE ALSO stacksreduce, stacksmean, stacksminmax, stacksprctile

    if ~exist('stack', 'var')
        error('Missing stack argument.');
    end

    if ~exist('indices', 'var')
        error('Missing indices argument.');
    end

    % to return default start/stop indices
    if isempty(indices)
        indices = 1;
    end

    % check indices
    nframes = size(stack, 5);
    if numel(indices) == 1
        indices = [indices, nframes];
    end

    indices_attr = ...
        {'integer', 'positive', '<=', nframes, 'nondecreasing', 'numel', 2};
    validateattributes(indices, {'numeric'}, indices_attr, '', 'indices');

    % split start/stop indices
    start = indices(1);
    stop = indices(2);
end
