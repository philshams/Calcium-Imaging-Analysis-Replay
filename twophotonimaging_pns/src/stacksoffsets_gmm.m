function offsets = stacksoffsets_gmm(stacks, varargin)
    % STACKSOFFSETS_GMM estimate stacks offsets using a GMM
    %
    % offsets = stacksoffsets_gmm(stacks, ...)
    %
    % This function samples frames (and pixels in these frames) to estimate the
    % stacks offsets, fitting GMMs.
    %
    % INPUTS
    %   stack - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   nframes - default: 20
    %       number of frames (per channel) to sample
    %   npixels - default: 2000
    %       number of pixels to sample in each sampled frame
    %   maxiter - default: 1000
    %       maximum number of iterations to fit the GMM
    %   ncomps - default: 2
    %       number of mixture components
    %   seed - default: 12345
    %       random number generator seed, fixed for reproducibility
    %
    % OUTPUTS
    %   offsets - estimated offsets, as either
    %       1) a [Channels] vector
    %       2) a cellarray of the previous type (if several stacks)
    %
    % REMARKS
    %    This estimation relies on the fact that most of the pixels are dark
    %    (first sharp Gaussian component) with a little bit of signal (second
    %    broader Gaussian component). This is typically the case with fast
    %    resonant scanners, but not with slower galvo scanners.
    %
    % SEE ALSO stacksextract, offsetsshow

    if ~exist('stacks', 'var')
        error('Missing stack argument.')
    end
    unpack = ~iscell(stacks);

    stacks = stackscheck(stacks);
    nstacks = numel(stacks);

    % parse optional inputs
    parser = inputParser;
    posint_attr = {'scalar', 'integer', 'positive'};
    parser.addParameter('nframes', 20, ...
        @(x) validateattributes(x, {'numeric'}, posint_attr, '', 'nframes'));
    parser.addParameter('npixels', 2000, ...
        @(x) validateattributes(x, {'numeric'}, posint_attr, '', 'npixels'));
    parser.addParameter('maxiter', 2000, ...
        @(x) validateattributes(x, {'numeric'}, posint_attr, '', 'maxiter'));
    parser.addParameter('ncomps', 2, ...
        @(x) validateattributes(x, {'numeric'}, posint_attr, '', 'ncomps'));
    parser.addParameter('seed', 12345, ...
        @(x) validateattributes(x, {'numeric'}, posint_attr, '', 'seed'));

    parser.parse(varargin{:});
    nframes = parser.Results.nframes;
    npixels = parser.Results.npixels;
    maxiter = parser.Results.maxiter;
    ncomps = parser.Results.ncomps;
    seed = parser.Results.seed;

    % fix the RNG seed for reproducibility
    rng(seed);

    % estimates offsets of each stack
    offsets = cell(1, nstacks);
    for ii = 1:nstacks
        offsets{ii} = stackoffsets_gmm(stacks{ii}, ...
            nframes, npixels, maxiter, ncomps);
    end

    % do not return cellarrays if only one stack
    if unpack && nstacks == 1
        offsets = offsets{1};
    end
end

function offsets = stackoffsets_gmm(stack, nframes, npixels, maxiter, ncomps)
    % subsample the input stack
    [nx, ny, nz, nc, nt] = size(stack);
    idx_t = randi(nt, nframes);
    idx_z = randi(nz, nframes);

    % sample frames/pixels and estimate offsets with a 2-components GMM
    mus = zeros(nc, nframes);
    for ii = 1:nc
        for jj = 1:nframes
            % retrieve a randomly sampled frame
            frame = stack(:, :, idx_z(jj), ii, idx_t(jj));
            % sub-sample pixels data
            idx_pixels = randperm(nx * ny, npixels);
            samples = double(frame(idx_pixels));
            % treat special case where all pixels are equal
            if numel(unique(samples)) == 1
                mus(ii, jj) = samples(1);
                continue;
            end
            % fit a GMM and keep the lowest mean
            reg_value = var(samples) * 1e-10;  % to avoid unstable fit
            gmm_opts = statset('MaxIter', maxiter);
            obj = fitgmdist(samples', ncomps, ...
                'Options', gmm_opts, 'RegularizationValue', reg_value);
            mus(ii, jj) = min(obj.mu);
        end
    end

    % aggregate replicates estimates with a median (more robust than mean)
    offsets = median(mus, 2);
end