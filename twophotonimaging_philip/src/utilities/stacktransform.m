function trstack = stacktransform(stack, tform)
    % STACKTRANSFORM apply an affine transform to a stack
    %
    % trstack = stacktransform(stack, tform)
    %
    % INPUTS
    %   stack - stack of frames, as a [X Y Z Channels Time] array-like object
    %   tform - affine transforms, as a [Z] vector of affine2d objects
    %
    % OUTPUTS
    %   trstack - transformed stack, as [X Y Z Channels Time] array
    %
    % SEE ALSO stacksregister_affine, roistransform

    if ~exist('stack', 'var')
        error('Missing stack argument.')
    end
    stackcheck(stack);
    [nx, ny, nz, nc, nframes] = size(stack);

    if ~exist('tform', 'var')
        error('Missing tform argument.')
    end
    validateattributes(tform, {'affine2d'}, {'numel', nz}, '', 'tform');

    % pre-allocate result
    classname = class(stack(1, 1, 1, 1, 1));  % numerical class from first pixel
    trstack = zeros(size(stack), classname);

    % iterate over frames, planes and channels
    output_view = imref2d([nx, ny]);

    for ii = 1:nframes
        for jj = 1:nz
            for kk = 1:nc
                frame = squeeze(stack(:, :, jj, kk, ii));
                frame = imwarp(frame, tform(jj), 'OutputView', output_view);
                trstack(:, :, jj, kk, ii) = frame;
            end
        end
    end
end