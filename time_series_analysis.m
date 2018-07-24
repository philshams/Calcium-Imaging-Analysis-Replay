% ---------------------------
% gCamp time series analysis
% ---------------------------

% file locations
results_file = 'C:\Drive\Rotation3\data\mef_results2\segmented_results.mat';
behaviour_folder = '\\172.24.170.8\data\public\projects\RaMa_20170301_Sleep\mef2c1\2017_11_15\behav\task';
psth_save_folder = 'C:\Drive\Rotation3\data\mef_psth2';

% range around stimulus to measure - should start at -20
psth_window = -20:40;

% set stims -- should correspond to get_stimulus_indices notation
stims = {'a1','b1','a2','b2','n1','p1','r1','n2','p2','r2'};

% name of animal (for bespoke behaviour_table editing below)
animal = 'mef2c1';

% frame rate in Hz
frame_rate = 3.9;

% load behaviour data and imaging results file
load_behaviour_and_results


%% find responsive cells (and take mean of non-responsive ones)





%% extract PSTHs from those cells


if exist('psth_selective','var') && exist('psth_BS_selective','var')
    disp('Using existing psths -- clear psth variable and restart to calculate anew')
else
    % just take the gCamp activity signal
    activity_struct = session_results.dff(task_session,responsive_cells);

    % initialize PSTH array -- cell x timepoint
    for s = 1:length(stims)
    psth_selective.(stims{s}) = zeros(length(activity_struct),length(psth_window));
    psth_BS_selective.(stims{s}) = zeros(length(activity_struct),length(psth_window));
    end
    disp('averaging across stimulus presentations...')

    % loop across cells
    for cell = 1:length(activity_struct)

        % extract data for the current cell
        curr_cell_activity = activity_struct(cell).activity;
        
        % set PSTH of deleted ROIs to NaN
        if isempty(curr_cell_activity)
            for s = 1:length(stims)
                psth_BS_selective.(stims{s})(cell,:) = NaN;
                psth_selective.(stims{s})(cell,:) = NaN;
            end
            continue
        end
        
        disp(['averaging for cell ' num2str(cell)])

        % loop across stimuli
        for s = 1:length(stims)

            % take stimulus onset times for that stimulus
            curr_onset_inds = onset.(stims{s});

            % exclude stimuli very close to beginning and end of session,
            % and not during stable epoch
            curr_onset_inds = curr_onset_inds(curr_onset_inds>abs(min(psth_window)) & ...
                                    curr_onset_inds<size(session_results.xyshifts{task_session},3)-max(psth_window));
            curr_onset_inds = intersect(curr_onset_inds, session_results.stable_epoch{task_session}(1):session_results.stable_epoch{task_session}(2));

            % fill the PSTH array corresponding to the current stimulus
            for tp = 1:length(psth_window)
                psth_selective.(stims{s})(cell,tp) = mean(curr_cell_activity(curr_onset_inds + psth_window(tp)));
            end
            
            % create baseline subtracted PSTH
            psth_BS_selective.(stims{s})(cell,:) = psth_selective.(stims{s})(cell,:) - mean(psth_selective.(stims{s})(cell,1:abs(psth_window(1))));

        end

    end
end



%% plot stimulus responses


% loop across stimuli
for s = 1:length(stims)

    figure('Position', [600+s*20 532-s*20 728 406]); hold on; movegui(gca,'onscreen')
    title(['PSTH of all cells to ' stims{s} ' stimulus']);
    xlabel('time (sec) from stim onset');
    ylabel('df/f');
    
    % loop across cells
    for cell = 1:size(psth_selective.(stims{s}),1)

        plot(psth_window/frame_rate, psth_BS_selective.(stims{s})(cell,:),'color',[0 0 1 .5],'linewidth',.6)
        
    end

    plot(psth_window/frame_rate, prctile(psth_BS_selective.(stims{s}),25),'color',[.6 .6 .8],'linewidth',2)
    plot(psth_window/frame_rate, prctile(psth_BS_selective.(stims{s}),50),'color','white','linewidth',4)
    plot(psth_window/frame_rate, prctile(psth_BS_selective.(stims{s}),75),'color',[.6 .6 .8],'linewidth',2)
    
    ylim([-1 1])
    
    line([0,0],ylim,'linestyle','--','color',[.6 .2 .5]);
    
    set(gca,'Color','k') 
    axis tight
    
    pause(.1)
    
end
    
    
