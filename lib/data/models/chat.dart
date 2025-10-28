/// Modelo de Chat
/// 
/// Representa una conversación entre comprador y vendedor sobre un listing específico.
/// Basado en el schema del backend PostgreSQL.
class Chat {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del listing sobre el que se está conversando
  final String listingId;
  
  /// Fecha de creación del chat
  final DateTime createdAt;
  
  /// Participantes del chat (opcional, solo en respuestas detalladas)
  final List<ChatParticipant>? participants;

  const Chat({
    required this.id,
    required this.listingId,
    required this.createdAt,
    this.participants,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: (json['id'] ?? json['uuid']).toString(),
      listingId: (json['listing_id'] ?? json['listingId']).toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema ChatCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
    };
  }

  /// Copia la instancia con campos modificados
  Chat copyWith({
    String? id,
    String? listingId,
    DateTime? createdAt,
    List<ChatParticipant>? participants,
  }) {
    return Chat(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      createdAt: createdAt ?? this.createdAt,
      participants: participants ?? this.participants,
    );
  }

  @override
  String toString() => 'Chat(id: $id, listingId: $listingId, createdAt: $createdAt, participants: ${participants?.length ?? 0})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chat &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listingId == other.listingId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, listingId, createdAt);
}

/// Modelo de Participante de Chat
/// 
/// Representa un usuario participando en un chat con un rol específico (buyer o seller).
class ChatParticipant {
  /// ID del chat
  final String chatId;
  
  /// ID del usuario
  final String userId;
  
  /// Rol del participante: "buyer" o "seller"
  final String role;
  
  /// Fecha en que se unió al chat
  final DateTime joinedAt;

  const ChatParticipant({
    required this.chatId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  /// Crea una instancia desde JSON del backend
  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      chatId: (json['chat_id'] ?? json['chatId']).toString(),
      userId: (json['user_id'] ?? json['userId']).toString(),
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  /// Convierte a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  /// Verifica si el participante es el comprador
  bool get isBuyer => role == 'buyer';
  
  /// Verifica si el participante es el vendedor
  bool get isSeller => role == 'seller';

  /// Copia la instancia con campos modificados
  ChatParticipant copyWith({
    String? chatId,
    String? userId,
    String? role,
    DateTime? joinedAt,
  }) {
    return ChatParticipant(
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  String toString() => 'ChatParticipant(chatId: $chatId, userId: $userId, role: $role, joinedAt: $joinedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParticipant &&
          runtimeType == other.runtimeType &&
          chatId == other.chatId &&
          userId == other.userId &&
          role == other.role &&
          joinedAt == other.joinedAt;

  @override
  int get hashCode => Object.hash(chatId, userId, role, joinedAt);
}
