import 'package:flutter/material.dart';
import 'document_viewer_stub.dart'
    if (dart.library.html) 'document_viewer_web.dart' as platform;

Widget buildPdfPlatformView(String url, {Key? key}) {
  return platform.buildPdfPlatformView(url, key: key);
}

void openInNewTab(String url) {
  platform.openInNewTab(url);
}
