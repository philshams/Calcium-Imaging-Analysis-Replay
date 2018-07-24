function xysshow(xyshifts, ncols, parent)
    % XYSSHOW plot (x,y)-shifts for several stacks
    %
    % xysshow(xyshifts, ncols, parent)
    %
    % INPUTS
    %   xyshifts - shifts for each frame and z-plane of stacks, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %   ncol - (optional) default: 1
    %       number of columns used to display shifts for each z-plane
    %   parent - (optional) default: new figure
    %       parent figure, uipanel object or uitab object to use to display
    %
    % SEE ALSO stacksregister_dft, stacktranslate

    if ~exist('xyshifts', 'var')
        error('Missing xyshifts argument.');
    elseif ~iscell(xyshifts)
        xyshifts = {xyshifts};
    end
    nstacks = numel(xyshifts);

    for ii = 1:nstacks
        xy_attr = {'3d', 'size', [2, NaN, NaN]};
        validateattributes(xyshifts{ii}, {'numeric'}, xy_attr, '', 'xyshifts'); 
    end

    if ~exist('ncols', 'var') || isempty(ncols)
        ncols = 1;
    else
        ncols_attr = {'scalar', 'integer', 'positive'};
        validateattributes(ncols, {'numeric'}, ncols_attr, '', 'ncols');
    end

    if ~exist('parent', 'var') || isempty(parent)
        % create a centered empty figure
        parent = ...
            figure('Units', 'normalized', 'Position', [0.25, 0.25, 0.5, 0.5]);
    else
        parent_class = {'matlab.ui.Figure', 'matlab.ui.container.Tab', ...
                        'matlab.ui.container.Panel'};
        validateattributes(parent, parent_class, {}, '', 'parent');
    end

    % plot first (x,y)-shifts and stop if there is no additional ones
    axes_sub = plot_xys(xyshifts{1}, parent, ncols);
    if nstacks == 1
        return;
    end

    % create control panel and configure slider/text inside
    ctrl_panel = uipanel('Units', 'characters', 'Position', [0, 0, 20, 3]);

    slider_step = [1 / (nstacks - 1), 1 / (nstacks - 1)];
    stack_slider = uicontrol('Style', 'slider', 'Parent', ctrl_panel, ...
        'Value', 1, 'Min', 1, 'Max', nstacks, 'SliderStep', slider_step, ...
        'Units', 'characters', 'Position', [2.5, 0.5, 15, 1]);
    stack_text = uicontrol('Style', 'Text', 'Parent', ctrl_panel, ...
        'String', 'stack 1', 'Units', 'characters', ...
        'Position', [2.5, 1.5, 15, 1]);

    function slider_callback(~, ~)
        cellfun(@delete, axes_sub);  % clean existing subplots
        istack = round(stack_slider.Value);
        stack_text.String = sprintf('stack %d', istack);
        axes_sub = plot_xys(xyshifts{istack}, parent, ncols);
    end
    stack_slider.Callback = @slider_callback;
end

function axes_sub = plot_xys(xys, parent, ncols)
    % plot provided (x,y)-shifts on a grid in parent handle
    nz = size(xys, 2);
    axes_sub = cell(1, nz);
    for ii = 1:nz
        h = subplot(ceil(nz / ncols), ncols, ii, 'Parent', parent);
        plot(h, squeeze(xys(:, ii, :))');
        grid(h, 'on');
        title(h, sprintf('z-plane %d', ii));
        axes_sub{ii} = h;
    end
    linkaxes(cat(1, axes_sub{:}), 'xy');
    ylim(axes_sub{1}, [min(xys(:)), max(xys(:))]);
    xlim(axes_sub{1}, [1, size(xys, 3)]);

    % add one legend, centered in the left margin of the first plot
    hl = legend(axes_sub{1}, 'x-shifts', 'y-shifts');
    hl.Position = [ ...
        axes_sub{1}.Position(1) / 4, ...
        axes_sub{1}.Position(2) + axes_sub{1}.Position(4) / 2, ...
        hl.Position(3:4)];
end
