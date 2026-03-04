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
- **Parallel processing** where partitions can be proceEssed
  independently

## Quick Start

``` r
# Initialize stamp
tdir <- tempfile("stamp-partitions-")
dir.create(tdir)
st_init(tdir)
#> ✔ stamp initialized
#>   alias: default
#>   root: /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34
#>   state: /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/.stamp

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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#>   @ version 1b1dc9b6f7b430d5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#>   @ version be88dac75135870a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>   @ version 461dd150092eb835
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#>   @ version 7f11fcf3e3e38a96
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#>   @ version 918af5327f59df1c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#>   @ version 6ae596df6d2d131e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#>   @ version dab38884ed3cf954
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#>   @ version d95a20189c5a40b8
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#>   @ version 58d7aeb99a2a0a5a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 2b743333377fd163
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#>   @ version fc5cf2675b3f46ec
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#>   @ version 32e0e972a5ca8361
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#>   @ version 64acff8b5a7a4e4f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#>   @ version e3209d2b03b6f6fc
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 683038eca912b3e8
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#>   @ version d494df4894582b6e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#>   @ version 5feca6b0b1054eca
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#>   @ version 0df86c89f457b23c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#>   @ version e3becdc86ba47add
#> ⠙ Saving 19/45 partitions [1s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#>   @ version e5c87ed34efffcac
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#>   @ version bd530a4c9ab8750f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#>   @ version eac39af4cf543bf3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#>   @ version 44111762e23c9291
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#>   @ version 6a3fa157b403e3e2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#>   @ version a6e0fbacb5c99768
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#>   @ version c16ea1eed4e4fa8b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#>   @ version 21238763f6631efa
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#>   @ version 84a656d2d7a2ca48
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#>   @ version 9f877166fd6220ae
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#>   @ version 0816444b20651876
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#>   @ version 92a178e6b77dfb1c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#>   @ version 02a34ca95727556a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#>   @ version acf1697e4018ac91
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#>   @ version ad635ea53018241c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#>   @ version 95955bbbf4cf95bb
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#>   @ version 69195591d375f5c4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#>   @ version 4c1823819cbb491f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#>   @ version 1a0b74d5b14b867e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#>   @ version 7bca1e2c46e654e6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#>   @ version 3249cee20c3c4d29
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#>   @ version eb0ee05b139619c9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#>   @ version 0eec8d7bc8b5596e
#> ⠹ Saving 42/45 partitions [2s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#>   @ version 1436633c2c278a5b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#>   @ version 72ee44d362bc03db
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#>   @ version 49b2fd26abb23c68
#> ⠹ Saving 45/45 partitions [2.1s]
#> 
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts

# View manifest
head(manifest, 3)
#>   partition_key
#> 1  USA, 202....
#> 2  USA, 202....
#> 3  USA, 202....
#>                                                                                                                   path
#> 1 /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> 2 /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> 3 /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>         version_id n_rows
#> 1 1b1dc9b6f7b430d5      3
#> 2 be88dac75135870a      9
#> 3 461dd150092eb835     10
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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> ✔ Skip save (reason: no_change_policy) for
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts
  
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
    [`data.table::split()`](https://rdrr.io/pkg/data.table/man/split.html)
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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/test_format/country=USA/part.parquet
#>   @ version ba254a47479ed084
#> ✔ Saved 1 partition to
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/test_format

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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/test_fst/country=USA/part.fst @
#>   version c070a9efa8821a41
#> ✔ Saved 1 partition to /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/test_fst

basename(manifest_fst$path[1])
#> [1] "part.fst"
```

## Loading Partitions

### Load All Partitions

``` r
# Load all partitions and row-bind
all_data <- st_load_parts(parts_dir, as = "dt")
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf(
  "Loaded %d rows from %d partitions\n",
  nrow(all_data),
  nrow(manifest)
))
#> Loaded 300 rows from 45 partitions

# Partition columns are automatically added
# Show first few rows with selected columns (only if they exist)
if (nrow(all_data) > 0) {
  cols_to_show <- intersect(
    c("country", "year", "reporting_level", "hh_id", "income"),
    names(all_data)
  )
  if (length(cols_to_show) > 0) {
    head(all_data[, ..cols_to_show], 3)
  } else {
    head(all_data, 3)
  }
} else {
  message("No data loaded")
}
#>    country   year reporting_level hh_id   income
#>     <char> <char>          <char> <int>    <num>
#> 1:     CAN   2020        national   106 53133.61
#> 2:     CAN   2020        national   116 45187.54
#> 3:     CAN   2020        national   141 44242.25
```

