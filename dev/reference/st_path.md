# Declare a path (with optional format & partition hint)

Declare a path (with optional format & partition hint)

## Usage

``` r
st_path(path, format = NULL, partition_key = NULL)
```

## Arguments

- path:

  file or directory path

- format:

  optional explicit format ("qs2","rds","csv","fst","json")

- partition_key:

  optional partition key (not used in M2)

## Value

list with class 'st_path'
