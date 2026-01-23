library(stamp)

root <- tempdir()  # Use fixed tempdir
st_opts_reset()
st_init(root = root, state_dir = ".s_debug", alias = "L")

pA <- fs::path(root, "A.qs")
pB <- fs::path(root, "B.qs")
fs::dir_create(fs::path_dir(pA), recurse = TRUE)
fs::dir_create(fs::path_dir(pB), recurse = TRUE)

cat("=== Test Setup ===\n")
cat("pA:", pA, "\n")
cat("pB:", pB, "\n")

cat("\n=== Saving pA ===\n")
st_save(data.frame(a = 1), pA, alias = "L", code = function(z) z)
vA <- st_latest(pA, alias = "L")
cat("vA:", vA, "\n")

cat("\n=== Computing artifact ID for pA manually ===\n")
aid_pA <- secretbase::siphash13(as.character(fs::path_abs(pA)))
cat("aid_pA:", aid_pA, "\n")

cat("\n=== Saving pB with parents ===\n")
st_save(
  data.frame(b = 2),
  pB,
  alias = "L",
  code = function(z) z,
  parents = list(list(path = pA, version_id = vA))
)

aid_pB <- secretbase::siphash13(as.character(fs::path_abs(pB)))
cat("aid_pB:", aid_pB, "\n")

cat("\n=== Reading catalog ===\n")
cat_contents <- stamp:::.st_catalog_read(alias = "L")
cat("Artifacts:\n")
print(cat_contents$artifacts)
cat("\nParents index:\n")
print(cat_contents$parents_index)

cat("\n=== Calling st_children ===\n")
kids <- st_children(pA, depth = 1L, alias = "L")
cat("Result data frame:\n")
print(kids)

cat("\n=== Checking match ===\n")
cat("nrow(kids):", nrow(kids), "\n")
if (nrow(kids) > 0) {
  cat("kids$child_path[1]:", kids$child_path[1], "\n")
  cat("pB:", pB, "\n")
  cat("Are they equal?:", kids$child_path[1] == pB, "\n")
  cat("Are they identical?:", identical(kids$child_path[1], pB), "\n")
  cat("Class of kids$child_path[1]:", class(kids$child_path[1]), "\n")
  cat("Class of pB:", class(pB), "\n")
}

