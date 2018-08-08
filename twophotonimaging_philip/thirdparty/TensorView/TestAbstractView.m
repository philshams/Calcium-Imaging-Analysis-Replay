classdef TestAbstractView < matlab.unittest.TestCase
    % TODO doc

    properties
        tensor   % regular tensor
        ts_view  % TensorView object
    end

    properties (TestParameter)
        % tested indexed dimensions
        dim_idx = {1, 2, 3, 4, 5};
        % tested indexing schemes
        subs = struct( ...
            'idx_flat', {{':'}}, ...
            'idx_all1', {{':'}}, ...
            'idx_all2', {{':', ':'}}, ...
            'idx_all3', {{':', ':', ':'}}, ...
            'idx_1', {{1}}, ...
            'idx_11', {{1, 1}}, ...
            'idx_111', {{1, 1, 1}}, ...
            'idx_121', {{1, 2, 1}}, ...
            'idx_part1', {{[2, 4, 7]}}, ...
            'idx_part2', {{[7, 2]}}, ...
            'idx_part3', {{1:5}}, ...
            'idx_part4', {{':', [2, 5]}}, ...
            'idx_part5', {{[2, 5], ':'}}, ...
            'idx_part6', {{':', ':', [2, 5]}}, ...
            'idx_part7', {{':', [2, 5], ':'}}, ...
            'idx_part8', {{[2, 5], ':', ':'}}, ...
            'idx_nd1', {{[1, 2, 3; 7, 6, 5]}}, ...
            'idx_nd2', {{[1, 2, 3; 7, 6, 5], ':'}}, ...
            'idx_nd3', {{':', [1, 2, 3; 7, 6, 5]}}, ...
            'idx_mask1', {{[true, false, true]}}, ...
            'idx_mask2', {{[true, false, true]'}}, ...
            'idx_mask3', {{[true, false, true; false, true, false]}}, ...
            'idx_empty1', {{2:1}}, ...
            'idx_empty2', {{2:1, ':'}}, ...
            'idx_empty3', {{2:1, ':', 2:1}}, ...
            'idx_empty4', {{2:1, ':', 2:1, ':'}}, ...
            'idx_empty5', {{[]}});
        % tested permutations of dimensions
        perm = struct( ...
            'perm1', {[1, 2, 3]}, ...
            'perm2', {[3, 2, 1]}, ...
            'perm3', {[1, 3, 2]}, ...
            'perm4', {[3, 1, 2]});
    end

    methods (Test)

        function testSize(testCase)
            % check size function, returning all dimensions

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            ts_size = size(testCase.tensor);
            view_size = size(testCase.ts_view);
            testCase.verifyEqual(view_size, ts_size);
        end

        function testSizeIdx(testCase, dim_idx)
            % check size function, with a dimension index

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            ts_size = size(testCase.tensor, dim_idx);
            view_size = size(testCase.ts_view, dim_idx);
            testCase.verifyEqual(view_size, ts_size);
        end

        function testSizeRetTwo(testCase)
            % check size function, with 2 outputs

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            [ts_size1, ts_size2] = size(testCase.tensor);
            [view_size1, view_size2] = size(testCase.ts_view);
            testCase.verifyEqual(view_size1, ts_size1);
            testCase.verifyEqual(view_size2, ts_size2);
        end

        function testSizeRetThree(testCase)
            % check size function, with 3 outputs

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            [ts_size1, ts_size2, ts_size3] = size(testCase.tensor);
            [view_size1, view_size2, view_size3] = size(testCase.ts_view);
            testCase.verifyEqual(view_size1, ts_size1);
            testCase.verifyEqual(view_size2, ts_size2);
            testCase.verifyEqual(view_size3, ts_size3);
        end

        function testNdims(testCase)
            % check ndims function

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            ts_ndims = ndims(testCase.tensor);
            view_ndims = ndims(testCase.ts_view);
            testCase.verifyEqual(view_ndims, ts_ndims);
        end

        function testIndexAll(testCase)
            % check indexing all dimensions

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            subs_all = repmat({':'}, 1, ndims(testCase.tensor));
            ts_sliced = testCase.tensor(subs_all{:});
            view_sliced = testCase.ts_view(subs_all{:});
            testCase.verifyEqual(view_sliced, ts_sliced);
        end

        function testIndexEnd(testCase)
            % check indexing with 'end'

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            subs_all = repmat({':'}, 1, ndims(testCase.tensor) - 1);
            ts_sliced = testCase.tensor(1:end, subs_all{:});
            view_sliced = testCase.ts_view(1:end, subs_all{:});
            testCase.verifyEqual(view_sliced, ts_sliced);
        end

        function testIndexEnd2(testCase)
            % check indexing with 'end' on the second (and last) dimension

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            ts_sliced = testCase.tensor(:, 1:end);
            view_sliced = testCase.ts_view(:, 1:end);
            testCase.verifyEqual(view_sliced, ts_sliced);
        end

        function testIndexEnd3(testCase)
            % check indexing with 'end' on the third (and last) dimension

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            ts_sliced = testCase.tensor(:, :, 1:end);
            view_sliced = testCase.ts_view(:, :, 1:end);
            testCase.verifyEqual(view_sliced, ts_sliced);
        end

        function testIndexing(testCase, subs)
            % check an indexing scheme

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            % try to index the tensor and check if it fails
            try
                ts_sliced = testCase.tensor(subs{:});
                expect_error = false;
            catch
                expect_error = true;
            end

            % try to index the TensorView, checking that it fails when it should
            if expect_error
                test_fcn = @() testCase.ts_view(subs{:});
                testCase.verifyError(test_fcn, 'TensorView:badsubscript');
            else
                view_sliced = testCase.ts_view(subs{:});
                testCase.verifyEqual(view_sliced, ts_sliced);
            end
        end

        function testPermute(testCase, perm)
            % check a permutation of dimensions

            % skip cases without TensorView object
            if isempty(testCase.ts_view)
                return
            end

            ts_permuted = permute(testCase.tensor, perm);
            view_permuted = permute(testCase.ts_view, perm);
            subs_all = repmat({':'}, 1, ndims(view_permuted));
            testCase.verifyEqual(view_permuted(subs_all{:}), ts_permuted);
        end

    end

end