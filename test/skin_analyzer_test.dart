import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:style_tone_ai/services/skin_analyzer.dart';

void main() {
  group('SkinAnalyzer', () {
    test('classifies warm peach skin as Spring', () async {
      final image = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          image.setPixelRgb(x, y, 235, 195, 145);
        }
      }
      final result = await processSelfie(image);
      expect(result, isNotNull);
      expect(result!['detected_category'], 'Warm Golden/Peach Skin Tone');
      expect(result['confidence'], greaterThan(0));
      expect(result['explanation'], isNotEmpty);
      expect(result['palettes'], isA<Map>());
      expect(
        (result['palettes'] as Map).keys,
        containsAll(['office', 'party', 'casual']),
      );
    });

    test('classifies cool rosy skin as Summer', () async {
      final image = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          image.setPixelRgb(x, y, 220, 200, 190);
        }
      }
      final result = await processSelfie(image);
      expect(result, isNotNull);
      expect(result!['detected_category'], 'Cool Rosy/Pink Skin Tone');
    });

    test('returns null for non-skin image', () async {
      final image = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          image.setPixelRgb(x, y, 0, 0, 0);
        }
      }
      final result = await processSelfie(image);
      expect(result, isNull);
    });
  });
}
