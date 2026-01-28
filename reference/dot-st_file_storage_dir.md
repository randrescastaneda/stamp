# Compute file storage directory (internal)

Given a relative path from alias root, compute the storage directory
where the file, versions, and metadata will be stored.

## Usage

``` r
.st_file_storage_dir(rel_path, alias = NULL)
```

## Arguments

- rel_path:

  Character relative path from alias root (includes filename)

- alias:

  Optional alias

## Value

Character scalar absolute path to the file storage directory

## Details

Structure: /\<rel_path\>/

Examples:

- rel_path: "data.qs2" → storage: /data.qs2/

- rel_path: "dirA/file.qs" → storage: /dirA/file.qs/
