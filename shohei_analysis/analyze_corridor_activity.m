% -------------------------------
% gCamp show PSTHs for all cells
% -------------------------------

% file locations
behaviour_folder = '\\172.24.170.8\data\public\projects\ShFu_20160303_Plasticity\Data\Imaging\CLP3\Labview_data\171225';
results_file = 'C:\Drive\Rotation3\data\shohei_results\results_task.mat';
psth_save_folder = 'C:\Drive\Rotation3\data\shohei_psth\';


% range around stimulus to measure - should start at -20
psth_window = -20:20;

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
active_cells_only = true; active_cell_threshold = .0075;

% bin position
corridor_closed_loop = [1 0 1 0 1 0 1 0 1 0]; % 0 indicates onset / offset; number indicates num of panels in between
corridor_panels =      [2 1 3 1 3 1 3 1 2 1];
bins_per_panel = 2;
num_position_bins = (sum(corridor_panels)) * bins_per_panel;


%% create array of activity, occupancy, and speed: binned position x cells x trials 

% clear position_response_array_analyze
if exist('position_response_array_analyze','var')
    disp('Using existing position response array -- clear variable and restart to calculate anew')
else
    % take the gCamp activity signal
    activity_struct = session_results.dff(1,1:size(session_results.dff,2));
    
    %     % (only during stable epoch)
    %     trial_onset_inds = [intersect(trial_onset_inds, session_results.dff(1).stable_epoch(1):session_results.dff(1).stable_epoch(2))];
    
    % initialize position response array -- binned position x cells x trials
    position_response_array_analyze.dff = zeros(num_position_bins, length(activity_struct), length(onset.(stims{1}))-2);
    position_response_array_analyze.occupancy = zeros(num_position_bins, length(onset.(stims{1}))-2);
    position_response_array_analyze.speed = zeros(num_position_bins, length(onset.(stims{1}))-2);
    position_response_array_analyze.photodiode = zeros(num_position_bins, length(onset.(stims{1}))-2);
    
    
    % loop across trials
    skip_trial_counter = 1; clear cell;
    bin_frames = cell(num_position_bins,1);
    for trial = 2:length(onset.a1)-1 % skip first and last trials
        disp(['processing trial ' num2str(trial) ' out of ' num2str(length(onset.a1))])
        
        [~, start_ind] = min(behaviour_table.position_tunnel(offset.r1(trial-1):onset.a1(trial)));
        start_ind = start_ind + offset.r1(trial-1) - 1;
        
        % do this so start_ind in loop works
        bin_inds = start_ind-1;
        bin = 0;
        s = 0;
        skip_trial = false;
        
        % loop across position bins
        for section = 1:length(corridor_panels)
            
            % if any section is screwed up, move on to the next trial
            if skip_trial
                break
            end            
            
            % if the panel is not a grating
            if corridor_closed_loop(section)
                % start after the offset of previous stimulus
                if section > 1
                    start_ind = offset.(stims{s})(trial)+1;
                end
                
                % if not the last section
                if section < length(corridor_panels)
                    % ends just before the onset of the upcoming stim
                    bin_positions = behaviour_table.position_tunnel(start_ind:onset.(stims{s+1})(trial)-1);
                   
                else
                % if the last section, go to end of corridor
                    [~, end_ind] = min(behaviour_table.position_tunnel(offset.r1(trial):onset.a1(trial+1)));
                    end_ind = end_ind + offset.r1(trial) - 1 - 1;
                    bin_positions = behaviour_table.position_tunnel(start_ind:end_ind);
                end
            else
                % if the next stim has arrived
                s = s + 1;
                bin_positions = behaviour_table.position_tunnel(onset.(stims{s})(trial):offset.(stims{s})(trial));
                start_ind = onset.(stims{s})(trial);
            end

            for b = 1:bins_per_panel*corridor_panels(section)
                % get bin indices
                curr_trial_bin_inds = find(bin_positions - bin_positions(1) >= ...
                                    (bin_positions(end)-bin_positions(1)) / (bins_per_panel*corridor_panels(section))*(b-1) & ...
                                         bin_positions - bin_positions(1) <= ...
                                         (bin_positions(end)-bin_positions(1)) / (bins_per_panel*corridor_panels(section))*b ) + start_ind - 1;
                
                % go to next bin index
                bin = bin + 1;
                
                % don't count if there are no trials of if the mouse is stationary
                if isempty(curr_trial_bin_inds) 
                    % get the speed and occupancy data
                    position_response_array.occupancy(bin,trial-1*skip_trial_counter) = 0;
                    position_response_array.speed(bin,trial-1*skip_trial_counter) = NaN;
                    position_response_array.photodiode(bin,trial-1*skip_trial_counter) = NaN;
                    position_response_array.dff(bin,:,trial-1*skip_trial_counter) = NaN;
                    continue
                elseif curr_trial_bin_inds(end) - curr_trial_bin_inds(1) + 1 > 100
                    
                    position_response_array_analyze.occupancy(:,trial-1*skip_trial_counter) = [];
                    position_response_array_analyze.speed(:,trial-1*skip_trial_counter) = [];
                    position_response_array_analyze.photodiode(:,trial-1*skip_trial_counter) = [];
                    position_response_array_analyze.dff(:,:,trial-1*skip_trial_counter) = [];
                    
                    disp(['trial ' num2str(trial) ' excluded from analysis!'])
                    skip_trial = true; skip_trial_counter = skip_trial_counter + 1;
                    break
                else
                    position_response_array_analyze.occupancy(bin,trial-1*skip_trial_counter) = curr_trial_bin_inds(end) - curr_trial_bin_inds(1) + 1;
                    position_response_array_analyze.speed(bin,trial-1*skip_trial_counter) = mean(behaviour_table.speed(curr_trial_bin_inds));
                    position_response_array_analyze.photodiode(bin,trial-1*skip_trial_counter) = mean(behaviour_table.photodiode(curr_trial_bin_inds));
                end
                
                % get the indices for each bin
                bin_frames{bin} = [bin_frames{bin}; curr_trial_bin_inds];
                
                
                % loop across cells
                for cell = 1:length(activity_struct)
                    % set data of deleted ROIs to NaN
                    if isempty(activity_struct(cell).activity)
                        position_response_array_analyze.dff(:,cell,:) = NaN;
                        continue
                    end
                    
                    % fill the activity array corresponding to the position bin
                    position_response_array_analyze.dff(bin,cell,trial-1*skip_trial_counter) = mean(activity_struct(cell).activity(curr_trial_bin_inds));
                
                end
                
            end
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
    cells_to_use = active_cells;
    disp(['plotting ' num2str(length(active_cells)) ' of ' num2str(length(activity_struct)) ' cells'])
    figure_name = 'binned activity of all active cells';
