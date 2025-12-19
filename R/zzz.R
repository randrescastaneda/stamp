# zzz.R — run-time hooks (safe, minimal side effects)

# tiny CLI theme
.st_cli_theme <- list(
  span.red = list(color = "red"),
  span.blue = list(color = "dodgerblue2")
)

# keep prior theme to restore later
.st_cli_old_theme <- NULL

.seed_extmap <- function() {
  # Seed mapping from canonical defaults table (idempotent)
  for (i in seq_len(nrow(.st_extmap_defaults))) {
    ext <- tolower(.st_extmap_defaults$ext[i])
    fmt <- .st_extmap_defaults$format[i]
    if (!rlang::env_has(.st_extmap_env, ext)) {
      rlang::env_poke(.st_extmap_env, ext, fmt)
    }
  }
}

# Canonical extension -> logical format mapping (maintainer-visible)
.st_extmap_defaults <- data.frame(
  ext = c("qs", "qs2", "rds", "csv", "fst", "json"),
  format = c("qs", "qs2", "rds", "csv", "fst", "json"),
  desc = c(
    "Legacy qs binary format (uses package 'qs')",
    "New qs2 binary format (uses package 'qs2')",
    "R serialized RDS",
    "Comma-separated values (data.table::fread/fwrite)",
    "fst columnar format (package 'fst')",
    "JSON sidecars / small objects"
  ),
  stringsAsFactors = FALSE,
  row.names = NULL
)

# Accessor for maintainers to inspect the canonical mapping table
st_extmap_defaults <- function() {
  .st_extmap_defaults
}

# Diagnostic report comparing defaults vs runtime mapping
st_extmap_report <- function() {
  defaults <- .st_extmap_defaults
  data.frame(
    ext = defaults$ext,
    default_format = defaults$format,
    current_format = vapply(
      tolower(defaults$ext),
      function(e) {
        if (rlang::env_has(.st_extmap_env, e)) {
          rlang::env_get(.st_extmap_env, e)
        } else {
          NA_character_
        }
      },
      FUN.VALUE = ""
    ),
    desc = defaults$desc,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

.mirror_opts_to_base <- function() {
  # expose read-only mirrors under options("stamp.*") for discoverability
  # authoritative values remain in .stamp_opts (used by st_opts())
  vals <- as.list(environment(.stamp_opts)) # read env contents
  if (length(vals)) {
    # prefix all names with "stamp."
    onames <- paste0("stamp.", names(vals))
    names(vals) <- onames
    old <- options()
    # only set missing keys to avoid clobbering user/session overrides
    to_set <- !(onames %in% names(old))
    if (any(to_set)) do.call(options, vals[to_set])
  }
}

.onLoad <- function(libname, pkgname) {
  # 1) ensure internal defaults exist
  st_opts_init_defaults()

  # 2) mirror into base options for user discoverability (read-only view)
  .mirror_opts_to_base()

  # 3) seed extension map (idempotent)
  .seed_extmap()

  # 4) apply small CLI theme (and remember prior theme to restore later)

  .st_cli_old_theme <<- getOption("cli.user_theme")
  options(
    cli.user_theme = utils::modifyList(
      .st_cli_old_theme %||% list(),
      .st_cli_theme
    )
  )

  invisible()
}

.onUnload <- function(libpath) {
  # restore previous CLI theme if we changed it
  if (!is.null(.st_cli_old_theme)) {
    options(cli.user_theme = .st_cli_old_theme)
  }
  invisible()
}
