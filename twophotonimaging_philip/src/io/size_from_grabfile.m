function [nbchannels, nbplanes] = size_from_grabfile(stackpath)
    % load metadata from a GRABinfo.mat in a directory, if any

    % default values for channels/zplanes in case of early return
    nbchannels = [];
    nbplanes = [];

    % use GRABinfo.mat file if any in the same directory as TIFF files
    files = dir(stackpath);
    grab_mask = ~cellfun(@isempty, regexpi({files.name}, 'GRABinfo.mat$'));
    ngrab = sum(grab_mask);

    if ngrab == 0
        return;

    elseif ngrab > 1
        error('Multiple GRABinfo.mat files detected.');

    else
        grab = load(fullfile(stackpath, files(grab_mask).name), 'GRABinfo');
        nbplanes = grab.GRABinfo.stackNumSlices;
        nbchannels = numel(grab.GRABinfo.channelsSave);
    end
end