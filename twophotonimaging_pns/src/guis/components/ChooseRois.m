classdef ChooseRois < handle

     properties (SetAccess = private)
        % View related properties
        slider_roi      % slider to scroll through ROIs
        panel_roi       % panel to display ROI footprint and traces
        text_roi        % text to display ROI name and annotations
        bt_export       % button to replace selected ROI

        % Model related properties
        stacks_model    % object managing input images
        rois_model      % object managing ROIs

        new_rois        % new ROIs/refined ROIs
        rois_xys        % (x,y) indices used to compute new_rois

        handles         % handles that need to be deleted with this object
     end

     methods

        function obj = ChooseRois(stacks_model, rois_model, new_rois, rois_xys, fig)
            obj.stacks_model = stacks_model;
            obj.rois_model = rois_model;

            obj.new_rois = new_rois;
            obj.rois_xys = rois_xys;

            % load the view
            obj.slider_roi = findobj(fig, 'tag', 'roiSlider');
            obj.panel_roi = findobj(fig, 'tag', 'panelRoi');
            obj.text_roi = findobj(fig,'tag','textROI');
            obj.bt_export = findobj(fig, 'tag', 'pbExportCell');

            % set sliders limits to the number of ROIs
            nrois = size(obj.new_rois, 2);
            if nrois > 1
                obj.slider_roi.Max = nrois;
                obj.slider_roi.SliderStep = [1 / nrois, 2 / nrois];
            elseif nrois == 1
                obj.slider_roi.Enable = 'off';
            else
                error('ChooseRois component called with no ROIs to display.')
            end

            % initialize view
            obj.update_view()

            % listeners to update view on model or view changes
            obj.handles{1} = addlistener( ...
                obj.slider_roi, 'Value', 'PostSet', @obj.update_view);
            obj.handles{2} = addlistener( ...
                obj.stacks_model, 'frame', 'PostSet', @obj.update_view);

            % set button callback
            obj.bt_export.Callback = @obj.export_roi;
        end

        function delete(obj)
            % destructor to remove listeners
            delete([obj.handles{:}]);
        end

        function update_view(obj, varargin)
            % retrieve selected ROI
            istack = obj.stacks_model.istack;
            roi_idx = round(obj.slider_roi.Value);
            roi = obj.new_rois(istack, roi_idx);

            % update ROI display
            delete(obj.panel_roi.Children);
            if ~isempty(roi.footprint)
                frame = obj.stacks_model.frame(obj.rois_xys{:});
                roishow(roi, frame, [], obj.panel_roi);
            end

            % update ROI text
            roi_txt = sprintf('ROI candidate %d', roi_idx);
            if isfield(roi, 'annotations') && ~isempty(roi.annotations)
                annotations = cellstr(roi.annotations);
                annotations_txt = strjoin(annotations, '; ');
                roi_txt = sprintf('%s (%s)', roi_txt, annotations_txt);
            end
            obj.text_roi.String = roi_txt;

            % TODO deal with replicated ROIs
            % disable replace button if (any) empty ROI
            if any(cellfun(@isempty, {obj.new_rois(:, roi_idx).footprint}))
                obj.bt_export.Enable = 'off';
            else
                obj.bt_export.Enable = 'on';
            end
        end

        function export_roi(obj, varargin)
            % replace ROI in RoisModel

            % get original ROI footprint informations
            roi_idx = obj.rois_model.selected(1);
            rois = obj.rois_model.current_rois();
            footprint_size = size(rois(1, roi_idx).footprint);

            roi_to_export = round(obj.slider_roi.Value);
            exported_rois = obj.new_rois(:, roi_to_export);

            % resize footprints
            for ii=1:numel(exported_rois)
                footprint = zeros(footprint_size);
                footprint(obj.rois_xys{:}) = exported_rois(ii).footprint;
                exported_rois(ii).footprint = sparse(footprint);
            end

            % TODO deal with replicated ROIs
            obj.rois_model.update_frame(exported_rois, roi_idx);
        end
     end

end