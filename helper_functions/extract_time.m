function DAQclocks = extract_time(filename, nbuffer)
    % extract multiple time information

    % structure of BIN file:
    % (i64) seconds since the epoch 01/01/1904 00:00:00.00 UTC (using Gregorian
    %       calendar and ignoring leap seconds)
    % (u64) positive fractions of a second
    % (f64) millisecond timer
    % (f64) iteration number
    fields ={'int64', 'uint64', 'float64', 'float64'};

    fields_size = cellfun(@precision_length, fields);
    sample_size = sum(fields_size);

    % load each time field
    n_fields = numel(fields);
    samples = cell(1, n_fields);

    fid = fopen(filename, 'r');
    for ii = 1:n_fields
        offset = sum(fields_size(1:ii-1));
        skip = sample_size - fields_size(ii);
        fseek(fid, offset, 'bof');
        samples{ii} = fread(fid, inf, fields{ii}, skip, 'ieee-be');
    end
    fclose(fid);

    % assign returned variables
    iterations = linear_upscale(samples{4}, nbuffer);
    system_time = linear_upscale(samples{3}, nbuffer);

    % TODO check division is reasonable (should be 2^64-1?)
    labview_time = samples{1} + samples{2} ./ 2^64;
    labview_time = linear_upscale(labview_time, nbuffer);
    labview_date = datetime([1904, 1, 1]) + seconds(labview_time);
    labview_time = labview_time - labview_time(1);

    DAQclocks = table(iterations, system_time, labview_time, labview_date);
    DAQclocks.Properties.VariableUnits{'labview_time'} = 's';
    DAQclocks.Properties.VariableDescriptions{'labview_time'} = ...
        'recorded with labview timer';
    DAQclocks.Properties.VariableUnits{'system_time'} = 'ms';
    DAQclocks.Properties.VariableDescriptions{'system_time'} = ...
        'recorded with system timer (since boot on Windows)';
end