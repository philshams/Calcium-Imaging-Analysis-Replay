
function chunk_sum = accum_stack(chunk)
    % sum a chunk of a stack over the time axis, and save the number of frames
    chunk_sum.sum = sum(chunk, 5);
    chunk_sum.nframes = size(chunk, 5);
end