%% Algorithm training
clear all
ops.cell_diam        = 2;
ops.ex               = 10;
ops.cells_per_image  = 150;
ops.NSS              = 1;
ops.KS               = 5;
ops.MP               = 0;
ops.inc              = 20;
ops.fig              = 1;
ops.learn            = 1;
ops.data_path        = 'C:\Users\Ko Ho\Dropbox\My documents\Research\Matlab Programs\Own\GCaMP6';
ops.code_location    = 'C:\Users\Ko Ho\Dropbox\My documents\Research\Matlab Programs\Own\GCaMP6\DonutCode\learning_module';

% OGBFlag=1;
% if OGBFlag
%     TrainingDataFileName = 'GCaMP6_AvgImMFOGB.mat';
%     ModelSaveFileName    = 'GCaMP6_ModelMFOGB';
%     ops.cell_diam        = 15;
% else
%     TrainingDataFileName = 'GCaMP6_AvgImMFSoma.mat';
%     ModelSaveFileName    = 'GCaMP6_ModelMFSoma2';
%     ops.cell_diam        = 7;
% end

NormalizeFlag=1;
TrainingDataFileName = 'GCaMP6_AvgImMFBouton.mat';
ModelSaveFileName    = 'GCaMP6_ModelMFBouton5Basis17';

MPCC2_KSVD;