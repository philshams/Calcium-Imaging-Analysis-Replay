%% Introduction
%
% This example illustrated a simple workflow using the toolbox functions.
%
% Major steps are:
% - loading data,
% - registering frames,
% - computing informative projections,
% - detecting ROIs,
% - visualizing data and ROIs,
% - extract ROIs mean traces.
%
% Don't forget to use 'help' command to get more information on functions ;-).

%% Loading data
% First of all, you must locate on your computer a 'stack', as a folder
% containing a set of .tif files.

% Here we use a simple GUI provided by Matlab to pick a such folder. You will
% need a stack with about 1000 frames for this example.
stackpath = uigetdir();

% You can also pick a .bin file (IRIS format) as follows (uncomment to use it):
% [filename, pathname] = uigetfile('*.bin');
% stackpath = fullfile(pathname, filename);

% To load this stack, we use 'stacksload' function.
stack = stacksload(stackpath);

% If you look at it, you will see that it is a 5D tensor, organized as follows:
% X, Y, Z, channels and time.
[nx, ny, nz, nc, nt] = size(stack);
fprintf('stack size is: [%d, %d, %d, %d, %d]\n', nx, ny, nz, nc, nt);

% Fortunately all data are not loaded into memory. Only when you access it, data
% is retrieved from disk and loaded into memory.

% Here we will load the very first frame.
img = stack(:, :, 1, 1, 1);
figure; imagesc(img); title('First frame')

% Remarks:
% All function with a name beginning with 'stacks' (with an 's') can take as
% input one stack or a cellarray of stacks, and apply the same operations on
% all of them.
% If you are using .bin files (IRIS format) and parallel computation, you can
% silence the numerous warnings from MappedTensor as follows:
% warning('off', 'MappedTensor:UnsupportedObjectStorage');
% and renable them at the end of your script with:
% warning('on', 'MappedTensor:UnsupportedObjectStorage');

%% Frames registration
% A second capital step consists in registering ("aligning") frames w.r.t some
% reference. Indeed some movements might happen at acquisition time and we want
% to compensate it, so that later a pixel would represent the same underlying
% structure in all frames.

% To compute the reference image, we can try to automatically create one using
% 'stackstemplate', which assemble randomly picked frames from the stack. Here
% we select 15 small batches of 20 frames each to create this template.
% stack = stack(50:end-50,50:end-50,:,:,:);

avg_ref = stackstemplate(stack, 10, 20,'refchannel', 1);


% Using this reference image, we compute (x,y)-shifts between frames of the
% stack and the reference. We remove 50 pixels at the borders in case there are
% some annoying artefacts (strips) that might cause poor results. We also
% activate verbosity to get feedback about completion time, and parallel
% computation to accelerate everything.
% Be patient, this step can take quite some time.
xyshifts = stacksregister_dft(stack, avg_ref, ...
    'margins', 50, 'useparfor', true,'refchannel', 1, 'verbose', true);

% It is always better to check values obtained by the registration method, as
% it might fail from times to time. Check for absence of outliers.
xysshow(xyshifts);

% Remarks:
% If you have some knowledge about the stability of acquired images, use it to
% select your reference image. Indeed, you can use 'stacksmean' over a specified
% period of time to create your reference image. For example, if you want to use
% frames from the 100th to the 200th, you can do it as follows:
% avg_ref = stacksmean(stack, 'indices', [100, 200]);

%% Projected data
% Now that registered data are available, we will compute some summary images,
% to be able to visualize cells, not visible in individual images.

% We begin with an average of the stack. We re-use 'stacksmean' function, but
% this time on the whole stack, with the (x,y)-shifts applied on each frame.
% We also indicate that we want data to be accessed by chunks of 20 frames,
% which makes loading faster, and using parallel computation.
avg_reg = stacksmean(stack, xyshifts, 'chunksize', 20, 'useparfor', true);

% Min- and max-projections are computed by a really similar function, except
% that both projections are computed at the same time.
% [min_proj, max_proj] = ...
%     stacksminmax(stack, xyshifts, 'chunksize', 20, 'useparfor', true);

% Interestingly, we can also get approximate percentiles of the stack. Here we
% will look at the 5th and 95th percentiles. Note that time axis is replace by
% percentiles.
% phats = stacksprctile(stack, [5, 95], [], xyshifts);

% Remarks:
% Be careful when using parallel computation and loading by chunks, as it
% significantly increases memory consumption.

%% Detect ROIs
% At this stage, we can use the average image of registered frames to detect
% cells (mostly active ones) automatically.

