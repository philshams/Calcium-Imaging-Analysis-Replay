function [mfig, img_fig] = stacksgui(stacks, xyshifts, varargin)
    % STACKSGUI display a graphical interface to look at stacks
    %
    % [mfig, img_fig] = stacksgui(stacks, xyshifts, varargin)
    %
    % This function provides a GUI to display a set of stacks, applying
    % registration on-the-fly if provided. Optionally, other sets of stacks can
    % be displayed.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %   varargin - (optional) other sets of stacks and their labels, passed as
    %       ___ = roisgui(___, Label1, Stacks1, Label2, Stacks2, ...)
    %
    % OUPUTS
    %   mfig - handle to the main panel figure
    %   img_fig - handle to the imtool figure
    %
    % EXAMPLES
    %   % load some .tif stacks
    %   stacks = stacksload({'folder_path1', 'folder_path2'});
    %
    %   % compute mean images
    %   avgs = stacksmean(stacks);
    %
    %   % display stacks and their mean images
    %   [mfig, ~] = stacksgui(stacks, [], 'averages', avgs);
    %
    %   % wait until figures are closed
    %   uiwait(mfig);
    %
    % SEE ALSO stacksload, stacksmean, stacksregister_dft, roisgui

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end

    if ~exist('xyshifts', 'var')
        xyshifts = [];
    end

    [stacks, xyshifts] = stackscheck(stacks, xyshifts);

    % models for sets of stacks and rois masks
    stacks_model = load_stacks_model(stacks, xyshifts, varargin{:});

    % load views and bind components to it
    [mfig, img_fig] = load_views(stacks_model.frame);
    comps = load_components(stacks_model, mfig, img_fig);

    % delete handle objects to free memory when any figure is closed
    iptaddcallback( ...
        mfig, 'CloseRequestFcn', @(~, ~) cellfun(@delete, comps));
    iptaddcallback( ...
        img_fig, 'CloseRequestFcn', @(~, ~) cellfun(@delete, comps));
end

function stacks_model = load_stacks_model(stacks, xyshifts, varargin)
    % instantiate a StacksModel instance

    if mod(numel(varargin), 2) ~= 0
        error('Expected even number of varargin arguments.')
    end

    % get number of sets and preallocate results
    isxyshifts = ~all(cellfun(@isempty, xyshifts));
    nsets = 1 - ~isxyshifts + nargin / 2;

    labels = cell(nsets, 1);
    stacks_sets = cell(nsets, 1);
    xyshifts_sets = cell(nsets, 1);

    % add input stacks in cellarray
    labels{1} = 'frames';
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
        stacks_sets{iset} = next_stacks;

        iset = iset + 1;
    end

    stacks_model = StacksModel(labels, stacks_sets, xyshifts_sets);
end

function [mfig, img_fig] = load_views(first_frame)
    % create views needed by the tool

    % create the main panel
    mfig = openfig('StacksGui.fig');

    % create image figure and move it next to the display panel
    img_fig = imtool(first_frame);
    img_fig.Position(1:2) = [ ...
        mfig.Position(1) + mfig.Position(3) + 10, ...
        mfig.Position(2) + mfig.Position(4) - img_fig.Position(4) - 55];

    % make figures close together
    handles = [mfig, img_fig];
    for ii=1:numel(handles)
        iptaddcallback( ...
            handles(ii), 'CloseRequestFcn', @(~, ~) delete(handles));
    end
end

function comps = load_components(stacks_model, mfig, img_fig)
    % load GUI components and wire them to models and views
    comps{1} = SelectStacks(stacks_model, mfig);
    comps{2} = AdjustContrast(stacks_model, mfig);
    comps{3} = ImtoolWrapper(comps{2}, img_fig);
end
