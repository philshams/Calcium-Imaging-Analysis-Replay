function rois = cellsegment(avgstack, cellpos, model, celldiam)
    % CELLSEGMENT extract ROIs masks of cells given their position in an image
    %
    % mask = cellsegment(avgstack, cellpos, model, celldiam)
    %
    % This function classifies pixels around cell locations as part of a cell
    % or something else. It uses learnt classifiers, 1 per pixel in the patch
    % surronding a cell location.
    %
    % INPUTS
    %   avgstack - average images of a stack, as a [X Y Z Channels] array
    %   cellpos - (x,y,z,channel) positions of cells, as a [Ncells 4] array
    %   model - either
    %       1) a model structure containing classifiers
    %       2) path of a .mat file containing a model structure
    %   celldiam - (optional) default: []
    %       cell diameter in pixels, use model value if empty
    %
    % OUTPUTS
    %   rois - ROIs, as a structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] sparse logical array
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %
    % REMARKS
    %   So far, one model is provided, using linear discriminant analysis (LDA)
    %   classifiers: 'GCaMP6_Soma_Ioana_lda'.
    %
    %   Do not forget to adjust 'celldiam' parameter if your images are not
    %   zoomed as in the model's training dataset.
    %
    % SEE ALSO stacksmean, celldetect_donut, cellpatches

    % check inputs and set default values
    if ~exist('avgstack', 'var')
        error('Missing avgstack argument.')
    end
    avgs_attr = {'size', [NaN, NaN, NaN, NaN]};
    validateattributes(avgstack, {'numeric'}, avgs_attr, '', 'avgstack');

    if ~exist('cellpos', 'var')
        error('Missing cellpos argument.')
    end
    cpos_attr = {'size', [NaN, 4]};
    validateattributes(cellpos, {'numeric'}, cpos_attr, '', 'cellpos');

    if ~exist('model', 'var')
        error('Missing model argument.')
    elseif ischar(model)
        modelfile = load(model, 'model');
        model = modelfile.model;
    end  % TODO check model fields ?

    if ~exist('celldiam', 'var') || isempty(celldiam)
        celldiam = model.celldiam;
    else
        cdiam_attr = {'integer', 'positive', 'scalar'};
        validateattributes(celldiam, {'numeric'}, cdiam_attr, '', 'celldiam');
    end

    % iterate over each z-plane and channel
    rois = struct('footprint', {}, 'zplane', {}, 'channel', {});
    [~, ~, nz, nc] = size(avgstack);

    for ii=1:nz
        for jj=1:nc
            % get masks from cell in the current z-plane
            avgframe = avgstack(:, :, ii, jj);
            xys = cellpos(cellpos(:, 3) == ii & cellpos(:, 4) == jj, 1:2);
            masks = segmentframe(avgframe, xys, model, celldiam);

            % add new ROIs to the returned structure
            new_rois = struct('footprint', masks, 'zplane', ii, 'channel', jj);
            rois = [rois, new_rois];
        end
    end

    % make sure that footprints aren't overlapping
    rois = roisseparate(rois);
end

function masks = segmentframe(frame, xys, model, celldiam)
    % extract cells in one frame

    % resize input frame if necessary, to the nearest integer size
    if celldiam ~= model.celldiam
        % save original image size
        [nx, ny] = size(frame);

        % scale image
        new_size = round([nx, ny] * model.celldiam / celldiam);
        frame = imresize(frame, new_size);

        % scale cell positions
        scale = new_size ./ [nx, ny];
        xys = xys .* repmat(scale, size(xys, 1), 1);
    end

    % get features for classifiers
    [patches, indices] = cellpatches(frame, xys, model.celldiam);
    [ncells, nfx, nfy] = size(patches);
    Y = reshape(patches, [], nfx * nfy);

    % classify each pixel in a patch, for all cells together
    segmented_cells = false(ncells, nfx, nfy);
    for ii=1:nfx
        for jj=1:nfy
            % classify pixels as cell/non-cell
            classif = model.classifiers{ii, jj};
            segmented_cells(:, ii, jj) = logical(model.predictfcn(classif, Y));
        end
    end

    % initialize each ROI
    masks = cell(1, ncells);

    for ii=1:ncells
        mask = false(size(frame));
        mask(indices(ii, :, :)) = segmented_cells(ii, :, :);

        % resize found mask if necessary
        if celldiam ~= model.celldiam
            mask = imresize(mask, [nx, ny], 'nearest');
        end

        masks{ii} = sparse(mask);
    end
end