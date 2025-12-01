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
#>   root: /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d
#>   state: /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/.stamp

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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#>   @ version 8a2e2527638ca8cb
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#>   @ version 893ad6e0fd5f510e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>   @ version c05d20c41958efb6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#>   @ version aa5b7e55aa25ccc0
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#>   @ version e98ad0fb74935d2c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#>   @ version 17e658485fc8020a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#>   @ version 6818a2ebc70e89a5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#>   @ version 19df0eb8bbef3ebe
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#>   @ version 21ab3fc929973293
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 9e99d848bb22c0fc
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#>   @ version 341604a02b95e532
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#>   @ version f6490d5a9c609799
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#>   @ version 577e34799347ea08
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#>   @ version bc7e879cb13ab24a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 31590f2a528338d7
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#>   @ version e5ccf5bc744594ca
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#>   @ version 6f8541be420b518b
#> ⠙ Saving 17/45 partitions [1s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#>   @ version f1f73553f231a05e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#>   @ version 122817469fc48044
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#>   @ version 6f28eda29f500ebf
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#>   @ version 7cb1560f189d9285
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#>   @ version 13f6d42c7ed1ef05
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#>   @ version 41afb42ad53285d3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#>   @ version 40cab56265ef7357
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#>   @ version 1d2b7ea568c6178f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#>   @ version 387e09c7a58eff63
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#>   @ version 4175c8d071f9dd82
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#>   @ version 1e67d3371b2015b2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#>   @ version de39cf83485bc880
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#>   @ version 2858ccd7af42c35f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#>   @ version f7bc6cd580130fc2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#>   @ version 5197f7ef1085f9a3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#>   @ version 040ad4c70f99f89c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#>   @ version 10351a490c62a686
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#>   @ version edaa5e6d467c7c97
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#>   @ version d52eb4f6a3e43395
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#>   @ version 055c2b99e2d2b2dc
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#>   @ version a7e65d740f4e8455
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#>   @ version 46c0fbfafcd43934
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#>   @ version c3a078927e7642a3
#> ⠹ Saving 40/45 partitions [2s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#>   @ version a8f31ae09315fc34
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#>   @ version 62aafcdaf4ef14d0
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#>   @ version 627346d1bf2072da
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#>   @ version f8c9ce4aa4ab63a4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#>   @ version 0172162d6a611396
#> ⠹ Saving 45/45 partitions [2.3s]
#> 
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts

# View manifest
head(manifest, 3)
#>   partition_key
#> 1  USA, 202....
#> 2  USA, 202....
#> 3  USA, 202....
#>                                                                                                                   path
#> 1 /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> 2 /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> 3 /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>         version_id n_rows
#> 1 8a2e2527638ca8cb      3
#> 2 893ad6e0fd5f510e      9
#> 3 c05d20c41958efb6     10
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
[`st_write_parts()`](https://randrescastaneda.github.io/stamp/reference/st_write_parts.md),
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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts
  
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
[`st_write_parts()`](https://randrescastaneda.github.io/stamp/reference/st_write_parts.md)
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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/test_format/country=USA/part.parquet
#>   @ version b42632b839db7e5b
#> ✔ Saved 1 partition to
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/test_format

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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/test_fst/country=USA/part.fst @
#>   version 79a1b1df04cfe899
#> ✔ Saved 1 partition to /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/test_fst

basename(manifest_fst$path[1])
#> [1] "part.fst"
```

## Loading Partitions

### Load All Partitions

``` r
# Load all partitions and row-bind
all_data <- st_load_parts(parts_dir, as = "dt")
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet

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
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
[`st_save_part()`](https://randrescastaneda.github.io/stamp/reference/st_save_part.md)
and
[`st_part_path()`](https://randrescastaneda.github.io/stamp/reference/st_part_path.md):

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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
#>   @ version 505f0695dd1fcc1d

# Get expected path for a partition
expected_path <- st_part_path(
  base = file.path(tdir, "manual_parts"),
  key = list(country = "USA", year = 2024, reporting_level = "urban")
)

cat("Expected path:\n", expected_path, "\n")
#> Expected path:
#>  /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=USA/year=2020/part.parquet
#>   @ version 0a3d288fa520457d
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=USA/year=2021/part.parquet
#>   @ version 2f55caa486e35df8
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=USA/year=2022/part.parquet
#>   @ version 3e07e6d7388d2787
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=USA/year=2023/part.parquet
#>   @ version 83a4bf4a85ad71e4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=USA/year=2024/part.parquet
#>   @ version 7430232b1c566360
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=CAN/year=2020/part.parquet
#>   @ version 5ba0114a1d724eab
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=CAN/year=2021/part.parquet
#>   @ version 33c920501b73a254
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=CAN/year=2022/part.parquet
#>   @ version 46e2e52e128806c7
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=CAN/year=2023/part.parquet
#>   @ version 2d4e76ea65a55852
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=CAN/year=2024/part.parquet
#>   @ version 08dfec7ac661914b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=MEX/year=2020/part.parquet
#>   @ version e68538b293a48cd6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=MEX/year=2021/part.parquet
#>   @ version 473955308c188e6e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=MEX/year=2022/part.parquet
#>   @ version b750be212835c477
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=MEX/year=2023/part.parquet
#>   @ version 31aff559e76f7405
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk/country=MEX/year=2024/part.parquet
#>   @ version c23f54759b7432e8
#> ✔ Saved 15 partitions to
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_pk

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
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 837ad2c5c2038e23
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 01ae9d1f4bbe228f
#> ✔ Saved 2 partitions to
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/welfare_parts

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
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=CAN/year=2022/part.parquet
#>   @ version ed0af09366436e46
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=CAN/year=2023/part.parquet
#>   @ version 550d713d40673b77
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=CAN/year=2024/part.parquet
#>   @ version a3e2c752c5094e94
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=MEX/year=2022/part.parquet
#>   @ version ae8af5877e3c240e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=MEX/year=2023/part.parquet
#>   @ version dc301c06e3de0a3f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=MEX/year=2024/part.parquet
#>   @ version b6c22e2902c6790e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=USA/year=2022/part.parquet
#>   @ version 0cb66956b6853acb
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=USA/year=2023/part.parquet
#>   @ version ce4f7c5a1c740f77
#> ✔ Saved [parquet] →
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare/country=USA/year=2024/part.parquet
#>   @ version bfcc520f65110644
#> ✔ Saved 9 partitions to
#>   /tmp/RtmpVhEfEv/stamp-partitions-1ceb7d60510d/processed_welfare
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

1.  **[`st_write_parts()`](https://randrescastaneda.github.io/stamp/reference/st_write_parts.md)**:
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
    [`st_list_parts()`](https://randrescastaneda.github.io/stamp/reference/st_list_parts.md)
    (inventory without loading)

Next steps: - See
[`vignette("hashing-and-versions")`](https://randrescastaneda.github.io/stamp/articles/hashing-and-versions.md)
for versioning details - See
[`vignette("lineage-rebuilds")`](https://randrescastaneda.github.io/stamp/articles/lineage-rebuilds.md)
for dependency tracking - See
[`?st_write_parts`](https://randrescastaneda.github.io/stamp/reference/st_write_parts.md)
for full API documentation
