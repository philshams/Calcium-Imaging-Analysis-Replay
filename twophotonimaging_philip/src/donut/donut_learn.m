function model = donut_learn(imgs, ops, maxtime, stopbutton, verbose)

% make sure that optimized functions are available
mexALL;

% default parameters values for those that are optional
if ~exist('maxtime', 'var')
    maxtime = inf;
end

if ~exist('stopbutton', 'var')
    stopbutton = true;
end

if ~exist('verbose', 'var')
    verbose = true;
end

%% normalize input data
y = double(imgs);

if isfield(ops, 'sig')
    sig1 = ops.sig(1);
    sig2 = ops.sig(2);

    for i = 1:size(y, 3)
        y(:,:,i) = normal_img(y(:,:,i), sig1, sig2);
    end
else
    sig1 = [];
    sig2 = [];
end

%% initialize model parameters
subs = cell(1, ops.NSS);
for i = 1:ops.NSS
    subs{i} = (i-1)*ops.KS+1:i*ops.KS;
end

dimSS = cellfun(@(x) length(x), subs);
Nmaps = sum(dimSS);

isfirst = zeros(1, Nmaps);
for i = 1:ops.NSS
    isfirst(subs{i}(1)) =  1;
end

lx = 2 * ops.cell_diam + 1;
dx = ops.cell_diam;
L = size(y, 1);
Ndata = size(y, 3);

W = .25 * randn(lx,lx, Nmaps);
zx = ceil(lx/3);
W(zx+1:zx+zx, zx+1:zx+zx,:) = randn(zx, zx, Nmaps);

nW = sum(sum(W.^2, 1),2).^.5;
W = W./repmat(nW, [lx lx 1]);

for j = 1:ops.NSS
    W(:,:,subs{j}(2:end)) = 0;
end

xs = repmat(-dx:dx, lx, 1);
ys = xs';
rs2 = xs.^2 + ys.^2;

tErr0 = 20.1;
tErr = tErr0;

%% train the model

dtErr = 5;

pos = zeros(Nmaps, 1);
for j = 1:length(subs)
    pos(subs{j}(1)) = 0;
end
pos(1) = 1;

PrVar = 1000;
Nmean = ops.KS * ops.cells_per_image;
Nmax = ops.KS * round(Nmean * 2/ops.KS);

% initialize batch variables
H = zeros(Nmax, Ndata);
X = zeros(Nmax, Ndata);
Nact = zeros(Ndata, 1);
Wy = zeros(L, L, Nmaps, Ndata);
yres = zeros(L, L, Ndata);

Bias = zeros(Nmaps, 1);
niter = 2500;
WtW = zeros(2*lx-1, 2*lx-1, Nmaps, Nmaps);
Cost = zeros(niter, 1);

% display a stop button
if stopbutton
    FS = msgbox('Stop the loop', 'STOPLOOP');
end

