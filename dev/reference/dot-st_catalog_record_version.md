# Record a new version in the catalog (internal)

Record a new version in the catalog (internal)

## Usage

``` r
.st_catalog_record_version(
  artifact_path,
  format,
  size_bytes,
  content_hash,
  code_hash,
  created_at,
  sidecar_format
)
```

## Arguments

- artifact_path:

  Character path to the artifact file.

- format:

  Character format name (e.g. "rds", "qs2").

- size_bytes:

  Numeric size of the artifact in bytes.

- content_hash:

  Character content hash of the artifact.

- code_hash:

  Character code hash (if available).

- created_at:

  Character ISO8601 timestamp of creation.

- sidecar_format:

  Character sidecar format present ("json", "qs2", "both", "none").

## Value

Character version id (SipHash of artifact id, hashes, timestamp).
