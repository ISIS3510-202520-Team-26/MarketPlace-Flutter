import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';
import '../models/chat.dart';
import '../models/message.dart';

/// Repository for managing chats and messages in the messaging domain.
///
/// Handles:
/// - Chat creation with buyer/seller participants
/// - Chat retrieval with participants and listing info
/// - Message sending and retrieval
/// - Message pagination for chat history
/// - Unread message tracking
///
/// Backend integration:
/// - POST /chats - Create new chat for a listing
/// - GET /chats/{chat_id} - Get chat with participants
/// - GET /chats - List user's chats
/// - POST /messages - Send message in a chat
/// - GET /messages?chat_id={id} - Get messages for a chat
class MessagingRepository {
  final Dio _dio = DioClient.instance.dio;

  // ============================================================================
  // Chat Operations
  // ============================================================================

  /// Creates a new chat for a listing between buyer and seller.
  ///
  /// The current user becomes the buyer, and the listing owner becomes the seller.
  /// Backend validates that you're not trying to chat with yourself.
  ///
  /// Returns the created [Chat] with participants.
  ///
  /// Throws [DioException] if:
  /// - Listing not found (404)
  /// - Trying to chat with yourself (400)
  /// - Unauthorized (401)
  Future<Chat> createChat({
    required String listingId,
  }) async {
    try {
      final response = await _dio.post(
        '/chats',
        data: {
          'listing_id': listingId,
        },
      );

      return Chat.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Gets a chat by ID with all participants and listing information.
  ///
  /// Returns null if the chat doesn't exist or user doesn't have access.
  Future<Chat?> getChatById(String chatId) async {
    try {
      final response = await _dio.get('/chats/$chatId');
      return Chat.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e);
    }
  }

  /// Lists all chats for the current user.
  ///
  /// Returns chats where the user is either buyer or seller.
  /// Chats are typically sorted by last message timestamp (backend dependent).
  ///
  /// Optional filters:
  /// - [listingId]: Filter chats by listing
  /// - [limit]: Maximum number of chats to return
  /// - [offset]: Pagination offset
  Future<List<Chat>> getMyChats({
    String? listingId,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (listingId != null) queryParams['listing_id'] = listingId;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;

      final response = await _dio.get(
        '/chats',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final List<dynamic> data = response.data;
      return data.map((json) => Chat.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Gets or creates a chat for a listing.
  ///
  /// Convenience method that tries to find an existing chat for the listing
  /// and creates one if it doesn't exist.
  ///
  /// Useful for "Message Seller" buttons in the UI.
  Future<Chat> getOrCreateChat(String listingId) async {
    // First try to find existing chat
    final chats = await getMyChats(listingId: listingId, limit: 1);
    if (chats.isNotEmpty) {
      return chats.first;
    }

    // Create new chat if none exists
    return await createChat(listingId: listingId);
  }

  // ============================================================================
  // Message Operations
  // ============================================================================

  /// Sends a message in a chat.
  ///
  /// Backend validates that the user is a participant in the chat.
  /// Automatically triggers push notification to the other participant.
  ///
  /// [chatId]: The chat to send the message in
  /// [content]: Message text content (required for text messages)
  /// [messageType]: Type of message (text, image, location, etc.)
  ///
  /// Returns the created [Message].
  Future<Message> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final response = await _dio.post(
        '/messages',
        data: {
          'chat_id': chatId,
          'content': content,
          'message_type': messageType,
        },
      );

      return Message.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Gets messages for a chat with pagination.
  ///
  /// Returns messages in reverse chronological order (newest first).
  ///
  /// [chatId]: The chat to get messages for
  /// [limit]: Maximum number of messages to return (default backend limit)
  /// [offset]: Pagination offset for loading older messages
  /// [beforeMessageId]: Get messages before this message ID (cursor pagination)
  Future<MessagesPage> getMessages({
    required String chatId,
    int? limit,
    int? offset,
    String? beforeMessageId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'chat_id': chatId,
      };
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (beforeMessageId != null) {
        queryParams['before_message_id'] = beforeMessageId;
      }

      final response = await _dio.get(
        '/messages',
        queryParameters: queryParams,
      );

      return MessagesPage.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Marks messages as read up to a specific message.
  ///
  /// Updates read status for all messages in the chat up to and including
  /// the specified message.
  ///
  /// Note: This endpoint may not be implemented in the current backend.
  /// If you get 404, the backend doesn't support read receipts yet.
  Future<void> markMessagesAsRead({
    required String chatId,
    required String lastMessageId,
  }) async {
    try {
      await _dio.post(
        '/messages/mark-read',
        data: {
          'chat_id': chatId,
          'last_message_id': lastMessageId,
        },
      );
    } on DioException catch (e) {
      // Silently ignore 404 if endpoint not implemented
      if (e.response?.statusCode != 404) {
        throw _handleError(e);
      }
    }
  }

  /// Sends a location message in a chat.
  ///
  /// Convenience method for sending location-type messages.
  ///
  /// [latitude] and [longitude]: GPS coordinates
  /// [locationName]: Optional human-readable location name
  Future<Message> sendLocationMessage({
    required String chatId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    final content = {
      'latitude': latitude,
      'longitude': longitude,
      if (locationName != null) 'name': locationName,
    };

    return await sendMessage(
      chatId: chatId,
      content: content.toString(),
      messageType: 'location',
    );
  }

  /// Sends an image message in a chat.
  ///
  /// Note: You'll need to upload the image first (likely using ListingsRepository
  /// image upload flow or a dedicated media upload endpoint) and then send
  /// the image URL/key in the message.
  ///
  /// [imageUrl]: URL or storage key of the uploaded image
  /// [caption]: Optional image caption
  Future<Message> sendImageMessage({
    required String chatId,
    required String imageUrl,
    String? caption,
  }) async {
    final content = caption != null ? '$imageUrl\n$caption' : imageUrl;

    return await sendMessage(
      chatId: chatId,
      content: content,
      messageType: 'image',
    );
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Gets the number of unread messages across all chats.
  ///
  /// Note: This may require a dedicated backend endpoint.
  /// If not available, you'll need to calculate this client-side.
  Future<int> getUnreadMessageCount() async {
    try {
      final response = await _dio.get('/messages/unread-count');
      return response.data['count'] ?? 0;
    } on DioException catch (e) {
      // Return 0 if endpoint not implemented
      if (e.response?.statusCode == 404) {
        return 0;
      }
      throw _handleError(e);
    }
  }

  /// Deletes a chat (if supported by backend).
  ///
  /// Note: This endpoint may not be implemented in the current backend.
  Future<void> deleteChat(String chatId) async {
    try {
      await _dio.delete('/chats/$chatId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Error Handling
  // ============================================================================

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final message = e.response!.data?['detail'] ?? e.message;

      switch (statusCode) {
        case 400:
          return Exception('Invalid request: $message');
        case 401:
          return Exception('Unauthorized. Please login again.');
        case 403:
          return Exception('Not allowed: $message');
        case 404:
          return Exception('Not found: $message');
        case 500:
          return Exception('Server error. Please try again later.');
        default:
          return Exception('Error ($statusCode): $message');
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please check your internet.');
    }

    return Exception('Network error: ${e.message}');
  }
}

// ==============================================================================
// Helper Classes
// ==============================================================================

/// Paginated response for messages.
///
/// Used for loading chat history with pagination.
class MessagesPage {
  final List<Message> messages;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  MessagesPage({
    required this.messages,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory MessagesPage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> messagesData = json['items'] ?? json['messages'] ?? [];
    final messages = messagesData.map((m) => Message.fromJson(m)).toList();
    
    final total = json['total'] ?? messages.length;
    final limit = json['limit'] ?? 50;
    final offset = json['offset'] ?? 0;
    final hasMore = json['has_more'] ?? (offset + messages.length < total);

    return MessagesPage(
      messages: messages,
      total: total,
      limit: limit,
      offset: offset,
      hasMore: hasMore,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': messages.map((m) => m.toJson()).toList(),
        'total': total,
        'limit': limit,
        'offset': offset,
        'has_more': hasMore,
      };

  @override
  String toString() =>
      'MessagesPage(messages: ${messages.length}, total: $total, hasMore: $hasMore)';
}
