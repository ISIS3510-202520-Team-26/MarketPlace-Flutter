# market_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### 1. **LoginPage** (`lib/presentation/auth/login_page.dart`)
**Funcionalidad:** Pantalla de inicio de sesión
- Login con email y contraseña
- Validación de campos
- Navegación a registro
- Persistencia de sesión con tokens

**Tecnologías usadas:**
- **Future con async/await**: Para llamadas a la API de autenticación
- **Preferences (SharedPreferences)**: Guarda el token JWT del usuario

### 2. **RegisterPage** (`lib/presentation/auth/register_page.dart`)
**Funcionalidad:** Pantalla de registro de nuevos usuarios
- Formulario de registro con validaciones
- Campos: nombre, email, contraseña
- Navegación automática al home después del registro

**Tecnologías usadas:**
- **Future con async/await**: Para crear usuarios en el backend
- **Preferences**: Almacena credenciales después del registro exitoso

### 3. **HomePage** (`lib/presentation/home/home_page.dart`)
**Funcionalidad:** Pantalla principal con listado de productos
- Grid de productos con imágenes
- Búsqueda y filtros por categoría
- Filtro por ubicación con GPS
- Sistema de cache para modo offline
- Analytics de categorías más vistas
- CTAs inteligentes basados en tiempo de permanencia
- Botón flotante para publicar productos
- Carrito de compras con badge
- Animaciones staggered en el grid
- Shimmer loading mientras carga

**Tecnologías usadas:**
- **Future con async/await**: Para cargar productos, categorías y telemetría
- **Stream**: Para actualizaciones en tiempo real de ubicación GPS (Geolocator)
- **BD Llave/Valor (SharedPreferences)**: Cache de productos y categorías para offline
- **CachedNetworkImage**: Cache de imágenes de productos con LRU interno
- **LRU Cache**: Map interno para URLs de fotos (`_photoUrlCache`)
- **Preferences**: Filtros por defecto del usuario (radio de ubicación)
- **Shimmer**: Loading skeleton mientras se cargan los productos
- **Animaciones**: Flutter Staggered Animations para efecto cascada

### 4. **ProfilePage** (`lib/presentation/profile/profile_page.dart`)
**Funcionalidad:** Perfil del usuario con información personal
- Muestra datos del usuario (nombre, email, campus)
- Modo offline: carga desde cache si no hay internet
- Badge "Offline" cuando usa datos cacheados
- Actualización automática cuando hay conexión
- Botón de logout con confirmación

**Tecnologías usadas:**
- **Future con async/await**: Para obtener datos del usuario del backend
- **BD Llave/Valor (SharedPreferences)**: Cache del perfil con TTL de 7 días
- **Future con handlers**: Manejo de errores de red con try-catch
- **Archivos locales**: Serialización JSON del perfil para persistencia

**Flujo offline:**
1. HomePage descarga el perfil en segundo plano al iniciar
2. ProfilePage intenta cargar desde cache primero
3. Si hay internet, actualiza el cache con datos frescos
4. Si no hay internet, muestra cache con indicador visual

### 5. **CartPage** (`lib/presentation/cart/cart_page.dart`)
**Funcionalidad:** Carrito de compras
- Lista de productos agregados con imágenes
- Modificar cantidades (+/-)
- Eliminar productos (swipe to delete)
- Cálculo automático del total
- Botón "Proceder al Pago"
- Empty state cuando el carrito está vacío
- Persistencia local del carrito

**Tecnologías usadas:**
- **BD Llave/Valor (SharedPreferences)**: Persistencia del carrito completo
- **Future con async/await**: Para operaciones de guardar/cargar carrito
- **Archivos locales**: JSON serialization de items del carrito
- **CachedNetworkImage**: Imágenes de productos en el carrito
- **Singleton Pattern**: CartService compartido globalmente

### 6. **CreateListingPage** (`lib/presentation/listings/create_listing_page.dart`)
**Funcionalidad:** Crear nuevas publicaciones de productos
- Formulario con múltiples campos
- Subir fotos desde galería o cámara
- Selección de categoría y marca
- Ubicación automática con GPS
- Guardar borrador localmente

**Tecnologías usadas:**
- **Future con async/await**: Upload de imágenes y creación de listing
- **Stream**: Ubicación en tiempo real (Geolocator)
- **BD Llave/Valor (SharedPreferences)**: Guardar borrador del formulario
- **Archivos locales**: Compresión y cache temporal de imágenes

