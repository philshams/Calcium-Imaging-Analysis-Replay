function avgs = stacksmean(stacks, varargin)
    % STACKSMEAN average images in stacks over time axis
    %
    % avgs = stacksmean(stacks, xyshifts, ...)
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
    %   avgs - averaged images, as either
    %       1) a [X Y Z Channels Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % EXAMPLES
    %   % average over the few first frames of a stack
    %   avg = stacksmean(stack, 'indices', [2, 10])
    %
    % SEE ALSO stacksload, stacksminmax, stacksreduce

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    unpack = ~iscell(stacks);

    % sum each stack over time, using a map/reduce operation
    stacks_sum = stacksreduce(stacks, @accum_stack, @reduce_stack, ...
        varargin{:}, 'unpack', false, 'fcn_name', 'averaging');

    % divide by the number of frames to get averages
    avgs = cellfun(@(x) x.sum ./ x.nframes, stacks_sum, 'un', false);

    % return one averaged stack if one input stack
    if unpack && numel(avgs) == 1
        avgs = avgs{1};
    end
end

function chunk_sum = accum_stack(chunk)
    % sum a chunk of a stack over the time axis, and save the number of frames
    chunk_sum.sum = sum(chunk, 5);
    chunk_sum.nframes = size(chunk, 5);
end

function chunks_sum = reduce_stack(chunk_sum1, chunk_sum2)
    % merge results from to summed chunks
    chunks_sum.sum = chunk_sum1.sum + chunk_sum2.sum;
    chunks_sum.nframes = chunk_sum1.nframes + chunk_sum2.nframes;
end