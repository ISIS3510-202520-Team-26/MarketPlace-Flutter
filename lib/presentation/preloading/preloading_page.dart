import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/preload_service.dart';
import '../../core/telemetry/telemetry.dart';

/// Página de carga que se muestra después del login
/// 
/// Muestra el progreso de precarga de datos en caché
/// y sincronización inicial para modo offline.
class PreloadingPage extends StatefulWidget {
  const PreloadingPage({super.key});

  @override
  State<PreloadingPage> createState() => _PreloadingPageState();
}

class _PreloadingPageState extends State<PreloadingPage> 
    with SingleTickerProviderStateMixin {
  
  static const _primary = Color(0xFF0F6E5D);
  static const _primaryLight = Color(0xFF4CAF90);
  
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  
  PreloadProgress? _progress;
  String? _error;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('preloading');

    // Configurar animación de pulso
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Iniciar precarga
    _startPreload();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startPreload() async {
    try {
      // Escuchar progreso mediante Stream
      PreloadService.instance.progressStream.listen(
        _onProgressUpdate,
        onError: (error) {
          setState(() {
            _error = 'Error al cargar datos: $error';
          });
        },
      );
      
      // Inicializar servicio de precarga
      await PreloadService.instance.initialize();
      
      // Esperar un momento para que el usuario vea "¡Todo listo!"
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Navegar al home
      if (mounted) {
        Telemetry.i.click('preload_complete');
        await Telemetry.i.flush();
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
      });
      Telemetry.i.click('preload_error', props: {'error': e.toString()});
    }
  }

  void _onProgressUpdate(PreloadProgress progress) {
    if (!mounted) return;
    
    setState(() {
      _progress = progress;
      _isComplete = progress.isComplete;
      if (progress.hasError && _error == null) {
        _error = progress.message;
      }
    });

    // Log de telemetría
    Telemetry.i.click('preload_step', props: {
      'step': progress.step,
      'total': progress.totalSteps,
      'message': progress.message,
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _progress = null;
      _isComplete = false;
    });
    Telemetry.i.click('preload_retry');
    _startPreload();
  }

  void _skipToHome() {
    Telemetry.i.click('preload_skip');
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animado
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Título
                Text(
                  _isComplete
                      ? '¡Todo listo!'
                      : 'Preparando tu experiencia',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Mensaje de progreso
                if (_progress != null && _error == null)
                  Text(
                    _progress!.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 32),

                // Indicador de progreso
                if (_error == null) ...[
                  // Barra de progreso
                  SizedBox(
                    width: 280,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress?.progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isComplete ? Colors.green : _primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Porcentaje
                  if (_progress != null)
                    Text(
                      '${_progress!.progressPercent}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Pasos
                  if (_progress != null)
                    Text(
                      'Paso ${_progress!.step} de ${_progress!.totalSteps}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reintentar
                      OutlinedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: _primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Continuar de todas formas
                      ElevatedButton.icon(
                        onPressed: _skipToHome,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continuar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Hint de modo offline
                if (_error == null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Descargando datos para uso offline',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