### 7. **ListingDetailPage** (`lib/presentation/listings/listing_detail_page.dart`)
**Funcionalidad:** Detalle completo de un producto
- Galería de imágenes con Hero animation
- Información completa del producto
- Botón "Añadir al carrito"
- Mapa de ubicación si está disponible

**Tecnologías usadas:**
- **Future con async/await**: Carga de detalles del producto
- **CachedNetworkImage**: Galería de fotos con cache
- **Hero Animation**: Transición fluida desde el grid

---

## 🛠️ Servicios y Utilidades Creadas

### **StorageHelper** (`lib/core/storage/storage_helper.dart`)
Servicio centralizado para manejo de cache y preferencias.

**Funcionalidades:**
- Cache de productos y categorías con TTL
- Cache de perfil de usuario con TTL de 7 días
- Gestión de búsquedas recientes
- Categorías favoritas
- Filtros por defecto del usuario
- Borradores de publicaciones
- Estadísticas de storage

**Tecnologías usadas:**
- **BD Llave/Valor (SharedPreferences)**: Almacenamiento principal
- **Future con async/await**: Todas las operaciones de I/O
- **Archivos locales**: JSON serialization/deserialization

### **CartService** (`lib/core/services/cart_service.dart`)
Singleton para gestión global del carrito.

**Funcionalidades:**
- Agregar/eliminar productos
- Actualizar cantidades
- Calcular totales
- Persistencia automática
- Sistema de listeners para UI reactiva

**Tecnologías usadas:**
- **BD Llave/Valor (SharedPreferences)**: Persistencia del carrito
- **Future con async/await**: Operaciones de guardado
- **Observer Pattern**: Notificación de cambios a la UI

### **CategoryAnalytics** (`lib/core/analytics/category_analytics.dart`)
Servicio de analytics para categorías (Business Question 1).

**Funcionalidades:**
- Tracking de vistas por categoría
- Cálculo de tiempo promedio de vista
- Top 5 categorías más exploradas
- Persistencia de datos analíticos

**Tecnologías usadas:**
- **BD Llave/Valor (SharedPreferences)**: Almacenamiento de métricas
- **Future con async/await**: Lectura/escritura de analytics
- **Archivos locales**: JSON maps para timestamps y contadores

### **ConnectivityService** (`lib/core/net/connectivity_service.dart`)
Verificación de conectividad a internet.

**Funcionalidades:**
- Detectar si hay conexión
- Distinguir entre WiFi y datos móviles

**Tecnologías usadas:**
- **Stream**: Monitoreo continuo de cambios de conectividad
- **connectivity_plus package**: Para detección de red

---

## 🎨 Mejoras Estéticas Implementadas

### **AppTheme** (`lib/core/theme/app_theme.dart`)
Sistema de diseño completo con:
- Paleta de colores consistente
- Tipografía con Google Fonts (Inter)
- Sistema de sombras multicapa
- Border radius estandarizado
- Widgets reutilizables (StyledCard, StyledIconButton)

**Tecnologías usadas:**
- **Google Fonts**: Tipografía profesional
- **Material Design 3**: Componentes modernos

### Animaciones y Loading States
- **Shimmer**: Loading skeletons en HomePage
- **Staggered Animations**: Efecto cascada en grid de productos
- **Hero Animations**: Transiciones fluidas entre páginas
- **Ripple Effects**: Feedback visual en todos los taps

---

## 📊 Tecnologías Implementadas (Checklist)

### ✅ **Implementado:**

#### **1. Future con async/await**
**Dónde:** Todas las páginas y servicios
- LoginPage: Autenticación
- RegisterPage: Crear usuario
- HomePage: Cargar productos, categorías, telemetría
- ProfilePage: Obtener perfil del usuario
- CartPage: Persistencia del carrito
- CreateListingPage: Upload de imágenes
- ListingDetailPage: Cargar detalles
- StorageHelper: Todas las operaciones I/O
- CartService: Guardar carrito

**Cómo se usa:** Para operaciones asíncronas que necesitan esperar una respuesta (llamadas a API, lectura/escritura de disco). Ejemplo:
```dart
Future<void> _loadProfile() async {
  final user = await _authRepo.getCurrentUser();
  setState(() => _user = user);
}
```

