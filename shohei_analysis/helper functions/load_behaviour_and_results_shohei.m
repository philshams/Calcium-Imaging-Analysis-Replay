% --------------------------------------------
% load behaviour data and imaging results file
% --------------------------------------------

% find or load imaging data
if exist('session_results','var')
    disp('Using existing imaging results -- clear variable and restart to load anew')
else
    disp('loading imaging results...');
    session_results = load(results_file);
end



% find or load behaviour data
if exist('behaviour_table','var')
    disp('Using existing behaviour_table -- clear variable and restart to load anew')
else
    disp('loading behaviour... (if behaviour does not start from the first frame pulse, this section should be modified...)');
    behaviour_table = load_labview_daq(behaviour_folder, 100);
    if strcmp(animal, 'mef2c1')
        behaviour_table = decimate_daqdata(behaviour_table(1.296e6:end,:), 4, 2.5);
    elseif strcmp(animal, 'egr2')
        behaviour_table = decimate_daqdata(behaviour_table(behaviour_table.labview_time>1.86e3,:), 4, 2.5);
    else
        behaviour_table = decimate_daqdata(behaviour_table, 4, 2.5);        
    end
end

% make sure behaviour and imaging have same number of frames
assert(size(behaviour_table,1)==size(session_results.xyshifts{1},3),...
    'different number of imaging and behaviour frames -- try plotting behaviour_table.frame_pulse to check for a time to start the behaviour from')


% get stimulus indicies
if exist('onset','var')
    disp('Using existing stimulus onset indices -- clear onset variable and restart to calculate anew')
else
    disp('getting stimulus onset indices...');
    get_stimulus_indices_shohei % stored as inds.stim_name / onset.stim_name / offset.stim_name
end

% trim onset and offset:
% get trial start indices to average data for each trial -- trim off
% stimuli from trials not starting at a1 or ending with rew
first_onset = onset.a1(1); last_offset = offset.r1(end);
for s = 1:length(stims)
   onset.(stims{s}) = onset.(stims{s})(onset.(stims{s}) >= first_onset);
   offset.(stims{s}) = offset.(stims{s})(offset.(stims{s}) >= first_onset);

   onset.(stims{s}) = onset.(stims{s})(onset.(stims{s}) <= last_offset);
   offset.(stims{s}) = offset.(stims{s})(offset.(stims{s}) <= last_offset);       
end