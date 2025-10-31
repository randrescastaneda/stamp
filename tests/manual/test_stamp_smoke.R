#### stamp smoke test (no testthat) ############################################
## Covers: init, options, save/load, sidecars, catalog/versions, skip-on-equal,
##          custom formats, and change-detection helpers.

## If running from a fresh R session, you can uncomment:
# devtools::load_all()

message("== stamp smoke test starting ==")

## --- helpers -----------------------------------------------------------------
ok <- function(cond, msg = "check failed") if (!isTRUE(cond)) stop(msg, call. = FALSE)
same <- function(x, y, msg = "objects not equal") {
  if (!isTRUE(all.equal(x, y, check.attributes = FALSE))) stop(msg, call. = FALSE)
}
`%+%` <- function(a, b) paste0(a, b)

## --- scratch root & wd -------------------------------------------------------
root <- file.path(tempdir(check = TRUE), paste0("stamp-smoke-", as.integer(runif(1, 1e6, 9e6))))
dir.create(root, recursive = TRUE, showWarnings = FALSE)
old_wd <- setwd(root); on.exit(setwd(old_wd), add = TRUE)

## --- options baseline ---------------------------------------------------------
st_opts_reset()
st_opts(
  meta_format    = "both",     # write JSON + QS2 sidecars
  versioning     = "content",  # skip write when content unchanged
  default_format = "qs2",
  code_hash      = TRUE,
  store_file_hash = TRUE,
  verify_on_load = TRUE
)

## --- init --------------------------------------------------------------------
state_dir_abs <- st_init(root = ".", state_dir = ".stamp")
ok(dir.exists(state_dir_abs), "state dir not created")

## --- fixtures ----------------------------------------------------------------
df  <- data.frame(id = 1:3, value = c("a", "b", "c"), stringsAsFactors = FALSE)
has_qs <- requireNamespace("qs2", quietly = TRUE) || requireNamespace("qs", quietly = TRUE)

p_qs  <- file.path(root, "data_qs.qs")     # ext '.qs' -> format 'qs2' via map
p_rds <- file.path(root, "data_rds.rds")
p_csv <- file.path(root, "data_csv.csv")

## === 1) QS/QS2 save+load, sidecars, catalog, skip-on-equal ===================
if (has_qs) {
  message("-- QS/QS2: first write, sidecars, catalog")

  s1 <- st_save(df, p_qs, code = function(z) z)
  ok(file.exists(p_qs), "artifact not written (.qs)")
  sc_json <- file.path(root, "stmeta", basename(p_qs) %+% ".stmeta.json")
  sc_qs2  <- file.path(root, "stmeta", basename(p_qs) %+% ".stmeta.qs2")
  ok(file.exists(sc_json), "JSON sidecar not written for .qs")
  ok(file.exists(sc_qs2),  "QS2 sidecar not written for .qs")

  df2 <- st_load(p_qs)
  same(df, df2, "roundtrip mismatch for qs/qs2")

  vtab1 <- st_versions(p_qs)
  ok(nrow(vtab1) >= 1L, "no catalog versions recorded after first save")
  vid1  <- st_latest(p_qs)
  ok(!is.na(vid1), "latest version id is NA after first save")

  message("-- QS/QS2: skip-on-equal (should NOT create new version)")
  vcount_before <- nrow(st_versions(p_qs))
  invisible(st_save(df, p_qs, code = function(z) z))  # same content -> skip
  vcount_after  <- nrow(st_versions(p_qs))
  ok(identical(vcount_before, vcount_after), "skip-on-equal did not hold")

  message("-- QS/QS2: content change (should create new version)")
  df$value[1] <- "aa"                         # mutate content
  Sys.sleep(1)                                # ensure timestamp tick
  s2 <- st_save(df, p_qs, code = function(z) z)
  vtab2 <- st_versions(p_qs)
  ok(nrow(vtab2) == vcount_before + 1L, "content change did not increase version count")
  vid2 <- st_latest(p_qs)
  ok(!identical(vid1, vid2), "latest version id did not change after content change")

  message("-- QS/QS2: versioned load & version directory layout")
  df2v <- st_load_version(p_qs, vid2)
  same(df, df2v, "versioned load mismatch for qs/qs2 after change")

  rel  <- fs::path_rel(fs::path_abs(p_qs), start = fs::path_abs("."))
  vdir <- fs::path(fs::path(state_dir_abs, "versions"), rel, vid2)
  ok(dir.exists(vdir), "version directory not created")
  ok(file.exists(file.path(vdir, "artifact")), "version artifact missing")
  ok(any(file.exists(file.path(vdir, c("sidecar.json", "sidecar.qs2")))),
     "version sidecars missing")
} else {
  message("Skipping QS/QS2 tests (no {qs2} or {qs}).")
}

## === 2) RDS save+load ========================================================
message("-- RDS: roundtrip")
s1_r <- st_save(df, p_rds, format = "rds")
ok(file.exists(p_rds), "artifact not written (.rds)")
df_r <- st_load(p_rds)
same(df, df_r, "roundtrip mismatch for rds")

## === 3) CSV save+load (if data.table) =======================================
if (requireNamespace("data.table", quietly = TRUE)) {
  message("-- CSV: roundtrip")
  s1_c <- st_save(df, p_csv, format = "csv")
  ok(file.exists(p_csv), "artifact not written (.csv)")
  df_c <- st_load(p_csv)
  df_c2 <- as.data.frame(df_c, stringsAsFactors = FALSE)
  same(df[order(df$id), ], df_c2[order(df_c2$id), ], "roundtrip mismatch for csv")
} else {
  message("Skipping CSV test (data.table not available).")
}

