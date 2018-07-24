result = load(resultspath);
rois_tf_chan2 = result.rois_tf;
[rois_tf_chan2.channel] = deal(2);
rois_tf = cat(2, result.rois_tf, rois_tf_chan2);
save(resultspath, 'rois_tf', '-append');