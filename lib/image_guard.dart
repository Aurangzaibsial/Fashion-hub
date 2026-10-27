import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Address of the FastAPI recommender / image-safety backend.
/// Override for a device or deployed server:
///   flutter run --dart-define=RECOMMENDER_URL=http://192.168.1.5:8000
const String kRecommenderUrl = String.fromEnvironment(
  'RECOMMENDER_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

/// Result of [checkImage].
class ImageCheck {
  /// The image passed the checks.
  final bool allowed;

  /// The backend could not be reached or gave an unreadable answer, so the
  /// image was NOT verified (and must not be accepted).
  final bool unverified;

  /// The backend's rejection detail (shown in the Security Alert dialog).
  final dynamic detail;

  const ImageCheck._(this.allowed, this.unverified, this.detail);
  const ImageCheck.ok() : this._(true, false, null);
  const ImageCheck.rejected(dynamic detail) : this._(false, false, detail);
  const ImageCheck.unverified() : this._(false, true, null);
}

/// Sends [bytes] to the backend's /validate-image endpoint.
///
/// [mode] is `wardrobe` (must be clothing / footwear / accessory) or `safety`
/// (only rejects weapons, gore and similar - for profile / community photos).
///
/// Fails closed: if the backend cannot be reached the image is reported as
/// unverified instead of being accepted.
Future<ImageCheck> checkImage({
  required Uint8List bytes,
  required String userId,
  String action = 'wardrobe_upload',
  String mode = 'wardrobe',
}) async {
  try {
    final uri = Uri.parse(
      '$kRecommenderUrl/validate-image'
      '?userId=${Uri.encodeComponent(userId)}'
      '&action=${Uri.encodeComponent(action)}'
      '&mode=$mode',
    );
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();
    final data = json.decode(body);

    if (response.statusCode == 200) return const ImageCheck.ok();
    if (response.statusCode == 400 && data is Map && data['detail'] != null) {
      return ImageCheck.rejected(data['detail']);
    }
    return const ImageCheck.unverified();
  } catch (e) {
    debugPrint('Image check failed (backend offline or too slow): $e');
    return const ImageCheck.unverified();
  }
}

/// Tells the user an image was not accepted: the Security Alert dialog for a
/// rejected image, or a snackbar when it could not be verified.
void showImageRejection(BuildContext context, ImageCheck result) {
  if (result.unverified) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
        "Couldn't verify this image right now. Please check your connection and try again.",
      ),
    ));
    return;
  }
  showSecurityAlert(context, result.detail);
}

/// The red "Security Alert" dialog shown for every unauthorized image.
void showSecurityAlert(BuildContext ctx, dynamic detail) {
  String message =
      'The selected image is not permitted. Weapons, violence, and non-wardrobe objects are strictly forbidden.';
  if (detail is Map && detail['message'] != null) {
    message = detail['message'].toString();
  } else if (detail is String) {
    message = detail;
  }

  showDialog(
    context: ctx,
    builder: (alertCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text(
            'Security Alert',
            style: TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.red, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This violation has been logged and sent to the Admin Dashboard for security moderation.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(alertCtx),
          child: const Text('Understood', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
