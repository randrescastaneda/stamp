# ---- stamp smoke test (no testthat) ------------------------------------------
# Goal: sanity-check options, I/O, sidecars, catalog, versions, and custom formats.
devtools::load_all()
message("== stamp smoke test starting ==")

# Helper assertions ------------------------------------------------------------
ok <- function(cond, msg = "check failed") {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}
same <- function(x, y, msg = "objects not equal") {
  if (!isTRUE(all.equal(x, y, check.attributes = FALSE))) {
    stop(msg, call. = FALSE)
  }
}

# small helper
`%+%` <- function(a, b) paste0(a, b)


# Choose a scratch root --------------------------------------------------------
root <- file.path(tempdir(check = TRUE), paste0("stamp-smoke-", as.integer(runif(1, 1e6, 9e6))))
dir.create(root, recursive = TRUE, showWarnings = FALSE)

# Start clean
st_opts_reset()

# Make output less noisy if you want:
# st_opts(verbose = FALSE)

# Configure defaults we rely on here
st_opts(
  meta_format   = "both",      # write both JSON + QS2 sidecars
  versioning    = "content",   # future use; OK for now
  default_format = "qs2"       # will be used when extension unknown
)

# Initialize state dir under our root
old_wd <- setwd(root); on.exit(setwd(old_wd), add = TRUE)
state_dir_abs <- st_init(root = ".", state_dir = ".stamp")
ok(dir.exists(state_dir_abs), "state dir not created")

# Basic fixture
df <- data.frame(id = 1:3, value = c("a", "b", "c"), stringsAsFactors = FALSE)

# Detect whether a qs handler is available (qs2 or qs)
has_qs <- requireNamespace("qs2", quietly = TRUE) || requireNamespace("qs", quietly = TRUE)

# Paths we’ll use
p_qs  <- file.path(root, "data_qs.qs")      # uses ext map -> qs2 handler
p_rds <- file.path(root, "data_rds.rds")
p_csv <- file.path(root, "data_csv.csv")

# --- 1) Save/load with qs/qs2 (if available) ---------------------------------
if (has_qs) {
  s1 <- st_save(df, p_qs)   # extension ".qs" should map to format "qs2"
  ok(file.exists(p_qs), "artifact not written (.qs)")
  sc_json <- file.path(root, "stmeta", basename(p_qs) %+% ".stmeta.json")
  sc_qs2  <- file.path(root, "stmeta", basename(p_qs) %+% ".stmeta.qs2")
  ok(file.exists(sc_json), "JSON sidecar not written for .qs")
  ok(file.exists(sc_qs2),  "QS2 sidecar not written for .qs")
  df2 <- st_load(p_qs)
  same(df, df2, "roundtrip mismatch for qs/qs2")

  # Catalog + versions
  vtab <- st_versions(p_qs)
  ok(nrow(vtab) >= 1L, "no catalog versions recorded")
  vid_latest <- st_latest(p_qs)
  ok(!is.na(vid_latest), "latest version id is NA")
  df2v <- st_load_version(p_qs, vid_latest)
  same(df, df2v, "versioned load mismatch for qs/qs2")

  # Save again (should bump versions)
  Sys.sleep(1) # ensure timestamp tick
  s2 <- st_save(df, p_qs)
  vtab2 <- st_versions(p_qs)
  ok(nrow(vtab2) >= nrow(vtab) + 1L, "second save did not increase version count")

  # Check version directory contents
  # versions/<rel-path>/<vid>/{artifact, sidecar.*}
  rel  <- fs::path_rel(fs::path_abs(p_qs), start = fs::path_abs("."))
  vdir <- fs::path(fs::path(state_dir_abs, "versions"), rel, st_latest(p_qs))
  ok(dir.exists(vdir), "version directory not created")
  ok(file.exists(file.path(vdir, "artifact")), "version artifact missing")
  # sidecars are optional, but at least one should exist given meta_format = both
  ok(any(file.exists(file.path(vdir, c("sidecar.json", "sidecar.qs2")))),
     "version sidecars missing")
}

# --- 2) Save/load with RDS ----------------------------------------------------
s1_r <- st_save(df, p_rds, format = "rds")
ok(file.exists(p_rds), "artifact not written (.rds)")
df_r <- st_load(p_rds)
same(df, df_r, "roundtrip mismatch for rds")

# --- 3) Save/load with CSV (requires data.table) ------------------------------
if (requireNamespace("data.table", quietly = TRUE)) {
  s1_c <- st_save(df, p_csv, format = "csv")
  ok(file.exists(p_csv), "artifact not written (.csv)")
  df_c <- st_load(p_csv)
  # fread/fwrite may type differently; coerce for comparison
  df_c2 <- as.data.frame(df_c, stringsAsFactors = FALSE)
  same(df[order(df$id), ], df_c2[order(df_c2$id), ], "roundtrip mismatch for csv")
} else {
  message("Skipping CSV test (data.table not available).")
}

# --- 4) st_path() and print method --------------------------------------------
sp <- st_path("some/where/file.qs")
ok(inherits(sp, "st_path"), "st_path did not return st_path class")
capture.output(print(sp)) # should not error

# --- 5) Custom format registration --------------------------------------------
tmp_txt <- file.path(root, "hello.txt")
st_register_format(
  "txt",
  read  = function(p, ...) readLines(p, warn = FALSE),
  write = function(x, p, ...) writeLines(as.character(x), p),
  extensions = "txt"
)
# roundtrip
txt_lines <- c("line 1", "line 2")
st_save(txt_lines, tmp_txt, format = "txt")
ok(file.exists(tmp_txt), "txt artifact not written")
got_txt <- st_load(tmp_txt)
same(txt_lines, got_txt, "roundtrip mismatch for txt")

# --- 6) Sidecar API read ------------------------------------------------------
if (has_qs) {
  meta <- st_read_sidecar(p_qs)
  ok(is.list(meta) && length(meta) > 0L, "st_read_sidecar did not return metadata list")
  ok(identical(meta$format, "qs2"), "sidecar format field unexpected for .qs")
}

# --- 7) Options API -----------------------------------------------------------
old <- st_opts(.get = TRUE)
st_opts(meta_format = "json", default_format = "rds")
ok(identical(st_opts("meta_format", .get = TRUE), "json"), "meta_format not set")
ok(identical(st_opts("default_format", .get = TRUE), "rds"), "default_format not set")
st_opts_reset()
now <- st_opts(.get = TRUE)
ok(identical(now$meta_format, "json"), "reset did not restore defaults (meta_format)")
ok(identical(now$default_format, "qs2"), "reset did not restore defaults (default_format)")

message("== stamp smoke test finished OK ==")