% Currently, the toolbox provides a 2 steps method: first find cell positions,
% then and infer their footprint given these positions. This method require
% trained models and fortunately some are provided for soma detection in GCaMP6
% based recordings.

% So first we will try to detect cells...
cellpos = celldetect_donut(avg_reg, 'GCaMP6_Soma_Ioana_tp77_fp71');
% ... then infer masks.
rois = cellsegment(avg_reg, cellpos, 'GCaMP6_Soma_Ioana_lda');

% Remarks:
% This step can be (re)-done in the GUI, so you can skip it.
% Be careful with the zoom factor of our data. If it is different from the
% model's, you can adjust it using the optional parameter 'celldiam' of both
% functions 'celldetect_donut' and 'cellsegment'.

%% Visualize data and ROIs
% At this stage, we have enough precomputed data to have lots of interesting
% things to look at.

% Visualization relies on the 'roisgui' function, which is a flexible function
% to display stacks, ROIs and optionally any kind of transformed data you want
% to feed it with.
% 'roisgui' function returns modified ROIs when the interface is closed. Thus,
% it is a good practice to put it in a variable.
% edited_rois = roisgui(short_stack, xyshifts, rois, ...
%     'ref. image', avg_ref, 'mean reg. image', avg_reg); %, ...
% %     'min proj.', min_proj, 'max proj.', max_proj, '5/95 perc.', phats);

edited_rois = roisgui(stack, xyshifts, mef_data2.rois(1,838:end), ...
    'ref. image', avg_ref, 'mean reg. image', mef_data.avg_regs_tf{1}); %, ...
%      'min proj.', min_proj, 'max proj.', max_proj, '5/95 perc.', phats);


% for i = 1:length(rois_to_switch)
%     if rois_to_switch(i).zplane == 1
%         rois_to_switch(i).zplane = 3;
%     elseif rois_to_switch(i).zplane == 2
%         rois_to_switch(i).zplane = 4;
%     end
% end

%% Extract time series from ROIs
% Once ROIs have been edited, we can extract the corresponding time series from
% the stack.

% First, it is important to estimate stacks offsets to remove them from
% extracted time series. If you are using fast resonant scanning, many pixels
% will be "black", hence the following function is relevant:
offsets = stacksoffsets_gmm(stack);

% It is good practice to check estimated offsets. Here we plot the histogram of
% a frame and overlay the offset estimate. If everything is allright, the offset
% estimate should align on a unique spike of the histogram, in the lowest
% intensities.
rng(1);  % seed random number generator for reproducibility
offsetsshow(stack, offsets);

% Here we use an optional parameter to make things faster -- at the expense of
% higher memory use -- loading data by chunks of 20 time points.
ts = stacksextract(stack, edited_rois, xyshifts, ...
    'chunksize', 20, 'offsets', offsets, 'verbose', true);

% 'ts' is a structure array containing the time series, and other information
% about the original ROI. Let's plot the time serie of the first ROI.
figure; plot(ts(1).activity); axis tight; grid on;
title('time serie of ROI 1');
xlabel('time (samples)');
ylabel('fluorescence (arbitrary unit)');

% Check the documentation of 'stacksextract' to know more about 'ts' structure.
help stacksextract

% Remarks:
% If 'stacksoffsets_gmm' fails at finding a correct offset (i.e. do not fit the
% first spike of the histogram), try to increase the number of components used
% with the 'ncomps' option:
% offsets = stacksoffsets_gmm(stack, 'ncomps', 3);

%% Computing dF/F0 with a running percentile
% This step computes dF/F0 of the ROIs traces, estimating the F0 baseline
% activity with a running percentile.

perc = 25;  % percentile used
half_win = 1000;  % half-width of the sliding window, in frames
[dff, f0] = roisfilter(ts, @(x) extractdff_prc(x, perc, half_win));

% Remarks:
% Be aware that there are many ways to compute dF/F0, and this one might not be
% the best suited for your data.
% In addition, if you want to apply some filtering on the traces (e.g. low-pass
% or high-pass before computing dF/F0), the 'roisfilter' function is what you
% need. Check its documentation ;-).

%% Save results
% It is always nice to save results for further analysis :-).

save('basic_example.mat', 'stackpath', ...
     'avg_ref', 'xyshifts', 'avg_reg', ... % 'min_proj', 'max_proj', 'phats', ...
     'cellpos', 'rois', 'edited_rois', ...
     'offsets', 'ts', 'dff', 'f0');