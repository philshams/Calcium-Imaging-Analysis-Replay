classdef RoisModel < handle

    properties (SetAccess = private)
        buffer     % stack of ROIs, as a circular buffer
        ibuffer    % currently selected version
        ioldest    % index of oldest version in the circular buffer

        partial_rframe    % partially merged footprints
        partial_overlaps  % partially merged binarized footprints
    end

    properties (SetAccess = private, SetObservable = true)
        iframe    % index of current frame (stack, z-plane, channel)
        rframe    % merged footprints of ROIs for current frame
        shown     % indices of ROIs in current frame
        selected  % selected ROIs indices

        n_undo    % number of cancelable steps
        n_redo    % number of redo-able steps

        merged_chans  % merging channels option
    end

    methods

        function obj = RoisModel(rois, n_buffer)
            % init circular buffer as a cellarray
            obj.buffer = cell(1, n_buffer);
            obj.buffer{1} = rois;

            obj.ibuffer = 1;
            obj.ioldest = 1;
            obj.n_undo = 0;
            obj.n_redo = 0;

            obj.partial_rframe = [];
            obj.partial_overlaps = [];

            % select first frame
            obj.merged_chans = false;
            obj.iframe = [1, 1, 1];
            obj.select_frame([1, 1, 1]);

            % start with no selection
            obj.selected = [];
        end

        function rois = current_rois(obj)
            % latest version of ROIs
            rois = obj.buffer{obj.ibuffer};
        end

        function select_frame(obj, iframe)
            % update current ROIs

            % get selected set of ROIs
            old_iframe = obj.iframe;
            obj.iframe = round(iframe);

            % trigger unselect if zplane/channel is changed
            same_channel = obj.merged_chans || (old_iframe(3) == obj.iframe(3));
            if old_iframe(2) ~= obj.iframe(2) || ~same_channel
                obj.selected = [];

            % or just remove selected ROIs not existing in new stack
            elseif old_iframe(1) ~= obj.iframe(1)
                rois = obj.buffer{obj.ibuffer}(obj.iframe(1), obj.selected);
                valid = ~cellfun(@isempty, {rois.footprint});

                % only update if there is a change, triggering listeners
                if any(~valid)
                    obj.selected = obj.selected(valid);
                end
            end

            % flush merged footprints caches
            obj.partial_rframe = [];
            obj.partial_overlaps = [];

            % update the current frame
            obj.refresh_frame()
        end

        function merge_channels(obj, merging)
            % set channel merging option

            obj.merged_chans = merging;

            % update the current frame
            obj.refresh_frame()

            % remove selected ROIs not visible
            obj.selected = obj.selected(ismember(obj.selected, obj.shown));
        end

        function refresh_frame(obj)
            % update merged footprints, using cached merged footprints

            % current stack ROIs
            stack_rois = obj.buffer{obj.ibuffer}(obj.iframe(1), :);

            % filter for z-plane and channel and non-empty footprints
            old_shown = obj.shown;  % backup for later comparison

            shown_idx = find(~cellfun(@isempty, {stack_rois.zplane}));
            shown_idx = shown_idx( ...
                [stack_rois(shown_idx).zplane] == obj.iframe(2));

            shown_idx = shown_idx( ...
                ~cellfun(@isempty, {stack_rois(shown_idx).channel}));

            if ~obj.merged_chans
                shown_idx = shown_idx( ...
                    [stack_rois(shown_idx).channel] == obj.iframe(3));
            end

            obj.shown = shown_idx( ...
                ~cellfun(@isempty, {stack_rois(shown_idx).footprint}));

            % empty caches if shown ROIs changed
            if ~isequal(old_shown, obj.shown)
                obj.partial_rframe = [];
                obj.partial_overlaps = [];
            end

            % empty mask if no ROIs in current frame
            if isempty(obj.shown)
                obj.rframe = [];

            % merging footprints otherwise
            else

                % fill merged footprints caches with non-selected ROIs
                if isempty(obj.partial_rframe) || isempty(obj.partial_overlaps)

                    frame_size = size(stack_rois(obj.shown(1)).footprint);
                    obj.partial_rframe = zeros(frame_size);
                    obj.partial_overlaps = zeros(frame_size);

                    non_selected = ...
                        obj.shown(~ismember(obj.shown, obj.selected));
                    for ii=1:numel(non_selected)
                        mask = stack_rois(non_selected(ii)).footprint ~= 0;
                        obj.partial_rframe = ...
                            obj.partial_rframe + mask * non_selected(ii);
                        obj.partial_overlaps = ...
                            obj.partial_overlaps + full(mask);
                    end
                end

                % filter selected ROIs to keep those visible
                visible_sel = obj.selected(ismember(obj.selected, obj.shown));

                % complete partially merged footprints with selected ROIs
                new_rframe = obj.partial_rframe;
                overlaps = obj.partial_overlaps;
                for ii=1:numel(visible_sel)
                    mask = stack_rois(visible_sel(ii)).footprint ~= 0;
                    new_rframe = new_rframe + mask * visible_sel(ii);
                    overlaps = overlaps + full(mask);
                end

                % assign negative ID to overlaps
                new_rframe(overlaps > 1) = -1;

                obj.rframe = new_rframe;
            end
        end

        function select_roi(obj, roi_idx, appendroi)
            % by default, replace all selected ROIs by the one given
            if ~exist('appendroi', 'var')
                appendroi = false;
            end

            % make sure ROI id is valid
            if ischar(roi_idx)
                roi_idx = round(str2double(roi_idx));
            end

            % update if valid ROI index (or empty) and not already selected
            nrois = size(obj.buffer{obj.ibuffer}, 2);
            if ~isempty(roi_idx) && (roi_idx < 1 || roi_idx > nrois ...
                                     || ismember(roi_idx, obj.selected) ...
                                     || ~ismember(roi_idx, obj.shown))
                return;
            end

            % flush merged footprints caches
            obj.partial_rframe = [];
            obj.partial_overlaps = [];

            % append ROI to the list or make it replace the others
            if appendroi
                obj.selected = [obj.selected, roi_idx];
            else
                obj.selected = roi_idx;
            end
        end

        function unselect_roi(obj, roi_idx)
            % make sure ROI id is valid
            if ischar(roi_idx)
                roi_idx = round(str2double(roi_idx));
            end

            % stop if the ROI is not selected
            valid = obj.selected ~= roi_idx;
            if all(valid)
                return;
            end

            % flush merged footprints caches
            obj.partial_rframe = [];
            obj.partial_overlaps = [];

            % remove ROI from the selected ones
            obj.selected = obj.selected(valid);
        end

        function undo(obj)
            % stop if not possible to cancel anything
            if obj.n_undo == 0
                return
            end

            % adjust number of undo/redo steps
            obj.n_undo = obj.n_undo - 1;
            obj.n_redo = obj.n_redo + 1;

            % flush merged footprints caches
            obj.partial_rframe = [];
            obj.partial_overlaps = [];

            % remove any selection
            obj.selected = [];

            % update ROIs version to previous one in the circular buffer
            obj.ibuffer = mod(obj.ibuffer - 2, length(obj.buffer)) + 1;
            obj.refresh_frame();
        end

        function redo(obj)
            % stop if not possible to redo anything
            if obj.n_redo == 0
                return
            end

            % adjust number of undo/redo steps
            obj.n_undo = obj.n_undo + 1;
            obj.n_redo = obj.n_redo - 1;

            % flush merged footprints caches
            obj.partial_rframe = [];
            obj.partial_overlaps = [];

            % remove any selection
            obj.selected = [];

            % update ROIs version to next one in the circular buffer
            obj.ibuffer = mod(obj.ibuffer, length(obj.buffer)) + 1;
            obj.refresh_frame();
        end

        function rois_idx = update_frame(obj, rois, rois_idx, inplace)
            % update ROIs in current stack or in all stacks

            % by default, create a new backup when updating
            if ~exist('inplace', 'var')
                inplace = false;
            end

            % copy current version of ROIs
            rois_copy = obj.buffer{obj.ibuffer};

            % deal with multiple stacks assignement
            if size(rois, 1) > 1
                istacks = 1:size(rois_copy, 1);
            else
                istacks = obj.iframe(1);
            end

            % delete case (blank footprints)
            if isempty(rois)
                nstacks = numel(istacks);
                nrois = numel(rois_idx);
                rois = struct('footprint', cell(nstacks, nrois));

                % flush merged footprints caches
                obj.partial_rframe = [];
                obj.partial_overlaps = [];
            end

            % append case
            if isempty(rois_idx)
                rois_idx = (1:size(rois, 2)) + size(rois_copy, 2);

                % flush merged footprints caches
                obj.partial_rframe = [];
                obj.partial_overlaps = [];
            end

            % flush footprints caches if some modified ROIs aren't selected
            if any(~ismember(rois_idx, obj.selected))
                obj.partial_rframe = [];
                obj.partial_overlaps = [];
            end

            % update ROIs
            [rois_copy, rois] = adjustfields(rois_copy, rois);
            rois_copy(istacks, rois_idx) = rois;

            % case of new version of ROIs (update not in-place)
            if ~inplace
                % increment buffer index
                obj.ibuffer = mod(obj.ibuffer, length(obj.buffer)) + 1;

                % increase number of cancelable steps and remove redo-able steps
                obj.n_undo = min(obj.n_undo + 1, length(obj.buffer) - 1);
                obj.n_redo = 0;
            end

            % remove deleted ROIs from selection and compress all ROIs
            del_rois = cellfun(@isempty, reshape({rois.footprint}, size(rois)));
            del_rois_idx = rois_idx(any(del_rois, 1));

            new_selected = obj.selected;
            if ~isempty(del_rois_idx)
                [rois_copy, new_selected] = ...
                    compress_rois(rois_copy, obj.selected, del_rois_idx);

                % flush merged footprints caches
                obj.partial_rframe = [];
                obj.partial_overlaps = [];
            end

            % update ROIs version and selection (trigger listeners)
            obj.buffer{obj.ibuffer} = rois_copy;
            obj.selected = new_selected;

            % update ROIs of current frame (trigger listeners)
            obj.refresh_frame();
        end

    end

end

function [rois, selected] = compress_rois(rois, selected, del_rois_idx)
    % remove ROIs missing in all stacks

    % remove deleted ROIs from selection
    selected = selected(~ismember(selected, del_rois_idx));

    % compress ROIs, removing lines where all ROIs have empty footprints
    del_footprints = reshape( ....
        {rois(:, del_rois_idx).footprint}, size(rois, 1), numel(del_rois_idx));
    removed_idx = del_rois_idx(all(cellfun(@isempty, del_footprints), 1));
    rois(:, removed_idx) = [];

    % shift selection indices
    for ii=1:numel(removed_idx)
        ridx = removed_idx(ii);
        selected(selected >= ridx) = selected(selected >= ridx) - 1;
        removed_idx(removed_idx >= ridx) = removed_idx(removed_idx >= ridx) - 1;
    end
end