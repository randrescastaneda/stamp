# zzz.R — run-time hooks (safe, minimal side effects)

# Optional: small CLI theme you can extend later (no long-lived divs)
.st_cli_theme <- list(
  span.red  = list(color = "red"),
  span.blue = list(color = "dodgerblue2")
)

.onLoad <- function(libname, pkgname) {
  # 1) Ensure internal options have defaults available to st_opts()
  st_opts_init_defaults()

  # 2) Seed common extension -> format mappings (idempotent)
  #    Built-ins will bind their format handlers elsewhere; this just maps extensions.
  if (!rlang::env_has(.st_extmap_env, "qs"))   rlang::env_poke(.st_extmap_env, "qs",   "qs2")
  if (!rlang::env_has(.st_extmap_env, "qs2"))  rlang::env_poke(.st_extmap_env, "qs2",  "qs2")
  if (!rlang::env_has(.st_extmap_env, "rds"))  rlang::env_poke(.st_extmap_env, "rds",  "rds")
  if (!rlang::env_has(.st_extmap_env, "csv"))  rlang::env_poke(.st_extmap_env, "csv",  "csv")
  if (!rlang::env_has(.st_extmap_env, "fst"))  rlang::env_poke(.st_extmap_env, "fst",  "fst")
  if (!rlang::env_has(.st_extmap_env, "json")) rlang::env_poke(.st_extmap_env, "json", "json")

  # 3) Apply a tiny CLI theme (safe + additive, idempotent)
  if (requireNamespace("cli", quietly = TRUE)) {
    old <- getOption("cli.user_theme")
    options(cli.user_theme = utils::modifyList(old %||% list(), .st_cli_theme))
  }

  invisible()
}

.onUnload <- function(libpath) {
  # Nothing persistent to undo. If you later save/restore themes, revert here.
  invisible()
}
