classdef DisplayRoisText < handle

    properties (SetAccess = private)
        % View related properties
        cb_numbered     % checkbox to toggle numbers display
        cb_annotations  % checkbox to toggle annotations display
        img_axis        % axis where images are displayed
        hlabels         % handles of ROIs text (their number)

        % Model related properties
        rois_model      % input feeder for rois
    end

    methods

        function obj = DisplayRoisText(rois_model, img_fig, fig)
            obj.rois_model = rois_model;

            % load the view
            obj.cb_numbered = findobj(fig, 'tag', 'cbNumbered');
            obj.cb_annotations = findobj(fig, 'tag', 'cbAnnotations');
            obj.img_axis = imgca(img_fig);
            obj.hlabels = {};

            % callback to update numbers display on view update
            obj.cb_numbered.Callback = @obj.update_labels;
            obj.cb_annotations.Callback = @obj.update_labels;

            % listeners to update numbers display on model update
            addlistener( ...
                obj.rois_model, 'shown', 'PostSet', @obj.update_labels);
        end

        function update_labels(obj, varargin)
            % remove previous texts displayed
            cellfun(@delete, obj.hlabels);
            obj.hlabels = {};

            % stop if no ROIs is displayed
            if isempty(obj.rois_model.shown)
                return;
            end

            % retrieve shown ROIs
            rois = obj.rois_model.current_rois();
            rois = rois(obj.rois_model.iframe(1), obj.rois_model.shown);

            % update numbers displayed, if necessary
            if obj.cb_numbered.Value
                obj.cb_annotations.Enable = 'off';

                rois_idx = num2cell(obj.rois_model.shown);
                obj.hlabels = cellfun( ...
                    @(f, i) add_roi_text(f, num2str(i), obj.img_axis), ...
                    {rois.footprint}, rois_idx, 'un', false);

            % update annotations displayed
            elseif obj.cb_annotations.Value
                obj.cb_numbered.Enable = 'off';

                if isfield(rois, 'annotations')
                    labeled_idx = ~cellfun(@isempty, {rois.annotations});
                    obj.hlabels = cellfun( ...
                        @(f, i) add_roi_text(f, i, obj.img_axis), ...
                        {rois(labeled_idx).footprint}, ...
                        {rois(labeled_idx).annotations}, ...
                        'un', false);
                end

            % re-enable checkboxes
            else
                obj.cb_numbered.Enable = 'on';
                obj.cb_annotations.Enable = 'on';
            end
        end

    end

end

function htext = add_roi_text(footprint, roi_label, ax)
    [y, x] = find(footprint ~= 0);
    mean_y = mean(y);
    mean_x = mean(x);
    htext = text(mean_x, mean_y, roi_label, ...
        'FontSize', 10, 'Color', 'w', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'PickableParts', 'none', ...
        'Parent', ax);
end
