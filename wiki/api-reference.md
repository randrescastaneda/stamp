# API Reference

<!-- cg:auto:functions -->
## Functions

This index covers exactly the 39 `export(...)` entries in [NAMESPACE](../NAMESPACE) for the feature-branch snapshot identified on [Home](README.md). The linked Rd files provide authoritative signatures and argument details. An Rd file alone does not make a function public.

| Area | Exported functions |
| --- | --- |
| Stores and aliases | [st_init](../man/st_init.Rd), [st_alias_get](../man/st_alias_get.Rd), [st_alias_list](../man/st_alias_list.Rd), [st_switch](../man/st_switch.Rd) |
| Save and load | [st_save](../man/st_save.Rd), [st_load](../man/st_load.Rd), [st_load_version](../man/st_load_version.Rd), [st_restore](../man/st_restore.Rd) |
| Metadata and history | [st_read_sidecar](../man/st_read_sidecar.Rd), [st_info](../man/st_info.Rd), [st_versions](../man/st_versions.Rd), [st_latest](../man/st_latest.Rd), [st_catalog_query](../man/st_catalog_query.Rd), [st_prune_versions](../man/st_prune_versions.Rd) |
| Hash and save decisions | [st_hash_obj](../man/st_hash_obj.Rd), [st_changed](../man/st_changed.Rd), [st_changed_reason](../man/st_changed_reason.Rd), [st_should_save](../man/st_should_save.Rd) |
| Primary keys and filtering | [st_pk](../man/st_pk.Rd), [st_with_pk](../man/st_with_pk.Rd), [st_get_pk](../man/st_get_pk.Rd), [st_inspect_pk](../man/st_inspect_pk.Rd), [st_add_pk](../man/st_add_pk.Rd), [st_filter](../man/st_filter.Rd) |
| Lineage and rebuilding | [st_lineage](../man/st_lineage.Rd), [st_children](../man/st_children.Rd), [st_is_stale](../man/st_is_stale.Rd), [st_register_builder](../man/st_register_builder.Rd), [st_builders](../man/st_builders.Rd), [st_clear_builders](../man/st_clear_builders.Rd), [st_plan_rebuild](../man/st_plan_rebuild.Rd), [st_rebuild](../man/st_rebuild.Rd) |
| Execution history | [st_execution_info](../man/st_execution_info.Rd), [st_record_outcome](../man/st_record_outcome.Rd) |
| Formats and options | [st_formats](../man/st_formats.Rd), [st_register_format](../man/st_register_format.Rd), [st_opts](../man/st_opts.Rd), [st_opts_get](../man/st_opts_get.Rd), [st_opts_reset](../man/st_opts_reset.Rd) |

The execution-history functions are the two new exports in this feature work. Hash-code/file helpers and partition helpers are not public exports in this snapshot.
<!-- cg:auto:end -->

<!-- cg:auto:parameters -->
## Parameters

Core signatures from the Rd reference:

```r
st_save(x, file, format = NULL, metadata = list(), code = NULL,
        parents = NULL, code_label = NULL, pk = NULL, domain = NULL,
        unique = TRUE, verbose = TRUE, alias = NULL, ...,
        request = NULL, semantic_schema = NULL)
st_plan_rebuild(targets, depth = Inf, include_targets = FALSE,
                mode = c("propagate", "strict"), requests = NULL)
st_rebuild(plan, rebuild_fun = NULL, dry_run = FALSE)
st_execution_info(path, receipt_id = NULL, alias = NULL)
st_record_outcome(path, outcome, request, failure = NULL, alias = NULL)
```

