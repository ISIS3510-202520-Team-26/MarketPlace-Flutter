/// Modelo de Foto de Listing (ListingPhoto)
/// 
/// Representa una foto asociada a un listing.
/// Basado en el schema del backend PostgreSQL.
class ListingPhoto {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del listing al que pertenece la foto
  final String listingId;
  
  /// Clave de almacenamiento en el storage (S3/MinIO)
  final String storageKey;
  
  /// URL de la imagen (opcional, puede ser generada on-demand)
  final String? imageUrl;
  
  /// URL de preview (alias para imageUrl, usado en algunos endpoints)
  String? get previewUrl => imageUrl;
  
  /// Ancho de la imagen en píxeles (opcional)
  final int? width;
  
  /// Alto de la imagen en píxeles (opcional)
  final int? height;
  
  /// Fecha de creación de la foto
  final DateTime createdAt;

  const ListingPhoto({
    required this.id,
    required this.listingId,
    required this.storageKey,
    this.imageUrl,
    this.width,
    this.height,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  factory ListingPhoto.fromJson(Map<String, dynamic> json) {
    return ListingPhoto(
      id: (json['id'] ?? json['uuid']).toString(),
      listingId: (json['listing_id'] ?? json['listingId']).toString(),
      storageKey: json['storage_key'] as String,
      imageUrl: (json['image_url'] ?? json['preview_url'])?.toString(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'storage_key': storageKey,
      if (imageUrl != null) 'image_url': imageUrl,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
  }

  /// Verifica si tiene URL de imagen disponible
  bool get hasImageUrl => imageUrl != null && imageUrl!.isNotEmpty;
  
  /// Verifica si tiene dimensiones disponibles
  bool get hasDimensions => width != null && height != null;
  
  /// Calcula el aspect ratio si tiene dimensiones
  double? get aspectRatio => 
      (width != null && height != null && height! > 0) 
          ? width! / height! 
          : null;

  /// Copia la instancia con campos modificados
  ListingPhoto copyWith({
    String? id,
    String? listingId,
    String? storageKey,
    String? imageUrl,
    int? width,
    int? height,
    DateTime? createdAt,
  }) {
    return ListingPhoto(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      storageKey: storageKey ?? this.storageKey,
      imageUrl: imageUrl ?? this.imageUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ListingPhoto(id: $id, listingId: $listingId, storageKey: $storageKey, hasImageUrl: $hasImageUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingPhoto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listingId == other.listingId &&
          storageKey == other.storageKey &&
          imageUrl == other.imageUrl &&
          width == other.width &&
          height == other.height &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, listingId, storageKey, imageUrl, width, height, createdAt);
}

/// Request para obtener URL presigned para subir imagen
class PresignRequest {
  final String listingId;
  final String filename;
  final String contentType;

  const PresignRequest({
    required this.listingId,
    required this.filename,
    required this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'filename': filename,
      'content_type': contentType,
    };
  }
}

/// Response con URL presigned para subir imagen
class PresignResponse {
  final String uploadUrl;
  final String objectKey;

  const PresignResponse({
    required this.uploadUrl,
    required this.objectKey,
  });

  factory PresignResponse.fromJson(Map<String, dynamic> json) {
    return PresignResponse(
      uploadUrl: json['upload_url'] as String,
      objectKey: json['object_key'] as String,
    );
  }
}

/// Request para confirmar subida de imagen
class ConfirmUploadRequest {
  final String listingId;
  final String objectKey;

  const ConfirmUploadRequest({
    required this.listingId,
    required this.objectKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'object_key': objectKey,
    };
  }
}

/// Response con URL de preview de imagen
class ConfirmUploadResponse {
  final String previewUrl;

  const ConfirmUploadResponse({required this.previewUrl});

  factory ConfirmUploadResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmUploadResponse(
      previewUrl: json['preview_url'] as String,
    );
  }
}
