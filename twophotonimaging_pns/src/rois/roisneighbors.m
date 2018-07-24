function rois = roisneighbors(rois, wsize, disk_size)
    % TODO doc
    % TODO input checks

    if ~exist('rois', 'var')
        error('Missing rois argument.');
    end
    rois = roischeck(rois);

    % structuring element to add a gap around ROIs
    se = strel('disk', disk_size);

    % z-planes and channels defined in ROIs
    zplanes = unique([rois.zplane]);
    channels = unique([rois.channel]);

    for ii = 1:size(rois, 1)
        for jj = 1:numel(zplanes)
            for kk = 1:numel(channels)
                % select concrete ROIs on the same z-plane and channel
                real_rois = ~cellfun(@isempty, {rois(ii, :).footprint});
                mask = real_rois;
                mask(real_rois) = mask(real_rois) ...
                    & [rois(ii, real_rois).zplane] == zplanes(jj) ...
                    & [rois(ii, real_rois).channel] == channels(kk);

                rois(ii, mask) = rois_neighbors_(rois(ii, mask), wsize, se);
            end
        end
    end

    % empty 'activity' field, if any
    if isfield(rois, 'activity')
        [rois.activity] = deal([]);
    end
end

function rois = rois_neighbors_(rois, wsize, se)
    % create neighborhood ROIs for a set of ROIs

    % aggregate masks of ROIs (+ additional gap)
    mask = false;
    for ii = 1:numel(rois)
        footprint = rois(ii).footprint ~= 0;
        mask = mask | imdilate(full(footprint), se);
    end
    mask = ~mask;

    % create new neighboring ROIs
    for ii = 1:numel(rois)
        rois(ii).footprint = neighbor_(rois(ii).footprint, wsize) & mask;
    end
end

function disk_footprint = neighbor_(footprint, wsize)
    % create a new footprint representing neighborhood of a given ROI footprint

    % get row/columns coordinates of ROI mask
    [r_roi, c_roi] = find(footprint ~= 0);

    % get row/columns coordinates of a bounding-box around the ROI
    [r_box, c_box] = roibbox(footprint, wsize);

    % design a disk ROI
    [cs, rs] = meshgrid(c_box - mean(c_roi), r_box - mean(r_roi));
    mask = sqrt(cs.^2 + rs.^2) <= wsize / 2;
    disk_footprint = false(size(footprint));
    disk_footprint(r_box, c_box) = mask;
end