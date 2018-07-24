function [tp, fp, ncells] = celldetectperf(labels, cellpos, thresh, detailed)
    % TODO documentation
    % TODO check inputs

    if ~exist('detailed', 'var')
        detailed = false;
    end

    % retrieve real position of existing cells
    nframes = size(labels, 3);
    cellpos_real = cell(size(cellpos));
    for ii=1:nframes
        cellpos_real{ii} = realpositions(labels(:, :, ii));
    end

    % compute true positives, false positives and number of real cells
    [tp, fp, ncells] = ...
        cellfun(@(x, y) perf(x, y, thresh), cellpos, cellpos_real);

    % sum results if details not asked
    if ~detailed
        tp = sum(tp);
        fp = sum(fp);
        ncells = sum(ncells);
    end
end

function cellpos = realpositions(labels)
    % returns real positions of cells given their masks

    cells_idx = nonzeros(unique(labels));
    cellpos = zeros(numel(cells_idx), 2);
    for ii=1:numel(cells_idx)
        [xs, ys] = find(labels == cells_idx(ii));
        cellpos(ii, :) = mean([xs, ys], 1);
    end
end

function [tp, fp, ncells] = perf(cellpos, cellpos_real, thresh)
    % various indicators of perfomance, comparing detected cells and real ones

    % closest real cell for each detected cell
    [dmat, imat] = pdist2(cellpos_real, cellpos, 'euclidean', 'Smallest', 1);

    % number of detected cells associated to a real cell
    filt_imat = imat(dmat < thresh);
    idx = unique(filt_imat);

    counts = zeros(size(idx));
    for ii=1:numel(idx)
        counts(ii) = sum(filt_imat == idx(ii));
    end

    % true positives, false positives and total number of cells
    tp = length(counts);
    fp = sum(dmat > thresh) + sum(counts) - tp;
    ncells = size(cellpos_real, 1);
end
