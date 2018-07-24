function xyshifts = stacksregister_dft(stacks, templates, varargin)
    % STACKSREGISTER_DFT register stacks to templates using DFT based method
    %
    % xyshifts = stacksregister_dft(stacks, templates, xyshifts, ...)
    %
    % This function registers each frame of a stack with a template image.
    % It uses the Fourier transform based registration technique from Kuglin and
    % Hines (1975), which only infers (x, y) translations.
    %
    % INPUTS
    %   stacks - stacks of frames, as either
    %       1) a [X Y Z Channels Time] array-like object
    %       2) a cellarray of the previous type
    %   templates - reference images, as either
    %       1) a [X Y Z Channels] array
    %       2) a cellarray of the previous type
    %   xyshifts - (optional) default: []
    %       shifts for each frame and z-plane, as either
    %       1) a [2 Z Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % NAME-VALUE PAIR INPUTS (optional)
    %   margins - default: 0
    %       number of pixels to remove from borders before registering images,
    %       as either
    %       1) a scalar (same margins for X and Y)
    %       2) a vector of two scalars (separate margins for X and Y)
    %   maxshift - default: []
    %       maximum shift allowed, restraining the search space
    %   refchannel - default: []
    %       index of channel to use (see remarks)
    %   refstack - default: []
    %       index of a stack whose respective template is used to align all
    %       templates and stacks together
    %   usegpu - default: false
    %       accelerate computations using GPU-enabled functions (see remarks)
    %   ... - other name-value pair arguments accepted by stacksreduce (indices,
    %       chunksize, useparfor, verbose, etc.)
    %
    % OUTPUTS
    %   xyshifts - (x, y) translations to apply to each frame/plane, as either
    %       1) a [2, Z, Time] array
    %       2) a cellarray of the previous type (if several stacks)
    %
    % REMARKS
    %   In case stacks have several channels, 'refchannel' input is mandatory.
    %
    %   Reported estimated completion times are slightly optimistic if 'parfor'
    %   is used.
    %
    %   In case several stacks are given but only one template, all stacks are
    %   registered to this template. If several templates are provided, each
    %   stack is only registered to its own template.
    %
    %   If (x,y)-shifts are provided, they are added to the returned values,
    %   except if 'indices' are used.
    %
    %   The 'usegpu' and 'useparfor' options do not play nicely together. The
    %   'usegpu' option shall be used only if you are sure that your program is
    %   the only doing GPU computing.
    %
    % EXAMPLES
    %   % create a template and register a stack to it, in verbose mode
    %   avg_ref = stackstemplate(stack, 15, 20);
    %   xyshifts = stacksregister_dft(stack, avg_ref, 'verbose', true);
    %
    %   % use options to accelerate it (parallel computing and loading chunks)
    %   avg_ref = stackstemplate(stack, 15, 20);
    %   xyshifts = stacksregister_dft(stack, avg_ref, ...
    %       'useparfor', true, 'chunksize', 20, 'verbose', true);
    %
    %   % for long stacks, use 2 passes (1 for trend and 1 smaller shifts)
    %   win_size = 200;  % sliding window use to smooth 1st pass (x,y)-shifts
    %   maxshift = 10;   % constrain 2nd pass (x,y)-shifts close to the trend
    %   xyshifts_noisy = stacksregister_dft(stack, avg_ref, 'verbose', true);
    %   xyshifts_smoothed = medfilt1(xyshifts_noisy, win_size, [], 3);
    %   xyshifts = stacksregister_dft(stack, avg_ref, xyshifts_smoothed, ...
    %       'maxshift', maxshift, 'verbose', true);
    %
    % SEE ALSO stacksload, stacktranslate, stacksreduce, xysshow

    if ~exist('stacks', 'var')
        error('Missing stacks argument.')
    end
    unpack = ~iscell(stacks);

    stacks = stackscheck(stacks);
    nstacks = numel(stacks);

    if ~exist('templates', 'var')
        error('Missing templates argument.')
    elseif ~iscell(templates)
        templates = repmat({templates}, 1, nstacks);
    end

    if numel(templates) ~= nstacks
        error('Number of templates is different from number of stacks.');
    end

    for ii = 1:nstacks
        [nx, ny, nz, nc, ~] = size(stacks{ii});
        tpl_attr = {'size', [nx, ny, nz, nc]};
        varname = sprintf('templates{%d}', ii);
        validateattributes(templates{ii}, {'numeric'}, tpl_attr, '', varname);
    end

    % parse optional inputs
    parser = inputParser;
    parser.KeepUnmatched = true;  % keep extra inputs
    parser.addOptional('xyshifts', []);
    parser.addParameter('margins', 0);

    mshift_attr = {'scalar', 'integer', 'positive'};
    parser.addParameter('maxshift', [], ...
        @(x) validateattr_opt(x, {'numeric'}, mshift_attr, '', 'maxshift'));

    refstack_attr = {'scalar', 'integer', '>=', 1, '<=', nstacks};
    parser.addParameter('refstack', [], ...
        @(x) validateattributes(x, {'numeric'}, refstack_attr, '', 'refstack'));

    max_channel = min(cellfun(@(x) size(x, 4), stacks));
    refch_attr = {'vector', 'integer', '>=', 1, '<=', max_channel};
    parser.addParameter('refchannel', [], ...
        @(x) validateattr_opt(x, {'numeric'}, refch_attr, '', 'refchannel'));

    parser.addParameter('usegpu', false, ...
        @(x) validateattributes(x, {'logical'}, {'scalar'}, '', 'usegpu'));

    parser.parse(varargin{:});
    margins = parser.Results.margins;
    maxshift = parser.Results.maxshift;
    refstack = parser.Results.refstack;
    refchan = parser.Results.refchannel;
    usegpu = parser.Results.usegpu;

    margins = cellfun(@(x) checkmargins(x, margins), stacks, 'un', false);
    [~, xyshifts] = stackscheck(stacks, parser.Results.xyshifts);

    % error if multiple channels and no reference channel
    if nc > 1 && isempty(refchan)
        error(['Input stacks have multiple channels and ''refchannel'' ', ...
               'has not been specified.']);
    end

    if nc == 1
        refchan = 1;
    end

    % check templates size against the reference template, if any
    if ~isempty(refstack)
        warning(['The ''refstack'' option is deprecated and will ', ...
                 'be removed in next release.'])

        [nx, ny, nz, nc] = size(templates{refstack});
        tpl_attr = {'size', [nx, ny, nz, nc]};
        for ii = 1:nstacks
            varname = sprintf('templates{%d}', ii);
            validateattributes( ...
                templates{ii}, {'numeric'}, tpl_attr, '', varname);
        end
    end

    % prepare template images
    fft_templates = cell(1, nstacks);
    for ii = 1:nstacks
        cropped_template = prepare_chunk(templates{ii}, margins{ii}, refchan);
        fft_templates{ii} = fft2(cropped_template);
    end

    % registration as a map/reduce operation over each stack
    reg_fcn = @(x, tpl, mg) register_stack(x, tpl, mg, maxshift, refchan);
    if usegpu
        reg_fcn = @(x, tpl, mg) gather(reg_fcn(gpuArray(x), gpuArray(tpl)), mg);
    end
    reduce_fcn = @(x, y) cat(3, x, y);

    new_xyshifts = stacksreduce(stacks, reg_fcn, reduce_fcn, ...
        xyshifts, 'fft_template', fft_templates, 'margins', margins, ...
        'unpack', false, 'fcn_name', 'registration', parser.Unmatched);

    % warn user if they use input (x,y)-shifts and 'indices'...
    if isfield(parser.Unmatched, 'indices') && any(~cellfun(@isempty, xyshifts))
        warning(['Incompatible ''xyshifts'' and ''indices'' options: ', ...
                 '(x,y)-shifts input will not be added to the output.'])

    % ... or add previous (x,y)-shifts to newly computed ones
    else
        for ii = 1:nstacks
            if isempty(xyshifts{ii})
                continue;
            end
            new_xyshifts{ii} = new_xyshifts{ii} + xyshifts{ii};
        end
    end

    xyshifts = new_xyshifts;

    % register stacks through their templates, if a reference is designated
    if ~isempty(refstack)
        fft_ref = fft_templates{refstack};
        for ii = 1:nstacks
            if ii == refstack
                continue;
            end

            % add template (x,y)-shifts to the stack (x,y)-shifts
            xys_tpl = reg_fcn(templates{ii}, fft_ref, margins{ii});
            nframes = size(xyshifts{ii}, 3);
            xyshifts{ii} = xyshifts{ii} + repmat(xys_tpl, 1, 1, nframes);
        end
    end

    % do not return cellarrays if only one stack
    if unpack && nstacks == 1
        xyshifts = xyshifts{1};
    end
