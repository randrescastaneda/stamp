# Absolute state directory path (internal)

Compute the absolute path to the package state directory. This is
constructed as /\<state_dir\> where `root` is from
[`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
and `state_dir` is an option stored in the package state.

## Usage

``` r
.st_state_dir_abs(alias = NULL)
```

## Value

Character scalar absolute path to the state directory.
