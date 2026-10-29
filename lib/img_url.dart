/// Returns a smaller, auto-format version of a Cloudinary image for display.
/// Any other URL (or an already transformed one) is returned unchanged, and
/// the stored URL in Firestore is never modified.
String thumb(String? url, int width) {
  if (url == null || url.isEmpty) return url ?? '';
  const marker = '/image/upload/';
  final i = url.indexOf(marker);
  if (!url.contains('res.cloudinary.com') || i < 0) return url;
  final rest = url.substring(i + marker.length);
  // Already has a transformation (e.g. "w_300,c_fill/") - leave it alone.
  if (RegExp(r'^[a-z]{1,3}_[^/]*/').hasMatch(rest)) return url;
  return '${url.substring(0, i + marker.length)}w_$width,q_auto,f_auto/$rest';
}
