import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../core/api_exception.dart';
import '../mock/mock_api.dart';
import 'movimiento_stock_screen.dart';

final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

String _cant(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Productos con stock propio (licorera/tienda): valor del inventario,
/// búsqueda por nombre o código, edición de precios y kárdex por producto.
class ProductosStockScreen extends StatefulWidget {
  const ProductosStockScreen({super.key, required this.restaurant, required this.user});

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<ProductosStockScreen> createState() => _ProductosStockScreenState();
}

enum _Filtro { todos, stockBajo, sinCosto, sinCodigo }

class _ProductosStockScreenState extends State<ProductosStockScreen> {
  final _buscarCtrl = TextEditingController();
  List<Producto> _productos = [];
  ValorInventario? _valor;
  bool _cargando = true;
  String? _error;
  _Filtro _filtro = _Filtro.todos;

  String get _rid => widget.restaurant.id;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait([MockMenuApi.getProductos(_rid), StockApi.valorInventario(_rid)]);
      if (!mounted) return;
      setState(() {
        _productos = (r[0] as List<Producto>).where((p) => p.controlaStock).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        _valor = r[1] as ValorInventario;
        _cargando = false;
      });
    } on ApiException catch (e) {
      _fallo(e.message);
    } catch (_) {
      _fallo('Sin conexión con el servidor');
    }
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _error = mensaje;
      _cargando = false;
    });
  }

  List<Producto> get _visibles {
    final q = _buscarCtrl.text.trim().toLowerCase();
    return _productos.where((p) {
      final pasa = switch (_filtro) {
        _Filtro.todos => true,
        _Filtro.stockBajo => p.stockBajo,
        _Filtro.sinCosto => p.costo <= 0,
        _Filtro.sinCodigo => p.codigoBarras == null,
      };
      if (!pasa) return false;
      if (q.isEmpty) return true;
      return p.nombre.toLowerCase().contains(q) || (p.codigoBarras ?? '').startsWith(q);
    }).toList();
  }

  Future<void> _irA(TipoMovimiento tipo) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MovimientoStockScreen(restaurant: widget.restaurant, tipo: tipo),
      ),
    );
    if (cambio == true) _cargar();
  }

  Future<void> _nuevo() async {
    final p = await mostrarFormProducto(context, _rid);
    if (p != null) _cargar();
  }

  Future<void> _abrir(Producto p) async {
    final cambio = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondoOscuro,
      builder: (_) => _DetalleProducto(rid: _rid, producto: p),
    );
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _visibles;
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        title: Text('Productos y stock', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh, color: AppColors.textoClaroMedio),
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.naranjaAccion,
        onPressed: _nuevo,
        icon: const Icon(Icons.add, color: AppColors.textoClaroAlto),
        label: Text('Producto', style: AppTypography.labelLarge.copyWith(color: AppColors.textoClaroAlto)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: AppTypography.bodyMedium))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  if (_valor != null)
                    _ResumenValor(valor: _valor!, stockBajo: _productos.where((p) => p.stockBajo).length),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BotonAccion(
                          icon: Icons.move_to_inbox_outlined,
                          label: 'Entrada',
                          color: AppColors.verdeExito,
                          onTap: () => _irA(TipoMovimiento.entrada),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BotonAccion(
                          icon: Icons.outbox_outlined,
                          label: 'Salida',
                          color: AppColors.rojoAlerta,
                          onTap: () => _irA(TipoMovimiento.salida),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BotonAccion(
                          icon: Icons.fact_check_outlined,
                          label: 'Conteo',
                          color: const Color(0xFF60A5FA),
                          onTap: () => _irA(TipoMovimiento.conteo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _buscarCtrl,
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o código',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textoClaroMedio),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (f, t) in [
                        (_Filtro.todos, 'Todos (${_productos.length})'),
                        (_Filtro.stockBajo, 'Stock bajo'),
                        (_Filtro.sinCosto, 'Sin costo'),
                        (_Filtro.sinCodigo, 'Sin código'),
                      ])
                        ChoiceChip(
                          label: Text(t),
                          selected: _filtro == f,
                          onSelected: (_) => setState(() => _filtro = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (lista.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        _productos.isEmpty
                            ? 'Aún no hay productos con stock. Crea uno o importa desde Gecofi.'
                            : 'Nada coincide con el filtro.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  for (final p in lista) _FilaProducto(producto: p, onTap: () => _abrir(p)),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulario de producto nuevo (también lo usa la entrada de mercancía)
// ---------------------------------------------------------------------------

/// Abre el formulario para crear un producto con stock. [codigo] llega
/// prellenado cuando se escaneó un código que no existía.
Future<Producto?> mostrarFormProducto(BuildContext context, String rid, {String? codigo}) =>
    showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondoOscuro,
      builder: (_) => _FormProducto(rid: rid, codigo: codigo),
    );

class _FormProducto extends StatefulWidget {
  const _FormProducto({required this.rid, this.codigo});
  final String rid;
  final String? codigo;

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _costo = TextEditingController();
  late final _codigo = TextEditingController(text: widget.codigo ?? '');
  final _stock = TextEditingController();
  final _minimo = TextEditingController();
  List<Categoria> _categorias = [];
  String? _categoriaId;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    MockCategoriasApi.getCategorias(widget.rid).then((c) {
      if (mounted) setState(() => _categorias = c);
    });
  }

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _costo, _codigo, _stock, _minimo]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty || _categoriaId == null || _num(_precio) <= 0) {
      setState(() => _error = 'Nombre, categoría y precio de venta son obligatorios');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final p = await StockApi.crearProducto(
        widget.rid,
        nombre: _nombre.text.trim(),
        precio: _num(_precio),
        categoriaId: _categoriaId!,
        codigoBarras: _codigo.text.trim().isEmpty ? null : _codigo.text.trim(),
        costo: _num(_costo),
        stockInicial: _num(_stock),
        stockMinimo: _num(_minimo),
      );
      if (mounted) Navigator.pop(context, p);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nuevo producto', style: AppTypography.titleLarge),
            const SizedBox(height: 12),
            _Campo('Código de barras', _codigo, hint: 'Escanéalo aquí', numerico: true),
            _Campo('Nombre', _nombre, autofocus: widget.codigo != null),
            DropdownButtonFormField<String>(
              initialValue: _categoriaId,
              items: [for (final c in _categorias) DropdownMenuItem(value: c.id, child: Text(c.nombre))],
              onChanged: (v) => setState(() => _categoriaId = v),
              decoration: _decoracion('Categoría'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Campo('Precio de venta', _precio, numerico: true)),
                const SizedBox(width: 10),
                Expanded(child: _Campo('Costo (compra)', _costo, numerico: true)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _Campo('Stock inicial', _stock, numerico: true)),
                const SizedBox(width: 10),
                Expanded(child: _Campo('Stock mínimo', _minimo, numerico: true)),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppColors.rojoAlerta)),
              ),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranjaAccion),
                child: Text(
                  _guardando ? 'Guardando…' : 'Crear producto',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.textoClaroAlto),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalle: editar y ver kárdex
