function [imgs, labels] = load_training_data(csv_filename, adatadir)
    % TODO documentation
    % TODO check inputs ?

    % parse csv to find relevant experiences
    exps_table = readtable(csv_filename);
    valid = strcmpi(exps_table.donutSegmentation, 'done');
    exps_valid = exps_table(valid, :);

    % retrieve mean images and labels
    animals = unique(exps_valid.Animal);
    folders = cellfun(@(x) fullfile(adatadir, x), animals, 'un', false);
    [imgs, labels] = cellfun( ...
        @(x) walk_animal_folder(x, exps_valid.ExpID), folders, 'un', false);

    % stack images and labels
    imgs = [imgs{:}];
    labels = [labels{:}];

    % return arrays instead of cellarrays
    [nx, ny] = size(imgs{1});
    imgs = reshape(cell2mat(imgs), nx, ny, []);
    labels = reshape(cell2mat(labels), nx, ny, []);
end

function [imgs, labels] = walk_animal_folder(folder, exp_ids)
    % explore animal folders to retrieve average images and labels

    % filter folders to keep those corresponding to dates
    folder_infos = dir(folder);
    mask = ~cellfun(@isempty, regexpi({folder_infos.name}, '\d\d_\d\d_\d\d'));
    mask = mask & cell2mat({folder_infos.isdir});

    % retrieve data
    subfolders = cellfun( ...
        @(x) fullfile(folder, x), {folder_infos(mask).name}, 'un', false);
    [imgs, labels] = cellfun( ...
        @(x) walk_exp_folder(x, exp_ids), subfolders, 'un', false);

    % stack images and labels
    imgs = [imgs{:}];
    labels = [labels{:}];
end

function [imgs, labels] = walk_exp_folder(folder, exp_ids)
    % explore folder of an experiment to load average images and labels

    % retrieve stack IDs from folder names
    folder_infos = dir(folder);
    stack_ids = regexp({folder_infos.name}, '^S1-T(\d+)_\(', 'tokens');

    % filter folders to keep those corresponding to stacks
    mask = ~cellfun(@isempty, stack_ids);
    mask = mask & cell2mat({folder_infos.isdir});

    folder_infos = folder_infos(mask);
    stack_ids = cellfun(@(x) str2double(x{1}), stack_ids(mask));

    % load data from folders if any corresponds to an experiment ID
    if any(ismember(stack_ids, exp_ids))
        catfn = @(x) fullfile(folder, x);
        subfolders = cellfun(catfn, {folder_infos.name}, 'un', false);
        [imgs, labels] = cellfun(@load_images, subfolders, 'un', false);

        % stack images and labels
        imgs = [imgs{:}];
        labels = [labels{:}];
    else
        imgs = {};
        labels = {};
    end
end

function [imgs, labels] = load_images(folder)
    % load averages of registered images and corresponding labels

    % filter filenames to get only .mat files for each slice
    folder_infos = dir(folder);
    mask = ~cellfun(@isempty, regexpi({folder_infos.name}, '^S1-.*\.mat$'));
    catfn = @(x) fullfile(folder, x);
    filenames = cellfun(catfn, {folder_infos(mask).name}, 'un', false);

    % preallocate returned variables
    nfiles = numel(filenames);
    imgs = cell(1, nfiles);
    labels = cell(1, nfiles);

    % load images and labels (labels might be missing)
    for ii=1:nfiles
        w = warning('off', 'MATLAB:load:variableNotFound');
        results = load(filenames{ii}, 'regavg', 'new_lbl_mask2');
        warning(w);

        imgs{ii} = results.regavg;

        % in case their is no mask...
        if ~isfield(results, 'new_lbl_mask2')
            labels{ii} = zeros(size(results.regavg));

        % ... or if the mask has the wrong size
        elseif any(size(results.new_lbl_mask2) ~= size(results.regavg))
            labels{ii} = zeros(size(results.regavg));

        else
            labels{ii} = results.new_lbl_mask2;

        end
    end
end
