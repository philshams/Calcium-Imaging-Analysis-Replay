function phats = stacksprctile(stacks, p, indices, xyshifts, ressize)
    % STACKSPRCTILE return approximate percentiles of stacks over time axis
    %
    % phats = stacksprctile(stacks, p, indices, xyshifts, ressize)
    %
    % This function approximates percentiles of stacks using reservoir
    % sampling (algorithm R from Vitter, 1985, "Random Sampling with a
    % Reservoir").
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   p - percentiles, either
    %       1) a scalar value in [0; 100]
    %       2) a vector of values in [0; 100]
    %   indices - (optional) default: []
    %       start/stop indices over which average is computed, either
    %       1) start index
    %       2) a vector with [start, stop] indices
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %   ressize - (optional) default: 1000
    %       size of the reservoir to compute approximated percentiles, bigger
    %       number improves accuracy but consume more memory
    %
    % OUTPUTS
    %   phats - percentiles, as either
    %       1) a [X Y Z Channels Percentiles] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % REMARKS
    %   If the size of data is smaller than the reservoir size, computed
    %   percentiles are exact.
    %
    % EXAMPLES
    %   % 5th and 95th percentiles over a range of frames of a stack
    %   phat = stacksprctile(stack, [5, 95], [10000, 20000])
    %
    % SEE ALSO stacksload, stacksmean, stacksminmax

    warning('This function is deprecated and will be removed in next release.')

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    unpack = ~iscell(stacks);

    if ~exist('xyshifts', 'var')
        xyshifts = [];
    end

    [stacks, xyshifts] = stackscheck(stacks, xyshifts);

    if ~exist('p', 'var')
        error('Missing p argument.')
    end
    p_attr = {'>=', 0, '<=',100, 'real', 'vector'};
    validateattributes(p, {'numeric'}, p_attr, '', 'p');

    if ~exist('ressize', 'var')
        ressize = 1000;
    else
        res_attr = {'scalar', 'integer', 'positive'};
        validateattributes(ressize, {'numeric'}, res_attr, '', 'ressize');
    end

    % dealing with default values for start/stop indices
    if ~exist('indices', 'var')
        indices = [];
    end

    % extracting percentiles for each stack
    nstacks = numel(stacks);
    phats = cell(1, nstacks);
    for ii=1:nstacks
        phats{ii} = ...
            stackprctile(stacks{ii}, p, indices, xyshifts{ii}, ressize);
    end

    % return one average if one input stack
    if unpack && nstacks == 1
        phats = phats{1};
    end
end

function phat = stackprctile(stack, p, indices, xyshifts, ressize)
    % compute approximate percentiles for one stack

    [nx, ny, nc, nz, ~] = size(stack);

    % check indices
    [start, stop] = checkindices(stack, indices);

    % build a reservoir if necessary
    ninterval = stop - start + 1;
    if ninterval < ressize
        reservoir = stack(:, :, :, :, start:stop);
        frames_idx = start:stop;
    else
        % start with the first data in the reservoir
        K = start + ressize + 1;
        reservoir = stack(:, :, :, :, start:K);
        frames_idx = start:K;

        % randomly sample remaining data and replace those in reservoir
        for ii=(K+1):stop
            new_id = randi(ii);
            if new_id <= ressize
                reservoir(:, :, :, :, new_id) = stack(:, :, :, :, ii);
                frames_idx(new_id) = ii;
            end
        end
    end

    if ~isempty(xyshifts)
        reservoir = stacktranslate(reservoir, xyshifts(:, :, frames_idx));
    end

    % extract percentiles from reservoir (or data if small enough)
    np = length(p);
    phat = nan(nx, ny, nc, nz, np);
    for ii=1:np
        phat(:, :, :, :, ii) = prctile(reservoir, p(ii), 5);
    end
end
