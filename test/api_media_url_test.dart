import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/config/api_config.dart';
import 'package:side_b/features/content/data/content_models.dart';

void main() {
  test('uses the API server for loopback and relative media URLs', () {
    for (final host in ['127.0.0.1', 'localhost', '[::1]']) {
      expect(
        ApiConfig.mediaUrl('http://$host:8000/media/cover.webp?v=2'),
        '${ApiConfig.baseUrl}/media/cover.webp?v=2',
      );
    }
    expect(ApiConfig.mediaUrl('/media/cover.webp'),
        '${ApiConfig.baseUrl}/media/cover.webp');
    expect(ApiConfig.mediaUrl('https://cdn.example.com/cover.webp'),
        'https://cdn.example.com/cover.webp');
    expect(ApiConfig.mediaUrl(null), isNull);
  });

  test('product images use reachable URLs throughout the gallery', () {
    final product = Product.fromJson({
      'id': 2,
      'nombre': 'AM',
      'precio': 399.0,
      'imagen': 'http://127.0.0.1:8000/media/cover.webp',
      'imagen_2': '/media/back.webp',
    });
    expect(product.image, '${ApiConfig.baseUrl}/media/cover.webp');
    expect(product.images, [
      '${ApiConfig.baseUrl}/media/cover.webp',
      '${ApiConfig.baseUrl}/media/back.webp',
    ]);
  });
}
