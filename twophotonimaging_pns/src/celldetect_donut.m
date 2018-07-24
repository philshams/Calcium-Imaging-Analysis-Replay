function cellpos = celldetect_donut(avgstack, model, ncells, celldiam)
    % CELLDETECT_DONUT find cell positions using donut algorithm
    %
    % cellpos = celldetect_donut(avgstack, model, ncells, celldiam)
    %
    % INPUTS
    %   avgstack - average images of a stack, as a [X Y Z Channels] array
    %   model - either
    %       1) a model structure learned with donut algorithm
    %       2) path of a .mat file containing a model structure
    %   ncells - (optional) default: 0
    %       approximate number of cells to find per frame, estimated from
    %       images if 0
    %   celldiam - (optional) default: []
    %       cell diameter in pixels, use model value if empty
    %
    % OUTPUTS
    %   cellpos - (x,y,z,channel) positions of cells, as a [Ncells 4] array
    %
    % REMARKS
    %   Use a relevant model for what you are looking for. Several models are
    %   provided, for soma or boutons, e.g.
    %   - GCaMP6_ModelMFBouton,
    %   - GCaMP6_Soma_Ioana_tp77_fp71 (advised for GCaMP6 imaging of somas).
    %
    %   Look at 'src/training/models' folder to find more models, with different
    %   true positive/false positive tradeoffs.
    %
    %   Do not forget to visually check your results, as this algorithm may:
    %   - miss some relevant cells,
    %   - label blood vessels (and some garbage) as cells.
    %
    %   Do not forget to adjust 'celldiam' parameter if your images are not
    %   zoomed as in the model's training dataset.
    %
    % SEE ALSO stacksmean, cellsegment

    % check inputs and set default values
    if ~exist('avgstack', 'var')
        error('Missing avgstack argument.')
    end
    avgs_attr = {'size', [NaN, NaN, NaN, NaN]};
    validateattributes(avgstack, {'numeric'}, avgs_attr, '', 'avgstack');

    if ~exist('model', 'var')
        error('Missing model argument.')
    elseif ischar(model)
        modelfile = load(model, 'model');
        model = modelfile.model;
    end  % TODO check model fields ?

    if ~exist('ncells', 'var')
        ncells = 0;
    else
        ncells_attr = {'scalar', 'integer', 'nonnegative'};
        validateattributes(ncells, {'numeric'}, ncells_attr, '', 'ncells');
    end

    if ~exist('celldiam', 'var') || isempty(celldiam)
        cellscale = 1;
    else
        cdiam_attr = {'integer', 'positive', 'scalar'};
        validateattributes(celldiam, {'numeric'}, cdiam_attr, '', 'celldiam');

        model_celldiam = (model.Params(5) - 1) / 2;
        cellscale = model_celldiam / celldiam;
    end

    % preallocate results
    [~, ~, nz, nc] = size(avgstack);
    coords = cell(nz, nc);

    % find cell on each z-plane and channel
    for ii=1:nz
        for jj=1:nc
            % find (x,y) coordinates of cells
            avgimg = avgstack(:, :, ii, jj);
            xys = findcells(avgimg, model, ncells, cellscale);

            % concatenate (x,y) with z-plane and channel coordinates
            found_cells = size(xys, 1);
            coords{ii, jj} = ...
                [xys, ones(found_cells, 1) * ii, ones(found_cells, 1) * jj];
        end
    end

    % concatenate results
    cellpos = cat(1, coords{:});
end

function xys = findcells(avgimg, model, ncells, cellscale)
    % detect (x,y) cell positions using donut model

    % rescale image to correspond to model's training images
    if cellscale == 1
        img = avgimg;
    else
        img = imresize(avgimg, cellscale);
    end

    % pad with zeros to get a square image size
    [nx, ny] = size(img);
    if nx > ny
        img = padarray(img, [0,  nx-ny], 0, 'post');
    elseif nx < ny
        img = padarray(img, ny-nx, 0, 'post');
    end

    % detect cells
    [elem, ~] = donut_infer(img, model, ncells);

    % extract position and rescale them for the original image
    valid = elem.map == model.cell_map & elem.ix <= nx & elem.iy <= ny;
    xs = elem.ix(valid) / cellscale;
    ys = elem.iy(valid) / cellscale;

    % return results
    xys = sortrows([xs, ys]);
end