## === 4) st_path() print ======================================================
sp <- st_path("some/where/file.qs")
ok(inherits(sp, "st_path"), "st_path did not return st_path class")
invisible(capture.output(print(sp))) # should not error

## === 5) Custom format registration ==========================================
message("-- custom format: txt")
tmp_txt <- file.path(root, "hello.txt")
st_register_format(
  "txt",
  read  = function(p, ...) readLines(p, warn = FALSE),
  write = function(x, p, ...) writeLines(as.character(x), p),
  extensions = "txt"
)
txt_lines <- c("line 1", "line 2")
st_save(txt_lines, tmp_txt, format = "txt")
ok(file.exists(tmp_txt), "txt artifact not written")
got_txt <- st_load(tmp_txt)
same(txt_lines, got_txt, "roundtrip mismatch for txt")

## === 6) Sidecar read & verify-on-load =======================================
if (has_qs) {
  meta <- st_read_sidecar(p_qs)
  ok(is.list(meta) && length(meta) > 0L, "st_read_sidecar did not return metadata list")
  ok(identical(meta$format, "qs2"), "sidecar format field unexpected for .qs")
  invisible(st_load(p_qs))  # triggers optional file-hash verify (no error expected)
}

## === 7) Options API set/get/reset ===========================================
old <- st_opts(.get = TRUE)
st_opts(meta_format = "json", default_format = "rds")
ok(identical(st_opts("meta_format", .get = TRUE), "json"), "meta_format not set")
ok(identical(st_opts("default_format", .get = TRUE), "rds"), "default_format not set")
st_opts_reset()
now <- st_opts(.get = TRUE)
ok(identical(now$meta_format, "json"), "reset did not restore defaults (meta_format)")
ok(identical(now$default_format, "qs2"), "reset did not restore defaults (default_format)")

## === 8) Change detection helpers ============================================
message("-- st_changed()/st_changed_reason()/st_should_save()")
p_chk <- file.path(root, "changed_demo.qs")
x1 <- data.frame(a = 1:2)
x2 <- data.frame(a = 1:3)

st_opts(versioning = "content", code_hash = TRUE, store_file_hash = TRUE)

st_save(x1, p_chk, code = function(z) z)  # first write
ok(st_changed_reason(p_chk, x1, function(z) z) == "no_change", "unexpected change reported")

ok(grepl("content", st_changed_reason(p_chk, x2, function(z) z)),
   "content change not detected")

ok(grepl("code", st_changed_reason(p_chk, x1, function(z) z + 1)),
   "code change not detected")

dec <- st_should_save(p_chk, x1, function(z) z)
ok(!dec$save && dec$reason == "no_change", "st_should_save() should recommend skip")

dec2 <- st_should_save(p_chk, x2, function(z) z)
ok(dec2$save, "st_should_save() should recommend save on content change")

message("== stamp smoke test finished OK ==")




devtools::load_all()

st_opts_reset()
st_opts(versioning = "content", code_hash = TRUE, store_file_hash = TRUE, verify_on_load = TRUE)

root <- tempdir(); st_init(root)

pA <- fs::path(root, "A.qs"); xA <- data.frame(a=1:3); st_save(xA, pA, code=function(z) z)
pB <- fs::path(root, "B.qs"); xB <- transform(xA, b=a*2)
st_save(xB, pB, code=function(z) z, parents=list(list(path=pA, version_id=st_latest(pA))))
pC <- fs::path(root, "C.qs"); xC <- transform(xB, c=b+1L)
st_save(xC, pC, code=function(z) z, parents=list(list(path=pB, version_id=st_latest(pB))))

stopifnot(nrow(st_children(pA, depth=1)) == 1L)
stopifnot(nrow(st_lineage(pC, depth=Inf)) >= 1L)

# Change A -> only B is strictly stale
xA2 <- transform(xA, a=a+10L); st_save(xA2, pA, code=function(z) z)
stopifnot(st_is_stale(pB), !st_is_stale(pC))

# Plan propagate: B then C
plan <- st_plan_rebuild(pA, depth=Inf, mode="propagate")
stopifnot(nrow(plan) == 2L)
stopifnot(any(plan$path == pB & plan$level == 1L))
stopifnot(any(plan$path == pC & plan$level == 2L))

# Builders
st_clear_builders()
st_register_builder(pB, function(path, parents) {
  A <- st_load_version(parents[[1]]$path, parents[[1]]$version_id)
  list(x = transform(A, b = a*2), code=function(z) z, code_label="B <- A*2")
})
st_register_builder(pC, function(path, parents) {
  B <- st_load_version(parents[[1]]$path, parents[[1]]$version_id)
  list(x = transform(B, c = b+1L), code=function(z) z, code_label="C <- B+1")
})

# Dry run then real
st_rebuild(plan, rebuild_fun = st_builder_for, dry_run = TRUE)
out <- st_rebuild(plan, rebuild_fun = st_builder_for, dry_run = FALSE)
stopifnot(all(out$status %in% c("built")))

# Postconditions
stopifnot(!st_is_stale(pB))
# C may or may not be stale (depends on further upstream changes); it should exist & be loadable:
invisible(st_load(pC))

message("Milestone 3 smoke test: OK")