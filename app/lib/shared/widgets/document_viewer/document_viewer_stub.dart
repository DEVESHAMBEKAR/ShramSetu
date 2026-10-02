import 'package:flutter/material.dart';

Widget buildPdfPlatformView(String url, {Key? key}) {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf, size: 40, color: Colors.redAccent),
          const SizedBox(height: 10),
          const Text(
            'PDF Document',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'PDF document preview is active.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}

void openInNewTab(String url) {
  // Stub for non-web environments
}
