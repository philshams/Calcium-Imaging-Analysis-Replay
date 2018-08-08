classdef TensorView < AbstractView
    % TENSORVIEW virtual tensor to lazily access a subset of another tensor
    %
    % This class allows one to slice a tensor-like object without actually copying
    % data. Retrieval is done on-the-fly when data is accessed from the TensorView
    % object.
    %
    % EXAMPLE
    %   % create a 100x10 tensor
    %   ts = randn(100, 10);
    %   % create a view on some elements of the 2nd dimension
    %   ts_view = TensorView(ts, ':', [5, 3, 1])
    %   % size of the view
    %   size(ts_view)
    %   % check that content is the same
    %   isequal(ts(:, 5), ts_view(:, 1))
    %
    % SEE ALSO TensorView.TensorView, TIFFStack, TensorStack, MappedTensor

    properties (SetAccess = private)
        tensor   % indexed tensor
        indices  % subscript indices
    end

    methods

        function obj = TensorView(tensor, varargin)
            % TENSORVIEW create a new TensorView object
            %
            % obj = TensorView(tensor, varargin)
            %
            % INPUTS
            %   tensor - N-D array-like object
            %   varargin - any indexing pattern, : being replaced by ':' or []
            %
            % OUTPUTS
            %   obj - TensorView object

            n_indices = numel(varargin);

            tensor_ndims = ndims(tensor);
            indices = repmat({':'}, 1, max(n_indices, tensor_ndims));
            for i = 1:n_indices
                sub = varargin{i};
                if isempty(sub)
                    sub = ':';
                end
                indices{i} = clean_subscript(sub, size(tensor, i));
            end

            % remove spurious subscripts (trailing 1's and :)
            indices = indices(1:tensor_ndims);
 
            obj.tensor = tensor;
            obj.indices = indices;
        end

        function sref = subsref(obj, s)
            % SUBSREF subscripted reference
            switch s(1).type
                case '()'
                    [subs, subs_dims] = clean_subscripts(s.subs, obj.size());
                    s.subs = obj.map_subscripts(subs);
                    sref = subsref(obj.tensor, s);
                    sref = reshape(sref, subs_dims);

                case '.'
                    error('Not a supported indexing expression.')

                case '{}'
                    error('Not a supported indexing expression.')
            end
        end

        function new_view = permute(obj, order)
            % PERMUTE rearrange order of tensor dimensions

            % permute the underlying tensor
            new_tensor = permute(obj.tensor, order);

            % permute the indices
            n_order = max(order);
            n_dims = numel(obj.indices);
            new_indices = [obj.indices, cell(1, n_order - n_dims)];
            new_indices = new_indices(order);

            % create a new view with permuted tensor and indices
            new_view = TensorView(new_tensor, new_indices{:});
        end

    end

    methods (Access = protected)

        function dim = size_dim(obj, dim_idx)
            % retrieve size of one indexed dimension
            if dim_idx > numel(obj.indices)
                dim = 1;
            elseif strcmp(obj.indices{dim_idx}, ':')
                dim = size(obj.tensor, dim_idx);
            else
                dim = numel(obj.indices{dim_idx});
            end
        end

        function n = max_ndims(obj)
            % maximum number of dimensions
            n = numel(obj.indices);
        end

        function tensor_subs = map_subscripts(obj, subs)
            % convert subscript indices from view to tensor

            n_subs = numel(subs);
            tensor_subs = cell(1, n_subs);

            for i = 1:n_subs
                % linear indexing case
                if i == n_subs && i < numel(obj.indices)

                    % retrieve additional dimensions for tensor and view
                    n_dims = numel(obj.indices);
                    tensor_dims = arrayfun(@(x) size(obj.tensor, x), i:n_dims);
                    view_dims = arrayfun(@obj.size_dim, i:n_dims);

                    % convert linear indices from view to tensor
                    extra_subs = map_linear_indices( ...
                        subs{i}, tensor_dims, view_dims, obj.indices(i:end));

                    tensor_subs = [tensor_subs(1:i-1), extra_subs];

                elseif strcmp(obj.indices{i}, ':')
                    tensor_subs{i} = subs{i};

                elseif strcmp(subs{i}, ':')
                    tensor_subs{i} = obj.indices{i};

                else
                    tensor_subs{i} = obj.indices{i}(subs{i});

                end
            end
        end

    end
end

function subs = map_linear_indices(subs_lin, tensor_dims, view_dims, indices)
    % convert subscript indices for linear indexing from view to tensor

    if strcmp(subs_lin, ':')
        subs = indices;

    else
        view_ndims = numel(view_dims);

        subs_extra = cell(1, view_ndims);
        [subs_extra{:}] = ind2sub(view_dims, subs_lin);

        for i = 1:view_ndims
            if ~strcmp(indices{i}, ':')
                subs_extra{i} = indices{i}(subs_extra{i});
            end
            subs_extra{i} = subs_extra{i}(:);
        end

        if numel(subs_extra{1}) == 1
            subs = subs_extra;
        else
            subs = {sub2ind(tensor_dims, subs_extra{:})};
        end
    end
end