import 'package:flutter/material.dart';
import '../../core/services/offline_listing_queue.dart';
import '../../data/models/pending_listing.dart';


class PendingUploadsBanner extends StatefulWidget {
  const PendingUploadsBanner({super.key});

  @override
  State<PendingUploadsBanner> createState() => _PendingUploadsBannerState();
}

class _PendingUploadsBannerState extends State<PendingUploadsBanner> {
  final _queue = OfflineListingQueue.instance;
  List<PendingListing> _pendingListings = [];

  @override
  void initState() {
    super.initState();
    _loadPendingListings();
    _queue.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) {
      _loadPendingListings();
    }
  }

  void _loadPendingListings() {
    setState(() {
      _pendingListings = _queue.pendingListings
          .where((l) => !l.isCompleted)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingListings.isEmpty) {
      return const SizedBox.shrink();
    }

    final uploadingCount = _pendingListings.where((l) => l.isUploading).length;
    final pendingCount = _pendingListings.where((l) => l.status == 'pending').length;
    final failedCount = _pendingListings.where((l) => l.isFailed).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uploadingCount > 0 
            ? Colors.blue.shade50 
            : failedCount > 0 
                ? Colors.red.shade50 
                : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: uploadingCount > 0 
              ? Colors.blue.shade300 
              : failedCount > 0 
                  ? Colors.red.shade300 
                  : Colors.orange.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (uploadingCount > 0)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  failedCount > 0 ? Icons.error_outline : Icons.cloud_upload_outlined,
                  color: failedCount > 0 ? Colors.red.shade700 : Colors.orange.shade700,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStatusMessage(uploadingCount, pendingCount, failedCount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: uploadingCount > 0 
                        ? Colors.blue.shade900 
                        : failedCount > 0 
                            ? Colors.red.shade900 
                            : Colors.orange.shade900,
                  ),
                ),
              ),
              if (failedCount > 0)
                TextButton(
                  onPressed: () => _showPendingListingsDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Ver', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (_pendingListings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._pendingListings.take(2).map((listing) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Icon(
                    listing.isUploading 
                        ? Icons.upload 
                        : listing.isFailed 
                            ? Icons.error 
                            : Icons.schedule,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      listing.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (listing.isUploading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                ],
              ),
            )),
            if (_pendingListings.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 24),
                child: Text(
                  '+ ${_pendingListings.length - 2} más',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _getStatusMessage(int uploading, int pending, int failed) {
    if (uploading > 0) {
      return uploading == 1 
          ? 'Subiendo 1 publicación...' 
          : 'Subiendo $uploading publicaciones...';
    }
    
    if (failed > 0) {
      return failed == 1 
          ? '1 publicación falló' 
          : '$failed publicaciones fallaron';
    }
    
    return pending == 1 
        ? '1 publicación pendiente' 
        : '$pending publicaciones pendientes';
  }

  void _showPendingListingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicaciones Pendientes'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _pendingListings.length,
            itemBuilder: (context, index) {
              final listing = _pendingListings[index];
              return ListTile(
                leading: Icon(
                  listing.isUploading 
                      ? Icons.upload 
                      : listing.isFailed 
                          ? Icons.error 
                          : Icons.schedule,
                  color: listing.isUploading 
                      ? Colors.blue 
                      : listing.isFailed 
                          ? Colors.red 
                          : Colors.orange,
                ),
                title: Text(listing.title),
                subtitle: Text(
                  listing.isFailed 
                      ? 'Error: ${listing.errorMessage ?? "Desconocido"}' 
                      : listing.isUploading 
                          ? 'Subiendo...' 
                          : 'Esperando conexión',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: listing.isFailed
                    ? IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _queue.retry(listing.id);
                          Navigator.of(context).pop();
                        },
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

