import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

final receiptShareServiceProvider = Provider<ReceiptShareService>((ref) {
  return SharePlusReceiptShareService();
});

final receiptImageExporterProvider = Provider<ReceiptImageExporter>((ref) {
  return RepaintBoundaryReceiptImageExporter();
});

final receiptPdfExporterProvider = Provider<ReceiptPdfExporter>((ref) {
  return PdfReceiptPdfExporter();
});

final receiptClipboardServiceProvider = Provider<ReceiptClipboardService>((
  ref,
) {
  return SystemReceiptClipboardService();
});

final receiptExportCoordinatorProvider = Provider<ReceiptExportCoordinator>((
  ref,
) {
  return DefaultReceiptExportCoordinator(
    imageExporter: ref.watch(receiptImageExporterProvider),
    pdfExporter: ref.watch(receiptPdfExporterProvider),
    shareService: ref.watch(receiptShareServiceProvider),
    clipboardService: ref.watch(receiptClipboardServiceProvider),
  );
});

enum ReceiptExportResult { shared, copied }

abstract interface class ReceiptExportCoordinator {
  Future<ReceiptExportResult> exportReceipt({
    required GlobalKey boundaryKey,
    required String text,
    required String subject,
    required String imageFileName,
    required String pdfFileName,
    Rect? sharePositionOrigin,
  });
}

class DefaultReceiptExportCoordinator implements ReceiptExportCoordinator {
  const DefaultReceiptExportCoordinator({
    required this.imageExporter,
    required this.pdfExporter,
    required this.shareService,
    required this.clipboardService,
  });

  final ReceiptImageExporter imageExporter;
  final ReceiptPdfExporter pdfExporter;
  final ReceiptShareService shareService;
  final ReceiptClipboardService clipboardService;

  @override
  Future<ReceiptExportResult> exportReceipt({
    required GlobalKey boundaryKey,
    required String text,
    required String subject,
    required String imageFileName,
    required String pdfFileName,
    Rect? sharePositionOrigin,
  }) async {
    Uint8List? imageBytes;
    Uint8List? pdfBytes;

    try {
      imageBytes = await imageExporter.capturePng(boundaryKey);
    } catch (_) {
      imageBytes = null;
    }
    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        pdfBytes = await pdfExporter.buildPdf(imageBytes: imageBytes);
      } catch (_) {
        pdfBytes = null;
      }
    }

    try {
      await shareService.shareReceipt(
        text: text,
        subject: subject,
        imageBytes: imageBytes,
        fileName: imageFileName,
        pdfBytes: pdfBytes,
        pdfFileName: pdfFileName,
        sharePositionOrigin: sharePositionOrigin,
      );
      return ReceiptExportResult.shared;
    } catch (_) {
      if (imageBytes != null || pdfBytes != null) {
        try {
          await shareService.shareReceipt(
            text: text,
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          );
          return ReceiptExportResult.shared;
        } catch (_) {
          // Fall through to a local text copy when platform sharing is absent.
        }
      }
    }

    await clipboardService.copy(text);
    return ReceiptExportResult.copied;
  }
}

abstract class ReceiptShareService {
  Future<void> shareReceipt({
    required String text,
    required String subject,
    Uint8List? imageBytes,
    String? fileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Rect? sharePositionOrigin,
  });
}

abstract interface class ReceiptClipboardService {
  Future<void> copy(String text);
}

class SystemReceiptClipboardService implements ReceiptClipboardService {
  @override
  Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}

class SharePlusReceiptShareService implements ReceiptShareService {
  @override
  Future<void> shareReceipt({
    required String text,
    required String subject,
    Uint8List? imageBytes,
    String? fileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Rect? sharePositionOrigin,
  }) async {
    final imageFileName = fileName ?? 'receipt.png';
    final pdfName = pdfFileName ?? 'receipt.pdf';
    final files = <XFile>[];
    final fileNameOverrides = <String>[];
    if (imageBytes != null && imageBytes.isNotEmpty) {
      files.add(
        XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: imageFileName,
        ),
      );
      fileNameOverrides.add(imageFileName);
    }
    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      files.add(
        XFile.fromData(
          pdfBytes,
          mimeType: 'application/pdf',
          name: pdfName,
        ),
      );
      fileNameOverrides.add(pdfName);
    }
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: subject,
        subject: subject,
        files: files.isEmpty ? null : files,
        fileNameOverrides: fileNameOverrides.isEmpty ? null : fileNameOverrides,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

abstract class ReceiptImageExporter {
  Future<Uint8List> capturePng(GlobalKey boundaryKey);
}

class RepaintBoundaryReceiptImageExporter implements ReceiptImageExporter {
  @override
  Future<Uint8List> capturePng(GlobalKey boundaryKey) async {
    await Future<void>.delayed(Duration.zero);
    final context = boundaryKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Receipt boundary is not ready.');
    }
    final image = await renderObject.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Could not export receipt image.');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

abstract class ReceiptPdfExporter {
  Future<Uint8List> buildPdf({required Uint8List imageBytes});
}

class PdfReceiptPdfExporter implements ReceiptPdfExporter {
  @override
  Future<Uint8List> buildPdf({required Uint8List imageBytes}) async {
    if (imageBytes.isEmpty) {
      throw StateError('Receipt image is required for PDF export.');
    }
    final document = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    return document.save();
  }
}
