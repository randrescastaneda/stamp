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
#>   root: /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea
#>   state: /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/.stamp

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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#>   @ version 77ea8378746818d6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#>   @ version 63f20cd8773e93fa
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>   @ version ba9f07dd5b894dfc
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#>   @ version 873401efb138f4a4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#>   @ version feca7fcb88ed67a1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#>   @ version 3c350949105705df
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#>   @ version c5eeb13fb84587f6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#>   @ version d2302c312af08d54
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#>   @ version 94a5888ae2348fa8
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version f38eef03fbbdff34
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#>   @ version 3c9e23ccab1c9f8b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#>   @ version 2ef895d405892fce
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#>   @ version 070d38f35d396699
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#>   @ version a3185faf7458387b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version f80cb6bb0fcbb827
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#>   @ version eac06aff4ff07dc2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#>   @ version 569e529a44933c2e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#>   @ version 7718182dd3319dfb
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#>   @ version 06b1275ee2e26c10
#> ⠙ Saving 19/45 partitions [1s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#>   @ version ac8aa3656f48bd84
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#>   @ version c4388a39517469ff
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#>   @ version 5c51393989d744dd
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#>   @ version 4bc5fb72192f266e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#>   @ version 428585cade87873b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#>   @ version e112c457a52186d9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#>   @ version 2e39c04a13094e21
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#>   @ version fd5b79f6a7c091fc
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#>   @ version a3e16b73afbadadb
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#>   @ version 998f4581a1a3efde
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#>   @ version 8d2d58410220a123
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#>   @ version 4cc3f9f1c5f7e151
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#>   @ version b8090000e27c445b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#>   @ version 716f01121d4d5a90
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#>   @ version 4d70fcd8a13cf4ea
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#>   @ version 732333230053e7b9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#>   @ version fdc8928dd69d66df
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#>   @ version d879817064cf8442
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#>   @ version e94dadfc1e93013d
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#>   @ version e747f7b668eedcc6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#>   @ version 9357f4efa92e4821
#> ⠹ Saving 40/45 partitions [2s]
#> 
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#>   @ version d1c6dabf692bf1e2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#>   @ version 8fb1cfb3e3901b4e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#>   @ version 807e24c6aa5624c5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#>   @ version 5c597bb1976aa903
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#>   @ version 25f78fd9137a8cf3
#> ⠹ Saving 45/45 partitions [2.2s]
#> 
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts

# View manifest
head(manifest, 3)
#>   partition_key
#> 1  USA, 202....
#> 2  USA, 202....
#> 3  USA, 202....
#>                                                                                                                   path
#> 1 /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> 2 /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> 3 /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>         version_id n_rows
#> 1 77ea8378746818d6      3
#> 2 63f20cd8773e93fa      9
#> 3 ba9f07dd5b894dfc     10
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
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#>   @ version 9398410672fde3d4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#>   @ version 077558c592b4b4ea
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#>   @ version b146d44b6b422f72
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#>   @ version 8a33a1070585f721
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#>   @ version 4ae6779603270897
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#>   @ version 34ddc16630085330
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#>   @ version 1feaf21403ba9832
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#>   @ version 0af2c3fcf5daf1b3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#>   @ version e0edd1bb9902f021
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version e4324a1ef7ad342f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#>   @ version 203ad559c7f952d4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#>   @ version d2f8a69edd87abb4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#>   @ version 39489e36137f162b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#>   @ version 0d9ddaf84b60c131
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 445db238fa69e952
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#>   @ version bf932629d96914da
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#>   @ version 5d076b8a09fa25fd
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#>   @ version c995365f041a5405
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#>   @ version 668adb107692d5f1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#>   @ version 72538a691bf31746
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#>   @ version dcea32989c8b4bd8
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#>   @ version 4830896e670dcd42
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#>   @ version 53f112f48ab9f2c3
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#>   @ version fc54f310f2933f00
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#>   @ version 53ad90a2dddb5aa1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#>   @ version 70b0f9de4e50c1b0
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#>   @ version 3dbdfe87dae79ae1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#>   @ version b4adcec24dcd5eb5
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#>   @ version fc833a481432734a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#>   @ version 11ec84d3ae057785
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#>   @ version ec8bf5c520f41a29
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#>   @ version 091122b724c6b08a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#>   @ version f787c7e02683e5a9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#>   @ version c680ac921f9ef6a4
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#>   @ version 01172c7c90b134b2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#>   @ version b7029a895e7ac5c0
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#>   @ version 8cf6087b736d0955
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#>   @ version 9127f63505e99fd0
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#>   @ version 8900515824e70517
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#>   @ version a7195a3f2cf23e36
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#>   @ version e2c5364e5e67e372
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#>   @ version 78bf95b83ebdf11b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#>   @ version 6b93f8b13ba13b6e
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#>   @ version c6cd4885e57278d9
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#>   @ version 701d098ee26b0f52
#> ✔ Saved 45 partitions to
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts
  
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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/test_format/country=USA/part.parquet
#>   @ version 8c7d0a8f74872759
#> ✔ Saved 1 partition to
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/test_format

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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/test_fst/country=USA/part.fst @
#>   version 668998730292ffa1
#> ✔ Saved 1 partition to /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/test_fst

