// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _pdfViewCounter = 0;

Widget buildPdfPlatformView(String url, {Key? key}) {
  final viewType = 'shramsetu-pdf-${DateTime.now().microsecondsSinceEpoch}-${_pdfViewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('allowfullscreen', 'true');
      return iframe;
    },
  );

  return HtmlElementView(
    key: key,
    viewType: viewType,
  );
}

void openInNewTab(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (_) {}
}
