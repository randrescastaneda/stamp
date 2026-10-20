---
date: 2026-10-15
title: "Initialize a managed wiki without confusing post-push files with published work"
category: "git-workflows"
language: "R"
tags: [git, wiki, compound, ownership, documentation]
root-cause: "Compound cannot update a wiki without its manifest, and files generated after a push are not included in the already-published commit."
severity: "P2"
related: [".cg-docs/solutions/bugs/2026-10-02-docs-describe-nonexistent-api.md", ".cg-docs/solutions/testing-patterns/2026-10-15-installed-r-checks-for-durable-request-convergence.md"]
---

# Initialize A Managed Wiki Without Confusing Post-Push Files With Published Work

## Problem

An earlier Compound capture correctly skipped wiki enrichment because
`wiki/_wiki.yml` did not exist. The user then requested a precise sequence:
commit/push the completed feature, initialize the wiki, and run Compound again.

Two different states must remain explicit: the implementation already published
to Git, and the wiki/knowledge files generated afterward. A successful first
push cannot certify that later files were committed or published. A project
`wiki/` folder is also not an automatically published GitHub Wiki site.

## Root Cause

Wiki enrichment requires a valid manifest and ownership rules before pages can
be updated. A missing manifest is not permission to invent page structure during
an update. Conversely, marking the API page as manual prevents later automated
API documentation updates even when Compound's trigger criteria are satisfied.

Git records the committed tree at push time. Later wiki initialization, context
enrichment and brain regeneration change the working tree, not the earlier
commit or its remote branch. The requested command order does not reverse this
publication boundary.

## Solution

### Publish The Intended Work First

Inspect status, the actual diff and recent history; stage intended paths only.
Leave unrelated existing local configuration and generated adapter state out.
Push only the current feature branch without force, then compare local and
remote identities:

```powershell
git rev-parse HEAD
git ls-remote --heads origin refs/heads/feat/m2-stamp-generic-gaps
```

Observed here: both returned
`9a894f7ed2982424a5bd1a131df5867600029399`, published as
`feat(stamp): validate durable request rebuilds`. The commit contained the
reviewed implementation and earlier knowledge capture. Local `.gitignore`,
`compound-gpid.local.md` and `.compound-gpid/` changes were deliberately excluded.

### Initialize Ownership Before Updating

Run the workflow commands in the requested order:

```text
/cg-wiki init
/cg-compound
```

The authoritative folder setting is `## Wiki Configuration` in
`compound-gpid.context.md`, not the manifest's informational `folder` field.
Initialize through `cg-wiki`; do not write wiki pages from the coordinating
workflow. Preserve existing manual pages and user prose outside managed blocks.

For a new R package wiki, initialization created Home, API Reference, Vignettes
and Changelog, all with auto ownership. The API entry uses this pattern within
the complete manifest:

```yaml
schemaVersion: "compound-gpid-wiki-v1"
pages:
  - id: "api-reference"
    file: "api-reference.md"
    title: "API Reference"
    ownership: "auto"
    order: 2
    sections:
      - id: "functions"
        managed: true
      - id: "parameters"
        managed: true
      - id: "return-values"
        managed: true
lastUpdated: "2026-10-15"
```

Use unique IDs/orders, plain `.md` filenames and matching non-nested managed
markers. Derive the public API from `NAMESPACE` and generated `man/*.Rd`, not
older prose. The initialized API table matched the 39 actual exports, including
`st_execution_info()` and `st_record_outcome()`, without publishing private hash
or partition helpers. Identify the feature branch/commit instead of implying
that its new API is already on CRAN or the default branch.

When Compound subsequently triggers wiki enrichment, pass the captured solution
and existing manifest to `cg-wiki` in update mode. Change only sections declared
in that manifest. Surface manual-ownership, conflict and packaging notifications
instead of silently treating skipped pages as updated.

The actual follow-up update modified Home's managed overview and Changelog's
managed version-history section. Static validation preserved all four auto pages,
nine paired non-nested sections and the 39-export API table. No manual-ownership
or conflict notification was emitted. This exercised enrichment through the new
manifest rather than merely creating files that had never been updated.

### Keep Publication And Packaging Claims Bounded

Record whether the post-push wiki/Compound files remain uncommitted. A later
commit/push is a separate Git action; do not claim that the earlier remote SHA
contains these newly generated files. Preserve the user's requested order.

Initial static inspection found that `.Rbuildignore` did not exclude `wiki/`.
This was reported and left unchanged during wiki/Compound execution: those write
scopes did not authorize editing the root package-build configuration. No package
runtime/test commands were run by wiki initialization.

The user then explicitly authorized exclusion and publication of the generated
documentation. Follow-up maintenance added `^wiki$` to `.Rbuildignore`. The wiki
and Compound records belong in a separate documentation commit, not the earlier
feature SHA. Validate the exclusion with a source copy that actually contains
`wiki/`; omitting it from the copy before building would not test the rule.
Bounded build/check evidence still does not imply full CRAN certification.

The authorized follow-up verified the rule with R 4.5.2 on Windows: the source
copy contained all five wiki files and the archive contained zero wiki entries
(`WIKI_EXCLUSION_OK source_files=5 archive_entries=0`). The complete tarball had
145 entries. Build and installed-package check exited 0; tests reported
PASS1873/FAIL0/WARN9/SKIP7. The nine test warnings/seven skips were unchanged
baseline cases, and two expected check warnings remained for unbuilt vignettes.
Evidence is in the disposable runner's
`build/run-20261015-161926600/stamp.Rcheck/00check.log` and
`tests/testthat.Rout`. No full CRAN-release certification is implied.

## Prevention

- Validate the manifest before updates; use auto ownership for references that
  are expected to track future public API changes.
- Keep command/module availability separate from the R package's runtime API.
  Workflow commands are not new exports or package CLI executables.
- Verify the pushed ref explicitly, and distinguish committed, staged, local
  generated and remote states in the completion report.
- Never stage all changes blindly when unrelated local configuration already
  exists; do not amend or force-push to hide a later documentation generation.
- Check package-build inclusion separately from wiki creation. Respect command
  file permissions rather than silently changing `.Rbuildignore`.
- Treat prior package test counts as dated evidence, not a fresh verification
  of files generated afterward.
- Cross-link existing lessons and rebuild the brain after capture; do not
  duplicate the entire implementation solution to describe a wiki bootstrap.

## Related

- [Prevent documentation/API drift](../bugs/2026-10-02-docs-describe-nonexistent-api.md).
- [Durable request verification](../testing-patterns/2026-10-15-installed-r-checks-for-durable-request-convergence.md).
- [Published feature commit](https://github.com/randrescastaneda/stamp/commit/9a894f7ed2982424a5bd1a131df5867600029399).
- [Wiki manifest](../../../wiki/_wiki.yml) and [Home](../../../wiki/README.md).
- [Package build exclusions](../../../.Rbuildignore) and [actual public exports](../../../NAMESPACE).
