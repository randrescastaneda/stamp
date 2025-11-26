# Working with Partitioned Datasets

This vignette demonstrates stamp’s partitioning system for managing
large datasets split across multiple files using Hive-style directory
structures. Partitioning is ideal for:

- **Large datasets** that need to be split by country, year, region,
  etc.
- **Selective loading** where you only need specific subsets (e.g., one
  country’s data)
- **Columnar efficiency** when using parquet/fst formats (load only
  needed columns)
- **Parallel processing** where partitions can be processed
  independently

## Quick Start

``` r
# Initialize stamp
tdir <- tempfile("stamp-partitions-")
dir.create(tdir)
st_init(tdir)
#> ✔ stamp initialized
#>   root: /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d
#>   state: /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/.stamp

# Create sample welfare data
set.seed(123)  # for reproducible vignette output
welfare <- data.table(
  country = rep(c("USA", "CAN", "MEX"), each = 100),
  year = rep(2020:2024, 60),
  reporting_level = sample(
    c("national", "urban", "rural"),
    300,
    replace = TRUE
  ),
  hh_id = 1:300,
  income = rnorm(300, 50000, 15000),
  consumption = rnorm(300, 35000, 10000)
)

# Auto-partition and save (eliminates manual looping!)
parts_dir <- file.path(tdir, "welfare_parts")

manifest <- st_write_parts(
  welfare,
  base = parts_dir,
  partitioning = c("country", "year", "reporting_level"),
  code_label = "welfare_data"
)
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#>   @ version 75c4eea4a963436e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#>   @ version 71b9c8af8b1f8a8e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>   @ version 03adec1093e0e74a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#>   @ version 46dd8b5f0d52e8e7
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#>   @ version ed87f8c5b9358aa6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#>   @ version e42ac0b05e745e39
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#>   @ version b2657f80842b8e19
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#>   @ version 38d7d67cc8965ef5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#>   @ version bba60ab160b722a2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 8d5af7444e176f4f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#>   @ version c56d73ca92681d92
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#>   @ version 5f493bea1af42a66
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#>   @ version f88fd2b5990cd115
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#>   @ version ce752c80944447b9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 4356a343fc0fc29a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#>   @ version 7d5db123c36f02a5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#>   @ version cac4238f545e6d66
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#>   @ version 98e25a3e2446cde9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#>   @ version e752fe553f16fdfa
#> ⠙ Saving 19/45 partitions [1s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#>   @ version 976bb0852efcbe41
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#>   @ version 0b4280642030955c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#>   @ version 36a62951456a4399
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#>   @ version e63443eaa1f3f293
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#>   @ version 963cb44da65f8a3b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#>   @ version 1b2c5eb9590a2487
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#>   @ version 6dca324951cad91e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#>   @ version b56409e86ad4d494
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#>   @ version 8ca9e772d58fb627
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#>   @ version 294c5cd9c76e57e7
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#>   @ version 15fa2611465ae4ec
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#>   @ version 23030da6904470f1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#>   @ version 852b1a6a8475a515
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#>   @ version 5bc40aa2ce38ad3f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#>   @ version b7e867924924567b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#>   @ version 06a6dc27392a059e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#>   @ version 134b0b79fb181b4a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#>   @ version 73a7bdb7cd3a0299
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#>   @ version af33ed8af2a18599
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#>   @ version f3d32dbe037b7c65
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#>   @ version 3b21c6b1f46b6340
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#>   @ version 7637e0d9204affde
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#>   @ version 3e0d3843f53f37a3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#>   @ version 1e42ee2ee7c4ec18
#> ⠹ Saving 43/45 partitions [2s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#>   @ version d26cb9d3fe33d671
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#>   @ version 9635289814ddaf93
#> ⠹ Saving 45/45 partitions [2.2s]
#> 
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts

# View manifest
head(manifest, 3)
#>   partition_key
#> 1  USA, 202....
#> 2  USA, 202....
#> 3  USA, 202....
#>                                                                                                                  path
#> 1 /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> 2 /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> 3 /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>         version_id n_rows
#> 1 75c4eea4a963436e      3
#> 2 71b9c8af8b1f8a8e      9
#> 3 03adec1093e0e74a     10
```

