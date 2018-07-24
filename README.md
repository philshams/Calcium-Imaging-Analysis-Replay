# Calcium Imaging Pipeline

Code to process and examine activity of calcium imaging data for task and sleep sessions in multiple stacks / channels

## Pipeline:

preprocessing_register: register each stack within that session, save output in a results file for that session

preprocessing_segment: register sessions to another, reference session (e.g. a task session to a sleep session)
   optionally, create ROIs and generate time series; However, it is recommended to wait until the next step for this

verify_edit_rois: create PSTH movies, and check that they line up with the ROIs and avg registered images, to ensure proper time series
   additionally, edit ROIs using these PSTHs and avg images; and select periods in which activity is stable to use for further analysis
   then, generate new df/f time series

psth_dff: now analyze these time series, looking at PSTHs across all cells -- and then visualize any cell's PSTH in the ROI gui

psth_particular_cell: if any cell in the ROI gui strikes your fancy, select its index, and view its PSTH over all trials


## Note
This code depends on a modified version of 'twophotonimagingv2', so be sure to either clear the other from your path or set the version in this folder as prioritized









