import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio Singleton para gestionar el carrito de compras
/// 
/// Persiste los items del carrito localmente usando SharedPreferences
class CartService {
  CartService._();
  static final instance = CartService._();

  static const String _cartKey = 'shopping_cart';
  
  /// Items del carrito: Map<listingId, CartItem>
  final Map<String, CartItem> _items = {};
  
  /// Listeners para notificar cambios
  final List<Function()> _listeners = [];

  /// Inicializa el servicio cargando el carrito desde el storage
  Future<void> initialize() async {
    await _loadFromStorage();
  }

  /// Agrega un listener para cambios en el carrito
  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  /// Remueve un listener
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  /// Notifica a todos los listeners de cambios
  void _notify() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Agrega un item al carrito
  /// 
  /// Si el item ya existe, incrementa la cantidad
  Future<void> addItem({
    required String listingId,
    required String title,
    required int priceCents,
    required String currency,
    String? imageUrl,
    String? sellerId,
    int quantity = 1,
  }) async {
    if (_items.containsKey(listingId)) {
      // Si ya existe, incrementar cantidad
      _items[listingId] = _items[listingId]!.copyWith(
        quantity: _items[listingId]!.quantity + quantity,
      );
    } else {
      // Agregar nuevo item
      _items[listingId] = CartItem(
        listingId: listingId,
        title: title,
        priceCents: priceCents,
        currency: currency,
        imageUrl: imageUrl,
        sellerId: sellerId,
        quantity: quantity,
        addedAt: DateTime.now(),
      );
    }
    
    await _saveToStorage();
    _notify();
  }

  /// Remueve un item del carrito
  Future<void> removeItem(String listingId) async {
    _items.remove(listingId);
    await _saveToStorage();
    _notify();
  }

  /// Actualiza la cantidad de un item
  Future<void> updateQuantity(String listingId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(listingId);
      return;
    }
    
    if (_items.containsKey(listingId)) {
      _items[listingId] = _items[listingId]!.copyWith(quantity: quantity);
      await _saveToStorage();
      _notify();
    }
  }

  /// Limpia todo el carrito
  Future<void> clear() async {
    _items.clear();
    await _saveToStorage();
    _notify();
  }

  /// Obtiene todos los items del carrito
  List<CartItem> get items => _items.values.toList();

  /// Obtiene un item específico
  CartItem? getItem(String listingId) => _items[listingId];

  /// Verifica si un item está en el carrito
  bool contains(String listingId) => _items.containsKey(listingId);

  /// Cantidad total de items (suma de cantidades)
  int get totalItems => _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Número de productos únicos en el carrito
  int get uniqueItems => _items.length;

  /// Precio total en centavos
  int get totalPriceCents => _items.values.fold(
    0, 
    (sum, item) => sum + (item.priceCents * item.quantity),
  );

  /// Precio total en unidades monetarias
  double get totalPrice => totalPriceCents / 100.0;

  /// Verifica si el carrito está vacío
  bool get isEmpty => _items.isEmpty;

  /// Verifica si el carrito tiene items
  bool get isNotEmpty => _items.isNotEmpty;

  /// Guarda el carrito en SharedPreferences
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsList = _items.values.map((item) => item.toJson()).toList();
    await prefs.setString(_cartKey, jsonEncode(itemsList));
  }

  /// Carga el carrito desde SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      
      if (cartJson != null) {
        final itemsList = jsonDecode(cartJson) as List<dynamic>;
        _items.clear();
        
        for (final itemJson in itemsList) {
          final item = CartItem.fromJson(itemJson as Map<String, dynamic>);
          _items[item.listingId] = item;
        }
        
        _notify();
      }
    } catch (e) {
      print('[CartService] Error loading cart: $e');
      // Si hay error, simplemente iniciar con carrito vacío
      _items.clear();
    }
  }
}

/// Representa un item en el carrito
class CartItem {
  final String listingId;
  final String title;
  final int priceCents;
  final String currency;
  final String? imageUrl;
  final String? sellerId;
  final int quantity;
  final DateTime addedAt;

  const CartItem({
    required this.listingId,
    required this.title,
    required this.priceCents,
    required this.currency,
    this.imageUrl,
    this.sellerId,
    required this.quantity,
    required this.addedAt,
  });

  /// Precio unitario en unidades monetarias
  double get unitPrice => priceCents / 100.0;

  /// Precio total (unitario × cantidad)
  double get totalPrice => (priceCents * quantity) / 100.0;

  /// Total en centavos
  int get totalPriceCents => priceCents * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      listingId: json['listing_id'] as String,
      title: json['title'] as String,
      priceCents: json['price_cents'] as int,
      currency: json['currency'] as String,
      imageUrl: json['image_url'] as String?,
      sellerId: json['seller_id'] as String?,
      quantity: json['quantity'] as int,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'title': title,
      'price_cents': priceCents,
      'currency': currency,
      'image_url': imageUrl,
      'seller_id': sellerId,
      'quantity': quantity,
      'added_at': addedAt.toIso8601String(),
    };
  }

  CartItem copyWith({
    String? listingId,
    String? title,
    int? priceCents,
    String? currency,
    String? imageUrl,
    String? sellerId,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItem(
      listingId: listingId ?? this.listingId,
      title: title ?? this.title,
      priceCents: priceCents ?? this.priceCents,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  String toString() => 'CartItem($title x$quantity = \$${totalPrice.toStringAsFixed(2)})';
}
