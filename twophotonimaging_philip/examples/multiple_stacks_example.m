%% Introduction
%
% This example highlights a simple workflow to deal with several stacks at the
% same time, sharing a similar set of ROIs.
%
% Here we will assume that you already had a look to 'basic_example.m' before,
% and won't remind the purpose of each parameter of each function ;-).

%% Loading data
% First, let's load several stacks, using 'uipickfiles' interface to pick stack
% folders, .bin files and even idividual .tif files.

stackspath = uipickfiles('REFilter', '\.tiff?$|\.bin$');

% 'stacksload' function can take a cellarray of paths to load all stacks
% together.
stacks = stacksload(stackspath);

% Remarks:
% 'uipickfiles' is an external (really practical) dependency that is installed
% with the toobox (if you ran the toolbox_setup function).
% By default, 'stacksload' behaves differently if you provide one or several
% stacks paths. To be sure to manipulate a cellarray of stacks, use the
% 'forcecell' option.

%% Frames registration
% Similarly to the single stack case, you need reference images to register
% stacks frames.

% Here we rely on 'stackstemplate' to create one template per stack.
avg_refs = stackstemplate(stacks, 10, 20, 'margins', 50, 'refchannel', 1);

% We also need to pick a stack as our reference stack. This one will be our
% reference to align other stacks.
ref_id = 1;

% (x,y)-shifts are now computed with 'stacksregister_dft', using each reference
% image for each stack, and then registering all reference images to the
% reference stack's.
xyshifts = stacksregister_dft(stacks, avg_refs, 'refstack', ref_id, ...
    'margins', 50, 'useparfor', true, 'verbose', true,'refchannel', 1);

% Do not forget to visually check (x,y)-shifts.
xysshow(xyshifts);

% Remarks:
% Choosing a reference stack should be done manually, inspecting them. One can
% use 'roisgui' function to display stacks and their corresponding reference
% images.

%% Average projection
% Here we will just compute the registered average images of each stack, which
% will be used later on to align stacks and find ROIs.
avg_regs = stacksmean(stacks, xyshifts, 'chunksize', 10, 'useparfor', true);

%% Pre-computing ROIs
% This stage is only applied on one stack as we want to keep the same set of
% ROIs for all stacks. Here we choose the reference stack but we don't have too.

cellpos = celldetect_donut(avg_regs{ref_id}, 'GCaMP6_Soma_Ioana_tp77_fp71');
rois = cellsegment(avg_regs{ref_id}, cellpos, 'GCaMP6_Soma_Ioana_lda');

%% Displaying and editing ROIs
% All these steps are done using 'roisgui'.

% As we are passing one set of ROIs to 'roisgui', it gets replicated for each
% stack. Make sure to use the 'replicate ROI(s)' option in the interface to have
% the same set of ROIs for all stacks in the end.
edited_rois = roisgui(stacks, xyshifts, mef_data.rois, 'mean reg. images', mef_data.avg_regs_tf);

mef_data.rois(1,:) = mef_data.rois(2,:);


% size(mef_data.rois)
% edited_rois(1,:) = edited_rois(2,:);

%% Extracting time series
% This step is handled by 'stacksextract' function, for all stacks with their
% own set of ROIs.

offsets = stacksoffsets_gmm(stacks);
ts = stacksextract(stacks, edited_rois, xyshifts, ...
                   'chunksize', 100, 'offsets', offsets, 'verbose', true);

% Do not forget to visually check estimated offsets.
rng(1);  % seed random number generator for reproducibility
offsetsshow(stacks, offsets);

%% Saving result
% Once everything have been done, save your results and parameters used to get
% them.

save('multiple_stacks_example.mat', 'stackspath', 'avg_refs', 'avg_regs', ...
     'ref_id', 'xyshifts', 'cellpos', 'rois', ...
     'edited_rois', 'ts', 'offsets');