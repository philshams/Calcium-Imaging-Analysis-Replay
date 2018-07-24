function fix_extract(datapath)
    % quick'n dirty function to re-extract ROIs saved in a .mat

    % ask for a .mat file if none is given
    if ~exist('datapath', 'var')
        [filename, pathname] = uigetfile('*.mat');
        datapath = fullfile(pathname, filename);
    end

    % load data in current workspace and list variables
    load(datapath);
    file_content = whos('-file', datapath);
    varnames = {file_content.name};

    % reload data
    [~, ~, nz, nc] = size(avg_ref);
    stack = stacksload(stackpath, 'nbplanes', nz, 'nbchannels', nc);

    % re-extract ROIs
    ts = stacksextract(stack, ts, xyshifts, ...
        'chunksize', 10, 'verbose', true, 'useparfor', true);

    % and save back everything
    [pathname, filename, ext] = fileparts(datapath);
    new_datapath = fullfile(pathname, [filename, '_fixed', ext]);
    save(new_datapath, varnames{:});
    fprintf('Re-extracted data saved in %s\n', new_datapath);
end