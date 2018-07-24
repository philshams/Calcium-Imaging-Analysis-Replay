classdef AdjustContrast < handle

    properties (SetAccess = private)
        % View related properties
        slider_cmin   % slider to limit minimum intensity
        slider_cmax   % slider to limit maximum intensity
        slider_gamma  % slider to adjust gamma correction
        cb_auto       % checkbox to auto adjust min/max to current image

        % Model related properties
        stacks_model  % input feeder for frames
    end

    properties (SetAccess = private, SetObservable = true)
        frame         % output for adjusted frames
    end

    methods

        function obj = AdjustContrast(stacks_model, fig)
            obj.stacks_model = stacks_model;

            % load the view
            obj.slider_cmin = findobj(fig, 'tag', 'sliderCMin');
            obj.slider_cmax = findobj(fig, 'tag', 'sliderCMax');
            obj.slider_gamma = findobj(fig, 'tag', 'sliderGamma');
            obj.cb_auto = findobj(fig, 'tag', 'cbAutoLimits');

            % initialize sliders limits
            [cmin, cmax] = obj.update_clim();
            obj.slider_cmin.Value = cmin;
            obj.slider_cmax.Value = cmax;

            % initialize the adjusted frame
            obj.update_frame();

            % listener to update the view on model update
            addlistener( ...
                obj.stacks_model, 'frame', 'PostSet', @obj.update_clim);

            % listener to update adjusted image on model update
            addlistener( ...
                obj.stacks_model, 'frame', 'PostSet', @obj.update_frame);

            % listeners/callback to update adjusted image on view update
            addlistener(obj.slider_cmin, 'Value', 'PostSet', ...
                        @obj.update_frame);
            addlistener(obj.slider_cmax, 'Value', 'PostSet', ...
                        @obj.update_frame);
            addlistener(obj.slider_gamma, 'Value', 'PostSet', ...
                        @obj.update_frame);
            obj.cb_auto.Callback = @obj.update_auto;
        end

        function [cmin, cmax] = update_clim(obj, varargin)
            % don't update if in auto mode
            if obj.cb_auto.Value
                return;
            end

            % get min/max values of the current frame in the model
            cmin = min(obj.stacks_model.frame(:));
            cmax = max(obj.stacks_model.frame(:));

            % set sliders limits to lowest/highest possible values
            set_clim_minmax(obj.slider_cmin, cmin, cmax);
            set_clim_minmax(obj.slider_cmax, cmin, cmax);
        end

        function update_frame(obj, varargin)
            % auto rescale image if auto mode activated
            if obj.cb_auto.Value
                disp_frame = mat2gray(obj.stacks_model.frame);
            else
                disp_frame = obj.stacks_model.frame;
            end

            % adjust image intensity, cutting lowest/highest values
            cmin = obj.slider_cmin.Value;
            cmax = obj.slider_cmax.Value;
            img = mat2gray(disp_frame, [cmin, cmax]);

            % apply gamma correction
            obj.frame = img .^ obj.slider_gamma.Value;
        end

        function update_auto(obj, varargin)
            % set sliders in [0, 1] interval if auto mode activated
            if obj.cb_auto.Value
                set_clim_minmax(obj.slider_cmin, 0, 1, true);
                set_clim_minmax(obj.slider_cmax, 0, 1, true);
                obj.slider_cmin.Value = 0;
                obj.slider_cmax.Value = 1;

            % restore limits to image range if auto mode deactivated
            else
                [cmin, cmax] = obj.update_clim();
                obj.slider_cmin.Value = cmin;
                obj.slider_cmax.Value = cmax;
            end
 
            % update displayed image
            obj.update_frame();
        end

    end

end

function set_clim_minmax(slider, cmin, cmax, force)
    % default value for forcing slider limits update
    if ~exist('force', 'var')
        force = false;
    end

    % update slider limits if new limits are bigger (or forced update)
    if slider.Min > cmin || force
        slider.Min = cmin;
    end
    if slider.Max < cmax || force
        slider.Max = cmax;
    end

    % set step size to corresponds to 1
    nrange =  slider.Max - slider.Min;
    if nrange > 2
        step = 1 / (nrange - 1);
        slider.SliderStep = [step step];
    else
        slider.SliderStep = [1 1];
    end
end
