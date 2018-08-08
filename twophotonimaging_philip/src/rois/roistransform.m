function rois = roistransform(rois, tforms)
    % ROISTRANSFORM apply an affine transform to ROIs footprints
    %
    % rois = roistransform(rois, tforms)
    %
    % This function applies an inverse transform to the footprint of each ROI.
    % The corresponding forward transform is used to detect ROIs whose footprint
    % will be cut by the inverse transform and remove them.
    %
    % INPUTS
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %                      or an empty scalar if the ROI is missing
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %   tforms - affine transforms, as either
    %       1) a [Z] vector of affine2d objects
    %       2) a cellarray of the previous type (if several stacks)
    %
    % OUTPUTS
    %   rois - similar structure as 'rois' input
    %
    % REMARKS
    %   If input ROIs have an 'activity' field, it will be emptied to ensure
    %   that one can't use traces incoherent with footprints.
    %
    %   "Inverse" and "forward" transforms are defined wrt. the output of
    %   'stacksregister_affine' function. Typically, one wants to register
    %   images together (= apply the forward tranform), detect ROIs with these
    %   transformed images and transform back the ROIs (= apply inverse
    %   transform) to the get ROIs for the original images.
    %
    % EXAMPLE
    %   % aligned averages of stacks to the first one
    %   [tforms, avgs_affine] = stacksregister_affine(avg_regs, avg_regs{1});
    %
    %   % get some ROIs with the GUI
    %   rois_affine = roisgui(avgs_affine);
    %
    %   % transform ROIs in the original stacks frames
    %   rois = roistransform(rois_affine, tforms);
    %
    % SEE ALSO stacksregister_affine, stacktransform

    if ~exist('rois', 'var')
        error('Missing rois argument.')
    end

    if ~exist('tforms', 'var')
        error('Missing tforms argument.')
    elseif ~iscell(tforms)
        tforms = {tforms};
    end

    nstacks = numel(tforms);
    for ii = 1:nstacks
        varname = sprintf('tforms{%d}', ii);
        validateattributes(tforms{ii}, {'affine2d'}, {}, '', varname);
    end

    stacks_dims = cellfun(@(x) [nan, nan, numel(x), inf], tforms, 'un', false);
    rois = roischeck(rois, stacks_dims);
    nrois = size(rois, 2);

    for i = 1:nstacks
        % size of a frame, from the first ROI with non-empty footprint
        idx = find(~cellfun(@isempty, {rois(1, :).footprint}), 1);
        [nx, ny] = size(rois(1, idx).footprint);

        % masks of pixels outside of forward transform
        masks = arrayfun( ...
            @(x) ~stacktransform(true(nx, ny), x), tforms{i}, 'un', false);

        % transform each ROI footprint
        for j = 1:nrois
            roi = rois(i, j);

            % skip missing ROI
            if isempty(roi.footprint)
                continue;
            end

            % remove ROI outside of transformed area ...
            if any(roi.footprint(masks{roi.zplane}))
                rois(i, j).footprint = [];

            % ... or transform ROI footprint
            else
                footprint = full(roi.footprint);
                tf_inv = tforms{i}(roi.zplane).invert();
                footprint = stacktransform(footprint, tf_inv);
                rois(i, j).footprint = sparse(footprint);
            end
        end
    end

    % empty 'activity' field, if any, and issue a warning
    if isfield(rois, 'activity')
        [rois.activity] = deal([]);
        warning('Activity field have been emptied to avoid incoherent traces.')
    end
end