end

function validateattr_opt(x, varargin)
    % helper function to disable validation if input is empty
    if isempty(x)
        return;
    end
    validateattributes(x, varargin{:});
end

function chunk = prepare_chunk(chunk, margins, refchannel)
    % remove borders and rescale input chunk

    % only use reference channel
    chunk = chunk(:, :, :, refchannel, :);

    % remove borders
    mx = margins(1);
    my = margins(2);
    chunk = double(chunk(1+mx:end-mx, 1+my:end-my, :, :, :));

    % rescale chunk
    [nx, ~, nz, nc, nt] = size(chunk);
    chunk_flat = zscore(reshape(chunk, [], nz, nc, nt), [], 1);
    chunk = reshape(chunk_flat, nx, [], nz, nc, nt);

    % put channels side-by-side
    chunk = permute(chunk, [1, 2, 4, 3, 5]);
    chunk = reshape(chunk, nx, [], nz, nt);
end

function xyshifts = register_stack(chunk, fft_template, margins, maxshift, refchan)
    % register a chunk of a stack

    % prepare chunk frames
    cropped_chunk = prepare_chunk(chunk, margins, refchan);
    fft_chunk = fft2(cropped_chunk);

    % register template and chunk frames using DFT based registration
    nframes = size(chunk, 5);
    fft_template = repmat(fft_template, 1, 1, 1, nframes);
    xyshifts = dftregister(fft_template, fft_chunk, maxshift);