// ---------------------------------------------------------------------------

class _DetalleProducto extends StatefulWidget {
  const _DetalleProducto({required this.rid, required this.producto});
  final String rid;
  final Producto producto;

  @override
  State<_DetalleProducto> createState() => _DetalleProductoState();
}

class _DetalleProductoState extends State<_DetalleProducto> {
  late final _nombre = TextEditingController(text: widget.producto.nombre);
  late final _precio = TextEditingController(text: _cant(widget.producto.precio));
  late final _costo = TextEditingController(text: _cant(widget.producto.costo));
  late final _codigo = TextEditingController(text: widget.producto.codigoBarras ?? '');
  late final _minimo = TextEditingController(text: _cant(widget.producto.stockMinimo));
  List<MovimientoStock>? _movs;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    StockApi.movimientos(widget.rid, productoId: widget.producto.id, limit: 30).then((m) {
      if (mounted) setState(() => _movs = m);
    });
  }

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _costo, _codigo, _minimo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final p = widget.producto;
    double? n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
    final codigo = _codigo.text.trim();
    final cambios = <String, dynamic>{
      if (_nombre.text.trim() != p.nombre && _nombre.text.trim().isNotEmpty) 'nombre': _nombre.text.trim(),
      if (n(_precio) != null && n(_precio) != p.precio) 'precio': n(_precio),
      if (n(_costo) != null && n(_costo) != p.costo) 'costo': n(_costo),
      if (n(_minimo) != null && n(_minimo) != p.stockMinimo) 'stockMinimo': n(_minimo),
      if (codigo != (p.codigoBarras ?? '')) 'codigoBarras': codigo.isEmpty ? null : codigo,
    };
    if (cambios.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _guardando = true);
    try {
      await StockApi.editarProducto(widget.rid, p.id, cambios);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final margen = p.precio > 0 && p.costo > 0 ? (p.precio - p.costo) / p.precio : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.nombre, style: AppTypography.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Stock ${_cant(p.stock)} ${p.unidad}'
                '${margen != null ? ' · margen ${(margen * 100).toStringAsFixed(0)} %' : ''}',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 12),
              _Campo('Nombre', _nombre),
              _Campo('Código de barras', _codigo, numerico: true),
              Row(
                children: [
                  Expanded(child: _Campo('Precio de venta', _precio, numerico: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _Campo('Costo', _costo, numerico: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _Campo('Mínimo', _minimo, numerico: true)),
                ],
              ),
              Text(
                'El stock se cambia con Entrada, Salida o Conteo, para que quede registrado.',
                style: AppTypography.caption,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppColors.rojoAlerta)),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranjaAccion),
                  child: Text(
                    'Guardar cambios',
                    style: AppTypography.labelLarge.copyWith(color: AppColors.textoClaroAlto),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Últimos movimientos', style: AppTypography.titleMedium),
              const SizedBox(height: 6),
              if (_movs == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_movs!.isEmpty)
                Text('Sin movimientos todavía', style: AppTypography.caption)
              else
                for (final m in _movs!) _FilaMovimiento(m),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

InputDecoration _decoracion(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  filled: true,
  fillColor: const Color(0xFF1E293B),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
);

class _Campo extends StatelessWidget {
  const _Campo(this.label, this.ctrl, {this.hint, this.numerico = false, this.autofocus = false});
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final bool numerico;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      autofocus: autofocus,
      keyboardType: numerico ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters: numerico ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
      style: AppTypography.bodyLarge,
      decoration: _decoracion(label, hint: hint),
    ),
  );
}

