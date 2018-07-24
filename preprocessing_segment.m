
%% Choose File Paths

% pick result files for within stack registration

% pick the .mat files that show the processing from the desired sessions
registerpath = uipickfiles('REFilter', '\.mat$','FilterSpec','C:\Drive\Rotation3\data'); 

% choose the path to output the cross-session alignment and ROI data, along
% with the above results, in a .mat file -- same folder, new name
resultsfolder = fileparts(registerpath{1}); %uigetdir();
resultspath = fullfile(resultsfolder, 'segmented_results.mat');



%% Register between stacks and extract ROIs

options.margins = [50, 50];
options.refchannel = 1;
options.maxiter_affine = 5000;
options.tformtype = 'affine';
options.zcorrection = true;
options.time_series = false;
forcerois = true;  % set to true to continue ROIs editing
stacks = pipeline_segment(resultspath, registerpath, forcerois, options);



%% Quality control

if options.time_series
    % load latest results
    results = load(resultspath);

    % check offset estimation
    offsetsshow(stacks, results.offsets);
end

% check that transforms and ROIs are alright
roisgui(results.avg_regs_tf, [], results.rois_tf, 'avg regs',...
    'max proj.', results.max_projs_tf);
    
disp('cross-session registration done -- now go to verify_edit_rois')     