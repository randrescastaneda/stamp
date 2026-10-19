# Run in a disposable R --vanilla child, never in an interactive user session:
# R.exe --vanilla --slave -f dev/benchmark-audit.R --args SOURCE SCRATCH [REPEATS]
# SOURCE may be the immutable audit mirror; SCRATCH must be an existing parent.
# Outputs are scratch-only RDS/text evidence, not package tests or a speed gate.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L || !dir.exists(args[1L]) || !dir.exists(args[2L])) {
  stop("Supply existing source and scratch parent directories.")
}
source_dir <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
scratch_parent <- normalizePath(args[2L], winslash = "/", mustWork = TRUE)
repeats <- if (length(args) >= 3L) as.integer(args[3L]) else 3L
stopifnot(length(repeats) == 1L, !is.na(repeats), repeats >= 1L)
seed <- 20261015L
set.seed(seed)
output <- tempfile("stamp-benchmark-", tmpdir = scratch_parent)
dir.create(output)
cat("Evidence directory:", output, "\n")
pkgload::load_all(source_dir, quiet = TRUE, export_all = FALSE)
data.table::setDTthreads(1L)
ns <- asNamespace("stamp")
internal <- function(name) get(name, envir = ns, inherits = FALSE)
stamp::st_opts_reset()
stamp::st_opts(meta_format = "json", versioning = "content",
               store_file_hash = FALSE, verify_on_load = FALSE)

# Namespace traces exist only in this child. Counts are R function entries,
# not OS syscalls, disk writes, C-level serialization, or total bytes written.
.audit_counts <- new.env(parent = emptyenv())
traced <- list()
trace_targets <- list(
  stamp = c("st_hash_obj", "st_hash_code", "st_hash_file",
            ".st_catalog_read", ".st_catalog_write", ".st_write_qs2"),
  base = c("serialize", "saveRDS"),
  fs = c("file_copy", "file_move", "file_delete", "dir_ls")
)
for (package in names(trace_targets)) {
  where <- asNamespace(package)
  for (name in trace_targets[[package]]) {
    key <- paste(package, name, sep = "::")
    tracer <- substitute({
      counts <- get(".audit_counts", envir = .GlobalEnv)
      counts[[KEY]] <- if (is.null(counts[[KEY]])) 1L else counts[[KEY]] + 1L
    }, list(KEY = key))
    invisible(capture.output(trace(name, tracer = tracer, print = FALSE,
                                   where = where)))
    traced[[key]] <- list(name = name, where = where)
  }
}
counter_keys <- names(traced)
rows <- list()
filesystem <- function(root) {
  paths <- list.files(root, recursive = TRUE, full.names = TRUE,
                      all.files = TRUE, no.. = TRUE)
  sizes <- file.info(paths)$size
  return(c(files = length(paths), bytes = sum(sizes, na.rm = TRUE)))
}
measure <- function(label, shape, fun, root = NULL) {
  for (iteration in seq_len(repeats)) {
    invisible(gc())
    before <- if (is.null(root)) c(files = 0, bytes = 0) else filesystem(root)
    for (key in counter_keys) .audit_counts[[key]] <- 0L
    profile <- file.path(output, "allocation-current.txt")
    profiling <- isTRUE(capabilities("profmem"))
    if (profiling) Rprofmem(profile)
    start <- proc.time()[["elapsed"]]
    value <- tryCatch(fun(iteration), finally = {
      elapsed <- proc.time()[["elapsed"]] - start
      if (profiling) Rprofmem(NULL)
    })
    counts <- vapply(counter_keys, function(key) .audit_counts[[key]], integer(1))
    after <- if (is.null(root)) c(files = 0, bytes = 0) else filesystem(root)
    allocations <- if (profiling) readLines(profile, warn = FALSE) else character()
    allocation_sizes <- suppressWarnings(as.numeric(sub(" .*", "", allocations)))
    row <- data.frame(label = label, shape = shape, iteration = iteration,
                      elapsed_seconds = elapsed,
                      allocated_bytes = if (profiling) {
                        sum(allocation_sizes, na.rm = TRUE)
                      } else NA_real_,
                      allocation_events = if (profiling) {
                        sum(!is.na(allocation_sizes))
                      } else NA_integer_,
                      files_before = before[["files"]],
                      files_after = after[["files"]],
                      bytes_before = before[["bytes"]],
                      bytes_after = after[["bytes"]])
    for (key in counter_keys) row[[key]] <- counts[[key]]
    rows[[length(rows) + 1L]] <<- row
    cat(label, shape, iteration, "elapsed", elapsed, "allocation bytes",
        row$allocated_bytes, "files", after[["files"]] - before[["files"]],
        "net bytes", after[["bytes"]] - before[["bytes"]], "\n")
  }
  return(invisible(value))
}
new_store <- function(label) {
  root <- file.path(output, label)
  dir.create(root)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  stamp::st_init(root, verbose = FALSE)
  return(root)
}
for (n in c(1000L, 10000L)) {
  root <- new_store(paste0("save-", n))
  x <- data.frame(id = seq_len(n), value = rnorm(n),
                  group = rep(letters[1:10], length.out = n))
  path <- file.path(root, "synthetic.rds")
  initial <- stamp::st_save(x, path, format = "rds", verbose = FALSE)
  stopifnot(!is.null(initial$version_id))
  measure("save_unchanged", paste(n, "rows x 3 columns; rds/json"),
          function(i) {
            result <- stamp::st_save(x, path, format = "rds", verbose = FALSE)
            stopifnot(isTRUE(result$skipped))
            return(result)
          }, root)
  measure("save_changed", paste(n, "rows x 3 columns; rds/json"),
          function(i) {
            changed <- x
            changed$value[1L] <- x$value[1L] + i
            result <- stamp::st_save(changed, path, format = "rds",
                                     verbose = FALSE)
            stopifnot(!is.null(result$version_id), !isTRUE(result$skipped))
            return(result)
          }, root)
}

