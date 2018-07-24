classdef AddRoi < handle

    properties (SetAccess = private)
        % View related properties
        bt_ellipse    % button to draw ellipsis
        bt_line       % button to draw lines
        cb_replicate  % checkbox to trigger replication over stacks
        img_fig       % figure where images are displayed
        img_axis      % axis where images are displayed
        hshape        % current shape

        % Model related properties
        rois_model    % model to get/set rois

        % shared state to ensure one drawing at a time
        drawing
    end

    methods

        function obj = AddRoi(rois_model, img_fig, fig)
            obj.rois_model = rois_model;
            obj.drawing = false;

            % load the view
            obj.bt_ellipse = findobj(fig, 'tag', 'btEllipse');
            obj.bt_line = findobj(fig, 'tag', 'btLine');
            obj.cb_replicate = findobj(fig, 'tag', 'cbReplicate');
            obj.img_fig = img_fig;
            obj.img_axis = imgca(img_fig);

            % listener/callbacks to update the rois model on view update
            obj.bt_ellipse.Callback = ...
                @(src, ~) obj.update_shape(src, @imellipse);
            obj.bt_line.Callback = @(src, ~) obj.update_shape(src, @imline);
        end

        function delete(obj)
            % remove current pending shape
            delete(obj.hshape)
        end

        function update_view(obj, handle)
            % release buttons not currently used

            if handle ~= obj.bt_ellipse
                obj.bt_ellipse.Value = false;
            end

            if handle ~= obj.bt_line
                obj.bt_line.Value = false;
            end
        end

        function update_shape(obj, handle, tool)
            % update view to be sure to have correct button positions
            obj.update_view(handle)

            % remove any current shape
            delete(obj.hshape);
            obj.hshape = [];

            % stop pending operations
            if obj.drawing
                obj.drawing = false;
                uiresume(obj.img_fig);
            end

            % /!\ start interactive drawing tool in a timer, with a delay,
            %     as 'uiresume' is effective after this callback returns
            if handle.Value
                shape_timer = timer( ...
                    'StartDelay', 0.1, 'TimerFcn', {@obj.draw_shape, tool});
                start(shape_timer);
            end
        end

        function draw_shape(obj, ~, ~, tool)
            obj.drawing = true;

            % open interactive tool to add shape
            % /!\ this can be interrupted by 'uiresume' called somewhere else,
            %     typically in 'update_shape' callback
            try
                obj.hshape = tool(obj.img_axis);
                p = wait(obj.hshape);
            catch
                p = [];
            end

            % create a new ROI, if any
            if obj.drawing && ~isempty(p) && ~isempty(obj.hshape)
                mask = createMask(obj.hshape);
                roi = struct('footprint', sparse(mask), ...
                             'zplane', obj.rois_model.iframe(2), ...
                             'channel', obj.rois_model.iframe(3));

                % replicate new ROI over stacks if necessary
                if obj.cb_replicate.Value
                    nstacks = size(obj.rois_model.current_rois(), 1);
                    roi = repmat(roi, nstacks, 1);
                end

                obj.rois_model.update_frame(roi, []);
            end

            % remove interactive shape
            delete(obj.hshape);
            obj.hshape = [];

            % if current callback is not interrupted, release all buttons
            if obj.drawing
                obj.update_view(-1);
            end

            obj.drawing = false;
        end

    end

end