% if not filtering by activity, include all cells    
else
    cells_to_use = 1:size(position_response_array_analyze.dff,2);
    figure_name = 'binned activity of all cells';
end 

position_response_array_analyze.dff_active = position_response_array_analyze.dff(:,cells_to_use,:);



%% plot stimulus responses as heatmap


% get mean responses by position
mean_dff_by_position = squeeze(nanmean(position_response_array_analyze.dff_active(:,:,:),3))';

% make figure
f = figure('Name',figure_name,'Position', [801+plot_iter*20 464-plot_iter*20 830 620]); hold on; movegui(gca,'onscreen')
f.InvertHardcopy = 'off';
subplot(3,1,1:2)

% sort mean responses by position of max responses
if plot_iter == 1 % sort using indices from first iteration
    [~, position_of_max_dff] = max(mean_dff_by_position,[],2);
    [~, position_sort_ind] = sort(position_of_max_dff);
end
mean_dff_by_position = mean_dff_by_position(position_sort_ind,:);

% filter for viewing pleasure
mean_dff_by_position = imgaussfilt(mean_dff_by_position,1,'FilterSize',[1 3]);

% plot activity
activity_map = imagesc(mean_dff_by_position);

% format plot and color
caxis([prctile(mean_dff_by_position(:),1) prctile(mean_dff_by_position(:),99)])
cb = colorbar('position',[.91 0.4090 0.0243 0.5164],'color','w'); title(cb,'df/f','color','w');
title(['V1 activity across corridor' title_modifier{plot_iter}],'color','w')

% format axes
set(activity_map, 'XData', [0 (num_position_bins-1)/bins_per_panel]);
set(gca, 'XTick', [2,6,10,14,17] - 1/(2*bins_per_panel) + .5, 'XTickLabel', {'A1','B1','A2','B2','R'},'XColor','w','YColor','w');
ylabel('cell num -- sorted by position of peak response','color','w')
axis tight
% xlim([0 18 - 1/(2*bins_per_panel)])

% show stim onsets
line([2,2] - 1/(2*bins_per_panel),ylim,'linestyle','--','color',[.7 .2 .3]);
line([6,6] - 1/(2*bins_per_panel),ylim,'linestyle','--','color','m');
line([10,10] - 1/(2*bins_per_panel),ylim,'linestyle','--','color',[.7 .2 .3]);
line([14,14] - 1/(2*bins_per_panel),ylim,'linestyle','--','color','m');
line([17,17] - 1/(2*bins_per_panel),ylim,'linestyle','--','color',[0 1 0]);

