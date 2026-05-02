import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tolerance for golden-image comparisons in integration tests.
///
/// Pixel-exact comparison on a real Android emulator is unreliable
/// run-to-run: GPU driver determinism, font subpixel positioning,
/// and asset-decoder LSB precision routinely produce 1–3 pixels of
/// difference between otherwise-identical renders. With viewport
/// 1080×2337 = ~2.5M pixels, a 1-pixel diff is `~0.00004%` — well
/// below the threshold below.
///
/// Tune up if real visual regressions are slipping through, and
/// down if run-to-run noise keeps tripping CI.
const double _diffRatioTolerance = 0.0001; // 0.01%

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) {
      return true;
    }
    if (result.diffPercent <= _diffRatioTolerance) {
      stderr.writeln(
        'Golden "${golden.toFilePath()}": '
        'diff ${(result.diffPercent * 100).toStringAsFixed(5)}% within '
        'tolerance ${(_diffRatioTolerance * 100).toStringAsFixed(2)}%; '
        'treated as pass.',
      );
      return true;
    }
    final String error =
        await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

/// Auto-loaded by `flutter test integration_test/...`. Replaces the
/// default `LocalFileComparator` (which is what
/// `VmServiceProxyGoldenFileComparator` delegates to on the host
/// side) with a tolerant variant. Real failures still surface
/// because the threshold is far below "I can perceive this with my
/// eyes" — only sub-perceptible run-to-run noise gets absorbed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final GoldenFileComparator existing = goldenFileComparator;
  if (existing is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(
      Uri.parse('${existing.basedir}placeholder.dart'),
    );
  }
  await testMain();
}
