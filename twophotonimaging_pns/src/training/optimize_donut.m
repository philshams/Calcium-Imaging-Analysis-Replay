function [result, models] = optimize_donut(train_imgs, valid_imgs, valid_labels, ...
                                           celldiam, pad, maxtime, seed, startpop)
    % TODO documentation
    % TODO check inputs + default values

    % remove borders, usually containing stripes
    train_imgs = train_imgs(pad:end-pad, pad:end-pad, :);
    valid_imgs = valid_imgs(pad:end-pad, pad:end-pad, :);
    valid_labels = valid_labels(pad:end-pad, pad:end-pad, :);

    % wrapper function to learn donuts on training data
    function model = donut_wrapper(donutargs)
        % retrieve donut parameters from input vector
        parameters = num2cell(donutargs);
        [ncells, KS, sig1, deltasig] = parameters{:};

        % fix random generator seed for reproducible results
        rng(seed);

        % learn a model
        ops.cells_per_image = ncells;
        ops.cell_diam   = celldiam;
        ops.NSS         = 1;
        ops.KS          = KS;
        ops.MP          = 0;
        ops.sig         = [sig1, sig1 + deltasig];
        ops.inc         = 20;
        ops.learn       = 1;
        ops.fig         = 0;
        ops.ex          = 1;

        % start learning and early exit if anything goes wrong
        model = donut_learn(train_imgs, ops, maxtime, false, false);
    end

    % optimized function
    thresh = ceil(celldiam / 2);
    optfcn = ...
        @(x) donut_score(valid_imgs, valid_labels, thresh, @donut_wrapper, x);

    % parameters bounds and start values (ncells, KS, sig1, deltasig)
    lb = [ 50,  1, 0.001, 0.001];
    ub = [300, 10,    50,    50];

    % initialize nsga2 options
    options = nsgaopt();
    options.popsize = 30;
    options.maxGen = 50;
    options.numObj = 2;
    options.numVar = 4;
    options.lb = lb;
    options.ub = ub;
    options.vartype = [2, 2, 1, 1];
    options.objfun = optfcn;

    % restart from an existing population if given
    if exist('startpop', 'var')
        options.initfun = {@initpop, startpop};
    end

    % adding a file tp save population information
    [folder, filename] = fileparts(tempname());
    options.outputfile = fullfile(folder, ['populations-', filename, '.txt']);
    fprintf('Saving population information in %s\n', options.outputfile)

    % optimization with NSGA-II (click on stop in figure to end it)
    rng(seed);
    result = nsga2(options);

    % learn each final unique model
    pops_var = unique(reshape([result.pops(end, :).var], 4, [])', 'rows');
    nmodels = size(pops_var, 1);
    models = cell(1, nmodels);
    for ii=1:nmodels
        models{ii} = donut_wrapper(pops_var(ii, :));
    end
end

function [y, cons] = donut_score(valid_imgs, valid_labels, thresh, learnfcn, donutargs)
    % function for NSGA-II to learn and validate donuts

    % start learning and early exit if anything goes wrong
    try
        model = learnfcn(donutargs);
    catch
        y = [0, inf];
        cons = [];
        return
    end

    % evaluate learned model on training data
    cellpos = celldetect_donut(valid_imgs, model);
    [tp, fp, ~] = celldetectperf(valid_labels, cellpos, thresh);

    % return values for NSGA-II
    nimgs = size(valid_imgs, 3);
    y = [-tp / nimgs, fp / nimgs];
    cons = [];
end
