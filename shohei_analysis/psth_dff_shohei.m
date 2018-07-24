% -------------------------------
% gCamp show PSTHs for all cells
% -------------------------------

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

% active cells only?
% provide threshold of proportion activity > 5 std negative distribution
active_cells_only = true; active_cell_threshold = .01;



%% extract PSTHs


if exist('psth','var') && exist('psth_BS','var')
    disp('Using existing psths -- clear psth variable and restart to calculate anew')
else
    % just take the gCamp activity signal
    activity_struct = session_results.dff(1,1:size(session_results.dff,2));

    % initialize PSTH array -- cell x timepoint
    for s = 1:length(stims)
    psth.(stims{s}) = zeros(length(activity_struct),length(psth_window));
    psth_BS.(stims{s}) = zeros(length(activity_struct),length(psth_window));
    end


    % loop across cells
    for cell = 1:length(activity_struct)

        % extract data for the current cell
        curr_cell_activity = activity_struct(cell).activity;
        
        % set PSTH of deleted ROIs to NaN
        if isempty(curr_cell_activity)
            for s = 1:length(stims)
                psth_BS.(stims{s})(cell,:) = NaN;
                psth.(stims{s})(cell,:) = NaN;
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
                                    curr_onset_inds<size(session_results.xyshifts{1},3)-max(psth_window));
            curr_onset_inds = intersect(curr_onset_inds, session_results.dff(1).stable_epoch(1):session_results.dff(1).stable_epoch(2));

            % fill the PSTH array corresponding to the current stimulus
            for tp = 1:length(psth_window)
                psth.(stims{s})(cell,tp) = mean(curr_cell_activity(curr_onset_inds + psth_window(tp)));
            end
            
            % create baseline subtracted PSTH
            psth_BS.(stims{s})(cell,:) = psth.(stims{s})(cell,:) - mean(psth.(stims{s})(cell,1:abs(psth_window(1))));

        end

    end
end

%% determine which cells are active

active_cells = [];
if active_cells_only
    
    % loop across cells
    for cell = 1:length(activity_struct)    
        
        % extract data for the current cell
        curr_cell_activity = activity_struct(cell).activity;    
        
        % look at just negative values and their reflection
        rectified_negative_activity = [curr_cell_activity(curr_cell_activity<0) abs(curr_cell_activity(curr_cell_activity<0))];
        
        % get 5x STD of this rectified histogram
        activity_threshold = 5*std(rectified_negative_activity);
        
        % check if this cell is active
        proportion_activity_over_threshold = sum(curr_cell_activity>activity_threshold) / length(curr_cell_activity);
        
        % include if over threshold
        if proportion_activity_over_threshold > active_cell_threshold
            active_cells(end+1) = cell;
        end
    end
    cells_to_plot = active_cells;
    disp(['plotting ' num2str(length(active_cells)) ' of ' num2str(length(activity_struct)) ' cells'])
    figure_name = 'PSTH of all active cells';
% if not filtering by activity, include all cells    
else
    cells_to_plot = 1:size(psth.(stims{s}),1);
    figure_name = 'PSTH of all cells';
end

%% plot stimulus responses

figure('Name',figure_name,'Position', [27 575 2349 707]); hold on; movegui(gca,'onscreen')
stim_order = {'a','b','r'};
stim_colors = {[0 0 1 .7];[.4 .4 0 .7];[0 .3 .8 .7];[.5 .3 .2 .7];[1 0 0 .7];};


% loop across stimuli
for s = 1:length(stims)

    subplot(2,3, find(cellfun(@(x) stims{s}(1)==x, stim_order))+3*(str2num(stims{s}(2))-1)); hold on
    
    title(['PSTH of all cells to ' stims{s} ' stimulus'],'color',stim_colors{s});
    xlabel('time (sec) from stim onset');
    ylabel('df/f');
    
    % loop across cells
    for cell = intersect(1:size(psth.(stims{s}),1),cells_to_plot)
        plot(psth_window/frame_rate, psth_BS.(stims{s})(cell,:),'color',[0 0 1 .7],'linewidth',.6)
    end

    % plot mean / std
    plot(psth_window/frame_rate, mean(psth_BS.(stims{s}))-std(psth_BS.(stims{s})),'color',[.6 .6 .8],'linewidth',1,'linestyle','--')
    plot(psth_window/frame_rate, mean(psth_BS.(stims{s})),'color','white','linewidth',2)
    plot(psth_window/frame_rate, mean(psth_BS.(stims{s}))+std(psth_BS.(stims{s})),'color',[.6 .6 .8],'linewidth',1,'linestyle','--')    


% plot formatting
    line([0,0],ylim,'linestyle','--','color',[.6 .2 .5]);
    set(gca,'Color','k') 
    axis tight
    
    pause(.05)
    
end
    
    
%% add psth and truncated activity to df/f, to see which ROIs respond

if isfield(session_results.dff,'psth')
   disp('PSTH already included in session_results.dff -- not saving')
else
    disp(['saving PSTHs to results file'])
    for cell = 1:length(activity_struct)

        % avg all psths to see avg stimulus response
        psth_all = zeros(length(psth_window),length(stims));
        for s = 1:length(stims)
            psth_all(:,s) = psth_BS.(stims{s})(cell,:) / length(stims);
        end

        % skip deleted ROIs
        if isempty(session_results.dff(1,cell).activity)
            continue
        end

        session_results.dff(1,cell).psth = psth_all;
       

    end
    dff = session_results.dff;
    save(results_file,'dff','-append');

end

%% show results in GUI


% load stimulus PSTH
if exist([psth_save_folder '\' stims{1} '_psth.mat'],'file')
    if ~exist('psth_movie','var')
        disp('Loading PSTH movies')
        for s = 1:length(stims)
            stim_psth = load([psth_save_folder '\' stims{s} '_psth']);
            psth_movie.(stims{s}) = stim_psth.stim_psth;
        end
    end
    
    % show PSTHs and truncated activity in GUI, and activity from the reference session
    psth_rois = roisgui(session_results.avg_regs{1}, [], session_results.dff, 'avg. regs.', ...
          'a1 psth', psth_movie.a1, 'b1 psth', psth_movie.b1, 'a2 psth', psth_movie.a2, 'b2 psth', psth_movie.b2,...
          'r1 psth', psth_movie.r1);  
      
else
    % show in GUI without PSTH movies
    psth_rois = roisgui(session_results.avg_regs_tf{1}, [], session_results.dff, 'avg. regs.');
end
    
    
