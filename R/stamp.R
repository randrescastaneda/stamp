#' Get stamp
#'
#' @description This is basically a wrapper around [digest::digest()]
#'
#' @inheritParams digest::digest
#'
#' @param x 	An arbitrary R object which will then be passed to the
#'   base::serialize function
#' @param algo character: default is value in option "stamp.digest.algo". This
#'   argument is the algorithms to be used; currently available choices are md5,
#'   which is also the default, sha1, crc32, sha256, sha512, xxhash32, xxhash64,
#'   murmur32, spookyhash and blake3
#'
#' @inherit digest::digest return details
#' @export
#'
#' @examples
#' stamp_get("abc")
stamp_get <- function(x,
                      algo            = c(
                        getOption("stamp.digest.algo"),
                        "md5",
                        "sha1",
                        "crc32",
                        "sha256",
                        "sha512",
                        "xxhash32",
                        "xxhash64",
                        "murmur32",
                        "spookyhash",
                        "blake3"
                      ),
                      serialize       = TRUE,
                      file            = FALSE,
                      length          = Inf,
                      skip            = "auto",
                      ascii           = FALSE,
                      raw             = FALSE,
                      seed            = 0,
                      errormode       = c("stop", "warn", "silent"),
                      serializeVersion = .getSerializeVersion()) {
  algo <- match.arg(algo)
  digest::digest(x, algo = algo)
}
