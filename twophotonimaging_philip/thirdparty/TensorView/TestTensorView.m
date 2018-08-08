classdef TestTensorView < TestAbstractView
    % Test suite for TensorView
    % Use 'run(TestTensorView)' to run the whole suite.

    properties (MethodSetupParameter)
        % size of tested tensors
        dims = {1, [100, 1], [110, 1], [12, 25], [10, 20, 30], [1, 1, 11]};
        % slices of tested tensors
        subs_slices = struct( ...
            'all', {{}}, ...
            'first', {{1}}, ...
            'part1', {{1:5}}, ...
            'part2', {{':', 1:5}}, ...
            'part3', {{':', ':', 1:5}}, ...
            'part4', {{':', 1:2:10}}, ...
            'part5', {{2:5, 4:10}}, ...
            'part6', {{':', ':', ':', ':'}}, ...
            'part7', {{':', ':', ':', ':', ':'}}, ...
            'part8', {{':', ':', 1:2, ':'}}, ...
            'part9', {{1, ':', 3}}, ...
            'part10', {{1, [2, 5, 3]}}, ...
            'part11', {{':', ':', 1, 1, 1, 1}});
    end

    methods (TestMethodSetup)

        function createTensor(testCase, dims, subs_slices)
            % create a new tensor and the corresponding TensorView object

            rng(1);  % fix the seed for reproducibility
            full_tensor = randn(dims);

            % indices to slice the tensor
            n_subs = numel(subs_slices);
            n_dims = numel(dims);
            subs_view = repmat({':'}, 1, max(n_subs, n_dims));
            subs_view(1:n_subs) = subs_slices;

            % try to index the original tensor and check if it failed
            try
                testCase.tensor = full_tensor(subs_view{:});
                expect_error = false;
            catch
                expect_error = true;
            end

            % try to create a TensorView, checking that it fails when it should
            if expect_error
                test_fcn = @() TensorView(full_tensor, subs_view{:});
                testCase.verifyError(test_fcn, 'TensorView:badsubscript');
                testCase.ts_view = [];
            else
                testCase.ts_view = TensorView(full_tensor, subs_view{:});
            end
        end

    end

end