test_that("atomic writes preserve the destination on writer and promotion failure", {
  root <- withr::local_tempdir()
  path <- file.path(root, "payload.rds")
  saveRDS(11L, path)
  expect_error(
    stamp:::.st_write_atomic(
      22L,
      path,
      function(x, p) {
        saveRDS(x, p)
        stop("injected writer failure")
      },
      overwrite = TRUE
    ),
    "injected writer failure"
  )
  expect_identical(readRDS(path), 11L)
  # Inject the failure into a local copy, not the fs namespace.
  write_atomic <- audit_local_function(
    stamp:::.st_write_atomic,
    replacements = list(list(quote(fs::file_move), quote(fail_move))),
    bindings = list(fail_move = function(...) {
      stop("injected promotion failure")
    })
  )
  expect_error(
    write_atomic(22L, path, saveRDS, overwrite = TRUE),
    "injected promotion failure"
  )
  expect_true(file.exists(path))
  if (file.exists(path)) {
    expect_identical(readRDS(path), 11L)
  }
  expect_identical(list.files(root), "payload.rds")
})

test_that("atomic writes enforce overwrite and require a produced payload", {
  root <- withr::local_tempdir()
  path <- file.path(root, "payload.rds")
  expect_error(
    stamp:::.st_write_atomic(1L, path, function(...) NULL),
    "Temp file not created"
  )
  stamp:::.st_write_atomic(11L, path, saveRDS)
  expect_identical(readRDS(path), 11L)
  expect_error(
    stamp:::.st_write_atomic(22L, path, saveRDS),
    "overwrite = FALSE"
  )
  expect_identical(readRDS(path), 11L)
  stamp:::.st_write_atomic(33L, path, saveRDS, overwrite = TRUE)
  expect_identical(readRDS(path), 33L)
  expect_identical(list.files(root), "payload.rds")
})

test_that("failed save boundaries do not publish incomplete snapshot records", {
  for (boundary in c(
    ".st_write_atomic",
    ".st_write_sidecar",
    ".st_version_commit_files",
    ".st_catalog_write"
  )) {
    local({
      local_stamp_state()
      local_st_opts(
        default_format = "rds",
        meta_format = "json",
        retain_versions = Inf,
        warn_missing_pk_on_load = FALSE
      )
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      first <- st_save(11L, "payload.rds", verbose = FALSE)
      expect_type(first$version_id, "character")
      before <- stamp:::.st_catalog_read()
      local_audit_binding(boundary, function(...) stop("injected save failure"))
      failed <- st_save(22L, "payload.rds", verbose = FALSE)
      expect_null(failed$version_id, info = boundary)
      expect_null(failed$metadata, info = boundary)
      after <- stamp:::.st_catalog_read()
      expect_equal(after, before, info = boundary)
      expect_identical(
        st_load_version("payload.rds", first$version_id, verbose = FALSE),
        11L,
        info = boundary
      )
      for (vid in after$versions$version_id) {
        expect_true(
          file.exists(file.path(
            stamp:::.st_version_dir("payload.rds", vid),
            "artifact"
          )),
          info = boundary
        )
      }
    })
  }
})

test_that("committed history survives snapshot failure in a fresh reader process", {
  skip_if_not_installed("callr")
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  first <- st_save(11L, "payload.rds", verbose = FALSE)
  local_audit_binding(".st_version_commit_files", function(...) {
    stop("injected snapshot failure")
  })
  expect_null(st_save(22L, "payload.rds", verbose = FALSE)$version_id)
  result <- callr::r(
    function(root, vid) {
      library(stamp)
      st_init(root, verbose = FALSE)
      list(
        versions = st_versions("payload.rds")$version_id,
        value = st_load_version("payload.rds", vid, verbose = FALSE)
      )
    },
    args = list(root, first$version_id),
    libpath = .libPaths(),
    user_profile = FALSE,
    system_profile = FALSE
  )
  expect_identical(result$versions, first$version_id)
  expect_identical(result$value, 11L)
})

test_that("lock fallback evaluates the caller expression without claiming exclusion", {
  with_lock <- audit_local_function(
    stamp:::.st_with_lock,
    bindings = list(requireNamespace = function(package, ...) FALSE)
  )
  root <- withr::local_tempdir()
  value <- 11L
  result <- with_lock(file.path(root, "fallback"), {
    value <- value + 1L
    value
  })
  expect_identical(result, 12L)
  expect_identical(value, 12L)
  expect_length(list.files(root), 0L)
})

