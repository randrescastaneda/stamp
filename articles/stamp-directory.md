# The .stamp Directory: Structure and Internals

## Overview

The `.stamp/` directory is the **persistent storage backend** for the
`stamp` package’s versioning system. This vignette explains:

1.  How and when `.stamp/` is created
2.  Its internal directory structure
3.  How versioning and metadata work under the hood
4.  Troubleshooting common issues

**Audience:** This vignette serves both **users** (understanding what
`.stamp` does) and **developers** (understanding internal implementation
details).

> Architecture note
>
> Recent changes introduced alias-aware paths and a dedicated storage
> directory `.st_data/` under the project root. In this model: -
> `.stamp/` continues to store the catalog, locks, and immutable version
> snapshots. - `.st_data/` can hold artifact files when using
> storage-managed paths, while your code still refers to logical
> paths. - Paths passed to APIs must resolve under the current alias
> root (the directory you called
> [`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
> on). Prefer saving within that root (e.g., `fs::path(demo_dir, ...)`).
>
> The examples below use in-project paths to keep the focus on `.stamp/`
> internals.

------------------------------------------------------------------------

## 1. Creation and Initialization

### 1.1 Creating `.stamp/` with `st_init()`

The `.stamp/` directory is created when you call
[`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md):

``` r
# Create a temporary project directory for demonstration
demo_dir <- fs::path_temp("stamp-demo")
fs::dir_create(demo_dir)

# Initialize stamp
st_init(demo_dir)
#> ✔ stamp initialized
#>   alias: default
#>   root: /tmp/RtmpQJPGvx/stamp-demo
#>   state: /tmp/RtmpQJPGvx/stamp-demo/.stamp

# Inspect what was created
fs::dir_tree(fs::path(demo_dir, ".stamp"), recurse = TRUE, all = TRUE)
#> /tmp/RtmpQJPGvx/stamp-demo/.stamp
#> ├── logs
#> └── temp
```

**What happens during initialization:**

1.  **Creates directory structure** (if it doesn’t exist):

    - `.stamp/` - Root state directory
    - `.stamp/temp/` - Temporary files during atomic writes
    - `.stamp/logs/` - Future use for logging (currently unused)

2.  **Records project root** in package state (in-memory reference)

3.  **Does NOT create or initialize** the catalog yet - that happens on
    first save

### 1.2 Re-running `st_init()`: Safe and Non-Destructive

**Important:** Running
[`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
multiple times is **safe** and will **NOT** delete or overwrite existing
version history.

``` r
# Save an artifact to create version history
test_data <- data.frame(x = 1:5, y = letters[1:5])
test_path <- fs::path(demo_dir, "data", "test.qs2")
st_save(test_data, test_path)
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2 @ version
#>   d455f29c69d11ceb

# Check versions exist
versions_before <- st_versions(test_path)
nrow(versions_before)
#> [1] 1

# Re-initialize (this is safe!)
st_init(demo_dir)
#> ✔ stamp initialized
#>   alias: default
#>   root: /tmp/RtmpQJPGvx/stamp-demo
#>   state: /tmp/RtmpQJPGvx/stamp-demo/.stamp

# Version history is preserved
versions_after <- st_versions(test_path)
identical(versions_before, versions_after)
#> [1] TRUE
```

**Why is this safe?**

- [`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
  only creates directories that don’t exist
- The catalog file (`catalog.qs2`) is read if present, never deleted
- Version snapshots in `versions/` are never touched by initialization

------------------------------------------------------------------------

## 2. Directory Structure Explained

### 2.1 High-Level Layout

    .stamp/                          # Root state directory
    ├── catalog.qs2                  # Central version registry (created on first save)
    ├── catalog.lock                 # Lock file for concurrent access control
    ├── temp/                        # Temporary files during atomic writes
    ├── logs/                        # Reserved for future logging features
    └── versions/                    # Version snapshots (created on first save)
        ├── data/                    # Mirrors your project structure
        │   └── test.qs2/            # One folder per artifact
        │       ├── 20250108T121500Z-abc12345/   # Version snapshot directory
        │       │   ├── artifact                  # Snapshot of the file itself
        │       │   ├── sidecar.json              # Metadata at save time
        │       │   ├── sidecar.qs2               # (optional) Binary metadata
        │       │   └── parents.json              # Lineage information
        │       └── 20250108T143000Z-def67890/   # Another version
        │           └── ...
        └── external/                # Artifacts outside project root
            └── a1b2c3d4-external.csv/
                └── ...

Let’s explore each component:

### 2.2 The Catalog: `catalog.qs2`

The catalog is a **central registry** tracking all artifacts and their
versions. It’s a QS2-serialized list containing two `data.table`
objects:

``` r
catalog <- list(
  artifacts = data.table(
    artifact_id,          # Stable hash of normalized path
    path,                 # Current canonical path
    format,               # File format (rds, qs2, csv, etc.)
    latest_version_id,    # Most recent version identifier
    n_versions            # Total number of saved versions
  ),
  versions = data.table(
    version_id,           # Unique version identifier
    artifact_id,          # Links to artifacts table
    content_hash,         # Hash of file contents
    code_hash,            # Hash of generating code (if tracked)
    size_bytes,           # File size in bytes
    created_at,           # ISO8601 UTC timestamp
    sidecar_format        # "json", "qs2", "both", or "none"
  )
)
```

**Key functions that read the catalog:**

``` r
# List all versions of an artifact
versions <- st_versions(test_path)
str(versions)
#> Classes 'data.table' and 'data.frame':   1 obs. of  7 variables:
#>  $ version_id    : chr "d455f29c69d11ceb"
#>  $ artifact_id   : chr "88478e560fa3b3e2"
#>  $ content_hash  : chr "2d26c6e5d9121bfd"
#>  $ code_hash     : chr NA
#>  $ size_bytes    : num 262
#>  $ created_at    : chr "2026-01-28T15:50:38.249775Z"
#>  $ sidecar_format: chr "json"
#>  - attr(*, ".internal.selfref")=<externalptr>

# Get latest version ID
latest_id <- st_latest(test_path)
latest_id
#> [1] "d455f29c69d11ceb"

# Get comprehensive info (catalog + sidecar + snapshot location)
info <- st_info(test_path)
str(info, max.level = 1)
#> List of 4
#>  $ sidecar     :List of 10
#>  $ catalog     :List of 2
#>  $ snapshot_dir: 'fs_path' chr "/tmp/RtmpQJPGvx/stamp-demo/data/test.qs2/versions/d455f29c69d11ceb"
#>  $ parents     : list()
```

### 2.3 Version Snapshots: `versions/`

Each time you save an artifact (and versioning is enabled), a new
**immutable snapshot** is created:

``` r
# Save the same artifact multiple times with changes
st_opts(versioning = "timestamp")  # ensure snapshots are created
#> ✔ stamp options updated
#>   versioning = "timestamp"
v1 <- data.frame(x = 1:3)
st_save(v1, test_path, code_label = "initial")
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2 @ version
#>   b4ca78ebe7522cff
Sys.sleep(1.1)

v2 <- data.frame(x = 1:5)
st_save(v2, test_path, code_label = "added rows")
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2 @ version
#>   2d66d94d67a29e56
Sys.sleep(1.1)

v3 <- data.frame(x = 1:5, y = 10:14)
st_save(v3, test_path, code_label = "added column")
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2 @ version
#>   5f39378acde977ad

# Each version gets its own directory
vroot <- fs::path(demo_dir, ".stamp", "versions")
if (fs::dir_exists(vroot)) {
  fs::dir_tree(vroot, recurse = 2)
} else {
  cat("No versions directory found (versioning may be off).\n")
}
#> No versions directory found (versioning may be off).

# reset to default behavior for the rest of the vignette
st_opts(versioning = "content")
#> ✔ stamp options updated
#>   versioning = "content"
```

**What’s inside a version snapshot directory?**

1.  **`artifact`** - A complete copy of the file at that point in time
2.  **`sidecar.json` / `sidecar.qs2`** - Metadata including:
    - Content hash
    - Code hash (if tracked)
    - File size
    - Timestamp
    - Custom metadata tags
    - Parent references (quick view)
3.  **`parents.json`** - Immutable provenance chain showing which
    artifacts this version depends on (only present if parents were
    specified)

``` r
# Get the latest version directory path
latest_info <- st_info(test_path)
latest_vdir <- latest_info$snapshot_dir

if (!is.na(latest_vdir) && fs::dir_exists(latest_vdir)) {
  # List contents - note: parents.json only exists if parents were specified
  fs::dir_ls(latest_vdir)
  
  # Read the sidecar from the snapshot
  sidecar_path <- fs::path(latest_vdir, "sidecar.json")
  if (fs::file_exists(sidecar_path)) {
    sidecar <- jsonlite::read_json(sidecar_path)
    str(sidecar[c("path", "format", "created_at", "size_bytes", "code_label")])
  }
} else {
  cat("No snapshot directory recorded for test_path; ensure versioning created snapshots.\n")
}
#> List of 5
#>  $ path      : chr "/tmp/RtmpQJPGvx/stamp-demo/data/test.qs2"
#>  $ format    : chr "qs2"
#>  $ created_at: chr "2026-01-28T15:50:41.093837Z"
#>  $ size_bytes: int 265
#>  $ code_label: chr "added column"
```

**Example of specifying parents during save:**

Notice that the `parents.json` file is not present in the example above.
This is because it is only created when parents are specified.

``` r
# Ensure snapshots are recorded for this demo
st_opts(versioning = "timestamp")
#> ✔ stamp options updated
#>   versioning = "timestamp"

# First, create an upstream artifact
upstream_path <- fs::path(demo_dir, "data", "upstream.qs2")
upstream_data <- data.frame(id = 1:10, value = rnorm(10))
st_save(upstream_data, upstream_path, code_label = "upstream data")
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/upstream.qs2 @ version
#>   b7150b0045f539ff
upstream_version <- st_latest(upstream_path)

# Now create a derived artifact with parent reference
derived_path <- fs::path(demo_dir, "data", "derived.qs2")
derived_data <- data.frame(id = 1:10, transformed = upstream_data$value * 2)
st_save(
  derived_data, 
  derived_path,
  parents = list(list(path = upstream_path, version_id = upstream_version)),
  code_label = "derived from upstream"
)
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/derived.qs2 @ version
#>   af0a195c3cbf57dc

# Now check the derived artifact's snapshot - parents.json will be present
derived_info <- st_info(derived_path)
derived_vdir <- derived_info$snapshot_dir
if (!is.na(derived_vdir) && fs::dir_exists(derived_vdir)) {
  fs::dir_ls(derived_vdir)
  
  # Read parents.json
  parents_file <- fs::path(derived_vdir, "parents.json")
  if (fs::file_exists(parents_file)) {
    parents <- jsonlite::read_json(parents_file)
    str(parents)
  } else {
    cat("parents.json not found; ensure parents were recorded.\n")
  }
} else {
  cat("No snapshot directory recorded for derived_path; ensure versioning created snapshots.\n")
}
#> List of 1
#>  $ :List of 2
#>   ..$ path      : chr "/tmp/RtmpQJPGvx/stamp-demo/data/upstream.qs2"
#>   ..$ version_id: chr "b7150b0045f539ff"

# Reset to default versioning for the remainder
st_opts(versioning = "content")
#> ✔ stamp options updated
#>   versioning = "content"
```

### 2.4 Artifact Organization: Path-Based vs. External Storage

The `versions/` directory organizes snapshots differently depending on
whether the artifact is **inside or outside your project directory**.
This affects how you’ll find version snapshots on disk.

#### Artifacts Inside Project Root (Path-Based Organization)

When you save an artifact that lives inside your project directory,
stamp mirrors the **relative path** structure:

**Example:** Project root is `/home/user/myproject/`, and you save
`/home/user/myproject/data/cleaned.rds`

    .stamp/versions/
    └── data/                        # Mirrors the relative path "data/"
        └── cleaned.rds/             # One directory per artifact
            ├── 20250108T121500Z-abc12345/  # Version 1
            ├── 20250108T143000Z-def67890/  # Version 2
            └── 20250108T165500Z-ghi13579/  # Version 3

The path `data/cleaned.rds/` mirrors your project structure, making
versions easy to locate.

#### Artifacts Outside Project Root (Hash-Based Organization)

When you save an artifact **outside** your project directory (e.g., in a
temp folder or shared drive), stamp cannot use a relative path. Instead,
it uses a **hash-based identifier** to prevent naming collisions:

**Example:** Project root is `/home/user/myproject/`, but you save
`/tmp/external_data.csv`

    .stamp/versions/
    └── external/                    # Special folder for out-of-project artifacts
        └── a1b2c3d4-external_data.csv/   # Hash prefix + basename
            ├── 20250108T121500Z-abc12345/
            └── 20250108T143000Z-def67890/

Here `a1b2c3d4` is the first 8 characters of the artifact’s unique ID
(hash of its absolute path). This ensures that two files with the same
name but different absolute paths don’t collide.

#### Real-World Example

``` r
# Scenario 1: File inside project (uses relative path)
project_file <- fs::path(demo_dir, "outputs", "results.qs2")
st_save(data.frame(x = 1:5), project_file)

# Versions stored at: .stamp/versions/outputs/results.qs2/
# ✓ Easy to navigate - mirrors your project structure

# Scenario 2: File outside project (uses hash + basename)
external_file <- fs::path_temp("temp_results.qs2")
st_save(data.frame(y = 6:10), external_file)

# Versions stored at: .stamp/versions/external/<hash>-temp_results.qs2/
# ✓ Collision-free - different absolute paths get different hashes
```

#### Why This Matters

1.  **Inside project**: Intuitive navigation - version directories match
    your project structure
2.  **Outside project**: Still tracked, but requires using
    [`st_info()`](https://randrescastaneda.github.io/stamp/reference/st_info.md)
    to find the exact snapshot location
3.  **Collision safety**: Two files named `data.csv` at different
    absolute paths never conflict

**Best practice:** Keep artifacts inside your project directory when
possible for easier manual inspection of the `.stamp/versions/` tree.

------------------------------------------------------------------------

## 3. How Versioning Works

### 3.1 The Version Creation Process

When you call
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md),
here’s what happens internally:

    ┌─────────────────────────────────────────────────────────────────┐
    │                       st_save(data, path)                       │
    └─────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
             ┌────────────────────────────────────────┐
             │  1. Decide if save is needed           │
             │     (st_should_save)                   │
             ├────────────────────────────────────────┤
             │  • Check if file exists                │
             │  • Compare content hash                │
             │  • Compare code hash                   │
             │  • Check versioning policy             │
             └────────────────┬───────────────────────┘
                              │
                              ▼
             ┌────────────────────────────────────────┐
             │  2. Write artifact atomically          │
             ├────────────────────────────────────────┤
             │  • Write to temp file                  │
             │  • Move to destination (atomic)        │
             └────────────────┬───────────────────────┘
                              │
                              ▼
             ┌────────────────────────────────────────┐
             │  3. Write sidecar metadata             │
             ├────────────────────────────────────────┤
             │  • Compute hashes                      │
             │  • Record timestamp                    │
             │  • Store in stmeta/ directory          │
             └────────────────┬───────────────────────┘
                              │
                              ▼
             ┌────────────────────────────────────────┐
             │  4. Update catalog                     │
             ├────────────────────────────────────────┤
             │  • Add version row to catalog          │
             │  • Update artifact's latest_version_id │
             │  • Increment n_versions counter        │
             └────────────────┬───────────────────────┘
                              │
                              ▼
             ┌────────────────────────────────────────┐
             │  5. Create version snapshot            │
             ├────────────────────────────────────────┤
             │  • Copy artifact to versions/          │
             │  • Copy sidecars                       │
             │  • Write parents.json                  │
             └────────────────┬───────────────────────┘
                              │
                              ▼
             ┌────────────────────────────────────────┐
             │  6. Apply retention policy             │
             │     (if configured)                    │
             ├────────────────────────────────────────┤
             │  • Prune old versions based on policy  │
             └────────────────────────────────────────┘

Each step is designed to be **atomic and crash-safe**, ensuring that
partial writes never corrupt your version history.

### 3.2 Version Identifiers

Version IDs are deterministic hashes combining:

- Timestamp (microsecond precision)
- Content hash
- Code hash (if available)
- Artifact ID

Example: `20250108T121507123456Z-abc12345`

This ensures:

- **Chronological ordering** - Timestamps sort naturally
- **Uniqueness** - Hash suffix prevents collisions
- **Traceability** - Hash links to specific content state

### 3.3 Versioning Modes

Control versioning behavior with
[`st_opts()`](https://randrescastaneda.github.io/stamp/reference/st_opts.md):

``` r
# Show current versioning mode
st_opts("versioning", .get = TRUE)
#> [1] "content"

# Available modes:
# - "content" (default): Save version only when content or code changes
# - "timestamp": Save version on every st_save() call
# - "off": Disable versioning (only update current file + sidecar)

# Example: Force version on every save
st_opts(versioning = "timestamp")
#> ✔ stamp options updated
#>   versioning = "timestamp"
v_same <- data.frame(x = 1:3)
st_save(v_same, test_path, code_label = "first")
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2 @ version
#>   43acd9365b98c284
Sys.sleep(0.2)
st_save(v_same, test_path, code_label = "second identical")  # Still creates version!
#> ✔ Saved [qs2] → /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2 @ version
#>   67c6062ba0e46ac7

# Check: two versions with identical content
recent_versions <- st_versions(test_path)
tail(recent_versions[, .(version_id, created_at, content_hash)], 2)
#>          version_id                  created_at     content_hash
#>              <char>                      <char>           <char>
#> 1: b4ca78ebe7522cff 2026-01-28T15:50:38.729107Z 41c16cfe6598913b
#> 2: d455f29c69d11ceb 2026-01-28T15:50:38.249775Z 2d26c6e5d9121bfd

# Reset to default
st_opts(versioning = "content")
#> ✔ stamp options updated
#>   versioning = "content"
```

------------------------------------------------------------------------

## 4. Developer Details

### 4.1 Key Internal Functions

These functions power the `.stamp/` infrastructure (from
`R/version_store.R`):

**Path and ID Management:**

``` r
.st_norm_path(path)           # Normalize path to absolute canonical form
.st_artifact_id(path)         # Compute stable hash identifier from path
.st_root_dir()                # Get project root from st_init()
.st_state_dir_abs()           # Get absolute .stamp/ path
```

**Catalog Operations:**

``` r
.st_catalog_path()            # Path to catalog.qs2
.st_catalog_read()            # Read catalog (or create empty if missing)
.st_catalog_write(cat)        # Atomic catalog write with locking
.st_catalog_record_version()  # Add new version row to catalog
```

**Version Management:**

``` r
.st_versions_root()           # Get versions/ directory path
.st_version_dir(rel_path, vid, alias)    # Compute specific version snapshot path
.st_version_commit_files()    # Copy artifact + sidecars to snapshot
.st_version_read_parents()    # Read parents.json from snapshot
.st_version_write_parents()   # Write parents.json to snapshot
```

### 4.2 Concurrency and Safety

#### File-Based Locking Explained

**The Problem:** Imagine two R sessions running simultaneously, both
trying to save artifacts:

    Session A: Reads catalog → Modifies → Writes back
    Session B: Reads catalog → Modifies → Writes back

Without coordination, Session B might overwrite Session A’s changes,
**losing version records**.

**The Solution:** `stamp` uses **file-based locking** to ensure only one
process modifies the catalog at a time:

    Session A: Acquires lock → Reads → Modifies → Writes → Releases lock
    Session B: Waits for lock → Acquires lock → Reads → Modifies → Writes → Releases lock

This is implemented via a lock file (`.stamp/catalog.lock`):

``` r
# Internal locking mechanism (simplified)
.st_with_lock(path, {
  cat <- .st_catalog_read()     # Read catalog safely
  # ... modify catalog ...       # Make changes
  .st_catalog_write(cat)         # Write back safely
})

# Lock file: .stamp/catalog.lock
# - Created automatically during catalog updates
# - Uses filelock package if available (recommended)
# - 5-second timeout prevents permanent deadlocks
# - Automatically cleaned up after operation completes
```

**Real-world scenarios where locking matters:**

1.  **Parallel processing:** Running `future::plan(multisession)` with
    multiple workers saving artifacts
2.  **Shared filesystems:** Multiple analysts on a server saving to the
    same project
3.  **Background jobs:** RStudio background jobs running
    [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
    while you work interactively

**What happens without the filelock package?**

- `stamp` falls back to **advisory locking** (no enforcement, relies on
  cooperation)
- Risk of corruption increases in high-concurrency scenarios
- Install `filelock` for production use: `install.packages("filelock")`

#### Atomic Operations

Beyond locking, `stamp` uses **atomic operations** to prevent partial
writes that could corrupt your data.

**What “atomic” means:** An operation that either completes entirely or
fails entirely, with no in-between state visible to other processes.

**Why this matters:** Consider what could go wrong without atomicity:

    # Bad scenario (non-atomic):
    1. Start writing new data to file
    2. ❌ CRASH (power outage, R session killed, etc.)
    3. File now contains partial/corrupt data
    4. Version history references a broken file

**How stamp ensures atomicity:**

- **File writes:** Always write to temp file → move to final location
  (filesystem-level atomic operation)
- **Catalog updates:** Read-modify-write under lock ensures serialized
  updates
- **Version snapshots:** Immutable once created (copy operations, never
  modified)

------------------------------------------------------------------------

## 5. Inspecting `.stamp/` Programmatically

### 5.1 User-Level Inspection

``` r
# Ensure at least two versions exist for demonstration
# Use explicit alias = NULL to auto-detect current alias
versions <- st_versions(test_path, alias = NULL)
if (nrow(versions) < 2) {
  st_opts(versioning = "timestamp")
  tmp <- data.frame(x = seq_len(3L))
  st_save(tmp, test_path, code_label = "autocreate v1 (user-inspection)")
  Sys.sleep(1.1)
  tmp2 <- transform(tmp, y = x * 10L)
  st_save(tmp2, test_path, code_label = "autocreate v2 (user-inspection)")
  versions <- st_versions(test_path, alias = NULL)
  st_opts(versioning = "content")
}

# List all versions of an artifact (compact view)
versions[, .(version_id, created_at, size_bytes)]
#>          version_id                  created_at size_bytes
#>              <char>                      <char>      <num>
#> 1: 67c6062ba0e46ac7 2026-01-28T15:50:41.877119Z        245
#> 2: 43acd9365b98c284 2026-01-28T15:50:41.633795Z        245
#> 3: 5f39378acde977ad 2026-01-28T15:50:41.093837Z        265
#> 4: 2d66d94d67a29e56 2026-01-28T15:50:39.950644Z        246
#> 5: b4ca78ebe7522cff 2026-01-28T15:50:38.729107Z        245
#> 6: d455f29c69d11ceb 2026-01-28T15:50:38.249775Z        262

# Get comprehensive info
info <- st_info(test_path)
info$catalog      # Latest version and count
#> $latest_version_id
#> [1] "67c6062ba0e46ac7"
#> 
#> $n_versions
#> [1] 6
info$snapshot_dir # Path to latest snapshot
#> /tmp/RtmpQJPGvx/stamp-demo/data/test.qs2/versions/67c6062ba0e46ac7

# Load a specific historical version (previous), safely
if (nrow(versions) > 1) {
  old_version_try <- try(st_load(test_path, version = -1, alias = NULL), silent = TRUE)
  if (!inherits(old_version_try, "try-error")) {
    str(old_version_try)
  } else {
    cat("Previous version not available; skipping load.\n")
  }
}
#> ✔ Loaded ← data/test.qs2 @ 43acd9365b98c284
#> [qs2]
#> 'data.frame':    3 obs. of  1 variable:
#>  $ x: int  1 2 3
```

### 5.2 Direct Catalog Access (Advanced)

``` r
# NOT recommended for users, but useful for debugging
catalog_path <- fs::path(demo_dir, ".stamp", "catalog.qs2")
if (fs::file_exists(catalog_path)) {
  cat <- qs2::qs_read(catalog_path)
  
  # View all artifacts
  print(cat$artifacts)
  
  # View all versions
  print(cat$versions)
}
```

### 5.3 Exploring Snapshots

``` r
# Get all version directories for an artifact
versions_root <- fs::path(demo_dir, ".stamp", "versions")
artifact_dir <- fs::path(versions_root, "data", "test.qs2")

if (fs::dir_exists(artifact_dir)) {
  # List all version snapshots
  snapshot_dirs <- fs::dir_ls(artifact_dir, type = "directory")
  
  # Inspect contents of latest snapshot
  if (length(snapshot_dirs) > 0) {
    latest <- snapshot_dirs[length(snapshot_dirs)]
    fs::dir_tree(latest)
    
    # Read parents.json if present
    parents_file <- fs::path(latest, "parents.json")
    if (fs::file_exists(parents_file)) {
      parents <- jsonlite::read_json(parents_file)
      str(parents)
    }
  }
}
```

------------------------------------------------------------------------

## 6. Troubleshooting

### 6.1 Missing or Corrupt `.stamp/` Directory

**Symptom:** Functions like
[`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md)
return empty results or error.

**Diagnosis:**

``` r
# Check if .stamp exists
stamp_dir <- fs::path(demo_dir, ".stamp")
fs::dir_exists(stamp_dir)

# Check if catalog exists
catalog_path <- fs::path(stamp_dir, "catalog.qs2")
fs::file_exists(catalog_path)
```

**Solution:**

``` r
# Re-initialize (safe, won't delete existing data)
st_init(demo_dir)

# If catalog is corrupt, it will be recreated empty on first st_save()
# Note: This means version history is lost - restore from backup if available
```

### 6.2 Catalog Schema Mismatch

**Symptom:** Error: “Catalog schema mismatch in versions table.”

**Cause:** Package upgrade changed catalog structure, or manual
corruption.

**Solution:**

``` r
# Back up existing catalog
backup_path <- fs::path(stamp_dir, "catalog_backup.qs2")
fs::file_copy(catalog_path, backup_path, overwrite = TRUE)

# Option 1: Delete catalog and rebuild (LOSES VERSION HISTORY)
fs::file_delete(catalog_path)
# Next st_save() will create fresh catalog

# Option 2: Manual migration (advanced - contact package maintainer)
```

### 6.3 Disk Space Issues

**Symptom:** `.stamp/versions/` grows very large.

**Diagnosis:**

``` r
# Check total size
info <- fs::dir_info(stamp_dir, recurse = TRUE)
data.table::data.table(total_mb = sum(info$size) / 1024^2)

# Find largest directories
info <- data.table::as.data.table(
  fs::dir_info(fs::path(stamp_dir, "versions"), recurse = TRUE)
)
info[order(-size)][1:10]
```

**Solution:**

``` r
# Configure retention policy to auto-prune old versions
st_opts(retention_policy = list(n = 10, days = 90))

# Manually prune versions for specific artifact
st_prune_versions(test_path, policy = list(n = 5), dry_run = FALSE)

# Prune all artifacts (use with caution!)
catalog <- stamp:::.st_catalog_read()
for (aid in unique(catalog$versions$artifact_id)) {
  artifact_path <- catalog$artifacts[artifact_id == aid]$path[1]
  st_prune_versions(artifact_path, policy = list(n = 5), dry_run = FALSE)
}
```

### 6.4 Version Timestamp Issues

**Symptom:** Timestamps appear corrupted or versions won’t load.

**Diagnosis:**

``` r
# Check for invalid timestamps
vers <- st_versions(test_path)
bad_timestamps <- vers[is.na(created_at) | created_at == ""]
nrow(bad_timestamps)
#> [1] 0
```

**Solution:** The package automatically drops corrupt version rows when
reading. If this happens frequently, check for:

- System clock issues
- Concurrent access without proper locking
- Manual modification of catalog files

### 6.5 Artifacts Outside Project Root

**Symptom:** Can’t find version snapshots for artifacts outside the
project directory.

**Explanation:** These are stored in `versions/external/` with a special
naming convention.

``` r
# Artifact outside project root
external_path <- fs::path_temp("external_data.csv")
st_save(data.frame(a = 1:3), external_path)

# Snapshot is under external/
aid <- stamp:::.st_artifact_id(external_path)
substr(aid, 1, 8)  # First 8 chars used in directory name

external_dir <- fs::path(stamp_dir, "versions", "external")
fs::dir_ls(external_dir)
```

### 6.6 Lock File Issues

**Symptom:** `catalog.lock` file persists after crash.

**Solution:**

``` r
# Safe to delete if no stamp operations are running
lock_file <- fs::path(stamp_dir, "catalog.lock")
if (fs::file_exists(lock_file)) {
  fs::file_delete(lock_file)
}
```

------------------------------------------------------------------------

## 7. Best Practices

### 7.1 Version Control Integration

**Include in `.gitignore`:**

    .stamp/temp/
    .stamp/logs/
    .stamp/catalog.lock

**Consider including:** - `.stamp/catalog.qs2` - Enables version history
tracking across team - `.stamp/versions/` - Useful for small datasets,
prohibitive for large files

**For large projects:**

    # .gitignore
    .stamp/versions/  # Too large for git
    .stamp/catalog.qs2  # Local catalog only

### 7.2 Backup Strategy

``` r
# Periodic catalog backup
backup_dir <- fs::path(demo_dir, "_backups")
fs::dir_create(backup_dir)

catalog_src <- fs::path(stamp_dir, "catalog.qs2")
catalog_dst <- fs::path(backup_dir, sprintf("catalog_%s.qs2", Sys.Date()))
fs::file_copy(catalog_src, catalog_dst, overwrite = TRUE)

# For critical projects, also backup versions/
versions_src <- fs::path(stamp_dir, "versions")
versions_dst <- fs::path(backup_dir, sprintf("versions_%s", Sys.Date()))
fs::dir_copy(versions_src, versions_dst, overwrite = TRUE)
```

------------------------------------------------------------------------

## 8. Summary

The `.stamp/` directory is a **robust, append-only version store** that:

✅ **Persists across sessions** - Re-running
[`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
is safe  
✅ **Tracks complete version history** - Every save creates an immutable
snapshot  
✅ **Enables lineage tracking** - Parent relationships preserved in
`parents.json`  
✅ **Supports concurrent access** - File-based locking prevents
corruption  
✅ **Scales with retention policies** - Auto-prune old versions to
manage disk space

**Key takeaways for users:**

- `.stamp/` is created once and grows with each version
- Safe to re-initialize without losing history
- Use
  [`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md),
  [`st_info()`](https://randrescastaneda.github.io/stamp/reference/st_info.md),
  and `st_load(version=...)` to explore history
- Configure retention policies to manage disk usage

**Key takeaways for developers:**

- Catalog is the source of truth (two tables: artifacts, versions)
- Version snapshots are immutable and organized by relative path
- All writes use atomic operations + locking for safety
- Internal functions prefixed with `.st_` provide infrastructure

------------------------------------------------------------------------

## Further Reading

- [`vignette("setup-and-basics", package = "stamp")`](https://randrescastaneda.github.io/stamp/articles/setup-and-basics.md) -
  General introduction
- [`vignette("hashing-and-versions", package = "stamp")`](https://randrescastaneda.github.io/stamp/articles/hashing-and-versions.md) -
  Deep dive into content hashing
