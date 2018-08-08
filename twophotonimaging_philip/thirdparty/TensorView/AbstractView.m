classdef AbstractView
    % TODO doc

    methods (Abstract)
        sref = subsref(obj, s)
    end

    methods (Abstract, Access = protected)
        n = max_ndims(obj)
        dim = size_dim(obj, dim_idx)
    end

    methods

        function idx = end(obj, k, n)
            % END indicate last array index
            if k < n
                idx = obj.size_dim(k);
            elseif k > obj.ndims()
                idx = 1;
            else
                dims = obj.size();
                idx = prod(dims(k:end));
            end
        end

        function varargout = size(obj, dim_idx)
            % SIZE size of the tensor

            if exist('dim_idx', 'var')
                nargoutchk(1, 1);
                validateattributes(dim_idx, {'numeric'}, ...
                    {'integer', 'scalar', 'positive'}, '', 'dim_idx');
                varargout{1} = obj.size_dim(dim_idx);
                return
            end

            n_out = max(1, nargout);
            n_outs_dims = max(n_out, obj.max_ndims());
            dims = arrayfun(@(x) obj.size_dim(x), 1:n_outs_dims);

            if n_out == 1
                last_dim = 2;
                if any(dims ~= 1)
                    last_dim = max(2, find(dims ~= 1, 1, 'last'));
                end
                varargout{1} = dims(1:last_dim);
            else
                varargout = cell(1, n_out);
                varargout(1:end-1) = num2cell(dims(1:n_out-1));
                varargout{end} = prod(dims(n_out:end));
            end
        end

        function n = ndims(obj)
            % NDIMS number of dimensions
            n = numel(obj.size());
        end

        function n = numel(obj)
            % NUMEL number of elements
            n = prod(obj.size());
        end

        function flag = isnumeric(obj)
            % ISNUMERIC true for numeric array
            val = subsref(obj, substruct('()', {1}));
            flag = isnumeric(val);
        end

    end
end