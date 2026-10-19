import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/imgbb_config.dart';

/// Picks an image, compresses to JPEG, uploads to [ImgBB](https://imgbb.com/) API, returns direct URL.
class ImgbbImageUploadService {
  ImgbbImageUploadService._();

  static const _uploadUrl = 'https://api.imgbb.com/1/upload';

  static Uint8List _compressToJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    var image = decoded;
    const maxW = 1200;
    if (image.width > maxW) {
      image = img.copyResize(image, width: maxW);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }

  /// Returns direct image URL for Supabase `image` fields, or `null` if user cancels picker.
  static Future<String?> pickCompressAndUpload() async {
    final key = ImgbbConfig.apiKey.trim();
    if (key.isEmpty) {
      throw StateError(
        'ImgBB API key missing. Get one at https://api.imgbb.com/ then run with '
        '--dart-define=IMGBB_API_KEY=your_key '
        'or set ImgbbConfig._devKey for local dev only.',
      );
    }

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (xFile == null) return null;

    var bytes = await xFile.readAsBytes();
    bytes = _compressToJpeg(bytes);

    final b64 = base64Encode(bytes);
    final uri = Uri.parse(_uploadUrl);

    final response = await http.post(
      uri,
      body: <String, String>{
        'key': key,
        'image': b64,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'ImgBB HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw Exception('ImgBB: invalid response');
    }
    if (json['success'] != true) {
      final err = json['error'];
      final msg =
          err is Map
              ? (err['message']?.toString() ?? err.toString())
              : err?.toString() ?? 'Unknown error';
      throw Exception('ImgBB: $msg');
    }
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('ImgBB: missing data');
    }
    final url = data['url'] as String?;
    final displayUrl = data['display_url'] as String?;
    final out = (url ?? displayUrl)?.trim();
    if (out == null || out.isEmpty) {
      throw Exception('ImgBB: no URL in response');
    }
    return out;
  }
}
