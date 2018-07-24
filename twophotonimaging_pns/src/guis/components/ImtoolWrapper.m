classdef ImtoolWrapper < handle

    properties (SetAccess = private)
        % View related properties
        api           % set of function handles to manipulate imtool

        % Model related properties
        stacks_model  % input feeder for frames
    end

    methods

        function obj = ImtoolWrapper(stacks_model, imtool_handle)
            obj.stacks_model = stacks_model;

            % API to manipulate imscrollpanel of imtool
            img_axis = imgca(imtool_handle);
            obj.api = iptgetapi(img_axis.Parent);

            % listener on the current frame to update image display
            addlistener( ...
                obj.stacks_model, 'frame', 'PostSet', @obj.redraw_img);

            % display current image, at full size
            obj.redraw_img();
            zoom_factor = obj.api.findFitMag();
            obj.api.setMagnification(zoom_factor);
        end

        function redraw_img(obj, varargin)
            obj.api.replaceImage(obj.stacks_model.frame, 'PreserveView', true);
        end

    end

end
