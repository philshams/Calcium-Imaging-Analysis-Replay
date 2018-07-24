function rois = roisseparate(rois)
    % ROISSEPARATE reassign overlapping part of ROIs and add a gap between them
    %
    % rois = roisseparate(rois)
    %
    % INPUTS
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %                      or an empty scalar if the ROI is missing
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %
    % OUTPUTS
    %   rois - similar structure as 'rois' input
    %
    % REMARKS
    %   Pixels in overlapping regions are reassigned to the ROI whose center is
    %   the closest.
    %
    %   Removal of ROI pixels touching a neighborhing ROI is done greedily,
    %   favoring smaller ROIs (i.e. removing pixels from bigger ROIs first).
    %
    %   If input ROIs have an 'activity' field, it will be emptied to ensure
    %   that one can't use traces incoherent with footprints.
    %
    % SEE ALSO cellsegment

    if ~exist('rois', 'var')
        error('Missing rois argument.');
    end
    rois = roischeck(rois);

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

                rois(ii, mask) = rois_separate_(rois(ii, mask));
                rois(ii, mask) = add_gap(rois(ii, mask));
            end
        end
    end

    % empty 'activity' field, if any, and issue a warning
    if isfield(rois, 'activity')
        [rois.activity] = deal([]);
        warning('Activity field have been emptied to avoid incoherent traces.')
    end
end

function rois = rois_separate_(rois)
    % assign overlapping pixels to the closest ROI footprint

    nrois = numel(rois);
    [nx, ny] = size(rois(1).footprint);

    % aggregate footprints to find overlaps, and compute ROIs center
    rois_masks = spalloc(nx * ny, nrois, 10 * nx * ny);
    centers = zeros(nrois, 2);
    for ii = 1:nrois
        mask = rois(ii).footprint ~= 0;
        rois_masks(mask(:), ii) = true;
        [rows, cols] = find(mask);
        centers(ii, :) = [mean(rows), mean(cols)];
    end

    % find conflicting pixels
    conflict_mask = sum(rois_masks, 2) > 1;
    [rows, cols] = ind2sub([nx, ny], find(conflict_mask));
    pix_coords = [rows, cols];

    % remove conflicting pixels from all footprints
    for ii = 1:nrois
        rois(ii).footprint(conflict_mask) = 0;
    end

    % find closest ROI center of each problematic pixel and add it to the ROI
    rois_mask_w_conflict = rois_masks(conflict_mask, :);
    pix_dists = pdist2(centers, pix_coords);
    for ii = 1:size(pix_dists, 2)
        rois_idx = find(rois_mask_w_conflict(ii, :));
        [~, id_min] = min(pix_dists(rois_idx, ii));
        roi_id = rois_idx(id_min);
        rois(roi_id).footprint(pix_coords(ii, 1), pix_coords(ii, 2)) = 1;
    end
end

function rois = add_gap(rois)
    % add a gap between ROIs footprints

    % sort ROIs using the size of their footprint
    [~, idx] = sort(cellfun(@nnz, {rois.footprint}));

    se = strel('square', 3);

    % fix footprints from smaller to larger ROIs
    rois_masks = 0;
    for ii = 1:numel(rois)
        roi_id = idx(ii);
        mask = full(rois(roi_id).footprint ~= 0);

        % find footprint pixels in the neighborhood of other footprints
        bad_pixels = mask & rois_masks;
        rois(roi_id).footprint(bad_pixels) = 0;

        % update image of neighborhoods of footprints
        mask(bad_pixels) = 0;
        rois_masks = rois_masks | imdilate(mask, se);
    end
end