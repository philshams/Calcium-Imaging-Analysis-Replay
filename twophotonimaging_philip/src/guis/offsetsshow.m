function offsetsshow(stacks, offsets, nframes, parent)
    % OFFSETSSHOW plot offsets in frames histograms for several stacks
    %
    % offsetsshow(stacks, offsets, nframes, parent)
    %
    % This function randomly samples frames from stacks and display estimated
    % offsets in the histogram of these frames.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   offsets - estimated offsets, as either
    %       1) a [Channels] vector
    %       2) a cellarray of the previous type
    %   nframes - (optional) default: 3
    %       number of frames sampled from each stack
    %   parent - (optional) default: new figure
    %       parent figure, uipanel object or uitab object to use to display
    %
    % REMARKS
    %   Fix the random generator seed (using 'rng' function) before calling this
    %   function to get reproducible results.
    %
    % SEE ALSO stacksregister_dft, stacktranslate

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    stacks = stackscheck(stacks);
    nstacks = numel(stacks);

    if ~exist('offsets', 'var')
        error('Missing offsets argument.');
    elseif ~iscell(offsets)
        offsets = {offsets};
    end

    if numel(offsets) ~= nstacks
        error('Number of offsets is different from number of stacks.');
    end
    for ii = 1:nstacks
        nc_stack = size(stacks{ii}, 4);
        off_attr = {'vector', 'numel', nc_stack};
        validateattributes(offsets{ii}, {'numeric'}, off_attr, '', 'offsets');
    end

    if ~exist('nframes', 'var') || isempty(nframes)
        nframes = 1;
    else
        nframes_attr = {'scalar', 'integer', 'positive'};
        validateattributes(nframes, {'numeric'}, nframes_attr, '', 'nframes');
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

    % randomly sample frames indices
    indices = cell(1, nstacks);
    for ii = 1:nstacks
        [~, ~, nz, ~, nt] = size(stacks{ii});
        indices{ii} = [randi(nz, 1, nframes); randi(nt, 1, nframes)];
    end

    % plot first offets and stop if there is no additional ones
    axes_sub = plot_offsets(stacks{1}, offsets{1}, indices{1}, parent);
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
        axes_sub = plot_offsets( ...
            stacks{istack}, offsets{istack}, indices{istack}, parent);
    end
    stack_slider.Callback = @slider_callback;
end

function axes_sub = plot_offsets(stack, offsets, idx, parent)
    % plot offsets on frames histograms in parent handle

    nc = numel(offsets);
    nframes = size(idx, 2);
    axes_sub = cell(nc, nframes);
    for ii = 1:nc
        for jj = 1:nframes
            iz = idx(1, jj);
            it = idx(2, jj);
            img = stack(:, :, idx(1, jj), ii, idx(2, jj));

            h = subplot(nc, nframes, (ii - 1) * nframes + jj, 'Parent', parent);
            histogram(h, img);

            ys = ylim(h);
            hline = line([offsets(ii), offsets(ii)], ys, ...
                'Color', 'r', 'LineWidth', 2);
            legend(hline, 'estimated offset');

            axis(h, 'tight');
            grid(h, 'on');
            xlabel(h, 'pixel intensity');
            title(h, sprintf('channel %d (z = %d, t = %d)', ii, iz, it));

            axes_sub{ii, jj} = h;
        end
    end
end
