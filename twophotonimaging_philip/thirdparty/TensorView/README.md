# TensorView

This repository provides the `TensorView` class, which provides a view on a
tensor. This allows one to conveniently access parts of tensor-like objects
without loading data.

It is meant to interoperate with the following classes:

- [TIFFStack](https://github.com/DylanMuir/TIFFStack),
- [MappedTensor](https://github.com/DylanMuir/MappedTensor),
- [TensorStack class](https://github.com/DylanMuir/TensorStack).


## Installation

Retrieve a copy of this repository, cloning it with git.
This can be achieved by to typing the following command in a terminal:
```
git clone https://bitbucket.org/lasermouse/TensorView.git
```

Then, in Matlab, just add the directory to your Matlab search path.


## Getting started

Typical use look like this:

```matlab
% create a 100x10 tensor
ts = randn(100, 10);
% create a view on some elements of the 2nd dimension
ts_view = TensorView(ts, ':', [5, 3, 1])
% size of the view
size(ts_view)
% check that content is the same
isequal(ts(:, 5), ts_view(:, 1))
```

Use the commands `doc TensorView` and `doc Tensorview.TensorView` to get more
information about the class and its constructor.


## Testing

The provided test suite can be run as follows:

```matlab
run(TestTensorView)
```