end

function xyshifts = dftregister(fft_template, fft_frame, maxshift)
    % register a frame using Kuglin and Hines phase correlation method

    % weighting coefficient to balance between phase correlation (alpha = 1)
    % and normal correlation (alpha = 0, no normalization)
    alpha = 0.5;

    % compute phase correlation from the normalized cross-spectrum
    cs = fft_template .* conj(fft_frame);
    cc = ifft2(cs ./ abs(cs).^alpha, 'symmetric');

    % constrain maximum shifts found
    if ~isempty(maxshift)
        cc(:, maxshift+2:end-maxshift, :) = NaN;
        cc(maxshift+2:end-maxshift, :) = NaN;
    end

    % split input dimensions
    cc_dims = num2cell(size(cc));
    [nx, ny] = deal(cc_dims{1:2});

    if numel(cc_dims) > 2
        other_dims = cc_dims(3:end);
    else
        other_dims = {1};
    end

    % deduce (x,y)-shift from the maximum in phase correlation
    [~, idx] = max(reshape(cc, [], other_dims{:}), [], 1);
    [x, y] = ind2sub([nx, ny], idx);

    % compensate for circular shifts
    x_mask = x > fix(nx / 2);
    x(x_mask) = x(x_mask) - nx;

    y_mask = y > fix(ny / 2);
    y(y_mask) = y(y_mask) - ny;

    % compensate for 1-based indexing
    x = x - 1;
    y = y - 1;

    % concatenate (x,y)-shifts
    xyshifts = cat(1, x, y);
end