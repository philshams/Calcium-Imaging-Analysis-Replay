function filt_frames = filterstripes(frames)
    % FILTERSTRIPES remove horizontal stripe artefact
    %
    % filt_frames = filterstripes(frames)
    %
    % This function is a really specific function to remove horizontal stripes.
    % To achieve this, it use a simple frequency-based low-pass filter on the
    % first dimension.
    %
    % It assumes stripes with about 1 pixels width (i.e. alternating pattern on
    % every horizontal line).
    %
    % INPUTS
    %   frames - contaminated images, as a ND array
    %
    % OUTPUT
    %   filt_frames - filtered images, as a ND array
    %
    % EXAMPLES
    %   % load some image
    %   I = double(imread('rice.png'));
    %
    %   % contaminate it with horizontal stripes
    %   I(1:2:end, :) = I(1:2:end, :) * 0.8;
    %
    %   % filter it
    %   J = filterstripes(I);
    %
    %   % compare contaminated, decontaminated and difference
    %   figure;
    %   subplot(131); imagesc(I); title('contaminated')
    %   subplot(132); imagesc(J); title('decontaminated')
    %   subplot(133); imagesc(I-J); title('difference')

    if ~exist('frames', 'var')
       error('Missing frame argument.');
    end
    validateattributes(frames, {'numeric'}, {'nonempty'}, '', 'frames');

    % FFT over line axis only, as we are dealing with an horizontal artefact
    ff_frames = fft(double(frames), [], 1);

    % select normalized frequencies to reject
    nf = size(ff_frames, 1);
    freqs = (0:(nf - 1)) ./ nf;

    frange = 0.043;  % half width of the window around Fs / 2 to reject
    high_freqs = freqs > (0.5 - frange) & freqs < (0.5 + frange);

    % removing high frequencies
    ff_frames(high_freqs, :) = 0;

    % converting back to spatial domain
    filt_frames = ifft(ff_frames, [], 1);
end
