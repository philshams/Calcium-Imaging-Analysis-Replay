function [rois, regavg, xyshifts, ref_stack_id] = importadata(dirnames, varargin)
% IMPORTADATA convert data from old pipeline into new format
%
% [rois, regavg, xyshifts, ref_stack_id] = importadata(dirnames, ...)
%
% INPUTS
%    dirnames - string or cells array of strings with paths to adata files
%
% NAME-VALUE PAIR INPUTS (optional)
%    verbose - default: false
%        whether to print progress to screen
%    masks - default: 'new_lbl_mask'
%        name of field to load ROIs footprints
%    activity - default: 'tc_filt_LC_dFoF'
%        name of field to load activity from
%    spikes - default: 'spikes_LC'
%        name of field to load spikes from
%    annotations - default: 'celllabels'
%        name of field to load annotation from
%
% OUTPUTS
%   rois - array of ROI structures
%   regavg - cell array average registered images for each stack
%   xyshifts - cell array of motion correction shifts for each stack
%   ref_stack_id - index of stack originally used to select ROIs

% parse inputs
if ~exist('dirnames', 'var')
    error('Missing directory names argument.');
elseif ~iscell(dirnames)
    dirnames = {dirnames};
end

parser = inputParser;
parser.addParameter('verbose', false, @islogical);
parser.addParameter('masks', 'new_lbl_mask', @ischar);
parser.addParameter('activity', 'tc_filt_LC_dFoF', @ischar);
parser.addParameter('spikes', 'spikes_LC', @ischar);
parser.addParameter('annotations', 'celllabels', @ischar);

parser.parse(varargin{:});
verbose = parser.Results.verbose;
activity_field = parser.Results.activity;
spikes_field = parser.Results.spikes;
annotations_field = parser.Results.annotations;
masks_field = parser.Results.masks;

% get list of all slice files and check that numbers match
stacknum = numel(dirnames);
slicefiles = cell(1, stacknum);
for ii=1:stacknum
    d = dir(fullfile(dirnames{ii}, '*slice*.mat'));
    slicefiles{ii} = {d.name};
end

% check all stacks have same number of slices
slicenum = cellfun(@numel, slicefiles);
if verbose
    cellfun(@(dir, num) fprintf('%s, %d slices\n', dir, num), ...
            dirnames, num2cell(slicenum));
end

if ~all(slicenum == slicenum(1))
    error('Number of slice files did not match.');
end

slicenum = slicenum(1);

% save warning state and disable variableNotFound warning
warn_backup = warning;
warning('off', 'MATLAB:load:variableNotFound');

% load data from slice files
slice = cell(stacknum, slicenum);
for istack=1:stacknum
    if verbose; fprintf('Loading stack %s\n', dirnames{istack}); end
    for islice=1:slicenum
        filename = fullfile(dirnames{istack}, slicefiles{istack}{islice});
        slice{istack,islice} = load(filename, ...
            'stackId', masks_field, 'ref_stack', 'xyshift', 'regavg', ...
            activity_field, spikes_field, annotations_field);
    end
end

% restore warning state
warning(warn_backup);

% for some reason, in some datasets ref_stack field in missing in some files
idx = cellfun(@(s) isfield(s,'ref_stack'), slice);

% ref stack should be same for all slices so use first
ref_stacks = cellfun(@(s) s.ref_stack, slice(idx), 'un', false);
if ~all(strcmp(ref_stacks(:), ref_stacks{1}))
    error('Ref_stack did not match across stacks/slices.');
end

% check there is one and only one reference stack
stackIds = cellfun(@(s) s.stackId, slice(:,1), 'un', false);
ref_stack_id = find(strcmp(stackIds, ref_stacks{1}));
if numel(ref_stack_id) > 1
    error('%d reference stacks found with stack ID %s.', ...
          numel(ref_stack_id), ref_stacks{1});
end

% retrieve ROIs masks from ref. stack, or another if ref. stack is not available
masks = cell(1, slicenum);
stacks_ids = [ref_stack_id, 1:stacknum];

for istack=1:numel(stacks_ids)
    id = stacks_ids(istack);
    for islice=1:slicenum
        % skip if masks already found or not available in this stack
        if ~isempty(masks{islice}) || ~isfield(slice{id, islice}, masks_field)
            continue;
        end
        masks{islice} = segmentframe(slice{id, islice}.(masks_field));
    end
end

% this is not saved anywhere but cell labels should be in the first stack
annotation_stack_id = 1;

% setup output variables
rois = cell(1, slicenum);
regavg = cell(1, stacknum);
xyshifts = cell(1, stacknum);

for islice=1:slicenum
    new_rois = cell(1, stacknum);

    for istack=1:stacknum
        curr_slice = slice{istack, islice};

        % get slice related information
        xyshifts{istack}(:,islice,:) = permute(curr_slice.xyshift, [2, 3, 1]);
        regavg{istack}(:,:,islice) = curr_slice.regavg;

        % retrieve ROIs information (or skip if no available masks)
        if isempty(masks{islice})
            continue;
        end
        nrois = numel(masks{islice});

        % assign activity
        if isfield(curr_slice, activity_field)
            activity = ...
                mat2cell(curr_slice.(activity_field), ones(nrois, 1))';
        else
            activity = [];
        end

        % assign spikes
        if isfield(curr_slice, spikes_field)
            spikes = ...
                mat2cell(curr_slice.(spikes_field), ones(nrois, 1))';
        else
            spikes = [];
        end

        % assign annotations
        annot_slice = slice{annotation_stack_id,islice};
        if isfield(annot_slice, annotations_field)
            annotations = annot_slice.(annotations_field)';
        else
            annotations = [];
        end

        new_rois{istack} = struct( ...
            'footprint', masks{islice}, 'zplane', islice, 'channel', 1, ...
            'activity', activity, 'spikes', spikes, ...
            'annotations', annotations);
    end

    rois{islice} = cat(1, new_rois{:});
end

% concatenate ROIs of all slices
rois = cat(2, rois{:});

end

function masks = segmentframe(frame)
    % extract individual footprints from a label matrix

    cellidx = unique(nonzeros(frame));
    ncells = numel(cellidx);
    dim = size(frame);

    masks = cell(1, ncells);
    for i = 1:ncells
        [r, c] = find(frame == cellidx(i));
        masks{i} = sparse(r, c, 1, dim(1), dim(2));
    end
end
