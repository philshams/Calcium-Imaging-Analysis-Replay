classdef DisplayRois < handle

    properties (SetAccess = private)
        % View related properties
        slider_alpha   % slider to control transparency
        cb_color       % checkbox to switch between color settings
        cb_mergechans  % checkbox to display ROIs from all channels

        % Model related properties
        stacks_model   % input feeder for frames
        rois_model     % input feeder for rois
    end

    properties (SetAccess = private, SetObservable = true)
        frame          % output for merged frames
    end

    methods

        function obj = DisplayRois(stacks_model, rois_model, fig)
            obj.stacks_model = stacks_model;
            obj.rois_model = rois_model;

            % load the view
            obj.slider_alpha = findobj(fig, 'tag', 'sliderAlpha');
            obj.cb_color = findobj(fig, 'tag', 'cbColor');
            obj.cb_mergechans = findobj(fig, 'tag', 'cbMergeChans');

            % initialize the merged frame
            obj.update_frame();

            % listener/callbacks to update the merged image on view update
            addlistener(obj.slider_alpha, 'Value', 'PostSet', ...
                        @obj.update_frame);
            obj.cb_color.Callback = @obj.update_frame;
            obj.cb_mergechans.Callback = @obj.merge_channels;

            % listeners to update the merged image on models update
            addlistener( ...
                obj.stacks_model, 'frame', 'PostSet', @obj.update_frame);
            addlistener( ...
                obj.rois_model, 'rframe', 'PostSet', @obj.update_frame);
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_frame);

            % listener to update view on model update
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);
        end

        function update_view(obj, varargin)
            % disable coloring if there are selected ROIs
            if ~isempty(obj.rois_model.selected)
                obj.cb_color.Enable = 'off';
            else
                obj.cb_color.Enable = 'on';
            end
        end

        function update_frame(obj, varargin)
            % retrieve merged footprints
            rframe = obj.rois_model.rframe;
            rois_idx = unique([rframe(:); obj.rois_model.selected(:)]);
            nrois = sum(rois_idx > 0);

            % shortcut if there is no ROIs visible
            if isempty(rframe) || (nrois == 0 && ~ismember(-1, rois_idx))
                obj.frame = obj.stacks_model.frame;
                return;
            end

            % remap ROIs indices to consecutive ones
            lut = zeros(1, max(rois_idx));
            lut(rois_idx(rois_idx > 0)) = 1:nrois;
            rframe(rframe > 0) = lut(rframe(rframe > 0));

            % select color for ROIs
            selected = obj.rois_model.selected;
            if obj.cb_color.Value && isempty(selected)
                cmap = lines(nrois);
            else
                cmap = selected_cmap(nrois, lut(selected));
            end

            % add red color for overlaps (negative values)
            if any(rois_idx < 0)
                rframe(rframe < 0) = nrois + 1;
                cmap(end + 1, :) = [1, 0, 0];
            end

            % merge stack image and ROIs mask
            alpha = obj.slider_alpha.Value;
            img = mergemask(obj.stacks_model.frame, rframe, alpha, cmap);

            % update displayed image
            obj.frame = img;
        end

        function merge_channels(obj, varargin)
            % set ROIs model channel merging option
            obj.rois_model.merge_channels(obj.cb_mergechans.Value);
        end
    end

end

function cmap = selected_cmap(nrois, selected_rois)
    % blue-ish color for unselected ROIs
    blue = [0.0241, 0.6595, 0.7680];
    cmap = repmat(blue, nrois, 1);

    % yellow-ish color for selected ROIs
    if ~isempty(selected_rois)
        yellow = [0.8937, 0.7267, 0.3164];
        cmap(selected_rois, :) = repmat(yellow, numel(selected_rois), 1);
    end
end
