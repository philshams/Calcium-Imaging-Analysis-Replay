function [nbchannels, nbplanes, perm_z_t] = size_from_scanimage(tifpath)
    % load ScanImage metadata from TIFF header, v5 or v2016

    % default values for channels/z-planes in case of early return
    nbchannels = [];
    nbplanes = [];

    % default value for z-planes and time axes permutation
    perm_z_t = false;

    % retrieve header info from first frame
    tif_obj = Tiff(tifpath, 'r');
    tags.ImageDescription = safe_get_tags(tif_obj, 'ImageDescription', '');
    tags.Software = safe_get_tags(tif_obj, 'Software', '');
    tif_obj.close()

    % z-planes/channels info from ScanImage metadata, v2016
    if ~isempty(tags.Software) && ~strcmp(tags.Software, 'MATLAB')
        metadata_field = tags.Software;
        prefix = '';

    % z-planes/channels info from ScanImage metadata, v5
    else
        metadata_field = tags.ImageDescription;
        prefix = 'scanimage\.';
    end

    channel_txt = regexp(metadata_field, ...
        [prefix, 'SI\.hChannels\.channelSave = (.+?)(?m:$)'], 'tokens', 'once');
    zplane_txt = regexp(metadata_field, ...
        [prefix, 'SI\.hFastZ\.numFramesPerVolume = (.+?)(?m:$)'], ...
        'tokens', 'once');
    frames_per_z_txt = regexp(metadata_field, ...
        [prefix, 'SI\.hStackManager\.framesPerSlice = (.+?)(?m:$)'], ...
        'tokens', 'once');

    % stop if no z-planes/channels info found
    if isempty(channel_txt) || isempty(zplane_txt)
        return
    end

    % convert channel and z-planes info to scalar
    nbchannels = numel(str2num(channel_txt{:}));  %#ok<ST2NM>
    nbplanes = str2double(zplane_txt{:});
    if isnan(nbplanes)
        nbplanes = 1;
    end

    % check if it is a Z-stack, permuting z-planes and time axes if so
    nbframes = str2double(frames_per_z_txt);
    if nbplanes == 1 && nbframes > 1 && ~isinf(nbframes)
        nbplanes = nbframes;
        perm_z_t = true;
    end
end

function tag_value = safe_get_tags(tif_obj, tag_name, default_value)
    % helper function to safely retrieve a tag from a TIFF object
    tag_value = default_value;
    try
        tag_value = tif_obj.getTag(tag_name);
    catch err
        if ~strcmp(err.identifier, 'MATLAB:imagesci:Tiff:tagRetrievalFailed')
            rethrow(err);
        end
    end
end