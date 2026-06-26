import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class FlexibleImage extends StatelessWidget {
  const FlexibleImage({
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorIcon = Icons.broken_image_outlined,
    super.key,
  });

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData errorIcon;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataUriBytes(source);
    if (bytes != null) {
      return Image.memory(bytes, width: width, height: height, fit: fit);
    }

    if (source.trim().isEmpty) {
      return _ErrorImage(icon: errorIcon, width: width, height: height);
    }

    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          _ErrorImage(icon: errorIcon, width: width, height: height),
    );
  }

  Uint8List? _dataUriBytes(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('data:image/')) return null;
    final commaIndex = trimmed.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return base64Decode(trimmed.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}

class _ErrorImage extends StatelessWidget {
  const _ErrorImage({required this.icon, this.width, this.height});

  final IconData icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(icon),
      ),
    );
  }
}
