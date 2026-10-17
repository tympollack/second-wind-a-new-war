// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void clearUrlParameters() {
  final uri = Uri.parse(html.window.location.href);
  if (uri.queryParameters.isNotEmpty) {
    final newUri = uri.replace(queryParameters: {});
    html.window.history.replaceState(null, '', newUri.toString());
  }
}
