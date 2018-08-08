classdef StacksModel < handle

    properties (SetAccess = private, SetObservable = true)
        labels        % name of stacks sets
        stacks_sets   % tracked stacks sets
        xyshifts_sets % (x,y)-shifts for stacks sets

        % Stacks sets related
        stacks        % set of stacks selected
        xyshifts      % (x,y) shifts of the stacks set, if any
        label         % name of current set of stacks
        istacks_sets  % index of currently selected set of stacks

        % Stack related
        stack         % stack currently selected
        xyshift       % (x,y) shifts of the stack, if any
        istack        % index of stack currently selected

        % Frame related
        frame         % frame currently selected
        iframe        % indices of currently selected frame
    end

    methods

        function obj = StacksModel(labels, stacks_sets, xyshifts_sets)
            % load input stacks
            obj.labels = labels;
            obj.stacks_sets = stacks_sets;
            obj.xyshifts_sets = xyshifts_sets;

            % select first set, stack and frame
            obj.istacks_sets = 1;
            obj.istack = 1;
            obj.iframe = [1, 1, 1];

            obj.select_set(obj.istacks_sets);
        end

        function select_set(obj, istacks_sets)
            % make sure index is valid
            istacks_sets = min(round(istacks_sets), numel(obj.stacks_sets));

            % update current set of stacks
            obj.istacks_sets = istacks_sets;
            obj.label = obj.labels{istacks_sets};
            obj.stacks = obj.stacks_sets{istacks_sets};
            obj.xyshifts = obj.xyshifts_sets{istacks_sets};

            % update selected stack
            obj.select_stack(obj.istack);
        end

        function select_stack(obj, istack)
            % make sure index is valid
            istack = min(round(istack), numel(obj.stacks));

            % update current stack
            obj.istack = istack;
            obj.stack = obj.stacks{istack};
            if ~isempty(obj.xyshifts)
                obj.xyshift = obj.xyshifts{istack};
            else
                obj.xyshift = [];
            end

            % update selected frame
            obj.select_frame(obj.iframe);
        end

        function select_frame(obj, iframe)
            % make sure indices are valid
            [~, ~, nz, nc, nt] = size(obj.stack);
            iframe = min(round(iframe), [nz, nc, nt]);

            % update current frame, applying registration if necessary
            obj.iframe = iframe;

            img = obj.stack(:, :, iframe(1), iframe(2), iframe(3));
            if ~isempty(obj.xyshift)
                xy = obj.xyshift(:, iframe(1), iframe(3));
                img = stacktranslate(img, xy);
            end
            obj.frame = img;
        end

    end

end
