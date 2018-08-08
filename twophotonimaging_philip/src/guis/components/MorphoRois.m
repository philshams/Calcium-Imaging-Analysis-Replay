classdef MorphoRois < handle

    properties (SetAccess = private)
        % View related properties
        edit_se       % field to select structuring element size
        bt_erode      % button to erode ROI(s)
        bt_dilate     % button to dilate ROI(s)
        cb_replicate  % checkbox to trigger replication over stacks
 
        % Model related properties
        rois_model    % input feeder for rois
    end

    methods

        function obj = MorphoRois(rois_model, fig)
            obj.rois_model = rois_model;

            % load the view
            obj.edit_se = findobj(fig, 'tag', 'editSE');
            obj.bt_erode = findobj(fig, 'tag', 'btErode');
            obj.bt_dilate = findobj(fig, 'tag', 'btDilate');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');

            % initialize the view
            obj.update_view();

            % listeners to update display when ROIs are (de-)selected
            addlistener( ...
                obj.rois_model, 'selected', 'PostSet', @obj.update_view);

            % callbacks to update the model on view updates
            obj.edit_se.Callback = @obj.cleaned_strel;
            obj.bt_erode.Callback = @obj.erode;
            obj.bt_dilate.Callback = @obj.dilate;
        end

        function update_view(obj, varargin)
            % enable morphological filtering if more than one selection
            if isempty(obj.rois_model.selected)
                obj.bt_erode.Enable = 'off';
                obj.bt_dilate.Enable = 'off';
            else
                obj.bt_erode.Enable = 'on';
                obj.bt_dilate.Enable = 'on';
            end
        end

        function se = cleaned_strel(obj, varargin)
            % cleanup morphological structuring element size
            se_str = obj.edit_se.String;
            se_size = max(1, round(str2double(se_str)));
            obj.edit_se.String = se_size;

            % return structuring element
            se = strel('disk', se_size);
        end

        function erode(obj, varargin)
            % erode each selected ROI

            % retrieve selected ROIs
            rois = obj.rois_model.current_rois();
            rois = rois(obj.rois_model.iframe(1), obj.rois_model.selected);

            % erode each ROI footprint
            se = obj.cleaned_strel();
            for ii=1:numel(rois)
                footprint = sparse(imerode(full(rois(ii).footprint) ~= 0, se));

                % check if ROI disappeared
                if nnz(footprint) > 0
                    rois(ii).footprint = footprint;
                else
                    rois(ii).footprint = [];
                end
            end

            % reset activity time series
            if isfield(rois, 'activity')
                [rois.activity] = deal([]);
            end

            % replicate new ROIs over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
            end

            % update ROIs
            obj.rois_model.update_frame(rois, obj.rois_model.selected);
        end

        function dilate(obj, varargin)
            % dilate each selected ROI

            % retrieve selected ROIs
            rois_idx = obj.rois_model.selected;
            rois = obj.rois_model.current_rois();
            rois = rois(obj.rois_model.iframe(1), rois_idx);

            % dilate each ROI footprint
            se = obj.cleaned_strel();
            for ii=1:numel(rois)
                footprint = imdilate(full(rois(ii).footprint) ~= 0, se);

                % avoid dilated mask to overlap other ROIs
                mask = ismember(obj.rois_model.rframe, [0, rois_idx(ii)]);
                rois(ii).footprint = sparse(footprint & mask);
            end

            % reset activity time series
            if isfield(rois, 'activity')
                [rois.activity] = deal([]);
            end

            % replicate new ROIs over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
            end

            % update ROIs
            obj.rois_model.update_frame(rois, rois_idx);
        end

    end

end