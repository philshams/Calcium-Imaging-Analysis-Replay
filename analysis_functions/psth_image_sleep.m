% ---------------------------------------------------------------------------
% visualizing pseudo PSTH of gCamp movies during sleep to ensure ROI quality
% ---------------------------------------------------------------------------

%% Set Parameters



% set PSTH window, in imaging frames
psth_window_sleep = -1:1;

% how many pseudo-trials to average over
avg_over_time_points = 250;





%% load task stack
if exist('sleep_stack','var')
    disp('Using existing task tif stack -- clear variable sleep_stack and restart to load anew')
    fprintf('stack size is: [%d, %d, %d, %d, %d]\n', nx, ny, nz, nc, nt);
else
%     disp('Select some sleep tif stacks from throughout the session')
%     imaging_files_sleep = uipickfiles('REFilter', '\.tiff?$|\.bin$');    
    
    disp('loading sleep stack...')
    sleep_stack = stacksload(imaging_folder_sleep);
%     sleep_stack = stacksload(imaging_files_sleep);
    [nx, ny, nz, nc, nt] = size(sleep_stack);
    fprintf('stack size is: [%d, %d, %d, %d, %d]\n', nx, ny, nz, nc, nt);
end







%% Loop through movie snips and concatenate stim responses



% pre-allocate psth array for each stimulus
psth.sleep = zeros([size(sleep_stack,1) size(sleep_stack,2) size(sleep_stack,3) size(sleep_stack,4) length(psth_window_sleep)],'int16'); 


% get stim averaged psth images
disp('averaging across stimulus presentations...')
unpack = ~iscell(sleep_stack);

% choose onset inds throughout session, as there are no stimuli during sleep
curr_onset_inds = round(linspace(100,nt-100,avg_over_time_points));
    
% loop across timepoints in pseudo psth
for tp = psth_window_sleep

    disp(['averaging timepoint ' num2str(find(psth_window_sleep==tp)) '/' num2str(length(psth_window_sleep))]) 
    
    % get xyshifts to proper time points
    curr_xyshifts = session_results.xyshifts{sleep_session}(:,:,curr_onset_inds + tp);


    % sum each stack over time, using a map/reduce operation
    stacks_sum = stacksreduce(sleep_stack(:,:,:,:,curr_onset_inds + tp), @accum_stack, @reduce_stack, ...
        curr_xyshifts, 'unpack', false, 'fcn_name', 'averaging');

    % divide by the number of frames to get averages
    avgs = cellfun(@(x) x.sum ./ x.nframes, stacks_sum, 'un', false);

    % return one averaged stack if one input stack
    if unpack && numel(avgs) == 1
        avgs = avgs{1};
    end
    
    % if task was the reference, transform sleep images
    if sleep_session ~= reference_session
        for z_pos = 1:nz
            for ch = 1:nc
                avgs(:,:,z_pos,ch) = imwarp(avgs(:,:,z_pos,ch), session_results.tforms{sleep_session}(z_pos),'OutputView', imref2d( size(avgs(:,:,z_pos,ch)) ));
            end
        end
    end
        
    % load into psth structure
    psth.sleep(:,:,:,:,tp+abs(psth_window_sleep(1))+1) = avgs;

end

% save pseudo psth tensor stack
sleep_psth = psth.sleep;
save([psth_save_folder '\sleep_psth'],'sleep_psth')