test_that("a real lock timeout never enters the critical section", {
  skip_if_not_installed("filelock")
  skip_if_not_installed("callr")
  root <- withr::local_tempdir()
  lockfile <- file.path(root, "held.lock")
  ready <- file.path(root, "ready")
  release <- file.path(root, "release")
  entered <- file.path(root, "entered")
  child <- callr::r_bg(
    function(lockfile, ready, release) {
      lock <- filelock::lock(lockfile, timeout = 5000)
      on.exit(filelock::unlock(lock))
      writeLines("held", ready)
      deadline <- Sys.time() + 30
      while (!file.exists(release) && Sys.time() < deadline) {
        Sys.sleep(0.02)
      }
    },
    args = list(lockfile, ready, release),
    libpath = .libPaths(),
    user_profile = FALSE,
    system_profile = FALSE
  )
  withr::defer({
    writeLines("release", release)
    child$wait(timeout = 5000)
    if (child$is_alive()) child$kill()
  })
  deadline <- Sys.time() + 20
  while (!file.exists(ready) && child$is_alive() && Sys.time() < deadline) {
    Sys.sleep(0.02)
  }
  expect_true(file.exists(ready))
  expect_error(
    stamp:::.st_with_lock(lockfile, writeLines("entered", entered)),
    "lock|Lock"
  )
  expect_false(file.exists(entered))
})

test_that("competing writers preserve exact same and different artifact updates", {
  skip_if_not_installed("filelock")
  skip_if_not_installed("callr")
  local_stamp_state()
  root <- withr::local_tempdir()
  for (same in c(TRUE, FALSE)) {
    store <- file.path(root, if (same) "same" else "different")
    dir.create(store)
    children <- lapply(1:2, function(worker) {
      callr::r_bg(
        function(store, worker, same) {
          library(stamp)
          st_init(store, verbose = FALSE)
          st_opts(
            default_format = "rds",
            versioning = "timestamp",
            warn_missing_pk_on_load = FALSE
          )
          path <- if (same) "shared.rds" else paste0(worker, ".rds")
          lapply(1:3, function(i) {
            value <- as.integer(worker * 10 + i)
            warnings <- character()
            saved <- withCallingHandlers(
              suppressMessages(st_save(value, path, verbose = TRUE)),
              warning = function(w) {
                warnings <<- c(warnings, conditionMessage(w))
                invokeRestart("muffleWarning")
              }
            )
            if (is.null(saved$version_id)) {
              stop(
                "Competing writer save failed: ",
                paste(warnings, collapse = "; ")
              )
            }
            list(path = path, value = value, id = saved$version_id)
          })
        },
        args = list(store, worker, same),
        libpath = .libPaths(),
        user_profile = FALSE,
        system_profile = FALSE
      )
    })
    withr::defer(lapply(children, function(child) {
      if (child$is_alive()) child$kill()
    }))
    results <- unlist(
      lapply(children, function(child) {
        child$wait(timeout = 60000)
        child$get_result()
      }),
      recursive = FALSE
    )
    st_init(store, verbose = FALSE)
    cat <- stamp:::.st_catalog_read()
    expect_equal(nrow(cat$versions), 6L)
    expect_equal(nrow(cat$artifacts), if (same) 1L else 2L)
    ids <- vapply(results, function(x) x$id, character(1))
    expect_length(unique(ids), 6L)
    expect_setequal(cat$versions$version_id, ids)
    for (result in results) {
      expect_identical(
        st_load_version(result$path, result$id, verbose = FALSE),
        result$value
      )
    }
  }
})

test_that("save decisions and info expose exact state rather than mere existence", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    versioning = "content",
    warn_missing_pk_on_load = FALSE
  )
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  expect_identical(
    st_should_save("value.rds", 11L),
    list(save = TRUE, reason = "missing_artifact")
  )
  first <- st_save(11L, "value.rds", verbose = FALSE)
  expect_identical(st_load("value.rds", verbose = FALSE), 11L)
  expect_identical(st_changed_reason("value.rds", 11L), "no_change")
  expect_identical(st_changed_reason("value.rds", 22L), "content")
  expect_identical(st_save(11L, "value.rds", verbose = FALSE)$skipped, TRUE)
  info <- st_info("value.rds")
  expect_identical(info$catalog$n_versions, 1L)
  expect_identical(info$catalog$latest_version_id, first$version_id)
  expect_identical(
    as.character(info$snapshot_dir),
    as.character(
      stamp:::.st_version_dir("value.rds", first$version_id)
    )
  )
  expect_identical(info$parents, list())
  expect_identical(stamp:::.st_guess_format("model.QS2"), "qs2")
  expect_null(stamp:::.st_guess_format("model.unknown"))
  path <- stamp:::st_path("value.rds")
  expect_identical(path$format, "rds")
  expect_message(expect_identical(print(path), path), "st_path")
})

