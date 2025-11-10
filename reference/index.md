# Package index

## Core I/O

- [`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
  : Initialize stamp project structure
- [`st_opts()`](https://randrescastaneda.github.io/stamp/reference/st_opts.md)
  : Get or set package options
- [`st_opts_get()`](https://randrescastaneda.github.io/stamp/reference/st_opts_get.md)
  : Convenience getter (optional sugar)
- [`st_opts_reset()`](https://randrescastaneda.github.io/stamp/reference/st_opts_reset.md)
  : Reset all options to package defaults
- [`st_path()`](https://randrescastaneda.github.io/stamp/reference/st_path.md)
  : Declare a path (with optional format & partition hint)
- [`st_part_path()`](https://randrescastaneda.github.io/stamp/reference/st_part_path.md)
  : Build a concrete partition path under a base directory
- [`st_list_parts()`](https://randrescastaneda.github.io/stamp/reference/st_list_parts.md)
  : List available partitions under a base directory
- [`st_formats()`](https://randrescastaneda.github.io/stamp/reference/st_formats.md)
  : Inspect available formats
- [`st_register_format()`](https://randrescastaneda.github.io/stamp/reference/st_register_format.md)
  : Register or override a format handler
- [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
  : Save an R object to disk with metadata & versioning (atomic move)
- [`st_save_part()`](https://randrescastaneda.github.io/stamp/reference/st_save_part.md)
  : Save a single partition (uses st_save under the hood)
- [`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md)
  : Load an object from disk (format auto-detected; optional integrity
  checks)
- [`st_load_parts()`](https://randrescastaneda.github.io/stamp/reference/st_load_parts.md)
  : Load and row-bind partitioned data
- [`st_load_version()`](https://randrescastaneda.github.io/stamp/reference/st_load_version.md)
  : Load a specific version of an artifact

## Versioning & Catalog

- [`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md)
  : List versions for an artifact path
- [`st_latest()`](https://randrescastaneda.github.io/stamp/reference/st_latest.md)
  : Get the latest version_id for an artifact path
- [`st_prune_versions()`](https://randrescastaneda.github.io/stamp/reference/st_prune_versions.md)
  : Prune stored versions according to a retention policy
- [`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
  : Rebuild artifacts from a plan (level order)
- [`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
  : Plan a rebuild of descendants when parents changed

## Lineage & Builders

- [`st_children()`](https://randrescastaneda.github.io/stamp/reference/st_children.md)
  : List children (reverse lineage) of an artifact
- [`st_lineage()`](https://randrescastaneda.github.io/stamp/reference/st_lineage.md)
  : Show immediate or recursive parents for an artifact
- [`st_builders()`](https://randrescastaneda.github.io/stamp/reference/st_builders.md)
  : List registered builders
- [`st_register_builder()`](https://randrescastaneda.github.io/stamp/reference/st_register_builder.md)
  : Register a builder for an artifact path
- [`st_clear_builders()`](https://randrescastaneda.github.io/stamp/reference/st_clear_builders.md)
  : Clear all builders (or only those for a given path)

## Metadata & PKs

- [`st_read_sidecar()`](https://randrescastaneda.github.io/stamp/reference/st_read_sidecar.md)
  : Read sidecar metadata (internal)
- [`st_inspect_pk()`](https://randrescastaneda.github.io/stamp/reference/st_inspect_pk.md)
  : Inspect primary-key of an artifact from its sidecar
- [`st_add_pk()`](https://randrescastaneda.github.io/stamp/reference/st_add_pk.md)
  : Add or repair primary-key metadata in an artifact sidecar
- [`st_get_pk()`](https://randrescastaneda.github.io/stamp/reference/st_get_pk.md)
  : Read primary-key keys from a data.frame or sidecar/meta list
- [`st_pk()`](https://randrescastaneda.github.io/stamp/reference/st_pk.md)
  : Normalize a primary-key specification
- [`st_with_pk()`](https://randrescastaneda.github.io/stamp/reference/st_with_pk.md)
  : Attach primary-key metadata to a data.frame (in-memory)

## Helpers

- [`st_changed()`](https://randrescastaneda.github.io/stamp/reference/st_changed.md)
  : Check whether an artifact would change if saved now
- [`st_changed_reason()`](https://randrescastaneda.github.io/stamp/reference/st_changed_reason.md)
  : Explain why an artifact would change
- [`st_should_save()`](https://randrescastaneda.github.io/stamp/reference/st_should_save.md)
  : Decide if a save should proceed given current st_opts() Uses
  versioning policy and code-change rule.
- [`st_is_stale()`](https://randrescastaneda.github.io/stamp/reference/st_is_stale.md)
  : Is a child artifact stale because its parents advanced?
- [`st_info()`](https://randrescastaneda.github.io/stamp/reference/st_info.md)
  : Inspect an artifact's current status (sidecar + catalog + snapshot
  location)
- [`st_filter()`](https://randrescastaneda.github.io/stamp/reference/st_filter.md)
  : Filter a data.frame by primary-key values (or arbitrary columns)