# Catalog fixtures isolate artifact count from versions-per-artifact. They do
# not claim to be complete stores: only catalog I/O and dry-run policy use them.
catalog_fixture <- function(root, artifacts, versions) {
  ids <- paste0("a", seq_len(artifacts))
  version_ids <- paste0("v", seq_len(artifacts * versions))
  catalog <- internal(".st_catalog_empty")()
  paths <- vapply(file.path(root, paste0(ids, ".rds")), function(path) {
    internal(".st_normalize_user_path")(path)$logical_path
  }, character(1), USE.NAMES = FALSE)
  catalog$artifacts <- data.table::data.table(
    artifact_id = ids, path = paths,
    format = "rds", latest_version_id = version_ids[seq_len(artifacts) * versions],
    n_versions = as.integer(versions))
  catalog$versions <- data.table::data.table(
    version_id = version_ids, artifact_id = rep(ids, each = versions),
    content_hash = sprintf("%016d", seq_along(version_ids)),
    code_hash = NA_character_, size_bytes = 100,
    created_at = format(as.POSIXct("2020-01-01", tz = "UTC") +
                          seq_along(version_ids), "%Y-%m-%dT%H:%M:%SZ",
                        tz = "UTC"), sidecar_format = "json")
  return(catalog)
}
for (artifacts in c(10L, 100L)) {
  for (versions in c(2L, 20L)) {
    root <- new_store(paste0("catalog-", artifacts, "-", versions))
    catalog <- catalog_fixture(root, artifacts, versions)
    shape <- paste(artifacts, "artifacts x", versions, "versions")
    internal(".st_catalog_write")(catalog)
    measure("catalog_read", shape, function(i) {
      result <- internal(".st_catalog_read")()
      stopifnot(identical(as.data.frame(result$versions),
                          as.data.frame(catalog$versions)))
      return(result)
    }, root)
    measure("catalog_write", shape, function(i) {
      internal(".st_catalog_write")(catalog)
    }, root)
    expected <- artifacts * (versions - 1L)
    measure("retention_dry_run", shape, function(i) {
      result <- suppressMessages(stamp::st_prune_versions(policy = 1L))
      stopifnot(nrow(result) == expected)
      return(result)
    }, root)
  }
}

