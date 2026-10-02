import 'package:flutter/material.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'document_viewer_platform.dart';

class DocumentViewerModal extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback? onApprove;
  final VoidCallback? onFlag;
  final bool isAdmin;

  const DocumentViewerModal({
    super.key,
    required this.doc,
    this.onApprove,
    this.onFlag,
    this.isAdmin = false,
  });

  /// Displays the modal dialog as a modern, high-fidelity in-app document viewer.
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> doc,
    VoidCallback? onApprove,
    VoidCallback? onFlag,
    bool isAdmin = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (ctx) => DocumentViewerModal(
        doc: doc,
        onApprove: onApprove,
        onFlag: onFlag,
        isAdmin: isAdmin,
      ),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String formatDocType(String? docType) {
    if (docType == null || docType.isEmpty) return 'DOCUMENT';
    return docType.replaceAll('_', ' ').toUpperCase();
  }

  @override
  State<DocumentViewerModal> createState() => _DocumentViewerModalState();
}

class _DocumentViewerModalState extends State<DocumentViewerModal> {
  bool _isLoading = true;
  String? _signedUrl;
  String? _errorMessage;
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadDocumentUrl();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentUrl() async {
    final storagePath = widget.doc['storage_path']?.toString() ?? '';
    if (storagePath.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No storage path provided for this document record.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = await DI.storageRepo.getSignedUrl(
        bucket: StorageBucket.workerDocuments,
        path: storagePath,
        expiresIn: 3600,
      );

      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load document: $e';
        });
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale * 1.25).clamp(0.5, 5.0);
      _transformationController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale / 1.25).clamp(0.5, 5.0);
      _transformationController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.doc['file_name']?.toString() ?? 'Document';
    final mimeType = widget.doc['mime_type']?.toString().toLowerCase() ?? '';
    final docType = widget.doc['document_type']?.toString() ?? 'DOCUMENT';
    final fileSize = (widget.doc['file_size'] as int?) ?? 0;
    final status = (widget.doc['status']?.toString() ?? 'PENDING').toUpperCase();

    final isPdf = mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
    final isImage = mimeType.contains('image') ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.webp');

    final screenSize = MediaQuery.of(context).size;
    final double dialogWidth = screenSize.width > 1000
        ? 940
        : (screenSize.width > 600 ? screenSize.width * 0.92 : screenSize.width * 0.96);
    final double dialogHeight = screenSize.height > 850
        ? 780
        : (screenSize.height > 600 ? screenSize.height * 0.88 : screenSize.height * 0.92);

    Color statusBadgeBg;
    Color statusBadgeText;
    if (status == 'APPROVED') {
      statusBadgeBg = const Color(0xFFE8F5E9);
      statusBadgeText = const Color(0xFF2E7D32);
    } else if (status == 'FLAGGED') {
      statusBadgeBg = const Color(0xFFFFEBEE);
      statusBadgeText = AppColors.error;
    } else {
      statusBadgeBg = const Color(0xFFFFF3E0);
      statusBadgeText = const Color(0xFFE65100);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPdf ? AppColors.errorContainer.withValues(alpha: 0.6) : AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.image,
                        size: 20,
                        color: isPdf ? AppColors.error : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fileName,
                            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  DocumentViewerModal.formatDocType(docType),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ),
                              if (fileSize > 0)
                                Text(
                                  DocumentViewerModal.formatBytes(fileSize),
                                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusBadgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusBadgeText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isImage && _signedUrl != null) ...[
                      IconButton(
                        tooltip: 'Zoom In',
                        icon: const Icon(Icons.zoom_in, size: 20),
                        onPressed: _zoomIn,
                      ),
                      IconButton(
                        tooltip: 'Zoom Out',
                        icon: const Icon(Icons.zoom_out, size: 20),
                        onPressed: _zoomOut,
                      ),
                      IconButton(
                        tooltip: 'Reset View',
                        icon: const Icon(Icons.fit_screen, size: 18),
                        onPressed: _resetZoom,
                      ),
                    ],
                    if (_signedUrl != null)
                      IconButton(
                        tooltip: 'Open in new tab',
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => openInNewTab(_signedUrl!),
                      ),
                    IconButton(
                      tooltip: 'Close viewer',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Document Content Area
              Expanded(
                child: Container(
                  color: isImage ? const Color(0xFF1E2024) : AppColors.surfaceContainerLow,
                  child: _buildDocumentBody(isPdf: isPdf, isImage: isImage),
                ),
              ),

              // 3. Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_clock_outlined, size: 14, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Text(
                          'Secure Signed View • Valid 1 Hour',
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.isAdmin && widget.onFlag != null && status != 'FLAGGED')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onFlag?.call();
                            },
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: const Text('Flag for Resubmission', style: TextStyle(fontSize: 12)),
                          ),
                        if (widget.isAdmin && widget.onApprove != null && status != 'APPROVED')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onApprove?.call();
                            },
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve Document', style: TextStyle(fontSize: 12)),
                          ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentBody({required bool isPdf, required bool isImage}) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Loading document preview...',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Document Preview Unavailable',
                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDocumentUrl,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_signedUrl == null) {
      return const Center(child: Text('Document URL could not be resolved.'));
    }

    // 1. PDF Document
    if (isPdf) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: buildPdfPlatformView(_signedUrl!),
      );
    }

    // 2. Image Document (JPG, PNG, WEBP)
    if (isImage) {
      return InteractiveViewer(
        transformationController: _transformationController,
        clipBehavior: Clip.antiAlias,
        minScale: 0.5,
        maxScale: 6.0,
        child: Center(
          child: Image.network(
            _signedUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final total = loadingProgress.expectedTotalBytes;
              final loaded = loadingProgress.cumulativeBytesLoaded;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: total != null && total > 0 ? loaded / total : null,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Downloading image... ${total != null && total > 0 ? '${(loaded / 1024).toStringAsFixed(0)} / ${(total / 1024).toStringAsFixed(0)} KB' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined, size: 48, color: Colors.white54),
                    const SizedBox(height: 8),
                    const Text('Failed to render image preview', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => openInNewTab(_signedUrl!),
                      child: const Text('Open in Browser'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // 3. Fallback for unrecognized mime-type (embed anyway via platform view)
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: buildPdfPlatformView(_signedUrl!),
    );
  }
}
