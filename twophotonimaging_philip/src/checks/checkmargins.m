function margins = checkmargins(stack, margins)
    % CHECKMARGINS clean input margins to crop stack borders
    % 
    % margins = checkmargins(stack, margins)
    %
    % This function is an helper function to clean other functions inputs.
    %
    % INPUTS
    %   stack - a stack of frames, as a [X Y Z Channels Time] array-like object
    %   margins - number of pixels to remove from borders,
    %       as either
    %       1) a scalar (same margins for X and Y)
    %       2) a vector of two scalars (separate margins for X and Y)
    %
    % OUTPUTS
    %   margins - a vector of two scalars
    %
    % SEE ALSO stacksregister_dft, stacksregister_demons

    if numel(margins) > 2
        error('Expected margins to have at most 2 elements.');
    end

    if numel(margins) == 1
        margins = [margins, margins];
    end

    [nx, ny, ~] = size(stack);
    max_nx = fix(nx / 2);
    max_ny = fix(ny / 2);

    nx_attr = {'scalar', 'integer', '>=', 0, '<=', max_nx};
    ny_attr = {'scalar', 'integer', '>=', 0, '<=', max_ny};
    validateattributes(margins(1), {'numeric'}, nx_attr, '', 'margins(1)');
    validateattributes(margins(2), {'numeric'}, ny_attr, '', 'margins(2)');
end