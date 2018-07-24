function [summ]=takeOnsets(dff, inds, DAQdata, times, jj)
%%
%jj=index within dff of interest
types={'a1', 'a2', 'b1', 'b2', 'n1', 'n2', 'r1', 'r2', 'p1', 'p2', 'gray'};
 %%
% figure;plot(DAQdata.stim_id);hold all;
% zer=zeros(size(DAQdata.stim_id));
% zer(behavInds)=3;
% plot(zer)
%%
% running profile
for i=1:length(types)
    ty=types{i};
    behavInds=inds.(ty);
    if ~strcmp(ty,'gray')
    behavInds=[behavInds(1); behavInds(find(diff(behavInds)>10)+1)];
    else
        
    behavInds=[ behavInds(find(diff(behavInds)>10)+1)];
 
    end
tms=bsxfun(@plus, behavInds, repmat(times, size(behavInds)));
[y x]=find(tms>length(DAQdata.encoder));
tms(y, :)=[];
[y x]=find(tms<1);
tms(y, :)=[];


sp=DAQdata.speed;
% sp(~behavInds)=nan;
summ.speed.(ty)=nanmean(sp(tms));
lick=DAQdata.lick;
% lick(~behavInds)=nan;
summ.lick.(ty)=nanmean(lick(tms));

summ.resp.(ty)=zeros(size(dff, 2), length(times));
% allResp=cell(size(dff, 2), 1);
     numPts=3;
     
for k=1:size(dff,2)
    nanDff=dff(jj,k).activity;
    
    [b, dev, stats]=glmfit(DAQdata.speed, nanDff);
    resids=stats.resid;
    
       allResp=resids(tms);
     mn=nanmean(allResp);
     
    summ.residResp.(ty)(k,:)=movmean(mn, numPts);
    summ.residci.(ty)(k,:)=1.96*nanstd(allResp)/(size(allResp,1)-1);
    
    
    
    if ~strcmp(ty, 'gray')
        otherInds=setdiff(1:length(DAQdata.encoder), [inds.(ty); inds.gray(:)]);
    nanDff(otherInds)=nan;
    end
    
    
    nanDff=nanDff';
    allResp=nanDff(tms);
     mn=nanmean(allResp);

    summ.resp.(ty)(k,:)=movmean(mn, numPts);
    summ.ci.(ty)(k,:)=1.96*nanstd(allResp)./(sum(~isnan(allResp),1)-1);
    
   
%     summ.ci.(ty)(k,:)=1.96*movstd(mn, numPts)/(numPts-1);
%     figure;plot(meanResp(k,:));
% figure;subplot(1,2,1);plot(allResp')
% subplot(1,2,2);plot(summ.resp.(ty)(k,:));vline(41)
end
end
    