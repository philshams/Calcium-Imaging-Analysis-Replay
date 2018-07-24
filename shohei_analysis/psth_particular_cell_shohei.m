% ----------------------------
% gCamp show PSTHs for a cell
% ----------------------------

% file locations
behaviour_folder = '\\172.24.170.8\data\public\projects\ShFu_20160303_Plasticity\Data\Imaging\CLP3\Labview_data\171225';
results_file = 'C:\Drive\Rotation3\data\shohei_results\results_task.mat';
psth_save_folder = 'C:\Drive\Rotation3\data\shohei_psth\';

% range around stimulus to measure - should start at -20
psth_window = -20:40;

% set stims -- should correspond to get_stimulus_indices notation
stims = {'a1','b1','a2','b2','r1'};

% name of animal (for bespoke behaviour_table editing below)
animal = 'shohei';

% frame rate in Hz
frame_rate = 3.9;

% load behaviour data and imaging results file
load_behaviour_and_results_shohei

% choose which cell(s) by ID to plot!
cells = 131;


%% extract PSTH


% just take the gCamp activity signal
activity_struct = session_results.dff(1,1:size(session_results.dff,2));


% loop across cells
for cell_num = 1:length(cells)
    cell = cells(cell_num);

    % extract data for the current cell
    curr_cell_activity = activity_struct(cell).activity;
    disp(['averaging for cell ' num2str(cell)])

    % loop across stimuli
    for s = 1:length(stims)
        
        % take stimulus onset times for that stimulus
        curr_onset_inds = onset.(stims{s});

        % exclude stimuli very close to beginning and end of session,
        % and not during stable epoch
        curr_onset_inds = curr_onset_inds(curr_onset_inds>abs(min(psth_window)) & ...
                                curr_onset_inds<size(session_results.xyshifts{1},3)-max(psth_window));
        curr_onset_inds = intersect(curr_onset_inds, session_results.dff(1).stable_epoch(1):session_results.dff(1).stable_epoch(2));
        
        % initialize PSTH arrays - PSTH window size x num trials
        psth_all_trials.(stims{s}) = zeros(length(curr_onset_inds), length(psth_window));
        psth_all_trials_BS.(stims{s}) = zeros(length(curr_onset_inds), length(psth_window));        

        % fill the PSTH array corresponding to the current stimulus
        for tp = 1:length(psth_window)
            psth_all_trials.(stims{s})(:,tp) = curr_cell_activity(curr_onset_inds + psth_window(tp));
        end

        % create baseline subtracted PSTH
        psth_all_trials_BS.(stims{s}) = psth_all_trials.(stims{s}) - mean(psth_all_trials.(stims{s})(:,1:abs(psth_window(1))),2);

    end



%% plot stimulus responses

figure('Position', [600 532 1528 706]); hold on; movegui(gca,'onscreen')
stim_order = {'a','b','r'};
stim_colors = {[0 0 1 .7];[.4 .4 0 .7];[0 .3 .8 .7];[.5 .3 .2 .7];[1 0 0 .7];};

% loop across stimuli
for s = 1:length(stims)
    
    subplot(2,3, find(cellfun(@(x) stims{s}(1)==x, stim_order))+3*(str2num(stims{s}(2))-1)); hold on
    
    title(['cell ' num2str(cell) ', stimulus ' stims{s}],'color',stim_colors{s});
    xlabel('time (sec) from stim onset');
    ylabel('df/f');
    
    % loop across trials
    for trial = 1:size(psth_all_trials.(stims{s}),1)
        plot(psth_window/frame_rate, psth_all_trials_BS.(stims{s})(trial,:),'color',[0 0 1 .5],'linewidth',.6)
    end

    if size(psth_all_trials.(stims{s}),1) > 10
%         plot(psth_window/frame_rate, prctile(psth_all_trials_BS.(stims{s}),90),'color',[.6 .6 .8],'linewidth',1,'linestyle','--')
%         plot(psth_window/frame_rate, prctile(psth_all_trials_BS.(stims{s}),50),'color','white','linewidth',2)
%         plot(psth_window/frame_rate, prctile(psth_all_trials_BS.(stims{s}),10),'color',[.6 .6 .8],'linewidth',1,'linestyle','--')
        
        plot(psth_window/frame_rate, mean(psth_all_trials_BS.(stims{s}))-std(psth_all_trials_BS.(stims{s})),'color',[.6 .6 .8],'linewidth',1,'linestyle','--')
        plot(psth_window/frame_rate, mean(psth_all_trials_BS.(stims{s})),'color','white','linewidth',2)
        plot(psth_window/frame_rate, mean(psth_all_trials_BS.(stims{s}))+std(psth_all_trials_BS.(stims{s})),'color',[.6 .6 .8],'linewidth',1,'linestyle','--')        
    end
    
    
    line([0,0],ylim,'linestyle','--','color',[.6 .2 .5]);
    
    set(gca,'Color','k') 
    axis tight
    
    pause(.05)
    
end


end
    