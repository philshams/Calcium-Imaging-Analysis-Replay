classdef EditRoi < handle

    properties (SetAccess = private)
        % View related properties
        bt_split_roi  % button to trigger ROI splitting
        bt_merge_roi  % button to trigger ROI merging
        bt_fill_roi   % button to trigger ROI filling
        bt_separate   % button to trigger ROI separation
        cb_replicate  % checkbox to trigger replication over stacks

        % Model related properties
        rois_model    % input feeder for rois
    end

    methods

        function obj = EditRoi(rois_model, fig)
            obj.rois_model = rois_model;

            % load the view
            obj.bt_split_roi = findobj(fig, 'tag', 'btSplitRoi');
            obj.bt_merge_roi = findobj(fig, 'tag', 'btMergeRoi');
            obj.bt_fill_roi = findobj(fig, 'tag', 'btFillRoi');
            obj.bt_separate = findobj(fig, 'tag', 'btSeparate');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');

            % callbacks to update the model on view updates
            obj.bt_split_roi.Callback = @obj.split_roi;
            obj.bt_merge_roi.Callback = @obj.merge_roi;
            obj.bt_fill_roi.Callback = @obj.fill_roi;
            obj.bt_separate.Callback = @obj.separate_roi;
        end

        function [rois, rois_idx] = get_current_rois(obj)
            % helper method to retrieve current selected ROIs, or all displayed
            if isempty(obj.rois_model.selected)
                rois_idx = obj.rois_model.shown;
            else
                rois_idx = obj.rois_model.selected;
            end
            rois = obj.rois_model.current_rois();
            rois = rois(obj.rois_model.iframe(1), rois_idx);
        end

        function split_roi(obj, varargin)
            % split disconnected components of each selected ROI

            % retrieve all or selected ROIs
            [rois, rois_idx] = obj.get_current_rois();

            new_rois = struct('footprint', {});
            rois_deleted = false(size(rois));
            for ii=1:numel(rois)
                % split ROI footprint
                cc = bwconncomp(full(rois(ii).footprint) ~= 0);

                % if several components found, create new ROIs
                if cc.NumObjects > 1
                    for jj=1:cc.NumObjects
                        footprint = false(size(rois(ii).footprint));
                        footprint(cc.PixelIdxList{jj}) = true;
                        new_rois(end+1).footprint = sparse(footprint); %#ok<AGROW>
                    end
                    rois_deleted(ii) = true;
                end
            end

            % stop if no new ROIs
            if isempty(new_rois)
                return;
            end

            % adapt zplane/channel information
            [new_rois.zplane] = deal(obj.rois_model.iframe(2));
            [new_rois.channel] = deal(obj.rois_model.iframe(3));

            % replicate ROIs over stacks if necessary
            old_rois = [];
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                new_rois = repmat(new_rois, nstacks, 1);
                old_rois = zeros(nstacks, 0);
            end

            % add new ROIs for each disconnected components
            obj.rois_model.update_frame(new_rois, []);

            % remove old ROIs, updating in-place
            obj.rois_model.update_frame(old_rois, rois_idx(rois_deleted), true);
        end

        function merge_roi(obj, varargin)
            % merge selected ROIs

            % retrieve all or selected ROIs
            [rois, rois_idx] = obj.get_current_rois();

            % merge footprints in the first selected ROI footprint
            footprint = rois(1).footprint ~= 0;
            for ii=2:numel(rois)
                footprint = footprint | (rois(ii).footprint ~= 0) ;
            end
            rois(1).footprint = sparse(footprint);
            [rois(2:end).footprint] = deal([]);

            % reset activity time serie
            if isfield(rois, 'activity')
                [rois.activity] = deal([]);
            end

            % replicate ROIs over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
            end

            % update merged ROI
            obj.rois_model.update_frame(rois, rois_idx);
        end

        function fill_roi(obj, varargin)
            % fill holes in selected ROIs

            % retrieve all or selected ROIs
            [rois, rois_idx] = obj.get_current_rois();

            % fill holes in each ROI
            for ii=1:numel(rois)
                footprint = full(rois(ii).footprint) ~= 0;

                % bounding box of the ROI
                [xs, ys] = find(footprint);
                px = min(xs):max(xs);
                py = min(ys):max(ys);

                % filling holes in the bounding box
                filled_bbox = imfill(footprint(px, py), 'holes');
                footprint(px, py) = filled_bbox;
                rois(ii).footprint = sparse(footprint);
            end

            % reset activity time serie
            if isfield(rois, 'activity')
                [rois.activity] = deal([]);
            end

            % replicate ROIs over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
            end

            % update ROIs
            obj.rois_model.update_frame(rois, rois_idx);
        end

        function separate_roi(obj, varargin)
            % separate overlapping ROIs

            % retrieve all or selected ROIs
            [rois, rois_idx] = obj.get_current_rois();

            % separate footprints
            rois = roisseparate(rois);

            % reset activity time serie
            if isfield(rois, 'activity')
                [rois.activity] = deal([]);
            end

            % replicate ROIs over stacks if necessary
            if obj.cb_replicate.Value
                nstacks = size(obj.rois_model.current_rois(), 1);
                rois = repmat(rois, nstacks, 1);
            end

            % update ROIs
            obj.rois_model.update_frame(rois, rois_idx);
        end
    end

end
