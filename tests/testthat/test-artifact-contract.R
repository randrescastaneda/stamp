test_that("artifact contract native value examples retain exact declared properties", {
  fixtures <- list(
    NULL,
    c(first = 1L, second = NA_integer_),
    c(1.25, NA_real_, Inf),
    c(TRUE, FALSE, NA),
    c("alpha", NA_character_),
    as.raw(c(0, 127, 255)),
    array(1:8, dim = c(2, 2, 2),
          dimnames = list(c("a", "b"), c("c", "d"), c("e", "f"))),
    data.frame(id = 1:3, category = factor(c("b", "a", "b"),
      levels = c("a", "b", "unused")), day = as.Date("2024-01-01") + 0:2),
    list(schema = "illustrative-result/v1",
      estimates = data.frame(id = 1:2, estimate = c(1.5, 2.5)),
      diagnostics = list(n = 2L, converged = TRUE),
      parameters = list(threshold = 1.25), units = "illustrative"))
  for (format in c("rds", "qs2")) {
    local({
      local_stamp_state()
      local_st_opts(default_format = format, meta_format = "json",
                    versioning = "content", warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      for (i in seq_along(fixtures)) {
        value <- fixtures[[i]]
        file <- paste0("value-", i, ".", format)
        saved <- st_save(value, file, verbose = FALSE)
        expect_type(saved$version_id, "character")
        expect_identical(st_load(file, verbose = FALSE), value)
        expect_identical(st_load_version(file, saved$version_id,
                                         verbose = FALSE), value)
      }
    })
  }
})

test_that("artifact contract makes semantic parameters visible to reuse checks", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf,
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  before <- list(schema = "illustrative-result/v1", data = data.frame(id = 1:2),
                  parameters = list(threshold = 1))
  first <- st_save(before, "result.rds", verbose = FALSE)
  expect_false(st_should_save("result.rds", x = before)$save)
  after <- before
  after$parameters$threshold <- 2
  expect_identical(before$parameters$threshold, 1)
  expect_true(st_should_save("result.rds", x = after)$save)
  expect_identical(st_changed_reason("result.rds", x = after), "content")
  second <- st_save(after, "result.rds", verbose = FALSE)
  expect_false(identical(first$version_id, second$version_id))
  expect_identical(st_load("result.rds", verbose = FALSE), after)
  expect_identical(st_load_version("result.rds", first$version_id,
                                   verbose = FALSE), before)
})

test_that("artifact contract original-key table example does not invent new keys", {
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  value <- data.table::data.table(id = 1:3, estimate = c(1.5, 2.5, 3.5))
  data.table::setkey(value, id)
  original <- data.table::copy(value)
  st_save(value, "keyed.rds", verbose = FALSE)
  loaded <- st_load("keyed.rds", verbose = FALSE)
  expect_identical(data.table::key(loaded), "id")
  expect_identical(as.data.frame(loaded), as.data.frame(original))
  expect_identical(value, original)
  unkeyed <- data.table::copy(value)
  data.table::setkey(unkeyed, NULL)
  st_save(unkeyed, "unkeyed.rds", verbose = FALSE)
  expect_null(data.table::key(st_load("unkeyed.rds", verbose = FALSE)))
})

test_that("artifact contract adapter example stores declared model data not live state", {
  # Illustrative class projection, not a production estimator or registry API.
  adapt <- function(model) list(
    adapter = "illustrative-lm-summary/v1",
    coefficients = stats::coef(model), covariance = stats::vcov(model),
    observations = stats::nobs(model), residual_df = stats::df.residual(model),
    formula_text = paste(deparse(stats::formula(model)), collapse = " "))
  # Do not serialize the changing test frame through a captured formula env.
  formula <- stats::as.formula("mpg ~ wt", env = baseenv())
  model <- stats::lm(formula, data = datasets::mtcars)
  before <- serialize(model, NULL, version = 3)
  snapshot <- adapt(model)
  expect_identical(serialize(model, NULL, version = 3), before)
  expect_identical(snapshot$adapter, "illustrative-lm-summary/v1")
  expect_identical(snapshot$coefficients, stats::coef(model))
  expect_identical(snapshot$covariance, stats::vcov(model))
  expect_type(snapshot$formula_text, "character")
  for (format in c("rds", "qs2")) {
    local({
      local_stamp_state()
      local_st_opts(default_format = format, warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      file <- paste0("summary.", format)
      st_save(snapshot, file, verbose = FALSE)
      loaded <- st_load(file, verbose = FALSE)
      expect_identical(loaded, snapshot)
      expect_identical(loaded$coefficients, stats::coef(model))
      expect_false(inherits(loaded, "lm"))
    })
  }
})
