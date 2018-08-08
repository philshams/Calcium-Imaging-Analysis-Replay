function [tforms, avgs_reg] = stacksregister_affine(stacks, template, varargin)
    % STACKSREGISTER_AFFINE register stacks with affine transform
    %
    % [tforms, avgs_reg] = stacksregister_affine(stacks, template, varargin)
    %
    % This function registers each z-plane of a stack with a template image,
    % using a geometric transform. It currently only works with single frame
    % stacks (e.g. stacks averages).
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels 1] array-like object
    %       2) a cellarray of the previous type
    %   templates - reference images, as either
    %       1) a [X Y Z Channels] array
    %       2) a cellarray of the previous type
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   margins - default: 0
    %       number of pixels to remove from borders before registering images,
    %       as either
    %       1) a scalar (same margins for X and Y)
    %       2) a vector of two scalars (separate margins for X and Y)
    %   refchannel - default: []
    %       index of channel to use (see remarks)
    %   tformtype - default: 'similarity'
    %       geometric transform used ('rigid', 'similiarity' or 'affine')
    %   maxiter - default: 1000
    %       maximum number of iterations for registration algorithm
    %   verbose - default: false
    %       boolean flag to display extra informations
    %
    % OUTPUTS
    %   tforms - affine transforms, as either
    %       1) a [Z] vector of affine2d objects
    %       2) a cellarray of the previous type (if several stacks)
    %   avg_regs - transformed stacks, as either
    %       1) a [X Y Z Channels 1] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % REMARKS
    %   In case stacks have several channels, 'refchannel' input is mandatory.
    %
    % SEE ALSO stacksregister_dft, stacktransform, roistransform, imregtform

    if ~exist('stacks', 'var')
        error('Missing stacks argument.');
    end
    unpack = ~iscell(stacks);

    if ~exist('template', 'var')
        error('Missing template argument.');
    end

    tpl_attr = {'size', nan(1, 4)};
    validateattributes(template, {'numeric'}, tpl_attr, '', 'template');
    [nx, ny, nz, nc] = size(template);

    stacks = stackscheck(stacks, [], [nx, ny, nz, nc, 1]);
    nstacks = numel(stacks);

    % parse optional inputs
    parser = inputParser;
    parser.addParameter('margins', 0);
    parser.addParameter('tformtype', 'similarity');
    parser.addParameter('verbose', false, ...
        @(x) validateattributes(x, {'logical'}, {'scalar'}, '', 'verbose'));

    max_channel = min(cellfun(@(x) size(x, 4), stacks));
    refch_attr = {'vector', 'integer', '>=', 1, '<=', max_channel};
    parser.addParameter('refchannel', [], ...
        @(x) validateattr_opt(x, {'numeric'}, refch_attr, '', 'refchannel'));

    maxiter_attr = {'scalar', 'integer', 'positive'};
    parser.addParameter('maxiter', 1000, ...
        @(x) validateattributes(x, {'numeric'}, maxiter_attr, '', 'maxiter'));

    parser.parse(varargin{:});
    margins = parser.Results.margins;
    refchan = parser.Results.refchannel;
    maxiter = parser.Results.maxiter;
    tformtype = parser.Results.tformtype;
    verbose = parser.Results.verbose;

    tform_types = {'affine', 'rigid', 'similarity'};
    tformtype = validatestring(tformtype, tform_types, '', 'tformtype');
    margins = cellfun(@(x) checkmargins(x, margins), stacks, 'un', false);

    % error if multiple channels and no reference channel
    if nc > 1 && isempty(refchan)
        error(['Input stacks have multiple channels and ''refchannel'' ', ...
               'has not been specified.']);
    end

    if nc == 1
        refchan = 1;
    end

    % register each z-plane of each stack average to the reference
    tforms = cell(1, nstacks);

    for ii = 1:nstacks
        % skip registration if current stack is the template
        if isequal(stacks{ii}, template)
            if verbose
                fprintf('registration for stack %d/%d skipped (%s)\n', ...
                        ii, nstacks, datestr(now()));
            end
            tforms{ii} = repmat(affine2d(eye(3)), 1, nz);
            continue
        end

        if verbose
            fprintf('registration for stack %d/%d started (%s)\n', ...
                    ii, nstacks, datestr(now()));
        end

        for jj = 1:nz
            fixed = template(:, :, jj, refchan);
            moving = stacks{ii}(:, :, jj, refchan);
            tforms{ii}(jj) = register_frame(fixed, moving, margins{ii}, ...
                tformtype, maxiter);
        end

        if verbose
            fprintf('registration for stack %d/%d completed (%s)\n', ...
                    ii, nstacks, datestr(now()));
        end
    end

    % apply transforms to get registered averages
    avgs_reg = cellfun(@stacktransform, stacks, tforms, 'un', false);

    % do not return cellarrays if only one stack
    if unpack && nstacks == 1
        tforms = tforms{1};
        avgs_reg = avgs_reg{1};
    end
end

function validateattr_opt(x, varargin)
    % helper function to disable validation if input is empty
    if isempty(x)
        return;
    end
    validateattributes(x, varargin{:});
end

function tform = register_frame(fixed, moving, margins, tformtype, maxiter)
    % estimate forward transforms to register moving to fixed

    % remove borders and rescale to get intensity images
    mx = margins(1);
    my = margins(2);

    fixed = mat2gray(fixed(1+mx:end-mx, 1+my:end-my));
    moving = mat2gray(moving(1+mx:end-mx, 1+my:end-my));

    % affine transform (initialize affine with rigid tranform)
    [optimizer, metric] = imregconfig('multimodal');
    optimizer.MaximumIterations = maxiter;
    optimizer.InitialRadius = 1e-3;

    tform = imregtform(moving, fixed, 'rigid', optimizer, metric);
    tform = imregtform(moving, fixed, tformtype, optimizer, metric, ...
        'InitialTransformation', tform);
end