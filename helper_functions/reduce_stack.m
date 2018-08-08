
function chunks_sum = reduce_stack(chunk_sum1, chunk_sum2)
    % merge results from to summed chunks
    chunks_sum.sum = chunk_sum1.sum + chunk_sum2.sum;
    chunks_sum.nframes = chunk_sum1.nframes + chunk_sum2.nframes;
end
