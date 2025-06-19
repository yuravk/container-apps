#!/usr/bin/env bash

#
# Finds all executable and shared library files within an RPM-based chroot
# and saves the sorted, unique list of file paths.
#

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# Pipeliines fail if any command in the pipe fails.
set -euo pipefail

# The target chroot directory to query.
readonly TARGET_ROOT_FS="/mnt/sys-root"
# The final output file containing the list of binaries.
readonly OUTPUT_FILE="${TARGET_ROOT_FS}/tmp/binaries.list"
# Regex pattern of MIME types to identify as binaries or libraries.
readonly BINARY_MIME_TYPES='application/x-executable|application/x-sharedlib|application/x-pie-executable'


# --- Pre-flight Checks ---
# Ensure the rpm command is available.
if ! command -v rpm >/dev/null; then
  echo "Error: 'rpm' command not found. Please install it." >&2
  exit 1
fi

# Ensure the target directory exists.
if [[ ! -d "${TARGET_ROOT_FS}" ]]; then
  echo "Error: Target directory not found at '${TARGET_ROOT_FS}'" >&2
  exit 1
fi


# --- Main Logic ---
main() {
  echo "Starting binary scan in '${TARGET_ROOT_FS}'..." >&2

  # 1. Get a single, consolidated list of all files from all packages.
  #    The `-qal` flags mean Query, All packages, List files.
  rpm -qal --root "${TARGET_ROOT_FS}" |

  # 2. Prepend the root filesystem path to each file to create full host paths.
  #    We use `awk` to robustly prepend the path and pass it to the next stage.
  #    This check also ensures we only process files that actually exist.
  awk -v root="${TARGET_ROOT_FS}/" '{ print root $0 }' |

  # 3. Use `file` to identify MIME types for all files in a single batch.
  #    `--files-from -` reads the list of file paths from stdin (the pipe).
  #    `--no-pad` prevents padding for alignment.
  #    `-F ':'` sets the separator to a colon, e.g., "filename: mimetype".
  file --no-pad -F ':' --mime-type --files-from - |

  # 4. Filter this output to keep only the lines matching our binary MIME types.
  #    `grep -E` uses the extended regex pattern we defined.
  grep -E ": ${BINARY_MIME_TYPES}" |

  # 5. Extract just the full filename from the filtered lines (the part before the colon).
  cut -d ':' -f 1 |

  # 6. Remove the `TARGET_ROOT_FS` prefix to get the original path within the chroot.
  #    `sed` is perfect for this substitution.
  sed "s|^${TARGET_ROOT_FS}/||" |

  # 7. Sort the final list and remove duplicates, then save to the output file.
  #    `sort -u` is more efficient than `sort | uniq`.
  sort -u > "${OUTPUT_FILE}"

  echo "Scan complete. Results saved to '${OUTPUT_FILE}'." >&2
  echo "Found $(wc -l < "${OUTPUT_FILE}") unique binaries/libraries." >&2
}

# --- Execute Script ---
main "$@"
