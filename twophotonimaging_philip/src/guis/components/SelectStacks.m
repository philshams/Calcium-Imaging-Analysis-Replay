classdef SelectStacks < handle

    properties (SetAccess = private)
        % View related properties
        menu_display   % menu to select stacks to display
        play           % button to toggle auto play of frames
        stack          % slider and text for stacks
        frame          % slider and text for frames
        channel        % slider and text for channels
        zplane         % slider and text for Z-planes
        
        % Model related properties
        stacks_model   % sets of stack to select
        play_timer     % timer to update the model periodically
    end

    methods

        function obj = SelectStacks(stacks_model, fig)
            obj.stacks_model = stacks_model;

            % load the view
            obj.menu_display = findobj(fig, 'tag', 'menuDisplay');
            obj.play = findobj(fig, 'tag', 'togglePlayFrames');

            obj.stack.slider = findobj(fig, 'tag', 'sliderStack');
            obj.stack.text = findobj(fig, 'tag', 'textNStack');
            obj.frame.slider = findobj(fig, 'tag', 'sliderFrame');
            obj.frame.text = findobj(fig, 'tag', 'textNFrame');
            obj.channel.slider = findobj(fig, 'tag', 'sliderChannel');
            obj.channel.text = findobj(fig, 'tag', 'textNChannel');
            obj.zplane.slider = findobj(fig, 'tag', 'sliderZPlane');
            obj.zplane.text = findobj(fig, 'tag', 'textNZPlane');

            % initialize the view
            obj.menu_display.String = obj.stacks_model.labels;
            obj.update_view();

            % timer to play frames as a movie
            % TODO add constructor parameter for timer speed?
            obj.play_timer = timer( ...
                'TimerFcn', @obj.play_timer_callback, ...
                'ExecutionMode', 'fixedSpacing', 'period', 0.05);

            % listener to update the view on model update
            addlistener( ...
                obj.stacks_model, 'frame', 'PostSet', @obj.update_view);

            % listeners/callback to update model on view update
            obj.menu_display.Callback = @obj.update_set;
            obj.play.Callback = @obj.play_callback;
            addlistener(obj.stack.slider, 'Value', 'PostSet', ...
                        @obj.update_stack);
            addlistener(obj.frame.slider, 'Value', 'PostSet', ...
                        @obj.update_frame);
            addlistener(obj.zplane.slider, 'Value', 'PostSet', ...
                        @obj.update_frame);
            addlistener(obj.channel.slider, 'Value', 'PostSet', ...
                        @obj.update_frame);
        end

        function update_view(obj, varargin)
            % selected stacks set
            obj.menu_display.Value = obj.stacks_model.istacks_sets;

            % adjust maximum of sliders
            nstacks = numel(obj.stacks_model.stacks);
            set_slider_max(obj.stack, nstacks);

            [~, ~, nz, nc, nf] = size(obj.stacks_model.stack);
            set_slider_max(obj.frame, nf);
            set_slider_max(obj.channel, nc);
            set_slider_max(obj.zplane, nz);

            % selected stack, z-plane, channel and frame
            update_slider(obj.stack, obj.stacks_model.istack);
            update_slider(obj.frame, obj.stacks_model.iframe(3));
            update_slider(obj.channel, obj.stacks_model.iframe(2));
            update_slider(obj.zplane, obj.stacks_model.iframe(1));
        end

        function update_set(obj, varargin)
            % retrieve index from slider
            istacks_sets = obj.menu_display.Value;
            % update model
            obj.stacks_model.select_set(istacks_sets);
        end

        function update_stack(obj, varargin)
            % retrieve index from slider
            istack = obj.stack.slider.Value;
            % update model
            obj.stacks_model.select_stack(istack);
        end

        function update_frame(obj, varargin)
            % retrieve indices from sliders
            iframe = obj.frame.slider.Value;
            izplane = obj.zplane.slider.Value;
            ichannel = obj.channel.slider.Value;

            % update model
            obj.stacks_model.select_frame([izplane, ichannel, iframe]);
        end

        function play_callback(obj, varargin)
            % start/stop play timer
            if obj.play.Value
                start(obj.play_timer);
            else
                stop(obj.play_timer);
            end

        end

        function play_timer_callback(obj, varargin)
            % update model to move forward frame
            iframe = obj.stacks_model.iframe;
            next = iframe(3) + 1;
            obj.stacks_model.select_frame([iframe(1), iframe(2), next])

            % stop if at the end
            nframes = size(obj.stacks_model.stack, 5);
            if next >= nframes
                stop(obj.play_timer);
                obj.play.Value = false;
            end
        end

    end

end

function set_slider_max(hstruct, nmax)
    % disable slider if one element
    if nmax <= 1
        hstruct.slider.Enable = 'off';
    else
        hstruct.slider.Enable = 'on';
    end

    % force valid value of the slider
    if hstruct.slider.Value > nmax
        update_slider(hstruct, nmax);
    end

    % set limit value
    hstruct.slider.Max = nmax;

    % set step size to corresponds to 1
    if nmax > 1
        step = 1 / (nmax - 1);
        hstruct.slider.SliderStep = [step step];
    else
        hstruct.slider.SliderStep = [1 1];
    end
end

function update_slider(hstruct, value)
    hstruct.slider.Value = value;
    hstruct.text.String = value;
end
