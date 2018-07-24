function [rois, varargout] = roisfilter(rois, fcn)
    % ROISFILTER apply a function to each ROI activity trace
    %
    % [rois, varargout] = roisfilter(rois, fcn)
    %
    % INPUTS
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %                      or an empty scalar if the ROI is missing
    %       - 'activity': time serie, as a [Time] vector
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %   fcn - function handle, to filter traces (see remarks)
    %
    % OUTPUTS
    %   rois - similar structure as 'rois' input, with filtered activity traces
    %   varargout - additional outputs of 'fcn', returned as cellarrays, each
    %       containing #Stacks elements
    %
    % REMARKS
    %   'fcn' parameter is a function that accepts a 2D array ([#ROIs Time]) and
    %   filter it on the second dimension (Time). Its first output should be a
    %   2D array with #ROIs elements on the first axis.
    %
    % EXAMPLES
    %   % extract dF/F0 for each ROI
    %   perc = 25;  % use the first quartile as baseline
    %   half_win = 250;  % use a sliding window of 500 frames (2 * 250)
    %   [dff, f0] = roisfilter(rois, @(x) extractdff_prc(x, perc, half_win));
    %
    %   % smooth traces using a Chebyshev type 2 low-pass filter
    %   [b, a] = cheby2(6, 40, 0.25);  % filter coefficients
    %   rois_smooth = roisfilter(rois, @(x) filtfilt(b, a, x')');
    %
    % SEE ALSO stacksextract, extractdff_prc

    if ~exist('rois', 'var')
        error('Missing rois argument.');
    end

    rois = roischeck(rois);
    if ~isfield(rois, 'activity')  % additional check that activity field exists
        error('Missing activity field in rois structure.');
    end
    [nstacks, nrois] = size(rois);

    if ~exist('fcn', 'var')
        error('Missing fcn argument.');
    end
    if ~isa(fcn, 'function_handle')
        error('Expected ''fcn'' to be a function handle.');
    end

    % initialize extra outputs
    varargout = repmat({{}}, 1, nargout - 1);

    for i = 1:nstacks
        % filter all trace of a stack at the same time
        traces = cat(1, rois(i, :).activity);
        outputs = cell(1, max(1, nargout));
        [outputs{:}] = fcn(traces);

        % split extra outputs of the function
        for k = 1:nargout-1
            varargout{k}{end + 1} = outputs{k + 1};
        end

        % re-assign new traces to ROIs
        cnt = 1;
        for j = 1:nrois
            % skip empty ROIs
            if isempty(rois(i, j).activity)
                continue;
            end
            rois(i, j).activity = outputs{1}(cnt, :);
            cnt = cnt + 1;
        end
    end
end