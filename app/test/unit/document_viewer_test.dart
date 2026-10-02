import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/shared/widgets/document_viewer/document_viewer_modal.dart';

void main() {
  setUpAll(() {
    DI.setup();
  });

  group('DocumentViewer Utilities', () {
    test('formatBytes formats bytes correctly across sizes', () {
      expect(DocumentViewerModal.formatBytes(0), '0 B');
      expect(DocumentViewerModal.formatBytes(500), '500 B');
      expect(DocumentViewerModal.formatBytes(1024), '1.0 KB');
      expect(DocumentViewerModal.formatBytes(355400), '347.1 KB');
      expect(DocumentViewerModal.formatBytes(1048576), '1.0 MB');
      expect(DocumentViewerModal.formatBytes(5242880), '5.0 MB');
    });

    test('formatDocType formats string snake_case to readable uppercase', () {
      expect(DocumentViewerModal.formatDocType('ADDRESS'), 'ADDRESS');
      expect(DocumentViewerModal.formatDocType('SKILL_CERTIFICATE'), 'SKILL CERTIFICATE');
      expect(DocumentViewerModal.formatDocType('IDENTITY_PROOF'), 'IDENTITY PROOF');
      expect(DocumentViewerModal.formatDocType(''), 'DOCUMENT');
      expect(DocumentViewerModal.formatDocType(null), 'DOCUMENT');
    });
  });

  group('DocumentViewerModal Widget Tests', () {
    testWidgets('renders PDF document viewer with header and metadata', (tester) async {
      final doc = {
        'id': 'doc-123',
        'file_name': 'OMKAREPIC11zon.pdf',
        'document_type': 'ADDRESS',
        'storage_path': 'workers/w1/ADDRESS-123.pdf',
        'file_size': 363929,
        'mime_type': 'application/pdf',
        'status': 'PENDING',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DocumentViewerModal.show(
                  ctx,
                  doc: doc,
                  isAdmin: true,
                  onApprove: () {},
                  onFlag: () {},
                ),
                child: const Text('Open Viewer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check header info
      expect(find.text('OMKAREPIC11zon.pdf'), findsOneWidget);
      expect(find.text('ADDRESS'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Approve Document'), findsOneWidget);
      expect(find.text('Flag for Resubmission'), findsOneWidget);
    });

    testWidgets('calls onApprove when Approve Document button is tapped', (tester) async {
      bool approved = false;
      final doc = {
        'id': 'doc-456',
        'file_name': 'aadhaar_scan.jpg',
        'document_type': 'IDENTITY',
        'storage_path': 'workers/w1/aadhaar.jpg',
        'file_size': 120400,
        'mime_type': 'image/jpeg',
        'status': 'PENDING',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DocumentViewerModal.show(
                  ctx,
                  doc: doc,
                  isAdmin: true,
                  onApprove: () => approved = true,
                ),
                child: const Text('Open Image Viewer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Image Viewer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Approve Document'), findsOneWidget);
      await tester.tap(find.text('Approve Document'));
      await tester.pumpAndSettle();

      expect(approved, isTrue);
    });

    testWidgets('shows graceful error message when storage path is empty', (tester) async {
      final doc = {
        'id': 'doc-err',
        'file_name': 'broken_file.pdf',
        'document_type': 'SKILL_CERTIFICATE',
        'storage_path': '',
        'file_size': 0,
        'mime_type': 'application/pdf',
        'status': 'PENDING',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DocumentViewerModal.show(ctx, doc: doc),
                child: const Text('Open Broken'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Broken'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Document Preview Unavailable'), findsOneWidget);
      expect(find.text('No storage path provided for this document record.'), findsOneWidget);
    });
  });
}