# Chain and star are measured separately, with one version per node and real
# parents.json files for lineage; catalog parents_index supplies child queries.
for (nodes in c(10L, 50L)) {
  for (graph in c("chain", "star")) {
    root <- new_store(paste0("graph-", graph, "-", nodes))
    catalog <- catalog_fixture(root, nodes, 1L)
    parent <- if (graph == "chain") seq_len(nodes - 1L) else rep(1L, nodes - 1L)
    child <- 2L:nodes
    catalog$parents_index <- data.table::data.table(
      parent_artifact_id = catalog$artifacts$artifact_id[parent],
      parent_version_id = catalog$versions$version_id[parent],
      child_artifact_id = catalog$artifacts$artifact_id[child],
      child_version_id = catalog$versions$version_id[child])
    # Public child lookups compute IDs from the normalized logical path.
    catalog$artifacts$artifact_id <- unname(vapply(catalog$artifacts$path,
                                          internal(".st_artifact_id"), ""))
    catalog$versions$artifact_id <- catalog$artifacts$artifact_id
    catalog$parents_index$parent_artifact_id <- catalog$artifacts$artifact_id[parent]
    catalog$parents_index$child_artifact_id <- catalog$artifacts$artifact_id[child]
    internal(".st_catalog_write")(catalog)
    for (j in seq_along(child)) {
      directory <- internal(".st_version_dir")(
        basename(catalog$artifacts$path[child[j]]),
        catalog$versions$version_id[child[j]])
      internal(".st_version_write_parents")(
        directory, list(list(path = catalog$artifacts$path[parent[j]],
                             version_id = catalog$versions$version_id[parent[j]])))
    }
    shape <- paste(graph, nodes, "nodes")
    measure("graph_children", shape, function(i) {
      result <- stamp::st_children(catalog$artifacts$path[1L], depth = Inf)
      stopifnot(nrow(result) == nodes - 1L)
      return(result)
    }, root)
    measure("graph_lineage", shape, function(i) {
      result <- stamp::st_lineage(catalog$artifacts$path[nodes], depth = Inf)
      stopifnot(nrow(result) == if (graph == "chain") nodes - 1L else 1L)
      return(result)
    }, root)
  }
}

# Alternatives are disposable algorithms, not modifications to stamp. Grid
# construction represents dense enumeration; current stamp uses split(), not
# expand.grid(). Both alternatives return sorted observed integer key pairs.
for (n in c(20L, 100L)) {
  keys <- data.frame(k1 = seq_len(n), k2 = seq_len(n))
  dense <- function(i) {
    grid <- expand.grid(k1 = unique(keys$k1), k2 = unique(keys$k2))
    result <- merge(grid, keys, by = c("k1", "k2"), sort = TRUE)
    result <- result[order(result$k1, result$k2), , drop = FALSE]
    rownames(result) <- NULL
    return(data.frame(k1 = result$k1, k2 = result$k2))
  }
  sparse <- function(i) {
    result <- unique(keys)
    result <- result[order(result$k1, result$k2), , drop = FALSE]
    rownames(result) <- NULL
    return(result)
  }
  stopifnot(identical(dense(1L), sparse(1L)))
  shape <- paste(n, "observed of", n * n, "possible key pairs")
  measure("partition_grid_observed", shape, dense)
  measure("partition_sparse_observed", shape, sparse)
}
for (parts in c(20L, 100L)) {
  chunks <- lapply(seq_len(parts), function(i) {
    data.frame(id = as.integer((i - 1L) * 100L + seq_len(100L)),
               value = rnorm(100L), group = "synthetic")
  })
  reduce_bind <- function(i) Reduce(rbind, chunks)
  list_bind <- function(i) as.data.frame(data.table::rbindlist(chunks))
  stopifnot(identical(reduce_bind(1L), list_bind(1L)))
  shape <- paste(parts, "partitions x 100 rows x 3 columns")
  measure("partition_reduce_rbind", shape, reduce_bind)
  measure("partition_rbindlist", shape, list_bind)
  root <- file.path(output, paste0("partition-files-", parts))
  dir.create(root)
  for (i in seq_len(parts)) {
    directory <- file.path(root, paste0("key=", i))
    dir.create(directory)
    saveRDS(chunks[[i]], file.path(directory, "part.rds"))
  }
  exts <- unique(internal(".st_known_exts")())
  repeated_scan <- function(i) sort(unique(as.character(unlist(lapply(exts,
    function(ext) fs::dir_ls(root, recurse = TRUE, type = "file",
                            glob = paste0("*.", ext))), use.names = FALSE))))
  single_scan <- function(i) {
    paths <- as.character(fs::dir_ls(root, recurse = TRUE, type = "file"))
    return(sort(paths[tolower(fs::path_ext(paths)) %in% exts]))
  }
  stopifnot(identical(repeated_scan(1L), single_scan(1L)))
  measure("partition_repeated_scan", shape, repeated_scan, root)
  measure("partition_single_scan", shape, single_scan, root)
  measure("partition_public_list", shape, function(i) {
    result <- internal("st_list_parts")(root)
    stopifnot(nrow(result) == parts,
              identical(sort(as.character(result$path)),
                        sort(as.character(fs::path_dir(single_scan(i))))))
    return(result)
  }, root)
}
for (target in traced) {
  invisible(capture.output(untrace(target$name, where = target$where)))
}
results <- do.call(rbind, rows)
# pkgload can load source when stamp is not installed: use source DESCRIPTION.
description <- read.dcf(file.path(source_dir, "DESCRIPTION"))
dependency_names <- unique(trimws(gsub("\\s*\\([^)]*\\)", "", unlist(
  strsplit(paste(description[1L, c("Imports", "Suggests")], collapse = ","),
           ",")))))
