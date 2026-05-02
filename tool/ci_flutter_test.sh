#!/usr/bin/env bash
# Wrap `flutter test <args>` to tolerate shutdown-cleanup noise that
# the post-May-2026 GitHub Actions runner image emits *after* a
# successful test run, observed only in `integration_test/goldens/`
# (golden-file tests use `IntegrationTestWidgetsFlutterBinding`'s
# VmService comparator, which makes the apk teardown sensitive).
#
# Symptoms (from CI logs):
# - All testWidgets emit "✅ <description>" lines
# - Final summary line "🎉 N tests passed." appears
# - But then `adb uninstall failed: ProcessException` and/or
#   `PathNotFoundException: Deletion failed, path = '/tmp/flutter_tools.*'`
#   fire during cleanup, causing flutter test to exit 1
# - GitHub Actions reports the job failed even though every test
#   genuinely passed
#
# This wrapper:
# 1. Forwards args verbatim to `flutter test`
# 2. Captures stdout+stderr to a temp log so the runner sees
#    everything in real time (via `tee`) AND we can grep it
# 3. If flutter test exits non-zero, decides whether to honor the
#    failure or recover:
#      - Honors if any "Test failed" / "Some tests failed" / "FAIL "
#        string appears (real test failures)
#      - Recovers if a "tests passed" / "All tests passed" line
#        appears with no real-failure string (post-test cleanup
#        glitch)
#
# Remove this wrapper once the underlying flutter_tools cleanup
# bug is fixed upstream; the regular `flutter test <args>` will
# work directly.

set +e
LOG=$(mktemp -t flutter_test.XXXXXX.log)
trap 'rm -f "$LOG"' EXIT

flutter test "$@" 2>&1 | tee "$LOG"
result=${PIPESTATUS[0]}

if [ "$result" -eq 0 ]; then
  exit 0
fi

# Non-zero exit — examine the log to decide whether tests genuinely
# failed or this is post-test shutdown noise.
if grep -q -E 'Test failed|Some tests failed|^FAIL |##\[error\] *Test ' "$LOG"; then
  # Real test failure — honor the original exit code.
  exit "$result"
fi

if grep -q -E 'tests passed|All tests passed|🎉' "$LOG"; then
  echo "::warning::flutter test exited $result but the log shows tests passed"
  echo "::warning::treating this as success (post-test cleanup glitch)"
  exit 0
fi

# Couldn't classify — bail out with the original exit code.
exit "$result"
