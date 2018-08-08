function new_rois = roisgui_psth(stacks, xyshifts, rois, stacklabel, varargin)
    % ROISGUI display a graphical interface to display stacks and edit ROIs
    %
    % new_rois = roisgui(stacks, xyshifts, rois, varargin)
    %
    % This function provides a GUI to display a set of stacks, applying
    % registration on-the-fly if provided. Optionally, other sets of stacks can
    % be displayed.
    % This GUI can also display regions-of-interest in an overlay. Various
    % tools to create new ROIs and edit existing ones are provided.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array or an empty scalar
    %                      if the ROI is missing
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %       - 'activity' (optional): time serie, as a [Time] vector
    %   varargin - (optional) other sets of stacks and their labels, passed as
    %       ___ = roisgui(___, Label1, Stacks1, Label2, Stacks2, ...)
    %
    % OUPUTS
    %   new_rois - ROIs created and edited, as a structure array (see 'rois'
    %       parameter definition for more details)
    %
    % REMARKS
    %   If only one set of ROIs is provided, i.e. a row vector, for several
    %   stacks, the set is duplicated for each stack.
    %
    % EXAMPLES
    %   % load some .tif stacks
    %   stacks = stacksload({'folder_path1', 'folder_path2'});
    %
    %   % compute mean images
    %   avgs = stacksmean(stacks);
    %
    %   % display stacks and their mean images
    %   roisgui(stacks, [], [], 'averages', avgs);
    %
    % SEE ALSO stacksload, stacksmean, stacksminmax, stacksregister_dft

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end

    if ~exist('xyshifts', 'var')
        xyshifts = [];
    end

    [stacks, xyshifts] = stackscheck(stacks, xyshifts);
    stacks_dims = cellfun(@size, stacks, 'un', false);
    xy_dims = stacks_dims{1}(1:2);  % TODO all stack should have same X/Y?

    if ~exist('rois', 'var') || isempty(rois)
        empty_field = cell(1, 0);  % to create a 1x0 struct array of ROIs
        rois = struct('footprint', empty_field, 'zplane', empty_field, ...
                      'channel', empty_field);
    end
    rois = roischeck(rois, stacks_dims);

    % models for sets of stacks and rois masks
    stacks_model = load_stacks_model(stacks, xyshifts, xy_dims, stacklabel, varargin{:});
    rois_model = RoisModel(rois, 50);

    % bind displayed stack, zplane and channels from stacks to ROIs
    roisfcn = @(~, ~) rois_model.select_frame( ...
        [stacks_model.istack, stacks_model.iframe(1:2)]);
    addlistener(stacks_model, 'istack', 'PostSet', roisfcn);
    addlistener(stacks_model, 'iframe', 'PostSet', roisfcn);

    % load views and bind components to it
    [mfig, ifig, img_fig] = load_views(stacks_model.frame);
    comps = load_components(stacks_model, rois_model, mfig, ifig, img_fig);

    % add the same shortcut function to each figure
    shortcuts = load_shortcuts(mfig);
    mfig.KeyPressFcn = @shortcuts.key_press;
    ifig.KeyPressFcn = @shortcuts.key_press;
    img_fig.KeyPressFcn = @shortcuts.key_press;

    % wait until figures closing
    uiwait(mfig);

    % returns updated rois, removing those without proper footprint
    new_rois = rois_model.current_rois();

    for ii = 1:numel(new_rois)
        if nnz(new_rois(ii).footprint) == 0
            new_rois(ii).footprint = [];
        end
    end

    % delete handle objects to free memory
    cellfun(@delete, comps);
end

function stacks_model = load_stacks_model(stacks, xyshifts, xy_dims, stacklabel, varargin)
    % instantiate a StacksModel instance

    if mod(numel(varargin), 2) ~= 0
        error('Expected even number of varargin arguments.')
    end

    % get number of sets and preallocate results
    isxyshifts = ~all(cellfun(@isempty, xyshifts));
    nsets = 1 - ~isxyshifts + (nargin - 2) / 2;

    labels = cell(nsets, 1);
    stacks_sets = cell(nsets, 1);
    xyshifts_sets = cell(nsets, 1);

    % add input stacks in cellarray
    if isempty(stacklabel)
        labels{1} = 'frames';
    else
        labels{1} = stacklabel;
    end    
    
    stacks_sets{1} = stacks;
    iset = 2;

    % and add stacks with (x,y)-shifts in cellarray, if any
    if isxyshifts
        labels{2} = 'registered';
        stacks_sets{2} = stacks;
        xyshifts_sets{2} = xyshifts;
        iset = iset + 1;
    end

    % check and add other sets of stacks
    for ii=1:2:numel(varargin)
        if ~ischar(varargin{ii})
            error('Expected string in varargin arguments.');
        end
        labels{iset} = varargin{ii};

        next_stacks = varargin{ii + 1};
        if ~iscell(next_stacks)
            next_stacks = {next_stacks};
        end
        stackscheck(next_stacks, [], xy_dims);
        stacks_sets{iset} = next_stacks;

        iset = iset + 1;
    end

    stacks_model = StacksModel(labels, stacks_sets, xyshifts_sets);
end

function copy_widgets(mainfig, panel_name)
    % helper function to copy widgets from .fig to existing figure
    fig = openfig([panel_name, '.fig'], 'invisible');
    new_parent = findobj(mainfig, 'tag', panel_name);
    copyobj(fig.Children, new_parent);
end

