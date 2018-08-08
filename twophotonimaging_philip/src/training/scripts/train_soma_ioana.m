%% retrieve mean images and labels from Ioana's datasets
% data comes from the network drive, so it takes a lot of time, hence be patient
% and save results

% pick M-drive path on your system to get Ioana's data folder
mdrive_path = uigetdir;
adatadir = fullfile(mdrive_path, 'Data', 'ImageData', 'AData', 'gaslioan');

[imgs, labels] = load_training_data('GCaMP6_Soma_Ioana.csv', adatadir); %#ok<ASGLU>
save('ioana_data', 'imgs', 'labels', '-v7.3');
clear imgs labels

%% statistics: number of cells, rois size
% look at images statistics to give good guesses about cell size and number to
% donut algorithm

data = matfile('ioana_data');

% number of cells labeled per average frame
[~, ~, nlabels] = size(data, 'labels');
ncells = zeros(1, nlabels);
for ii=1:nlabels
    ncells(ii) = numel(unique(data.labels(:, :, ii))) - 1;
end

% cell size from mask size in labeled frames
cell_sizes = nan(nlabels, max(ncells));
for ii=1:nlabels
    lbls = data.labels(:, :, ii);
    idx = nonzeros(unique(lbls));
    for jj=1:length(idx)
        [nx, ny] = find(lbls == jj);
        cell_sizes(ii, jj) = max(range(nx), range(ny));
    end
end

% plot distributions of number of cell per image and cell size
figure;

subplot(121);
histogram(ncells(ncells > 0), 'Normalization', 'pdf');
grid on; axis tight;
xlabel('# of cells per image');
ylabel('density');

subplot(122);
histogram((cell_sizes(:) - 1) / 2, ...
          'BinMethod', 'integers', 'Normalization', 'probability');
grid on; axis tight;
xlabel('half window size of a cell');
ylabel('frequency');

%% optimize donut model on a manageable subset of data
% find candidate models with different tradeoffs of true positives and false
% positives, using NSGA-II multi-objective optimization algorithm

% load Ioana's dataset, previously grabbed from the server
data = matfile('ioana_data');

% training images, clean enough to allow donut algorithm to easily pick the
% shape of cells in its filters
train_idx = 2345:2347;
train_imgs = data.imgs(:, :, train_idx);

% validation images, picking some randomly
[valid_imgs, valid_labels, valid_idx] = sample_imgs(data, 50, train_idx);

% get output of NSGA-II algorithm and candidate models
[result, models] = ...
    optimize_donut(train_imgs, valid_imgs, valid_labels, 7, 70, 120, 12346);

% save results (and metadata)
save('ioana_models.mat', 'result', 'models', 'train_idx', 'valid_idx');

%% check results on a test set and compare to Ko Ho's model

% load Ioana's dataset and learnt models
data = matfile('ioana_data');
load('ioana_models.mat');

% test datasets
ntest = 300;
[test_imgs, test_labels, test_idx] = ...
    sample_imgs(data, ntest, [train_idx, valid_idx]);

% models results
cellpos = cellfun(@(x) celldetect_donut(test_imgs, x), models, 'un', false);
[tp, fp, ~] = cellfun(@(x) celldetectperf(test_labels, x, 4), cellpos);
tp = tp / ntest;
fp = fp / ntest;

% comparison with Ko Ho's model
cellpos_k = celldetect_donut(test_imgs, 'GCaMP6_ModelMFSoma7');
[tp_k, fp_k, ~] = celldetectperf(test_labels, cellpos_k, 4);
tp_k = tp_k / ntest;
fp_k = fp_k / ntest;

% summarize results
objs = reshape([result.pops(end, :).obj], 2, []);

figure; hold on; grid;
plot(1 - objs(1, :), objs(2, :), 'o');
plot(tp, fp, 'o');
plot(tp_k, fp_k, 'o');
xlabel('true positives per image');
ylabel('false positives per image');
legend('models w/ validation dataset', 'models w/ test dataset', ...
       'Ko Ho''s w/ test dataset', 'Location', 'northwest');

% save each model with a name reflecting its performance
for ii=1:length(models)
    model = models{ii}; %#ok<NASGU>
    filename = sprintf('GCaMP6_Soma_Ioana_tp%.0f_fp%.0f.mat', tp(ii), fp(ii));
    save(filename, 'model');
end

%% load training data for cell segmentation

% load Ioana's dataset, previously grabbed from the server
data = matfile('ioana_data');

% load some training data, picking them randomly
[train_imgs, train_labels, train_idx] = sample_imgs(data, 400);

% extract patches surrounding each cell center
celldiam = 7;
[patches, labels] = load_training_patches(train_imgs, train_labels, celldiam);

% display (some) extracted patches and corresponding masks
[ncells, nx, ny] = size(patches);
split_patches = mat2cell(patches, ones(1, ncells), nx, ny);
split_patches = cellfun(@squeeze, split_patches, 'un', false);
tpatches = cell2mat(reshape(split_patches(1:40000), 200, 200));

split_labels = mat2cell(labels, ones(1, ncells), nx, ny);
split_labels = cellfun(@squeeze, split_labels, 'un', false);
tlabels = cell2mat(reshape(split_labels(1:40000), 200, 200));

figure;
ax(1) = subplot(121); imagesc(tpatches); title('cell patches');
ax(2) = subplot(122); imagesc(tlabels); title('cell masks');
linkaxes(ax, 'xy');

% save the training dataset
save('ioana_patches.mat', 'patches', 'labels', 'celldiam', 'train_idx');

%% train classifiers (one per patch pixel) for cell segmentation

% load training data (cell patches and corresponding masks)
load('ioana_patches');

% train LDA classifiers (one per pixel)
[~, nx, ny] = size(patches);
[xs, ys] = meshgrid(1:nx, 1:ny);
features = reshape(patches, [], nx * ny);

rng(1);  % for reproducible results
classifiers = ...
    arrayfun(@(x, y) fitcdiscr(features, labels(:, x, y)), xs, ys, 'un', false);

% plot errors on cross-validated classifiers (can take some time)
cvloss = cellfun(@(m) kfoldLoss(crossval(m)), classifiers);
figure; imagesc(1 - cvloss); colorbar; title('cross-validated accuracy');

% only keep LDA coefficients and save them (lighter than full objects)
coeffs = cellfun(@(m) m.Coeffs(1, 2), classifiers, 'un', false);
model = struct('celldiam', celldiam, ...
               'classifiers', {coeffs}, ...
               'predictfcn', @(m, x) x * m.Linear + m.Const < 0);

save('GCaMP6_Soma_Ioana_lda', 'model', 'train_idx');

%% display some results using both cell detection and segmentation

% load Ioana's dataset, previously grabbed from the server
data = matfile('ioana_data');
timgs = sample_imgs(data, 10);

% use learnt models for detection and segmentation
cellpos = celldetect_donut(timgs, 'GCaMP6_Soma_Ioana_tp77_fp71');
mask = cellsegment(timgs, cellpos, 'GCaMP6_Soma_Ioana_lda');

% display results
roisgui(timgs, [], mask);