#### **2. Future con handlers (try-catch)**
**Dónde:** ProfilePage, HomePage, LoginPage
- Manejo de errores de red
- Fallback a cache cuando falla la API
- Mensajes de error al usuario

**Cómo se usa:** Para capturar errores y mostrar mensajes apropiados. Ejemplo:
```dart
try {
  await _loadFromBackend();
} catch (e) {
  // Mostrar cache si hay error de red
  _loadFromCache();
}
```

#### **3. Stream**
**Dónde:** 
- **ConnectivityService**: Monitoreo de cambios de red
- **Geolocator (HomePage y CreateListingPage)**: Ubicación GPS en tiempo real

**Cómo se usa:** Para escuchar cambios continuos. Ejemplo:
```dart
Stream<Position> positionStream = Geolocator.getPositionStream();
positionStream.listen((Position position) {
  // Actualizar ubicación en el mapa
});
```

#### **4. BD Llave/Valor (SharedPreferences)**
**Dónde:** 
- **StorageHelper**: Cache de productos, categorías, perfil
- **CartService**: Persistencia del carrito
- **CategoryAnalytics**: Métricas de categorías
- **Auth**: Tokens JWT

**Cómo se usa:** Para guardar datos simples como JSON strings. Ejemplo:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('user_profile', jsonEncode(userData));
final cached = prefs.getString('user_profile');
```

#### **5. Archivos Locales (JSON serialization)**
**Dónde:** 
- Todos los modelos (User, Listing, CartItem)
- Cache de StorageHelper
- Borradores de CreateListingPage

**Cómo se usa:** Convertir objetos Dart a JSON y viceversa. Ejemplo:
```dart
// Guardar
final json = user.toFullJson();
await storage.save(json);

