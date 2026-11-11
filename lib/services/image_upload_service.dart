import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Picks an image, compresses it to JPEG and uploads it to Firebase Storage
/// (same bucket + `driver_documents/<folder>/` layout as the partner app).
/// Returns the download URL stored in Supabase `image` columns.
class ImageUploadService {
  ImageUploadService._();

  static const folderRestaurants = 'restaurants';
  static const folderMenuItems = 'menu_items';
  static const folderCategories = 'categories';

  static const _maxEdge = 1600;
  static const _jpegQuality = 80;

  /// Longest side ≤ [_maxEdge], JPEG (drops EXIF / alpha).
  static Uint8List _compressToJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image file');
    }
    var image = decoded;
    final longest = max(image.width, image.height);
    if (longest > _maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(image, width: _maxEdge)
          : img.copyResize(image, height: _maxEdge);
    }
    image.exif.clear();
    return Uint8List.fromList(img.encodeJpg(image, quality: _jpegQuality));
  }

  static String _fileName() {
    final rand = Random().nextInt(1 << 30).toRadixString(36);
    return '${DateTime.now().millisecondsSinceEpoch}_$rand.jpg';
  }

  /// Returns the Firebase download URL, or `null` if the picker was cancelled.
  static Future<String?> pickCompressAndUpload({required String folder}) async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 95,
    );
    if (xFile == null) return null;

    final original = await xFile.readAsBytes();
    final compressed = _compressToJpeg(original);
    debugPrint(
      '📦 Image compressed ${(original.length / 1024).toStringAsFixed(0)} KB → '
      '${(compressed.length / 1024).toStringAsFixed(0)} KB',
    );

    final ref = FirebaseStorage.instance
        .ref()
        .child('driver_documents/$folder/${_fileName()}');
    await ref.putData(
      compressed,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    return ref.getDownloadURL();
  }
}
