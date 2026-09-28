---
project-name: "stamp"
team: "DECDG / GPID -- World Bank"
created: "2026-09-28"
last-reviewed: "2026-09-28"
---

# stamp

## Objective

An R package that saves R objects with sidecar metadata (hashes, provenance,
primary keys), keeps version history, prunes old versions, and supports
Hive-style partitions. It is for data scientists and analysts who need
reproducible, traceable artifact storage in their workflows.

## Key Deliverables

- CRAN-ready R package `stamp`
- pkgdown documentation site
- Vignettes (setup, hashing/versions, lineage/rebuilds, stamp directory,
  aliases, retention/prune)

## Constraints

- Fail loudly, never silently
- CRAN policy compliance (R CMD check clean)
- R >= 4.1 compatibility
- data.table + collapse dialect
- Artifact reproducibility (stable hashing, immutable version history)

## Current Focus

Preparing the package for CRAN submission on the `ready_cran` branch.
