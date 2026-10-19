# Data Products Plus Adapters: Artifact Contract

Status: approved design direction; executable examples, not production enforcement.
Approval: user selected "Data products plus adapters" on 2026-10-19.

## Scope

This contract describes the artifact boundary of the new estimation pipeline.
It is not a global restriction on the general-purpose stamp package. It does not
copy the legacy pipeline's DAG, cache layout, accumulator environments, nested
table conventions, or metadata design. Cleaning remains an upstream concern;
no cleaning or estimator algorithm is implemented here.

This approval authorizes the contract and focused tests only. No validator,
adapter registry, reference-object rejection default, new hash scheme, or
production pipeline is introduced.

## Artifact Requirements

An artifact represents an inspectable result or an explicitly declared snapshot,
not an accidental capture of its producing process. Each artifact category must
declare a schema/version, payload meaning, required types/properties, relevant
parameters and provenance, storage fidelity, and reuse dependencies.

Initial value-oriented candidates are typed tables, vectors, arrays and explicit
structured collections of supported values. NULL is a value, not deletion or an
omitted result. A category is supported only to the extent its declared properties
are verified; listing a broad R type does not certify every class, attribute,
backend or nested combination.

Required properties can include names, dimensions, column types, levels, units,
meaningful classes, original data.table keys and row order. They must be specified
deliberately. Arbitrary incidental attributes do not automatically become part of
the contract. Primary-key annotations and data.table keys remain distinct.

Whether related outputs form separate artifacts or one structured result is a
later design choice based on meaning, update granularity and access. These tests
do not prescribe one envelope or require that every result be flattened.

## Correct Reuse

All semantic inputs affecting a result must participate in its reuse decision:
upstream artifact identities, relevant parameters, approved payload/restoration
state and the applicable code/provenance policy. Hidden environment state must
not be assumed to participate in a source-only code hash.

For the current stamp API, arbitrary `metadata=` fields alone are not a general
invalidation mechanism. The executable parameter example deliberately places its
parameters in the hashed value payload. A future parameter/provenance API needs a
separately approved and tested rule; recording a value is not proof it is checked.

Hashes and versions must not be rewritten silently. New representations or hash
schemes need explicit compatibility rules. Global hash equivalence across locales,
all nested attributes, platforms and R versions is not certified by this contract.

## Richer Classes and Adapters

A future richer class needs an explicit adapter contract before support is
claimed. It must define its identifier/version, accepted input class, meaningful
state, deterministic projection, storage representation, validation, excluded
resources and post-load capabilities. It must not mutate the caller.

An adapter must distinguish a data snapshot from reconstruction of an executable
object. Exporting coefficients and diagnostics does not promise a rehydrated
model or support for all original methods. A statistical model in the tests is
an illustrative adapter only, not a choice of estimator for the new pipeline.

Open connections, controllers and working environments are not implicitly
approved payloads. Objects may contain references through attributes or nested
values; a broad recursive ban is not authorized either. Normal data.table
bookkeeping must not be confused with unsupported user state.

There is no production adapter registration interface in this step. The example
is test-local. Reference-object mutation in the existing generic hashing path
remains unresolved; these tests do not convert it into a passing safety claim.

## Storage and Failure

Native RDS/QS2 fixtures verify exact selected value properties. Tabular/text
formats keep their own fidelity contracts; their serialization success is not
proof of arbitrary R-object fidelity. Legacy missing restoration descriptors
cannot recreate information that was never recorded.

Future pipeline enforcement must validate before changing outputs and produce
actionable failures. This document does not alter stamp's existing save fallback,
warning, append, retention or verification behavior. Full multi-file rollback,
power-loss durability and network filesystem safety remain separate guarantees.

## Executable Examples and Limits

`tests/testthat/test-artifact-contract.R` verifies selected value products,
structured plain-value collections, parameter-driven invalidation, original-key
tables and a test-local model-summary projection. Fixtures are synthetic and do
not use legacy pipeline data or execute its code.

The examples are not exhaustive certification, a runtime allowlist or evidence
that the not-yet-developed estimators return these exact structures. Nested
data.tables, arbitrary subclasses, every attribute combination and live resource
reconstruction require their own explicit support evidence.

## Validation Recorded

R 4.5.2, Windows: the focused examples pass 76 assertions with zero test failures,
warnings or skips. Complete normal and shuffled package checks each pass 2225
assertions with zero test failures, warnings or skips. Builds/checks exit zero;
examples and vignettes pass. Checks use `--no-manual` because LaTeX is unavailable;
the existing vignette-dependency/incoming NOTEs remain separate from test results.

Evidence parent: `C:/Users/wb384996/AppData/Local/Temp/2/kilo/`.
Focused run: `stamp-contract-focused2`. Complete run: `stamp-contract-final`.
Shuffled run: `stamp-contract-shuffle`, seed `20261019`.

An initial test serialized a model whose formula captured the changing test
environment, so before/after bytes were not a valid immutability oracle. The
fixture now uses a fixed base formula environment and still verifies unchanged
model serialization. This is a fixture correction, not production hashing work.

No production R source, default hash behavior, reference policy, legacy pipeline
or pipdata code was changed. All fixtures are illustrative; they do not certify
future estimator implementations or solve the existing reference-mutation gap.
