classdef ShortcutsManager < handle

    properties (SetAccess = private)
        help_shortcut;  % shortcut to display the summary
        callbacks;  % map containing callbacks associated to shortcuts
        messages;  % map containing descriptions of shortcuts actions
        shortcuts;  % cellarray of shortcuts, to save insertion order :-)
    end

    methods

        function obj = ShortcutsManager(help_shortcut)
            obj.callbacks = containers.Map();
            obj.messages = containers.Map();
            obj.add_shortcut(help_shortcut, ...
                @obj.display_summary, 'display shortcut summary');
        end

        function add_shortcut(obj, shortcut, callback, msg)
            % add a new managed shortcut
            if obj.messages.isKey(shortcut)
                warning('Redefined shortcut ''%s'' ("%s" becomes "%s").', ...
                        shortcut, obj.messages(shortcut), msg);
            end
            obj.callbacks(shortcut) = callback;
            obj.messages(shortcut) = msg;
            obj.shortcuts{end + 1} = shortcut;
        end
        
        function key_press(obj, ~, evt)
            % trigger actions depending on key presses
            if obj.callbacks.isKey(evt.Key)
                callback = obj.callbacks(evt.Key);
                callback();
            end     
        end

        function display_summary(obj)
            % display a summary of all managed shortcuts
            fprintf('### Shortcuts summary ###\n');
            for i = 1:numel(obj.shortcuts)
                key = obj.shortcuts{i};
                fprintf('# %s: %s\n', key, obj.messages(key));
            end
            fprintf('#########################\n');
        end

    end
 
end