### Exact Match Filtering (Named List)

Use a named list for exact equality matching (backward compatible).
Note: character partition values are normalized to lowercase in paths
and loaded data. Match using lowercase or use case-insensitive formulas.

``` r
# Load only USA data
usa_data <- st_load_parts(
  parts_dir,
  filter = list(country = "usa"),
  as = "dt"
)

cat(sprintf("USA data: %d rows\n", nrow(usa_data)))
#> USA data: 0 rows
unique(usa_data$country)
#> NULL
```

``` r
# Multiple exact matches (AND logic)
usa_2020 <- st_load_parts(
  parts_dir,
  filter = list(country = "usa", year = "2020"),
  as = "dt"
)

cat(sprintf("USA 2020: %d rows\n", nrow(usa_2020)))
#> USA 2020: 0 rows
# Show unique values for partition columns (only if they exist)
if (nrow(usa_2020) > 0) {
  cols_to_show <- intersect(c("country", "year"), names(usa_2020))
  if (length(cols_to_show) > 0) {
    unique(usa_2020[, ..cols_to_show])
  }
}
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
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("Recent data (year > 2021): %d rows\n", nrow(recent_data)))
#> Recent data (year > 2021): 180 rows
table(recent_data$year)
#> 
#> 2022 2023 2024 
#>   60   60   60
```

``` r
# Complex boolean logic: (country == "usa" AND year >= 2023) OR (country == "can" AND year == 2020)
complex_filter <- st_load_parts(
  parts_dir,
  filter = ~ (tolower(country) == "usa" & year >= 2023) |
    (tolower(country) == "can" & year == 2020),
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("Complex filter: %d rows\n", nrow(complex_filter)))
#> Complex filter: 60 rows
# Check if country/year columns exist before using them
cols_to_group <- intersect(c("country", "year"), names(complex_filter))
if (length(cols_to_group) > 0) {
  complex_filter[, .N, by = c(cols_to_group)][order(cols_to_group)]
}
#>    country   year     N
#>     <char> <char> <int>
#> 1:     CAN   2020    20
#> 2:     USA   2023    20
```

``` r
# Use %in% for multiple values
selected_countries <- st_load_parts(
  parts_dir,
  filter = ~ tolower(country) %in% c("usa", "mex") & year != 2020,
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

cat(sprintf("USA/MEX (not 2020): %d rows\n", nrow(selected_countries)))
#> USA/MEX (not 2020): 160 rows
# Check if country column exists before using it
if ("country" %in% names(selected_countries)) {
  selected_countries[, .N, by = country]
}
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

names(income_only) # May include partition keys (country, year, reporting_level) if available
#> character(0)
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
#> Columns loaded:
```

### Combining Filters and Column Selection

The real power comes from combining both:

