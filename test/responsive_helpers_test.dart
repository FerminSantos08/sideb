import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/layout/side_b_layout.dart';
import 'package:side_b/core/utils/text_formatters.dart';

void main() {
  test('classifies the supported logical widths', () {
    expect(SideBLayout.sizeFor(360), SideBScreenSize.compact);
    expect(SideBLayout.sizeFor(600), SideBScreenSize.medium);
    expect(SideBLayout.sizeFor(800), SideBScreenSize.medium);
    expect(SideBLayout.sizeFor(1024), SideBScreenSize.expanded);
  });

  test('keeps the featured cover within its intended height range', () {
    expect(SideBLayout.featuredPostHeight(360), inInclusiveRange(260, 340));
    expect(SideBLayout.featuredPostHeight(800), inInclusiveRange(320, 420));
    expect(SideBLayout.featuredPostHeight(1024), inInclusiveRange(320, 420));
  });

  test('formats dates and repairs common UTF-8 mojibake for presentation', () {
    expect(formatSpanishDate('2026-10-31T09:17:22'), '31 oct 2026');
    expect(repairMojibake('MÃºsica'), 'Música');
  });
}
