function img = mergemask(frame, mask, alpha, colormap)
    % MERGEMASK merge an gray image with a set of ROIs defined in a mask
    %
    % img = mergemask(frame, mask, alpha, colormap)
    %
    % INPUTS
    %   frame - a gray image
    %   mask - ROIs, as a label matrix (2D array of 0's where there is no ROI,
    %       and different values representing each ROI)
    %   alpha - transparency level of ROIs, as a value in [0;1]
    %   colormap - colors to display ROIs, either
    %       1) a [N 3] array
    %       2) a string defining a colormap (e.g. 'jet')
    %       3) a function handle (such as @jet)
    %
    % OUTPUTS
    %   img - an RGB image
    %
    % SEE ALSO label2rgb

    % TODO check inputs

    % convert frame in RGB
    frame_rgb = repmat(double(frame), 1, 1, 3);

    % convert mask to color
    mask_rgb = mat2gray(label2rgb(mask, colormap));

    % merge image where mask is non zero, emulating transparency
    idx = repmat(mask ~= 0, 1, 1, 3);
    img = frame_rgb;
    img(idx) = (1 - alpha) .* frame_rgb(idx) + alpha .* mask_rgb(idx);
end
