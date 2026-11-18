// API real: venta al detalle (licorera/tienda).
// Escáner de código de barras, kárdex de stock, venta rápida y reportes.
// La usan PuntoVentaScreen, ProductosStockScreen, MovimientoStockScreen y
// ReporteVentasScreen.

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../menu/mock_menu_api.dart'; // Producto

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

/// Una línea del carrito del punto de venta.
class LineaVenta {
  final Producto producto;
  int cantidad;
  LineaVenta(this.producto, {this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}

class MovimientoStock {
  final String id;
  final String productoId;
  final String productoNombre;
  final String tipo; // entrada | venta | salida | ajuste | importacion
  final double cantidad;
  final double stockResultante;
  final double costoUnitario;
  final String motivo;
  final String nota;
  final DateTime fecha;

  const MovimientoStock({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    required this.tipo,
    required this.cantidad,
    required this.stockResultante,
    required this.costoUnitario,
    required this.motivo,
    required this.nota,
    required this.fecha,
  });

  static MovimientoStock fromJson(Map<String, dynamic> j) => MovimientoStock(
    id: j['id'] as String,
    productoId: j['productoId'] as String,
    productoNombre: j['productoNombre'] as String? ?? '',
    tipo: j['tipo'] as String,
    cantidad: (j['cantidad'] as num).toDouble(),
    stockResultante: (j['stockResultante'] as num).toDouble(),
    costoUnitario: (j['costoUnitario'] as num? ?? 0).toDouble(),
    motivo: j['motivo'] as String? ?? '',
    nota: j['nota'] as String? ?? '',
    fecha: DateTime.parse(j['fecha'] as String).toLocal(),
  );
}

class ValorCategoria {
  final String categoria;
  final int productos;
  final double unidades;
  final double valorCosto;
  final double valorVenta;

  const ValorCategoria(this.categoria, this.productos, this.unidades, this.valorCosto, this.valorVenta);

  static ValorCategoria fromJson(Map<String, dynamic> j) => ValorCategoria(
    j['categoria'] as String? ?? '',
    j['productos'] as int? ?? 0,
    (j['unidades'] as num).toDouble(),
    (j['valorCosto'] as num).toDouble(),
    (j['valorVenta'] as num).toDouble(),
  );
}

class ValorInventario {
  final int productos;
  final double unidades;
  final double valorCosto;
  final double valorVenta;
  final int productosSinCosto;
  final int productosStockNegativo;
  final List<ValorCategoria> porCategoria;

  const ValorInventario({
    required this.productos,
    required this.unidades,
    required this.valorCosto,
    required this.valorVenta,
    required this.productosSinCosto,
    required this.productosStockNegativo,
    required this.porCategoria,
  });

  static ValorInventario fromJson(Map<String, dynamic> j) => ValorInventario(
    productos: j['productos'] as int,
    unidades: (j['unidades'] as num).toDouble(),
    valorCosto: (j['valorCosto'] as num).toDouble(),
    valorVenta: (j['valorVenta'] as num).toDouble(),
    productosSinCosto: j['productosSinCosto'] as int? ?? 0,
    productosStockNegativo: j['productosStockNegativo'] as int? ?? 0,
    porCategoria: (j['porCategoria'] as List).map((e) => ValorCategoria.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

/// Fila de "por categoría" o "más vendidos" en el reporte de ventas.
class FilaVentas {
  final String nombre;
  final double cantidad;
  final double ventas;
  final double costo;
  final double utilidad;

  const FilaVentas(this.nombre, this.cantidad, this.ventas, this.costo, this.utilidad);

  static FilaVentas fromJson(Map<String, dynamic> j, String campoNombre) => FilaVentas(
    j[campoNombre] as String? ?? '',
    (j['cantidad'] as num).toDouble(),
    (j['ventas'] as num).toDouble(),
    (j['costo'] as num).toDouble(),
    (j['utilidad'] as num).toDouble(),
  );
}

class ReporteVentas {
  final int tickets;
  final double totalVentas;
  final double ticketPromedio;
  final double ventasConCosto;
  final double costo;
  final double utilidad;
  final double margen;
  final double salidasUnidades;
  final double salidasCosto;
  final List<FilaVentas> porCategoria;
  final List<FilaVentas> masVendidos;

  const ReporteVentas({
    required this.tickets,
    required this.totalVentas,
    required this.ticketPromedio,
    required this.ventasConCosto,
    required this.costo,
    required this.utilidad,
    required this.margen,
    required this.salidasUnidades,
    required this.salidasCosto,
    required this.porCategoria,
    required this.masVendidos,
  });

  static ReporteVentas fromJson(Map<String, dynamic> j) => ReporteVentas(
    tickets: j['tickets'] as int,
    totalVentas: (j['totalVentas'] as num).toDouble(),
    ticketPromedio: (j['ticketPromedio'] as num).toDouble(),
    ventasConCosto: (j['ventasConCosto'] as num).toDouble(),
    costo: (j['costo'] as num).toDouble(),
    utilidad: (j['utilidad'] as num).toDouble(),
    margen: (j['margen'] as num).toDouble(),
    salidasUnidades: (j['salidasUnidades'] as num).toDouble(),
    salidasCosto: (j['salidasCosto'] as num).toDouble(),
    porCategoria: (j['porCategoria'] as List)
        .map((e) => FilaVentas.fromJson(e as Map<String, dynamic>, 'categoria'))
        .toList(),
    masVendidos: (j['masVendidos'] as List)
        .map((e) => FilaVentas.fromJson(e as Map<String, dynamic>, 'productoNombre'))
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

String _fecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StockApi {
  // ----- Escáner -----

  /// Producto con ese código de barras, o null si no está registrado.
  static Future<Producto?> porCodigo(String rid, String codigo) async {
    try {
      final j = await ApiClient.get('/restaurants/$rid/productos/barcode/${Uri.encodeComponent(codigo.trim())}');
      return Producto.fromJson(j as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Por nombre (contiene) o por inicio del código de barras.
  static Future<List<Producto>> buscar(String rid, String texto, {int limit = 20}) async {
    final j =
        await ApiClient.get('/restaurants/$rid/productos/buscar', query: {'q': texto.trim(), 'limit': '$limit'})
            as List;
    return j.map((e) => Producto.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ----- Productos -----

  static Future<Producto> crearProducto(
    String rid, {
    required String nombre,
    required double precio,
    required String categoriaId,
    String? codigoBarras,
    double costo = 0,
    double stockInicial = 0,
    double stockMinimo = 0,
    String unidad = 'und',
  }) async {
    final j = await ApiClient.post(
      '/restaurants/$rid/productos',
      body: {
        'nombre': nombre,
        'precio': precio,
        'categoriaId': categoriaId,
        'codigoBarras': codigoBarras,
        'costo': costo,
        'controlaStock': true,
        'stockInicial': stockInicial,
        'stockMinimo': stockMinimo,
        'unidad': unidad,
      },
    );
    return Producto.fromJson(j as Map<String, dynamic>);
  }

  /// Edición parcial: solo se envían los campos que cambian.
  static Future<Producto> editarProducto(String rid, String productoId, Map<String, dynamic> cambios) async {
    final j = await ApiClient.patch('/restaurants/$rid/productos/$productoId', body: cambios);
    return Producto.fromJson(j as Map<String, dynamic>);
  }

  // ----- Kárdex -----

  /// [items]: {productoId, cantidad, costoUnitario?}
  static Future<void> entrada(String rid, List<Map<String, dynamic>> items, {String nota = ''}) =>
      ApiClient.post('/restaurants/$rid/stock/entradas', body: {'items': items, 'nota': nota});

  /// [items]: {productoId, cantidad}
  static Future<void> salida(
    String rid,
    List<Map<String, dynamic>> items, {
    String motivo = 'merma',
    String nota = '',
  }) => ApiClient.post('/restaurants/$rid/stock/salidas', body: {'items': items, 'motivo': motivo, 'nota': nota});

  /// [items]: {productoId, stockReal}
  static Future<void> ajuste(String rid, List<Map<String, dynamic>> items, {String nota = ''}) =>
      ApiClient.post('/restaurants/$rid/stock/ajustes', body: {'items': items, 'nota': nota});

  static Future<List<MovimientoStock>> movimientos(String rid, {String? productoId, int limit = 200}) async {
    final j =
        await ApiClient.get(
              '/restaurants/$rid/stock/movimientos',
              query: {'productoId': ?productoId, 'limit': '$limit'},
            )
            as List;
    return j.map((e) => MovimientoStock.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ----- Venta rápida -----

  /// Registra una venta de mostrador (sin mesa). El backend congela precio y
  /// costo de cada producto y descuenta el stock.
  static Future<void> venderMostrador(
    String rid, {
    required List<LineaVenta> lineas,
    required String metodoPago,
  }) async {
    final total = lineas.fold<double>(0, (s, l) => s + l.subtotal);
    await ApiClient.post(
      '/restaurants/$rid/ventas',
      body: {
        'mesaNumero': 0,
        'orden': 0,
        'nombreCliente': 'Mostrador',
        'items': [
          for (final l in lineas)
            {
              'productoId': l.producto.id,
              'productoNombre': l.producto.nombre,
              'categoriaId': l.producto.categoriaId,
              'cantidad': l.cantidad,
              'precioUnitario': l.producto.precio,
            },
        ],
        'pagos': [
          {'metodo': metodoPago, 'monto': total},
        ],
        'total': total,
      },
    );
  }

  // ----- Reportes -----

  static Future<ValorInventario> valorInventario(String rid) async {
    final j = await ApiClient.get('/restaurants/$rid/reportes/inventario');
    return ValorInventario.fromJson(j as Map<String, dynamic>);
  }

  static Future<ReporteVentas> reporteVentas(
    String rid, {
    required DateTime desde,
    required DateTime hasta,
    int horaCorte = 0,
  }) async {
    final j = await ApiClient.get(
      '/restaurants/$rid/reportes/ventas',
      query: {'desde': _fecha(desde), 'hasta': _fecha(hasta), 'horaCorte': '$horaCorte', 'top': '15'},
    );
    return ReporteVentas.fromJson(j as Map<String, dynamic>);
  }
}
