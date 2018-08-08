% ------------------------------------------
% extract stimulus indices
% ------------------------------------------

% get indices of each stimulus
inds.ab = intersect(find(behaviour_table.stim_id<1.51), find(behaviour_table.stim_id>1.49));
inds.pun = intersect(find(behaviour_table.stim_id>2.9), find(behaviour_table.stim_id<3.1));
inds.rew = find(behaviour_table.stim_id>4);
inds.gray = setdiff(1:length(behaviour_table.stim_id),[inds.ab; inds.pun; inds.rew]);
inds.stim = setdiff(1:length(behaviour_table.stim_id),inds.gray);

% get particular stimulus identity by tunnel position
pos=behaviour_table.position_tunnel;
inds.a1=intersect(inds.ab, intersect(find(pos>0), find(pos<0.8))); % the four gratings
inds.b1=intersect(inds.ab, intersect(find(pos>.8), find(pos<1.65)));
inds.a2=intersect(inds.ab, intersect(find(pos>1.65), find(pos<2.5)));
inds.b2=intersect(inds.ab, intersect(find(pos>2.5), find(pos<3.4)));

inds.end1=intersect(find(pos>3.4), find(pos<4.15)); % end zone
inds.end2=intersect(find(pos>4.15), find(pos<5));

inds.n1=intersect(inds.ab, inds.end1); % neutral 1
inds.n2=intersect(inds.ab, inds.end2);
inds.p1=intersect(inds.pun, inds.end1); % punishment1
inds.p2=intersect(inds.pun, inds.end2);
inds.r1=intersect(inds.rew, inds.end1); % reward 1
inds.r2=intersect(inds.rew, inds.end2);

% get onset and offset times -- watch out for issue where stim turns on and
% off again repeatedly, before switching to other stims...

for s = 1:length(stims)
    
inds_since_last_stim = diff(inds.(stims{s}));
onset.(stims{s}) = inds.(stims{s})([1; find(inds_since_last_stim > 100)+1]);
offset.(stims{s}) = inds.(stims{s})([find(inds_since_last_stim > 100); length(inds.(stims{s}))]);

% throw out first few seconds
onset.(stims{s}) = onset.(stims{s})(onset.(stims{s}) > 50);
offset.(stims{s}) = offset.(stims{s})(offset.(stims{s}) > 50);


end
