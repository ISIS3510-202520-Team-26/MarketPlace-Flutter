import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/cart_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/app_theme.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _cartService = CartService.instance;
  
  static const _primary = Color(0xFF0F6E5D);
  static const _cardBg = Color(0xFFF7F8FA);
  static const _textGray = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('cart');
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _cartService.items;
    final isEmpty = _cartService.isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () {
            Telemetry.i.click('cart_back');
            context.pop();
          },
        ),
        title: const Text(
          'Mi Carrito',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _showClearCartDialog,
              child: const Text(
                'Vaciar',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: isEmpty ? _buildEmptyCart() : _buildCartContent(items),
      bottomNavigationBar: isEmpty ? null : _buildCheckoutBar(),
    );
  }

  // ==================== Empty State ====================

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _cardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 60,
              color: _textGray,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tu carrito está vacío',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Explora productos y agrégalos a tu carrito',
            style: TextStyle(
              fontSize: 14,
              color: _textGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Telemetry.i.click('cart_empty_explore');
              context.pop();
            },
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explorar Productos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Cart Content ====================

  Widget _buildCartContent(List<CartItem> items) {
    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          color: _cardBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_cartService.uniqueItems} producto${_cartService.uniqueItems > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textGray,
                ),
              ),
              Text(
                '${_cartService.totalItems} item${_cartService.totalItems > 1 ? 's' : ''} en total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textGray,
                ),
              ),
            ],
          ),
        ),
        
        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildCartItem(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Dismissible(
      key: Key(item.listingId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) => _confirmRemoveItem(item),
      onDismissed: (direction) {
        Telemetry.i.click('cart_item_removed', listingId: item.listingId);
        _cartService.removeItem(item.listingId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} eliminado del carrito'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                _cartService.addItem(
                  listingId: item.listingId,
                  title: item.title,
                  priceCents: item.priceCents,
                  currency: item.currency,
                  imageUrl: item.imageUrl,
                  sellerId: item.sellerId,
                  quantity: item.quantity,
                );
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          Telemetry.i.click('cart_item_view', listingId: item.listingId);
          context.push('/listings/${item.listingId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              _buildItemImage(item),
              const SizedBox(width: 12),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${item.unitPrice.toStringAsFixed(0)} ${item.currency}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildQuantitySelector(item),
                  ],
                ),
              ),
              
              // Total price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.currency,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(CartItem item) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.imageUrl != null
          ? CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.image_not_supported_outlined,
                color: _textGray,
                size: 32,
              ),
            )
          : const Icon(
              Icons.image_not_supported_outlined,
              color: _textGray,
              size: 32,
            ),
    );
  }

  Widget _buildQuantitySelector(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityButton(
            icon: Icons.remove,
            onTap: () {
              Telemetry.i.click('cart_decrease_quantity', listingId: item.listingId);
              _cartService.updateQuantity(item.listingId, item.quantity - 1);
            },
            enabled: item.quantity > 1,
          ),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _quantityButton(
            icon: Icons.add,
            onTap: () {
              Telemetry.i.click('cart_increase_quantity', listingId: item.listingId);
              _cartService.updateQuantity(item.listingId, item.quantity + 1);
            },
            enabled: true,
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _primary : Colors.grey,
        ),
      ),
    );
  }

  // ==================== Checkout Bar ====================

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textGray,
                  ),
                ),
                Text(
                  '\$${_cartService.totalPrice.toStringAsFixed(0)} COP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '\$${_cartService.totalPrice.toStringAsFixed(0)} COP',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Checkout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Proceder al Pago',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Actions ====================

  Future<bool?> _confirmRemoveItem(CartItem item) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Quieres eliminar "${item.title}" del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('¿Estás seguro de que quieres vaciar todo el carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Telemetry.i.click('cart_cleared');
              _cartService.clear();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Carrito vaciado'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout() {
    Telemetry.i.click('checkout_button');
    
    // TODO: Implementar proceso de checkout
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen de tu compra:'),
            const SizedBox(height: 12),
            Text('Productos: ${_cartService.uniqueItems}'),
            Text('Items totales: ${_cartService.totalItems}'),
            const SizedBox(height: 8),
            Text(
              'Total: \$${_cartService.totalPrice.toStringAsFixed(0)} COP',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '(Proceso de pago por implementar)',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: _textGray,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cartService.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Compra simulada exitosa! Carrito vaciado.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simular Compra'),
          ),
        ],
      ),
    );
  }
}
