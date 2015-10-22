# ReadWriteLocks

[![Build Status](https://travis-ci.org/invenia/ReadWriteLocks.jl.svg?branch=master)](https://travis-ci.org/invenia/ReadWriteLocks.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/qxqgjon7ocblik3q?svg=true)](https://ci.appveyor.com/project/iamed2/readwritelocks-jl)
[![codecov.io](https://codecov.io/github/invenia/ReadWriteLocks.jl/coverage.svg?branch=master)](https://codecov.io/github/invenia/ReadWriteLocks.jl?branch=master)

## Compatibility

This package is meant to be compatible with Julia's lightweight threads (where it is not strictly necessary) and true multithreaded Julia, in order to facilitate unified codebases that support future thread-safety.

## License

ReadWriteLocks.jl is provided under the MIT "Expat" License.

## Citation

This is a reimplementation of the original Java source from:
> M. Herlihy and N. Shavit, “8.3.1 Simple Readers-Writers Lock,” in The art of multiprocessor programming, revised first edition, Rev. 1st., Waltham, Massachusetts: Morgan Kaufmann, 2012, pp. 184–185.
