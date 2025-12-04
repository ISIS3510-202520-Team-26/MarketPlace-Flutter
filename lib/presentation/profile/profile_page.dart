import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/storage/storage.dart';
import '../../core/theme/theme_helper.dart';
import '../../core/net/connectivity_service.dart';

/// Página de perfil de usuario
/// 
/// Muestra la información del usuario actual incluyendo:
/// - Foto de perfil (o iniciales si no tiene foto)
/// - Nombre completo
/// - Email
/// - Campus (si lo tiene configurado)
/// - Opciones de configuración y acciones
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  
  
  final _authRepo = AuthRepository();
  final _storage = StorageHelper.instance;
  
  User? _user;
  bool _loading = true;
  bool _isFromCache = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('profile_page');
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    print('[ProfilePage] 📦 Iniciando carga de perfil...');
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    
    // PASO 1: Intentar cargar desde cache primero (para mostrar rápido)
    final cachedProfile = await _storage.getCachedUserProfile();
    
    if (cachedProfile != null) {
      print('[ProfilePage] ✅ Perfil encontrado en cache');
      try {
        final cachedUser = User.fromJson(cachedProfile);
        
        if (mounted) {
          setState(() {
            _user = cachedUser;
            _isFromCache = true;
            _loading = false;
          });
        }
      } catch (e) {
        print('[ProfilePage] ⚠️ Error al parsear cache: $e');
      }
    } else {
      print('[ProfilePage] ℹ️ No hay perfil en cache');
    }
    
    // PASO 2: Verificar conectividad
    final isOnline = await ConnectivityService.instance.isOnline;
    
    if (!isOnline) {
      print('[ProfilePage] ❌ Sin conexión a internet');
      
      if (_user != null) {
        // Ya mostramos el cache, solo notificar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Sin conexión. Mostrando perfil guardado.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          setState(() {
            _loading = false;
          });
        }
      } else {
        // No hay cache y no hay internet
        if (mounted) {
          setState(() {
            _errorMessage = 'Sin conexión a internet y no hay perfil guardado';
            _loading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Row(children: [Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Sin conexión a internet'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }
    
    // PASO 3: Hay internet, intentar obtener perfil actualizado del backend
    try {
      print('[ProfilePage] 🌐 Obteniendo perfil actualizado del backend...');
      
      // Si no teníamos cache, mostrar loading
      if (_user == null && mounted) {
        setState(() => _loading = true);
      }
      
      final user = await _authRepo.getCurrentUser();
      print('[ProfilePage] ✅ Perfil obtenido del backend');
      
      // Guardar en cache para uso offline (usando toFullJson para datos completos)
      await _storage.cacheUserProfile(user.toFullJson());
      print('[ProfilePage] 💾 Perfil guardado en cache');
      
      if (mounted) {
        setState(() {
          _user = user;
          _isFromCache = false;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('[ProfilePage] ⚠️ Error al obtener perfil del backend: $e');
      
      if (_user != null) {
        // Ya mostramos el cache, solo notificar el error de actualización
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Error al actualizar perfil. Mostrando versión guardada.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          setState(() {
            _loading = false;
          });
        }
      } else {
        // No hay cache, mostrar error
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () {
            Telemetry.i.click('profile_back');
            context.pop();
          },
        ),
        title: Row(
          children: [
             Text(
              'Perfil',
              style: TextStyle(
                color: colors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_isFromCache) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 12, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colors.primary),
            onPressed: () {
              Telemetry.i.click('profile_edit');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Editar perfil (próximamente)')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadUserProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 16),
                        _buildInfoSection(),
                        const SizedBox(height: 16),
                        _buildActionsSection(),
                        const SizedBox(height: 16),
                        _buildSettingsSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Header con foto de perfil y nombre
  Widget _buildProfileHeader() {
    final colors = context.colors;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Avatar con foto o iniciales
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.primary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _user!.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Badge de verificación
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: colors.primary,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Nombre del usuario
          Text(
            _user!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Fecha de registro
          Text(
            'Miembro desde ${_formatDate(_user!.createdAt)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de información del usuario
  Widget _buildInfoSection() {
    final colors = context.colors;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Información Personal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.email_outlined,
            label: 'Correo Electrónico',
            value: _user!.email,
            iconColor: Colors.blue,
          ),
          if (_user!.hasCampus) ...[
            const Divider(height: 1, indent: 56),
            _buildInfoTile(
              icon: Icons.school_outlined,
              label: 'Campus',
              value: _user!.campus!,
              iconColor: Colors.orange,
            ),
          ],
          _buildInfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Último acceso',
            value: _user!.lastLoginAt != null
                ? _formatDateTime(_user!.lastLoginAt!)
                : 'Nunca',
            iconColor: Colors.green,
          ),
        ],
      ),
    );
  }

  /// Sección de acciones rápidas
  Widget _buildActionsSection() {
    final colors = context.colors;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.bar_chart,
            title: 'Mis Estadísticas',
            subtitle: 'Ver estadísticas de ventas',
            color: Colors.purple,
            onTap: () {
              Telemetry.i.click('profile_stats');
              context.push('/profile/stats');
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.inventory_2_outlined,
            title: 'Mis Publicaciones',
            subtitle: 'Ver y administrar mis productos',
            color: colors.primary,
            onTap: () {
              Telemetry.i.click('profile_my_listings');
              context.push('/listings/my');
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.favorite_outline,
            title: 'Favoritos',
            subtitle: 'Productos que me interesan',
            color: Colors.red,
            onTap: () {
              Telemetry.i.click('profile_favorites');
              context.push('/favorites'); // ✨ SP4 FAV: Navega a Favorites Page (vista 3/4)
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.shopping_bag_outlined,
            title: 'Mis Órdenes',
            subtitle: 'Historial de órdenes y compras',
            color: Colors.orange,
            onTap: () {
              Telemetry.i.click('profile_orders');
              context.push('/orders'); // SP4: Navega a Orders Page
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.star_outline,
            title: 'Mis Reviews',
            subtitle: 'Reseñas y calificaciones',
            color: Colors.amber,
            onTap: () {
              Telemetry.i.click('profile_reviews');
              context.push('/reviews'); // SP4: Navega a Reviews Page
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            subtitle: 'Alertas y actualizaciones',
            color: Colors.blue,
            onTap: () {
              Telemetry.i.click('profile_notifications');
              context.push('/notifications'); // ✨ SP4 NOTIF: Navega a Notifications Page (vista 4/4)
            },
          ),
        ],
      ),
    );
  }

  /// Sección de configuración
  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Configuración',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.settings_outlined,
            title: 'Ajustes',
            subtitle: 'Tema, idioma y preferencias',
            color: Colors.orange,
            onTap: () {
              Telemetry.i.click('profile_settings');
              context.push('/settings');
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            subtitle: 'Administrar notificaciones',
            color: Colors.purple,
            onTap: () {
              Telemetry.i.click('profile_notifications');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente: Notificaciones')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.security_outlined,
            title: 'Privacidad y Seguridad',
            subtitle: 'Contraseña y seguridad',
            color: Colors.indigo,
            onTap: () {
              Telemetry.i.click('profile_security');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente: Seguridad')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.help_outline,
            title: 'Ayuda y Soporte',
            subtitle: 'Preguntas frecuentes',
            color: Colors.teal,
            onTap: () {
              Telemetry.i.click('profile_help');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente: Ayuda')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.logout,
            title: 'Cerrar Sesión',
            subtitle: 'Salir de la aplicación',
            color: Colors.red,
            onTap: () => _showLogoutDialog(),
          ),
        ],
      ),
    );
  }

  /// Tile de información
  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tile de acción
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  /// Estado de error
  Widget _buildErrorState() {
    final colors = context.colors;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Por favor, intenta de nuevo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUserProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de confirmación de cierre de sesión
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () {
              Telemetry.i.click('logout_cancel');
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Telemetry.i.click('logout_confirm');
              Navigator.pop(context);
              
              try {
                // Mostrar loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('Cerrando sesión...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
                
                // Limpiar cache del perfil
                print('[ProfilePage] 🗑️ Limpiando cache del perfil...');
                await _storage.invalidateUserProfile();
                
                // Cerrar sesión (limpia tokens)
                await _authRepo.logout();
                
                // Enviar telemetría final
                await Telemetry.i.flush();
                
                // Navegar al login
                if (mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesión: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  /// Formatea una fecha a formato legible
  String _formatDate(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Formatea fecha y hora
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diff.inHours < 1) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inDays < 1) {
      return 'Hace ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return _formatDate(dateTime);
    }
  }
}