for x_position = [0 1 3 4 5 7 8 9 11 12 13 15 16 18] - 1/(bins_per_panel*2)
    line([x_position x_position],ylim,'linestyle','--','color',[.7 .7 .7 .4]);
end

% prepare speed and occupancy
x_position = linspace(0,num_position_bins/bins_per_panel - 1/(bins_per_panel),num_position_bins);
gauss_filt = gausswin(ceil(bins_per_panel / 2)); gauss_filt = gauss_filt / sum(gauss_filt);


occupancy = nanmean(position_response_array_analyze.occupancy(:,:),2);
occupancy = (occupancy - nanmean(occupancy)) / nanstd(occupancy);
speed = nanmean(position_response_array_analyze.speed(:,:),2) * 80 / 5;
% photodiode_to_plot = nanmean(position_response_array.photodiode(:,cross_val_inds{plot_iter}),2);

% smooth speed and occupancy
occupancy_to_plot = filter(gauss_filt,1, [flip(occupancy); occupancy; flip(occupancy)]);
occupancy_to_plot = occupancy_to_plot(length(occupancy)+1:2*length(occupancy));

speed_to_plot = filter(gauss_filt,1, [flip(speed); speed; flip(speed)]);
speed_to_plot = speed_to_plot(length(speed)+1:2*length(speed));


% plot speed and occupancy
subplot(3,1,3); hold on
set(gca,'color',[1 1 1]*.05,'XColor','w','YColor','w')
set(f,'color','black')

