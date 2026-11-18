import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import '../widgets/selector_productos.dart';
import 'cobrar_mesa_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Selección de una opción de ingrediente (público — usado en AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

class IngredienteSeleccion {
  final String ingrediente;
  final String opcion;
  const IngredienteSeleccion(
      {required this.ingrediente, required this.opcion});
}

// ──────────────────────────────────────────────────────────────────────────────
// Ítem de la orden (público — compartido con AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

class OrdenItem {
  OrdenItem({
    required this.producto,
    this.cantidad = 1,
    this.configuracion = const [],
  });
  final Producto producto;
  int cantidad;
  final List<IngredienteSeleccion> configuracion;
  double get subtotal => producto.precio * cantidad;

  String get configText => configuracion
      .map((s) => '${s.ingrediente}: ${s.opcion}')
      .join(' · ');
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen principal
// ──────────────────────────────────────────────────────────────────────────────

class MesaDetalleScreen extends StatefulWidget {
  const MesaDetalleScreen({
    super.key,
    required this.mesa,
    required this.restaurant,
    required this.user,
    this.ordenInicial = const [],
  });

  final Mesa            mesa;
  final Restaurant      restaurant;
  final AppUser         user;
  final List<OrdenItem> ordenInicial;

  @override
  State<MesaDetalleScreen> createState() => _MesaDetalleScreenState();
}

class _MesaDetalleScreenState extends State<MesaDetalleScreen> {
  List<Categoria>    _categorias = [];
  List<Producto>     _productos  = [];
  final List<OrdenItem> _orden   = [];
  bool _loading = true;

  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    for (final o in widget.ordenInicial) {
      _orden.add(
          OrdenItem(producto: o.producto, cantidad: o.cantidad,
              configuracion: o.configuracion));
    }
    if (widget.ordenInicial.isNotEmpty) _persistir();
    _load();
  }

