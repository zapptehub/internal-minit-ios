#!/bin/sh
# Resolve Debug, Internal, and Release settings for the minit and minitTests
# targets. Prints names and non-secret values only. Access values are reported
# as empty or non-empty, never as themselves.
#
# Debug and Internal may include gitignored Local.xcconfig and Secrets.xcconfig.
# When either file exists, backend, base URL, and Access assertions for those
# two configurations are skipped. Release, Sentry environment, DSN, and DEBUG
# assertions always run.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
project="$root/minit.xcodeproj"
sdk="${SDK:-iphonesimulator}"

inside=$(git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null || true)
if [ "$inside" != "true" ]; then
  echo "FAIL not inside a git work tree; cannot scan tracked files, untracked files, or the diff against HEAD for Access values" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

override_note=""
if [ -f "$root/Config/Local.xcconfig" ]; then
  override_note="Local.xcconfig present"
fi
if [ -f "$root/Config/Secrets.xcconfig" ]; then
  if [ -n "$override_note" ]; then
    override_note="Local.xcconfig and Secrets.xcconfig present"
  else
    override_note="Secrets.xcconfig present"
  fi
fi

show_settings() {
  target=$1
  config=$2
  out=$3
  if ! xcodebuild \
    -project "$project" \
    -target "$target" \
    -configuration "$config" \
    -sdk "$sdk" \
    -showBuildSettings \
    >"$out" 2>"$out.err"
  then
    echo "FAIL $target $config did not configure" >&2
    # stderr can include resolved settings; keep only the error summary.
    grep -E 'error:|fatal' "$out.err" | head -n 20 >&2 || true
    exit 1
  fi
}

for config in Debug Internal Release; do
  show_settings minit "$config" "$tmp/$config.txt"
  show_settings minitTests "$config" "$tmp/minitTests-$config.txt"
done

setting() {
  file=$1
  key=$2
  awk -v key="$key" '
    $1 == key && $2 == "=" {
      sub(/^[[:space:]]*[^=]*=[[:space:]]*/, "")
      print
      exit
    }
  ' "$file"
}

value() {
  setting "$tmp/$1.txt" "$2"
}

expect() {
  config=$1
  key=$2
  expected=$3
  actual=$(value "$config" "$key")
  if [ "$actual" != "$expected" ]; then
    echo "FAIL $config $key" >&2
    echo "expected: $expected" >&2
    case $key in
      CF_ACCESS_*|SENTRY_DSN)
        echo "actual: withheld" >&2
        ;;
      *)
        echo "actual: $actual" >&2
        ;;
    esac
    exit 1
  fi
  echo "OK $config $key"
}

expect_empty() {
  config=$1
  key=$2
  actual=$(value "$config" "$key")
  if [ -n "$actual" ]; then
    echo "FAIL $config $key is non-empty" >&2
    exit 1
  fi
  echo "OK $config $key empty"
}

# Backend, URL, and Access on Debug/Internal follow gitignored overrides.
expect_committed() {
  config=$1
  key=$2
  expected=$3
  if [ -n "$override_note" ]; then
    echo "SKIP $config $key ($override_note)"
    return
  fi
  expect "$config" "$key" "$expected"
}

expect_empty_committed() {
  config=$1
  key=$2
  if [ -n "$override_note" ]; then
    echo "SKIP $config $key ($override_note)"
    return
  fi
  expect_empty "$config" "$key"
}

expect Debug SENTRY_ENVIRONMENT development
expect_committed Debug MINIT_DATA_BACKEND http
expect_committed Debug MINIT_API_BASE_URL "https://api.zappte.eu/mock/min"
expect_empty_committed Debug CF_ACCESS_CLIENT_ID
expect_empty_committed Debug CF_ACCESS_CLIENT_SECRET
expect Debug PRODUCT_BUNDLE_IDENTIFIER saleseverest.minit

