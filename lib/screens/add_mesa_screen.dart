import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';
import '../widgets/restaurant_header.dart';
import '../widgets/selector_productos.dart';
import 'mesa_detalle_screen.dart'; // OrdenItem, CompositeSelectionSheet

// ──────────────────────────────────────────────────────────────────────────────
// Resultado que se devuelve al pop
// ──────────────────────────────────────────────────────────────────────────────

class AddMesaResult {
  final Mesa            mesa;
  final List<OrdenItem> orden;
  const AddMesaResult({required this.mesa, required this.orden});
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────

class AddMesaScreen extends StatefulWidget {
  const AddMesaScreen({
    super.key,
    required this.restaurant,
    required this.user,
  });

  final Restaurant restaurant;
  final AppUser    user;

  @override
  State<AddMesaScreen> createState() => _AddMesaScreenState();
}

class _AddMesaScreenState extends State<AddMesaScreen> {
  // ── Form ───────────────────────────────────────────────────────────────────
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  bool _saving  = false;
  bool _intento = false;

  // ── Categorías + Productos ────────────────────────────────────────────────
  List<Categoria> _categorias   = [];
  List<Producto>  _productos    = [];
  bool            _loadingCats  = true;

  // ── Orden ─────────────────────────────────────────────────────────────────
  final List<OrdenItem> _orden = [];
  static final _fmt = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    final cats  = await MockCategoriasApi.getCategorias(widget.restaurant.id);
    final prods = await MockMenuApi.getProductos(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _categorias  = cats;
      _productos   = prods.where((p) => p.visible).toList();
      _loadingCats = false;
    });
  }

  // ── Validación ────────────────────────────────────────────────────────────
  bool _validar() => _numeroCtrl.text.trim().isNotEmpty;

  // ── Orden helpers ─────────────────────────────────────────────────────────
  void _cambiarCantidadPorIndex(int index, int delta) {
    setState(() {
      _orden[index].cantidad += delta;
      if (_orden[index].cantidad <= 0) _orden.removeAt(index);
    });
  }

  int _cantidadEnOrden(String productoId) => _orden
      .where((o) => o.producto.id == productoId)
      .fold(0, (s, o) => s + o.cantidad);

  double get _total => _orden.fold(0.0, (s, o) => s + o.subtotal);

  void _agregar(Producto p) {
    if (!p.esCompuesto) {
      _cambiarSimple(p, 1);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CompositeSelectionSheet(
        producto: p,
        onConfirmar: (config) =>
            setState(() => _orden.add(OrdenItem(producto: p, configuracion: config))),
      ),
    );
  }

  void _cambiarSimple(Producto p, int delta) {
    setState(() {
      final idx = _orden.indexWhere(
          (o) => o.producto.id == p.id && o.configuracion.isEmpty);
      if (idx == -1) {
        if (delta > 0) _orden.insert(0, OrdenItem(producto: p));
      } else {
        _orden[idx].cantidad += delta;
        if (_orden[idx].cantidad <= 0) _orden.removeAt(idx);
      }
    });
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intento = true);
    if (!_validar()) return;
    setState(() => _saving = true);

    final mesa = await MockAtenderMesaApi.addMesa(
      widget.restaurant.id,
      numero: int.tryParse(_numeroCtrl.text.trim()) ?? 0,
      nombre: _nombreCtrl.text.trim(),
    );

    if (!mounted) return;
    Navigator.pop(context, AddMesaResult(mesa: mesa, orden: List.of(_orden)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back, color: AppColors.textoClaroAlto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nueva mesa', style: AppTypography.titleLarge),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          // En pantallas anchas el pedido va a la derecha, siempre a la vista.
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
          return Column(
            children: [
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
              _barraTotal(),
            ],
          );
        },
      ),
    );
  }

  Widget _izquierda({required bool autofocus}) {
    final errorNumero = _intento && _numeroCtrl.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RestaurantHeader(restaurant: widget.restaurant, user: widget.user),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: _LabeledField(
                label: 'Número de mesa *',
                child: TextField(
                  controller: _numeroCtrl,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.bodyLarge,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDec(hint: 'Ej: 5', error: errorNumero),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'Cliente (opcional)',
                child: TextField(
                  controller: _nombreCtrl,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.bodyLarge,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDec(hint: 'Ej: Carlos Ruiz'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (errorNumero)
          _errorText('Escribe el número de mesa')
        else
          Text('El número de orden se asigna solo.',
              style: AppTypography.caption.copyWith(color: AppColors.textoTenue)),
        const SizedBox(height: 20),
        Text('Agregar al pedido', style: AppTypography.titleMedium),
        const SizedBox(height: 10),
        if (_loadingCats)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_productos.isEmpty)
          Text('No hay productos en el menú', style: AppTypography.bodyMedium)
        else
          SelectorProductos(
            categorias: _categorias,
            productos: _productos,
            cantidadFn: _cantidadEnOrden,
            onAgregar: _agregar,
            onQuitar: (p) => _cambiarSimple(p, -1),
            autofocus: autofocus,
          ),
      ],
    );
  }

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
            onPressed: _saving ? null : _guardar,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.table_restaurant_outlined, size: 20),
            label: const Text('Abrir mesa'),
          ),
        ]),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDec({required String hint, bool error = false}) =>
    InputDecoration(
      hintText:  hint,
      hintStyle: AppTypography.caption.copyWith(
          color: AppColors.textoTenue),
      filled:    true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: error
              ? AppColors.rojoAlerta
              : AppColors.bordeControl,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: error ? AppColors.rojoAlerta : AppColors.naranjaAccion,
        ),
      ),
    );

Widget _errorText(String msg) => Text(
      msg,
      style: AppTypography.caption.copyWith(color: AppColors.rojoAlerta),
    );

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textoClaroMedio)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