function [mfig, ifig, img_fig] = load_views(first_frame)
    % create views needed by the tool

    % create the main panel, aggregating views created in .fig files
    mfig = openfig('RoisGui.fig', 'invisible');
    copy_widgets(mfig, 'DisplayGui');
    copy_widgets(mfig, 'EditRois');
    copy_widgets(mfig, 'DetectRois');
    mfig.Visible = 'on';

    % create image figure and move it next to the display panel
    img_fig = imtool(first_frame);
    img_fig.Position = [ ...
        mfig.Position(1) + mfig.Position(3) + 10, mfig.Position(2), ...
        mfig.Position(4), mfig.Position(4) - 55];

    % create Rois inspection figure and move it aside the image figure
    ifig = openfig('InspectRois.fig', 'invisible');
    ifig.Position(1:2) = [ ...
        img_fig.Position(1) + img_fig.Position(3) + 10, ...
        mfig.Position(2) + mfig.Position(4) - ifig.Position(4)];
    ifig.Visible = 'on';

    % make figures close together
    handles = [mfig, ifig, img_fig];
    for ii=1:numel(handles)
        iptaddcallback( ...
            handles(ii), 'CloseRequestFcn', @(~, ~) delete(handles));
    end
end

function comps = load_components(stacks_model, rois_model, mfig, ifig, img_fig)
    % load GUI components and wire them to models and views

    % main panel
    comps{1} = SelectStacks(stacks_model, mfig);
    comps{2} = AdjustContrast(stacks_model, mfig);
    comps{3} = DisplayRois(comps{2}, rois_model, mfig);
    comps{4} = ImtoolWrapper(comps{3}, img_fig);
    comps{5} = DisplayRoisText(rois_model, img_fig, mfig);
    comps{6} = UndoRedoRois(rois_model, mfig);

    % ROIs inspection panel
    comps{7} = InspectRois(stacks_model, rois_model, ifig);

    % ROIs edition panel
    comps(8:14) = { ...
        SelectRoi(rois_model, img_fig, mfig), ...
        AddRoi(rois_model, img_fig, mfig), ...
        RemoveRois(rois_model, mfig), ...
        EditRoi(rois_model, mfig), ...
        MorphoRois(rois_model, mfig), ...
        PaintRoi(rois_model, img_fig, mfig), ...
        AnnotateRoi(stacks_model, rois_model, mfig)};

    % ROIs detection panel
    comps{15} = DetectRois(stacks_model, rois_model, img_fig, mfig);
end

function shortcuts = load_shortcuts(mfig)
    % define key bindings to actions on the GUI figures

    shortcuts = ShortcutsManager('h');

    alpha_slider = findobj(mfig, 'tag', 'sliderAlpha');
    shortcuts.add_shortcut('z', @() update_alpha(alpha_slider, 0.25), ...
        'increase ROIs transparency by 25%');
    shortcuts.add_shortcut('a', @() update_alpha(alpha_slider, 0.6), ...
        'toggle ROIs transparency (0 or 60%)');

    bt_new = findobj(mfig, 'tag', 'btNewID');
    shortcuts.add_shortcut('n', bt_new.Callback, 'create a new empty ROI');

    bt_select = findobj(mfig, 'tag', 'btSelectID');
    shortcuts.add_shortcut( ...
        's', @() toggle_button(bt_select), 'toggle ROI selection button');

    bt_undo = findobj(mfig, 'tag', 'btUndo');
    shortcuts.add_shortcut('u', bt_undo.Callback,  'undo ROIs changes');

    bt_redo = findobj(mfig, 'tag', 'btRedo');
    shortcuts.add_shortcut('r', bt_redo.Callback, 'redo ROIs changes');

    bt_delete_roi = findobj(mfig, 'tag', 'btDeleteRoi');
    shortcuts.add_shortcut('d', bt_delete_roi.Callback, 'delete ROI');

    bt_ellipse = findobj(mfig, 'tag', 'btEllipse');
    shortcuts.add_shortcut( ...
        'e', @() toggle_button(bt_ellipse, bt_ellipse), 'ellipse drawing tool');

    bt_line = findobj(mfig, 'tag', 'btLine');
    shortcuts.add_shortcut( ...
        'l', @() toggle_button(bt_line, bt_line), 'line drawing tool');

    bt_paint = findobj(mfig, 'tag', 'btPaint');
    shortcuts.add_shortcut( ...
        'p', @() toggle_button(bt_paint), 'toggle painting button');

    brush_field = findobj(mfig, 'tag', 'editBrush');
    shortcuts.add_shortcut( ...
        '1', @() edit_brush(brush_field, -1), 'decrease brush size');
    shortcuts.add_shortcut( ...
        '2', @() edit_brush(brush_field, 1), 'increase brush size');

    bt_merge_roi = findobj(mfig, 'tag', 'btMergeRoi');
    shortcuts.add_shortcut('m', bt_merge_roi.Callback, 'merge ROIs');

    bt_erode = findobj(mfig, 'tag', 'btErode');
    shortcuts.add_shortcut('comma', bt_erode.Callback, 'erode ROIs');

    bt_dilate = findobj(mfig, 'tag', 'btDilate');
    shortcuts.add_shortcut('period', bt_dilate.Callback, 'dilate ROIs');
end

function update_alpha(alpha_slider, offset)
    % helper slider to increase alpha slider by some amount (and cycle)
    value = alpha_slider.Value;
    value = floor(value / offset) * offset + offset;  % closest next value
    if value > 1
        alpha_slider.Value = 0;
    else
        alpha_slider.Value = value;
    end
end

function toggle_button(button, varargin)
    % helper function to toggle a button widget
    if strcmp(button.Enable, 'off')
        return;
    end
    button.Value = ~button.Value;
    button.Callback(varargin{:});
end

function edit_brush(field, offset)
    % helper function to edit brush size widget
    field.String = str2double(field.String) + offset;
    field.Callback();
end