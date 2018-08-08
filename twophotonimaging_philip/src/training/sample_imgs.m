function [imgs, labels, idx] = sample_imgs(data, nsamples, forbidden)
    % TODO documentation
    % TODO check inputs

    if ~exist('forbidden', 'var')
        forbidden = [];
    end

    % preallocated returned arrays
    [nx, ny, nframes] = size(data, 'imgs');
    imgs = nan(nx, ny, nsamples);
    labels = nan(nx, ny, nsamples);
    idx = nan(1, nsamples);

    % allowed indices
    allowed = true(1, nframes);
    allowed(forbidden) = false;
    indices = 1:nframes;

    % sample from allowed indices
    rng(1);
    found = 0;
    while found < nsamples
        inext = datasample(indices(allowed), 1);
        allowed(inext) = false;

        nlabels = nnz(unique(data.labels(:, :, inext)));
        if nlabels == 0
            continue
        end

        found = found + 1;
        imgs(:, :, found) = data.imgs(:, :, inext);
        labels(:, :, found) = data.labels(:, :, inext);
        idx(found) = inext;
    end
end