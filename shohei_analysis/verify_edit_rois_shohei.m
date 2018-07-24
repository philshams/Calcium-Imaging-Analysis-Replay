% ---------------------------------------------
% Show PSTHs, edit ROIs, and update time series
% ---------------------------------------------


%% Parameters

% set folders
behaviour_folder = '\\172.24.170.8\data\public\projects\ShFu_20160303_Plasticity\Data\Imaging\CLP3\Labview_data\171225';
results_file = 'C:\Drive\Rotation3\data\shohei_results\results_task.mat';
psth_save_folder = 'C:\Drive\Rotation3\data\shohei_psth\';

animal = 'shohei';


% set PSTH window, in imaging frames
psth_window = -10:20;

% set stims -- should correspond to get_stimulus_indices notation
stims = {'a1','b1','a2','b2','r1'};

% update time series using the edited and saved ROIs?
update_time_series = false;





%% Load Imaging Data and Behaviour Table, or check if they exist

% load behaviour data and imaging results file
load_behaviour_and_results_shohei

% plot stimuli
plot_stimuli_shohei; disp('') % verify that things look right

% view avg transformed/registered images to make sure things look ok
stacksgui(session_results.avg_regs,[]);
answer = questdlg2('How do things look?','Avg Image Susser','Oh, just fine!','Something is off.','Oh, just fine!');
assert(strcmp(answer,'Oh, just fine!'))

% load task and sleep stacks
load_task_sleep_stacks_shohei




%% Create PSTH, or check if they exist



% load or create stimulus PSTH
if exist([psth_save_folder '\' stims{1} '_psth.mat'],'file')
    disp('Loading existing PSTHs -- delete or set new file path to create anew')
    for s = 1:length(stims)
        stim_psth = load([psth_save_folder '\' stims{s} '_psth']);
        psth_movie.(stims{s}) = stim_psth.stim_psth;
    end
else
    disp('creating PSTHs...')
    psth_image_shohei
end; disp('')




%% Visualize / Modify Rois and PSTH


% Show ROIs as well as task psth and sleep pseudo-psths
try
    reference_rois = session_results.rois;
catch; reference_rois = [];
end

disp('add/edit ROIs and check that they match with task PSTHs')
rois = roisgui(session_results.avg_regs{1}, [], reference_rois, 'avg. regs.', ...
          'a1 psth', psth_movie.a1, 'b1 psth', psth_movie.b1, 'a2 psth', psth_movie.a2, 'b2 psth', psth_movie.b2,...
          'r1 psth', psth_movie.r1);
        

% transform ROIs for time series creation
assert(logical(size(rois,2)),'no ROIs -- analysis halted')

        
% Save rois if user desires
answer = questdlg('Would you like to save the changes just made to the ROIs?','Save ROIs?');
if strcmp(answer,'Yes')
    save(results_file, 'rois', '-append');
    % clear session_results
end





%% Update Time Series

if update_time_series
    
disp('Updating time series with these improved ROIs!')

% load task stack
if exist('task_stack','var')
    disp('Using existing task tif stack -- clear variable task_stack and restart to load anew')
else
    disp('loading task stack...')
    task_stack = stacksload(imaging_folder_task);
    [nx, ny, nz, nc, nt] = size(task_stack);
    fprintf('stack size is: [%d, %d, %d, %d, %d]\n', nx, ny, nz, nc, nt);
end


% reload imaging results since changes were made to ROIs
disp('reloading imaging results...');
session_results = load(results_file);


% extract ROIS traces -- first estimate intensity offsets (save? or fast...)
fprintf('estimating stacks offsets...\n');
if isfield(session_results,'offsets')
    offsets = session_results.offsets;
else
%     session_results.opts.nframes = 20 % this option missing...?
%     session_results.opts.npixels = 2000 % this option missing...?
%     session_results.opts.ncomps = 2 % this option missing...?
%     session_results.opts.maxiter_gmm = 1000
    offsets = stacksoffsets_gmm(task_stack, ...
        'nframes', session_results.opts.nframes, 'npixels', session_results.opts.npixels, ...
        'maxiter', session_results.opts.maxiter_gmm, 'ncomps', session_results.opts.ncomps);
    save(results_file, 'offsets', '-append');
end


% extract ROIs time series
fprintf('extracting ROIs time series...\n');
ts = stacksextract(task_stack, session_results.rois, xyshifts, ...
    'offsets', offsets, 'chunksize', session_results.opts.chunksize, ...
    'verbose', session_results.opts.verbose, 'useparfor', session_results.opts.useparfor);
save(results_file, 'ts', '-append');


% compute deltaF/FO
fprintf('estimating dF/F0...\n');
% session_results.opts.half_win = [];  % this option missing...?
% session_results.opts.perc = 40;  % this option missing...?
extractfcn = @(x) extractdff_prc(x, session_results.opts.perc, session_results.opts.half_win);
[dff, f0] = roisfilter(ts, extractfcn); 
save(results_file, 'dff', 'f0', '-append');



      
%% examine the mean traces -- if there are some 'bad' epochs, truncate activity during this session

session_results = load(results_file);
avg_trace = zeros(1,length(session_results.dff(1,1).activity));

% get avg trace across all cells
disp(['averaging traces...']);
cells_to_avg_over = length(session_results.dff(1,:));
for cell = 1:cells_to_avg_over
    if isempty(session_results.dff(1,cell).activity)
        continue
    end
    avg_trace = avg_trace + (session_results.dff(1,cell).activity / cells_to_avg_over);
end

% show average trace and enter indices of stable activity
figure; plot(avg_trace); title('avg trace')
answer = questdlg2(['Truncate activity?']); 
if strcmp(answer,'Yes')
    stable_epoch = inputdlg( ...
        'Enter epoch to keep (start index, space, end index)', ...
        'stable epoch', 1, {''}, struct('WindowStyle','normal'));
    stable_epoch = str2num(stable_epoch{1}); 
else
    stable_epoch = [1 length(avg_trace)];
end
    

% save to results file
for cell = 1:length(session_results.dff(1,:))
    session_results.dff(1,cell).stable_epoch = stable_epoch;  
end
dff = session_results.dff;

save(results_file, 'stable_epoch', 'dff', '-append');


end





   




      