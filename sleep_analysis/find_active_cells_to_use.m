
% % % % find_active_cells_to_use
cells_to_use = {};

for session = 1:num_sessions
    
active_cells = [];
if active_cells_only
    
    % loop across cells
    for cell = 1:length(activity_struct{session})    
        
        % extract data for the current cell
        curr_cell_activity = activity_struct{session}(cell).activity;    
        
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
    cells_to_use{session} = active_cells;
    disp(['session ' num2str(session) ': ' num2str(length(active_cells)) ' of ' num2str(length(activity_struct{session})) ' cells active '])
    figure_name = 'binned activity of all active cells';
% if not filtering by activity, include all cells    
else
    cells_to_use{session} = 1:size(position_response_array.dff{session},2);
    figure_name = 'binned activity of all cells';
end 

end

% use cells active in both sessions
cells_to_use = intersect(cells_to_use{1},cells_to_use{2});
disp([num2str(length(cells_to_use)) ' of ' num2str(length(activity_struct{session})) ' cells active on both sessions'])
for session = 1:num_sessions
    position_response_array.dff_active{session} = position_response_array.dff{session}(:,cells_to_use,:);
end