expect Internal SENTRY_ENVIRONMENT internal
expect_committed Internal MINIT_DATA_BACKEND http
expect_committed Internal MINIT_API_BASE_URL "https://api.zappte.eu/mock/min"
expect_empty_committed Internal CF_ACCESS_CLIENT_ID
expect_empty_committed Internal CF_ACCESS_CLIENT_SECRET
expect Internal PRODUCT_BUNDLE_IDENTIFIER saleseverest.minit

expect Release SENTRY_ENVIRONMENT release
expect Release MINIT_DATA_BACKEND firebase
expect Release MINIT_API_BASE_URL "https://api.minit.app"
expect Release PRODUCT_BUNDLE_IDENTIFIER saleseverest.minit
expect_empty Release CF_ACCESS_CLIENT_ID
expect_empty Release CF_ACCESS_CLIENT_SECRET

for config in Debug Internal Release; do
  dsn=$(value "$config" SENTRY_DSN)
  case $dsn in
    https://*) ;;
    *)
      echo "FAIL $config SENTRY_DSN did not expand" >&2
      exit 1
      ;;
  esac
  case $dsn in
    *'$()'*)
      echo "FAIL $config SENTRY_DSN still contains an unexpanded token" >&2
      exit 1
      ;;
  esac
  echo "OK $config SENTRY_DSN expanded"
done

debug_flags=$(value Debug SWIFT_ACTIVE_COMPILATION_CONDITIONS)
internal_flags=$(value Internal SWIFT_ACTIVE_COMPILATION_CONDITIONS)
release_flags=$(value Release SWIFT_ACTIVE_COMPILATION_CONDITIONS)
case $debug_flags in
  *DEBUG*) ;;
  *)
    echo "FAIL Debug is missing DEBUG" >&2
    exit 1
    ;;
esac
case $internal_flags in
  *DEBUG*)
    echo "FAIL Internal defines DEBUG" >&2
    exit 1
    ;;
esac
case $release_flags in
  *DEBUG*)
    echo "FAIL Release defines DEBUG" >&2
    exit 1
    ;;
esac
echo "OK Internal matches Release: DEBUG is not defined"

for config in Debug Internal Release; do
  actual=$(setting "$tmp/minitTests-$config.txt" CONFIGURATION)
  if [ "$actual" != "$config" ]; then
    echo "FAIL minitTests $config CONFIGURATION" >&2
    echo "expected: $config" >&2
    echo "actual: $actual" >&2
    exit 1
  fi
  echo "OK minitTests $config CONFIGURATION"
done

tests_debug_flags=$(setting "$tmp/minitTests-Debug.txt" SWIFT_ACTIVE_COMPILATION_CONDITIONS)
tests_internal_flags=$(setting "$tmp/minitTests-Internal.txt" SWIFT_ACTIVE_COMPILATION_CONDITIONS)
tests_release_flags=$(setting "$tmp/minitTests-Release.txt" SWIFT_ACTIVE_COMPILATION_CONDITIONS)
case $tests_debug_flags in
  *DEBUG*) ;;
  *)
    echo "FAIL minitTests Debug is missing DEBUG" >&2
    exit 1
    ;;
esac
case $tests_internal_flags in
  *DEBUG*)
    echo "FAIL minitTests Internal defines DEBUG" >&2
    exit 1
    ;;
esac
case $tests_release_flags in
  *DEBUG*)
    echo "FAIL minitTests Release defines DEBUG" >&2
    exit 1
    ;;
esac
echo "OK minitTests Internal matches Release: DEBUG is not defined"

contains_token() {
  flags=$1
  token=$2
  case " $flags " in
    *" $token "*) return 0 ;;
    *) return 1 ;;
  esac
}

require_token() {
  label=$1
  flags=$2
  token=$3
  if ! contains_token "$flags" "$token"; then
    echo "FAIL $label is missing $token" >&2
    echo "flags: $flags" >&2
    exit 1
  fi
  echo "OK $label has $token"
}

reject_token() {
  label=$1
  flags=$2
  token=$3
  if contains_token "$flags" "$token"; then
    echo "FAIL $label defines $token" >&2
    echo "flags: $flags" >&2
    exit 1
  fi
  echo "OK $label has no $token"
}

