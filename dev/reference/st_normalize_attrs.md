# Normalize attributes for consistent hashing

Normalizes the order of object attributes to a canonical form by
creating a new object with attributes in the correct order. This is
necessary because R does not allow reordering attributes in-place.

## Usage

``` r
st_normalize_attrs(x)
```

## Arguments

- x:

  A data.frame, data.table, list, or other object.

## Value

A new object with the same data but attributes in canonical order. The
class is preserved.

## Problem

Operations like
[`collapse::rowbind()`](https://sebkrantz.github.io/collapse/reference/rowbind.html) +
[`collapse::funique()`](https://sebkrantz.github.io/collapse/reference/funique.html)
can leave attributes in different orders even when content is identical.
Since [`serialize()`](https://rdrr.io/r/base/serialize.html) includes
attribute order, this causes different byte streams and thus different
hashes for logically identical objects.

## Solution

This function reorders attributes to a canonical order:

1.  Priority attributes: names, row.names, class, .internal.selfref

2.  Additional attributes: alphabetically sorted

## Implementation Strategy

The function creates a new object with attributes in canonical order.
This is a shallow copy - the actual data (columns, elements) is
referenced, not copied, making it efficient even for large objects.

**For data.table objects:**

- Warning on the need of sanitation of the object using
  `st_sanitize_for_hash`

**For regular data.frames:**

- Rebuilds from column list with canonical attribute order

- Shallow copy (column data is referenced, not copied)

- Preserves data.frame class

**For lists and other objects:**

- Uses [`unclass()`](https://rdrr.io/r/base/class.html) + attribute
  replacement

- Shallow copy when possible

## Performance

- Shallow copy strategy: data is referenced, not duplicated

- Fast path: returns unchanged if already in canonical order

- Negligible overhead for most use cases (\< 1% of hashing time)
