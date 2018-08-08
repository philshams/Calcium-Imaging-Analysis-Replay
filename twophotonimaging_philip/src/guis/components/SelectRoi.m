classdef SelectRoi < handle

    properties (SetAccess = private)
        % View related properties
        edit_roi      % field to display/set select ROI
        bt_new        % button to generate new ROI id
        bt_select     % button to enable selection with mouse
        bt_unselect   % button to unselect ROIs
        cb_replicate  % checkbox to trigger replication over stacks
        img_axis      % axis where images are displayed
        himage        % handle of image display
 
        % Model related properties
        rois_model    % input feeder for rois

        % ID of callback dealing with mouse clicks
        id_cb
    end

    methods

        function obj = SelectRoi(rois_model, img_fig, fig)
            obj.rois_model = rois_model;

            % load the view
            obj.edit_roi = findobj(fig, 'tag', 'editRoiID');
            obj.bt_new = findobj(fig, 'tag', 'btNewID');
            obj.bt_select = findobj(fig, 'tag', 'btSelectID');
            obj.bt_unselect = findobj(fig, 'tag', 'btUnselectID');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');
            obj.img_axis = imgca(img_fig);
            obj.himage = imhandles(obj.img_axis);

            % initialize the view
            obj.update_view();

            % listener to update display when ROIs are (de-)selected
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);

            % callbacks to update the model on view updates
            obj.edit_roi.Callback = @obj.update_edit_roi;
            obj.bt_new.Callback = @obj.update_new_roi;
            obj.bt_unselect.Callback = @(~, ~) obj.rois_model.select_roi([]);
            obj.bt_select.Callback = @obj.update_select;
        end

        function update_view(obj, varargin)
            nsel = numel(obj.rois_model.selected);

            % disable unselect if no selection
            if nsel <= 0 
                obj.bt_unselect.Enable = 'off';
            else
                obj.bt_unselect.Enable = 'on';
            end

            % update current selection text
            if nsel <= 1
                obj.edit_roi.Enable = 'on';
                obj.edit_roi.String = obj.rois_model.selected;

            else
                obj.edit_roi.String = '-';
                obj.edit_roi.Enable = 'off';
            end
        end

        function update_edit_roi(obj, varargin)
            % add a new selection
            obj.rois_model.select_roi(obj.edit_roi.String);
        end

        function update_new_roi(obj, varargin)
            % create a new (empty) ROI and select it

            % new ROI in current channel and zplane
            [nx, ny, ~] = size(obj.himage.CData);
            iframe = obj.rois_model.iframe;

            roi = struct('footprint', sparse(zeros(nx, ny)), ...
                         'channel', iframe(3), 'zplane', iframe(2));

            % replicate new ROI over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                roi = repmat(roi, nstacks, 1);
            end

            % append ROI and select it
            roi_idx = obj.rois_model.update_frame(roi, []);
            obj.rois_model.select_roi(roi_idx);
        end

        function update_select(obj, varargin)
            % add callback to image, to click on ROI to select
            if obj.bt_select.Value
                obj.id_cb = iptaddcallback( ...
                    obj.himage, 'ButtonDownFcn', @obj.select_pixel);

            % remove clicking callback
            else
                iptremovecallback( ...
                    obj.himage, 'ButtonDownFcn', obj.id_cb);
                obj.id_cb = [];
            end
        end

        function select_pixel(obj, varargin)
            % last clicked pixel coordinates
            pixel = obj.img_axis.CurrentPoint;
            col = round(pixel(1, 1));
            line = round(pixel(1, 2));

            % get selected ROI
            roi_idx = obj.rois_model.rframe(line, col);

            % don't update selected ROI if background or overlap
            if roi_idx <= 0
                return;
            end

            % unselect ROI if already selected, otherwise select it
            if ismember(roi_idx, obj.rois_model.selected)
                obj.rois_model.unselect_roi(roi_idx);
            else
                % type of click on current figure (w/ or wo/ CTRL pressed)
                fig = gcbf;
                appendroi = strcmp(fig.SelectionType, 'alt');

                obj.rois_model.select_roi(roi_idx, appendroi);
            end
        end

    end

end
