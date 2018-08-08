# Change log

## Version 0.10.0 (2018-01-05)

- New features
    - `stacksload` detect Z-stacks acquired with recent ScanImage and
      deinterleave frames accordingly
    - new optional input for `stackscheck` and `stackcheck`, to provide the
      name of the checked variable
    - new function `split_mrois_stack` to divide a stack with multiple
      ScanImage ROIs into separate stacks
    - new function `extractdff_prc` to compute dF/F0 from traces using running
      percentiles
    - new function `roisfilter` to apply a filtering function to the trace of
      each ROI
    - new function `stackszshift` to translate stacks and associated
      (x,y)-shifts over the z-axis
    - added options to `stacksoffsets_gmm` to selected the number of mixture
      components and the random seed
    - added `forcecell` option to the `stacksload` function, to ensure that a
      cellarray of stack(s) is returned
    - new function `roisdelay` to estimate time delay from acquisition onset
      for each ROI
    - new function `pipeline_register` to perform all registration steps and
      save results in a row, allowing interruptions and restarts
    - new function `pipeline_segment` to perform across days registration and
      ROIs edition, and saving results in a row
    - new functions `stacksregister_affine`, `stacktransform` and
      `roistransform` to find geometric transformations betweem stacks apply
      them to stacks and ROIs

- Bug fixes
    - fix `stacksload` crashing if user forgot to give at least one output
    - fix `stackscnmf`, making `xyshifts` input really optional
    - make `parse_si_header` work with stack containing dummy frames
    - fix selection of empty ROIs in `RoisModel` and in `AnnotateRoi`
    - fix channel detection in `size_from_grabfile` function
    - modified 'stacks...' functions to return cellarrays if input is a
      cellarray of stacks (even for one stack)
    - fix `stacksregister_dft` crashing when using reference stack ID
    - fix extraction of ROIs with 1 pixel footprint in `stacksextract`
    - fix ROIs with bad footprint (no active pixels) returned by `roisgui`
    - fix offset computation for constant frames in `stacksoffsets_gmm`

- Breaking changes
    - renamed `separate_rois` function into `roisseparate`
    - removed `stackfilter` function, unused and replaceable by `filtfilt`
    - changed optional inputs of `stacksoffsets_gmm` into name-value pairs
    - changed optional inputs of `stacksload` into name-value pairs
    - make 'refchannel' input mandatory in the `stacksregister_dft` function if
      input stacks have several channels

- Deprecation
    - `stackscnmf` will be removed in version 0.11.0
    - `stacksprctile` will be removed in version 0.11.0
    - `refstack` option of `stacksregister_dft` will be removed in version
      0.11.0


## Version 0.9.0 (2017-06-02)

- New features
    - regrouped panels in `roisgui`, to reduce the number of opened windows
    - add lightweight and non-blocking GUI to look at stacks, using the
      function `stacksgui`
    - `toolbox_setup` function to download dependencies and configure Matlab
      search path, replacing `install.bash` script
    - new function `separate_rois` to remove overlap and add a small gap
      between ROIs, used in `cellsegment` and also available in `roisgui`
    - new option in `roisgui` to add ROIs using a range of cell diameters
    - handling of a cellarray of char in the annotations field of ROIs, and
      new option in `roisgui` to add a annotation to the existing ones
    - add shortcuts support in `roisgui`

- Bug fixes
    - fix bug in `stacksextract` wrt. empty ROIs (empty footprints), which now
      have empty traces
    - `stacktranslate` now returns an array of the right class (same as input)
    - fix `roisgui` side panel size on screens with lower resolution
    - fix listeners triggering in RoisModel after ROIs modifications

- Breaking changes
    - updated `stackscnmf` function to use new code from CNMF, making use of
      tiling functionality (concatenated stacks not yet re-implemented)


## Version 0.8.1 (2017-01-16)

- Bug fixes
    - minor fix in `multiple_stacks_example.m` script


## Version 0.8.0 (2017-01-16)