% plot occupancy, left yaxis
yyaxis left
plot(x_position,occupancy_to_plot','color',[0 0 1 .8],'linewidth',3)
% plot(x_position,photodiode_to_plot','color','white','linewidth',1)
ylabel('occupancy z-score')
axis tight
% xlim([0 18 - 1/(2*bins_per_panel)])

% plot speed, right yaxis
yyaxis right
plot(x_position,speed_to_plot','color',[1 0 0 .8],'linewidth',3)
ylabel('speed (cm/s)','color','red')
xlabel('position along corridor')
set(gca, 'XTick', [2,6,10,14,17] - 1/(2*bins_per_panel) + .5, 'XTickLabel', {'A1','B1','A2','B2','R'},'XColor','w','Ycolor','r');

% show stim onsets
line([2,2] - 1/(2*bins_per_panel),ylim,'linestyle','--','color',[.7 .2 .3]);
line([6,6] - 1/(2*bins_per_panel),ylim,'linestyle','--','color','m');
line([10,10] - 1/(2*bins_per_panel),ylim,'linestyle','--','color',[.7 .2 .3]);
line([14,14] - 1/(2*bins_per_panel),ylim,'linestyle','--','color','m');
line([17,17] - 1/(2*bins_per_panel),ylim,'linestyle','--','color',[0 1 0]);

for x_position = [0 1 3 4 5 7 8 9 11 12 13 15 16 18] - 1/(bins_per_panel*2)
    line([x_position x_position],ylim,'linestyle','--','color',[.7 .7 .7 .4]);
end


% --------------------------------------------------
%% plot mean of certain group of cells across time
% --------------------------------------------------
close all
% select cells who respond to stimuli of interest (1 - 18)
stimuli_of_interest = [18];
% name of stimulus
type_of_cells = 'reward cells';

% select position bins of interest
% position_bins = {[1]; [2]; [4; 6; 10; 12; 14]; [8]; [16]; [17]}; % 'post-grating non-rewarded' -- [4; 6; 12; 10; 14]
position_bins = {[1; 2]; [4; 6; 12; 10; 14; 8; 16; 17]; [3; 7; 11; 15]; [9]; [13]; [18]};

% name position bins
% position_bin_names_activity = {'beginning of corridor','2nd in beginning','post-grating non-rewarded','post-grating confound','penultimate pre-reward','ultimate pre-reward'};
% stimulus_type_name = 'dotted gray screens';
position_bin_names_activity = {'beginning of corridor','other gray screens','gratings','disappointing landmark','other landmark','reward'};
stimulus_type_name = 'all screen types';

% make smoothing filter
gauss_filt = gausswin(5); gauss_filt = gauss_filt / sum(gauss_filt);


% ---------------------------------------------------------------------------------------------


% get indices of cells responding maximally to this stimulus
sorted_position_of_max_dff = position_of_max_dff(position_sort_ind);
cells_of_interest = find(ismember(ceil(sorted_position_of_max_dff / bins_per_panel),stimuli_of_interest))

% set x position
x_position_corridor = linspace(0 + 1/(2*bins_per_panel),num_position_bins/bins_per_panel - 1/(2*bins_per_panel),num_position_bins);

% get number of trials
num_trials = size(position_response_array_analyze.dff_active(:,:,:),3);

% get mean responses by position
mean_dff_by_position = squeeze(nanmean(position_response_array_analyze.dff_active(:,:,:),3))';

% make figure
f = figure('Name',figure_name,'Position', [801 519 1110 565]); hold on; movegui(gca,'onscreen')
f.InvertHardcopy = 'off';

% sort mean responses by position of max responses
if plot_iter == 1 % sort using indices from first iteration
    [~, position_of_max_dff] = max(mean_dff_by_position,[],2);
    [~, position_sort_ind] = sort(position_of_max_dff);
end

% now that they're ordered, get mean across cells of interest
mean_dff_by_position_across_cells =  squeeze(nanmean(position_response_array_analyze.dff_active(:,position_sort_ind(cells_of_interest),:),2));


% format plot and colorbar
title([type_of_cells ' -- activity across corridor'],'color','w');
cb = colorbar('color','w'); caxis([1 num_trials]); title(cb,'trial','color','w');
set(gca,'color',[1 1 1]*.025,'XColor','w','YColor','w')
set(f,'color','black')
xlim([0 18])
ylim([-.1 1])

% show stim onsets
set(gca, 'XTick', [2,6,10,14,17], 'XTickLabel', {'A1','B1','A2','B2','R'},'XColor','w','YColor','w');
line([2,2],ylim,'linestyle','--','color',[.7 .2 .3]);
line([6,6],ylim,'linestyle','--','color','m');
line([10,10],ylim,'linestyle','--','color',[.7 .2 .3]);
line([14,14],ylim,'linestyle','--','color','m');
line([17,17],ylim,'linestyle','--','color',[0 1 0]);

for x_position = [0 1 3 4 5 7 8 9 11 12 13 15 16 18]
    line([x_position x_position],ylim,'linestyle','--','color',[1 1 1 .2]);
end

% plot activity for each trial
cmap = num2cell([parula(num_trials) ones(num_trials,1)*.4],2);
for trial = 1:num_trials
    p = plot(x_position_corridor, mean_dff_by_position_across_cells(:,trial)); hold on
    set(p,'color',cmap{trial})
%     pause(.05)
end



% ------------------------------------
% plot avg over position, over trials
% ------------------------------------

% set x position
x_position_corridor = linspace(0 + 1/(bins_per_panel),num_position_bins/bins_per_panel - 1/(bins_per_panel),num_position_bins);

% tag position bins of interest
clear cell
position_bin_names_speed = cell(length(position_bin_names_activity),1);
for bin = 1:length(position_bin_names_activity)
    position_bin_names_speed{bin} = [position_bin_names_activity{bin} ' speed'];
end

% make figure
f = figure('Name',figure_name,'Position', [547 402 1003 954]); hold on; movegui(gca,'onscreen')
set(f,'color','black'); f.InvertHardcopy = 'off';


% plot each position bin across trials
cmap = num2cell([parula(length(position_bin_names_activity)) ones(length(position_bin_names_activity),1)*.4],2);
p = {}; s = {};

subplot(2,1,1)

for bin = 1:length(position_bins)
    
    cur_position_inds = [];
    for stim_occurence = 1:size(position_bins{bin},1)
        cur_position_occurence_inds = find(x_position_corridor>position_bins{bin}(stim_occurence)-1 & x_position_corridor<position_bins{bin}(stim_occurence));
        cur_position_inds = [cur_position_inds cur_position_occurence_inds(1):cur_position_occurence_inds(end)];
    end
    
    cur_activity_over_trials = nanmean(mean_dff_by_position_across_cells(cur_position_inds,:),1);
    cur_activity_over_trials_to_plot = filter(gauss_filt,1, [flip(cur_activity_over_trials) cur_activity_over_trials flip(cur_activity_over_trials)]);
    cur_activity_over_trials_to_plot = cur_activity_over_trials_to_plot(length(cur_activity_over_trials)+1:2*length(cur_activity_over_trials));
    
    p{bin} = plot(cur_activity_over_trials_to_plot,'linewidth',4,'linestyle','-'); hold on
    set(p{bin},'color',cmap{bin})

end

title([type_of_cells ' -- activity during ' stimulus_type_name ' (c = ' num2str(length(cells_of_interest)) ' / ' num2str(length(position_of_max_dff)) ')'],'color','w');
ylabel('activity (df/f)','color','w')
set(gca,'color',[1 1 1]*.025,'XColor','w','YColor','w','YColor','w')
l = legend(position_bin_names_activity,'textcolor','white','position',[0.8096 0.8879 0.1914 0.1074]);

% plot speed as well
subplot(2,1,2)

for bin = 1:length(position_bins)
    
    cur_position_inds = [];
    for stim_occurence = 1:size(position_bins{bin},1)
        cur_position_occurence_inds = find(x_position_corridor>position_bins{bin}(stim_occurence)-1 & x_position_corridor<position_bins{bin}(stim_occurence));
        cur_position_inds = [cur_position_inds cur_position_occurence_inds(1):cur_position_occurence_inds(end)];
    end    
    
    cur_speed_over_trials = nanmean(position_response_array_analyze.speed(cur_position_inds,:));
    cur_speed_over_trials_to_plot = filter(gauss_filt,1, [flip(cur_speed_over_trials) cur_speed_over_trials flip(cur_speed_over_trials)]);
    cur_speed_over_trials_to_plot = cur_speed_over_trials_to_plot(size(position_response_array_analyze.speed,2)+1:2*size(position_response_array_analyze.speed,2));    
    
    s{bin} = plot(cur_speed_over_trials_to_plot*80/5,'linewidth',4, 'linestyle','-'); hold on
    set(s{bin},'color',cmap{bin}) 
end
title(['speed'],'color','w');
ylabel('speed (cm/s)','color','w')
set(gca,'color',[1 1 1]*.025,'XColor','w','YColor','w')
xlabel('trials')

% legend(position_bin_names_speed,'textcolor','white')




%% correlate to speed, acceleration and offset versions of these
                           

% format speed / acceleration
speed_to_correlate = behaviour_table.speed;
acceleration = [0; diff(behaviour_table.speed)];

% % get frames to use indices
clear cell;
frames_to_use=cell(num_position_bins,1);
for bin = 1:num_position_bins
    frames_to_use{bin} = find(~ismember(1:length(speed_to_correlate), bin_frames{bin}));
end

% make figure
f = figure('Name',figure_name,'Position', [286 613 1269 615]); hold on; movegui(gca,'onscreen')

set(f,'color','black'); f.InvertHardcopy = 'off';
set(gca,'color',[1 1 1]*.025,'XColor','w','YColor','w')

cmap = parula(max(position_of_max_dff));

% loop over each cell
correlations = zeros(length(cells_to_use),2);
for cell_num = 1:length(cells_to_use)
    
    cell = cells_to_use(cell_num);
    preferred_bin = position_of_max_dff(cell_num);
    
%     [R, P] = corrcoef(behaviour_table.speed(frames_to_use{preferred_bin}),activity_struct(cell).activity(frames_to_use{preferred_bin}));
    [R, P] = corrcoef(behaviour_table.speed,activity_struct(cell).activity);
    
    correlations(cell_num,1) = R(2);
    correlations(cell_num,2) = P(2);

    s = scatter(position_of_max_dff(cell_num) / bins_per_panel - 1/(2*bins_per_panel), correlations(cell_num,1), ...
        'markerfacecolor', cmap(position_of_max_dff(cell_num),:),'markerfacealpha', 1 - .8*(abs(P(2)) > .001),...
            'markeredgecolor',[1 1 1],'markeredgealpha',.2);

end

% plot 0 correlation
plot(xlim, [0 0],'linestyle','-','color',[1 1 1 .5]);
plot(xlim, [-.1 -.1],'linestyle',':','color',[1 1 1 .2]);
plot(xlim, [.1 .1],'linestyle',':','color',[1 1 1 .2]);

% show stim onsets
set(gca, 'XTick', [2,6,10,14,17]+1/bins_per_panel, 'XTickLabel', {'A1','B1','A2','B2','R'},'XColor','w','YColor','w');
line([2,2],ylim,'linestyle','--','color',[.7 .2 .3]);
line([6,6],ylim,'linestyle','--','color','m');
line([10,10],ylim,'linestyle','--','color',[.7 .2 .3]);
line([14,14],ylim,'linestyle','--','color','m');
line([17,17],ylim,'linestyle','--','color',[0 1 0]);

for x_position = [0 1 3 4 5 7 8 9 11 12 13 15 16 18]
    line([x_position x_position],ylim,'linestyle','--','color',[1 1 1 .2]);
end

% set title
% title('Correlation to speed by preferred location in corridor -- within preferred patch','color','w')
title('Correlation to speed by preferred location in corridor','color','w')
xlabel('position in corridor','color','w')
ylabel('correlation coefficient','color','w')


    
