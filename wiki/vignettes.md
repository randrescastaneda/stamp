# Vignettes

<!-- cg:auto:examples -->
## Examples

Start with [Setup and Basics](../vignettes/setup-and-basics.Rmd), then [Hashing and Versions](../vignettes/hashing-and-versions.Rmd). The [main vignette](../vignettes/stamp.Rmd) gives a broader tour.

For this feature branch, use [Builders, Plans, and Rebuilds](../vignettes/builders-plans.Rmd), especially **Request-Aware Execution**, **Retained Output And Failures** and **Typed Semantic History**. Its root example hashes actual function formals/body plus explicitly declared helper and constant values, builds a complete request, previews execution, rebuilds and inspects the receipt. The repeat demonstrates a satisfied skip without writes. The typed-history example distinguishes empty vectors from NULL and reads exact historical sidecars.

The guide contains both illustrative chunks and explicitly enabled runnable examples. The `both` sidecar example requires QS2. This wiki initialization did not execute any examples or package checks.
<!-- cg:auto:end -->

<!-- cg:auto:use-cases -->
## Use Cases

| Need | Guide |
| --- | --- |
| Understand artifact storage layout | [Stamp Directory](../vignettes/stamp-directory.Rmd) |
| Select among multiple stores | [Using Aliases](../vignettes/using-alias.Rmd) |
| Inspect parent/child provenance | [Lineage and Rebuilds](../vignettes/lineage-rebuilds.Rmd) |
| Preview retention and pruning | [Version Retention and Pruning](../vignettes/version_retention_prune.Rmd) |
| Prove execution against an explicit calculation request | [Builders, Plans, and Rebuilds](../vignettes/builders-plans.Rmd) |

Use legacy lineage inspection for recorded parent changes, not as complete proof of current helper/constants/rules. Use explicit requests when currentness depends on those components. Keep workers deterministic and return their results to rebuild instead of writing artifacts inside builders. For exact API contracts, use [API Reference](api-reference.md).
<!-- cg:auto:end -->

← [Home](README.md)
