classdef TestConstantView < TestAbstractView
    % Test suite for ConstantView
    % Use 'run(TestConstantView)' to run the whole suite.

    properties (MethodSetupParameter)
        % size of tested tensors
        dims = {1, 5, [100, 1], [110, 1], [12, 25], [10, 20, 30], [1, 1, 11]};
        % values to fill the tensor
        value = struct( ...
            'zeros', {0}, ...
            'ones', {1}, ...
            'true', {true}, ...
            'false', {false}, ...
            'double', {3.12});
    end

    methods (TestMethodSetup)

        function createTensor(testCase, dims, value)
            % create a new tensor and the corresponding ConstantView object

            % create the real tensor
            tensor = zeros(dims, 'like', value);
            tensor(:) = value;
            testCase.tensor = tensor;

            % create view tensor
            testCase.ts_view = ConstantView(value, dims);
        end

    end

end