  Future<void> _load() async {
    final cats  = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    final prods = await MockMenuApi.getProductos(widget.restaurant.id);
    final visibles = prods.where((p) => p.visible).toList();

    // Si no vino orden inicial, recuperar el pedido guardado de esta mesa
    if (widget.ordenInicial.isEmpty && _orden.isEmpty) {
      final pedido = await MockPedidosApi.getPedidoMesa(
          widget.restaurant.id, widget.mesa.id);
      if (pedido != null) {
        for (final it in pedido.items) {
          Producto? prod;
          for (final p in prods) {
            if (p.id == it.productoId) { prod = p; break; }
          }
          // Reconstruir configuración a partir del texto guardado
          final config = <IngredienteSeleccion>[];
          if (it.config.isNotEmpty) {
            for (final part in it.config.split(' · ')) {
              final kv = part.split(': ');
              if (kv.length == 2) {
                config.add(IngredienteSeleccion(
                    ingrediente: kv[0], opcion: kv[1]));
              }
            }
          }
          prod ??= Producto(
            id:          it.productoId,
            nombre:      it.productoNombre,
            precio:      0,
            categoriaId: it.categoriaId,
          );
          _orden.add(OrdenItem(
              producto: prod, cantidad: it.cantidad, configuracion: config));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _categorias = cats;
      _productos  = visibles;
      _loading    = false;
    });
  }

  // ── Orden helpers ──────────────────────────────────────────────────────────

  /// Persiste la orden actual en el almacén central de pedidos (para despacho).
  void _persistir() {
    final items = _orden
        .map((o) => ItemPedido(
              productoId:     o.producto.id,
              productoNombre: o.producto.nombre,
              categoriaId:    o.producto.categoriaId,
              cantidad:       o.cantidad,
              config:         o.configText,
            ))
        .toList();
    MockPedidosApi.guardarPedido(
      widget.restaurant.id,
      mesaId:     widget.mesa.id,
      mesaNumero: widget.mesa.numero,
      orden:      widget.mesa.orden,
      items:      items,
    );
  }

  /// Para productos simples: incrementa qty o crea entrada nueva
  void _cambiarCantidadPorId(String productoId, int delta) {
    setState(() {
      final idx = _orden.indexWhere(
          (o) => o.producto.id == productoId && o.configuracion.isEmpty);
      if (idx == -1) {
        if (delta > 0) {
          final prod = _productos.firstWhere((p) => p.id == productoId);
          _orden.add(OrdenItem(producto: prod));
        }
      } else {
        _orden[idx].cantidad += delta;
        if (_orden[idx].cantidad <= 0) _orden.removeAt(idx);
      }
    });
    _persistir();
  }

  /// Para productos compuestos: siempre agrega nueva entrada con config
  void _agregarCompuesto(Producto p, List<IngredienteSeleccion> config) {
    setState(() => _orden.add(
        OrdenItem(producto: p, configuracion: config)));
    _persistir();
  }

  void _cambiarCantidadPorIndex(int index, int delta) {
    setState(() {
      _orden[index].cantidad += delta;
      if (_orden[index].cantidad <= 0) _orden.removeAt(index);
    });
    _persistir();
  }

  int _cantidadEnOrden(String productoId) => _orden
      .where((o) => o.producto.id == productoId)
      .fold(0, (s, o) => s + o.cantidad);

  double get _total => _orden.fold(0.0, (s, o) => s + o.subtotal);

  void _agregar(Producto p) {
    if (!p.esCompuesto) {
      _cambiarCantidadPorId(p.id, 1);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CompositeSelectionSheet(
        producto: p,
        onConfirmar: (config) => _agregarCompuesto(p, config),
      ),
    );
  }

  // ── Cobrar ──────────────────────────────────────────────────────────────────

  Future<void> _irACobrar() async {
    // No se puede cobrar con la caja cerrada
    final caja = await MockCarteraApi.getCajaState(widget.restaurant.id);
    if (!mounted) return;
    if (caja.status == CajaStatus.cerrada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'La caja está cerrada. Ábrela en Cartera para poder cobrar.'),
          backgroundColor: AppColors.rojoBoton,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final items = _orden
        .map((o) => ItemPedido(
              productoId:     o.producto.id,
              productoNombre: o.producto.nombre,
              categoriaId:    o.producto.categoriaId,
              cantidad:       o.cantidad,
              config:         o.configText,
            ))
        .toList();

    final cobrada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CobrarMesaScreen(
          mesa:       widget.mesa,
          restaurant: widget.restaurant,
          user:       widget.user,
          items:      items,
          total:      _total,
        ),
      ),
    );
    // Si se cobró, cerrar el detalle devolviendo true para refrescar mesas
    if (cobrada == true && mounted) Navigator.pop(context, true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Mesa ${widget.mesa.numero}',
            style: AppTypography.titleLarge),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.55)),
            ),
            child: Text(
              'Orden #${widget.mesa.orden}',
              style: AppTypography.caption.copyWith(
                  color: const Color(0xFF93C5FD),
                  fontWeight: FontWeight.w700),
            ),
          ),
          // Icono de cobrar
          IconButton(
            tooltip: 'Cobrar mesa',
            onPressed: _orden.isEmpty ? null : _irACobrar,
            icon: Icon(
              Icons.point_of_sale,
              color: _orden.isEmpty
                  ? AppColors.textoTenue
                  : AppColors.verdeExito,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: _izquierda(autofocus: true),
                      ),
                    ),
                    Container(
                      width: c.maxWidth >= 1300 ? 420 : 360,
                      decoration: const BoxDecoration(
                        color: AppColors.superficie,
                        border: Border(left: BorderSide(color: AppColors.borde)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: _tituloPedido(),
                          ),
                          Expanded(
                            child: _orden.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        'Busca o toca un producto para agregarlo al pedido',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ),
                                  )
                                : ListView(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    children: _lineas(),
                                  ),
                          ),
                          _barraTotal(),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _izquierda(autofocus: false),
                        if (_orden.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _tituloPedido(),
                          const SizedBox(height: 8),
                          ..._lineas(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_orden.isNotEmpty) _barraTotal(),
              ]);
            }),
    );
  }

  Widget _izquierda({required bool autofocus}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
          if (widget.mesa.nombre.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textoClaroMedio),
              const SizedBox(width: 4),
              Text(widget.mesa.nombre, style: AppTypography.bodyMedium),
            ]),
          ],
          const SizedBox(height: 16),
          Text('Agregar al pedido', style: AppTypography.titleMedium),
          const SizedBox(height: 10),
          if (_productos.isEmpty)
            Text('No hay productos en el menú', style: AppTypography.bodyMedium)
          else
            SelectorProductos(
              categorias: _categorias,
              productos: _productos,
              cantidadFn: _cantidadEnOrden,
              onAgregar: _agregar,
              onQuitar: (p) => _cambiarCantidadPorId(p.id, -1),
              autofocus: autofocus,
            ),
        ],
      );

  Widget _tituloPedido() => Row(children: [
        Text('Pedido', style: AppTypography.titleMedium),
        const Spacer(),
        if (_orden.isNotEmpty)
          Text(
            '${_orden.fold<int>(0, (s, o) => s + o.cantidad)} und',
            style: AppTypography.caption.copyWith(color: AppColors.textoTenue),
          ),
      ]);

  List<Widget> _lineas() => [
        for (var i = 0; i < _orden.length; i++)
          LineaPedidoTile(
            nombre: _orden[i].producto.nombre,
            detalle: _orden[i].configText.isNotEmpty
                ? _orden[i].configText
                : _fmt.format(_orden[i].producto.precio),
            detalleResaltado: _orden[i].configText.isNotEmpty,
            cantidad: _orden[i].cantidad,
            subtotal: _orden[i].subtotal,
            onMenos: () => _cambiarCantidadPorIndex(i, -1),
            onMas: () => _cambiarCantidadPorIndex(i, 1),
          ),
      ];

  Widget _barraTotal() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total', style: AppTypography.caption),
                Text(
                  _fmt.format(_total),
                  style: AppTypography.titleLarge.copyWith(
                      color: AppColors.naranjaAccion, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _orden.isEmpty ? null : _irACobrar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBoton),
            icon: const Icon(Icons.point_of_sale, size: 20),
            label: const Text('Cobrar'),
          ),
        ]),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Pantalla de selección de opciones (PÚBLICO — usado también en AddMesaScreen)
