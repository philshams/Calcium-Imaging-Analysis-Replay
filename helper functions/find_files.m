function filenames = find_files(files_dir, files_pattern, only_one)
    % helper function to find files matching a simple pattern

    full_pattern = fullfile(files_dir, files_pattern);
    files_info = dir(full_pattern);

    if isempty(files_info)
        filenames = [];
    else
        filenames = fullfile({files_info.folder}, {files_info.name});
    end

    if only_one
        % check that one and only one file has been found
        if isempty(filenames)
            error('No file matching %s!\n', full_pattern);
        elseif numel(filenames) > 1
            error('More than one file matching %s!\n', full_pattern);
        end
        filenames = filenames{1};
    end
end