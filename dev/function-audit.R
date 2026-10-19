# Standalone, base-R audit. Does not source R/ or execute tests.
# PowerShell (use R.exe if the Rscript launcher is broken):
# & 'C:/Program Files/R/R-4.5.2/bin/R.exe' --vanilla --slave `
#   -f dev/function-audit.R --args --root . --out <scratch-directory> `
#   --library '<installed-library>;<dependency-library>' `
#   --coverage <coverage.csv> --evidence <curated.csv>
# --root and --out are required. --library, --coverage and --evidence are
# optional. Libraries use .Platform$path.sep; an omitted library leaves
# namespace reconciliation explicitly blocked (never loads an arbitrary copy).
# Run in a disposable subprocess: loading the installed namespace runs its hooks.
# No package build, test runner, coverage instrumentation or benchmark is run.
#
# Coverage CSV: file,line,hits; paths relative to root, complete measured line
# inventory, nonnegative hits, NA for unavailable measurements. Include only
# test-only coverage from one identified run. Missing lines are NOT zero hits.
# Evidence CSV: unique site_id, optional source_md5 (recommended to reject stale
# evidence), plus any assessment fields listed in
# evidence_fields below. Use the generated inventory as the site_id template.
# For adequate confidence also provide required_scenarios,
# passing_required_scenarios, blocked_required_scenarios,
# unexecuted_required_scenarios, observed_result=passed and evidence_reference.
# Counts and statements are curator attestations, not independently verified.
# CSV inputs must contain no duplicate keys or unknown site IDs.
# Outputs: function-audit.csv, module-summary.csv, module-summary.txt,
# calls.csv, test-sites.csv, test-references.csv, runtime-instances.csv,
# discrepancies.csv and run-metadata.csv. All assessments are provisional.

