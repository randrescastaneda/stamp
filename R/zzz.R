# zzz.R — run-time hooks (safe, minimal side effects)

# tiny CLI theme
.st_cli_theme <- list(
  span.red = list(color = "red"),
  span.blue = list(color = "dodgerblue2")
)

# keep prior theme to restore later
.st_cli_old_theme <- NULL

.seed_extmap <- function() {
  # idempotent extension -> format hints
  if (!rlang::env_has(.st_extmap_env, "qs")) {
    rlang::env_poke(.st_extmap_env, "qs", "qs2")
  }
  if (!rlang::env_has(.st_extmap_env, "qs2")) {
    rlang::env_poke(.st_extmap_env, "qs2", "qs2")
  }
  if (!rlang::env_has(.st_extmap_env, "rds")) {
    rlang::env_poke(.st_extmap_env, "rds", "rds")
  }
  if (!rlang::env_has(.st_extmap_env, "csv")) {
    rlang::env_poke(.st_extmap_env, "csv", "csv")
  }
  if (!rlang::env_has(.st_extmap_env, "fst")) {
    rlang::env_poke(.st_extmap_env, "fst", "fst")
  }
  if (!rlang::env_has(.st_extmap_env, "json")) {
    rlang::env_poke(.st_extmap_env, "json", "json")
  }
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

