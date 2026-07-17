import 'package:image_picker/image_picker.dart';

import '../data/topup_repository.dart';

Future<TopupSlipUpload?> pickTopupSlipUpload() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 92,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  return TopupSlipUpload(
    filename: file.name.isEmpty ? 'topup-slip.jpg' : file.name,
    bytes: bytes,
  );
}
