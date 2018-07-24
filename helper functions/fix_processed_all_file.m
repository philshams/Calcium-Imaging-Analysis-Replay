% -----------------------
% Fix processed_all file
% -----------------------

% load the processed_all files to concatenate
processed_all_z_12 = load('C:\Drive\Rotation3\data\egr2_15_11_top_2\processed_all.mat');
processed_all_z_34 = load('C:\Drive\Rotation3\data\egr2_modified_file\processed_all_z_shift_correction');
processed_all_z_34 = processed_all_z_34.egr_all_chan_2;

processed_all_z_1234 = processed_all_z_34;

% modify fields as necessary
processed_all_z_1234.rois(:,1:386/2) =  processed_all_z_34.rois(:,1:386/2);
processed_all_z_1234.rois(1,386/2+1:386/2+78) = processed_all_z_12.rois;
processed_all_z_1234.rois(2,386/2+1:386/2+78) = processed_all_z_12.rois;

% 
% processed_all_z_1234.dff(:,1:386/2) =  processed_all_z_34.dff(:,1:386/2);
% processed_all_z_1234.dff(:,386/2+1:) =  processed_all_z_34.dff(:,1:386/2);
% 
% 
% processed_all_z_1234.f0 = 
% 
% 
% processed_all_z_1234.rois_tf =
% processed_all_z_1234.ts =
