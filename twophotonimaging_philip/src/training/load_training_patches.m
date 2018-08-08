function [patches, categories] = load_training_patches(train_imgs, train_labels, celldiam)
    % TODO documentatiom
    % TODO input checks and default values

    % preallocate patches and label arrays
    nframes = size(train_imgs, 3);
    ncells = sum(arrayfun(@(x) nnz(unique(train_labels(:, :, x))), 1:nframes));
    npixels = celldiam * 2 + 1;

    patches = nan(ncells, npixels, npixels);
    categories = nan(ncells, npixels, npixels);

    % retrieve training data
    curr_idx = 1;
    for ii=1:nframes
        frame = train_imgs(:, :, ii);
        labels = train_labels(:, :, ii);

        idx = nonzeros(unique(labels(:)));
        [xs, ys] = arrayfun(@(x) find(labels == x), idx, 'un', false);
        cellpos = [cellfun(@mean, xs), cellfun(@mean, ys)];
        [feats, indices] = cellpatches(frame, cellpos, celldiam);

        new_idx = curr_idx + size(feats, 1);
        patches(curr_idx:new_idx-1, :, :) = feats;
        categories(curr_idx:new_idx-1, :, :) = labels(indices) ~= 0;

        curr_idx = new_idx;
    end

    patches = patches(1:curr_idx-1, :, :);
    categories = categories(1:curr_idx-1, :, :);
end