dependencies <- lapply(dependency_names, function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(list(package = package, available = FALSE))
  }
  desc <- packageDescription(package)
  return(list(package = package, available = TRUE, version = desc$Version,
              depends = desc$Depends, imports = desc$Imports,
              linking_to = desc$LinkingTo, built = desc$Built))
})
names(dependencies) <- dependency_names
installed <- installed.packages()
closure_names <- unique(c(dependency_names, unlist(
  tools::package_dependencies(dependency_names, db = installed,
                              which = c("Depends", "Imports", "LinkingTo"),
                              recursive = TRUE), use.names = FALSE)))
closure_names <- setdiff(closure_names, c("R", NA_character_))
dependency_minimums <- do.call(rbind, lapply(sort(closure_names), function(name) {
  if (!name %in% rownames(installed)) {
    return(data.frame(package = name, version = NA_character_,
                       depends = NA_character_, available = FALSE))
  }
  desc <- packageDescription(name)
  return(data.frame(package = name, version = desc$Version,
                     depends = if (is.null(desc$Depends)) "" else desc$Depends,
                     available = TRUE))
}))
metadata <- list(seed = seed, repeats = repeats, source = source_dir,
  source_md5 = tools::md5sum(c(file.path(source_dir, "DESCRIPTION"),
                              list.files(file.path(source_dir, "R"),
                                         full.names = TRUE, pattern = "\\.R$"))),
  output = output, R = R.version, platform = Sys.info(), session = sessionInfo(),
  libraries = .libPaths(), dependencies = dependencies,
  dependency_minimums = dependency_minimums,
  threads = list(data_table = data.table::getDTthreads(),
    qs2_default = qs2::qopt("nthreads"),
    environment = Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS",
                                "MKL_NUM_THREADS", "RCPP_PARALLEL_NUM_THREADS"))),
  qs2_formals = formals(qs2::qs_save),
  backend = "RDS payload; JSON metadata; QS2 catalog; local Windows filesystem",
  limitations = c("Instrumented elapsed includes tracing, Rprofmem and assertions.",
    "Allocations are Rprofmem events/bytes, not peak RSS or all native allocations.",
    "File bytes are net persisted bytes, not cumulative device traffic.",
    "Counts are traced R function entries, not OS syscalls or C serialization.",
    "Single scan comparison uses simple lowercase extensions and no sidecars.",
    "Catalog fixtures are not full stores; retention is dry-run only.",
    "No network, PIP-scale, concurrency, cold-cache or minimum-R claims."))
saveRDS(list(metadata = metadata, measurements = results),
        file.path(output, "measurements.rds"))
capture.output(dput(metadata), file = file.path(output, "metadata.txt"))
capture.output(print(results, row.names = FALSE),
               file = file.path(output, "measurements.txt"))
capture.output(print(dependency_minimums, row.names = FALSE),
               file = file.path(output, "dependency-minimums.txt"))
cat("Measurements:", nrow(results), "; installed dependency closure:",
    nrow(dependency_minimums), "\n")
cat("Complete:", file.path(output, "measurements.rds"), "\n")