audit_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  fail <- function(text) stop(text, call. = FALSE)
  text <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")
  signature <- function(formals) {
    node <- as.call(list(as.name("function"), formals, quote(NULL)))
    return(sub(" NULL$", "", text(node)))
  }
  bind <- function(rows, columns) {
    if (!length(rows)) {
      return(as.data.frame(setNames(rep(list(character()), length(columns)),
                                    columns), stringsAsFactors = FALSE))
    }
    return(do.call(rbind, lapply(rows, as.data.frame,
                                stringsAsFactors = FALSE)))
  }
  options <- list(root = NULL, out = NULL, library = NULL,
                  coverage = NULL, evidence = NULL)
  if (!length(args) || length(args) %% 2L) {
    fail("Use --name value pairs; see CLI comments.")
  }
  for (i in seq.int(1L, length(args), by = 2L)) {
    key <- sub("^--", "", args[i])
    if (!startsWith(args[i], "--") || !key %in% names(options)) {
      fail(paste("Unknown argument:", args[i]))
    }
    options[[key]] <- args[i + 1L]
  }
  if (is.null(options$root) || is.null(options$out)) {
    fail("--root and --out are required; see CLI comments.")
  }
  root <- normalizePath(options$root, winslash = "/", mustWork = TRUE)
  if (!dir.exists(file.path(root, "R"))) fail("Root has no R directory.")
  out <- normalizePath(options$out, winslash = "/", mustWork = FALSE)
  # Never overwrite package sources, tests or the audit report directory.
  protected <- file.path(root, c("R", "tests", ".cg-docs", ".kilo", "dev"))
  if (identical(tolower(out), tolower(root)) || any(vapply(protected,
      function(p) identical(tolower(out), tolower(p)) ||
        startsWith(tolower(out), paste0(tolower(p), "/")), logical(1)))) {
    fail("Use a dedicated output directory outside protected source paths.")
  }
  if (!dir.exists(out) && !dir.create(out, recursive = TRUE)) {
    fail("Cannot create output directory.")
  }
  write_csv <- function(x, name) {
    utils::write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE,
                     na = "", fileEncoding = "UTF-8")
  }
  discrepancies <- list()
  issue <- function(kind, subject, detail) {
    discrepancies[[length(discrepancies) + 1L]] <<-
      list(kind = kind, subject = subject, detail = detail)
  }
  call_name <- function(x) {
    if (is.symbol(x)) return(as.character(x))
    if (is.call(x) && as.character(x[[1L]])[1L] %in% c("::", ":::")) {
      return(paste0(as.character(x[[2L]]), as.character(x[[1L]]),
                    as.character(x[[3L]])))
    }
    return("")
  }
  bare_name <- function(x) sub("^.*:::?", "", x)
  # FUNCTION tokens identify function expressions, including shorthand lambdas.
  # Their parent expr supplies the full span, including single-line callbacks.
  parse_source <- function(path) {
    expr <- parse(path, keep.source = TRUE)
    pd <- utils::getParseData(expr)
    fun <- pd[pd$token == "FUNCTION", , drop = FALSE]
    fun <- fun[order(fun$line1, fun$col1), , drop = FALSE]
    spans <- pd[match(fun$parent, pd$id), , drop = FALSE]
    return(list(expr = expr, pd = pd, spans = spans))
  }
  sites <- list()
  source_nodes <- list()
  calls <- list()
  files <- sort(list.files(file.path(root, "R"), "\\.[Rr]$",
                           full.names = TRUE))
  for (path in files) {
    parsed <- parse_source(path)
    file <- paste0("R/", basename(path))
    cursor <- 0L
    walk <- function(x, owner = "", binding = "", top_owner = "") {
      if (is.expression(x) || is.pairlist(x)) {
        for (j in seq_along(x)) {
          # Missing formal defaults cannot be bound to an R variable.
          if (!identical(x[[j]], quote(expr = ))) {
            walk(x[[j]], owner, "", top_owner)
          }
        }
        return(invisible(NULL))
      }
      if (!is.call(x)) return(invisible(NULL))
      head <- call_name(x[[1L]])
      if (head == "function") {
        cursor <<- cursor + 1L
        if (cursor > nrow(parsed$spans)) fail(paste("Span mismatch:", file))
        span <- parsed$spans[cursor, ]
        id <- paste0(file, ":", span$line1, ":", span$col1, "-",
                     span$line2, ":", span$col2)
        label <- if (nzchar(binding)) binding else "<anonymous>"
        level <- if (nzchar(owner)) "nested" else "top-level"
        if (!nzchar(owner)) top_owner <- id
        sites[[length(sites) + 1L]] <<- list(
          site_id = id, file = file, module = basename(path), name = label,
          owner_site_id = owner, top_owner_site_id = top_owner,
          source_kind = level, named = nzchar(binding),
          line_start = span$line1, column_start = span$col1,
          line_end = span$line2, column_end = span$col2,
          signature = signature(x[[2L]]))
        source_nodes[[id]] <<- x
        walk(x[[2L]], id, "", top_owner)
        walk(x[[3L]], id, "", top_owner)
        return(invisible(NULL))
      }
      if (head %in% c("<-", "=", "<<-", "->", "->>")) {
        right <- if (head %in% c("->", "->>")) 2L else 3L
        left <- if (right == 2L) 3L else 2L
        target <- if (is.symbol(x[[left]])) as.character(x[[left]]) else ""
        # Traverse in lexical order so parse-data spans stay aligned.
        for (j in 2:length(x)) {
          walk(x[[j]], owner, if (j == right) target else "", top_owner)
        }
        return(invisible(NULL))
      }
      if (nzchar(head)) {
        calls[[length(calls) + 1L]] <<- list(file = file,
          caller_site_id = owner, callee = head,
          resolution = "syntactic call; dynamic dispatch/aliases unresolved")
      }
      for (j in seq_along(x)) {
        if (!identical(x[[j]], quote(expr = ))) {
          walk(x[[j]], owner, "", top_owner)
        }
      }
      return(invisible(NULL))
    }
    walk(parsed$expr)
    if (cursor != nrow(parsed$spans)) fail(paste("Unmatched FUNCTION:", file))
  }
  inventory <- bind(sites, c("site_id", "file"))
  inventory$owner_name <- inventory$name[match(inventory$owner_site_id,
                                               inventory$site_id)]
  inventory$owner_name[is.na(inventory$owner_name)] <- ""
  inventory$top_owner_name <- inventory$name[match(inventory$top_owner_site_id,
                                                   inventory$site_id)]
  inventory$site_role <- ifelse(inventory$source_kind == "top-level",
    "top-level definition", ifelse(inventory$named, "named local function",
                                    "anonymous/returned function"))
  inventory$source_md5 <- unname(tools::md5sum(file.path(root,
                                                          inventory$file)))
  call_table <- unique(bind(calls,
    c("file", "caller_site_id", "callee", "resolution")))
  top <- inventory$source_kind == "top-level"
  named_local <- !top & inventory$named
  census <- c(top_level = sum(top), nested = sum(!top),
              named_local = sum(named_local), anonymous_nested =
                sum(!top & !inventory$named))
  expected <- c(top_level = 132L, nested = 60L, named_local = 6L,
                anonymous_nested = 54L)
  for (key in names(expected)) {
    if (census[key] != expected[key]) {
      issue("census", key, paste("Expected", expected[key], "observed",
                                 census[key]))
    }
  }
  expected_modules <- c(aaa.R = 10L, format_registry.R = 20L, hashing.R = 9L,
    IO_core.R = 16L, options.R = 4L, partitions.R = 13L, rebuild.R = 9L,
    retention.R = 6L, schema_pk.R = 8L, `stamp-package.R` = 0L,
    utils.R = 6L, version_store.R = 31L, zzz.R = 6L)
  for (module in union(names(expected_modules), basename(files))) {
    count <- sum(top & inventory$module == module)
    wanted <- expected_modules[module]
    if (is.na(wanted) || count != wanted) {
      issue("module-census", module, paste("Expected", wanted,
                                          "observed", count))
    }
  }
  if (sum(expected_modules) != expected["top_level"]) {
    issue("plan-arithmetic", "top_level", paste("Plan module table sums to",
      sum(expected_modules), "but stated total is", expected["top_level"]))
  }
  # NAMESPACE is parsed, never evaluated.
  ns_spec <- parse(file.path(root, "NAMESPACE"), keep.source = TRUE)
  exports <- character()
  s3 <- character()
  for (x in ns_spec) {
    if (!is.call(x)) next
    h <- call_name(x[[1L]])
    if (h == "export") exports <- c(exports, vapply(as.list(x)[-1L],
                                                   as.character, ""))
    if (h == "S3method") {
      s3 <- c(s3, if (length(x) >= 4L) as.character(x[[4L]]) else
        paste(as.character(x[[2L]]), as.character(x[[3L]]), sep = "."))
    }
  }
  hooks <- c(".onLoad", ".onUnload", ".onAttach", ".onDetach", ".Last.lib")
  inventory$visibility <- ifelse(!top, "nested",
    ifelse(inventory$name %in% exports, "exported",
      ifelse(inventory$name %in% s3, "registered S3 method",
        ifelse(inventory$name %in% hooks, "lifecycle hook", "internal"))))
  if (sum(inventory$visibility == "exported") != 37L) {
    issue("export-census", subject = "exports", detail =
      paste("Expected 37; observed", sum(inventory$visibility == "exported")))
  }
  for (name in setdiff(c(exports, s3), inventory$name[top])) {
    issue("namespace-source", name, "Declaration has no top-level function site")
  }
  inventory$callers <- vapply(seq_len(nrow(inventory)), function(i) {
    if (!inventory$named[i]) return("")
    candidates <- call_table[bare_name(call_table$callee) == inventory$name[i], ]
    paste(unique(ifelse(nzchar(candidates$caller_site_id),
                        candidates$caller_site_id,
                        paste0(candidates$file, ":<module>"))), collapse = "; ")
  }, "")
  inventory$caller_limitations <- paste(
    "AST call names only; same-name/shadowed locals are candidate links;",
    "dynamic calls, S3 dispatch and externally supplied callbacks unresolved")

  # Test sites and call references are syntactic evidence, not passing results.
  test_sites <- list()
  references <- list()
  test_files <- sort(list.files(file.path(root, "tests", "testthat"),
                                "^test-.*\\.[Rr]$", full.names = TRUE))
  for (path in test_files) {
    parsed <- parse_source(path)
    pd <- parsed$pd
    tokens <- pd[pd$terminal & pd$text == "test_that" &
                   pd$token == "SYMBOL_FUNCTION_CALL", ]
    tokens <- tokens[order(tokens$line1, tokens$col1), , drop = FALSE]
    cursor <- 0L
    file <- paste0("tests/testthat/", basename(path))
    scan_test <- function(x, case = "") {
      if (is.expression(x) || is.pairlist(x)) {
        for (j in seq_along(x)) {
          if (!identical(x[[j]], quote(expr = ))) scan_test(x[[j]], case)
        }
        return(invisible(NULL))
      }
      if (!is.call(x)) return(invisible(NULL))
      head <- call_name(x[[1L]])
      if (head %in% c("test_that", "testthat::test_that")) {
        cursor <<- cursor + 1L
        if (cursor > nrow(tokens)) fail(paste("Test span mismatch:", file))
        tok <- tokens[cursor, ]
        callee_span <- pd[match(tok$parent, pd$id), ]
        call_span <- pd[match(callee_span$parent, pd$id), ]
        case <- paste0(file, ":", tok$line1, ":", tok$col1)
        test_sites[[length(test_sites) + 1L]] <<- list(test_site_id = case,
          file = file, line = tok$line1, column = tok$col1,
          line_start = call_span$line1, column_start = call_span$col1,
          line_end = call_span$line2, column_end = call_span$col2,
          label = if (length(x) >= 2L) text(x[[2L]]) else "",
          assertions_syntactic = 0L, skip_calls_syntactic = 0L,
          skip_on_cran_syntactic = 0L, observed_result = "not executed")
      }
      if (nzchar(head)) {
        if (nzchar(case)) {
          at <- which(vapply(test_sites, function(z)
            identical(z$test_site_id, case), logical(1)))
          if (length(at)) {
            z <- test_sites[[at]]
            b <- bare_name(head)
            z$assertions_syntactic <- z$assertions_syntactic +
              as.integer(startsWith(b, "expect_") || b == "expect")
            z$skip_calls_syntactic <- z$skip_calls_syntactic +
              as.integer(b == "skip" || startsWith(b, "skip_"))
            z$skip_on_cran_syntactic <- z$skip_on_cran_syntactic +
              as.integer(b == "skip_on_cran")
            test_sites[[at]] <<- z
          }
        }
        targets <- inventory$site_id[inventory$named &
          inventory$name == bare_name(head)]
        for (target in targets) {
          references[[length(references) + 1L]] <<- list(
            site_id = target, test_site_id = case, file = file, callee = head,
            evidence_kind = "AST call-name candidate; not assertion coverage")
        }
      }
      for (j in seq_along(x)) {
        if (!identical(x[[j]], quote(expr = ))) scan_test(x[[j]], case)
      }
      return(invisible(NULL))
    }
    scan_test(parsed$expr)
    # Token counts can include non-call uses, so use the recursive AST count.
  }
  tests <- bind(test_sites, c("test_site_id", "file", "line", "column",
    "line_start", "column_start", "line_end", "column_end",
    "label", "assertions_syntactic", "skip_calls_syntactic",
    "skip_on_cran_syntactic", "observed_result"))
  refs <- unique(bind(references,
    c("site_id", "test_site_id", "file", "callee", "evidence_kind")))
  if (length(test_files) != 23L) issue("test-census", "files",
    paste("Expected 23; observed", length(test_files)))
  if (nrow(tests) != 127L) issue("test-census", "test_that",
    paste("Expected 127; observed", nrow(tests)))
  inventory$test_site_references <- vapply(inventory$site_id, function(id) {
    paste(unique(refs$test_site_id[refs$site_id == id &
                                  nzchar(refs$test_site_id)]), collapse = "; ")
  }, "")
  inventory$owner_test_site_references <- inventory$test_site_references[
    match(inventory$top_owner_site_id, inventory$site_id)]

  # Namespace reconciliation never counts imported functions as owned sites.
  instances <- list()
  namespace_status <- "blocked: no --library supplied"
  namespace_path <- ""
  package <- read.dcf(file.path(root, "DESCRIPTION"))[1L, "Package"]
  source_version <- read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]
  installed_version <- ""
  inventory$namespace_status <- "not reconciled"
  inventory$runtime_instances <- ""
  if (!is.null(options$library)) {
    libs <- strsplit(options$library, .Platform$path.sep, fixed = TRUE)[[1L]]
    libs <- vapply(libs, normalizePath, "", winslash = "/", mustWork = TRUE)
    .libPaths(unique(c(libs, .libPaths())))
    ns <- tryCatch(loadNamespace(package, lib.loc = libs), error = function(e) {
      issue("namespace-load", package, conditionMessage(e))
      NULL
    })
    if (!is.null(ns)) {
      namespace_path <- getNamespaceInfo(ns, "path")
      installed_parent <- normalizePath(dirname(namespace_path),
        winslash = "/", mustWork = TRUE)
      if (!tolower(installed_parent) %in% tolower(libs)) {
        fail("Loaded namespace is outside the explicitly supplied libraries.")
      }
      installed_version <- as.character(getNamespaceVersion(ns))
      namespace_status <- "loaded from explicit library"
      if (installed_version != source_version) issue("namespace-version",
        package, paste("Source", source_version, "installed", installed_version))
      actual_exports <- getNamespaceExports(ns)
      for (name in union(setdiff(exports, actual_exports),
                         setdiff(actual_exports, exports))) {
        issue("namespace-export", name, "Source/installed export mismatch")
      }
      add_instance <- function(label, fn, candidates = character(),
                               factory = "", captured = "") {
        matches <- candidates[vapply(candidates, function(id) {
          node <- source_nodes[[id]]
          identical(text(formals(fn)), text(node[[2L]])) &&
            identical(text(body(fn)), text(node[[3L]]))
        }, logical(1))]
        state <- if (length(matches) == 1L) "matched body and formals" else
          if (length(matches)) "ambiguous source match" else "unmatched"
        captured_source <- character()
        captured_name <- ""
        if (nzchar(captured) && exists(captured, environment(fn),
                                       inherits = FALSE)) {
          backend <- get(captured, environment(fn), inherits = FALSE)
          if (is.function(backend)) {
            captured_source <- inventory$site_id[top & vapply(
              inventory$site_id, function(id) {
                node <- source_nodes[[id]]
                identical(text(formals(backend)), text(node[[2L]])) &&
                  identical(text(body(backend)), text(node[[3L]]))
              }, logical(1))]
            captured_name <- paste(inventory$name[match(captured_source,
              inventory$site_id)], collapse = "; ")
          }
        }
        instances[[length(instances) + 1L]] <<- list(instance = label,
          source_site_id = paste(matches, collapse = "; "),
          signature = signature(formals(fn)), status = state,
          factory = factory, captured_binding = captured,
          captured_callable = captured_name,
          captured_source_site_id = paste(captured_source, collapse = "; "))
        if (length(matches) != 1L) issue("runtime-source", label, state)
        for (id in matches) {
          i <- match(id, inventory$site_id)
          inventory$runtime_instances[i] <<- paste(
            c(inventory$runtime_instances[i], label)[nzchar(
              c(inventory$runtime_instances[i], label))], collapse = "; ")
          inventory$namespace_status[i] <<- state
        }
      }
      package_owned <- function(env) {
        while (is.environment(env) && !identical(env, emptyenv())) {
          if (identical(env, ns)) return(TRUE)
          env <- parent.env(env)
        }
        return(FALSE)
      }
      owned <- character()
      for (name in ls(ns, all.names = TRUE)) {
        obj <- get(name, envir = ns, inherits = FALSE)
        if (!is.function(obj) || !package_owned(environment(obj))) next
        owned <- c(owned, name)
        candidates <- inventory$site_id[top & inventory$name == name]
        if (!length(candidates)) candidates <- inventory$site_id[!top]
        add_instance(paste0("namespace:", name), obj, candidates)
      }
      for (name in setdiff(inventory$name[top], owned)) {
        issue("source-runtime", name, "Top-level site absent from owned namespace")
      }
      methods <- getNamespaceInfo(ns, "S3methods")
      method_names <- if (length(methods)) ifelse(nzchar(methods[, 3L]),
        methods[, 3L], paste(methods[, 1L], methods[, 2L], sep = ".")) else
          character()
      for (name in union(setdiff(s3, method_names), setdiff(method_names, s3))) {
        issue("namespace-S3", name, "Source/installed S3 registration mismatch")
      }
      if (exists(".st_formats_env", ns, inherits = FALSE)) {
        registry <- get(".st_formats_env", ns, inherits = FALSE)
        for (format in sort(ls(registry, all.names = TRUE))) {
          handler <- get(format, registry, inherits = FALSE)
          for (direction in c("read", "write")) {
            fn <- handler[[direction]]
            if (!is.function(fn)) {
              issue("registry", paste(format, direction), "Handler is not a function")
              next
            }
            factory <- paste0(".st_wrap_", if (direction == "read") "reader"
                              else "writer")
            owners <- inventory$site_id[top & inventory$name == factory]
            candidates <- inventory$site_id[inventory$owner_site_id %in% owners]
            add_instance(paste0("registry:", format, "$", direction), fn,
                         candidates, factory,
                         if (direction == "read") "read_fn" else "write_fn")
          }
        }
      }
    } else namespace_status <- "blocked: namespace load failed"
  }
  if (startsWith(namespace_status, "blocked")) {
    issue("namespace", package, namespace_status)
  }

  evidence_fields <- c("responsibility", "stated_contract",
    "expected_value_source", "tests_and_assertions", "exercise",
    "relevant_branches", "confirmed_findings", "candidate_findings",
    "efficiency_evidence", "lifecycle_recommendation", "residual_limitations",
    "functional_status", "testing_confidence", "lifecycle",
    "required_scenarios", "passing_required_scenarios",
    "blocked_required_scenarios", "unexecuted_required_scenarios",
    "observed_result", "evidence_reference", "recommendation_reason",
    "replacement", "usage_evidence", "compatibility_impact",
    "migration_sequence")
  for (field in evidence_fields) inventory[[field]] <- "not assessed"
  inventory$functional_status <- "unverified/ambiguous"
  inventory$testing_confidence <- "missing"
  inventory$lifecycle <- ifelse(inventory$module == "partitions.R" |
    inventory$name == "st_path" |
    inventory$top_owner_site_id %in% inventory$site_id[
      inventory$name == "st_path"], "deferred", "supported")
  inventory$exercise <- "not established"
  inventory$observed_result <- "not executed by audit"
  inventory$residual_limitations <- paste(
    "No behavioral assertions reviewed or executed by audit; required",
    "scenarios and branches need curation; call references are not coverage")
  if (!is.null(options$evidence)) {
    evidence <- utils::read.csv(options$evidence, stringsAsFactors = FALSE,
                               check.names = FALSE, na.strings = "")
    if (!"site_id" %in% names(evidence) || anyNA(evidence$site_id) ||
        anyDuplicated(evidence$site_id) ||
        any(!evidence$site_id %in% inventory$site_id)) {
      fail("Evidence requires unique known nonmissing site_id values.")
    }
    unknown <- setdiff(names(evidence), c("site_id", "source_md5",
                                         evidence_fields))
    if (length(unknown)) fail(paste("Unknown evidence columns:",
                                  paste(unknown, collapse = ", ")))
    index <- match(evidence$site_id, inventory$site_id)
    if ("source_md5" %in% names(evidence) &&
        any(is.na(evidence$source_md5) |
              evidence$source_md5 != inventory$source_md5[index])) {
      fail("Curated evidence source_md5 does not match the current source.")
    }
    for (field in intersect(evidence_fields, names(evidence))) {
      use <- !is.na(evidence[[field]]) & nzchar(as.character(evidence[[field]]))
      inventory[index[use], field] <- as.character(evidence[[field]][use])
    }
  }
  allowed <- list(functional_status = c("verified in tested scenarios",
    "confirmed defect", "unverified/ambiguous"), testing_confidence =
    c("adequate", "partial", "missing", "blocked"), lifecycle =
    c("supported", "deferred", "legacy candidate"))
  for (field in names(allowed)) {
    if (any(!inventory[[field]] %in% allowed[[field]])) {
      fail(paste("Invalid curated status in", field))
    }
  }
  for (i in seq_len(nrow(inventory))) {
    row <- inventory[i, ]
    counts <- suppressWarnings(as.numeric(unlist(row[c("required_scenarios",
      "passing_required_scenarios", "blocked_required_scenarios",
      "unexecuted_required_scenarios")], use.names = FALSE)))
    observed <- row$observed_result == "passed" &&
      !row$evidence_reference %in% c("", "not assessed") &&
      !row$tests_and_assertions %in% c("", "not assessed") &&
      !row$expected_value_source %in% c("", "not assessed")
    adequate <- observed && all(is.finite(counts)) &&
      all(counts >= 0 & counts == floor(counts)) && counts[1L] > 0 &&
      counts[2L] == counts[1L] && counts[3L] == 0 && counts[4L] == 0
    if (row$testing_confidence == "adequate" && !adequate) {
      fail(paste("Adequate requires passing required-scenario evidence:",
                 row$site_id))
    }
    if (row$functional_status == "verified in tested scenarios" && !observed) {
      fail(paste("Verified status requires passing assertion evidence:",
                 row$site_id))
    }
    if (row$functional_status == "confirmed defect" &&
        (row$confirmed_findings %in% c("", "not assessed") ||
         row$evidence_reference %in% c("", "not assessed"))) {
      fail(paste("Confirmed defect requires finding and evidence:", row$site_id))
    }
  }
  inventory$measured_coverage <- NA_real_
  owner_index <- match(inventory$owner_site_id, inventory$site_id)
  for (field in c("functional_status", "testing_confidence",
                  "residual_limitations", "evidence_reference")) {
    value <- inventory[[field]][owner_index]
    value[is.na(value)] <- ""
    inventory[[paste0("owner_", field)]] <- value
  }
  inventory$owner_evidence_limitations <- ifelse(top, "",
    paste("Owner context only; nested-site status is not inherited.",
          "Owner assertions must explicitly cover this callback's scenarios."))
  inventory$measured_lines <- 0L
  inventory$coverage_limitations <- paste(
    "Not measured; line coverage is not branch or assertion coverage")
  if (!is.null(options$coverage)) {
    coverage <- utils::read.csv(options$coverage, stringsAsFactors = FALSE)
    if (!all(c("file", "line", "hits") %in% names(coverage))) {
      fail("Coverage requires file,line,hits columns.")
    }
    coverage$file <- gsub("\\\\", "/", coverage$file)
    coverage$file <- vapply(coverage$file, function(p) {
      if (startsWith(p, paste0(root, "/"))) substring(p, nchar(root) + 2L) else p
    }, "")
    for (file in setdiff(unique(coverage$file), inventory$file)) {
      issue("coverage-input", file,
            "File has no function sites; no coverage assigned from its records")
    }
    if (all(is.na(coverage$hits))) coverage$hits <- as.numeric(coverage$hits)
    if (anyNA(coverage$file) || anyNA(coverage$line) ||
        any(!is.finite(coverage$line) | coverage$line < 1 |
              coverage$line != floor(coverage$line)) ||
        !is.numeric(coverage$hits) ||
        any(!is.na(coverage$hits) &
              (!is.finite(coverage$hits) | coverage$hits < 0)) ||
        anyDuplicated(coverage[c("file", "line")])) {
      fail("Invalid or duplicate coverage line records.")
    }
    for (i in seq_len(nrow(inventory))) {
      row <- inventory[i, ]
      hits <- coverage$hits[coverage$file == row$file &
        coverage$line >= row$line_start & coverage$line <= row$line_end]
      inventory$measured_lines[i] <- sum(!is.na(hits))
      if (any(!is.na(hits))) {
        inventory$measured_coverage[i] <- mean(hits > 0, na.rm = TRUE) * 100
      }
    }
    inventory$coverage_limitations <- paste(
      "Supplied test-only line inventory; inclusive source spans overlap nested",
      "sites; missing lines unknown; not branch/assertion coverage")
  }
  inventory$assessment_stage <- "provisional; curated claims not re-executed"
  modules <- lapply(basename(files), function(module) {
    rows <- inventory[inventory$module == module, ]
    list(module = module, top_level = sum(rows$source_kind == "top-level"),
      nested = sum(rows$source_kind == "nested"),
      named_local = sum(rows$source_kind == "nested" & rows$named),
      exported = sum(rows$visibility == "exported"),
      s3 = sum(rows$visibility == "registered S3 method"),
      hooks = sum(rows$visibility == "lifecycle hook"),
      verified = sum(rows$functional_status == "verified in tested scenarios"),
      confirmed_defects = sum(rows$functional_status == "confirmed defect"),
      unverified = sum(rows$functional_status == "unverified/ambiguous"),
      adequate = sum(rows$testing_confidence == "adequate"),
      partial = sum(rows$testing_confidence == "partial"),
      missing = sum(rows$testing_confidence == "missing"),
      blocked = sum(rows$testing_confidence == "blocked"),
      nested_owner_not_adequate = sum(rows$source_kind == "nested" &
        rows$owner_testing_confidence != "adequate"))
  })
  summary <- bind(modules, "module")
  write_csv(inventory, "function-audit")
  write_csv(summary, "module-summary")
  write_csv(call_table, "calls")
  write_csv(tests, "test-sites")
  write_csv(refs, "test-references")
  write_csv(bind(instances, c("instance", "source_site_id", "signature",
    "status", "factory", "captured_binding", "captured_callable",
    "captured_source_site_id")), "runtime-instances")
  write_csv(bind(discrepancies, c("kind", "subject", "detail")), "discrepancies")
  metadata <- c(root = root, generated_utc = format(Sys.time(), tz = "UTC",
    usetz = TRUE), R = R.version.string, platform = R.version$platform,
    package = package, source_version = source_version,
    namespace_status = namespace_status, namespace_path = namespace_path,
    installed_version = installed_version,
    libraries = paste(.libPaths(), collapse = .Platform$path.sep),
    coverage_input = if (is.null(options$coverage)) "none" else options$coverage,
    evidence_input = if (is.null(options$evidence)) "none" else options$evidence,
    test_files = length(test_files), test_cases = nrow(tests),
    top_level = census["top_level"], nested = census["nested"],
    discrepancies = length(discrepancies),
    limitations = "No tests run; no assertions or performance independently verified")
  write_csv(data.frame(key = names(metadata), value = unname(metadata)),
            "run-metadata")
  lines <- c("Provisional function audit (source sites, not closure counts)",
    paste("Root:", root), paste("Namespace:", namespace_status),
    paste("Census:", paste(names(census), census, collapse = "; ")),
    paste("Tests:", length(test_files), "files;", nrow(tests),
          "syntactic test_that cases; none executed"),
    paste("Discrepancies:", length(discrepancies), "(see discrepancies.csv)"),
    "", capture.output(print(summary, row.names = FALSE)), "",
    "Call-name references are not proof of execution, assertions or passing tests.",
    "Owner references are candidates for indirect exercise, not established coverage.",
    "Coverage is inclusive-span line coverage, not branch or assertion coverage.",
    "Curated assessments are external attestations; this script does not verify them.")
  writeLines(lines, file.path(out, "module-summary.txt"), useBytes = TRUE)
  cat(paste(lines[seq_len(6L)], collapse = "\n"), "\n")
  return(invisible(inventory))
}

if (sys.nframe() == 0L) audit_main()
