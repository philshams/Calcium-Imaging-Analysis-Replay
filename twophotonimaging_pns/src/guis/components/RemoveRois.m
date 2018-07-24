classdef RemoveRois < handle

    properties (SetAccess = private)
        % View related properties
        edit_filter       % field to set filter size
        bt_delete_small   % button to remove small ROIs
        edit_border       % field to set border size
        bt_delete_border  % button to remove ROIs close to borders
        bt_delete_roi     % button to delete selected ROI
        cb_replicate  % checkbox to trigger replication over stacks

        % Model related properties
        rois_model        % input feeder for rois
    end

    methods

        function obj = RemoveRois(rois_model, fig)
            obj.rois_model = rois_model;

            % load the view
            obj.edit_filter = findobj(fig, 'tag', 'editFilter');
            obj.bt_delete_small = findobj(fig, 'tag', 'btDeleteSmall');
            obj.edit_border = findobj(fig, 'tag', 'editBorder');
            obj.bt_delete_border = findobj(fig, 'tag', 'btDeleteBorder');
            obj.bt_delete_roi = findobj(fig, 'tag', 'btDeleteRoi');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');

            % initialize the view
            obj.update_view();

            % listener to update display when ROIs are (de-)selected
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);

            % callbacks to update the model on view updates
            obj.edit_filter.Callback = @obj.delete_small;
            obj.bt_delete_small.Callback = @obj.delete_small;
            obj.edit_border.Callback = @obj.delete_border;
            obj.bt_delete_border.Callback = @obj.delete_border;
            obj.bt_delete_roi.Callback = @obj.delete_rois;
        end

        function update_view(obj, varargin)
            % disable delete roi if no selection
            if isempty(obj.rois_model.selected)
                obj.bt_delete_roi.Enable = 'off';
            else
                obj.bt_delete_roi.Enable = 'on';
            end
        end

        function delete_rois(obj, varargin)
            % replicate over stacks if necessary
            del_rois = [];
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                del_rois = zeros(nstacks, 0);
            end

            % remove selected rois
            obj.rois_model.update_frame(del_rois, obj.rois_model.selected);
        end

        function delete_small(obj, varargin)
            % cleanup filter value
            filt_str = obj.edit_filter.String;
            filt_size = max(1, round(str2double(filt_str)));
            obj.edit_filter.String = filt_size;

            % retrieve displayed ROIs
            rois_idx = obj.rois_model.shown;
            rois = obj.rois_model.current_rois();
            rois = rois(obj.rois_model.iframe(1), rois_idx);

            % find ROIs smaller than filt_size (and stop if none)
            del_rois_idx = rois_idx( ...
                cellfun(@(f) nnz(f ~= 0) <= filt_size, {rois.footprint}));

            if isempty(del_rois_idx)
                return;
            end

            % replicate over stacks if necessary
            del_rois = [];
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                del_rois = zeros(nstacks, 0);
            end

            % remove found ROIs
            obj.rois_model.update_frame(del_rois, del_rois_idx);
        end

        function delete_border(obj, varargin)
            % cleanup filter value
            border_str = obj.edit_border.String;
            border_size = max(1, round(str2double(border_str)));
            obj.edit_border.String = border_size;

            % delete everything if current image is smaller than borders
            if border_size >= min(size(obj.rois_model.rframe))
                del_rois_idx = obj.rois_model.rframe(:);

            % otherwise find ROIs located in at the borders
            else
                left_rois = obj.rois_model.rframe(:, 1:border_size);
                right_rois = obj.rois_model.rframe(:, end-border_size:end);
                top_rois = obj.rois_model.rframe(1:border_size, :);
                bottom_rois = obj.rois_model.rframe(end-border_size:end, :);
                del_rois_idx = [left_rois(:); right_rois(:); ...
                                top_rois(:); bottom_rois(:)];
            end

            del_rois_idx = unique(del_rois_idx);
            del_rois_idx = del_rois_idx(del_rois_idx > 0);

            if isempty(del_rois_idx)
                return;
            end

            % replicate over stacks if necessary
            del_rois = [];
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                del_rois = zeros(nstacks, 0);
            end

            % remove found ROIs
            obj.rois_model.update_frame(del_rois, del_rois_idx);
        end
    end

end
