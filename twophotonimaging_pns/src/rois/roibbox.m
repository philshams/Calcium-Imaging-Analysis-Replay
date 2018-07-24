function [r, c] = roibbox(footprint, dim)
    % ROIBBOX defines a bounding box around a ROI, given its footprint
    %
    % [r, c] = roibbox(footprint, dim)
    %
    % INPUTS
    %   footprint - ROI footprint, as a [X Y] array
    %   dim - bounding box side length, as a positive integer
    %
    % OUPUTS
    %   r - indices for rows, as a vector
    %   c - indices for columns, as a vector
    %
    % REMARKS
    %   Non-zeros coefficients of the footprint are used to delineate it.
    %
    %   The bounding box is shrunk if it goes outside image limits. It is also
    %   expanded to a minimal size to entirely contain the footprint.

    if ~exist('footprint', 'var')
        error('Missing footprint argument.');
    end

    if ~exist('dim', 'var')
        error('Missing dim argument.');
    end

    validateattributes(footprint, ...
        {'numeric', 'logical'}, {'2d', 'nonempty'}, '', 'footprint');
    if nnz(footprint) == 0
        error('Expected footprint to contain at least one non-zero element.');
    end

    dim_attr = {'scalar', 'positive', 'integer'};
    validateattributes(dim, {'numeric'}, dim_attr, '', 'dim');

    % find borders of the ROI
    roi_mask = footprint ~= 0;
    framedim = size(roi_mask);
    r = [find(sum(roi_mask, 2), 1, 'first'), find(sum(roi_mask, 2), 1, 'last')];
    c = [find(sum(roi_mask, 1), 1, 'first'), find(sum(roi_mask, 1), 1, 'last')];

    % indices of the frame to use
    dr = max(0, (dim - r(2) + r(1)) / 2);
    r = max(round(r(1)-dr), 1) : min(round(r(2)+dr), framedim(1));

    dc = max(0, (dim - c(2) + c(1)) / 2);
    c = max(round(c(1)-dc), 1) : min(round(c(2)+dc), framedim(2));
end