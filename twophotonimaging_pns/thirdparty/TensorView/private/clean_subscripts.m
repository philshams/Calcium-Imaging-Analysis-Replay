function [subs, subs_dims] = clean_subscripts(subs, tensor_dims)
    % check and convert subscript indices

    tensor_ndims = numel(tensor_dims);

    % check subscript indices for trailing dimensions
    trailing_subs = subs(tensor_ndims+1:end);
    empty_subs = cellfun(@isempty, trailing_subs);
    unitary_subs = cellfun( ...
        @(x) isscalar(x) && (x == 1 || strcmp(x, ':')), trailing_subs);

    if ~all(empty_subs | unitary_subs)
        error('TensorView:badsubscript', 'Index exceeds matrix dimensions.');
    end

    % initialize size of indexed tensor, with extra zero and unitary dimensions
    subs_dims = zeros(1, numel(subs));
    subs_dims(tensor_ndims+1:end) = unitary_subs;

    % trim trailing dimensions
    subs = subs(1:min(numel(subs), tensor_ndims));

    % copy of the first subscript, useful to compute final dimensions
    subs1 = subs{1};

    % convert subscript indices of all dimensions
    n_subs = numel(subs);
    for i = 1:n_subs
        if i < n_subs
            [subs{i}, subs_dims(i)] = clean_subscript(subs{i}, tensor_dims(i));
        else
            % linear indexing over the last dimensions
            last_dim = prod(tensor_dims(i:end));
            [subs{i}, subs_dims(i)] = clean_subscript(subs{i}, last_dim);
        end
    end

    % deal with indexing with a vector
    if numel(subs_dims) == 1
        % column vector if everything is indexed
        if strcmp(subs1, ':')
            subs_dims = [subs_dims, 1];

        % indexing a vector with a vector (or mask transformed into vector)
        elseif nnz(tensor_dims ~= 1) == 1 && (isvector(subs1) || islogical(subs1))
            n_elems = subs_dims;
            subs_dims = ones(1, tensor_ndims);
            subs_dims(tensor_dims ~= 1) = n_elems;

        % indexing a non-vector with a mask transformed into vector
        elseif islogical(subs1)
            subs_dims = size(subs{1});

        % otherwise reshape output based on indexing shape
        else
            subs_dims = size(subs1);
        end
    end
end