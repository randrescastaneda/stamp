# Switch the session's default alias

Rebase the session "default" alias to the configuration stored under
`alias`. This does not modify any on-disk paths; it only affects which
stamp folder is used when functions are called without an explicit
`alias` argument.

## Usage

``` r
st_switch(alias)
```

## Arguments

- alias:

  Character alias to make the session default.

## Value

Invisibly returns the alias.
