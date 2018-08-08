function [stacks, xyshifts] = stackscheck(stacks, xyshifts, dims, varname)
    % STACKSCHECK check if stacks are valid or issue errors
    %
    % [stacks, xyshifts] = stackscheck(stacks, xyshifts, dims, varname)
    %
    % This function is an helper function to clean other functions inputs.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %   dims - (optional) default: []
    %       stack dimensions, as an array of 5 elements at most
    %   varname - (optional) default: 'stacks'
    %       name of checked variable to report in case of error
    %
    % OUTPUTS
    %   stacks - stacks of frames, as a cellarray
    %   xyshifts - shifts, as a cellarray
    %
    % SEE ALSO stacksload, stacksmean, stacksminmax

    if ~exist('stacks', 'var')
        error('Missing stacks argument.');
    elseif ~iscell(stacks)
        stacks = {stacks};
    end
    nstacks = numel(stacks);

    if ~exist('xyshifts', 'var') || isempty(xyshifts)
        xyshifts = cell(1, nstacks);
    elseif ~iscell(xyshifts)
        xyshifts = {xyshifts};
    end

    if ~exist('dims', 'var')
        dims = [];
    end

    if ~exist('varname', 'var') || isempty(varname)
        varname = 'stacks';
    end

    if numel(xyshifts) ~= nstacks
        error('Number of xyshifts is different from number of stacks.');
    end

    for ii = 1:nstacks
        element_name = sprintf('%s{%d}', varname, ii);
        stackcheck(stacks{ii}, xyshifts{ii}, dims, element_name);
    end
end
