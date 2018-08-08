function dF=dFoverF(signalRaw, span)
%%
signalRaw=signalRaw(:)+200;

mn = running_percentile(signalRaw,span,5);

dF=(signalRaw-mn)./mn;

% %reject very low outliers (if LED flickered or something)
% outliersThresh=prctile(dF,2);
% dF(dF<outliersThresh)=0;

%%
end