// Leer
final json = await storage.read();
final user = User.fromJson(json);
```

#### **6. Preferences/UserDefaults**
**Dónde:** StorageHelper
- Filtros por defecto (radio de ubicación)
- Búsquedas recientes
- Categorías favoritas
- Configuración de usuario

**Cómo se usa:** Similar a BD Llave/Valor, para preferencias del usuario. Ejemplo:
```dart
await _prefs.setBool('locationEnabled', true);
await _prefs.setDouble('radius', 5.0);
```

#### **7. CachedNetworkImage**
**Dónde:** 
- HomePage: Grid de productos
- CartPage: Imágenes de items
- ListingDetailPage: Galería de fotos
- ProfilePage: Foto de perfil (si se implementa)

**Cómo se usa:** Widget que descarga, cachea y muestra imágenes. Tiene LRU interno. Ejemplo:
```dart
CachedNetworkImage(
  imageUrl: 'https://...jpg',
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

#### **8. LRU Cache (Manual)**
**Dónde:** HomePage
- `_photoUrlCache`: Map<String, String> para URLs de fotos

**Cómo se usa:** Map en memoria para evitar refetch de URLs. Ejemplo:
```dart
final Map<String, String> _photoUrlCache = {};

// Guardar
_photoUrlCache[listingId] = photoUrl;

// Leer
final cached = _photoUrlCache[listingId];
```

---

### ❌ **No Implementado:**

#### **Isolates**
- **Por qué:** No hay operaciones CPU-intensive que bloqueen el UI
- **Alternativa usada:** async/await para operaciones I/O
- **Cuándo sería útil:** Procesamiento de imágenes pesado, cálculos complejos

#### **BD Local Relacional (SQLite)**
- **Por qué:** SharedPreferences es suficiente para el scope actual
- **Alternativa usada:** SharedPreferences + JSON
- **Cuándo sería útil:** Queries complejas, relaciones entre tablas, grandes volúmenes

#### **Hive o RealmDB**
- **Por qué:** SharedPreferences cubre las necesidades de cache
- **Alternativa usada:** SharedPreferences
- **Cuándo sería útil:** Cache de objetos complejos con alta frecuencia de acceso

#### **Glide/Picasso (Android nativo)**
- **Por qué:** CachedNetworkImage es el equivalente Flutter
- **Implementado:** CachedNetworkImage con cache LRU interno

#### **SparseArray/ArrayMap (Android específico)**
- **Por qué:** Dart tiene Maps eficientes por defecto
- **Implementado:** Map<String, dynamic> estándar

#### **NSCache (iOS específico)**
- **Por qué:** CachedNetworkImage maneja cache multiplataforma
- **Implementado:** Cache de SharedPreferences + CachedNetworkImage

---

## 🏗️ Arquitectura

### **Estructura de Carpetas:**
```
lib/
├── core/                    # Servicios compartidos
│   ├── analytics/          # CategoryAnalytics
│   ├── net/                # Dio, interceptors, ConnectivityService
│   ├── router/             # GoRouter config
│   ├── services/           # CartService
│   ├── storage/            # StorageHelper
│   ├── telemetry/          # Telemetry tracking
│   ├── theme/              # AppTheme
│   └── ux/                 # UX hints y tunning
├── data/
│   ├── models/             # User, Listing, CartItem, etc.
│   └── repositories/       # AuthRepo, ListingsRepo, etc.
└── presentation/
    ├── auth/               # Login, Register
    ├── cart/               # CartPage
    ├── home/               # HomePage
    ├── listings/           # Create, Detail
    └── profile/            # ProfilePage
```

### **Patrón de Diseño:**
- **Repository Pattern**: Separación de lógica de datos
- **Singleton**: Servicios globales (StorageHelper, CartService, Analytics)
- **Observer Pattern**: CartService notifica cambios a la UI
- **MVC/MVVM híbrido**: StatefulWidgets con lógica de presentación

---

## 🔧 Dependencias Principales

```yaml
# Navegación
go_router: ^14.2.0

# Red y Cache
dio: ^5.9.0
dio_cache_interceptor: ^3.4.4
cached_network_image: ^3.4.1

# Storage
flutter_secure_storage: ^9.2.4
shared_preferences: ^2.3.2

# Conectividad y Sensores
connectivity_plus: ^7.0.0
geolocator: ^14.0.2

# UI y Animaciones
shimmer: ^3.0.0
flutter_animate: ^4.5.0
google_fonts: ^6.2.1
flutter_staggered_animations: ^1.1.1

# Utilidades
uuid: ^4.5.1
image_picker: ^1.2.0
flutter_image_compress: ^2.3.0
```

---

## 🚀 Características Destacadas

### **Modo Offline**
- Cache inteligente de productos y categorías
- Perfil disponible sin conexión
- Carrito persiste localmente
- Indicadores visuales de estado offline

### **Performance**
- Imágenes cacheadas con LRU
- Shimmer loading para mejor UX
- Lazy loading en grids
- Animaciones optimizadas (375ms)

### **Analytics**
- Tracking de vistas por categoría
- Business Question 1 implementada
- CTAs inteligentes basados en tiempo de permanencia
- Telemetría de interacciones

### **UX/UI**
- Material Design 3
- Google Fonts (Inter)
- Animaciones fluidas
- Feedback visual en todas las interacciones
- Empty states informativos
- Error handling con mensajes claros

---

## 📈 Métricas del Proyecto

- **Páginas:** 7 pantallas completas
- **Servicios:** 5 servicios core
- **Modelos:** 15+ modelos de datos
- **Líneas de código:** ~10,000+
- **Uso de Future:** 50+ funciones async
- **Uso de Stream:** 3 implementaciones
- **Cache layers:** 3 niveles (memoria, SharedPrefs, CachedNetworkImage)

---

## 👨‍💻 Desarrollo

### **Ejecutar la app:**
```bash
flutter pub get
flutter run
```

### **Generar build:**
```bash
flutter build apk --release
```

---

## 📝 Notas Técnicas

### **Cache TTL (Time To Live):**
- Productos y categorías: 30 minutos
- Perfil de usuario: 7 días
- Carrito: Persistente sin expiración
- Analytics: Persistente acumulativo

### **Estrategia Offline-First:**
1. Intentar cargar desde cache primero
2. Mostrar datos cacheados inmediatamente
3. Actualizar en segundo plano si hay conexión
4. Notificar al usuario del estado

### **Manejo de Errores:**
- Try-catch en todas las operaciones async
- Fallback a cache cuando falla la red
- Mensajes de error descriptivos al usuario
- Logging para debugging

---

## 🎯 Conclusión

Esta aplicación demuestra el uso efectivo de:
- ✅ Programación asíncrona (Future, async/await)
- ✅ Streams para datos en tiempo real
- ✅ Persistencia local con múltiples estrategias
- ✅ Cache multinivel para performance
- ✅ Arquitectura limpia y escalable
- ✅ UX/UI moderna y profesional

**Desarrollado con Flutter para Android** 🚀
