classdef ConstantView < AbstractView
    % TODO doc

    properties (SetAccess = private)
        value  % filling value
        dims  % tensor dimensions
    end

    methods

        function obj = ConstantView(value, dims)
            % TODO doc

            % add a 2nd dimension if only one is given
            if numel(dims) == 1
                dims = [dims, dims];
            end

            obj.value = value;
            obj.dims = dims;
        end

        function sref = subsref(obj, s)
            % SUBSREF subscripted reference
            switch s(1).type
                case '()'
                    [~, subs_dims] = clean_subscripts(s.subs, obj.size());
                    sref = zeros(subs_dims, 'like', obj.value);
                    sref(:) = obj.value;

                case '.'
                    error('Not a supported indexing expression.')

                case '{}'
                    error('Not a supported indexing expression.')
            end
        end

        function new_view = permute(obj, order)
            % PERMUTE rearrange order of tensor dimensions

            % permute the dimensions
            n_order = max(order);
            n_dims = numel(obj.dims);
            new_dims = [obj.dims, ones(1, n_order - n_dims)];
            new_dims = new_dims(order);

            % create a new view with permuted dimensions
            new_view = ConstantView(obj.value, new_dims);
        end

    end

    methods (Access = protected)

        function dim = size_dim(obj, dim_idx)
            % retrieve size of one indexed dimension
            if dim_idx > numel(obj.dims)
                dim = 1;
            else
                dim = obj.dims(dim_idx);
            end
        end

        function n = max_ndims(obj)
            % maximum number of dimensions
            n = numel(obj.dims);
        end

    end
end