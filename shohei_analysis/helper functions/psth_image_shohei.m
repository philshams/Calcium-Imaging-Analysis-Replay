% ------------------------------------------
% visualizing PSTH of gCamp movies
% ------------------------------------------


%% load task stack
if exist('task_stack','var')
    disp('Using existing task tif stack -- clear variable task_stack and restart to load anew')
else
    disp('loading task stack...')
    task_stack = stacksload(imaging_folder_task);
    [nx, ny, nz, nc, nt] = size(task_stack);
    fprintf('stack size is: [%d, %d, %d, %d, %d]\n', nx, ny, nz, nc, nt);
end





%% Loop through movie snips and concatenate stim responses



% pre-allocate psth array for each stimulus
for s = 1:length(stims)
    psth_movie.(stims{s}) = zeros([size(task_stack,1) size(task_stack,2) size(task_stack,3) size(task_stack,4) length(psth_window)],'int16'); 
end


% get stim averaged psth images
disp('averaging across stimulus presentations...')
unpack = ~iscell(task_stack);

% loop acros stimuli
for s = 1:length(stims)
    
    disp(['Stimulus: ' stims{s}])
    
    % take stimulus onset times for that stimulus
    curr_onset_inds = onset.(stims{s});
    
    % exclude stimuli very close to beginning and end of session
    curr_onset_inds = curr_onset_inds(curr_onset_inds>abs(min(psth_window)) & ...
                                    curr_onset_inds<size(task_stack,5)-max(psth_window));
    
    % loop across timepoints in psth
    for tp = psth_window
        
        % get xyshifts to proper time points
        curr_xyshifts = session_results.xyshifts{1}(:,:,curr_onset_inds + tp);

        
        % sum each stack over time, using a map/reduce operation
        stacks_sum = stacksreduce(task_stack(:,:,:,:,curr_onset_inds + tp), @accum_stack, @reduce_stack, ...
            curr_xyshifts, 'unpack', false, 'fcn_name', 'averaging');

        % divide by the number of frames to get averages
        avgs = cellfun(@(x) x.sum ./ x.nframes, stacks_sum, 'un', false);

        % return one averaged stack if one input stack
        if unpack && numel(avgs) == 1
            avgs = avgs{1};
        end
        
      % add text in top left corner indicating time relative to stimulus
      for z_pos = 1:size(avgs,3)
          for ch = 1:size(avgs,4)        
              
              text_brightness = prctile(avgs(:),98);
        
              avgs_with_text = insertText(avgs(:,:,z_pos,ch),[10 10],[stims{s} ': ' num2str(psth_window(tp+abs(psth_window(1))+1))],'BoxColor',[0 0 0],'BoxOpacity',0.8,'TextColor',[text_brightness 0 0]);
              avgs(:,:,z_pos,ch) = avgs_with_text(:,:,1);        
          end
      end
      
    % load into psth structure
    psth_movie.(stims{s})(:,:,:,:,tp+abs(psth_window(1))+1) = avgs;
    
    end

    % save psth tensor stacks
    stim_psth = psth_movie.(stims{s});
    save([psth_save_folder '\' stims{s} '_psth'],'stim_psth')
    
end