basename(manifest_fst$path[1])
#> [1] "part.fst"
```

## Loading Partitions

### Load All Partitions

``` r
# Load all partitions and row-bind
all_data <- st_load_parts(parts_dir, as = "dt")
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
#>   @ version 54cf7f448afa1a1c

# Get expected path for a partition
expected_path <- st_part_path(
  base = file.path(tdir, "manual_parts"),
  key = list(country = "USA", year = 2024, reporting_level = "urban")
)

cat("Expected path:\n", expected_path, "\n")
#> Expected path:
#>  /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/manual_parts/country=USA/reporting_level=urban/year=2024/part.qs2
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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=USA/year=2020/part.parquet
#>   @ version 73fcbac7014eab2d
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=USA/year=2021/part.parquet
#>   @ version 2307dd089549ff5c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=USA/year=2022/part.parquet
#>   @ version 21872ce08d67cfbf
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=USA/year=2023/part.parquet
#>   @ version cf9eee17858bbcc6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=USA/year=2024/part.parquet
#>   @ version b0c4ffaf1fa5de01
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=CAN/year=2020/part.parquet
#>   @ version f2867577c7e35867
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=CAN/year=2021/part.parquet
#>   @ version fe86f2c6cb3b27c6
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=CAN/year=2022/part.parquet
#>   @ version 076e661b0e8a175f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=CAN/year=2023/part.parquet
#>   @ version 1da9bea244c897d1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=CAN/year=2024/part.parquet
#>   @ version a3926267476de2c1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=MEX/year=2020/part.parquet
#>   @ version 8eab03899b81720a
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=MEX/year=2021/part.parquet
#>   @ version d8a27e176116e90f
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=MEX/year=2022/part.parquet
#>   @ version 1b1d11a0834007fe
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=MEX/year=2023/part.parquet
#>   @ version 6bf635a21e9e7ad1
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk/country=MEX/year=2024/part.parquet
#>   @ version 8979ddf0d5b1098d
#> ✔ Saved 15 partitions to
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_pk

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
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2020/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2021/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#>   @ version 435d998d25becd6b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet
#>   @ version 2036d10ef571570a
#> ✔ Saved 2 partitions to
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts

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
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=CAN/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=MEX/reporting_level=urban/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=national/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=rural/year=2024/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2022/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2023/part.parquet
#> Warning: No primary key recorded for
#> /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [parquet] ←
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/welfare_parts/country=USA/reporting_level=urban/year=2024/part.parquet

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
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=CAN/year=2022/part.parquet
#>   @ version 1550c0295a0540e2
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=CAN/year=2023/part.parquet
#>   @ version 2df47e87d98e7820
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=CAN/year=2024/part.parquet
#>   @ version d02e139cd063f7f7
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=MEX/year=2022/part.parquet
#>   @ version a04461541797b3fc
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=MEX/year=2023/part.parquet
#>   @ version a52e2adbd8a20e5c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=MEX/year=2024/part.parquet
#>   @ version efff97768dd45bdf
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=USA/year=2022/part.parquet
#>   @ version 8b1f6380849db19c
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=USA/year=2023/part.parquet
#>   @ version 35c4715ed8b71d4b
#> ✔ Saved [parquet] →
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare/country=USA/year=2024/part.parquet
#>   @ version 470730be237b7d3d
#> ✔ Saved 9 partitions to
#>   /tmp/RtmpANskQE/stamp-partitions-21124c49c0ea/processed_welfare
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
