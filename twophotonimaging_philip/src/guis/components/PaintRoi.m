classdef PaintRoi < handle

    properties (SetAccess = private)
        % View related properties
        edit_brush    % field to set brush size
        bt_paint      % button to toggle painting
        cb_replicate  % checkbox to trigger replication over stacks
        img_fig       % figure where images are displayed
        img_axis      % axis where images are displayed

        % Model related properties
        rois_model    % input feeder for rois

        % ID of callbacks added to the figure (to remove them)
        id_down       % WindowButtonDownFcn callback
        id_motion     % WindowButtonMotionFcn callback
        id_up         % WindowButtonUpFcn callback

        brush         % brush mask
        brush_idx     % brush mask (x, y) indices, centred on (0, 0)

        first_click   % boolean to keep track of first painting click
    end

    methods

        function obj = PaintRoi(rois_model, img_fig, fig)
            obj.rois_model = rois_model;

            obj.id_up = [];
            obj.id_down = [];
            obj.id_motion = [];

            obj.first_click = true;

            % load the view
            obj.edit_brush = findobj(fig, 'tag', 'editBrush');
            obj.bt_paint = findobj(fig, 'tag', 'btPaint');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');
            obj.img_fig = img_fig;
            obj.img_axis = imgca(img_fig);

            % initialize the view
            obj.update_view();

            % initialize brush
            obj.brush = [];
            obj.brush_idx = [];
            obj.update_brush();

            % listeners to update display when ROIs are (de-)selected
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);

            % listeners/callbacks to update the model on view updates
            obj.edit_brush.Callback = @obj.update_brush;
            obj.bt_paint.Callback = @obj.update_mouse_callbacks;
        end

        function update_view(obj, varargin)
            % enable painting if only one selection
            if numel(obj.rois_model.selected) == 1
                obj.bt_paint.Enable = 'on';
            else
                obj.bt_paint.Enable = 'off';
                obj.bt_paint.Value = false;
                obj.update_mouse_callbacks();
            end
        end

        function update_brush(obj, varargin)
            % cleanup filter value
            brush_str = obj.edit_brush.String;
            brush_size = max(0, round(str2double(brush_str)));
            obj.edit_brush.String = brush_size;

            % update brush matrix
            obj.brush = strel('disk', brush_size, 0).getnhood();
            [ncol, nlines] = size(obj.brush);
            obj.brush_idx = ...
                [(1:nlines) - round(nlines/2); (1:ncol) - round(ncol/2)];
        end

        function update_mouse_callbacks(obj, varargin)
            % install mouse click callbacks on figure
            if obj.bt_paint.Value
                obj.id_down = iptaddcallback( ...
                    obj.img_fig, 'WindowButtonDownFcn', @obj.mouse_click_cb);

            % uninstall mouse click callbacks on figure
            else
                iptremovecallback( ...
                    obj.img_fig, 'WindowButtonDownFcn', obj.id_down);
                obj.id_down = [];

                obj.reset_window_callbacks();
            end
        end

        function mouse_click_cb(obj, src, ~)
            % install callback for drawing with mouse
            if isempty(obj.id_motion)
                obj.id_motion = iptaddcallback( ...
                    obj.img_fig, 'WindowButtonMotionFcn', @obj.paint_roi);
            end

            % install callback to stop drawing when key is released
            if isempty(obj.id_up)
                obj.id_up = iptaddcallback( ...
                    obj.img_fig, 'WindowButtonUpFcn', ...
                    @obj.reset_window_callbacks);
            end

            % paint clicked pixel
            obj.paint_roi(src);
        end

        function reset_window_callbacks(obj, varargin)
            % uninstall painting callback
            iptremovecallback( ...
                obj.img_fig, 'WindowButtonMotionFcn', obj.id_motion);
            obj.id_motion = [];

            % uninstall key released callback
            iptremovecallback( ...
                obj.img_fig, 'WindowButtonUpFcn', obj.id_up);
            obj.id_up = [];

            % reset first click flag
            obj.first_click = true;
        end

        function paint_roi(obj, src, ~)
            % last clicked pixel coordinates
            pixel = obj.img_axis.CurrentPoint;
            col = round(pixel(1, 1));
            line = round(pixel(1, 2));

            % indices to insert brush mask
            i = obj.brush_idx(1, :) + line;
            j = obj.brush_idx(2, :) + col;

            % interrupt if outside of image
            [n, m] = size(obj.rois_model.rframe);
            if any(i <= 0 | i > n) || any(j <= 0 | j > m)
                return;
            end

            % retrieve selected ROI
            roi_idx = obj.rois_model.selected(1);
            rois = obj.rois_model.current_rois();
            roi = rois(obj.rois_model.iframe(1), roi_idx);

            % modified ROI mask (removal if CTRL pressed)
            footprint = full(roi.footprint) ~= 0;
            if exist('src', 'var') && strcmp(src.SelectionType, 'alt')
                footprint(i, j) = footprint(i, j) & ~obj.brush;
            else
                footprint(i, j) = footprint(i, j) | obj.brush;
            end
            roi.footprint = sparse(footprint);

            % reset activity time serie
            if isfield(roi, 'activity')
                roi.activity = [];
            end

            % replicate new ROI over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                roi = repmat(roi, nstacks, 1);
            end

            % update in-place except for the first click
            obj.rois_model.update_frame(roi, roi_idx, ~obj.first_click);
            obj.first_click = false;
        end
    end

end
