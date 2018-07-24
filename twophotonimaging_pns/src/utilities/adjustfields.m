function varargout = adjustfields(varargin)
    % add missing fields in each input stucture arrays
    % TODO documentation
    % TODO input checks

    % all fields in all structures
    all_fields = cellfun(@fieldnames, varargin, 'un', false);
    fields = unique(cat(1, all_fields{:}));

    % add missing fields
    varargout = varargin;
    for ii=1:numel(varargout)
        % update structures with missing field
        for jj=1:numel(fields)
            if ~isfield(varargout{ii}, fields{jj})
                if isempty(varargout{ii})
                    [varargout{ii}.(fields{jj})] = deal();
                else
                    [varargout{ii}.(fields{jj})] = deal([]);
                end
            end
        end
        % reorder fields to match
        varargout{ii} = orderfields(varargout{ii}, fields);
    end
end