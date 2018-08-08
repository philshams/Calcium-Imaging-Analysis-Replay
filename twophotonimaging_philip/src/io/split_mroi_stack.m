function stacks = split_mroi_stack(stack, header)
    % SPLIT_MROI_STACK divide a stack with ScanImage ROIs into mulitple stacks
    %
    % stacks = split_mroi_stack(stack, header)
    %
    % This function virtually splits a stack into multiple stacks, based on
    % ScanImage Tiff header information.
    %
    % INPUTS
    %   stack - a stack of frames, as a [X Y Z Channels Time] array-like object
    %   header - TIFF header, as a structure array (1 frame needed)
    %
    % OUTPUTS
    %   stacks - ScanImage ROIs, as a cellarray of [X Y Z Channels Time]
    %       array-like objects (TensorView)
    %
    % EXAMPLE
    %   % single stack example
    %   stackpath = uigetdir();  % get a directory of TIFF files (split stack)
    %   [stack, headers] = stacksload(stackpath);
    %   stacks = split_mroi_stack(stack, headers);
    %
    % SEE ALSO stacksload

    if ~exist('stack', 'var')
        error('Missing stack argument.')
    end

    if ~exist('header', 'var')
        error('Missing header argument.')
    end

    stackcheck(stack);
    validateattributes(header, {'struct'}, {'nonempty'}, '', 'header');

    if ~all(isfield(header, {'Artist', 'Software'}))
        error('Expected header structure to have Artist and Software fields.');
    end

    % get relevant infromatio for TIFF header
    artist_info = header(1).Artist;
    software_info = header(1).Software;

    % retrieve ScanImage ROIs information from json-encoded string
    artist_info = artist_info(1:find(artist_info == '}', 1, 'last'));
    artist = jsondecode(artist_info);
    si_rois = artist.RoiGroups.imagingRoiGroup.rois;

    % retrieve values for z-planes
    zs_txt = regexp(software_info, ...
        'SI\.hStackManager\.zs = (.+?)(?m:$)', 'tokens', 'once');
    zs = str2num(zs_txt{:});  %#ok<ST2NM>
    nz = numel(zs);

    % order z-planes if they are not
    zs_asc = sort(zs(:), 1, 'ascend');
    [zs_desc, desc_idx] = sort(zs(:), 1, 'descend');

    if isequal(zs(:), zs_asc) || isequal(zs(:), zs_desc)
        zs_idx = 1:nz;
    else
        warning('unordered z-planes, re-ordered as [%s].', num2str(zs_desc'));
        zs_idx = desc_idx;
    end

    % get ROIs dimensions for each z-plane
    n_si_rois = numel(si_rois);
    n_rows = cell(nz, n_si_rois);
    for i = 1:nz
        for j = 1:n_si_rois
            if si_rois(j).discretePlaneMode && ~ismember(zs(i), si_rois(j).zs)
                continue;
            end
            n_rows{i, j} = si_rois(j).scanfields.pixelResolutionXY(2);
        end
    end

    % deduce flyback frames from most filled z-plane
    n_rows_sum = arrayfun(@(x) sum([n_rows{x, :}]), 1:nz);
    [n_rows_max, idx_rows] = max(n_rows_sum);
    n_rois_max = numel([n_rows{idx_rows, :}]);
    n_flyback = (size(stack, 1) - n_rows_max) / max(1, (n_rois_max - 1));

    % get ROIS for each z-plane
    stack_views = cell(nz, n_si_rois);
    for i = 1:nz
        offset = 0;
        for j = 1:n_si_rois
            if isempty(n_rows{i, j})
                continue;
            end
            rows = offset + (1:n_rows{i, j});
            stack_views{i, j} = TensorView(stack, rows, [], zs_idx(i));
            offset = offset + n_rows{i, j} + n_flyback;
        end
    end

    % concatenate multi-planes ScanImage ROIs
    stacks = cell(1, n_si_rois);
    for i = 1:n_si_rois
        views_mask = ~cellfun(@isempty, stack_views(:, i));
        if nnz(views_mask) == 1
            stacks{i} = stack_views{views_mask, i};
        else
            stacks{i} = TensorStack(3, stack_views{views_mask, i});
        end
    end
end