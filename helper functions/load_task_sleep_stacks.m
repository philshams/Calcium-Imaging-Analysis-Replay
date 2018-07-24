% --------------------------
% load task and sleep stacks
% --------------------------


% find the folders or files for raw sleep / task data
imaging_folder_task = session_results.stackspath{task_session};
imaging_folder_sleep = session_results.stackspath{sleep_session};

% if stacks are already loaded in memory, assign them these variable names
% to make this code run much faster!
if exist('stacks','var')
    disp('Using existing stacks -- clear variable and restart to calculate anew')
    task_stack = stacks{task_session};
    sleep_stack = stacks{sleep_session};
end
