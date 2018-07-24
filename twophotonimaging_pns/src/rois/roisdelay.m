function delays = roisdelay(rois, nbplanes, fps)
    % ROISDELAY estimate ROIs time delay from top z-plane frame onset
    %
    % delays = roisdelay(rois, nbplanes, fps)
    %
    % INPUTS
    %   rois - ROIs, as a [#Stacks #ROIs] structure array with following fields
    %       - 'footprint': spatial extent, as a [X Y] array
    %                      or an empty scalar if the ROI is missing
    %       - 'zplane': z-plane of the ROI
    %       - 'channel': channel of the ROI
    %   nbplanes - number of z-planes in stacks
    %   fps - acquisition speed, in frames per second
    %
    % OTUPUTS
    %   delays - time delay in seconds for each ROI, as a [#Stacks #ROIs] array
    %
    % REMARKS
    %   Acquisition speed correspond to acquisition of individual frames, i.e.
    %   counting each z-plane as a separate frame.
    %
    %   Delays are given from the onset of the first z-plane.
    %
    %   For missing ROIs (empty footprint), NaN is returned.
    %
    % EXAMPLE
    %   fps = 29.97;
    %   nz = size(stack, 3);
    %   rdelays = roisdelay(rois, nz, fps);
    %
    % SEE ALSO cellsegment

    if ~exist('rois', 'var')
        error('Missing rois argument.');
    end
    roischeck(rois)

    if ~exist('nbplanes', 'var')
        error('Missing nbplanes argument.')
    end
    pos_int_attr = {'scalar', 'integer', 'positive'};
    validateattributes(nbplanes, {'numeric'}, pos_int_attr, '', 'nbplanes');

    if ~exist('fps', 'var')
        error('Missing fps argument.')
    end
    pos_attr = {'scalar', 'positive'};
    validateattributes(fps, {'numeric'}, pos_attr, '', 'fps');

    % time to acquire one frame
    dt = nbplanes / fps;

    [nstacks, nrois] = size(rois);
    delays = nan(nstacks, nrois);

    for ii = 1:nstacks
        for jj = 1:nrois
            % skip empty ROIs
            roi = rois(ii, jj);
            if isempty(roi.footprint)
                continue;
            end

            % get time offset within a frame and add delay from previous planes
            rows = roibbox(roi.footprint, 1);
            delay_in_frame = dt * mean(rows) / size(roi.footprint, 1);
            delays(ii, jj) = (roi.zplane - 1) * dt + delay_in_frame;
        end
    end
end