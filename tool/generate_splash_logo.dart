// Run with: dart run tool/generate_splash_logo.dart
// Requires: dart pub add image --dev

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const width = 512;
  const height = 512;
  
  // Create image with light background
  final image = img.Image(width: width, height: height);
  
  // Fill with background color #F6FBF8
  img.fill(image, color: img.ColorRgba8(246, 251, 248, 255));
  
  final centerX = width ~/ 2;
  final centerY = height ~/ 2;
  
  final green = img.ColorRgba8(0, 193, 123, 255); // #00C17B
  
  // Draw a stylized "V" checkmark logo
  // Left part of V
  for (int t = 0; t < 100; t++) {
    final x1 = centerX - 80 + t;
    final y1 = centerY - 60 + (t * 1.2).toInt();
    img.fillCircle(image, x: x1, y: y1, radius: 18, color: green);
  }
  
  // Right part of V (going up)
  for (int t = 0; t < 120; t++) {
    final x1 = centerX + 20 + (t * 0.8).toInt();
    final y1 = centerY + 60 - (t * 1.0).toInt();
    img.fillCircle(image, x: x1, y: y1, radius: 18, color: green);
  }
  
  // Add a small leaf accent at the top right
  for (int t = 0; t < 30; t++) {
    final x1 = centerX + 100 + (t * 0.3).toInt();
    final y1 = centerY - 60 - (t * 0.5).toInt();
    img.fillCircle(image, x: x1, y: y1, radius: 8 - (t * 0.2).toInt().clamp(0, 8), color: green);
  }
  
  // Save as PNG
  final outputPath = 'assets/images/splash_logo.png';
  File(outputPath).writeAsBytesSync(img.encodePng(image));
  // ignore: avoid_print
  print('✅ Generated: $outputPath');
  // ignore: avoid_print
  print('📍 Logo saved to: ${File(outputPath).absolute.path}');
}
