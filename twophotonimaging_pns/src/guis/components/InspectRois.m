classdef InspectRois < handle

     properties (SetAccess = private)
        % View related properties
        slider_roi      % slider to scroll through ROIs
        panel_roi       % panel to display ROI footprint and traces
        text_roi        % text to display ROI name and annotations
        edit_bbox       % field to set bounding box around ROI

        % Model related properties
        stacks_model    % object managing input images
        rois_model      % object managing ROIs
     end

     methods

        function obj = InspectRois(stacks_model, rois_model, fig)
            obj.stacks_model = stacks_model;
            obj.rois_model = rois_model;

            % load the view
            obj.slider_roi = findobj(fig, 'tag', 'roiSlider');
            obj.panel_roi = findobj(fig, 'tag', 'panelRoi');
            obj.text_roi = findobj(fig,'tag','textROI');
            obj.edit_bbox = findobj(fig, 'tag', 'editBbox');

            % initialize view
            obj.update_view()

            % listeners to update view on model or view changes
            addlistener(obj.stacks_model, 'frame', 'PostSet', @obj.update_view);
            addlistener(obj.rois_model, 'rframe', 'PostSet', @obj.update_view);
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);

            % callback for options
            obj.edit_bbox.Callback = @obj.update_view;

            % listerner for slider to update selection
            addlistener(obj.slider_roi, 'Value', 'PostSet', @obj.select_roi);
        end

        function select_roi(obj, varargin)
            % select one ROI shown

            % unselect ROIs if slider value is 0
            shown_idx = round(obj.slider_roi.Value);
            if shown_idx == 0
                obj.rois_model.select_roi([]);
            else
                roi_idx = obj.rois_model.shown(shown_idx);
                obj.rois_model.select_roi(roi_idx);
            end
        end

        function update_view(obj, varargin)
            % clear ROI display
            delete(obj.panel_roi.Children);

            % disable slider if no ROIs, else adjust limits
            if isempty(obj.rois_model.shown)
                obj.slider_roi.Value = 0;
                obj.slider_roi.Max = 1;
                obj.slider_roi.SliderStep = [0.01, 0.1];
                obj.slider_roi.Enable = 'off';
            else
                nrois = numel(obj.rois_model.shown);
                obj.slider_roi.Max = nrois;
                obj.slider_roi.SliderStep = [1 / nrois, 2 / nrois];
                obj.slider_roi.Enable = 'on';
            end

            % stop if no selection
            if isempty(obj.rois_model.selected)
                obj.slider_roi.Value = 0;
                obj.text_roi.String = 'No selected ROI';
                return;
            end

            % retrieve first selected ROI
            rois = obj.rois_model.current_rois();
            roi_idx = obj.rois_model.selected(1);
            roi = rois(obj.rois_model.iframe(1), roi_idx);

            % update slider value
            obj.slider_roi.Value = find(obj.rois_model.shown == roi_idx);

            % retrieve and clean bounding box parameter
            bbox = max(1, round(str2double(obj.edit_bbox.String)));
            obj.edit_bbox.String = bbox;

            % update ROI display
            roishow(roi, obj.stacks_model.frame, bbox, obj.panel_roi);

            % update ROI text
            roi_txt = sprintf('ROI %d', roi_idx);
            if isfield(roi, 'annotations') && ~isempty(roi.annotations)
                annotations = cellstr(roi.annotations);
                annotations_txt = strjoin(annotations, '; ');
                roi_txt = sprintf('%s (%s)', roi_txt, annotations_txt);
            end
            obj.text_roi.String = roi_txt;
        end

     end

end