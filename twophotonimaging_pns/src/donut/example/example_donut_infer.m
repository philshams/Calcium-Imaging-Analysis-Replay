% replace OrigImg with any mean image from a GCaMP6 experiment
load('GCaMP6_example_imgs');
OrigImg = imgs(:, :, 1);

% pre-learned model parameters, model.W contains the templates
load('GCaMP6_example_model');

% If Nextract = 0, the model is calibrated to extract the number of cells
% it thinks are present in the image. If Nextract>0, it extracts exactly
% that many elements from the image (both cell contours and dendrite
% fragments). The calibrated default for GCaMP6_example_model is about 100.
Nextract = 0;

% Returns elem with all identified template locations at elem.ix and elem.iy,
% and with the element types at elem.map. Also returns the normalized image
% that was used to run the inference.
[elem, NormImg] = donut_infer(OrigImg, model, Nextract);

%% and here is one way to look at the results overlaid on an image
% selects which of the maps to look at. By default take the cell_map.
% change this to 1 (or 2) to see the locations for the dendrite fragments
which_map = 1;

% select only elements from that map
valid = (elem.map == which_map);

% can replace with the mean image, OrigImg
Im = NormImg;

figure('outerposition',[0 0 1000 1000])

sig = nanstd(Im(:));
mu = nanmean(Im(:));
M1 = mu - 4*sig;
M2 = mu + 12*sig;
imagesc(Im, [M1 M2])
colormap('gray')

hold on
plot(elem.iy(valid), elem.ix(valid), 'or', 'Linewidth', 1, 'MarkerSize', 10)

axis off
