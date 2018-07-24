# Two-photon imaging toolbox


## Introduction

This toolbox provides routines to analyze data from two-photon imaging
systems, automating preprocessing steps such as:

- loading (on-demand) all images from sequences,
- registration of images,
- averaging sequences,
- visualizations of images and regions-of-interest (ROIs),
- extraction of traces from ROIs,
- neuropil decontamination.

It intends to be a light wrapper around publicly available packages, providing
the right amount of glue code to make them nicely interoperate with each other
and work on large datasets.


## Dependencies

The toolbox requires Matlab (tested on Matlab 2016b) and the following
packages:

- [TIFFStack](https://github.com/DylanMuir/TIFFStack)
- [MappedTensor](https://github.com/DylanMuir/MappedTensor)
- [TensorStack class](https://github.com/DylanMuir/TensorStack)
- [TensorView class](https://bitbucket.org/lasermouse/TensorView)
- [running_percentiles function](http://www.mathworks.com/matlabcentral/fileexchange/48201-running-percentile)
- [uipickfiles](http://www.mathworks.com/matlabcentral/fileexchange/10867-uipickfiles--uigetfile-on-steroids)
- [NGPM](http://www.mathworks.com/matlabcentral/fileexchange/31166-ngpm-a-nsga-ii-program-in-matlab-v1-4)
  (optional, only for model training)
- [Constrained NMF](https://github.com/epnev/ca_source_extraction) and its
  dependencies ([SPGL1](https://github.com/mpf/spgl1),
  [CVX](http://cvxr.com/cvx/download/)
  [Continuous time sampler](https://github.com/epnev/continuous_time_ca_sampler))


## Installation

Retrieve a copy if this repository, cloning it with git.
This can be achieved by to typing the following command in a terminal:
```
git clone https://bitbucket.org/lasermouse/twophotonimagingv2.git
```

Then, in Matlab, go to the toolbox folder and use the `toolbox_setup` function
to download the dependencies and properly configure Matlab search path.
Do not forget to save Matlab search path for future use.

**Do not** manually add the repository folder to the path, as the hidden *.git*
folder will likely cause troubles.


## Getting started

Typical use look like this:

```matlab
% load a set of .tif files
stackfolder = uigetdir;
stack = stacksload(stackfolder);
% compute an average image
avg_img = stacksmean(stack);
% display the stack and extract ROIs masks from it
rois = roisgui(stack, [], [], 'avg.', avg_img);
```

Of course you can do much more than this! Have a look to the files in
*examples* subfolder:

- *basic_example.m* provides an overall introduction to the main
  functions of the toolbox,
- *multiple_stacks_example.m* shows you how the same functions can be
  applied on a several datasets at a time.

Some workflows have been frozen into *pipeline* functions, that add some bells
and whistles (autosaving results, input dialogs for file selection...):

- `pipeline_register` to handle within recording registration,
- `pipeline_segment` to handle between recordings registration and ROIs
  extraction.

To get a list of provided functions, you can type in Matlab command line:

- `help twophotonimagingv2/src` for the core functions,
- `help twophotonimagingv2/src/pipeline` for pipeline functions,
- `help twophotonimagingv2/src/guis` for the graphical interfaces functions,
- `help twophotonimagingv2/src/rois` for ROIs related functions,
- `help twophotonimagingv2/src/utilities` for miscellaneous functions.

Documentation of each function be can accessed from Matlab command line using
`help <function name>` and `doc <function name>`.


## Contributing

- For bug reports and features suggestions, please use the
  [issues tracker](https://bitbucket.org/lasermouse/twophotonimagingv2/issues?status=new&status=open).
- For questions and comments, you can contact Maxime Rio
  (<maxime.rio@unibas.ch>).