tic;
for n = 1:niter
    for i = 1:Nmaps
        W0 = W(:,:,i);
        for j = 1:Nmaps
            WtW(:,:,j,i) = filter2(W(:,:,j), W0, 'full');
        end
    end

    A = squeeze(WtW(lx, lx, :, :));
    Akki = zeros(size(A));
    for i =1:ops.NSS
        Akki(subs{i}, subs{i}) = A(subs{i}, subs{i}) + 1/PrVar * eye(dimSS(i));
    end
    Akki = inv(Akki);

    parfor j = 1:Ndata
        for i = 1:Nmaps
            Wy(:,:,i, j) = filter2(W(:,:,i), y(:,:,j), 'same');
        end
    end
    Wy = reshape(Wy, L*L*Nmaps, Ndata);

    Params = [Nmax tErr PrVar L lx Nmaps];
    yres = reshape(yres, L*L, Ndata);
    parfor j = 1:Ndata
        [H(:,j), X(:,j), yres(:,j), Nact(j), ~] = ...
            extract_coefs2_SBC(Wy(:,j), WtW, Params, y(:,:,j), ...
            W, Bias, Akki, isfirst, pos);
    end
    Wy = reshape(Wy, L, L, Nmaps, Ndata);
    yres = reshape(yres, L, L, Ndata);
    Cost(n) = mean(yres(:).^2);

    type = ceil(H/(L*L));
    hist_type = hist(type(:), 1:1:Nmaps);
    if ops.learn && min(hist_type)>0
        for j = 1:ops.NSS
            % add back the contribution from these maps
            imap = zeros(1, Nmaps);
            imap(subs{j}) = 1;
            add_back_coefs(yres, H, Params, X, W, imap, Nact);

            Params(7) = subs{j}(1);
            dW = pick_patches(yres, H, Params);

            COV = dW * dW'/size(dW,2);
            [U, ~] = svd(COV);

            xr = U' * dW;
            signs = 2 * (mean(xr > 0, 2) > 0.5) - 1;
            U = U .* repmat(signs', [lx^2 1]);

            if ops.MP
                U(:,2:end) = 0;
            elseif ops.inc
                k = ceil(n/ops.inc);
                U(:,1+k:end) = 0;
            end

            W(:, :, subs{j}) = reshape(U(:,1:dimSS(j)), lx, lx, dimSS(j));

            dWrec = U(:,1:dimSS(j)) * (U(:,1:dimSS(j))' * dW);

            unpick_patches(yres, H, Params, dWrec);

            absW = abs(W(:,:,subs{j}(1)));
            absW = absW / mean(absW(:));
            x0 = mean(mean(absW .* xs));
            y0 = mean(mean(absW .* ys));

            xform = [1 0 0; 0 1 0; -x0 -y0 1];
            tform_translate = maketform('affine', xform);

            for k = subs{j}
                W(:,:,k) = imtransform(W(:,:,k), tform_translate,...
                    'XData', [1 lx], 'YData', [1 lx]);
            end
        end
    end

    Nused = mean(Nact(:));
    nW = 1e-10 + sum(sum(W.^2, 1),2).^.5;
    W = W./repmat(nW, [lx lx 1]);

    if Nused > Nmean*1.5
        tErr = tErr + dtErr;
    elseif Nused < Nmean/1.5
        tErr = tErr - dtErr;
    elseif Nused > Nmean*1.1
        tErr = tErr + dtErr/5;
    elseif Nused < Nmean/1.1
        tErr = tErr - dtErr/5;
    elseif Nused > Nmean*1.01
        tErr = tErr + dtErr/20;
    elseif Nused < Nmean/1.01
        tErr = tErr - dtErr/20;
    end

    % which map is the cell map?
    S_area = zeros(ops.NSS, 1);
    for i =1:ops.NSS
        S_area(i) = sum(sum(rs2.*W(:,:,subs{i}(1)).^2)).^.5;
    end
    est_diam = 2*S_area+1;
    [~, cell_map] = min((est_diam - ops.cell_diam).^2);

    if cell_map > 1
        W0 = W;
        W(:,:,subs{1}) = W0(:,:,subs{cell_map});
        W(:,:,subs{cell_map}) = W0(:,:,subs{1});

        cell_map = 1;
    end

    % update figures every 10 iterations
    if ops.fig && rem(n, 10) == 0
        sign_center = -squeeze(sign(W(dx,dx,:)));
        sign_center(:) = 1;
        Wi = reshape(W, lx^2, Nmaps);
        nW = max(abs(Wi), [], 1);

        Wi = Wi./repmat(sign_center' .* nW, lx*lx,1);

        figure(1); visualSS(Wi, 4, ops.KS, [-1 1]); colormap('jet')
        figure(3); colormap('jet')

        H0 = H(:,ops.ex);
        elem = get_elem(H0, L, isfirst, ops.KS);
        valid = elem.map==cell_map;

        elem.iy(~valid) = [];
        elem.ix(~valid) = [];

        Im = y(:,:,ops.ex);
        sig = nanstd(Im(:));
        mu = nanmean(Im(:));
        M1 = mu - 4*sig;
        M2 = mu + 12*sig;
        imagesc(Im, [M1 M2])

        hold on
        plot(elem.iy, elem.ix, 'or', 'Linewidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', 'r')
        hold off
        drawnow
    end

    % display informatio about current iteration
    tcurrent = toc;
    if verbose
        fprintf('Iteration %d , elapsed time is %0.2f seconds\n', n, tcurrent);
    end

    % stop if maximum time exceeded
    if tcurrent > maxtime
        break;
    end

    % check state of stop button, if any
    drawnow;  % ensure clicks on FS are handled
    if stopbutton && ~ishandle(FS);
        break;
    end
end

% remove message box, if any
if stopbutton
    delete(FS);
end

% save current model
model.W         = W;
model.tErr      = tErr;
model.Bias      = Bias;
model.Params    = Params;
model.Nmaps     = Nmaps;
model.isfirst   = isfirst;
model.pos       = pos;
model.subs      = subs;
model.dimSS     = dimSS;
model.NSS       = ops.NSS;
model.KS        = ops.KS;
model.cell_map  = cell_map;
model.PrVar     = PrVar;
model.Nmax      = Nmax;
model.sig1      = sig1;
model.sig2      = sig2;
