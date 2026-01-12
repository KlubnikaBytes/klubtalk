import 'dart:html' as html;
import 'dart:typed_data';

String createImageUrlFromBytes(Uint8List bytes, {String? mimeType}) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}
