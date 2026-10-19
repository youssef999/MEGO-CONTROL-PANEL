import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Loads Firebase Storage HTTP URLs.
///
/// Keeps the project bucket `*.firebasestorage.app` (rewriting to `.appspot.com`
/// returns 404). On web, uses [WebHtmlElementStrategy.prefer] so images still
/// render when the bucket response lacks CORS headers for CanvasKit.
class FirebaseStorageImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? fallbackBackground;
  final Color? fallbackIconColor;

  const FirebaseStorageImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackBackground,
    this.fallbackIconColor,
  });

  /// Fixes legacy `.appspot.com` bucket URLs to `.firebasestorage.app`.
  static String? normalizeUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('firebasestorage.googleapis.com')) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('b') + 1;
    if (bucketIndex <= 0 || bucketIndex >= segments.length) return trimmed;
    final bucket = segments[bucketIndex];
    if (!bucket.endsWith('.appspot.com')) return trimmed;
    final fixedBucket = bucket.replaceAll('.appspot.com', '.firebasestorage.app');
    final fixedSegments = [...segments]..[bucketIndex] = fixedBucket;
    return uri.replace(pathSegments: fixedSegments).toString();
  }

  /// For [CircleAvatar] / [DecorationImage] — prefer [avatar] on web instead.
  static ImageProvider? networkProvider(String? raw) {
    final url = normalizeUrl(raw);
    if (url == null || url.isEmpty) return null;
    return NetworkImage(
      url,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    );
  }

  /// Web-safe circular profile image (avoids CORS issues with [CircleAvatar]
  /// + [NetworkImage] on Flutter web).
  static Widget avatar({
    String? imageUrl,
    String? label,
    double radius = 16,
    Color? backgroundColor,
    IconData emptyIcon = Icons.person_outline,
  }) {
    final size = radius * 2;
    final bg = backgroundColor ?? Colors.deepPurple.withOpacity(0.35);
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    final initial = (label != null && label.trim().isNotEmpty)
        ? label.trim()[0].toUpperCase()
        : null;

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: bg,
        alignment: Alignment.center,
        child: hasImage
            ? FirebaseStorageImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fallbackIcon: emptyIcon,
                fallbackBackground: bg,
                fallbackIconColor: Colors.white70,
              )
            : initial != null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.85,
                    ),
                  )
                : Icon(emptyIcon, color: Colors.white70, size: radius),
      ),
    );
  }

  @override
  State<FirebaseStorageImage> createState() => _FirebaseStorageImageState();
}

class _FirebaseStorageImageState extends State<FirebaseStorageImage> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolveUrl(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant FirebaseStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _future = _resolveUrl(widget.imageUrl);
    }
  }

  Future<String?> _resolveUrl(String? raw) async {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance.refFromURL(trimmed).getDownloadURL();
      } catch (_) {
        return null;
      }
    }
    return FirebaseStorageImage.normalizeUrl(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final resolved = snapshot.data;
        if (resolved == null || resolved.isEmpty) {
          return _fallback();
        }
        return Image.network(
          resolved,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      },
    );
  }

  Widget _fallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.fallbackBackground ?? Colors.grey[800],
      child: Icon(
        widget.fallbackIcon,
        color: widget.fallbackIconColor ?? Colors.grey,
      ),
    );
  }
}