The manifest shows: - `partition_key`: List of key-value pairs for each
partition - `path`: File location with Hive-style structure -
`version_id`: Version identifier for tracking - `n_rows`: Number of rows
in partition

## Hive-Style Partitioning

Partitions are organized in directories following the Hive convention:

    base_dir/
      key1=value1/
        key2=value2/
          part.parquet

For example:

    welfare_parts/
      country=USA/
        year=2020/
          reporting_level=national/
            part.parquet
          reporting_level=urban/
            part.parquet

This structure: - **Self-documenting**: Directory names encode partition
values - **Efficient discovery**: Tools can scan directory structure to
find partitions - **Standard format**: Compatible with Apache Spark,
Apache Arrow, DuckDB, etc.

## Auto-Partitioning with `st_write_parts()`

Before
[`st_write_parts()`](https://randrescastaneda.github.io/stamp/dev/reference/st_write_parts.md),
you had to manually loop through partition combinations:

``` r
# ❌ OLD WAY - Manual looping (verbose, error-prone)
for (ctry in unique(welfare$country)) {
  for (yr in unique(welfare$year)) {
    for (rl in unique(welfare$reporting_level)) {
      part_dt <- welfare[country == ctry & year == yr & reporting_level == rl]
      if (nrow(part_dt) > 0) {
        st_save_part(
          part_dt,
          base = parts_dir,
          key = list(country = ctry, year = yr, reporting_level = rl)
        )
      }
    }
  }
}
```

Now it’s a single function call:

``` r
# ✅ NEW WAY - Auto-partitioning (clean, efficient)
manifest <- st_write_parts(
  welfare,
  base = parts_dir,
  partitioning = c("country", "year", "reporting_level"),
  code_label = "welfare_data",
  .progress = FALSE # Disable progress bar for vignette
)
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts
  
cat(sprintf("Saved %d partitions\n", nrow(manifest)))
#> Saved 45 partitions
```

### Benefits

1.  **Automatic splitting**: Handles all combinations of partition
    values
2.  **Progress tracking**: Shows progress bar for many partitions (\>10
    by default)
3.  **Error handling**: Gracefully handles failed partitions
4.  **Consistent metadata**: All partitions get same code_label,
    versioning
5.  **Performance**: Uses
    [`data.table::split()`](https://rdatatable.gitlab.io/data.table/reference/split.html)
    when available for speed

### Format Selection

By default,
[`st_write_parts()`](https://randrescastaneda.github.io/stamp/dev/reference/st_write_parts.md)
uses **parquet** format for optimal columnar performance:

``` r
# Default format is parquet
format_manifest <- st_write_parts(
  welfare[1:50],
  base = file.path(tdir, "test_format"),
  partitioning = "country",
  .progress = FALSE
)
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/test_format/country=USA/part.parquet
#>   @ version a1312d8af50e2fe0
#> ✔ Saved 1 partition to /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/test_format

# Check file extension
basename(format_manifest$path[1])
#> [1] "part.parquet"
```

Override with explicit format:

``` r
# Use fst format instead
manifest_fst <- st_write_parts(
  welfare[1:50],
  base = file.path(tdir, "test_fst"),
  partitioning = "country",
  format = "fst",
  .progress = FALSE
)
#> ✔ Saved [fst] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/test_fst/country=USA/part.fst @
#>   version 0e4ef78205791b76
#> ✔ Saved 1 partition to /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/test_fst

basename(manifest_fst$path[1])
#> [1] "part.fst"
```

## Loading Partitions

### Load All Partitions

``` r
# Load all partitions and row-bind
all_data <- st_load_parts(parts_dir, as = "dt")
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf(
  "Loaded %d rows from %d partitions\n",
  nrow(all_data),
  nrow(manifest)
))
#> Loaded 300 rows from 45 partitions

# Partition columns are automatically added
head(all_data[, .(country, year, reporting_level, hh_id, income)], 3)
#>    country   year reporting_level hh_id   income
#>     <char> <char>          <char> <int>    <num>
#> 1:     CAN   2020        national   106 53133.61
#> 2:     CAN   2020        national   116 45187.54
#> 3:     CAN   2020        national   141 44242.25
```

### Exact Match Filtering (Named List)

Use a named list for exact equality matching (backward compatible):

``` r
# Load only USA data
usa_data <- st_load_parts(
  parts_dir,
  filter = list(country = "USA"),
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("USA data: %d rows\n", nrow(usa_data)))
#> USA data: 100 rows
unique(usa_data$country)
#> [1] "USA"
```

``` r
# Multiple exact matches (AND logic)
usa_2020 <- st_load_parts(
  parts_dir,
  filter = list(country = "USA", year = "2020"),
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet

cat(sprintf("USA 2020: %d rows\n", nrow(usa_2020)))
#> USA 2020: 20 rows
unique(usa_2020[, .(country, year)])
#>    country   year
#>     <char> <char>
#> 1:     USA   2020
```

Notice it is possible to use the numeric string “2020”. See [Filter
Expression Capabilities](#filter-expression-capabilities) below for
clarification.

### Expression-Based Filtering (Formula)

For flexible filtering with comparisons and boolean logic, use formula
syntax:

``` r
# Load data where year > 2021 (numeric comparison)
recent_data <- st_load_parts(
  parts_dir,
  filter = ~ year > 2021,
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("Recent data (year > 2021): %d rows\n", nrow(recent_data)))
#> Recent data (year > 2021): 180 rows
table(recent_data$year)
#> 
#> 2022 2023 2024 
#>   60   60   60
```

``` r
# Complex boolean logic: (country == "USA" AND year >= 2023) OR (country == "CAN" AND year == 2020)
complex_filter <- st_load_parts(
  parts_dir,
  filter = ~ (country == "USA" & year >= 2023) |
    (country == "CAN" & year == 2020),
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("Complex filter: %d rows\n", nrow(complex_filter)))
#> Complex filter: 60 rows
complex_filter[, .N, by = .(country, year)][order(country, year)]
#>    country   year     N
#>     <char> <char> <int>
#> 1:     CAN   2020    20
#> 2:     USA   2023    20
#> 3:     USA   2024    20
```

``` r
# Use %in% for multiple values
selected_countries <- st_load_parts(
  parts_dir,
  filter = ~ country %in% c("USA", "MEX") & year != 2020,
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("USA/MEX (not 2020): %d rows\n", nrow(selected_countries)))
#> USA/MEX (not 2020): 160 rows
selected_countries[, .N, by = country]
#>    country     N
#>     <char> <int>
#> 1:     MEX    80
#> 2:     USA    80
```

### Filter Expression Capabilities

Formula filters support:

- **Comparisons**: `>`, `<`, `>=`, `<=`, `==`, `!=`
- **Boolean logic**: `&` (AND), `|` (OR), `!` (NOT)
- **Set operations**: `%in%`, `%nin%` (if defined)
- **Parentheses**: For grouping complex logic
- **Type conversion**: Automatic for numeric partition keys

**Important**: Partition keys are automatically type-converted: -
Numeric strings (`"2020"`) → numeric (`2020`) - Boolean strings
(`"TRUE"`) → logical (`TRUE`) - Other strings remain strings

## Columnar Loading (Column Selection)

When using parquet or fst formats, you can load only specific columns
for massive performance gains:

``` r
# Load only income column (+ partition keys automatically included)
income_only <- st_load_parts(
  parts_dir,
  columns = c("income"),
  as = "dt"
)

names(income_only) # income + partition keys (country, year, reporting_level)
#> [1] "income"          "country"         "reporting_level" "year"
```

### Native vs. Fallback Column Selection

| Format  | Native Support | Behavior                                       |
|---------|----------------|------------------------------------------------|
| parquet | ✅ Yes         | Fast - reads only specified columns from disk  |
| fst     | ✅ Yes         | Fast - reads only specified columns from disk  |
| qs/qs2  | ❌ No          | Loads full object, then subsets (with warning) |
| rds     | ❌ No          | Loads full object, then subsets (with warning) |
| csv     | ❌ No          | Loads full object, then subsets (with warning) |

``` r
# Parquet: native column selection (efficient)
parquet_cols <- st_load_parts(
  parts_dir,
  columns = c("hh_id", "income"),
  as = "dt"
)

cat("Columns loaded:", paste(names(parquet_cols), collapse = ", "), "\n")
#> Columns loaded: hh_id, income, country, reporting_level, year
```

### Combining Filters and Column Selection

The real power comes from combining both:

``` r
# Load recent USA data, only income and consumption columns
usa_recent_finance <- st_load_parts(
  parts_dir,
  filter = ~ country == "USA" & year >= 2022,
  columns = c("income", "consumption"),
  as = "dt"
)

cat(sprintf(
  "Loaded %d rows × %d columns\n",
  nrow(usa_recent_finance),
  ncol(usa_recent_finance)
))
#> Loaded 60 rows × 5 columns

head(usa_recent_finance, 3)
#>      income consumption country reporting_level   year
#>       <num>       <num>  <char>          <char> <char>
#> 1: 52886.62    45512.59     USA        national   2022
#> 2: 28921.19    41564.68     USA        national   2022
#> 3: 68243.75    48980.75     USA        national   2022
```

This approach: 1. **Filters partitions** before reading (only loads
relevant files) 2. **Reads only needed columns** from those files (with
parquet/fst) 3. **Minimizes memory** and I/O for large datasets

## Discovering Partitions with `st_list_parts()`

List available partitions without loading data:

``` r
# List all partitions
all_partitions <- st_list_parts(parts_dir)

cat(sprintf("Found %d partitions\n", nrow(all_partitions)))
#> Found 45 partitions
head(all_partitions[, c("country", "year", "reporting_level")], 6)
#>   country year reporting_level
#> 1     CAN 2020        national
#> 2     CAN 2021        national
#> 3     CAN 2022        national
#> 4     CAN 2023        national
#> 5     CAN 2024        national
#> 6     CAN 2020           rural
```

``` r
# List specific partitions with filter
mexico_partitions <- st_list_parts(
  parts_dir,
  filter = ~ country == "MEX" & year >= 2022
)

cat(sprintf("Mexico (2022+): %d partitions\n", nrow(mexico_partitions)))
#> Mexico (2022+): 9 partitions
mexico_partitions[, c("country", "year", "reporting_level")]
#>   country year reporting_level
#> 1     MEX 2022        national
#> 2     MEX 2023        national
#> 3     MEX 2024        national
#> 4     MEX 2022           rural
#> 5     MEX 2023           rural
#> 6     MEX 2024           rural
#> 7     MEX 2022           urban
#> 8     MEX 2023           urban
#> 9     MEX 2024           urban
```

Use cases: - **Inventory check**: What partitions exist? -
**Validation**: Ensure expected partitions were created - **Selective
processing**: Get file paths for external processing - **Metadata
extraction**: Extract partition values without loading data

## Single Partition Operations

For fine-grained control, use
[`st_save_part()`](https://randrescastaneda.github.io/stamp/dev/reference/st_save_part.md)
and
[`st_part_path()`](https://randrescastaneda.github.io/stamp/dev/reference/st_part_path.md):

``` r
# Save a single partition explicitly
single_partition <- welfare[
  country == "USA" & year == 2024 & reporting_level == "urban"
]

st_save_part(
  single_partition,
  base = file.path(tdir, "manual_parts"),
  key = list(country = "USA", year = 2024, reporting_level = "urban"),
  code_label = "manual_partition"
)
#> ✔ Saved [qs2] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
#>   @ version 8577f1270812da00

# Get expected path for a partition
expected_path <- st_part_path(
  base = file.path(tdir, "manual_parts"),
  key = list(country = "USA", year = 2024, reporting_level = "urban")
)

cat("Expected path:\n", expected_path, "\n")
#> Expected path:
#>  /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
file.exists(expected_path)
#> [1] TRUE
```

## Primary Keys and Partitions

Combine partitioning with primary key validation:

``` r
# Define primary key spanning partition columns
pk_manifest <- st_write_parts(
  welfare,
  base = file.path(tdir, "welfare_pk"),
  partitioning = c("country", "year"),
  pk = c("country", "year", "reporting_level", "hh_id"),
  unique = TRUE, # Enforce uniqueness
  .progress = FALSE
)
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=USA/year=2020/part.parquet
#>   @ version 20ac963f34b5ab1f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=USA/year=2021/part.parquet
#>   @ version d829d8db3ba6b2b1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=USA/year=2022/part.parquet
#>   @ version c7ac0d86c5fbc42a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=USA/year=2023/part.parquet
#>   @ version c61343048a82a7ed
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=USA/year=2024/part.parquet
#>   @ version e5aa82d247faa0d3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=CAN/year=2020/part.parquet
#>   @ version 205c2ba1233a41ca
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=CAN/year=2021/part.parquet
#>   @ version cb4dc111d348f543
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=CAN/year=2022/part.parquet
#>   @ version f1bc766d386bae66
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=CAN/year=2023/part.parquet
#>   @ version 9ccf9af388181166
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=CAN/year=2024/part.parquet
#>   @ version ab2c620dca80481f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=MEX/year=2020/part.parquet
#>   @ version c4b591ae2d123b81
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=MEX/year=2021/part.parquet
#>   @ version 3471a0d4158ba5fb
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=MEX/year=2022/part.parquet
#>   @ version b8e417cc8d7995dd
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=MEX/year=2023/part.parquet
#>   @ version d20fa20f2c094192
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk/country=MEX/year=2024/part.parquet
#>   @ version 021fc40d1eb17d63
#> ✔ Saved 15 partitions to
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_pk

# Each partition file has PK validation in sidecar metadata
```

When `unique = TRUE`: - Validates PK uniqueness **within each partition
file** - Stores PK definition in sidecar metadata - Fails save if
duplicates found

## Performance Considerations

### When to Use Partitioning

**Good for:** - Datasets \> 100MB with natural groupings (country, date,
category) - Workloads that frequently filter by partition keys -
Parallel/distributed processing - Incremental updates (update only
changed partitions)

**Not ideal for:** - Small datasets (\< 10MB) - overhead not worth it -
Random access patterns across all partitions - High cardinality
partition keys (millions of unique values)

### Format Selection

| Format  | Write Speed | Read Speed | Column Select | Compression | Use Case                                    |
|---------|-------------|------------|---------------|-------------|---------------------------------------------|
| parquet | Medium      | Fast       | ✅ Yes        | Excellent   | **Default** - best all-around for analytics |
| fst     | Very Fast   | Very Fast  | ✅ Yes        | Good        | High-speed iteration, frequent updates      |
| qs2     | Fast        | Fast       | ❌ No         | Excellent   | R-specific objects, complex structures      |
| rds     | Slow        | Slow       | ❌ No         | Medium      | Small files, maximum compatibility          |

**Recommendation**: Use **parquet** (default) unless you have specific
needs.

### Partition Key Selection

Choose partition keys that:

1.  **Match your query patterns**: If you always filter by country, make
    it a partition key
2.  **Have moderate cardinality**: 10-1000 unique values ideal per key
3.  **Create balanced partitions**: Avoid one huge partition + many tiny
    ones
4.  **Are immutable**: Values shouldn’t change over time

**Example - Good:**

``` r
partitioning = c("country", "year", "quarter")  # 195 countries × 10 years × 4 quarters = ~8K partitions
```

**Example - Bad:**

``` r
partitioning = c("user_id", "timestamp")  # Millions of users × millions of timestamps = too many!
```

### Memory Optimization

``` r
# Bad: Load everything then filter in R
# all_data <- st_load_parts(parts_dir)
# usa_data <- all_data[country == "USA"]  # ❌ Wasteful

# Good: Filter partitions before loading
usa_data <- st_load_parts(
  parts_dir,
  filter = ~ country == "USA" # ✅ Only loads USA partitions
)
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

# Better: Also select columns
usa_income <- st_load_parts(
  parts_dir,
  filter = ~ country == "USA",
  columns = c("income") # ✅ Only loads USA partitions, income column
)
```

## Advanced Patterns

### Incremental Updates

Update only specific partitions:

``` r
# New data for USA 2024 only
new_usa_2024 <- data.table(
  country = "USA",
  year = 2024,
  reporting_level = c("national", "urban"),
  hh_id = 1001:1002,
  income = c(60000, 55000),
  consumption = c(40000, 38000)
)

# Overwrite just the USA 2024 partitions
st_write_parts(
  new_usa_2024,
  base = parts_dir,
  partitioning = c("country", "year", "reporting_level"),
  code_label = "incremental_update",
  .progress = FALSE
)
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 189fdae5fef6d2b0
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 17052d71924527c7
#> ✔ Saved 2 partitions to
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/welfare_parts

# Other partitions remain unchanged
```

### Processing Pipeline

``` r
# 1. List partitions matching criteria
target_partitions <- st_list_parts(
  parts_dir,
  filter = ~ year >= 2022
)

cat(sprintf("Processing %d partitions...\n", nrow(target_partitions)))
#> Processing 27 partitions...

# 2. Load filtered data
recent_data <- st_load_parts(
  parts_dir,
  filter = ~ year >= 2022,
  columns = c("income", "consumption"),
  as = "dt"
)

# 3. Process
recent_data[, income_ratio := income / consumption]

# 4. Save results to new partition set
st_write_parts(
  recent_data,
  base = file.path(tdir, "processed_welfare"),
  partitioning = c("country", "year"),
  code_label = "computed_ratios",
  .progress = FALSE
)
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=CAN/year=2022/part.parquet
#>   @ version 824b51b9050ca40b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=CAN/year=2023/part.parquet
#>   @ version ee399f327b9d7de6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=CAN/year=2024/part.parquet
#>   @ version c925d4182811411b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=MEX/year=2022/part.parquet
#>   @ version 09751c7676a59fe5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=MEX/year=2023/part.parquet
#>   @ version a5906ccd5d3fb418
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=MEX/year=2024/part.parquet
#>   @ version 8ca11bf3e5f14aff
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=USA/year=2022/part.parquet
#>   @ version 603dc5ea1a9469df
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=USA/year=2023/part.parquet
#>   @ version 89e565fea3f2850b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare/country=USA/year=2024/part.parquet
#>   @ version 480f4432991d5d9c
#> ✔ Saved 9 partitions to
#>   /tmp/RtmpVqREKm/stamp-partitions-1cd81eee82d/processed_welfare
```

## Comparison with Arrow/DuckDB

stamp partitions are compatible with other tools:

``` r
# stamp partitions can be read by Arrow
library(arrow)
ds <- open_dataset(
  parts_dir,
  partitioning = c("country", "year", "reporting_level")
)
ds %>%
  filter(year > 2021) %>%
  select(income, consumption) %>%
  collect()

# Or DuckDB
library(duckdb)
con <- dbConnect(duckdb())
dbGetQuery(
  con,
  sprintf("SELECT * FROM read_parquet('%s/**/*.parquet')", parts_dir)
)
```

Differences:

| Feature        | stamp               | Arrow         | DuckDB           |
|----------------|---------------------|---------------|------------------|
| Format control | ✅ Multiple formats | Parquet focus | Multiple formats |
| Versioning     | ✅ Built-in         | ❌ None       | ❌ None          |
| Lineage        | ✅ Tracked          | ❌ None       | ❌ None          |
| R integration  | ✅ Native           | Good          | Good             |
| Query engine   | Basic filtering     | Advanced SQL  | Full SQL         |
| Dependencies   | Lightweight         | Heavy (C++)   | Heavy (C++)      |

**Use stamp when:** - You need versioning and lineage tracking - You
want lightweight dependencies - You’re primarily working in R

**Use Arrow/DuckDB when:** - You need advanced query capabilities -
You’re working with multi-language teams - Dataset size exceeds memory
(lazy evaluation needed)

## Summary

Key takeaways:

1.  **[`st_write_parts()`](https://randrescastaneda.github.io/stamp/dev/reference/st_write_parts.md)**:
    Auto-partition datasets (eliminates manual loops)
2.  **Hive-style paths**: `key1=value1/key2=value2/file.ext`
    (self-documenting)
3.  **Two filter modes**:
    - Named list: `filter = list(country = "USA")` (exact match)
    - Formula: `filter = ~ year > 2021` (flexible expressions)
4.  **Column selection**: `columns = c("col1", "col2")` (native for
    parquet/fst)
5.  **Default format**: Parquet (optimal for analytics)
6.  **Partition discovery**:
    [`st_list_parts()`](https://randrescastaneda.github.io/stamp/dev/reference/st_list_parts.md)
    (inventory without loading)

Next steps: - See
[`vignette("hashing-and-versions")`](https://randrescastaneda.github.io/stamp/dev/articles/hashing-and-versions.md)
for versioning details - See
[`vignette("lineage-rebuilds")`](https://randrescastaneda.github.io/stamp/dev/articles/lineage-rebuilds.md)
for dependency tracking - See
[`?st_write_parts`](https://randrescastaneda.github.io/stamp/dev/reference/st_write_parts.md)
for full API documentation