test_that("verification does not report a mismatch for an unrecorded QS2 file hash", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "qs2",
    verify_on_load = TRUE,
    store_file_hash = FALSE,
    warn_missing_pk_on_load = FALSE
  )
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(11L, "value.rds", verbose = FALSE)
  expect_identical(st_read_sidecar("value.rds")$file_hash, NA_character_)
  value <- expect_warning(st_load("value.rds"), NA)
  expect_identical(value, 11L)
})

test_that("live primary-key annotations do not rewrite immutable snapshot metadata", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "both",
    warn_missing_pk_on_load = FALSE
  )
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  value <- data.frame(id = 1:2, value = c(11L, 22L))
  saved <- st_save(value, "value.rds", verbose = FALSE)
  vdir <- stamp:::.st_version_dir("value.rds", saved$version_id)
  files <- file.path(vdir, c("artifact", "sidecar.json", "sidecar.qs2"))
  bytes <- function(path) readBin(path, "raw", n = file.info(path)$size)
  before <- lapply(files, bytes)
  catalog <- bytes(stamp:::.st_catalog_path())
  st_add_pk("value.rds", keys = "id")
  expect_identical(lapply(files, bytes), before)
  expect_identical(bytes(stamp:::.st_catalog_path()), catalog)
  expect_identical(st_get_pk(st_load("value.rds", verbose = FALSE)), "id")
  historical <- st_load_version("value.rds", saved$version_id, verbose = FALSE)
  expect_identical(historical, value)
  expect_identical(st_get_pk(historical), character())
  expect_identical(st_versions("value.rds")$version_id, saved$version_id)
})

test_that("restore retains legacy format fallback for unreadable snapshot metadata", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    warn_missing_pk_on_load = FALSE
  )
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  first <- st_save(11L, "value.rds", verbose = FALSE)
  second <- st_save(22L, "value.rds", verbose = FALSE)
  vdir <- stamp:::.st_version_dir("value.rds", first$version_id)
  writeLines("{", file.path(vdir, "sidecar.json"))
  expect_identical(
    st_restore("value.rds", first$version_id, verbose = FALSE),
    11L
  )
  expect_identical(st_load("value.rds", verbose = FALSE), 11L)
  ids <- st_versions("value.rds")$version_id
  expect_length(ids, 3L)
  expect_true(all(c(first$version_id, second$version_id) %in% ids))
})

test_that("save decisions hold the artifact lock for writes and unchanged skips", {
  skip_if_not_installed("filelock")
  skip_if_not_installed("callr")
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    versioning = "content",
    warn_missing_pk_on_load = FALSE
  )
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  path <- stamp:::.st_normalize_user_path("value.rds")$storage_path
  fs::dir_create(fs::path_dir(path))
  original <- st_should_save
  blocked <- logical()
  local_audit_binding("st_should_save", function(...) {
    available <- callr::r(
      function(path) {
        lock <- filelock::lock(paste0(path, ".lock"), timeout = 0)
        if (is.null(lock)) {
          return(FALSE)
        }
        filelock::unlock(lock)
        TRUE
      },
      args = list(path),
      libpath = .libPaths(),
      user_profile = FALSE,
      system_profile = FALSE
    )
    blocked <<- c(blocked, !available)
    original(...)
  })
  first <- st_save(11L, "value.rds", verbose = FALSE)
  second <- st_save(11L, "value.rds", verbose = FALSE)
  expect_identical(blocked, c(TRUE, TRUE))
  expect_type(first$version_id, "character")
  expect_true(second$skipped)
  expect_identical(st_load("value.rds", verbose = FALSE), 11L)
})

test_that("decision errors still propagate instead of becoming save fallbacks", {
  local_stamp_state()
  local_st_opts(default_format = "rds")
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_audit_binding("st_should_save", function(...) {
    stop("injected decision failure")
  })
  expect_error(
    st_save(11L, "value.rds", verbose = FALSE),
    "injected decision failure"
  )
  expect_false(file.exists(stamp:::.st_artifact_path("value.rds")))
  expect_equal(nrow(stamp:::.st_catalog_read()$versions), 0L)
})