require_token "Debug" "$debug_flags" MINIT_SHAKE
require_token "Internal" "$internal_flags" MINIT_SHAKE
reject_token "Release" "$release_flags" MINIT_SHAKE
require_token "minitTests Debug" "$tests_debug_flags" MINIT_SHAKE
require_token "minitTests Internal" "$tests_internal_flags" MINIT_SHAKE
reject_token "minitTests Internal" "$tests_internal_flags" DEBUG
reject_token "minitTests Release" "$tests_release_flags" MINIT_SHAKE

release_email=$(value Release MINIT_SHAKE_REPORT_EMAIL)
if [ -n "$release_email" ]; then
  echo "FAIL Release MINIT_SHAKE_REPORT_EMAIL is non-empty" >&2
  exit 1
fi
echo "OK Release MINIT_SHAKE_REPORT_EMAIL empty"

for config in Debug Internal; do
  actual=$(value "$config" MINIT_SHAKE_REPORT_EMAIL)
  if [ -z "$actual" ]; then
    echo "FAIL $config MINIT_SHAKE_REPORT_EMAIL is empty" >&2
    exit 1
  fi
  echo "OK $config MINIT_SHAKE_REPORT_EMAIL set"
done

# Committed source lines. Resolved Debug and Internal settings can still be
# overridden by gitignored Local.xcconfig, which is why expect_committed skips
# when that file or Secrets.xcconfig is present. These lines always run.
expect_exact_line() {
  file=$1
  line=$2
  if ! grep -F -x -e "$line" "$file" >/dev/null; then
    echo "FAIL $file is missing the committed setting: $line" >&2
    exit 1
  fi
  echo "OK committed $line in $(basename "$file")"
}

expect_exact_line "$root/Config/Development.xcconfig" "MINIT_DATA_BACKEND = http"
expect_exact_line "$root/Config/Internal.xcconfig" "MINIT_DATA_BACKEND = http"
expect_exact_line "$root/Config/Release.xcconfig" "MINIT_DATA_BACKEND = firebase"
expect_exact_line "$root/Config/Development.xcconfig" "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG MINIT_SHAKE"
expect_exact_line "$root/Config/Internal.xcconfig" "SWIFT_ACTIVE_COMPILATION_CONDITIONS = MINIT_SHAKE"
expect_exact_line "$root/Config/Release.xcconfig" "MINIT_SHAKE_REPORT_EMAIL ="

# The http assignment has to precede the optional Local include, so Local can
# still override it. An exact-line check does not prove that order.
line_number() {
  file=$1
  text=$2
  grep -n -F -x -e "$text" "$file" | head -n 1 | cut -d: -f1
}

expect_http_before_local_include() {
  file=$1
  setting_line=$(line_number "$file" "MINIT_DATA_BACKEND = http")
  include_line=$(line_number "$file" '#include? "Local.xcconfig"')
  if [ -z "$setting_line" ] || [ -z "$include_line" ]; then
    echo "FAIL $(basename "$file") is missing MINIT_DATA_BACKEND = http or #include? \"Local.xcconfig\"" >&2
    exit 1
  fi
  if [ "$setting_line" -ge "$include_line" ]; then
    echo "FAIL $(basename "$file") MINIT_DATA_BACKEND = http is not before #include? \"Local.xcconfig\"" >&2
    exit 1
  fi
  echo "OK $(basename "$file") MINIT_DATA_BACKEND = http comes before #include? \"Local.xcconfig\""
}

expect_http_before_local_include "$root/Config/Development.xcconfig"
expect_http_before_local_include "$root/Config/Internal.xcconfig"

