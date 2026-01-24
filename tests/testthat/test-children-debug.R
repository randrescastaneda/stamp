test_that("debug: st_children test", {
  root <- withr::local_tempdir()
  st_opts_reset()
  st_init(root = root, state_dir = ".s", alias = "L")

  pA <- fs::path(root, "A.qs")
  pB <- fs::path(root, "B.qs")
  fs::dir_create(fs::path_dir(pA), recurse = TRUE)
  fs::dir_create(fs::path_dir(pB), recurse = TRUE)

  st_save(data.frame(a = 1), pA, alias = "L", code = function(z) z)
  vA <- st_latest(pA, alias = "L")

  st_save(
    data.frame(b = 2),
    pB,
    alias = "L",
    code = function(z) z,
    parents = list(list(path = pA, version_id = vA))
  )

  cat_data <- stamp:::.st_catalog_read(alias = "L")
  kids <- st_children(pA, depth = 1L, alias = "L")

  # Write debug info to temporary file
  debug_file <- withr::local_tempfile(fileext = ".txt")
  debug_output <- sprintf(
    "pA: %s\npB: %s\nvA: %s\n\nArtifacts:\n%s\n\nParents Index:\n%s\n\nKids result:\n%s\n\nMatch: %s\n",
    pA,
    pB,
    vA,
    paste(capture.output(print(cat_data$artifacts[, .(artifact_id, path)])), collapse = "\n"),
    paste(capture.output(print(cat_data$parents_index)), collapse = "\n"),
    paste(capture.output(print(kids)), collapse = "\n"),
    if (nrow(kids) > 0) kids$child_path[1] == pB else "N/A"
  )
  writeLines(debug_output, debug_file)

  expect_true(TRUE)
})
