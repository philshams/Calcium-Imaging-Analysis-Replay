function avgs_ref = stackstemplate(stacks, n_batches, batch_size, varargin)
    % STACKSTEMPLATE create template images for registration
    %
    % avgs_ref = stackstemplate(stacks, n_batches, batch_size, ...)
    %
    % This function creates reference images useful for registration, using a
    % fraction of each stack. It randomly samples batches of images, then
    % registers and averages them.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   n_batches - number of batches to sample in a stack (see remarks)
    %   batch_size - number of frames in each batch (see remarks)
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   seed - default: 12345
    %       arbitrary number used to seed the random number generator, to get
    %       repoducible results
    %   filterfcn - default: @(x) x
    %       function used to filter each batch before averaging
    %   ... - name-value pair arguments accepted by stacksregister_dft (margins,
    %       maxshift, etc.)
    %
    % OUTPUTS
    %   avgs_ref - template images, as either
    %       1) a [X Y Z Channels] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % REMARKS
    %   The number of frames in each batch is a tradeoff between signal and
    %   sharpness. With more frames, you get a better signal to noise ratio in
    %   each batch average, making them easier to register. However, with more
    %   frames, these averages will also be individually blurrier, leading to a
    %   worse final template.
    %
    %   Using more batches will increase the quality of the template at the
    %   expense of computational time. It will also lower the risk that template
    %   signal is dominated by one bad batch average.
    %
    % EXAMPLES
    %   % use of 300 frames as 15 batches of 20 frames to create templates
    %   avgs_ref = stackstemplate(stack, 15, 20);
    %
    %   % use margins (50 pixels) during registration
    %   avgs_ref = stackstemplate(stack, 15, 20, 'margins', 50);
    %
    %   % filter batches to avoid noise enhancement during the registration
    %   avgs_ref = stackstemplate(stack, 15, 20, 'filterfcn', @filtersmall);
    %
    % SEE ALSO stacksregister_dft, stacksmean, filtersmall, filterstripes

    % check mandatory inputs
    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    unpack = ~iscell(stacks);

    stacks = stackscheck(stacks);
    nstacks = numel(stacks);

    pos_attr = {'scalar', 'integer', 'positive'};

    if ~exist('n_batches', 'var')
        error('Missing n_batches argument.')
    else
        validateattributes(n_batches, {'numeric'}, pos_attr, '', 'n_batches');
    end

    if ~exist('batch_size', 'var')
        error('Missing batch_size argument.')
    else
        validateattributes(batch_size, {'numeric'}, pos_attr, '', 'batch_size');
    end

    % parse optional inputs
    parser = inputParser;
    parser.KeepUnmatched = true;  % keep extra inputs
    parser.addParameter('seed', 12345, ...
        @(x) validateattributes(x, {'numeric'}, pos_attr, '', 'seed'));
    parser.addParameter('filterfcn', @(x) x, @(x) isa(x, 'function_handle'));

    parser.parse(varargin{:});
    seed = parser.Results.seed;
    filterfcn = parser.Results.filterfcn;

    % fix random seed for reproducibility
    rng(seed);

    % create template from each stack
    avgs_ref = cell(1, nstacks);
    for ii = 1:nstacks
        avgs_ref{ii} = stacktemplate(stacks{ii}, ...
            n_batches, batch_size, filterfcn, parser.Unmatched);
    end

    % do not return cellarrays if only one stack
    if unpack && nstacks == 1
        avgs_ref = avgs_ref{1};
    end
end

function avg_ref = stacktemplate(stack, n_batches, batch_size, filterfcn, dft_args)
    % create a reference image from sampled mini-batches of images

    % sample batches start/stop indices, evenly on the time axis
    nt = size(stack, 5);
    chunksize = fix(nt / n_batches);
    istart = randi(chunksize - batch_size + 1, 1, n_batches);
    idx = istart + ((1:n_batches) - 1) * chunksize;

    % retrieve and average mini-batches
    batches_avg = cell(1, n_batches);
    for ii = 1:n_batches
        indices = idx(ii):(idx(ii) + batch_size - 1);
        mini_batch = stack(:, :, :, :, indices);
        batches_avg{ii} = mean(filterfcn(mini_batch), 5);
    end

    % reorder averages according to their "signal" (measured as total mean)
    batches_means = cellfun(@(x) max(fft_snr(x)), batches_avg);
    [~, batches_order] = sort(batches_means, 'descend');
    batches_avg = batches_avg(batches_order);

    % greedily register averaged mini-batches and accumulate them
    avg_ref = batches_avg{1};
    for ii = 2:n_batches
        xys = stacksregister_dft(batches_avg{ii}, avg_ref, dft_args);
        avg_ref = avg_ref + stacktranslate(batches_avg{ii}, xys);
    end
    avg_ref = avg_ref ./ n_batches;
end

function channels_snr = fft_snr(frames)
    % helper function to roughly estimate SNR using FFT
    [nx, ny, ~, nc] = size(frames);
    half_x = fix(nx / 4);
    half_y = fix(ny / 4);

    fft_frames = fft(fft(frames, [], 1), [], 2);
    fft_sig = fft_frames(2:half_x, 2:half_y, :, :);
    fft_noise = fft_frames(half_x:(2 * half_x), half_y:(2 * half_y), :, :);

    sig_psd = mean(reshape(abs(fft_sig).^2, [], nc), 1);
    noise_psd = mean(reshape(abs(fft_noise).^2, [], nc), 1);
    channels_snr = sig_psd ./ noise_psd;
end
