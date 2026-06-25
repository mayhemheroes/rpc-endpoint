#!/usr/bin/env bash
#
# mayhem/test.sh — functional oracle for the go-fuzz harness.
#
# Go test binaries are STATICALLY linked, so the verify-repo sabotage check (an
# LD_PRELOAD _exit(0) constructor) cannot neuter them — a `go test` oracle would be
# reward-hackable. Instead we probe the DYNAMICALLY-linked, clang-linked fuzz binary
# (/mayhem/fuzzServer) on a known seed and assert libFuzzer actually EXECUTED the input
# through the harness (which drives server.NewRedisState). Under sabotage the dynamic
# binary is _exit(0)'d by the preloaded constructor BEFORE it can report execution,
# so the oracle FAILS — i.e. it asserts behavior, not just exit status (§6.3).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${SRC:=/mayhem}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

BIN=/mayhem/fuzzServer
if [ ! -x "$BIN" ]; then
  echo "FAIL: $BIN missing — build.sh did not produce the fuzz binary" >&2
  emit_ctrf "go-fuzz-libfuzzer-probe" 0 1
  exit 1
fi

# Seed routes to harness case 0 (server.NewRedisState) — the non-panicking path:
# the first byte is a non-digit, so strconv.Atoi(...) fails -> num=0.
seed="$(mktemp)"
printf 'x' > "$seed"

passed=0; failed=0
out="$("$BIN" "$seed" -runs=1 2>&1)" || true
if printf '%s' "$out" | grep -qE 'Executed[[:space:]]|Done [0-9]+ runs'; then
  echo "PASS: fuzz harness executed the seed through libFuzzer"
  passed=1
else
  echo "FAIL: fuzz harness did not report executing the seed; tail of output:" >&2
  printf '%s\n' "$out" | tail -8 >&2
  failed=1
fi
rm -f "$seed"

emit_ctrf "go-fuzz-libfuzzer-probe" "$passed" "$failed"
