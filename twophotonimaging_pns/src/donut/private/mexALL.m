% functions provided by C files
cfuntions = {'add_back_coefs', 'pick_patches', 'unpick_patches', ...
             'extract_coefs2_SBC'};

% compile everything if any function is not from a mex file
if any(cellfun(@(x) exist(x) ~= 3, cfuntions))
    scriptdir = fileparts(mfilename('fullpath'));
    retdir = cd(scriptdir);
    try
        fprintf('Attempting to compile all C files...\n')
        cellfun(@(p) mex([p, '.c']), cfuntions);
        fprintf('Successfull.\n')
    catch
        fprintf('Something went wrong. Did you run mex -setup ?\n')
    end
    cd(retdir);
end
