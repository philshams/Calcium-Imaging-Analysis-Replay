% ---------------------------------------------
% Show PSTHs, edit ROIs, and update time series
% ---------------------------------------------


%% Parameters

% set folders
behaviour_folder = '\\172.24.170.8\data\public\projects\RaMa_20170301_Sleep\mef2c1\2017_11_15\behav\task\';
results_file = 'C:\Drive\Rotation3\data\mef_results\segmented_results.mat';
psth_save_folder = 'C:\Drive\Rotation3\data\mef_psth\';

animal = 'mef2c1';


% set PSTH window, in imaging frames
psth_window = -10:20;

% set stims -- should correspond to get_stimulus_indices notation
stims = {'a1','b1','a2','b2','n1','p1','r1','n2','p2','r2'};

% update time series using the edited and saved ROIs?
update_time_series = false;





%% Load Imaging Data and Behaviour Table, or check if they exist

% load behaviour data and imaging results file
load_behaviour_and_results

% plot stimuli
plot_stimuli; disp('') % verify that things look right

% view avg transformed/registered images to make sure things look ok
stacksgui(session_results.avg_regs_tf,[])
answer = questdlg2('How do things look?','Avg Image Susser','Oh, just fine!','Something is off.','Oh, just fine!');
assert(strcmp(answer,'Oh, just fine!'))

% load task and sleep stacks
load_task_sleep_stacks




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
    psth_image
end; disp('')

% load or create sleep pseudo-psth
if exist([psth_save_folder '\sleep_psth.mat'],'file')
    disp('Loading existing sleep pseudo PSTH -- delete or set new file path to create anew')
    sleep_psth = load([psth_save_folder '\sleep_psth']);
    sleep_psth = sleep_psth.sleep_psth;
else
    disp('creating sleep pseudo PSTH...')
    psth_image_sleep
end




%% Visualize / Modify Rois and PSTH


% Show ROIs as well as task psth and sleep pseudo-psths
try
    reference_rois = session_results.rois(reference_session,:);
catch; reference_rois = [];
end

disp('add/edit ROIs and check that they match with task and sleep PSTHs')
rois = roisgui(session_results.avg_regs_tf{sleep_session}, [], reference_rois, 'avg. regs. sleep', ...
          'avg. regs. task', session_results.avg_regs_tf{task_session}, ...
          'a1 psth', psth_movie.a1, 'b1 psth', psth_movie.b1, 'a2 psth', psth_movie.a2, 'b2 psth', psth_movie.b2,...
          'r1 psth', psth_movie.r1, 'r2 psth', psth_movie.r2, 'p1 psth', psth_movie.p1, 'p2 psth', psth_movie.p2,...
          'n1 psth', psth_movie.n1, 'n2 psth', psth_movie.n2, 'sleep pseudo psth', sleep_psth);
        

% transform ROIs for time series creation
assert(logical(size(rois,2)),'no ROIs -- analysis halted')
disp('transforming ROIs...')
rois_tf = roistransform(rois, session_results.tforms);

        
% Save rois if user desires
answer = questdlg('Would you like to save the changes just made to the ROIs?','Save ROIs?');
if strcmp(answer,'Yes')
    save(results_file, 'rois', '-append');
    save(results_file, 'rois_tf', '-append');
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

% load sleep stack
if exist('sleep_stack','var')
    disp('Using existing full sleep stack -- clear variable sleep_stack_full and restart to load anew')
else
    disp('loading sleep stack...')
    
    sleep_stack = stacksload(imaging_folder_sleep);
    [nx, ny, nz, nc, nt] = size(sleep_stack);
    fprintf('stack size is: [%d, %d, %d, %d, %d]\n', nx, ny, nz, nc, nt);
end

% put both stacks into a 'stacks' variable
stacks{sleep_session} = sleep_stack;
stacks{task_session} = task_stack;


% reload imaging results since changes were made to ROIs
disp('reloading imaging results...');
session_results = load(results_file);


% z correct if applicable
if session_results.opts.zcorrection
    [stacks, xyshifts] = stackszshift(stacks, session_results.zshifts, session_results.xyshifts);
end

% extract ROIS traces -- first estimate intensity offsets (save? or fast...)
fprintf('estimating stacks offsets...\n');
if isfield(session_results,'offsets')
    offsets = session_results.offsets;
else
    offsets = stacksoffsets_gmm(stacks, ...
        'nframes', session_results.opts.nframes, 'npixels', session_results.opts.npixels, ...
        'maxiter', session_results.opts.maxiter_gmm, 'ncomps', session_results.opts.ncomps);
    save(results_file, 'offsets', '-append');
end


% extract ROIs time series
fprintf('extracting ROIs time series...\n');
ts = stacksextract(stacks, session_results.rois_tf, xyshifts, ...
    'offsets', offsets, 'chunksize', session_results.opts.chunksize, ...
    'verbose', session_results.opts.verbose, 'useparfor', session_results.opts.useparfor);
save(results_file, 'ts', '-append');


% compute deltaF/FO
fprintf('estimating dF/F0...\n');
extractfcn = @(x) extractdff_prc(x, session_results.opts.perc, session_results.opts.half_win);
[dff, f0] = roisfilter(ts, extractfcn); 
save(results_file, 'dff', 'f0', '-append');



      
%% examine the mean traces -- if there are some 'bad' epochs, truncate activity during this session

% for each session
session_results = load(results_file);
session_types{task_session} = 'task'; session_types{sleep_session} = 'sleep'; stable_epoch = {};
for session = [task_session sleep_session]
    avg_trace = zeros(1,length(session_results.dff(session,1).activity));
    
    % get avg trace across all cells
    disp(['averaging ' session_types{session} ' traces...']);
    cells_to_avg_over = length(session_results.dff(session,:));
    for cell = 1:cells_to_avg_over
        if isempty(session_results.dff(session,cell).activity)
            continue
        end
        avg_trace = avg_trace + (session_results.dff(session,cell).activity / cells_to_avg_over);
    end
    
    % show average trace and enter indices of stable activity
    figure; plot(avg_trace); title([session_types{session} ' avg trace'])
    answer = questdlg2(['Truncate ' session_types{session} ' activity?']); 
    if strcmp(answer,'Yes')
        epoch = inputdlg( ...
            'Enter epoch to keep (start index, space, end index)', ...
            'stable epoch', 1, {''}, struct('WindowStyle','normal'));
        epoch = str2num(epoch{1}); 
    else
        epoch = [1 length(avg_trace)];
    end
    
    % save to cell array
    stable_epoch{session} = epoch;
    
end

% save to results file
for cell = 1:length(session_results.dff(session,:))
    session_results.dff(1,cell).stable_epoch = stable_epoch{1};  
    session_results.dff(2,cell).stable_epoch = stable_epoch{2}; 
end
dff = session_results.dff;

save(results_file, 'stable_epoch', 'dff', '-append');


end





      