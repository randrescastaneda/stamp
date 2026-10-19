# Integration only: no package loading, source execution, or test execution.
# R.exe --vanilla --slave -f dev/curate-function-audit.R --args
#   --root . --inventory <final-parser-directory> --test-log <testthat.Rout>
#   --evidence <scratch/curated-evidence.csv>
#   --out .cg-docs/reviews/2026-10-15-function-audit.csv
#   [--scope full-suite] [--coverage <file,line,hits.csv>]
# --scope full-suite is an explicit curator attestation that the supplied log
# covers ALL current tests, not a focused suite. Default scope is unconfirmed.
# Aggregate logs cannot prove individual case execution. Skips therefore prevent
# verification promotion. Scenario counts stay unknown unless enumerated here.
curate_function_audit <- function(args = commandArgs(trailingOnly = TRUE)) {
  fail <- function(message) stop(message, call. = FALSE)
  opts <- list(root = ".", inventory = NULL, `test-log` = NULL,
               evidence = NULL, out = NULL, coverage = NULL,
               scope = "unconfirmed")
  if (!length(args) || length(args) %% 2L) fail("Use --name value pairs.")
  for (i in seq.int(1L, length(args), 2L)) {
    key <- sub("^--", "", args[i])
    if (!startsWith(args[i], "--") || !key %in% names(opts)) {
      fail(paste("Unknown option", args[i]))
    }
    opts[[key]] <- args[i + 1L]
  }
  if (any(vapply(opts[c("inventory", "test-log", "evidence", "out")],
                 is.null, logical(1)))) fail("Missing required CLI option.")
  if (!opts$scope %in% c("unconfirmed", "full-suite")) {
    fail("--scope must be unconfirmed or full-suite.")
  }
  root <- normalizePath(opts$root, winslash = "/", mustWork = TRUE)
  read_csv <- function(path) utils::read.csv(path, stringsAsFactors = FALSE,
                                            check.names = FALSE, na.strings = "")
  inventory <- read_csv(file.path(opts$inventory, "function-audit.csv"))
  tests <- read_csv(file.path(opts$inventory, "test-sites.csv"))
  needed <- c("site_id", "file", "name", "source_md5", "source_kind",
              "line_start", "line_end", "top_owner_name", "signature")
  if (!all(needed %in% names(inventory)) || anyDuplicated(inventory$site_id)) {
    fail("Invalid function inventory.")
  }
  inventory[is.na(inventory)] <- ""
  tests[is.na(tests)] <- ""
  for (file in unique(tests$file)) {
    lines <- readLines(file.path(root, file), warn = FALSE)
    at <- which(tests$file == file)
    labels <- gsub('^"|"$', "", tests$label[at])
    if (any(tests$line_end[at] > length(lines)) || any(!vapply(
        seq_along(at), function(j) grepl(labels[j], lines[tests$line[at[j]]],
                                         fixed = TRUE), logical(1)))) {
      fail(paste("Stale test-site inventory; rerun parser:", file))
    }
  }
  current_md5 <- unname(tools::md5sum(file.path(root, inventory$file)))
  if (anyNA(current_md5) || any(current_md5 != inventory$source_md5)) {
    fail("Inventory is stale: rerun dev/function-audit.R on final sources.")
  }
  log_path <- normalizePath(opts$`test-log`, winslash = "/", mustWork = TRUE)
  log <- readLines(log_path, warn = FALSE)
  summary_pattern <- "\\[\\s*FAIL\\s+[0-9]+\\s*\\|\\s*WARN\\s+[0-9]+\\s*\\|\\s*SKIP\\s+[0-9]+\\s*\\|\\s*PASS\\s+[0-9]+\\s*\\]"
  summaries <- regmatches(log, regexpr(summary_pattern, log, perl = TRUE))
  summaries <- summaries[nzchar(summaries)]
  if (length(summaries) != 1L) {
    fail("Require exactly one observed testthat FAIL/WARN/SKIP/PASS summary.")
  }
  counts <- as.integer(regmatches(summaries, gregexpr("[0-9]+", summaries))[[1L]])
  if (counts[1L] != 0L || counts[4L] < 1L ||
      any(grepl("Execution halted|Tests failed|Fatal error", log))) {
    fail("Test log is not an observed passing run.")
  }
  test_files <- list.files(file.path(root, "tests/testthat"), "\\.[Rr]$",
                           full.names = TRUE)
  newest <- max(file.info(c(file.path(root, unique(inventory$file)),
                            test_files))$mtime, na.rm = TRUE)
  fresh <- file.info(log_path)$mtime >= newest
  observed <- opts$scope == "full-suite" && counts[3L] == 0L && fresh
  run_limit <- if (!fresh) {
    "Supplied passing log predates current sources/tests; final run required"
  } else if (opts$scope != "full-suite") {
    "Supplied passing log scope unconfirmed; full-suite attestation required"
  } else if (counts[3L] > 0L) {
    "Aggregate passing log contains skips; per-case execution not established"
  } else "Full-suite passing-log attestation; no individual-case result manifest"

  # Explicit top-owner map from the module auditors. The last column selects
  # reviewed behavioral cases, not symbol references or executable-line hits.
  map_text <- c(
    "NULL_FALLBACK|Return fallback lazily only for NULL|state access and lazy null",
    "st_state_set|Store named session-state bindings|state access and lazy null",
    "st_state_get|Read session-state binding or supplied default|state access and lazy null",
    ".st_alias_register|Register alias root and metadata configuration|alias helpers match",
    ".st_alias_get|Resolve explicit or active alias configuration|alias helpers match",
    ".st_path_matches_alias|Check normalized path root boundary for an alias|alias helpers match",
    ".st_detect_alias_from_path|Select the longest matching registered root|alias helpers match|paths handle missing aliases",
    ".st_normalize_path|Normalize platform path spelling for logical identity|alias helpers match|path helpers distinguish",
    ".st_make_abs|Resolve an absolute path with failure fallback|alias helpers match",
    "st_opts_init_defaults|Seed absent options without replacing existing bindings|options initialize idempotently",
    ".st_opts_validate|Validate proposed option update before mutation|options initialize idempotently",
    "st_opts|Get or validate then update option bindings and report changes|options initialize idempotently",
    "st_opts_reset|Reset the option environment to package defaults|options initialize idempotently",
    "st_opts_get|Read all options or a single option binding|options initialize idempotently",
    ".st_now_utc|Format current UTC time including fractional seconds|path helpers distinguish",
    ".st_dir_create|Create directory recursively only when needed|path helpers distinguish",
    ".st_file_storage_dir|Resolve artifact payload directory under configured alias|path helpers distinguish",
    ".st_artifact_path|Resolve the payload file named artifact|path helpers distinguish",
    ".st_extract_rel_path|Recover logical relative path from artifact or metadata layout|path helpers distinguish",
    ".st_normalize_user_path|Separate alias-relative logical identity and physical storage path|paths handle missing aliases|path helpers distinguish",
    ".seed_extmap|Seed missing extension mappings without replacing custom bindings|extension defaults seed",
    "st_extmap_defaults|Return built-in extension-to-format defaults|extension defaults seed",
    "st_extmap_report|Report effective extension map as a named vector|extension defaults seed",
    ".mirror_opts_to_base|Mirror missing stamp options without replacing session overrides|option mirrors fill",
    ".onLoad|Initialize options maps registry and CLI theme on namespace load|lifecycle hooks restore",
    ".onUnload|Restore prior CLI theme including initially absent option|lifecycle hooks restore",
    "st_pk|Normalize PK names and validate columns and optional uniqueness|PK normalization validates",
    "st_with_pk|Attach normalized PK metadata without mutating caller|PK normalization validates",
    "st_get_pk|Read PK names from object attributes or sidecar metadata|PK normalization validates",
    "st_inspect_pk|Read live metadata PK or return empty on unavailable metadata|PK inspection failure",
    "st_add_pk|Update live PK metadata without rewriting immutable snapshots|PK inspection failure|live primary key metadata",
    "st_filter|Select rows by named membership filters preserving table classes|filtering preserves values",
    "st_set_pk|Attach PK and optional domain after uniqueness validation|PK normalization validates",
    "st_assert_pk|Assert declared PK columns and uniqueness when present|PK normalization validates",
    "st_normalize_attrs|Order top-level attributes while preserving values and classes|normalization preserves|normalizer handles",
    ".st_is_dt|Recognize data.table objects by inheritance|normalization preserves",
    ".st_has_custom_rownames|Distinguish custom row names from automatic encodings|default rowname encodings",
    "st_sanitize_for_hash|Construct stable stored object with restoration metadata|sanitizer output matches|DT internals and keys|NULL and empty objects|atomic classes and list attrs",
    "st_hash_obj|SipHash serialized sanitized object with canonical top attributes|object hash retains|sanitizer output matches|NULL and empty objects",
    "st_hash_code|Hash normalized code text or function formals and body|code hashing matches",
    "st_hash_file|Hash file bytes independently of object serialization|file hashing uses bytes",
    ".st_restore_sanitized_object|Restore recorded class and row names and remove storage markers|reader restores a hand-built|restoration does not mutate|atomic classes and list attrs",
    ".st_data_table_key|Read only the actual original data.table key or explicit unkeyed state|native loads preserve only keys|unkeyed sorted inputs|key-only changes",
    ".st_recorded_data_table_key|Decode versioned key metadata distinguishing legacy unknown from recorded unkeyed|native loads preserve only keys|key-only changes|legacy missing descriptors|key descriptors are validated",
    ".st_restore_data_table_key|Restore only recorded native keys after independent order validation without sorting returned rows|native loads preserve only keys|unkeyed sorted inputs|recorded keys do not|key descriptors are validated|known-unkeyed metadata|recorded keys do not coerce|key validation distrusts|native keys retain",
    "st_changed|Compare supplied object including explicit NULL while omitted content stays unchecked|change detection reports independent",
    ".st_wrap_reader|Return reader adapter forwarding path and optional arguments|returned reader and writer wrappers|six builtin handlers",
    ".st_wrap_writer|Return writer adapter forwarding object path and arguments|returned reader and writer wrappers|six builtin handlers",
    ".st_write_qs2|Serialize object with QS2 backend|six builtin handlers",
    ".st_read_qs2|Read object with QS2 backend|six builtin handlers",
    ".st_rds_read|Read R serialization with forwarded arguments|RDS retains attributes|six builtin handlers",
    ".st_rds_write|Write R serialization with forwarded arguments|RDS retains attributes|six builtin handlers",
    ".st_csv_read|Read tabular delimited text with data.table|RDS retains attributes|six builtin handlers",
    ".st_csv_write|Write tabular delimited text with data.table|RDS retains attributes|six builtin handlers",
    ".st_fst_read|Read fst table or fail explicitly when backend missing|optional fst absence|six builtin handlers",
    ".st_fst_write|Write fst table or fail explicitly when backend missing|optional fst absence|six builtin handlers",
    ".st_parquet_read|Read parquet table with nanoparquet|six builtin handlers",
    ".st_parquet_write|Write parquet table with nanoparquet|six builtin handlers",
    ".st_json_read|Read simplified JSON table representation|six builtin handlers",
    ".st_json_write|Write JSON object with explicit numeric fidelity policy|six builtin handlers",
    "st_register_format|Validate register and replace wrapped format handlers|custom|registration",
    ".st_extmap_set|Normalize extensions and update extension-to-format map|extension defaults seed|registration",
    "st_formats|List registered format names|registered format handlers|registration|custom filenames",
    ".st_sidecar_path|Resolve JSON or QS2 metadata location under alias|all metadata representation transitions",
    ".st_write_sidecar|Publish configured metadata representations and retire stale sidecar|all metadata representation transitions|interrupted sidecar transitions|promotion",
    "st_read_sidecar|Read metadata with JSON priority and visible dual divergence|corrupt and divergent metadata|all metadata representation transitions",
    ".st_is_named_scalar_list|Validate partition key shape and scalar atomic values|partition helper keys",
    ".st_key_normalize|Sort key names and encode scalar values rejecting separators|partition helper keys",
    ".st_key_segments|Construct sorted key=value directory segments|partition helper keys",
    ".st_known_exts|Enumerate registered extensions for partition discovery|partition helper keys",
    ".st_guess_or_default_format|Apply explicit format then extension then default precedence|partition helper keys",
    ".st_file_basename_default|Choose part.<format> default filename|partition helper keys",
    ".st_parse_key_from_rel|Parse directory key segments into scalar key values|partition helper keys",
    ".st_match_filter|Evaluate partition expression or named membership filter|partition helper keys",
    "st_part_path|Combine normalized partition key directories and payload filename|custom filenames|partition helper keys",
    "st_save_part|Save one keyed partition through artifact save boundary|custom filenames|unloadable partition keys|failed partition writers",
    "st_write_parts|Split observed key combinations and save partition manifests|partition binding unions|unloadable partition keys|failed partition writers|sparse|st_write_parts",
    "st_list_parts|Discover physical partition files and report logical paths and keys|custom filenames|partition helper keys",
    "st_load_parts|Load full or projected physical payloads and bind requested partitions|custom filenames|noncolumnar projection|unreadable and missing listed|partition binding unions|fst projection",
    "st_init|Initialize isolated alias root state and format settings|save decisions and info|alias",
    "st_path|Construct deferred logical path descriptor with inferred format|deferred st_path S3|save decisions and info",
    "print.st_path|Print path descriptor and return it invisibly unchanged|deferred st_path S3|save decisions and info",
    ".st_guess_format|Resolve registered file extension case-insensitively|save decisions and info",
    ".st_reference_copy_for_save|Preflight a bounded ordinary environment graph and detach it once for native-RDS save only|native RDS save uses one owned copy|copy preserves cycles|special roots and binding|special parent boundaries|promises and active|opaque bindings|unsafe nested environments|atomic attributes|non-native formats|graph node and depth|serialization failures|ordinary locked environment",
    "st_save|Apply save policy under the artifact lock then publish payload metadata snapshot and catalog|failed save boundaries|competing writers|save decisions and info|committed history survives|save decisions hold the artifact lock|decision errors still propagate",
    "st_load|Read current payload or selected version with verification policy|save decisions and info|sidecar|historical verification|file.hash|public signed restore",
    "st_info|Report exact logical identity metadata catalog and snapshot state|save decisions and info",
    "st_alias_list|List alias configuration and active status|alias",
    "st_alias_get|Return explicit or active alias configuration|alias",
    "st_switch|Switch active alias while preserving state on invalid alias|switch success and failure",
    "st_restore|Restore selected historical payload using signed offsets with warned positive compatibility|restore explicit IDs|restore retains legacy format fallback|public signed restore|public positive restore|invalid public restore",
    ".st_resolve_version_identifier|Resolve zero/negative retained-history offsets IDs and keywords with warned legacy positive positions|restore selectors|version selectors enforce",
    "st_changed_reason|Expose exact detected change reason for save decisions|save decisions and info|change detection reports",
    "st_should_save|Apply content timestamp and off policy to change result|save decisions and info|should save|versioning|save decisions hold the artifact lock",
    ".st_write_atomic|Stage payload and replace destination without pre-deletion|atomic writes preserve|atomic writes enforce",
    ".st_with_lock|Evaluate critical expression only after lock acquisition or documented fallback|lock fallback evaluates|real lock timeout|competing writers",
    ".st_norm_path|Resolve absolute path preserving established identity spelling|version path and compact ID",
    ".st_artifact_id|Derive persisted artifact ID from normalized path bytes|version path and compact ID|catalog upsert append",
    ".st_root_dir|Resolve configured root for active or explicit alias|version path and compact ID",
    ".st_state_dir_abs|Resolve configured metadata state root|version path and compact ID",
    ".st_versions_root|Return deprecated centralized versions location|version path and compact ID",
    ".st_version_dir|Resolve per-artifact immutable version directory|version path and compact ID",
    ".st_catalog_path|Resolve alias-local catalog.qs2 path|version path and compact ID",
    ".st_catalog_empty|Construct typed empty artifact version and parent-index tables|catalog templates",
    ".st_catalog_read|Return empty for missing catalog and read legacy/current shapes while surfacing corrupt bytes|catalog templates",
    ".st_catalog_write|Publish catalog through replacement-safe staging helper|catalog upsert append|failed save boundaries",
    "st_versions|List ordered catalog versions with stable tie handling|version ordering handles",
    "st_latest|Resolve latest valid version despite stale latest pointer|version ordering handles",
    ".st_resolve_version|Resolve latest exact IDs and negative offsets with explicit interactive opt-in|version selectors enforce|public signed restore",
    ".st_prompt_select_version|Present interactive version menu and validate selection|version selectors enforce",
    "st_load_version|Read committed format and verify immutable historical payload|historical loads use|historical custom readers|historical verification|legacy snapshots without",
    "st_lineage|Walk committed parent snapshots with alias-relative paths|lineage and children return|cross-alias multi-parent",
    ".st_version_id|Construct compact compatibility ID from time and content|version path and compact ID",
    ".st_sidecar_present|Detect either supported metadata representation|version path and compact ID",
    ".st_version_commit_files|Stage complete snapshot and refuse existing-version mutation|snapshot commits refuse|failed save boundaries",
    ".st_version_dir_latest|Locate snapshot directory selected by latest catalog version|version ordering handles|version path and compact ID",
    ".st_catalog_upsert_artifact|Insert or update artifact row without duplicate identities|catalog upsert append",
    ".st_catalog_append_version|Append immutable version row to catalog|catalog upsert append",
    ".st_catalog_record_version|Record exact version identity and normalized parent edges|catalog upsert append|competing writers",
    ".st_version_write_parents|Publish committed parent JSON without losing prior file on failure|parent normalization and snapshots|failed parent metadata promotion",
    ".st_version_read_parents|Read committed parent JSON with visible corruption fallback|parent normalization and snapshots",
    ".st_parents_normalize|Normalize accepted parent vector list and table shapes|parent normalization and snapshots",
    ".st_artifact_path_from_id|Resolve catalog artifact identity back to path|catalog upsert append|lineage and children return",
    ".st_children_once|Find immediate indexed children with canonical relative-path snapshot fallback|lineage and children return|children traversal terminates|snapshot scanning takes relative paths",
    "st_children|Traverse reverse dependencies with cycle termination and depth|lineage and children return|children traversal terminates",
    "st_is_stale|Compare committed parent versions with current parent latest|lineage and children return|stale",
    "st_catalog_query|Join each artifact to its latest version using artifact-local identity|catalog query|query",
    ".st_builder_key|Derive normalized path and optional name registry key|builder registration|builder lookup survives",
    "st_register_builder|Validate and replace builder registered for artifact path|builder registration",
    "st_builders|List exact currently registered builders|builder registration",
    "st_clear_builders|Clear all builders or only matching artifact path|builder registration",
    ".st_committed_parents_latest|Read latest committed parent table for rebuild planning|parent readers normalize",
    ".st_sidecar_parents|Recover parent metadata fallback for rebuild execution|rebuild sidecar fallback",
    ".children_of|Normalize immediate child paths used by rebuild traversal|rebuild plans cover",
    "st_rebuild|Execute dependency-safe builders with dry-run and failure reporting|unequal-depth DAG rebuilds|registered builders rebuild|rebuild failures|rebuild sidecar fallback",
    "st_plan_rebuild|Plan strict or propagated dependent rebuilds without loops|rebuild plans cover",
    "st_prune_versions|Prune selected scope preserving surviving files records and edges|scoped prune preserves|multiple scoped paths|partial snapshot deletion|pruning honors timestamp ties",
    ".st_normalize_policy|Validate and normalize count age and combined retention|retention normalization rejects",
    ".st_apply_retention|Apply configured retention after successful save|scoped prune preserves|automatic",
    ".st_policy_keep_ids|Compute union of count and age keep sets preserving latest minimum|retention count and age policies|pruning honors timestamp ties",
    ".st_parse_utc_times|Parse whole and fractional UTC timestamps for retention cutoff|retention count and age policies",
    ".st_delete_version_dir_safe|Delete only intended snapshot directory and report failure|safe version deletion|partial snapshot deletion"
  )
  map <- strsplit(map_text, "|", fixed = TRUE)
  map[[1L]][1L] <- "%||%"
  keys <- vapply(map, `[`, "", 1L)
  top <- inventory$source_kind == "top-level"
  unknown <- setdiff(inventory$name[top], keys)
  if (length(unknown)) fail(paste("Missing curated top-level mapping:",
                                 paste(unknown, collapse = ", ")))

  module_test <- c(aaa.R = "state-schema", options.R = "state-schema",
    utils.R = "state-schema", zzz.R = "state-schema", schema_pk.R = "state-schema",
    hashing.R = "hashing", format_registry.R = "formats-partitions",
    partitions.R = "formats-partitions", IO_core.R = "io",
    version_store.R = "versions", retention.R = "retention-rebuild",
    rebuild.R = "retention-rebuild", reference_copy.R = "reference-copy-pilot")
  module_gaps <- c(
    aaa.R = "POSIX/Windows drive/UNC parity, root ties and symlink/junction routing not all executed",
    options.R = "Malformed .get controls and validation policy for all supported options not exhaustively specified",
    utils.R = "Relative traversal alias-root boundary unresolved; POSIX/UNC/junction containment scenarios pending",
    zzz.R = "Clean-session hooks tested locally; supported R/platform matrix and all startup failure branches pending",
    schema_pk.R = "Live PK metadata versus immutable snapshot semantics differ; all structured failure/backend branches not enumerated",
    hashing.R = "Original native data.table keys are now versioned restoration metadata, not content hashes. Locale, nested attributes, environment mutation, custom-class and primitive-code equivalence remain unresolved",
    format_registry.R = "All six backend fixtures are bounded; arbitrary R-type fidelity and every backend failure/argument combination not established; no dual-write transaction guarantee",
    partitions.R = "Directory versus payload key authority, Windows key case, numeric/factor/NA fidelity unresolved; all filter/key/backend failure combinations not established",
    IO_core.R = "Fault injection and two-writer local tests do not establish transactional crash/rollback guarantees or network-filesystem safety; full policy/backend matrix not enumerated",
    version_store.R = "Reverse cross-alias global discovery, malformed catalog rows, historical-child/latest recursion and first-visit output levels not fully specified. Canonical 0/-n selectors approved and tested; positive restore compatibility deprecated. Query-expression operators are N/A: st_catalog_query accepts alias only",
    retention.R = "Local count/age/scope/failure fixtures do not establish all filesystem/platform failures or transactional deletion guarantees",
    rebuild.R = "Cycles terminate but no dependency-safe cycle execution contract; full multi-alias/backend and builder failure combinations not established",
    reference_copy.R = "Default-off save-only pilot, not a generic reference copier: ordinary unclassed environment roots, native RDS writer, NULL/atomic bindings and recursively atomic attributes only. Special parents stay shared/uninspected; special roots/binding values and unsupported graphs rejected. Boundary-limit acceptance edges, alternate R/platform serialization and complete failure permutations unverified")
  fields <- c("responsibility", "stated_contract", "expected_value_source",
    "tests_and_assertions", "exercise", "relevant_branches", "confirmed_findings",
    "candidate_findings", "efficiency_evidence", "lifecycle_recommendation",
    "residual_limitations", "functional_status", "testing_confidence", "lifecycle",
    "required_scenarios", "passing_required_scenarios", "blocked_required_scenarios",
    "unexecuted_required_scenarios", "observed_result", "evidence_reference",
    "recommendation_reason", "replacement", "usage_evidence",
    "compatibility_impact", "migration_sequence")
  evidence <- inventory[c("site_id", "source_md5")]
  for (field in fields) evidence[[field]] <- "none identified"
  evidence$functional_status <- "unverified/ambiguous"
  evidence$testing_confidence <- "missing"
  evidence$lifecycle <- ifelse(inventory$module == "partitions.R" |
    inventory$top_owner_name == "st_path", "deferred", "supported")
  evidence$required_scenarios <- "unknown; no exhaustive count attested"
  evidence$passing_required_scenarios <- "unknown; aggregate assertions are not scenario counts"
  evidence$blocked_required_scenarios <- "unknown; see residual_limitations"
  evidence$unexecuted_required_scenarios <- "unknown; see residual_limitations"
  evidence$observed_result <- "passing aggregate; site execution unconfirmed"
  evidence$evidence_reference <- paste0(log_path, " [", summaries, "]; log_md5=",
                                       unname(tools::md5sum(log_path)))
  provenance <- c(
    aaa.R = "board_ad43b7ce-ee35-429e-a359-2e51439c822b",
    options.R = "board_ad43b7ce-ee35-429e-a359-2e51439c822b",
    utils.R = "board_4e0c8016-3ca2-49f5-8a6d-8d93cc61301f; board_d80174a6-7694-43a3-9f6c-c60a179c7454",
    zzz.R = "board_4e0c8016-3ca2-49f5-8a6d-8d93cc61301f",
    schema_pk.R = "board_2ffbfdc6-6b01-403b-903b-451199fd6fb7; board_e0e8b17b-5509-4337-b3a4-1a2629360981",
    hashing.R = "board_f4355638-213e-46ed-a868-405b1b9540f4; board_4cbcc813-90cf-48a6-839a-8f91a7118954; board_aa34cdbf-5cc6-4f0f-9115-4df9184c5d39",
    format_registry.R = "board_d18d7451-5e08-43b5-a925-137ddeff495e; board_be7fae6f-7d69-4ea2-b2d2-94195b0459b7",
    partitions.R = "board_13bf6942-6c24-419a-a44f-07eb727bc7e3; board_59a8e8e2-bbcc-4fc0-8329-0c011577c5ce",
    IO_core.R = "board_53a6872e-2816-4f3c-af3f-d6be9c3a728a; board_e0e8b17b-5509-4337-b3a4-1a2629360981; tests/testthat/test-audit-io.R",
    version_store.R = "board_bba3c7ff-019e-4c44-8873-2acb81e9acda; board_b0e66fd7-d45d-4947-b562-cade34a63816; board_797cec2f-9af4-4482-aaef-5a1f8b58f7a9; board_a12325fe-6b85-4200-ac17-6e433675a708",
    retention.R = "board_f936fd71-cedd-4964-a269-2680f2fdbeef",
    rebuild.R = "board_f64a7131-112a-4c78-9f9a-3c89196de1e1; board_0cd43cea-ad7b-4a21-9650-36c1f5bb7f72",
    reference_copy.R = "R/reference_copy.R; tests/testthat/test-reference-copy-pilot.R; bounded source/assertion review only, final frozen-source full-suite log required")
  evidence$evidence_reference <- paste(evidence$evidence_reference,
    "Module auditor attestation:", provenance[inventory$module])
  evidence$efficiency_evidence <- paste(
    "No site-specific efficiency claim. Shared immutable-baseline benchmark:",
    "dev/benchmark-audit.R; 114 measurements/3 repeats/seed20261015/R4.5.2 Windows;",
    "C:/Users/wb384996/AppData/Local/Temp/2/kilo/stamp-benchmark-6c4c61eb250e/measurements.txt; not assertion evidence")
  evidence$lifecycle_recommendation <- "Retain current API/implementation; no removal implemented"
  evidence$recommendation_reason <- "Role supports artifact-store or adjacent schema contract"
  evidence$replacement <- "none proposed"
  evidence$usage_evidence <- ifelse(nzchar(inventory$callers),
    inventory$callers, "No static caller found; dynamic/external use not ruled out")
  evidence$compatibility_impact <- "No API removal, hash rule change or store migration implemented"
  evidence$migration_sequence <- "No migration proposed for supported behavior"

  source_lines <- lapply(unique(inventory$file), function(file) {
    readLines(file.path(root, file), warn = FALSE)
  })
  names(source_lines) <- unique(inventory$file)
  assertion_links <- function(selected) {
    links <- character()
    for (j in selected) {
      lines <- readLines(file.path(root, tests$file[j]), warn = FALSE)
      indices <- seq.int(tests$line_start[j], tests$line_end[j])
      at <- indices[grepl("\\bexpect(_[[:alnum:]_]+)?\\s*\\(", lines[indices])]
      links <- c(links, paste0(tests$file[j], ":", tests$line[j], " ",
        tests$label[j], " [assertions ", paste(at, collapse = ","), "]"))
    }
    return(paste(links, collapse = "; "))
  }
  for (i in seq_len(nrow(inventory))) {
    row <- inventory[i, ]
    owner <- if (top[i]) row$name else row$top_owner_name
    entry <- map[[match(owner, keys)]]
    patterns <- paste(entry[-c(1L, 2L)], collapse = "|")
    intended <- paste0("test-audit-", module_test[row$module], ".R")
    eligible <- grepl(intended, tests$file, fixed = TRUE)
    if (row$module == "format_registry.R") eligible <- eligible |
      grepl("test-format-", tests$file, fixed = TRUE)
    if (row$module == "version_store.R") eligible <- eligible |
      grepl("test-catalog-query.R", tests$file, fixed = TRUE)
    if (owner %in% c("st_restore", "st_switch", "st_add_pk", "st_load")) {
      eligible <- eligible | grepl("test-audit-versions.R", tests$file, fixed = TRUE)
    }
    if (owner %in% c("st_restore", "st_load", ".st_resolve_version_identifier",
                      ".st_resolve_version")) {
      eligible <- eligible | grepl("test-restore-selectors.R", tests$file,
                                    fixed = TRUE)
    }
    if (row$module == "IO_core.R") eligible <- eligible |
      grepl("test-alias", tests$file, fixed = TRUE) |
      grepl("test-should-save.R", tests$file, fixed = TRUE) |
      grepl("test-audit-state-schema.R", tests$file, fixed = TRUE)
    if (row$module == "partitions.R") eligible <- eligible |
      grepl("test-write-parts.R", tests$file, fixed = TRUE)
    callback_cases <- c(
      .st_make_abs = "absolute path fallback returns",
      st_save = "new divergence diagnostics preserve quiet-save",
      st_load = "current loader error callbacks",
      st_alias_list = "alias list maps configured",
      .st_resolve_version_identifier = "restore selector helper preserves explicit",
      st_should_save = "save decision metadata failures",
      st_opts = "option messages report exact",
      st_read_sidecar = "sidecar normalization failure retains",
      st_lineage = "lineage sidecar read failures")
    if (owner %in% names(callback_cases)) {
      eligible <- eligible | grepl("test-audit-callbacks.R", tests$file,
                                    fixed = TRUE)
      patterns <- paste(patterns, callback_cases[[owner]], sep = "|")
    }
    null_cases <- c(
      st_changed = "explicit NULL content|native NULL replacements|NULL is distinct|omitted wrapper|omitted forwarding",
      st_should_save = "explicit NULL content|native NULL replacements|fresh native NULL|omitted wrapper|omitted forwarding",
      st_changed_reason = "explicit NULL content|native NULL replacements|omitted wrapper|omitted forwarding",
      st_save = "native NULL replacements|fresh native NULL|NULL table writes|optional FST NULL",
      st_restore = "native NULL replacements",
      st_load = "native NULL replacements|fresh native NULL|NULL is distinct",
      st_load_version = "native NULL replacements|fresh native NULL",
      .st_rds_read = "native NULL replacements",
      .st_rds_write = "native NULL replacements",
      .st_read_qs2 = "native NULL replacements",
      .st_write_qs2 = "native NULL replacements",
      .st_csv_write = "NULL table writes",
      .st_parquet_write = "NULL table writes",
      .st_fst_write = "optional FST NULL")
    if (owner %in% names(null_cases)) {
      eligible <- eligible | grepl("test-null-objects.R", tests$file, fixed = TRUE)
      patterns <- paste(patterns, null_cases[[owner]], sep = "|")
    }
    key_cases <- c(
      .st_data_table_key = "native loads preserve only keys|unkeyed sorted inputs|key-only changes",
      .st_recorded_data_table_key = "native loads preserve only keys|key-only changes|legacy missing descriptors|key descriptors are validated",
      .st_restore_data_table_key = "native loads preserve only keys|unkeyed sorted inputs|recorded keys do not|key descriptors are validated|known-unkeyed metadata|key validation distrusts|native keys retain|empty keyed tables",
      st_save = "native loads preserve only keys|unkeyed sorted inputs|key-only changes|empty keyed tables",
      st_load = "native loads preserve only keys|unkeyed sorted inputs|legacy missing descriptors|key descriptors are validated|known-unkeyed metadata|native keys retain",
      st_load_version = "native loads preserve only keys|key-only changes|legacy missing descriptors|known-unkeyed metadata|native keys retain",
      st_restore = "key-only changes",
      st_changed = "key-only changes",
      st_should_save = "key-only changes|legacy missing descriptors",
      st_changed_reason = "key-only changes",
      st_add_pk = "live primary-key annotation preserves")
    if (owner %in% names(key_cases)) {
      eligible <- eligible | grepl("test-data-table-keys.R", tests$file, fixed = TRUE)
      patterns <- paste(patterns, key_cases[[owner]], sep = "|")
    }
    reference_cases <- c(
      .st_reference_copy_for_save = "native RDS save uses one owned copy|copy preserves cycles|special roots and binding|special parent boundaries|promises and active|opaque bindings|unsafe nested environments|atomic attributes|non-native formats|graph node and depth|serialization failures|ordinary locked environment",
      st_opts_init_defaults = "reference copy defaults",
      .st_opts_validate = "reference copy defaults",
      st_opts = "reference copy defaults",
      st_opts_reset = "reference copy defaults",
      st_save = "native RDS save uses one owned copy|copy preserves cycles|unchanged copies skip|default off and direct hashing|non-environment saves|default-off classed|special roots and binding|promises and active|opaque bindings|unsafe nested environments|atomic attributes|non-native formats|normal validation precedes|graph node and depth|serialization failures|ordinary locked environment",
      st_should_save = "native RDS save uses one owned copy|unchanged copies skip",
      st_sanitize_for_hash = "native RDS save uses one owned copy|default off and direct hashing|default-off classed",
      st_hash_obj = "default off and direct hashing",
      st_changed = "default off and direct hashing")
    reference_cases[c(".st_reference_copy_for_save", "st_save")] <- paste(
      reference_cases[c(".st_reference_copy_for_save", "st_save")],
      "namespace marker bindings|counterfeit namespace and package|ordinary missing and empty environment names",
      sep = "|")
    reference_cases[["st_save"]] <- paste(reference_cases[["st_save"]],
      "data frame environments", sep = "|")
    if (owner %in% names(reference_cases)) {
      eligible <- eligible | grepl("test-reference-copy-pilot.R", tests$file,
                                    fixed = TRUE)
      patterns <- paste(patterns, reference_cases[[owner]], sep = "|")
    }
    selected <- which(grepl(patterns, tests$label, ignore.case = TRUE) & eligible)
    evidence$responsibility[i] <- entry[2L]
    lines <- source_lines[[row$file]]
    # A nearby roxygen block is provenance, not a substitute for a contract.
    previous <- if (row$line_start > 1L) {
      seq.int(max(1L, row$line_start - 160L), row$line_start - 1L)
    } else integer()
    doc <- previous[grepl("^#'", lines[previous])]
    evidence$stated_contract[i] <- if (top[i] && length(doc) &&
        max(doc) >= row$line_start - 3L) {
      paste0("Roxygen contract ", row$file, ":", max(doc),
        " (preceding block): ", entry[2L],
        "; bounded by documented failure policy and compatibility gates")
    } else paste0("Explicitly internal inferred contract: ", entry[2L],
                  "; inferred from current body/callers, not a new public guarantee")
    evidence$expected_value_source[i] <- paste(
      "Expected contract:", entry[2L], ".",
      "Module auditor's hand-built fixtures and independent invariants in linked",
      "assertions; native one-direction readers/writers for formats; literal",
      "expected values/schema/IDs/edges rather than coverage or symbol counts")
    evidence$relevant_branches[i] <- paste0(entry[2L], "; cases: ",
      if (length(selected)) paste(tests$label[selected], collapse = "; ") else
        "No matching assertion case in supplied final test inventory")
    evidence$residual_limitations[i] <- paste(module_gaps[row$module],
                                              run_limit, sep = "; ")
    links <- assertion_links(selected)
    if (top[i]) {
      evidence$tests_and_assertions[i] <- if (nzchar(links)) links else paste0(
        "BLOCKER: no curated assertion case found for ", row$name,
        "; add direct result and failure assertions for ", entry[2L])
      evidence$exercise[i] <- if (nzchar(links)) {
        "Reviewed direct/owner integration cases; aggregate log is separate execution evidence"
      } else "No behavioral exercise established"
      if (nzchar(links)) {
        evidence$testing_confidence[i] <- "partial"
        if (observed) {
          evidence$functional_status[i] <- "verified in tested scenarios"
          evidence$observed_result[i] <- "passed"
        }
      }
    } else {
      body_lines <- lines[seq.int(row$line_start, row$line_end)]
      last <- length(body_lines)
      body_lines[last] <- substr(body_lines[last], 1L, row$column_end)
      body_lines[1L] <- substring(body_lines[1L], row$column_start)
      body <- paste(trimws(body_lines), collapse = " ")
      evidence$responsibility[i] <- paste0("Within ", owner, ", ",
        row$site_role, " ", row$signature, " executes source body: ", body)
      evidence$stated_contract[i] <- paste0(
        "Explicitly internal inferred callback contract in ", owner,
        ": execute the recorded body for its supplied arguments; preserve owner ",
        "return/failure policy. No independent public callback guarantee.")
      evidence$expected_value_source[i] <- paste0(
        "Owner hand-built fixtures are candidate evidence only; callback-specific ",
        "result or error expectation must be identified for body: ", body)
      evidence$tests_and_assertions[i] <- paste0(
        "BLOCKER: no callback-specific assertion attribution completed for ",
        row$site_id, " (", owner, "). Required branch/result: ", body,
        if (nzchar(links)) paste0(". Candidate owner assertions, NOT verified ",
                                 "inheritance: ", links) else "")
      evidence$exercise[i] <- "Owner candidates only; callback branch execution not established"
      evidence$relevant_branches[i] <- paste0(
        "Required callback body/result/error branch attribution: ", body)
      evidence$residual_limitations[i] <- paste(
        "Missing callback-specific assertion and execution attribution;",
        evidence$residual_limitations[i])
    }
  }

  # Callback attribution is explicit and body/owner-specific. These records
  # identify actual asserted outcomes reported by auditors, not owner promotion.
  nested_map <- c(
    ".st_reference_copy_for_save|function(reason)|Abort unsupported pilot input with structured error rather than save fallback|special roots and binding|Special roots/binding values produce stamp_reference_copy_unsupported before sanitizer/hash/metadata evaluation; caller attributes and existing file MD5s unchanged|decline",
    ".st_reference_copy_for_save|function(env)|Recognize registered special environment identities without reading input bindings|special roots and binding|Global/base/empty/namespace/package roots or binding values rejected; actual special parents retained; injected distinct system-root copy rejected before sanitizer/hash|special",
    ".st_reference_copy_for_save|function(value, depth = 0L, parent_boundary = FALSE)|Preflight graph values attributes ordinary parents cycles and resource limits without forcing unsafe bindings|copy preserves cycles|Exact cycle/shared-child/ordinary-parent alias identities preserved; namespace/package markers and unsupported graphs rejected before serialization; active/lazy marker counters remain zero on roots children and parents|visit",
    ".st_reference_copy_for_save|function(e)|Translate serialization failure into structured pilot rejection before ordinary save fallback|serialization failures|Injected serialize failure throws stamp_reference_copy_unsupported with unchanged caller attributes and no store files; retained-root unserialize rejection asserted separately|<anonymous>",
    ".st_make_abs|function(e)|Return the lexical path after absolute-path failure|absolute path fallback returns|Injected fs::path_abs error returns exact relative-file.rds, not an unintended new absolute path",
    "st_alias_list|function(a)|Map valid or NULL alias configuration into one typed row|alias list maps configured|Exact configured/NULL row values and column types, with independent root/.state literals",
    "st_should_save|function(e)|Treat corrupt metadata read as unavailable save-decision metadata|save decision metadata failures|Established corrupt JSON throws on direct read, decision equals list(save=TRUE,reason=missing_meta), original integer payload unchanged",
    "st_opts|function(x)|Format each reported option setting value|option messages report exact|Message includes exact quoted rds and FALSE values in supplied order; getters return exact changed values",
    "st_lineage|function(e)|Treat failed first-level sidecar fallback as absent edges|lineage sidecar read failures|Injected sidecar failure yields exact typed empty edge data.frame and unchanged latest ID",
    ".st_detect_alias_from_path|function(alias_name)|Evaluate candidate-root match and length|alias helpers match|Longest inner root wins; sibling and NULL-config aliases do not match",
    ".st_wrap_reader|function(path, verbose = TRUE, ...)|Invoke captured reader and respect warning suppression|returned reader and writer wrappers|Exact forwarded argument result plus propagated read error; messages remain visible; verbose FALSE suppresses warnings in test-format-wrappers.R",
    ".st_wrap_writer|function(x, path, verbose = TRUE, ...)|Invoke captured writer and respect warning suppression|returned reader and writer wrappers|Exact forwarded writer result plus propagated write error; messages remain visible; verbose FALSE suppresses warnings in test-format-wrappers.R",
    ".st_write_sidecar|function(x, path)|Write JSON metadata into staged path|all metadata representation transitions|Independent jsonlite readback equals new metadata and failed promotion retains old bytes",
    "st_read_sidecar|function(e)|Handle failed logical-path or QS2 metadata read|corrupt and divergent metadata|Corrupt QS2 with valid JSON warns and returns exact JSON value; invalid metadata failures remain visible",
    "st_changed|function(e)|Turn malformed sidecar into missing metadata change reason|change detection reports independent|Malformed JSON produces exact missing_meta reason rather than an accidental success",
    ".st_is_named_scalar_list|function(z)|Check each partition value is scalar atomic|partition helper keys|Scalar factor accepted; vector and nested list rejected",
    ".st_key_normalize|function(z)|Coerce scalar partition key and reject path separators|partition helper keys|Sorted string keys equal literal expected values; slash and equals values error",
    ".st_match_filter|function(e)|Convert failed partition expression evaluation to nonmatch|partition helper keys|Absent-variable expression returns FALSE; invalid length NA and nonlogical results return FALSE",
    "st_write_parts|function(e)|Report failed key/backend save without claiming successful manifest|unloadable partition keys|Invalid key emits warning and yields no successful manifest; failed writer is visible",
    "st_write_parts|function(r)|Extract per-partition key path version or row count into manifest|sparse data.frame and data.table|Exact sparse manifest key lists, readable paths, nonempty IDs and n_rows 1 plus 2; source body identifies each distinct extracted field",
    "st_list_parts|function(g)|Discover candidate payloads for registered glob|custom filenames|Native custom-named file appears while sidecar/version payload copies do not",
    "st_list_parts|function(p)|Build one discovered partition row from physical payload path|custom filenames|Exact logical custom filename path and independently read native payload",
    "st_list_parts|function(r)|Extract discovered row path or key field for listing|custom filenames|Exact simple-key values and paths; heterogeneous missing-key fill branch not asserted",
    "st_load_parts|function(e)|Abort with partition identity when a payload read fails|unreadable and missing listed|Corrupt and deleted payload cannot disappear as partial successful rows",
    "st_load_parts|function(a, b)|Combine tables by name or retain non-table elements|partition binding unions|Exact unioned rows and columns; non-table objects retained as list",
    "st_prune_versions|function(p)|Normalize each selected prune path without filtering persisted catalog|multiple scoped paths|Only selected artifact/alias versions pruned; unrelated catalog and snapshot bytes identical",
    "st_prune_versions|function(e)|Retain catalog row when snapshot deletion fails|partial snapshot deletion|Injected failed directory remains with catalog record while successful deletion removes only its row",
    "st_builders|function(rec)|Convert registered builder record into listed row|builder registration|Exact three sorted path/name records and replacement without extra row",
    ".st_committed_parents_latest|function(i)|Convert committed parent table row into descriptor|parent readers normalize|Injected data.frame produces exact descriptor list; absent and empty give list()",
    ".st_sidecar_parents|function(e)|Treat failed sidecar read as unavailable fallback parents|parent readers normalize|Injected sidecar error returns list()",
    ".st_sidecar_parents|function(i)|Convert live sidecar parent table row into descriptor|parent readers normalize|Exact list descriptors for injected table and list() for empty table",
    ".children_of|function(e)|Treat failed child query as empty child-path vector|parent readers normalize|Injected query error returns character(); duplicate paths deduplicated",
    "st_rebuild|function(path, allow_sidecar_fallback = TRUE)|Choose committed parents then level-eligible sidecar fallback|rebuild sidecar fallback|Level1 fallback versus level2 no fallback and exact refreshed latest parent IDs|get_parents_for",
    "st_rebuild|function(p)|Refresh parent descriptor with latest committed version|rebuild sidecar fallback|Saved metadata contains exact fresh committed parent IDs|<anonymous>",
    "st_rebuild|function(p)|Resolve explicit function or registered artifact builder|rebuild failures|Missing builder produces exact failed cause; explicit and registered paths yield exact saved outputs|resolve_builder",
    "st_rebuild|function(e)|Capture builder lookup execution or save error into failed result|rebuild failures|Missing lookup, thrown builder and thrown save each return exact failure cause and NA version ID; source body distinguishes three stages",
    "st_plan_rebuild|function(p)|Normalize artifact path used by planner graph comparisons|rebuild plans cover|Exact chain/diamond/unequal-depth/multiple-root plan paths and levels|norm",
    "st_plan_rebuild|function(child)|Select descendant based on committed or eligible live parents|rebuild plans cover|Strict only stale child; propagated chain and unequal-depth DAG all scheduled once; parentless sidecar excluded",
    "st_plan_rebuild|function(i)|Normalize tabular fallback parent row for stale predicate|rebuild sidecar fallback|Injected data.frame parents yields exact B,D plan, excluding parentless C",
    "st_plan_rebuild|function(pp)|Normalize parent path before scheduled-parent intersection|rebuild plans cover|Diamond/unequal-depth plan promotes dependent only after every scheduled parent",
    "st_plan_rebuild|function(p)|Build scheduled dependency set for topological promotion|rebuild plans cover|Unequal-depth D follows E, exact B1 C1 E2 D3 expected levels|<anonymous>",
    "st_plan_rebuild|function(pars)|Choose dependency-ready scheduled nodes or detect no-ready cycle|rebuild plans cover|DAG dependency order exact; Inf cycle terminates uniquely without inventing cycle execution order",
    "st_inspect_pk|function(e)|Recover invalid path or corrupt metadata as absent PK|PK inspection failure|NA path and corrupt JSON return character() exactly",
    "st_add_pk|function(e)|Recover invalid path or rebuild corrupt live metadata|PK inspection failure|NA path gives structured error; corrupt JSON repair returns exact requested keys",
    "st_versions|function(x)|Unwrap singleton timestamp representation|version ordering handles|Exact tie order and singleton/plain timestamps; malformed shapes remain partial",
    "st_load_version|function(e)|Recover corrupt snapshot metadata or unavailable verification digest|historical verification|Corrupt metadata fallback fixture returns exact RDS object; digest-error callback attribution still incomplete",
    "st_lineage|function(child_path, child_vid, level)|Walk committed parent edges recursively|lineage and children return|Relative and absolute chain edges and levels equal independently specified table",
    ".st_catalog_record_version|function(p)|Construct parent-index row for one normalized parent|catalog upsert append|Exact parent and child version/artifact IDs match independent SipHash formula",
    ".st_version_read_parents|function(e)|Warn and return empty parents for corrupt JSON|parent normalization and snapshots|Corrupt descriptor emits expected warning and returns list()",
    ".st_parents_normalize|function(i)|Convert parent data.frame row to descriptor|parent normalization and snapshots|Exact normalized descriptors for data.frame fixture",
    ".st_parents_normalize|function(z)|Keep only parent descriptors with required fields|parent normalization and snapshots|Mixed valid and missing-field descriptors produce exact expected retained list",
    ".st_children_once|function(i)|Convert indexed child row to resolved child descriptor|children traversal terminates|Indexed cycle returns exact child identities; unresolved-child skip branch still missing",
    "st_children|function(df, level)|Add unique child rows with traversal level|lineage and children return|Exact child paths IDs and levels; cycle rows emitted once",
    "st_children|function(p_path_abs, p_vid, level)|Expand reverse graph with bounded depth and cycle guard|children traversal terminates|Infinite-depth cycle terminates with exact unique children; unequal-depth convergence has independent four-child and Zlevel3 assertion",
    "st_extmap_report|function(e)|Map extension binding to format or missing marker|extension defaults seed|Removed CSV reports NA; custom RDS remains and reseeding restores CSV"
  )
  for (record in strsplit(nested_map, "|", fixed = TRUE)) {
    at <- which(!top & inventory$top_owner_name == record[1L] &
                  inventory$signature == record[2L])
    if (length(record) >= 6L) at <- at[inventory$name[at] == record[6L]]
    if (record[1L] == "st_read_sidecar") {
      at <- at[grepl("source body: function(e) e", evidence$responsibility[at],
                    fixed = TRUE)]
    }
    if (record[1L] == "st_load_version") next
    selected <- which(grepl(record[4L], tests$label, ignore.case = TRUE))
    if (record[1L] == ".st_reference_copy_for_save") {
      callback_cases <- c(
        decline = "special roots and binding|non-native formats|opaque bindings|serialization failures|namespace marker bindings|counterfeit namespace and package",
        special = "special roots and binding|special parent boundaries|counterfeit namespace and package",
        visit = "copy preserves cycles|special parent boundaries|promises and active|opaque bindings|unsafe nested environments|atomic attributes|graph node and depth|ordinary locked environment|namespace marker bindings|counterfeit namespace and package|ordinary missing and empty environment names",
        "<anonymous>" = "serialization failures")
      selected <- which(grepl(callback_cases[[record[6L]]], tests$label,
                              ignore.case = TRUE) &
        grepl("test-reference-copy-pilot.R", tests$file, fixed = TRUE))
    }
    links <- assertion_links(selected)
    for (i in at) {
      evidence$responsibility[i] <- paste(record[3L], "within", record[1L],
                                         ";", evidence$responsibility[i])
      evidence$expected_value_source[i] <- paste(
        "Independent asserted callback outcome:", record[5L])
      evidence$tests_and_assertions[i] <- paste(record[5L], links, sep = "; ")
      evidence$exercise[i] <- "Specific callback outcome asserted through owner; not automatic owner inheritance"
      evidence$testing_confidence[i] <- "partial"
      evidence$residual_limitations[i] <- paste(
        "Only enumerated callback outcome attributed; other body/error branches",
        "not exhaustively mapped;", module_gaps[inventory$module[i]], run_limit)
      # Identical error signatures can cover multiple different catch sites;
      # retain ambiguity until each catch is distinguished by body and assertion.
      distinct <- length(at) == 1L || record[1L] %in%
        c("st_inspect_pk", "st_add_pk")
      if (observed && nzchar(links) && distinct) {
        evidence$functional_status[i] <- "verified in tested scenarios"
        evidence$observed_result[i] <- "passed"
      }
    }
  }
  at <- which(!top & inventory$top_owner_name == "st_read_sidecar" &
    grepl("source body: function(e) NULL", evidence$responsibility, fixed = TRUE))
  for (i in at) {
    selected <- which(grepl("sidecar normalization failure retains", tests$label,
                             ignore.case = TRUE))
    evidence$responsibility[i] <- paste(
      "Recover absolute-path normalization failure as no normalized descriptor;",
      evidence$responsibility[i])
    evidence$expected_value_source[i] <- paste(
      "Supported absolute missing path established first; injected normalizer",
      "throws; missing metadata still returns NULL. No existing-outside-root read contract selected.")
    evidence$tests_and_assertions[i] <- paste(
      evidence$expected_value_source[i], assertion_links(selected))
    evidence$exercise[i] <- "Normalization catch induced separately from corrupt-QS2 catch"
    evidence$testing_confidence[i] <- "partial"
    evidence$residual_limitations[i] <- paste(
      "Only missing-file recovery after injected failure observed; existing-file/alias-boundary failure semantics remain unspecified;",
      run_limit)
    if (observed && length(selected)) {
      evidence$functional_status[i] <- "verified in tested scenarios"
      evidence$observed_result[i] <- "passed"
    }
  }
  at <- which(!top & inventory$top_owner_name == "st_load_version" &
                inventory$signature == "function(e)")
  for (i in at) {
    lines <- source_lines[[inventory$file[i]]]
    context <- paste(lines[seq.int(max(1L, inventory$line_start[i] - 10L),
                                   inventory$line_start[i])], collapse = " ")
    metadata <- grepl("function(e) NULL", evidence$responsibility[i], fixed = TRUE)
    role <- if (metadata) "Recover corrupt snapshot sidecar as absent metadata" else
      if (grepl("st_hash_file(art)", context, fixed = TRUE)) {
        "Recover file verification hash error as unavailable digest"
      } else "Recover object verification hash error as unavailable digest"
    pattern <- if (metadata) "legacy snapshots without" else "historical verification"
    selected <- which(grepl(pattern, tests$label, ignore.case = TRUE))
    evidence$responsibility[i] <- paste(role, ";", evidence$responsibility[i])
    evidence$stated_contract[i] <- paste(
      "Explicitly internal inferred compatibility contract:", role,
      "; do not turn unavailable optional metadata/digest into unreadable payload")
    evidence$expected_value_source[i] <- if (metadata) {
      "One-direction raw-RDS fixture reads exactly 42L after corrupt JSON or nonlist snapshot metadata"
    } else paste(
      "Injected file/object hash errors return exact historical 99L with no",
      "false mismatch warnings; independent raw-RDS fixture")
    evidence$tests_and_assertions[i] <- paste(evidence$expected_value_source[i],
                                            assertion_links(selected), sep = "; ")
    evidence$exercise[i] <- "Callback-specific corruption/hash-error injection asserted through historical reader"
    evidence$testing_confidence[i] <- "partial"
    evidence$residual_limitations[i] <- paste(
      "Identified recovery outcome tested; all corrupt metadata/backend/error",
      "permutations not established;", run_limit)
    if (observed && length(selected)) {
      evidence$functional_status[i] <- "verified in tested scenarios"
      evidence$observed_result[i] <- "passed"
    }
  }

  for (i in which(!top & inventory$top_owner_name == "st_load" &
                   inventory$signature == "function(e)")) {
    lines <- source_lines[[inventory$file[i]]]
    context <- paste(lines[seq.int(max(1L, inventory$line_start[i] - 8L),
                                   inventory$line_start[i])], collapse = " ")
    role <- if (grepl("st_hash_file", context, fixed = TRUE)) {
      "Recover unavailable live file digest without a false mismatch"
    } else if (grepl("st_hash_obj", context, fixed = TRUE)) {
      "Recover unavailable live object digest without a false mismatch"
    } else "Recover corrupt current sidecar metadata as absent annotations"
    selected <- which(grepl("current loader error callbacks", tests$label,
                             ignore.case = TRUE))
    evidence$responsibility[i] <- paste(role, "within st_load;",
                                        evidence$responsibility[i])
    evidence$expected_value_source[i] <- paste(
      "Independent native integer payload and explicit sanitation markers;",
      "actual corruption/mock precondition checked; expected readable result 11L without warning")
    evidence$tests_and_assertions[i] <- paste(role, assertion_links(selected))
    evidence$exercise[i] <- "Each metadata/file-digest/object-digest failure induced independently"
    evidence$testing_confidence[i] <- "partial"
    evidence$residual_limitations[i] <- paste(
      "Scalar RDS recovery observed; every data class/backend/hash/sidecar error combination unverified;",
      run_limit)
    if (observed && length(selected)) {
      evidence$functional_status[i] <- "verified in tested scenarios"
      evidence$observed_result[i] <- "passed"
    }
  }

  # New save catches retain distinct decision/fallback policies. Attribute them
  # by source body, never by their shared function(e) signature alone.
  for (i in which(!top & inventory$top_owner_name == "st_save")) {
    body <- evidence$responsibility[i]
    decision <- grepl("decision_error <<- e", body, fixed = TRUE)
    writer <- grepl("writer_formals", body, fixed = TRUE)
    fallback <- grepl("Save failed for", body, fixed = TRUE)
    if (!decision && !writer && !fallback) next
    pattern <- if (decision) "decision errors still propagate" else
      if (writer) "custom registration" else "failed save boundaries"
    role <- if (decision) {
      "Remember and rethrow change-detection errors despite the write fallback"
    } else if (writer) {
      "Forward accepted named writer arguments and serialize staged output"
    } else "Return the existing warning/fallback result after a write failure"
    outcome <- if (decision) {
      "Injected decision failure propagates; payload absent and catalog empty"
    } else if (writer) {
      "Custom handler requires forwarded arguments and native saved values match"
    } else {
      "Injected writer/metadata/snapshot/catalog failures return no version and preserve committed history"
    }
    selected <- which(grepl(pattern, tests$label, ignore.case = TRUE))
    evidence$responsibility[i] <- paste(role, "within st_save;", body)
    evidence$expected_value_source[i] <- outcome
    evidence$tests_and_assertions[i] <- paste(outcome, assertion_links(selected))
    evidence$exercise[i] <- "Distinct callback-specific error/result assertion"
    evidence$testing_confidence[i] <- "partial"
    evidence$residual_limitations[i] <- paste(
      "Only enumerated callback outcomes; all backend/argument/failure permutations unverified;",
      run_limit)
    if (observed && length(selected)) {
      evidence$functional_status[i] <- "verified in tested scenarios"
      evidence$observed_result[i] <- "passed"
    }
  }
  for (i in which(!top & inventory$top_owner_name == "st_restore" &
                   inventory$signature == "function(e)")) {
    selected <- which(grepl("restore retains legacy format fallback", tests$label,
                             ignore.case = TRUE))
    evidence$tests_and_assertions[i] <- paste(
      "Corrupt snapshot metadata falls back to legacy format: exact restored 11L, current 11L and three version IDs;",
      assertion_links(selected))
    evidence$expected_value_source[i] <- "Independent 11L/22L historical fixture with corrupt JSON"
    evidence$exercise[i] <- "Corrupt-metadata callback explicitly asserted"
    evidence$testing_confidence[i] <- "partial"
    evidence$residual_limitations[i] <- paste(
      "Legacy corruption fixture passes; full malformed-sidecar/backend matrix unverified;", run_limit)
    if (observed && length(selected)) {
      evidence$functional_status[i] <- "verified in tested scenarios"
      evidence$observed_result[i] <- "passed"
    }
  }

  fixed <- c(
    st_sanitize_for_hash = "NULL attribute error fixed without changing previously valid hashes (audit-hashing-probe.R red/green; compatibility 18 object fixtures)",
    .st_restore_sanitized_object = "Caller-owned partially sanitized DT no longer mutated during marker cleanup (hashing probe red/green)",
    .mirror_opts_to_base = "Wrong environment caused missing mirrors; actual option env now mirrored (state-audit-probe.R red/green)",
    .onUnload = "Initially absent CLI theme now restored to NULL (state-audit-probe.R red/green)",
    st_pk = "NA key name rejection fixed (state-audit-probe.R red/green)",
    st_filter = "NA filter name rejection fixed for strict TRUE/FALSE (state-audit-probe.R red/green)",
    .st_write_atomic = "Removed delete-before-promotion; writer/promotion failures preserve old destination and clean staged file (parent IO red/green)",
    st_save = "Completed snapshot precedes catalog publication; failed writer/sidecar/snapshot/catalog keeps history readable. Decision reads hold artifact lock, preventing observed Windows EPERM race; decision errors still propagate. Baseline quiet policy preserved after new divergence diagnostics (audit-quiet-save.R intermediate red/current green)",
    .st_with_lock = "NULL timeout result now aborts before critical expression; real timeout and two-writer tests (parent IO red/green)",
    st_load = "Absent NA QS2 file_hash no longer warns as false mismatch; verbose FALSE suppresses package sidecar warnings (parent independent missing-filehash probe)",
    st_restore = "Explicit failed save cannot report restore success; recorded snapshot format used (parent/version integration assertions)",
    .st_write_sidecar = "Transitions retire stale opposite metadata only after publish; per-format promotion preserves old bytes and cleans temps (formats 10-invariant baseline/current probes)",
    st_read_sidecar = "Divergent/corrupt dual QS2 warns while preserving JSON authority (formats baseline/current probes)",
    st_load_parts = "Projected reads use physical payload; failed reads abort and warning state stays local, not GlobalEnv (formats baseline/current probes)",
    st_write_parts = "Sparse split drops unused combinations; failed saves cannot return successful manifest (formats baseline/current probes)",
    st_save_part = "Failed underlying save cannot masquerade as successful partition path (formats baseline/current probes)",
    st_list_parts = "Metadata-backed missing current payload remains listed so load cannot silently lose partition rows (formats baseline/current probes)",
    st_load_version = "Historical format and verification use committed metadata with legacy fallback (audit-version-probe.R red/green)",
    .st_resolve_version = "Fractional selectors rejected without truncation (audit-version-probe.R red/green)",
    .st_version_commit_files = "Immutable snapshot overwrite rejected and incomplete staging cleaned (audit-version-probe.R red/green)",
    .st_version_write_parents = "Failed actual promotion preserves committed parents.json and cleans temp (audit-version-probe.R red/green)",
    st_lineage = "Relative/absolute paths normalized per-node alias to avoid recursive PATH_MAX failure (baseline vignette failure; exact chain equivalence assertions)",
    .st_children_once = "Query-only mixed-case parent-ID fallback preserves old identities; canonicalize both path_rel operands so snapshot scans receive exact a.rds/b.rds instead of repeated ../ paths (audit-case-fallback.R original red/current green; CRAN PATH_MAX failures)",
    st_children = "Cycle termination and best expanded depth preserve shorter converging routes; intermediate Boolean-guard regression reproduced against check5, fixed with exact four-child/Zlevel3 regression (version convergence red1/current10PASS)",
    st_catalog_query = "Latest join includes artifact identity; another artifact's version cannot satisfy stale pointer (version probe red/green)",
    st_prune_versions = "Scoped prune preserves unrelated catalog rows/edges/files and only removes successfully deleted snapshots (retention original red/green)",
    .st_normalize_policy = "Invalid fractional/vector retention policy rejected (retention original red/green)",
    .st_parse_utc_times = "Fractional UTC seconds parsed with %OS so fresh versions survive age retention (retention original red/green)",
    st_plan_rebuild = "Propagation retains frontier and strict cycles terminate; chain/unequal-depth DAG outputs asserted (retention/rebuild original red/green)",
    .st_builder_key = "In-memory Windows builder matching normalized without rewriting persisted artifact IDs (retention/rebuild original red/green)")
  for (name in names(fixed)) {
    at <- which(top & inventory$name == name)
    evidence$confirmed_findings[at] <- paste("Reproduced baseline defect, compatible fix:", fixed[[name]])
  }
  specific_gaps <- c(
    .st_make_abs = "Injected fs::path_abs failure returns exact lexical input; real permission/platform filesystem failure matrix unverified",
    .st_opts_validate = "Most supported keys deliberately lack validators; default_format NA and malformed controls require policy, not silent new validation",
    st_opts = "Malformed .get controls/name policy not exhaustive; inert options retained without changing save/path behavior",
    st_pk = "Character keys documented; positional support not introduced. Single NA data key accepted versus duplicate NA rejected; broader NA-row policy unresolved",
    st_with_pk = "DF value/attribute/input-immutability tested; caller-owned DT mutation not directly asserted for this helper",
    st_add_pk = "Live-only semantics explicitly tested: snapshot payload/JSON/QS2 and catalog bytes unchanged; current PK differs from historical original. validate=FALSE coercion/NA policy not redefined",
    st_filter = "DF/DT/factor/NA/empty/strict branches asserted; duplicate filter-name policy unspecified. Retain documented post-load convenience API",
    st_assert_pk = "Malformed externally forged stamp_pk shape not specified; no new validation policy introduced",
    st_register_format = "NA/empty names and malformed extension vectors not exhaustively specified; required custom arguments and replacement exercised",
    .st_extmap_set = "NA extension semantics not specified; normalized dedup/empty omission/unknown-format errors exercised",
    .st_sidecar_path = "Explicit alternate-alias/outside-root error not directly asserted for this resolver",
    .st_is_named_scalar_list = "NA, duplicate and unsafe key-name policy unresolved",
    .st_key_normalize = "NA, unsafe names and key-type collisions unresolved; scalar conversion does not certify round-trip type fidelity",
    .st_key_segments = "Unsafe key names can introduce separators; value validation does not establish key-name traversal policy",
    .st_guess_or_default_format = "Missing valid default failure not injected",
    .st_known_exts = "Builtin enumeration observed; separate custom registered-extension listing oracle not exhaustive",
    .st_file_basename_default = "Exact part.rds result observed; malformed format-name policy inherited from callers, not a partition key-fidelity guarantee",
    .st_parse_key_from_rel = "Large integer 2147483648 overflows then errors in observed baseline probe; FALSE/Inf/date and name-collision typing not certified",
    .st_match_filter = "Captured formula environment discarded: closure cutoff probe misses matching partition; no new expression-environment semantics selected",
    st_part_path = "Invalid key names, traversal, case and type collision policy unresolved",
    st_save_part = "Forwarded PK/domain/parents metadata not directly asserted by partition-owner tests; skipped unchanged path and failed writer differentiated",
    st_write_parts = "Observed base DF NA grouping loses row (2 input to manifest sum1), DT retains 2; key case/type/NA policy unresolved. Automatic >10 progress UI not certified",
    st_list_parts = "Formula closure/case/NA/inaccessible filesystem and heterogeneous-key fill unverified; deleted artifacts without live sidecar cannot be discovered",
    st_load_parts = "Payload-folder key authority/types/case unresolved; NULL-object reader still skipped; missing requested column fallback and fst-unavailable projected matrix unverified",
    .st_catalog_read = "Arbitrary corrupt-object/type validation and supported historical-release catalog matrix not exhaustive",
    .st_catalog_upsert_artifact = "Existing format/path change policy unspecified; data.table reference behavior retained",
    .st_catalog_append_version = "Malformed rows and duplicate version IDs not redefined",
    .st_catalog_record_version = "Timestamp/content collisions retain existing identity formula; snapshot-before-record guarantee belongs to st_save, not this standalone recorder",
    st_versions = "Malformed multi-value/nested NULL timestamps and non-ISO nonempty timestamp strings not exhaustively validated",
    .st_resolve_version = "Interactive picker blocked; canonical 0/-n semantics match restore. Only restore accepts legacy positive positions with migration warnings; loader still rejects positives",
    .st_resolve_version_identifier = "Approved signed selectors and warned positive migration observed; malformed versions-table schemas and final positive-removal release are not certified",
    .st_version_commit_files = "Sidecar/copy/parents-step failure permutations and power-loss recovery not all tested; no transactional/fsync claim",
    .st_version_dir_latest = "Dangling snapshot and malformed ID cases not explicit",
    .st_version_write_parents = "Actual promotion preserves prior bytes; writer/permission failure permutations remain partial",
    .st_parents_normalize = "Malformed field types/lengths retained; relative parent paths resolve against cwd with unclear contract",
    st_load_version = "RDS/custom historical readers, corrupt/nonlist metadata and hash-error fallback tested; all six built-in historical format matrix and keyed-DT restoration incomplete",
    st_lineage = "Injected sidecar fallback failure yields exact empty schema; malformed depth, duplicate parent edges and deleted-parent semantics partial",
    st_children = "Best expansion depth fixes missing-descendant convergence; first-seen output level and historical-child versus latest-child recursion remain unchanged/ambiguous; reverse cross-alias global discovery absent",
    st_is_stale = "Deleted-parent conservative FALSE retained; missing snapshot branch not explicit",
    st_catalog_query = "Malformed duplicate latest rows untested. Plan query-expression operators N/A: API has alias argument only",
    st_rebuild = "Unchanged st_save returns no version_id and rebuild labels failure: no-write invariant tested, success-status policy unresolved; cycle execution order not newly specified")
  for (name in names(specific_gaps)) {
    at <- which(top & inventory$name == name)
    evidence$residual_limitations[at] <- paste(specific_gaps[[name]], run_limit,
                                               sep = "; ")
  }

  # Small complete branch sets are enumerated explicitly, never inferred from
  # expectation count, symbol references, or line coverage.
  complete <- list(
    "%||%" = c("NULL chooses fallback", "FALSE does not evaluate fallback",
                "empty non-NULL value preserved"),
    ".st_is_dt" = c("data.table TRUE", "data.frame FALSE"),
    "st_state_set" = c("named list binding stored", "NULL binding stored"),
    "st_state_get" = c("existing list returned", "absent binding uses default",
                       "existing NULL does not use default"))
  for (name in names(complete)) {
    at <- which(top & inventory$name == name)
    evidence$relevant_branches[at] <- paste(complete[[name]], collapse = "; ")
    evidence$required_scenarios[at] <- as.character(length(complete[[name]]))
    evidence$residual_limitations[at] <- paste(
      "Adequacy limited to explicitly enumerated primitive/binding contract;",
      "does not cover arbitrary forged class/state environments;", run_limit)
    if (observed) {
      evidence$testing_confidence[at] <- "adequate"
      evidence$passing_required_scenarios[at] <- as.character(length(complete[[name]]))
      evidence$blocked_required_scenarios[at] <- "0"
      evidence$unexecuted_required_scenarios[at] <- "0"
    }
  }

  # Concrete unresolved contracts override any bounded passing assertions.
  unresolved <- list(
    st_normalize_attrs = "Locale-sensitive sorting and nested attribute normalization are unresolved persisted hash rules",
    st_sanitize_for_hash = "Sanitized payload intentionally excludes DT keys; native original-key metadata is preserved outside hashes. Environment input can still mutate caller attributes before error; persisted hash changes withheld",
    st_hash_obj = "DT keys intentionally remain outside content hashes with approved metadata-only change detection. Locale/nested-attribute and DT-vs-DF/custom-rowname equivalence remain unresolved; environment mutation unsupported",
    st_hash_code = "Primitive sum/prod share hash because formals/body NULL; captured environment excluded; whitespace normalization semantics unchanged",
    .st_restore_sanitized_object = "Ordinary DT class and rownames restored; original keys handled separately from sidecars. Arbitrary subclass/secondary-index restoration is not specified or certified",
    st_restore = "Selector and native NULL replacement contracts resolved by user approvals. Content-policy no-op/always-append restoration and full live-file/metadata divergence repair remain separate unresolved contracts",
    .st_normalize_user_path = "Observed relative ../ escapes despite equivalent absolute rejection; existing outside junction target rejected but missing junction child remains lexical root path. Alias security boundary decision required",
    .st_prompt_select_version = "Actual interactive selection branches not executed in noninteractive check",
    st_children = "Reverse cross-alias global discovery not established; local catalog traversal is not a global graph index",
    .st_children_once = "Reverse cross-alias global discovery not established; legacy snapshot fallback is query-only compatibility",
    st_rebuild = "Unchanged/no-ID saves labelled failed; continuation after failed upstream builder remains default. No-op/failure-continuation and cycle execution policies unresolved")
  for (name in names(unresolved)) {
    at <- which(inventory$name == name & top)
    evidence$candidate_findings[at] <- unresolved[[name]]
    evidence$residual_limitations[at] <- paste(unresolved[[name]],
      evidence$residual_limitations[at], sep = "; ")
    evidence$functional_status[at] <- "unverified/ambiguous"
    if (name == ".st_prompt_select_version") {
      evidence$testing_confidence[at] <- "blocked"
      evidence$observed_result[at] <- "interactive branch unexecuted"
    }
  }
  at <- which(top & inventory$name %in% c("st_restore",
                                          ".st_resolve_version_identifier"))
  evidence$compatibility_impact[at] <- paste(
    "New 0/-n restore selectors; positive p keeps old selection with a deprecation",
    "warning. Default oldest, exact IDs, hash rules and stored payloads unchanged")
  evidence$migration_sequence[at] <- paste(
    "User approved option 3 on 2026-10-15; replace legacy positive p with 1-p;",
    "retain warnings now and remove positive support only in a future release")
  at <- which(top & inventory$name %in% c("st_changed", "st_changed_reason",
                                          "st_should_save", "st_save"))
  evidence$compatibility_impact[at] <- paste(
    "User-approved explicit NULL comparison/storage; omitted x keeps old behavior.",
    "Callers using explicit x=NULL as a sentinel must omit x instead.",
    "Hash algorithms, IDs, signatures and existing save-failure policy unchanged")
  evidence$migration_sequence[at] <- paste(
    "NULL option 1 approved 2026-10-16; replace sentinel x=NULL with omitted x",
    "in comparison calls; use RDS/QS2 for exact NULL persistence; no store migration")
  at <- which(top & inventory$name %in% c(".st_data_table_key",
    ".st_recorded_data_table_key", ".st_restore_data_table_key", "st_save",
    "st_load", "st_load_version", "st_changed", "st_should_save", "st_changed_reason"))
  evidence$compatibility_impact[at] <- paste(evidence$compatibility_impact[at],
    "Original native DT keys are versioned sidecar metadata only; content hashes",
    "and payload sanitation remain unchanged. Key-only changes add metadata reason",
    "and optional metadata_changed detail; no automatic keys or returned-row sorting")
  evidence$migration_sequence[at] <- paste(evidence$migration_sequence[at],
    "Key option1 approved 2026-10-17; legacy descriptor-absent snapshots load asbefore",
    "without inferred keys. Resaving an originally keyed input captures its descriptor")
  at <- which(!top & inventory$top_owner_name == ".st_prompt_select_version")
  evidence$testing_confidence[at] <- "blocked"
  evidence$observed_result[at] <- "interactive label/menu/cancel branches unexecuted"
  evidence$residual_limitations[at] <- paste(
    "Interactive menu label callback and selection/cancel branches unavailable",
    "in noninteractive check; no fake menu execution claimed;", run_limit)
  at <- which(top & inventory$name == "st_save")
  evidence$exercise[at] <- paste(
    evidence$exercise[at], "Native NULL replacement/restoration, unchanged NULL",
    "skipping, independent raw payload/hash checks and failed table writes",
    "without changing prior bytes are explicitly asserted")
  if (observed) evidence$observed_result[at] <- "passed"
  # Deferral is not itself a functional result: bounded pure format utilities
  # retain their tested status independently of unresolved key/payload semantics.
  pure_partition <- top & inventory$name %in% c(".st_known_exts",
    ".st_guess_or_default_format", ".st_file_basename_default")
  at <- which(inventory$module == "partitions.R" & !pure_partition)
  evidence$functional_status[at] <- "unverified/ambiguous"
  evidence$candidate_findings[at] <- module_gaps["partitions.R"]
  legacy <- c(.st_versions_root = ".st_version_dir(rel_path, version_id, alias)",
    .st_path_matches_alias = ".st_detect_alias_from_path / .st_normalize_user_path after contract comparison",
    .st_extract_rel_path = "rel_path from .st_normalize_user_path after layout compatibility review")
  for (name in names(legacy)) {
    at <- which(inventory$name == name & top)
    evidence$lifecycle[at] <- "legacy candidate"
    evidence$lifecycle_recommendation[at] <- paste(
      "Review and later retire unused internal helper", name,
      "only after docs/external ::: use audit; no deletion implemented")
    evidence$recommendation_reason[at] <- paste(
      "Baseline audit found no executable source/test callers; new audit tests",
      "do not establish production use. Legacy documentation still references helpers")
    evidence$replacement[at] <- legacy[[name]]
    evidence$usage_evidence[at] <- paste(
      "Immutable-baseline R/tests search: definition only; current callers:",
      evidence$usage_evidence[at], "; external ::: usage unknown")
    evidence$compatibility_impact[at] <- paste(
      "Internal removal could break ::: consumers; replacements have different",
      "routing/layout semantics; no store relocation or identity changes")
    evidence$migration_sequence[at] <- paste(
      "Compare contracts and documentation; review external usage; announce",
      "internal deprecation with NEWS; remove only in separately approved release")
  }
  at <- which(inventory$name %in% c("st_opts", ".st_opts_validate",
                                    "st_opts_init_defaults") & top)
  evidence$lifecycle_recommendation[at] <- paste(
    "Retain option APIs. Deprecate inert force_on_code_change and data_folder",
    "only after documenting no-op and warning on explicit set; then remove in",
    "approved release. Do not wire them in: save policy/path identity would change")
  evidence$usage_evidence[at] <- paste(evidence$usage_evidence[at],
    "; baseline force_on_code_change default/validator/docs only; data_folder default/stale docs only; neither read operationally")

  # Keep the default-off pilot bounded even after a passing aggregate run.
  # These scopes are not added to complete: coverage cannot earn adequacy.
  pilot <- which(inventory$module == "reference_copy.R")
  pilot_contracts <- c(
    ".st_reference_copy_for_save" = paste(
      "Internal save-only pilot: native RDS writer identity checked before",
      "preflight; one serialize(version=3)/unserialize copy of a supported",
      "ordinary root environment; detached root required. Cycles and shared",
      "ordinary children/parents retained within that owned graph"),
    decline = paste(
      "Internal rejection path: cli_abort with class",
      "stamp_reference_copy_unsupported and reason; no fallback success or",
      "new default failure policy for other saves"),
    special = paste(
      "Internal identity predicate over actual namespace/attached-package",
      "registry snapshots plus global/base/empty, without input classifiers.",
      "Special roots/binding values rejected; actual parent boundaries stay",
      "shared/uninspected; special copied roots are rejected"),
    visit = paste(
      "Internal bounded preflight: ordinary unclassed environments and",
      "NULL/atomic values with recursively atomic attributes; identity-based",
      "cycle guard, ordinary-parent traversal, active/promise checks before",
      "binding reads; reject unrecognized namespace/package markers without",
      "evaluation and reject opaque/classed/reference-attribute graphs or",
      "over 10000 nodes/64 levels"),
    "<anonymous>" = paste(
      "Internal serialization catch: preserve error context through structured",
      "unsupported-input decline, before ordinary save fallback"))
  for (i in pilot) {
    evidence$stated_contract[i] <- pilot_contracts[[inventory$name[i]]]
    evidence$testing_confidence[i] <- "partial"
    evidence$residual_limitations[i] <- paste(
      module_gaps["reference_copy.R"],
      "Special-parent identity assertions are not a detached snapshot of their",
      "contents; shared parents can change. Exact accepted node/depth limits",
      "and all serialization error permutations not exhaustively asserted;",
      run_limit)
    evidence$lifecycle_recommendation[i] <- paste(
      "Retain only the explicitly limited default-off native-RDS save pilot;",
      "do not advertise generic reference copying or enable by default")
    evidence$recommendation_reason[i] <- paste(
      "Isolates supported caller-owned root environments during opted-in saves",
      "without redefining persisted hash semantics or other API behavior")
    evidence$compatibility_impact[i] <- paste(
      "Opt-in only; unsupported environment graphs reject before metadata",
      "capture/sanitization/save writes. Non-environment/default-off saves and",
      "direct hashing/change detection retain existing behavior and limitations")
    evidence$migration_sequence[i] <- paste(
      "No store migration; retain reference_copy_on_save=FALSE by default.",
      "Broader formats/graphs or a new default require separate approval")
    evidence$efficiency_evidence[i] <- paste(
      "One helper invocation and owned-object identity asserted for the native",
      "RDS fixture; no elapsed-time/allocation benchmark or generic copy-cost claim")
    evidence$evidence_reference[i] <- paste(
      evidence$evidence_reference[i],
      "Pilot assertions reviewed in tests/testthat/test-reference-copy-pilot.R;",
      "execution evidence must come from the final frozen-source full-suite log")
    if (!nzchar(assertion_links(which(grepl("test-reference-copy-pilot.R",
        tests$file, fixed = TRUE))))) {
      evidence$functional_status[i] <- "unverified/ambiguous"
      evidence$observed_result[i] <- "pilot assertions absent from final inventory"
    }
  }
  at <- which(top & inventory$name == ".st_reference_copy_for_save")
  marked <- which(inventory$module == "reference_copy.R" &
    inventory$name %in% c(".st_reference_copy_for_save", "special", "visit"))
  evidence$confirmed_findings[marked] <- paste(
    evidence$confirmed_findings[marked],
    "Independent review reproduced active .__NAMESPACE__. execution in the",
    "intermediate classifier. Fixed with registry-identity classification,",
    "nonforcing counterfeit-marker rejection and copied-system-root guard.",
    "Root/child/parent counter-zero, zero-serialization and no-file assertions",
    "are linked to the final observed suite; broader reference safety remains partial")
  evidence$expected_value_source[at] <- paste(
    "Literal native readRDS payload 1:3; exactly one helper call and identical",
    "owned object at decision/sanitizer boundaries; caller serialization and",
    "attributes unchanged; legacy native-RDS fixture content hash equality is",
    "a bounded compatibility comparison, not an independent hash oracle")
  option_sites <- which(top & inventory$name %in% c("st_opts_init_defaults",
    ".st_opts_validate", "st_opts", "st_opts_reset"))
  evidence$stated_contract[option_sites] <- paste(
    evidence$stated_contract[option_sites],
    "Pilot option reference_copy_on_save defaults/resets to FALSE; setter",
    "accepts only length-one non-NA logical; invalid multi-option update is atomic")
  evidence$residual_limitations[option_sites] <- paste(
    evidence$residual_limitations[option_sites],
    "Pilot defaults/validation assertions do not certify all option controls",
    "or generic reference safety; pilot confidence remains partial")
  evidence$testing_confidence[option_sites] <- "partial"
  at <- which(top & inventory$name == "st_save")
  evidence$stated_contract[at] <- paste(evidence$stated_contract[at],
    "After ordinary path/PK/format validation, only an environment root with",
    "reference_copy_on_save=TRUE enters the native-RDS owned-copy boundary,",
    "before metadata capture and existing save decisions/sanitization/writes")
  evidence$exercise[at] <- paste(evidence$exercise[at],
    "Pilot cases assert one owned copy, unchanged/changed save behavior, graph",
    "rejection before side effects, default-off/non-env bypass, and unchanged",
    "direct hashing/change-detection mutation behavior. Classed environments",
    "cannot enter PK decoration or attached-PK inspection through data.frame",
    "class dispatch when opted in; default-off PK mutation/fallback is retained")
  evidence$confirmed_findings[at] <- paste(evidence$confirmed_findings[at],
    "Parent reproduced pre-copy PK annotation mutating an environment classed",
    "as data.frame. Fixed enabled-mode tabular guards before decoration or",
    "attached-PK inspection; explicit caller-attribute/counter/no-write and",
    "default-off compatibility regressions are linked")
  evidence$residual_limitations[at] <- paste(evidence$residual_limitations[at],
    module_gaps["reference_copy.R"], "Pilot confidence remains partial")
  evidence$testing_confidence[at] <- "partial"
  at <- which(top & inventory$name %in% c("st_hash_obj", "st_changed",
                                          "st_sanitize_for_hash"))
  evidence$residual_limitations[at] <- paste(evidence$residual_limitations[at],
    "Reference-copy option affects opted-in st_save roots only; direct hashing",
    "and change detection retain legacy environment mutation. This pilot does",
    "not resolve the reference-object hash contract")

  # Coverage is reported independently and cannot change any status dimension.
  inventory$measured_coverage <- NA_real_
  inventory$measured_lines <- 0L
  inventory$coverage_limitations <- "No supplied measurement; not branch/assertion coverage"
  if (!is.null(opts$coverage)) {
    coverage <- read_csv(opts$coverage)
    if (!all(c("file", "line", "hits") %in% names(coverage))) {
      fail("Coverage CSV requires file,line,hits.")
    }
    coverage$file <- gsub("\\\\", "/", coverage$file)
    coverage$file <- vapply(coverage$file, function(file) {
      if (!is.na(file) && startsWith(file, paste0(root, "/"))) {
        substring(file, nchar(root) + 2L)
      } else file
    }, "")
    if (all(is.na(coverage$hits))) coverage$hits <- as.numeric(coverage$hits)
    if (anyNA(coverage$file) || anyNA(coverage$line) ||
        anyDuplicated(coverage[c("file", "line")]) ||
        any(!is.finite(coverage$line) | coverage$line < 1L |
              coverage$line != floor(coverage$line)) ||
        !is.numeric(coverage$hits) || any(!is.na(coverage$hits) &
          (!is.finite(coverage$hits) | coverage$hits < 0))) {
      fail("Invalid or duplicate coverage records.")
    }
    for (i in seq_len(nrow(inventory))) {
      hits <- coverage$hits[coverage$file == inventory$file[i] &
        coverage$line >= inventory$line_start[i] &
        coverage$line <= inventory$line_end[i]]
      inventory$measured_lines[i] <- sum(!is.na(hits))
      if (any(!is.na(hits))) inventory$measured_coverage[i] <- mean(hits > 0,
        na.rm = TRUE) * 100
    }
    inventory$coverage_limitations <- paste(
      "Supplied test-only inclusive-span measurements overlap nested sites;",
      "missing lines unknown; line coverage is not assertion/branch coverage")
  }
  for (field in fields) inventory[[field]] <- evidence[[field]]
  owner <- match(inventory$owner_site_id, inventory$site_id)
  for (field in c("functional_status", "testing_confidence",
                  "residual_limitations", "evidence_reference")) {
    value <- inventory[[field]][owner]
    value[is.na(value)] <- ""
    inventory[[paste0("owner_", field)]] <- value
  }
  inventory$assessment_stage <- "Curated integration; explicit residual blockers; not universal correctness"
  if (any(vapply(evidence, function(x) any(grepl("not assessed", x,
                                               fixed = TRUE)), logical(1)))) {
    fail("Unassessed placeholder remains.")
  }
  paths <- vapply(c(opts$evidence, opts$out), normalizePath, "",
                  winslash = "/", mustWork = FALSE)
  if (anyDuplicated(tolower(paths))) fail("Evidence and final CSV paths must differ.")
  inputs <- normalizePath(c(log_path, file.path(opts$inventory,
    c("function-audit.csv", "test-sites.csv")), opts$coverage),
    winslash = "/", mustWork = TRUE)
  if (any(tolower(paths) %in% tolower(inputs))) {
    fail("Output cannot overwrite an input.")
  }
  for (path in paths) {
    if (!dir.exists(dirname(path))) fail(paste("Output parent missing:", path))
    relative <- substring(path, nchar(root) + 2L)
    if (startsWith(tolower(path), paste0(tolower(root), "/")) &&
        !identical(relative, ".cg-docs/reviews/2026-10-15-function-audit.csv")) {
      fail("Workspace output is restricted to the requested final CSV.")
    }
  }
  tested_stage <- file.path(dirname(dirname(dirname(log_path))), "stamp")
  if (observed && dir.exists(tested_stage)) {
    source_files <- c("DESCRIPTION", "NAMESPACE",
      paste0("R/", list.files(file.path(root, "R"), "\\.[Rr]$")),
      paste0("tests/", list.files(file.path(root, "tests"), "\\.[Rr]$",
                                  recursive = TRUE)))
    current_hashes <- unname(tools::md5sum(file.path(root, source_files)))
    tested_hashes <- unname(tools::md5sum(file.path(tested_stage, source_files)))
    if (anyNA(tested_hashes) || !identical(current_hashes, tested_hashes)) {
      fail("Current R/tests/DESCRIPTION/NAMESPACE differ from the tested stage.")
    }
    cat("Tested-stage R/tests/DESCRIPTION/NAMESPACE: byte-identical\n")
  }
  utils::write.csv(evidence, opts$evidence, row.names = FALSE, na = "")
  utils::write.csv(inventory, opts$out, row.names = FALSE, na = "")
  cat("Rows:", nrow(inventory), "; top-level:", sum(top),
      "; nested:", sum(!top), "\n")
  cat("Observed log:", summaries, "; scope:", opts$scope,
      "; current:", fresh, "\n")
  print(table(inventory$functional_status))
  print(table(inventory$testing_confidence))
  print(table(inventory$lifecycle))
  gaps <- inventory$testing_confidence %in% c("missing", "blocked")
  print(inventory[gaps, c("site_id", "name", "top_owner_name",
                          "testing_confidence")], row.names = FALSE)
  cat("Evidence:", normalizePath(opts$evidence, winslash = "/"), "\n")
  cat("Final CSV:", normalizePath(opts$out, winslash = "/"), "\n")
  return(invisible(inventory))
}

if (sys.nframe() == 0L) curate_function_audit()
