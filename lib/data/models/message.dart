/// Modelo de Mensaje (Message)
/// 
/// Representa un mensaje dentro de un chat.
/// Basado en el schema del backend PostgreSQL.
class Message {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del chat al que pertenece el mensaje
  final String chatId;
  
  /// ID del usuario que envió el mensaje
  final String senderId;
  
  /// Tipo de mensaje: "text", "image", "system"
  final String messageType;
  
  /// Contenido del mensaje (opcional, máx 4000 caracteres)
  /// Para mensajes de texto: el texto
  /// Para mensajes de imagen: URL de la imagen
  /// Para mensajes de sistema: descripción del evento
  final String? content;
  
  /// Fecha de creación del mensaje
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.messageType,
    this.content,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? json['uuid']).toString(),
      chatId: (json['chat_id'] ?? json['chatId']).toString(),
      senderId: (json['sender_id'] ?? json['senderId']).toString(),
      messageType: (json['message_type'] ?? json['messageType'] ?? 'text') as String,
      content: json['content']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema MessageCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'message_type': messageType,
      if (content != null) 'content': content,
    };
  }

  /// Verifica si el mensaje es de texto
  bool get isText => messageType.toLowerCase() == 'text';
  
  /// Verifica si el mensaje es una imagen
  bool get isImage => messageType.toLowerCase() == 'image';
  
  /// Verifica si el mensaje es del sistema
  bool get isSystem => messageType.toLowerCase() == 'system';
  
  /// Verifica si tiene contenido
  bool get hasContent => content != null && content!.isNotEmpty;

  /// Copia la instancia con campos modificados
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? messageType,
    String? content,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Message(id: $id, chatId: $chatId, senderId: $senderId, messageType: $messageType, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          chatId == other.chatId &&
          senderId == other.senderId &&
          messageType == other.messageType &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, chatId, senderId, messageType, content, createdAt);
}

/// Tipos de mensaje disponibles
class MessageType {
  static const String text = 'text';
  static const String image = 'image';
  static const String system = 'system';
  
  /// Lista de todos los tipos válidos
  static const List<String> all = [text, image, system];
  
  /// Verifica si un tipo es válido
  static bool isValid(String type) => all.contains(type.toLowerCase());
}