// ──────────────────────────────────────────────────────────────────────────────

class CompositeSelectionSheet extends StatefulWidget {
  const CompositeSelectionSheet({
    super.key,
    required this.producto,
    required this.onConfirmar,
  });

  final Producto                                      producto;
  final void Function(List<IngredienteSeleccion>)     onConfirmar;

  @override
  State<CompositeSelectionSheet> createState() =>
      _CompositeSelectionSheetState();
}

class _CompositeSelectionSheetState
    extends State<CompositeSelectionSheet> {
  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  late final Map<String, String?> _selecciones;

  @override
  void initState() {
    super.initState();
    _selecciones = {};
    for (final ing in widget.producto.ingredientes) {
      if (ing.obligatorio && ing.opciones.isNotEmpty) {
        _selecciones[ing.nombre] = ing.opciones.first.nombre;
      } else {
        _selecciones[ing.nombre] = null; // requiere selección
      }
    }
  }

  bool get _listo =>
      _selecciones.values.every((v) => v != null);

  void _confirmar() {
    final config = widget.producto.ingredientes
        .map((ing) => IngredienteSeleccion(
              ingrediente: ing.nombre,
              opcion:      _selecciones[ing.nombre]!,
            ))
        .toList();
    widget.onConfirmar(config);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.45,
      maxChildSize:     0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:
                  AppColors.textoTenue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Encabezado: nombre + precio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.producto.nombre,
                        style: AppTypography.titleLarge),
                    Text('Elige tus opciones',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textoClaroMedio)),
                  ],
                ),
              ),
              Text(_fmt.format(widget.producto.precio),
                  style: AppTypography.titleMedium.copyWith(
                      color: AppColors.naranjaAccion,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF334155)),

          // Lista de ingredientes
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: widget.producto.ingredientes.length,
              itemBuilder: (_, i) {
                final ing = widget.producto.ingredientes[i];
                return _IngredienteSection(
                  ingrediente:    ing,
                  seleccionado:   _selecciones[ing.nombre],
                  onSeleccionar:  (opcion) =>
                      setState(() => _selecciones[ing.nombre] = opcion),
                );
              },
            ),
          ),

          // Botón confirmar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: ElevatedButton(
              onPressed: _listo ? _confirmar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.naranjaBoton,
                disabledBackgroundColor:
                    AppColors.naranjaAccion.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
              ),
              child: Text(
                _listo ? 'AÑADIR A LA ORDEN' : 'Selecciona todas las opciones',
                style: AppTypography.labelLarge.copyWith(
                    color: _listo
                        ? AppColors.textoClaroAlto
                        : AppColors.textoClaroMedio),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Sección de un ingrediente en el selection sheet ──────────────────────────

class _IngredienteSection extends StatelessWidget {
  const _IngredienteSection({
    required this.ingrediente,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final IngredienteReceta  ingrediente;
  final String?            seleccionado;
  final void Function(String) onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del ingrediente
          Row(children: [
            Text(ingrediente.nombre,
                style: AppTypography.titleMedium),
            const SizedBox(width: 6),
            if (ingrediente.obligatorio)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.verdeExito.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppColors.verdeExito
                          .withValues(alpha: 0.3)),
                ),
                child: Text('Incluido',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.verdeExito,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.naranjaAccion.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Requerido',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.naranjaAccion,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 10),

          if (ingrediente.obligatorio)
            // Auto-seleccionado — solo muestra el valor
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.verdeExito.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.verdeExito.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: AppColors.verdeExito, size: 18),
                const SizedBox(width: 10),
                Text(ingrediente.opciones.first.nombre,
                    style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.verdeExito)),
                const Spacer(),
                Text('Auto-incluido',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.verdeExito.withValues(
                            alpha: 0.7),
                        fontSize: 10)),
              ]),
            )
          else
            // Opciones seleccionables
            Column(
              children: ingrediente.opciones.map((op) {
                final selected = seleccionado == op.nombre;
                return GestureDetector(
                  onTap: () => onSeleccionar(op.nombre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.naranjaAccion
                              .withValues(alpha: 0.08)
                          : AppColors.fondoOscuro,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.naranjaAccion
                                .withValues(alpha: 0.6)
                            : AppColors.bordeControl,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      // Radio circle
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.naranjaAccion
                                : AppColors.bordeControl,
                            width: 2,
                          ),
                          color: selected
                              ? AppColors.naranjaAccion
                              : Colors.transparent,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(op.nombre,
                          style: AppTypography.bodyMedium.copyWith(
                            color: selected
                                ? AppColors.textoClaroAlto
                                : AppColors.textoClaroMedio,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

