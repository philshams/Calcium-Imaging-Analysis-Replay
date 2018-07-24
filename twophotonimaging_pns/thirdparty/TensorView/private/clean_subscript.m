function [sub, sub_dim] = clean_subscript(sub, tensor_dim)
    % check and convert subscript indices of one dimension

    % full dimension indexing
    if strcmp(sub, ':')
        sub_dim = tensor_dim;

    % logical indices to linear indices
    elseif islogical(sub)
        sub = find(sub);
        if max(sub) > tensor_dim
            error('TensorView:badsubscript', ...
                  'Index exceeds matrix dimensions.');
        end
        sub_dim = numel(sub);

    % normal indexing, i.e with a vector of numbers
    else
        sub_attr = {'integer', 'real', 'positive', '<=', tensor_dim};
        try
            validateattributes(sub, {'numeric'}, sub_attr);
        catch err
            error('TensorView:badsubscript', err.message);
        end

        sub = sub(:);  % flatten indices arrays
        sub_dim = numel(sub);

    end
end