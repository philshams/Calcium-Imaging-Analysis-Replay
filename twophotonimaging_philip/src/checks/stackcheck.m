function stackcheck(stack, xyshifts, dims, varname)
    % STACKCHECK check if a stack is valid or issue errors
    %
    % stackcheck(stacks, xyshifts, dims)
    %
    % This function is an helper function to clean other functions inputs.
    %
    % INPUTS
    %   stack - a stack of frames, as a [X Y Z Channels Time] array-like object
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as a [2 Z Time] array
    %   dims - (optional) default: []
    %       stack dimensions, as an array of 5 elements at most
    %   varname - (optional) default: 'stacks'
    %       name of checked variable to report in case of error
    %
    % SEE ALSO stackscheck

    if ~exist('stack', 'var')
        error('Missing stack argument.');
    end

    if ~exist('xyshifts', 'var')
        xyshifts = [];
    end

    if ~exist('dims', 'var') || isempty(dims)
        dims = [];
    else
        posint_attr = {'vector', 'integer', 'positive'};
        validateattributes(dims, {'numeric'}, posint_attr, '', 'dims');
        if numel(dims) > 5
            error('Expected dims to have at most 5 elements.');
        end
    end

    if ~exist('varname', 'var') || isempty(varname)
        varname = 'stack';
    end

    % check stack
    stack_dims = nan(1, 5);
    stack_dims(1:numel(dims)) = dims;

    if ~isnumeric(stack) && ~islogical(stack)
        error(['Expected stack to be a numeric or a logical array. ', ...
               'Instead its type was %s.'], class(stack));
    end

    stack_cls = {class(stack)};  % do not check class
    stack_attr = {'size', stack_dims};
    validateattributes(stack, stack_cls, stack_attr, '', varname);

    % check (x,y)-shifts, if any
    if isempty(xyshifts)
        return;
    end

    [~, ~, nz, ~, nt] = size(stack);
    xy_attr = {'3d', 'size', [2, nz, nt]};
    validateattributes(xyshifts, {'numeric'}, xy_attr, '', 'xyshifts');
end
