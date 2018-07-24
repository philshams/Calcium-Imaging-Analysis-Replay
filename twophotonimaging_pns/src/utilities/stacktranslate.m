function trstack = stacktranslate(stack, xyshifts)
    % STACKTRANSLATE apply an (x,y)-shift to a stack
    %
    % trstack = stacktranslate(stack, xyshifts)
    %
    % INPUTS
    %   stack - stack of frames, as a [X Y Z Channels Time] array-like object
    %   xyshifts - shifts for each frame and z-plane, as a [2 Z Time] array
    %
    % OUTPUTS
    %   trstack - translated stack, as [X Y Z Channels Time] array
    %
    % REMARKS
    %   Provided shifts are expected to be integer values and thus are rounded.
    %   Shifts are considered as similar for all channels, i.e channels are
    %   already aligned.
    %
    % SEE ALSO stacksregister_dft, imtranslate

    if ~exist('stack', 'var')
        error('Missing stack argument.')
    end

    if ~exist('xyshifts', 'var')
        error('Missing xyshifts argument.')
    end

    stackcheck(stack, xyshifts);

    % pre-allocate result
    classname = class(stack(1, 1, 1, 1, 1));  % numerical class from first pixel
    trstack = zeros(size(stack), classname);

    % iterate over frames, planes and channels
    [~, ~, nz, ~, nframes] = size(stack);
    for ii=1:nframes
        for jj=1:nz
            xy = round(xyshifts(:, jj, ii));
            frame = squeeze(stack(:, :, jj, :, ii));
            trstack(:, :, jj, :, ii) = shift_frame(frame, xy(1), xy(2));
        end
    end
end

function trframe = shift_frame(frame, sx, sy)
    % translate a frame by filling an output frame subregion with the input
    % frame, which is faster than imstranslate or imdilate-based translation,
    % for integer shifts

    % TODO fill with meaningful default value ? say mean, median, min ?

    % preallocated result
    trframe = zeros(size(frame), 'like', frame);

    % fill part of output frame with input frame
    [nx, ny, ~] = size(frame);
    trframe(max(1, 1+sx):min(nx, nx+sx), max(1, 1+sy):min(ny, ny+sy), :) = ...
        frame(max(1, 1-sx):min(nx-sx, nx), max(1, 1-sy):min(ny-sy, ny), :);
end
