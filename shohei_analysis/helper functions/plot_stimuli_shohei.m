% ------------------------------------------
% plot sequence of stimuli
% ------------------------------------------

% get time axis
time = (behaviour_table.labview_time - behaviour_table.labview_time(1)) / 60;

% make binary versions of stimuli
r1Binary = zeros(size(behaviour_table.stim_id));
a1Binary = zeros(size(behaviour_table.stim_id));
b1Binary = zeros(size(behaviour_table.stim_id));
a2Binary = zeros(size(behaviour_table.stim_id));
b2Binary = zeros(size(behaviour_table.stim_id));

r1Binary(inds.r1)=1;
a1Binary(inds.a1)=1; b1Binary(inds.b1)=1; a2Binary(inds.a2)=1; b2Binary(inds.b2)=1;

% plot binary versions of stimuli
figure('Position',[700 600 1400 500])
subplot(2,1,2); hold on;

plot(time, a1Binary,'color',[0 1 0]); plot(time, b1Binary,'color',[.8 .7 0]);
plot(time, a2Binary,'color',[0 .5 0]); plot(time, b2Binary,'color',[.4 .35 0]); 
plot(time, r1Binary,'color',[0 0 1]); 


try
scatter(time(onset.a1),ones(size(onset.a1)),'.','markeredgecolor','black')
scatter(time(offset.a1),ones(size(offset.a1)),'.','markeredgecolor',[.5 .5 .5])
catch
end

ylim([.9 1.1])
legend('a1','b1','a2','b2','r1') %,'Location','eastoutside')
set(gca,'YTickLabel',[]);
xlabel('time (mins)')
title('stimulus presentations')


subplot(2,1,1)

plot(time, behaviour_table.position_tunnel, 'linewidth', 2)
xlabel('time (mins)')
title('position in tunnel')