- New features
    - common map/reduce function `stacksreduce` used as a backbone for other
      functions
    - homogenenous name-value pair arguments for `stacksmean`, `stacksminmax`,
      `stacksregister_dft` and `stracksextract` (`chunksize` and `verbose`
      options available for all of them)
    - handling by `stacksload` of stacks saved by ScanImage with an incorrect
      number of frames (to be correctly deinterleaved)
    - added options to `stacksregister_dft`: reference stack, reference
      channel, optional input (x,y)-shifts, different X and Y margins, GPU
      computing
    - added `filterfcn` option to `stackstemplate`, to filter batches before
      averaging  in order to avoid aligning on artifacts
    - new function `filtersmall` to remove "diamond shaped" artifact in images
      acquired with resonant scanner (useful with `stackstemplate`)
    - new function `xysshow` to display (x,y)-shifts
    - new function 'offsetsshow` to inspect estimated offsets.

- Bug fixes
    - update `stacksload` to use the new `getImageTags` method of TIFFStack, to
      retrieve tags
    - remove ROIs close to any border in `RemoveRois` component
    - fix bug affecting registration of stacks with several z-planes and
      channels
    - fix bug in registration triggered by clipping sparse images and use of
      margins and maxshifts options
    - make `parse_si_header` work with partially corrupted headers

- Breaking changes
    - split offset estimation from stacks and ROIS traces extraction (API
      change for `stacksextract` and replacing `estimate_offsets_gmm` with
      `stacksoffsets_gmm`)
    - new API for `stacksmean`, `stacksminmax`, `stacksregister_dft` and
      `stracksextract`
    - `stackreduce` function replaced by a more generic `stacksreduce` function


## Version 0.7.1 (2016-12-21)

- Bug fixes
    - use of a small regularization term in `estimate_offsets_gmm` to avoid
      failure of the GMM fit


## Version 0.7.0 (2016-12-07)

- New features
    - much faster `stacksextract`, e.g. 18x faster with 2 local stacks of
      512-by-512-by-1-by-1-by-2160 and 348 ROIs
    - added option (true by default) to `stacksextract` to remove the smallest
      value of each stack to the extracted traces
    - ScanImage v2016 metadata support in `stacksload`
    - optional output of `stacksload` to retrieve TIFF frames headers
    - new function `parse_si_header` to get ScanImage retrieve ScanImage
      metadata from TIFF headers
    - new function 'stackstemplate' to automatically create reference images
      for registration

- Bug fixes
    - correct offset estimation in `stacksextract` using `estimate_offsets_gmm`
    - warning in `stacksload` in case of bad numbering of input TIFF files,
      causing a wrong order in the concatenated sequence (see ISSUES section of
      `stacksload` documentation)
    - better handling of long sequences registration (see #759a841)
    - deletion of overlapping ROIs close to borders in `roisgui`
    - extraction of ROIs information with`importadata` even when reference
      stack is not given

- Breaking changes
    - minor changes in API of `stacksextract`, for optional parameters


## Version 0.6.1 (2016-06-27)

- Bug fixes
    - corrected paths in `install.bash`
    - better handling of ROIs at the border in `stackscnmf`
    - various mistakes in `importadata`
    - add documentation for `maxshift` parameter of `stacksregister_dft`

- Other changes
    - use of Jaccard distance to sort ROIs in `stackscnmf` function
    - ROIs that are empty in all stacks are now removed from the results of
      `stackscnmf`


## Version 0.6.0 (2016-06-22)

- New features:
    - ScanImage v5 metadata support in `stacksload`
    - annotations in `roisgui`
    - replicated operations on ROIs over stacks in `roisgui`
    - neuropil decontamination (Constrained NMF) with `stacksunmix`
    - neuropil decontamination (Constrained NMF) in `roisgui`
    - parallel trace extraction with `stacksextract`
    - more detection models for `celldetect_donut`

- Other changes:
    - provided values for z-planes/channels in `stacksload` overload ScanImage
      and GRABinfo.mat metadata (used to be the other way around)


## Version 0.5.0 (2016-03-06)

First tagged version.
