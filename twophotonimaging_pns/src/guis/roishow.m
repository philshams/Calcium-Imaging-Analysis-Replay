function roishow(roi, frame, bbox, parent)
    % ROISHOW plot ROI structure information
    %
    % roishow(roi, frame, bbox, parent)
    %
    % This function creates a display for a ROI structure, for its footprint and
    % various extracted traces. If no parent figure is provided, it will create
    % one.
    %
    % INPUTS
    %   roi - input ROI, as a structure with the following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %       - 'activity' (optional): extracted trace, as a vector
    %       - 'raw_activity' (optional): raw extracted trace, as a vector
    %       - 'spikes' (optional): extracted spikes, as a vector
    %   frame - (optional) default: []
    %       image to display aside the ROI footprint
    %   bbox - (optional) default: []
    %       bounding box side length, to restrict the view around the ROI
    %   parent - (optional) default: new figure
    %       parent figure, uipanel object or uitab object to use to display
    %
    % SEE ALSO roisgui, roibbox

    if ~exist('roi', 'var')
        error('Missing roi argument.');
    end

    validateattributes(roi, {'struct'}, {'scalar'}, '', 'roi');
    roi = roischeck(roi);
    if isempty(roi.footprint)  % additional check that footprint is not empty
        error('Empty footprint field in roi structure.');
    end

    [nx, ny] = size(roi.footprint);

    if ~exist('frame', 'var')
        frame = [];
    elseif ~isempty(frame)
        validateattributes(frame, {'numeric'}, {'size', [nx, ny]}, '', 'frame');
    end

    if ~exist('bbox', 'var')
        bbox = [];
    elseif ~isempty(bbox)
        bbox_attr = {'scalar', 'positive', 'integer'};
        validateattributes(bbox, {'numeric'}, bbox_attr, '', 'bbox');
    end

    if ~exist('parent', 'var') || isempty(parent)
        % create an empty figure
        parent = figure('ToolBar', 'none', 'MenuBar', 'none', 'Resize', 'off');
        parent.Position = [parent.Position(1:2), 755, 255];
    else
        parent_class = {'matlab.ui.Figure', 'matlab.ui.container.Tab', ...
                        'matlab.ui.container.Panel'};
        validateattributes(parent, parent_class, {}, '', 'parent');
    end

    % settings to space subplots
    pad = 0.01;  % space between subplots and border
    w_img = 0.33;  % width for images subplots
    h_img = 1 - pad * 2;  % height for images subplots

    % ROI center
    if ~isempty(bbox) && nnz(roi.footprint) > 0
        [r, c] = roibbox(roi.footprint, bbox);
    else
        r = 1:nx;
        c = 1:ny;
    end

    % plot zoomed frame
    ax_frame = subplot('Position', [pad, pad, w_img, h_img], 'Parent', parent);
    if ~isempty(frame)
        plot_image(frame(r, c), ax_frame);
        safe_colormap(ax_frame, 'gray');
    else
        axis(ax_frame, 'off');
        text(0.5, 0.5, 'No input frame', 'HorizontalAlignment', 'center', ...
             'Parent', ax_frame);
    end

    % plot zoomed footprint
    pos_footprint = [w_img + 2 * pad, pad, w_img, h_img];
    ax_footprint = subplot('Position', pos_footprint, 'Parent', parent);
    plot_image(full(roi.footprint(r, c)), ax_footprint);

    % filter possible traces fields with ROI structure content
    fields_titles = {'stable_epoch', 'activity', 'raw activity', 'spikes', 'psth'};
    fields = cellfun(@(x) strrep(x, ' ', ''), fields_titles, 'un', false);

    field_mask = cellfun(@(x) isfield(roi, x) && ~isempty(roi.(x)), fields);
    
    % if activity_truncated and activity, only show the former
    if field_mask(1) && field_mask(2)
        field_mask(1) = 0;
        roi.(fields{2}) = roi.(fields{2})(roi.(fields{1})(1):roi.(fields{1})(2));
    end
    fields = fields(field_mask);
    fields_titles = fields_titles(field_mask);

    % setting to space traces plots
    left_plots = w_img * 2 + pad * 3;  %left position of traces plots
    w_trace = 1 - left_plots - pad;  % width for traces plots
    h_title = 0.12;  % vertical space to keep for title

    % plot ROI traces
    if numel(fields) > 0
        h_trace = (1 - pad)  / numel(fields);
        bottom_trace = pad;
        for ii = numel(fields):-1:1        
            pos = [left_plots, bottom_trace, w_trace, h_trace - h_title - pad];
            ax_trace = subplot('Position', pos, 'Parent', parent);
            plot_trace(roi.(fields{ii}), fields_titles{ii}, ax_trace);

            bottom_trace = bottom_trace + h_trace;
        end
    else
        ax_traces = subplot('Position', [left_plots, pad, w_trace, h_img], ...
                            'Parent', parent);
        axis(ax_traces, 'off');
        text(0.5, 0.5, 'No time series', 'HorizontalAlignment', 'center', ...
             'Parent', ax_traces);
    end 
end

function plot_image(img, parent)
    % plot an image with few decorations
    imagesc(img, 'Parent', parent);
    axis(parent, 'square');
    axis(parent, 'off');
end

function plot_trace(trace, trace_title, parent)
    % plot a trace with few decorations
    try
    axes(parent)
    h = plot(trace, 'Parent', parent); hold on
    if strcmp(trace_title, 'psth')
        plot([20 20],[min(trace(:)) 1.2*max(trace(:))],'color','k','linestyle',':', 'Parent', parent)
        if size(trace,2) == 5
            set(h,{'color'},{[0 0 1 .7];[.4 .4 0 .7];[0 .3 .8 .7];[.5 .3 .2 .7];[0 1 0 .7]})
        elseif size(trace,2) == 10
            set(h,{'color'},{[0 0 1 .7];[.4 .4 0 .7];[0 .3 .8 .7];[.5 .3 .2 .7];[.3 .3 .3 .7];[.5 0 0 .7];[0 .5 0 .7];[.3 .3 .3 .7];[1 0 0 .7];[0 1 0]})
        end
    end
    
    axis(parent, 'tight');
    axis(parent, 'off');
    title(parent, trace_title, 'FontWeight', 'normal');
    catch; end
end

function safe_colormap(parent, cm)
    % safely set a colormap, creating a dummy figure if none seem selected
    if isempty(get(groot, 'CurrentFigure'))
        fig = figure('Visible', 'off');
        colormap(parent, cm);
        delete(fig);
    else
        colormap(parent, cm);
    end
end
