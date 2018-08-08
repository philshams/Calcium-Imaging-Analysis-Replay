function filt_frames = filtersmall(frames, nsigmas, subfactor)
    % FILTERSMALL threshold small values pixels in sparse images
    %
    % filt_frames = filtersmall(frames)
    %
    % This function is a really specific function to remove small values
    % artifacts in sparse images (e.g. acquired with a resonant scanner). It
    % assumes that images are mostly dark, with few active pixels.
    %
    % INPUTS
    %   frames - contaminated images, as a ND array
    %   nsigmas - (optional) default: 3
    %       number of standard deviations, used for thresholding
    %   subfactor - (optional) default: 50
    %       sub-sampling factor for image statistics estimation
    %
    % OUTPUT
    %   filt_frames - filtered images, as a ND array
    %
    % SEE ALSO stackstemplate

    if ~exist('frames', 'var')
       error('Missing frame argument.');
    end
    validateattributes(frames, {'numeric'}, {'nonempty'}, '', 'frames');

    if ~exist('nsigmas', 'var') || isempty(nsigmas)
        nsigmas = 3;
    else
        nsig_attr = {'scalar', 'positive'};
        validateattributes(nsigmas, {'numeric'}, nsig_attr, '', 'nsigmas');
    end

    if ~exist('subfactor', 'var') || isempty(subfactor)
        subfactor = 50;
    else
        subf_attr = {'scalar', 'integer', 'positive'};
        validateattributes(subfactor, {'numeric'}, subf_attr, '', 'subfactor');
    end

    % sub-sample frames
    [nx, ny, ~] = size(frames);
    npixels = round(nx * ny / subfactor);
    idx_pixels = randperm(nx * ny, npixels);

    frames_flat = reshape(frames, nx * ny, []);
    frames_sub = frames_flat(idx_pixels, :);

    % compute threshold based on robust estimates (median and MAD)
    med_frames = median(frames_sub);
    mad_frames = median(abs(frames_sub - repmat(med_frames, npixels, 1)));
    threshold = med_frames + 1.4826 * mad_frames * nsigmas;

    % threshold small values in each frame
    filt_frames = frames;
    for ii = 1:size(threshold, 2)
        frame = frames(:, :, ii);
        frame(frame < threshold(ii)) = med_frames(ii);
        filt_frames(:, :, ii) = frame;
    end
end