import 'package:web/web.dart' as web;

Future<String?> getSsoSessionJson(String projectRef) async {
  final cookieString = web.document.cookie;
  final prefix = 'sb-$projectRef-auth-token';
  
  // Try single cookie first
  final match = RegExp('(^| )$prefix=([^;]+)').firstMatch(cookieString);
  if (match != null) {
    return Uri.decodeComponent(match.group(2)!);
  }
  
  // If not found, try chunked cookies
  String chunkedData = '';
  int i = 0;
  while (true) {
    final chunkMatch = RegExp('(^| )$prefix.$i=([^;]+)').firstMatch(cookieString);
    if (chunkMatch == null) break;
    chunkedData += Uri.decodeComponent(chunkMatch.group(2)!);
    i++;
  }
  
  if (chunkedData.isNotEmpty) {
    return chunkedData;
  }
  
  return null;
}
