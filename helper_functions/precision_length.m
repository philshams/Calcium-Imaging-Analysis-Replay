function psize = precision_length(precision)
    % convert precision format into number of bytes
    switch precision
        case 'single'
            psize = 4;
        case 'double'
            psize = 8;
        case 'int64'
            psize = 8;
        case 'uint64'
            psize = 8;
        case 'float64'
            psize = 8;
        otherwise
            error('conversion of %s format not implemented\n', precision);
    end
end