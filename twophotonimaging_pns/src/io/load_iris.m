function stack = load_iris(irispath, nbplanes, nbchannels)
    % load a stack saved in a binary file (IRIS format)

    % default values for number of z-planes and channels if none found/provided
    if isempty(nbplanes)
        nbplanes = 1;
    end
    if isempty(nbchannels)
        nbchannels = 1;
    end

    % get (x, y) shape from first bytes
    fd = fopen(irispath);
    x_res = fread(fd, 1, 'uint16');
    y_res = fread(fd, 1, 'uint16');
    fclose(fd);

    % get number of frames
    finfo = dir(irispath);
    nframes = finfo.bytes / (x_res * y_res * 2);
    nframes = floor(nframes / (nbchannels * nbplanes));

    % load the sequence
    stack = MappedTensor(...
        irispath, x_res, y_res, nbchannels, nbplanes, nframes, ...
        'Class', 'int16', 'HeaderBytes', 4, 'ReadOnly', true);
    stack = permute(stack, [1, 2, 4, 3, 5]);
end