``` r
# Load recent USA data, only income and consumption columns
usa_recent_finance <- st_load_parts(
  parts_dir,
  filter = ~ tolower(country) == "usa" & year >= 2022,
  columns = c("income", "consumption"),
  as = "dt"
)

cat(sprintf(
  "Loaded %d rows × %d columns\n",
  nrow(usa_recent_finance),
  ncol(usa_recent_finance)
))
#> Loaded 0 rows × 0 columns

head(usa_recent_finance, 3)
#> Null data.table (0 rows and 0 cols)
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
  filter = ~ tolower(country) == "mex" & year >= 2022
)

cat(sprintf("Mexico (2022+): %d partitions\n", nrow(mexico_partitions)))
#> Mexico (2022+): 9 partitions
if (nrow(mexico_partitions) > 0) {
  mexico_partitions[, c("country", "year", "reporting_level")]
} else {
  # Return an empty data.frame with expected columns to avoid subsetting errors
  data.frame(country = character(), year = numeric(), reporting_level = character())
}
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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
#>   @ version eafca371fd5ba202

# Get expected path for a partition
expected_path <- st_part_path(
  base = file.path(tdir, "manual_parts"),
  key = list(country = "USA", year = 2024, reporting_level = "urban")
)

cat("Expected path:\n", expected_path, "\n")
#> Expected path:
#>  /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=USA/year=2020/part.parquet
#>   @ version d1e5d203bfbbe4ff
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=USA/year=2021/part.parquet
#>   @ version 4b4c88abe20269fa
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=USA/year=2022/part.parquet
#>   @ version 28bf2f48cb2ede87
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=USA/year=2023/part.parquet
#>   @ version ec615538e7da2767
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=USA/year=2024/part.parquet
#>   @ version 8f93136de5c9fb5c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=CAN/year=2020/part.parquet
#>   @ version e9d80e9ba2146e07
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=CAN/year=2021/part.parquet
#>   @ version 9ef39996739997e6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=CAN/year=2022/part.parquet
#>   @ version 0cac1160eb4ddd79
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=CAN/year=2023/part.parquet
#>   @ version 1fd304d67b6087ff
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=CAN/year=2024/part.parquet
#>   @ version 7b1f1273481e61d6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=MEX/year=2020/part.parquet
#>   @ version 8bb22ade190ff8c6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=MEX/year=2021/part.parquet
#>   @ version 31f489b74c8681d2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=MEX/year=2022/part.parquet
#>   @ version d6b07bdcccdf9989
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=MEX/year=2023/part.parquet
#>   @ version 74eaacf2930ccff8
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk/country=MEX/year=2024/part.parquet
#>   @ version 9390a0260a59fb26
#> ✔ Saved 15 partitions to
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_pk

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
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 023727f7c373e2b5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version b8aa732e139aabc6
#> ✔ Saved 2 partitions to
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts

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
  as = "dt"
)
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

# 3. Process (compute ratio from income and consumption) - only if columns exist
if ("income" %in% names(recent_data) && "consumption" %in% names(recent_data)) {
  recent_data[, income_ratio := income / consumption]
  
  # Keep only needed columns for output
  cols_to_keep <- intersect(c("country", "year", "income", "consumption", "income_ratio"), names(recent_data))
  recent_data <- recent_data[, ..cols_to_keep]
} else {
  cat("Note: income or consumption columns not available in loaded data\n")
}

# 4. Save results to new partition set (only if we have processed data)
if (nrow(recent_data) > 0 && ncol(recent_data) > 0) {
  st_write_parts(
    recent_data,
    base = file.path(tdir, "processed_welfare"),
    partitioning = c("country", "year"),
    code_label = "computed_ratios",
    .progress = FALSE
  )
}
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=CAN/year=2022/part.parquet
#>   @ version 5596c6b48c8ca80d
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=CAN/year=2023/part.parquet
#>   @ version c2e43af5a81f4d06
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=CAN/year=2024/part.parquet
#>   @ version f317b1d14b5e70ef
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=MEX/year=2022/part.parquet
#>   @ version c565a3cb8588ad18
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=MEX/year=2023/part.parquet
#>   @ version 34cc788171ad99ec
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=MEX/year=2024/part.parquet
#>   @ version 37e5dbe6bcab12a5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=USA/year=2022/part.parquet
#>   @ version 4d63ad9c0d59bc06
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=USA/year=2023/part.parquet
#>   @ version 5e76696410b1cef7
#> ✔ Saved [parquet] →
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare/country=USA/year=2024/part.parquet
#>   @ version f33ea29e3ddd7f6b
#> ✔ Saved 9 partitions to
#>   /tmp/RtmpD4GS6T/stamp-partitions-1ef367fa3b34/processed_welfare
```

## Comparison with Arrow/DuckDB

stamp partitions are compatible with other tools:

``` r
# stamp partitions can be read by Arrow
library(arrow)
ds <- open_dataset(
  parts_dir,
  partitioning = schema(
    country = string(),
    year = int32(),
    reporting_level = string()
  )
)
ds |>
  filter(year > 2021) |> 
  select(income, consumption) |> 
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
