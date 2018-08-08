function [dff, f0] = extractdff_prc(traces, perc, half_win)
    % EXTRACTDFF_PRC transform raw traces into dF/F0 traces using percentiles
    %
    % [dff, f0] = extractdff_prc(traces, perc, half_win)
    %
    % This function uses percentiles to estimate the F0 baseline, possibly with
    % a sliding window.
    %
    % INPUTS
    %   traces - raw signals, as a [#ROIs Time] array
    %   perc - percentile of each trace used as F0 baseline
    %   half_win - (optional) default: []
    %       half-width of a sliding window, in frames
    %
    % OUTPUTS
    %   dff - delta F over F0, as a [#ROIs Time] array
    %   f0 - F0 baseline, as a [#ROIs Time] array
    %
    % REMARKS
    %   If a sliding window is used, the estimated F0 is fixed constant close to
    %   the borders, where there is not enough data to fill the whole window.
    %
    % SEE ALSO roisfilter, stacksextract

    if ~exist('traces', 'var')
        error('Missing traces argument.')
    end
    validateattributes(traces, {'numeric'}, {'nonempty', '2d'}, '', 'traces');
    [nrois, nt] = size(traces);

    if ~exist('perc', 'var')
        error('Missing traces argument.')
    end
    perc_attr = {'scalar', 'nonnegative', '<=', 100};
    validateattributes(perc, {'numeric'}, perc_attr, '', 'perc');

    if ~exist('half_win', 'var')
        half_win = [];
    elseif ~isempty(half_win)
        half_attr = {'scalar', 'integer', 'positive', '<=', floor(nt / 2)};
        validateattributes(half_win, {'numeric'}, half_attr, '', 'half_win');
    end

    % constant F0
    if isempty(half_win)
        f0 = prctile(traces, perc, 2);
        f0 = repmat(f0, 1, nt);

    % non-constant F0
    else
        % compute all F0 baselines together, as a percentile of a running window
        f0 = zeros(nrois, nt);
        for ii = 1:nrois
            f0(ii, :) = running_percentile(traces(ii, :), half_win * 2, perc);
        end

        % fix edges issues, due to zero-padding by previous function
        f0(:, 1:half_win-1) = repmat(f0(:, half_win), 1, half_win - 1);
        f0(:, end-half_win+1:end) = repmat(f0(:, end-half_win), 1, half_win);
    end

    dff = (traces - f0) ./ f0;
end