expect_line_after_local_include() {
  file=$1
  text=$2
  setting_line=$(line_number "$file" "$text")
  include_line=$(line_number "$file" '#include? "Local.xcconfig"')
  if [ -z "$setting_line" ] || [ -z "$include_line" ]; then
    echo "FAIL $(basename "$file") is missing $text or #include? \"Local.xcconfig\"" >&2
    exit 1
  fi
  if [ "$setting_line" -le "$include_line" ]; then
    echo "FAIL $(basename "$file") $text is not after #include? \"Local.xcconfig\"" >&2
    exit 1
  fi
  echo "OK $(basename "$file") $text comes after #include? \"Local.xcconfig\""
}

expect_line_after_local_include "$root/Config/Development.xcconfig" "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG MINIT_SHAKE"
expect_line_after_local_include "$root/Config/Internal.xcconfig" "SWIFT_ACTIVE_COMPILATION_CONDITIONS = MINIT_SHAKE"

for file in "$root/Config/Development.xcconfig" "$root/Config/Internal.xcconfig"; do
  if ! grep -E '^MINIT_SHAKE_REPORT_EMAIL = [^[:space:]]' "$file" >/dev/null; then
    echo "FAIL $(basename "$file") MINIT_SHAKE_REPORT_EMAIL is missing or empty" >&2
    exit 1
  fi
  echo "OK $(basename "$file") MINIT_SHAKE_REPORT_EMAIL is non-empty"
done

if grep -E '#include\??[[:space:]]+"*(Local|Secrets)\.xcconfig"' "$root/Config/Release.xcconfig" >/dev/null; then
  echo "FAIL Release.xcconfig includes Local.xcconfig or Secrets.xcconfig" >&2
  exit 1
fi
echo "OK Release.xcconfig does not include Local.xcconfig or Secrets.xcconfig"

# Committed xcconfigs must not carry an Access secret. Gitignored Local and
# Secrets files are not part of this scan.
for file in \
  "$root/Config/Development.xcconfig" \
  "$root/Config/Internal.xcconfig" \
  "$root/Config/Release.xcconfig" \
  "$root/Config/Sentry.xcconfig"
do
  if grep -E 'CF_ACCESS_CLIENT_(ID|SECRET) *= *[^[:space:]]' "$file" >/dev/null; then
    echo "FAIL $file has a non-empty Access value" >&2
    exit 1
  fi
done
echo "OK committed xcconfigs have empty Access values"

# Tracked files, additions versus HEAD, and untracked files that are not
# gitignored. Matching lines are not printed.
access_pattern='CF_ACCESS_CLIENT_(ID|SECRET) *= *[^[:space:]]'

set +e
tracked=$(git -C "$root" grep -l -E "$access_pattern" -- . 2>"$tmp/grep.err")
grep_status=$?
set -e
if [ "$grep_status" -eq 0 ]; then
  echo "FAIL tracked files contain a non-empty Access value" >&2
  printf '%s\n' "$tracked" >&2
  exit 1
fi
if [ "$grep_status" -ne 1 ]; then
  echo "FAIL git grep could not scan tracked files for Access values" >&2
  cat "$tmp/grep.err" >&2
  exit 1
fi

git -C "$root" diff HEAD -- . >"$tmp/diff.txt"
if grep -E "^\+.*${access_pattern}" "$tmp/diff.txt" >/dev/null; then
  echo "FAIL diff against HEAD contains a non-empty Access value" >&2
  exit 1
fi

git -C "$root" ls-files -o --exclude-standard >"$tmp/untracked.txt"
while IFS= read -r rel || [ -n "$rel" ]; do
  [ -n "$rel" ] || continue
  if [ ! -f "$root/$rel" ]; then
    continue
  fi
  set +e
  grep -I -E -- "$access_pattern" "$root/$rel" >/dev/null 2>"$tmp/untracked-grep.err"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "FAIL untracked file contains a non-empty Access value: $rel" >&2
    exit 1
  fi
  if [ "$status" -gt 1 ]; then
    echo "FAIL could not scan untracked file for Access values: $rel" >&2
    exit 1
  fi
done < "$tmp/untracked.txt"

echo "OK no non-empty Access assignment in tracked files, the diff against HEAD, or untracked files (gitignored files are not scanned)"
