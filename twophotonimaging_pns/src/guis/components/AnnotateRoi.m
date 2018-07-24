classdef AnnotateRoi < handle

    properties (SetAccess = private)
        % View related properties
        edit_annotation  % field to display/edit annotation
        cb_replicate     % checkbox to trigger replication over stacks
        pb_find          % button to find ROIs by annotation
        pb_apply         % button to change annotation
        pb_add           % button to append annotation

        % Model related properties
        stacks_model     % model to manipulate stacks of images
        rois_model       % model to get/set ROIs

        % last ROI selected by search
        find_roi_id
    end

    methods

        function obj = AnnotateRoi(stacks_model, rois_model, fig)
            obj.stacks_model = stacks_model;
            obj.rois_model = rois_model;
            obj.find_roi_id = 0;

            % load the view
            obj.edit_annotation = findobj(fig, 'tag', 'editAnnotation');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');
            obj.pb_apply = findobj(fig, 'tag', 'pbApply');
            obj.pb_find = findobj(fig, 'tag', 'pbFind');
            obj.pb_add = findobj(fig, 'tag', 'pbAdd');

            % initialize the view
            obj.update_view();

            % buttons callbacks
            obj.pb_apply.Callback = @(~, ~) obj.apply_annotation(true);
            obj.pb_add.Callback = @(~, ~) obj.apply_annotation(false);
            obj.pb_find.Callback = @obj.find_roi;

            % update view (textbox and buttons state) on model changes
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);
            addlistener( ...
                obj.rois_model, 'iframe', 'PostSet', @obj.update_view);

            % clear find_roi_id when annotation text changes
            addlistener(obj.edit_annotation, 'String', 'PostSet', ...
                        @obj.reset_find_roi_id);
        end

        function update_view(obj, varargin)
            % update the view (textbox and buttons) state

            % disable annotation buttons if no selected ROI
            if isempty(obj.rois_model.selected)
                obj.pb_apply.Enable = 'off';
                obj.pb_add.Enable = 'off';

            % otherwise enable annotation buttons
            else
                obj.pb_apply.Enable = 'on';
                obj.pb_add.Enable = 'on';

                % replace text, if empty, with ROI annotation
                if isempty(obj.edit_annotation.String)
                    % retrieve selected ROIs
                    rois_idx = obj.rois_model.selected;
                    rois = obj.rois_model.current_rois();
                    rois = rois(obj.rois_model.iframe(1), rois_idx);

                    % find first non-empty annotation and display it
                    obj.edit_annotation.String = first_annotation(rois);
                end
            end
        end

        function reset_find_roi_id(obj, varargin)
            % reset last selected ROI index
            obj.find_roi_id = 0;
        end

        function find_roi(obj, varargin)
            % find ROIs with corresponding annotation and cycle through them

            rois = obj.rois_model.current_rois();

            % shortcut if no annotation field
            if ~isfield(rois, 'annotations')
                return;
            end

            % rois with annotations
            valid = reshape(~cellfun(@isempty, {rois.annotations}), size(rois));
            valid(valid) = ~cellfun(@isempty, {rois(valid).footprint});
            [rois_istack, rois_idx] = find(valid);

            % if cb_replicate, only search current stack
            if obj.cb_replicate.Value
                istack = obj.rois_model.iframe(1);
                rois_idx = rois_idx(rois_istack == istack);
                rois_istack = rois_istack(rois_istack == istack);
            end

            % indices of annotated ROIs that match search string
            annotations = ...
                {rois(sub2ind(size(rois), rois_istack, rois_idx)).annotations};
            matching_fcn = @(x) any(strcmp(x, obj.edit_annotation.String));
            matching = find(cellfun(matching_fcn, annotations));

            % select next maching ROI, if any
            if ~isempty(matching)

                % next available index, returning to first one if at the end
                obj.find_roi_id = mod(obj.find_roi_id, numel(matching)) + 1;
                matched = matching(obj.find_roi_id);

                % matched ROI and its stack index
                roi_idx = rois_idx(matched);
                roi_istack = rois_istack(matched);
                roi = rois(roi_istack, roi_idx);

                % change current stack if necessary
                if roi_istack ~= obj.stacks_model.istack
                    obj.stacks_model.select_stack(roi_istack);
                end

                % change zslice and channel if necessary
                iframe = obj.stacks_model.iframe;
                if roi.zplane ~= iframe(1) || roi.channel ~= iframe(2)
                    iframe(1:2) = [roi.zplane, roi.channel];
                    obj.stacks_model.select_frame(iframe);
                end

                % select roi
                obj.rois_model.select_roi(roi_idx);

            end
        end

        function apply_annotation(obj, replace_txt)
            % append an annotation to existing ones

            % get all currently selected rois
            rois_idx = obj.rois_model.selected;
            rois = obj.rois_model.current_rois();

            % if replicate is on, get rois from all stacks
            if obj.cb_replicate.Value
                selected_rois = rois(:, rois_idx);

            % otherwise, current stack only
            else
                selected_rois = rois(obj.rois_model.iframe(1), rois_idx);
            end

            % replace ROIs annotations
            if replace_txt || ~isfield(selected_rois, 'annotations')
                [selected_rois.annotations] = deal(obj.edit_annotation.String);

            % or add a new one
            elseif ~isempty(obj.edit_annotation.String)
                for ii = 1:numel(selected_rois)
                    selected_rois(ii) = append_annotation( ...
                        selected_rois(ii), obj.edit_annotation.String);
                end
            end

            obj.rois_model.update_frame(selected_rois, rois_idx);
        end

    end

end

function txt = first_annotation(rois)
    % returns first non-empty annotation of ROIs, if any, or an empty string

    % early return if no annotations field in ROIs
    if ~isfield(rois, 'annotations')
        txt = '';
        return;
    end

    annotations = {rois.annotations};
    valid = ~cellfun(@isempty, annotations);

    if any(valid)
        first_valid = cellstr(annotations{find(valid, 1)});
        txt = first_valid{1};
    else
        txt = '';
    end
end

function roi = append_annotation(roi, annotation)
    % add a new annotation to a ROI
    if isempty(roi.annotations)
        roi.annotations = annotation;
    elseif ~any(strcmp(roi.annotations, annotation))
        roi.annotations = [cellstr(roi.annotations), annotation];
    end
end