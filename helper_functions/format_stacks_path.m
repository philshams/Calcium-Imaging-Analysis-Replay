% --------------------
% format stacks path
% --------------------


% format stackspath so that all paths from same directory are in the same cell

i = 1; folder = 1; parent_dir = ones(100,1); file_num = ones(100,1); 
stacks_path_formatted = {}; folder_paths = {};

for ind=1:length(stacks_path)
    % if its a directory, add it to the stacks path formatted
    if isdir(stacks_path{ind})
        stacks_path_formatted{i} = stacks_path{ind}; i = i+1;
    else
    % otherwise, check if its parent directory has been added already
        curr_folder_path = fileparts(stacks_path{ind});
        if ~any(cellfun(@(x) strcmp(x, curr_folder_path), folder_paths))
            % if not, add a cell for that parent directory
            folder_paths{folder} = curr_folder_path;       
            stacks_path_formatted{i}{1} = stacks_path{ind};
            parent_dir(folder) = i; i = i+1; 
            folder = folder+1; file_num(folder) = 2; 
        else
            % if so, add it to the list of files in that same parent directory
            folder_ind = find(cellfun(@(x) strcmp(x, curr_folder_path), folder_paths));
            stacks_path_formatted{parent_dir(folder_ind)}{file_num(folder)} = stacks_path{ind};
            file_num(folder) = file_num(folder) + 1;            
        end
    end
        
end