class _ResumenValor extends StatelessWidget {
  const _ResumenValor({required this.valor, required this.stockBajo});
  final ValorInventario valor;
  final int stockBajo;

  @override
  Widget build(BuildContext context) {
    Widget dato(String t, String v, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: AppTypography.caption),
          const SizedBox(height: 2),
          Text(v, style: AppTypography.titleMedium.copyWith(color: color)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            children: [
              dato('Inventario a costo', _fmt.format(valor.valorCosto)),
              dato('A precio de venta', _fmt.format(valor.valorVenta), color: AppColors.verdeExito),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              dato('Unidades', _cant(valor.unidades)),
              dato('Stock bajo', '$stockBajo', color: stockBajo > 0 ? AppColors.naranjaAccion : null),
              dato(
                'Sin costo',
                '${valor.productosSinCosto}',
                color: valor.productosSinCosto > 0 ? AppColors.rojoAlerta : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({required this.producto, required this.onTap});
  final Producto producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final colorStock = p.stock < 0
        ? AppColors.rojoAlerta
        : p.stockBajo
        ? AppColors.naranjaAccion
        : AppColors.textoClaroAlto;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre, style: AppTypography.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        [
                          p.codigoBarras ?? 'sin código',
                          'venta ${_fmt.format(p.precio)}',
                          p.costo > 0 ? 'costo ${_fmt.format(p.costo)}' : 'sin costo',
                        ].join(' · '),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_cant(p.stock), style: AppTypography.titleLarge.copyWith(color: colorStock)),
                    Text('mín ${_cant(p.stockMinimo)}', style: AppTypography.caption),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento(this.m);
  final MovimientoStock m;

  static final _f = DateFormat('d MMM HH:mm', 'es');
  static const _nombres = {
    'entrada': 'Entrada',
    'venta': 'Venta',
    'salida': 'Salida',
    'ajuste': 'Conteo',
    'importacion': 'Importación',
  };

  @override
  Widget build(BuildContext context) {
    final positivo = m.cantidad > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(_f.format(m.fecha), style: AppTypography.caption)),
          Expanded(
            child: Text(
              [
                _nombres[m.tipo] ?? m.tipo,
                if (m.motivo.isNotEmpty) m.motivo,
                if (m.nota.isNotEmpty) m.nota,
              ].join(' · '),
              style: AppTypography.bodyMedium,
            ),
          ),
          Text(
            '${positivo ? '+' : ''}${_cant(m.cantidad)}',
            style: AppTypography.labelLarge.copyWith(color: positivo ? AppColors.verdeExito : AppColors.rojoAlerta),
          ),
          SizedBox(
            width: 52,
            child: Text('→ ${_cant(m.stockResultante)}', textAlign: TextAlign.right, style: AppTypography.caption),
          ),
        ],
      ),
    );
  }
}
