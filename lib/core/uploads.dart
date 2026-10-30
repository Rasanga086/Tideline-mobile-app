import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

/// Upload rules mirror DocumentStorageService on the backend (the server re-checks by file content):
/// photos are JPG/PNG/WebP up to 8 MB; account documents are PDF/JPG/PNG up to 5 MB.
const maxPhotoBytes = 8 * 1024 * 1024;
const maxDocumentBytes = 5 * 1024 * 1024;
const maxAvatarBytes = 5 * 1024 * 1024;

const imageContentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

const documentContentTypes = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
};

String extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// The document extension for [head] (the first bytes of a file) judged by its content, or
/// null. Some Android pickers hand back names with no extension; the server also checks content.
String? sniffDocumentExtension(List<int> head) {
  bool starts(List<int> m) =>
      head.length >= m.length &&
      [for (var i = 0; i < m.length; i++) head[i] == m[i]].every((b) => b);
  if (starts([0x25, 0x50, 0x44, 0x46])) return 'pdf';
  if (starts([0xFF, 0xD8, 0xFF])) return 'jpg';
  if (starts([0x89, 0x50, 0x4E, 0x47])) return 'png';
  return null;
}

/// Null if [name]/[bytes] is an acceptable photo, else why not.
String? checkImage(String name, int bytes, {int maxBytes = maxPhotoBytes}) {
  if (!imageContentTypes.containsKey(extensionOf(name))) {
    return '$name is not a supported photo. Use JPG, PNG or WebP.';
  }
  if (bytes > maxBytes) {
    return '$name is larger than ${maxBytes ~/ (1024 * 1024)} MB.';
  }
  return null;
}

/// Null if [name]/[bytes] is an acceptable certificate or licence, else why not.
String? checkDocument(String name, int bytes) {
  if (!documentContentTypes.containsKey(extensionOf(name))) {
    return '$name is not a PDF, JPG or PNG file.';
  }
  if (bytes > maxDocumentBytes) return '$name is larger than 5 MB.';
  return null;
}

/// A file the user picked, independent of which picker produced it. Either a file [path]
/// (streamed) or in-memory [bytes] (content URIs that have no path).
class PickedUpload {
  PickedUpload({
    required this.name,
    required this.size,
    this.path,
    this.bytes,
    this.read,
  });
  final String name;
  final int size;
  final String? path;
  final Uint8List? bytes;

  /// Reads the contents on demand when there is neither a file [path] nor loaded [bytes]
  /// (e.g. a content:// URI on Android).
  final Future<Uint8List> Function()? read;
}

/// A picker failure with a message that is fit to show the user.
class PickFailure implements Exception {
  PickFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<http.MultipartFile> uploadPart(String field, PickedUpload f) async {
  final types = {...imageContentTypes, ...documentContentTypes};
  final type = MediaType.parse(
    types[extensionOf(f.name)] ?? 'application/octet-stream',
  );
  if (f.path != null) {
    return http.MultipartFile.fromPath(
      field,
      f.path!,
      filename: f.name,
      contentType: type,
    );
  }
  final bytes = f.bytes ?? await f.read?.call();
  if (bytes == null) throw PickFailure('Could not read ${f.name}.');
  return http.MultipartFile.fromBytes(
    field,
    bytes,
    filename: f.name,
    contentType: type,
  );
}