- `alias` selects the registered store. Save/load use `file`; sidecar reads use `rel_path`. Use the exact argument names in each Rd page.
- `parents` contains records with `path` and exact `version_id`. Request proof requires persisted valid byte checksums. A deferred NULL pin is allowed only during planning for an explicit selected parent recipe, then resolves before child execution.
- `requests = NULL` retains legacy planning: `strict` selects recorded parent-version mismatches; `propagate` also schedules recorded descendants. These modes do not discover current calculation dependencies. Explicit requests determine their own graph and currentness, independently of `mode`.
- A complete request has `schema = 1L`, `path`, `root`, `parents`, `required_components` including `calculation`, matching named `components`, `semantic_schema`, `semantic` and an exact registered `format`. Each component carries `hash`, `algorithm` and a caller-defined canonicalization `schema`. Optional `audit` and `review` do not affect request equality. See [st_plan_rebuild](../man/st_plan_rebuild.Rd) for the full contract.
- Semantic descriptors define `type`, `shape`, `required`, `nullable` and `allow_na`. Logical, integer, double and character types are distinct. Optional absence, NULL, typed NA and empty vectors are distinct. Classed/nested values, NaN and infinities are rejected. `request` and `semantic_schema` in `st_save()` require exact argument names after `...`.
- `rebuild_fun(path, parents)` returns a list with exactly one non-NULL `x` on the request route. Optional `format` and semantic `metadata` must match the request. Without it, rebuild uses a registered builder. A dry run invokes no builder and writes no execution records.
- `st_record_outcome()` accepts only `outcome = "failed"` or `"blocked"`, with a required `failure = list(class = ..., message = ...)`. Classes are `deterministic`, `external` or `unknown`; blocked facts require `unknown`. This API cannot publish success.
<!-- cg:auto:end -->

<!-- cg:auto:return-values -->
## Return Values And Guarantees

| Call | Result |
| --- | --- |
| `st_save()` | Invisible list with `path`, `metadata`, `version_id` for a new save; unchanged saves return `skipped`, `reason` and the validated retained pin, without a receipt or descriptive rewrite. Modern request/semantic failures propagate; the legacy write-error route can return NULL metadata/version ID. |
| `st_load()` / `st_load_version()` | Loaded R object. Exact historical loads use the snapshot's recorded physical format. |
| `st_read_sidecar()` | Metadata list; modern declared semantic types are preserved. Exact historical proof must exist; it never substitutes current metadata. No artifact format reader is invoked. |
| `st_plan_rebuild()` | Data frame; request-aware rows include `request`, `decision` (`run`, `skip`, `blocked`), `request_id` and `receipt_id`. A plan is a preview, not execution evidence. |
| `st_rebuild()` | Invisible result data frame. Request-aware statuses are `built`, `unchanged`, `skipped`, `blocked`, `failed`, `dry_run`; only validated successful or reused outputs have usable version pins. |
| `st_execution_info()` | List with `state`, `reason`, `receipt`, `outcome`, `version_id`, `receipt_id`, `outcome_id`. States: `absent`, `invalid`, `recorded`, `success`. Explicit IDs never fall back to latest; unknown IDs error in a valid store. |
| `st_record_outcome()` | Invisible immutable outcome envelope, including its ID; output is NULL, so it cannot manufacture a usable pin. |

Execution inspection and pinned sidecar reads do not deserialize artifact data; checksum streaming still performs I/O. Execution history is not a requested-currentness check. Use `st_is_stale(request = ...)` or request-aware planning; blocked proof raises `stamp_blocked_request` in `st_is_stale()` rather than reporting currentness.

After A advances, B must actually run against the effective new input. Equal result content, producing components, semantic proof and format can retain B1 with a new receipt binding the new input. B1's original sidecars and ancestry stay immutable. A fully satisfied repeat writes neither a version nor a receipt. Changed component or semantic proof can create a new version even for equal data.

Deterministic recovery requires changed input/component proof **and** `review$outcome_id` naming the governing failure. Review alone, audit labels or semantic/format-only edits do not unlock it. External failures allow one attempt on the next analyst-started rebuild; unknown actual failures remain blocked. Missing builder configuration is recoverable blocked work, not an actual unknown failure. Blocked observations do not supersede actual failures. There is no Force interface or automatic retry.

Committed references protect effective inputs, outputs and retained ancestry from pruning. Inspect `st_prune_versions(..., dry_run = TRUE)` first. These guarantees cover serial isolated execution, not SMB atomicity, multiwriter safety or cryptographic authenticity.
<!-- cg:auto:end -->

← [Home](README.md)
