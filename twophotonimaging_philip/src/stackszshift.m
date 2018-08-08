function [stacks, xyshifts] = stackszshift(stacks, zshifts, xyshifts)
    % STACKSZSHIFT move up/down stacks on the z-axis
    %
    % [stacks, xyshifts] = stackszshift(stacks, zshifts, xyshifts)
    %
    % This function creates a different view on data, as if z-planes were
    % translated up or down. Data corresponding to missing z-planes are replaced
    % by zeros.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   zshifts - z-axis shift to apply to each stack, as a [#Stacks] vector
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % OUTPUTS
    %   stacks - transformed stacks, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   xyshifts - transformed (x,y)-shifts, as either
    %       1) an empty array (if none provided)
    %       2) a [2 Z Time] array
    %       3) a cellarray of the previous types (if several stacks)
    % 
    % SEE ALSO stacksregister_dft, stacksgui

    if ~exist('stacks', 'var')
        error('Missing stack argument.')
    end
    unpack = ~iscell(stacks);

    if ~exist('xyshifts', 'var')
        xyshifts  = [];
    end

    [stacks, xyshifts] = stackscheck(stacks, xyshifts);
    nstacks = numel(stacks);

    if ~exist('zshifts', 'var')
        error('Missing zshifts argument.')
    end
    validateattributes(zshifts, {'numeric'}, {'numel', nstacks}, '', 'zshifts');
    for ii = 1:nstacks
        nz = size(stacks{ii}, 3);
        zattr = {'>', -nz, '<', nz};
        varname = sprintf('zshifts(%d)', ii);
        validateattributes(zshifts(ii), {'numeric'}, zattr, '', varname);
    end

    % shift each stack and its corresponding (x,y)-shifts
    for ii = 1:nstacks
        stacks{ii} = zshift_stack(stacks{ii}, zshifts(ii));
        xyshifts{ii} = zshift_xys(xyshifts{ii}, zshifts(ii));
    end

    % do not return cellarrays if only one stack
    if unpack && nstacks == 1
        stacks = stacks{1};
        xyshifts = xyshifts{1};
    end
end

function stack = zshift_stack(stack, zshift)
    % move up/down a stack, inserting empty data to compensate

    % skip if there is no z-offset
    if zshift == 0
        return;
    end

    [nx, ny, nz, nc, nt] = size(stack);

    % create a view on the original data
    z_idx = (1:nz) - zshift;
    z_idx = z_idx(z_idx > 0 & z_idx <= nz);
    ts_view = TensorView(stack, [], [], z_idx);

    % create fake data to compensate for z-shift
    value = zeros(1, 'like', stack(1, 1, 1, 1, 1));
    const_view = ConstantView(value, [nx, ny, abs(zshift), nc, nt]);

    % assemble both tensors
    if zshift > 0
        stack = TensorStack(3, const_view, ts_view);
    else
        stack = TensorStack(3, ts_view, const_view);
    end
end

function xyshifts = zshift_xys(xyshifts, zshift)
    % move up/down (x,y)-shifts

    % skip if there is no z-offset or no (x,y)-shifts
    if zshift == 0 || isempty(xyshifts)
        return;
    end

    [~, nz, nt] = size(xyshifts);

    z_idx = (1:nz) - zshift;
    z_idx = z_idx(z_idx > 0 & z_idx <= nz);
    xyshifts_view = xyshifts(:, z_idx, :);
    zeros_shifts = zeros(2, abs(zshift), nt);

    if zshift > 0
        xyshifts = cat(2, zeros_shifts, xyshifts_view);
    else
        xyshifts = cat(2, xyshifts_view, zeros_shifts);
    end
end