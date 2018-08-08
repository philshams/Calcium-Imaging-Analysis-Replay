classdef DetectRois < handle

    properties (SetAccess = private)
        % View related properties
        bt_dmodel       % button to select detection model file
        edit_dmodel     % field to display selected detection model file
        bt_smodel       % button to select segmentation model file
        edit_smodel     % field to display selected segmentation model file
        edit_diam_min   % field to edit minimum cell diameter parameter
        edit_diam_max   % field to edit maximum cell diameter parameter
        edit_ncells     % field to edit number of cells looked for
        bt_detect_rois  % button to start ROIs detection
        bt_add_roi      % button to add a ROI
        cb_replicate    % checkbox to trigger replication over stacks
        img_axis        % axis where images are displayed
        himage          % handle of image display
 
        % Model related properties
        stacks_model    % object managing input images
        rois_model      % object managing ROIs
        dmodel          % detection model
        smodel          % segmentation model

        % ID of callback dealing with mouse clicks
        id_cb
    end

    methods

        function obj = DetectRois(stacks_model, rois_model, img_fig, fig)
            obj.stacks_model = stacks_model;
            obj.rois_model = rois_model;
            obj.dmodel = [];
            obj.smodel = [];

            % load the view
            obj.bt_dmodel = findobj(fig, 'tag', 'btDModel');
            obj.edit_dmodel = findobj(fig, 'tag', 'editDModel');
            obj.bt_smodel = findobj(fig, 'tag', 'btSModel');
            obj.edit_smodel = findobj(fig, 'tag', 'editSModel');
            obj.edit_diam_min = findobj(fig, 'tag', 'editDiamMin');
            obj.edit_diam_max = findobj(fig, 'tag', 'editDiamMax');
            obj.edit_ncells = findobj(fig, 'tag', 'editNcells');
            obj.bt_detect_rois = findobj(fig, 'tag', 'btDetectRois');
            obj.bt_add_roi = findobj(fig, 'tag', 'btAddRoi');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');
            obj.img_axis = imgca(img_fig);
            obj.himage = imhandles(obj.img_axis);

            % load models (which initializes the view)
            obj.update_dmodel();
            obj.update_smodel();

            % callbacks to update the view
            obj.bt_dmodel.Callback = @(~, ~) pick_model(obj.edit_dmodel);
            obj.bt_smodel.Callback = @(~, ~) pick_model(obj.edit_smodel);
            obj.edit_dmodel.Callback = @obj.update_dmodel;
            obj.edit_smodel.Callback = @obj.update_smodel;
            obj.edit_diam_min.Callback = @obj.clean_celldiams;
            obj.edit_diam_max.Callback = @obj.clean_celldiams;
            obj.edit_ncells.Callback = @obj.clean_ncells;

            % callbacks to update the model on view updates
            obj.bt_detect_rois.Callback = @obj.detect_rois;
            obj.bt_add_roi.Callback = @obj.update_add_roi;
        end

        function update_view(obj, varargin)
            % disable ROI detection buttons if no model

            if isempty(obj.dmodel) || isempty(obj.smodel)
                % disable buttons
                obj.bt_detect_rois.Enable = 'off';
                obj.bt_add_roi.Enable = 'off';
                % turn off add ROI button
                obj.bt_add_roi.Value = false;
                obj.update_add_roi();
            else
                obj.bt_detect_rois.Enable = 'on';
                obj.bt_add_roi.Enable = 'on';
            end
        end

        function update_dmodel(obj, varargin)
            % load detection model
            obj.dmodel = load_model(obj.edit_dmodel);
            % update view
            obj.update_view();
            % update cell diameter default value if necessary
            obj.clean_celldiams();
        end

        function update_smodel(obj, varargin)
            % load segmentation model
            obj.smodel = load_model(obj.edit_smodel);
            % update view
            obj.update_view();
        end

        function celldiams = clean_celldiams(obj, varargin)
            % clean user input for cell diameter(s)

            % use detection model patch size (if any) as default celldiam
            default_celldiam = [];
            if ~isempty(obj.dmodel)
                default_celldiam = (obj.dmodel.Params(5) - 1) / 2;
            end

            % local function to filter bad input values
            function x = replace_bad(x)
                if x <= 0 || isnan(x)
                    x = default_celldiam;
                end
            end

            celldiams = {str2double(obj.edit_diam_min.String), ...
                         str2double(obj.edit_diam_max.String)};
            celldiams = cellfun(@replace_bad, celldiams, 'un', false);
            celldiams = sort(cell2mat(celldiams));

            % assign min/max values to the corresponding fields
            obj.edit_diam_min.String = celldiams(1);
            obj.edit_diam_max.String = celldiams(end);
        end

        function ncells = clean_ncells(obj, varargin)
            % clean user input for cell number
            ncells = max(0, str2double(obj.edit_ncells.String));
            obj.edit_ncells.String = ncells;
        end

        function detect_rois(obj, varargin)
            % detect ROIs using the currently displayed frame

            % retrieve inputs for detection/segmentation models
            frame = obj.stacks_model.frame;
            celldiams = obj.clean_celldiams();
            celldiam = celldiams(end);  % only use the biggest diameter
            ncells = obj.clean_ncells();

            % find cells and segment them
            cellpos = celldetect_donut(frame, obj.dmodel, ncells, celldiam);
            rois = cellsegment(frame, cellpos, obj.smodel, celldiam);

            % stop there if no cell found
            if isempty(rois)
                return;
            end

            % adapt zplane/channel information
            [rois.zplane] = deal(obj.rois_model.iframe(2));
            [rois.channel] = deal(obj.rois_model.iframe(3));

            % replicate new ROI over stacks if necessary
            del_rois = [];
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
                del_rois = zeros(nstacks, 0);
            end

            % delete old displayed ROIs
            obj.rois_model.update_frame(del_rois, obj.rois_model.shown);

            % update current displayed ROIs
            obj.rois_model.update_frame(rois, [], true);
        end

        function update_add_roi(obj, varargin)
            % add callback to image, to click to add a new ROI
            if obj.bt_add_roi.Value
                obj.id_cb = iptaddcallback( ...
                    obj.himage, 'ButtonDownFcn', @obj.add_roi);

            % removing clicking callback
            else
                iptremovecallback( ...
                    obj.himage, 'ButtonDownFcn', obj.id_cb);
                obj.id_cb = [];
            end
        end

        function add_roi(obj, varargin)
            % last clicked pixel coordinates
            pixel = obj.img_axis.CurrentPoint;
            col = round(pixel(1, 1));
            line = round(pixel(1, 2));

            % retrieve inputs from detection/segmentation
            celldiams = obj.clean_celldiams();
            celldiams = celldiams(1):celldiams(end);
            frame = obj.stacks_model.frame;
            [nx, ny] = size(frame);

            for ii = 1:numel(celldiams)
                % get patch around location
                cdiam = celldiams(ii);
                ys = [max([1, col - 2*cdiam]), min([nx, col + 2*cdiam])];
                xs = [max([1, line - 2*cdiam]), min([ny, line + 2*cdiam])];
                patch = frame(xs(1):xs(2), ys(1):ys(2));

                % try to detect few cells
                cellpos = celldetect_donut(patch, obj.dmodel, 0, cdiam);
                rois = cellsegment(patch, cellpos, obj.smodel, cdiam);

                % stop as soon as some cells were detected
                if ~isempty(rois)
                    break;
                end
            end

            % stop if no cell detected
            if isempty(rois)
                return;
            end

            % mask to avoid overlap with existing cells
            if isempty(obj.rois_model.rframe)
                mask = true(nx, ny);
            else
                mask = obj.rois_model.rframe == 0;
            end

            % insert result back in current ROIs frame format
            nrois = numel(rois);
            valid_rois = true(1, nrois);
            for ii=1:nrois
                % expand ROI footprint
                footprint = false(nx, ny);
                footprint(xs(1):xs(2), ys(1):ys(2)) = rois(ii).footprint;

                % remove overlapping parts and update mask
                footprint = footprint & mask;
                valid_rois = nnz(footprint) > 0;

                rois(ii).footprint = sparse(footprint);
            end

            % remove ROIs with empty footprints
            rois(~valid_rois) = [];

            % replicate new ROI over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
            end

            % adapt zplane/channel information
            [rois.zplane] = deal(obj.rois_model.iframe(2));
            [rois.channel] = deal(obj.rois_model.iframe(3));

            % add ROIs to the model
            if ~isempty(rois)
                obj.rois_model.update_frame(rois, []);
            end
        end

    end

end

function pick_model(field)
    % pick a model file and update corresponding field

    % pick a .mat file
    [filename, dirname] = uigetfile('*.mat');

    % stop if no file picked
    if ~filename
        return;
    end

    % update field
    field.String = fullfile(dirname, filename);
    field.Callback();
end

function model = load_model(field)
    % load a model from a .mat file, given in an edit field

    modelfile = [];
    filename = field.String;
    if exist(filename, 'file')
        modelfile = load(filename, '-mat', 'model');
    end

    % load model if part of the file
    if isfield(modelfile, 'model')
        model = modelfile.model;
    else
        field.String = 'not a model file';
        model = [];
    end
end