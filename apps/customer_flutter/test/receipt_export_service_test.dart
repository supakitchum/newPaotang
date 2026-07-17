import 'dart:typed_data';

import 'package:customer_flutter/shared/services/receipt_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receipt export shares rendered PNG and PDF', () async {
    final image = _FakeImageExporter(Uint8List.fromList([1, 2, 3]));
    final pdf = _FakePdfExporter(Uint8List.fromList([4, 5, 6]));
    final share = _RecordingShareService();
    final clipboard = _RecordingClipboardService();
    final coordinator = DefaultReceiptExportCoordinator(
      imageExporter: image,
      pdfExporter: pdf,
      shareService: share,
      clipboardService: clipboard,
    );

    final result = await coordinator.exportReceipt(
      boundaryKey: GlobalKey(),
      text: 'receipt text',
      subject: 'receipt subject',
      imageFileName: 'receipt.png',
      pdfFileName: 'receipt.pdf',
    );

    expect(result, ReceiptExportResult.shared);
    expect(pdf.receivedImageBytes, image.bytes);
    expect(share.calls, hasLength(1));
    expect(share.calls.single.imageBytes, image.bytes);
    expect(share.calls.single.pdfBytes, pdf.bytes);
    expect(share.calls.single.fileName, 'receipt.png');
    expect(share.calls.single.pdfFileName, 'receipt.pdf');
    expect(clipboard.text, isEmpty);
  });

  test('receipt export falls back to text sharing when capture fails',
      () async {
    final share = _RecordingShareService();
    final clipboard = _RecordingClipboardService();
    final coordinator = DefaultReceiptExportCoordinator(
      imageExporter: _ThrowingImageExporter(),
      pdfExporter: _FakePdfExporter(Uint8List.fromList([4, 5, 6])),
      shareService: share,
      clipboardService: clipboard,
    );

    final result = await coordinator.exportReceipt(
      boundaryKey: GlobalKey(),
      text: 'receipt text',
      subject: 'receipt subject',
      imageFileName: 'receipt.png',
      pdfFileName: 'receipt.pdf',
    );

    expect(result, ReceiptExportResult.shared);
    expect(share.calls, hasLength(1));
    expect(share.calls.single.imageBytes, isNull);
    expect(share.calls.single.pdfBytes, isNull);
    expect(clipboard.text, isEmpty);
  });

  test('receipt export copies text after file and text sharing fail', () async {
    final share = _RecordingShareService(failAll: true);
    final clipboard = _RecordingClipboardService();
    final coordinator = DefaultReceiptExportCoordinator(
      imageExporter: _FakeImageExporter(Uint8List.fromList([1, 2, 3])),
      pdfExporter: _FakePdfExporter(Uint8List.fromList([4, 5, 6])),
      shareService: share,
      clipboardService: clipboard,
    );

    final result = await coordinator.exportReceipt(
      boundaryKey: GlobalKey(),
      text: 'receipt text',
      subject: 'receipt subject',
      imageFileName: 'receipt.png',
      pdfFileName: 'receipt.pdf',
    );

    expect(result, ReceiptExportResult.copied);
    expect(share.calls, hasLength(2));
    expect(share.calls.first.imageBytes, isNotNull);
    expect(share.calls.last.imageBytes, isNull);
    expect(share.calls.last.pdfBytes, isNull);
    expect(clipboard.text, 'receipt text');
  });
}

class _FakeImageExporter implements ReceiptImageExporter {
  _FakeImageExporter(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> capturePng(GlobalKey boundaryKey) async => bytes;
}

class _ThrowingImageExporter implements ReceiptImageExporter {
  @override
  Future<Uint8List> capturePng(GlobalKey boundaryKey) {
    throw StateError('capture unavailable');
  }
}

class _FakePdfExporter implements ReceiptPdfExporter {
  _FakePdfExporter(this.bytes);

  final Uint8List bytes;
  Uint8List? receivedImageBytes;

  @override
  Future<Uint8List> buildPdf({required Uint8List imageBytes}) async {
    receivedImageBytes = imageBytes;
    return bytes;
  }
}

class _RecordingShareService implements ReceiptShareService {
  _RecordingShareService({this.failAll = false});

  final bool failAll;
  final calls = <_ShareCall>[];

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
    calls.add(
      _ShareCall(
        imageBytes: imageBytes,
        fileName: fileName,
        pdfBytes: pdfBytes,
        pdfFileName: pdfFileName,
      ),
    );
    if (failAll) throw StateError('share unavailable');
  }
}

class _ShareCall {
  const _ShareCall({
    required this.imageBytes,
    required this.fileName,
    required this.pdfBytes,
    required this.pdfFileName,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final Uint8List? pdfBytes;
  final String? pdfFileName;
}

class _RecordingClipboardService implements ReceiptClipboardService {
  String text = '';

  @override
  Future<void> copy(String text) async {
    this.text = text;
  }
}
