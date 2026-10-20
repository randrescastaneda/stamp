# Home

<!-- cg:auto:overview -->
## Overview

`stamp` saves R objects with sidecar metadata for hashes, provenance and primary keys. Immutable versions and retention controls keep analytical artifacts traceable across sessions. The project belongs to DECDG / GPID at the World Bank.

This wiki describes the 39 exported functions on `feat/m2-stamp-generic-gaps` at commit [`9a894f7ed2982424a5bd1a131df5867600029399`](https://github.com/randrescastaneda/stamp/commit/9a894f7ed2982424a5bd1a131df5867600029399), not a merged default-branch or CRAN release. `DESCRIPTION` reports version `0.0.11`. R >= 4.1 and CRAN readiness are project constraints; CRAN release certification is not established here.

Keep artifact versions, actual execution receipts and requested-currentness decisions separate. Saving unchanged data is not proof that a builder ran. Request-aware rebuilding validates declared components, semantic metadata, exact parent pins and retained bytes. Callers remain responsible for declaring all result-affecting helpers, constants and rules.

Wiki maintenance requires `/cg-wiki init` when the manifest is missing, not before every `/cg-compound` enrichment run. These are development-workflow commands, not R package CLI commands or exports. The authoritative wiki folder is the `folder` comment under `## Wiki Configuration` in `compound-gpid.context.md`; `_wiki.yml` records page ownership and managed sections. Keep API Reference on `auto` ownership so later API changes can update it. Manual pages and prose outside managed markers remain user-owned.

Wiki initialization and Compound enrichment generated documentation after feature commit `9a894f7ed2982424a5bd1a131df5867600029399`; these outputs are versioned separately from that feature SHA. A source `wiki/` folder does not automatically publish a GitHub Wiki site. Explicitly authorized follow-up maintenance added `^wiki$` to `.Rbuildignore` to exclude the developer wiki from package builds. This configuration change is not evidence of a fresh package check or a successful documentation push.
<!-- cg:auto:end -->

## Contents

1. [API Reference](api-reference.md)
2. [Vignettes](vignettes.md)
3. [Changelog](changelog.md)

<!-- cg:auto:installation -->
## Installation

Use R >= 4.1. The following R command installs the feature branch documented here, including its 39-export API; it does not install a CRAN release. It requires `pak`, network access and any build tools needed by dependencies. The branch can advance; the commit above identifies this wiki's source snapshot.

```r
pak::pkg_install("randrescastaneda/stamp@feat/m2-stamp-generic-gaps")
```

Runtime imports include `cli`, `fs`, `rlang`, `secretbase`, `jsonlite`, `data.table`, `utils`, `nanoparquet` and `qs2`. `collapse` is suggested, not a required import. Development follows the project's data.table + collapse dialect. See [DESCRIPTION](../DESCRIPTION) for dependency versions and optional packages.
<!-- cg:auto:end -->

<!-- cg:auto:quick-start -->
## Quick Start

Run this R example in a session with the documented branch installed. It creates a temporary store and saves a small object; it does not certify a builder execution.

```r
library(stamp)
root <- tempfile("stamp-demo-")
dir.create(root)
st_init(root, alias = "wiki-demo", verbose = FALSE)
saved <- st_save(1:3, "result.rds", alias = "wiki-demo", verbose = FALSE)
value <- st_load("result.rds", alias = "wiki-demo")
meta <- st_read_sidecar("result.rds", alias = "wiki-demo",
                        version_id = saved$version_id)
st_versions("result.rds", alias = "wiki-demo")
st_execution_info("result.rds", alias = "wiki-demo")$state # "absent"
```

Use explicit aliases when working across stores. For incremental execution, start with the request-aware example in [Vignettes](vignettes.md), not a raw save comparison. Inspect a pruning dry run before deleting versions.
<!-- cg:auto:end -->
