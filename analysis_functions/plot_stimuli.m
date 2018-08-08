% ------------------------------------------
% plot sequence of stimuli
% ------------------------------------------

% get time axis
time = (behaviour_table.labview_time - behaviour_table.labview_time(1)) / 60;

% plot onsets
p1Binary = zeros(size(behaviour_table.stim_id));
p2Binary = zeros(size(behaviour_table.stim_id));
r1Binary = zeros(size(behaviour_table.stim_id));
r2Binary = zeros(size(behaviour_table.stim_id));
n1Binary = zeros(size(behaviour_table.stim_id));
n2Binary = zeros(size(behaviour_table.stim_id));
a1Binary = zeros(size(behaviour_table.stim_id));
b1Binary = zeros(size(behaviour_table.stim_id));
a2Binary = zeros(size(behaviour_table.stim_id));
b2Binary = zeros(size(behaviour_table.stim_id));

p1Binary(inds.p1)=1; r1Binary(inds.r1)=1; n1Binary(inds.n1)=1;
p2Binary(inds.p2)=1; r2Binary(inds.r2)=1; n2Binary(inds.n2)=1;

a1Binary(inds.a1)=1; b1Binary(inds.b1)=1; a2Binary(inds.a2)=1; b2Binary(inds.b2)=1;


figure('Position',[700 600 1400 500])

subplot(2,1,2); hold on;

plot(time, a1Binary,'color',[0 1 0]); plot(time, b1Binary,'color',[.8 .7 0]);
plot(time, a2Binary,'color',[0 .5 0]); plot(time, b2Binary,'color',[.4 .35 0]); 
plot(time, n1Binary,'color',[.5 .5 .5]); plot(time, n2Binary,'color',[0 0 0]);
plot(time, r1Binary,'color',[0 0 1]); plot(time, r2Binary,'color',[0 0 .6]);  
plot(time, p1Binary,'color',[1 0 0]); plot(time, p2Binary,'color',[.6 0 0]);
  

try
scatter(time(onset.a1),ones(size(onset.a1)),'.','markeredgecolor','black')
scatter(time(offset.a1),ones(size(offset.a1)),'.','markeredgecolor',[.5 .5 .5])
catch
end

ylim([.9 1.1])
legend('a1','b1','a2','b2','n1','n2','r1','r2','p1','p2') %,'Location','eastoutside')
set(gca,'YTickLabel',[]);
xlabel('time (mins)')
title('stimulus presentations')


subplot(2,1,1)

plot(time, behaviour_table.position_tunnel, 'linewidth', 2)
xlabel('time (mins)')
title('position in tunnel')