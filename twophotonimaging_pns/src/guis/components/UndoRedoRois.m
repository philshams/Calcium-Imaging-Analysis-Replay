classdef UndoRedoRois < handle

    properties (SetAccess = private)
        % View related properties
        bt_undo       % button to undo ROIs modification
        bt_redo       % button to redo ROIs modification
 
        % Model related properties
        rois_model    % input feeder for rois
    end

    methods

        function obj = UndoRedoRois(rois_model, fig)
            obj.rois_model = rois_model;

            % load the view
            obj.bt_undo = findobj(fig, 'tag', 'btUndo');
            obj.bt_redo = findobj(fig, 'tag', 'btRedo');

            % initialize the view
            obj.update_view();

            % listeners to update display when number of ROIs version changes
            addlistener(obj.rois_model, 'n_undo', 'PostSet', @obj.update_view);
            addlistener(obj.rois_model, 'n_redo', 'PostSet', @obj.update_view);

            % callbacks to update the model on view updates
            obj.bt_undo.Callback = @(~, ~) obj.rois_model.undo();
            obj.bt_redo.Callback = @(~, ~) obj.rois_model.redo();
        end

        function update_view(obj, varargin)
            % disable undo button if not possible
            if obj.rois_model.n_undo <= 0
                obj.bt_undo.Enable = 'off';
            else
                obj.bt_undo.Enable = 'on';
            end

            % disable redo button if not possible
            if obj.rois_model.n_redo <= 0
                obj.bt_redo.Enable = 'off';
            else
                obj.bt_redo.Enable = 'on';
            end
        end

    end

end
