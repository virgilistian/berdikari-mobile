import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Picks a photo from the camera or gallery and compresses it client-side
/// before it ever reaches [ApiClient.postMultipart] — a raw camera photo
/// can be several MB; shrinking it here keeps the upload fast and cheap on
/// a warung's mobile data before the server re-compresses it again anyway.
///
/// Abstract so [ProductFormViewModel] can be tested with a fake — real
/// camera/gallery access needs a platform channel `flutter test` can't
/// provide.
abstract class DeviceImageService {
  /// Returns null if the user cancels the camera/gallery picker.
  Future<File?> pickFromCamera();
  Future<File?> pickFromGallery();
}

class DeviceImageServiceImpl implements DeviceImageService {
  DeviceImageServiceImpl({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<File?> pickFromCamera() => _pickAndCompress(ImageSource.camera);

  @override
  Future<File?> pickFromGallery() => _pickAndCompress(ImageSource.gallery);

  Future<File?> _pickAndCompress(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return null;
    return _compress(File(picked.path));
  }

  /// Resizes to a 1024px-long-side JPEG at quality 80 — comfortably under
  /// 1 MB for a typical product photo, versus the 3-15 MB a modern phone
  /// camera produces straight out of the sensor.
  Future<File> _compress(File original) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      'product_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final result = await FlutterImageCompress.compressAndGetFile(
      original.path,
      targetPath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    // Compression can fail on an unsupported source format/platform — fall
    // back to the original file rather than blocking the upload; the
    // server re-compresses regardless (defense in depth, not the only cap).
    return result == null ? original : File(result.path);
  }
}
