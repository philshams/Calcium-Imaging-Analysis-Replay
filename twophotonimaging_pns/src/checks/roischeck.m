function rois = roischeck(rois, stacks_dims)
    % ROISCHECK check if ROIs are valid structures or issue errors
    %
    % rois = roischeck(rois, stacks_dims)
    %
    % This function is an helper function to clean other functions inputs.
    %
    % INPUTS
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %                      or an empty scalar if the ROI is missing
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %   stacks_dims - (optional) default: []
    %       dimensions (X, Y, Z, Channels) of stacks as either
    %       1) a vector of 4 elements
    %       2) a cellarray of the previous type (if several stacks)
    %
    % OUTPUTS
    %   rois - similar structure as 'rois' input
    %
    % REMARKS
    %   If a 1D structure array is provided, i.e one set of ROIs, then ROIs will
    %   be copied for each stack, returning a [#Stacks #ROIS] structure array.
    %
    % SEE ALSO stackscheck, stackcheck

    if ~exist('rois', 'var')
        error('Missing rois argument.');
    elseif ~isstruct(rois)
        error('Expected rois to be a structure array.');
    end

    if ~exist('stacks_dims', 'var') || isempty(stacks_dims)
        stacks_dims = cell(1, size(rois, 1));
    elseif ~iscell(stacks_dims)
        stacks_dims = {stacks_dims};
    end
    nstacks = numel(stacks_dims);

    % TODO check dims

    if size(rois, 1) == 1
        rois = repmat(rois, nstacks, 1);
    elseif size(rois, 1) ~= nstacks
        error('Number of ROIs sets is different from number of stacks.');
    end

    % check mandatory fields
    if ~isfield(rois, 'footprint')
        error('Missing footprint field in rois structure array.');
    end

    if ~isfield(rois, 'zplane')
        error('Missing zplane field in rois structure array.');
    end

    if ~isfield(rois, 'channel')
        error('Missing channel field in rois structure array.');
    end

    % check each set of ROIs
    for ii = 1:nstacks
        dims = clean_dims(stacks_dims{ii});
        check_fields(rois(ii, :), dims, ii);
    end
end

function dims = clean_dims(stack_dims)
    % helper function to return appropriate dimensions for varying inputs
    dims = [nan, nan, inf, inf];
    ndims = min(numel(stack_dims), 4);
    dims(1:ndims) = stack_dims(1:ndims);
end

function check_fields(rois, dims, stack_idx)
    % check ROIs fields

    % template use to report erroneous field
    varname_tpl = sprintf('rois(%d,%%d).%%s', stack_idx);

    % split dimensions
    cdims = num2cell(dims);
    [nx, ny, nz, nc] = cdims{:};

    % attributes of checked fields
    footprint_attr = {'size', [nx, ny]};
    zplane_attr = {'integer', '>=', 1, '<=' nz, 'nonempty'};
    channel_attr = {'integer', '>=', 1, '<=' nc, 'nonempty'};

    % check each ROI
    for ii = 1:numel(rois)
        roi = rois(ii);

        % skip empty ROIs
        if isempty(roi.footprint)
            continue;
        end

        % check footprint field
        varname = sprintf(varname_tpl, ii, 'footprint');
        validateattributes(roi.footprint, ...
            {'numeric', 'logical'}, footprint_attr, '', varname);

        % check z-plane field
        varname = sprintf(varname_tpl, ii, 'zplane');
        validateattributes(roi.zplane, {'numeric'}, zplane_attr, '', varname);

        % check channel field
        varname = sprintf(varname_tpl, ii, 'channel');
        validateattributes(roi.channel, {'numeric'}, channel_attr, '', varname);
    end
end