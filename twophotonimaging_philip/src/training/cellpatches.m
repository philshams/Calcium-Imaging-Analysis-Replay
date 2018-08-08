function [patches, indices] = cellpatches(frame, cellpos, celldiam)
    % TODO documentation
    % TODO input checks

    [nx, ny] = size(frame);
    valid_cells = all(cellpos - celldiam >= 1, 2) & ...
                  all(cellpos(:, 1) + celldiam <= nx, 2) & ...
                  all(cellpos(:, 2) + celldiam <= ny, 2);
    cellpos = cellpos(valid_cells, :);

    ncells = size(cellpos, 1);
    npixels = (celldiam * 2 + 1);

    patches = zeros(ncells, npixels, npixels);
    indices = zeros(ncells, npixels, npixels);
    for ii=1:ncells
        coords = cellpos(ii, :);
        xbar = round(coords(1));
        ybar = round(coords(2));

        xs = xbar-celldiam:xbar+celldiam;
        ys = ybar-celldiam:ybar+celldiam;
        patch = double(frame(xs, ys));
        pfeat = (patch - mean(patch(:))) / std(patch(:));
        patches(ii, :, :) = pfeat;

        [mxs, mys] = meshgrid(xs, ys);
        indices(ii, :, :) = sub2ind(size(frame), mxs, mys);
    end
end
