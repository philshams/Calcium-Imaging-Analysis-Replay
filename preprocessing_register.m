%% Choose File Paths

% pick stacks using Matlab gui, and load it
stacks_path = uipickfiles('REFilter', '\.tiff?$|\.bin$',...
                'FilterSpec','\\172.24.170.8\data\public\projects\RaMa_20170301_Sleep'); 

% put all stacks in stacks_path from same folder in a single cell            
format_stacks_path;

% choose the output path for the within-session regisstration, one for each stack
resultspaths{1} = 'C:\Drive\Rotation3\data\mef_results\results_sleep.mat';
resultspaths{2} = 'C:\Drive\Rotation3\data\mef_results\results_task.mat';





%% Registration

% options used for registration (see 'pipeline_register' documentation)
options.extract_si_metadata = false;
options.n_batches = 15; % 30
options.batch_size = 20;
options.filterfcn = @filtersmall;
options.margins = [20, 60]; % 50
options.maxshift = 20;
options.refchannel = 1;
options.win_size = 250;
options.verbose = true;
options.chunksize = 20; % 10
options.useparfor = true;

% register/average each stack in turn -- 
nstacks = numel(stacks_path);
stacks = cell(1, nstacks);
for ind = 1:nstacks
    fprintf('### stack %d/%d ###\n', ind, nstacks);
    stacks(ind) = pipeline_register(resultspaths{ind}, stacks_path_formatted{ind}, options);
end
fprintf('### registration done ###\n');





%% Quality control

% load all results
results = cellfun(@load, resultspaths, 'un', false);
results = cat(1, results{:});

% concatenate results
xyshifts = cat(2, results.xyshifts);
avg_refs = cat(2, results.avg_refs);
avg_regs = cat(2, results.avg_regs);
min_projs = cat(2, results.min_projs);
max_projs = cat(2, results.max_projs);

% display (x,y)-shifts
xysshow(xyshifts);

% display stacks and their projections
stacksgui(stacks{1}, xyshifts{1}, ...
    'avg_refs', avg_refs{1}, 'avg_regs', avg_regs{1}, ...
    'min_projs', min_projs{1}, 'max_projs', max_projs{1});