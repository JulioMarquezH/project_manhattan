import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../mock/mock_api.dart';

final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

String _cant(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Quita tildes y pasa a minúsculas para buscar "cafe" y encontrar "Café".
String _normalizar(String s) {
  const de = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const a = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b.toString();
}

/// Buscador y cuadrícula de productos para armar un pedido.
///
/// - Busca por nombre (sin importar tildes ni el orden de las palabras),
///   por código de barras o por ID.
/// - Enter con un código de barras o ID exacto, o con un único resultado,
///   agrega el producto y limpia el campo: así funciona también con un
///   lector de código de barras, que escribe el código y pulsa Enter.
/// - Los chips filtran por categoría; la cuadrícula ocupa el ancho que haya.
class SelectorProductos extends StatefulWidget {
  const SelectorProductos({
    super.key,
    required this.categorias,
    required this.productos,
    required this.cantidadFn,
    required this.onAgregar,
    required this.onQuitar,
    this.autofocus = false,
  });

  final List<Categoria> categorias;
  final List<Producto> productos;
  final int Function(String productoId) cantidadFn;

  /// Suma uno (productos simples) o abre la configuración (compuestos).
  final void Function(Producto) onAgregar;

  /// Resta uno. Solo se ofrece para productos simples.
  final void Function(Producto) onQuitar;
  final bool autofocus;

  @override
  State<SelectorProductos> createState() => SelectorProductosState();
}

class SelectorProductosState extends State<SelectorProductos> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _categoriaId;

  void enfocar() => _focus.requestFocus();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _q => _ctrl.text.trim();

  List<Producto> get _filtrados {
    final q = _normalizar(_q);
    final palabras = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return widget.productos.where((p) {
      if (_categoriaId != null && p.categoriaId != _categoriaId) return false;
      if (palabras.isEmpty) return true;
      final nombre = _normalizar(p.nombre);
      if (palabras.every(nombre.contains)) return true;
      final codigo = p.codigoBarras ?? '';
      if (codigo.isNotEmpty && codigo.startsWith(q)) return true;
      return _normalizar(p.id).contains(q);
    }).toList();
  }

  void _enviar(String _) {
    final q = _q;
    if (q.isEmpty) return;
    Producto? elegido;
    for (final p in widget.productos) {
      if (p.codigoBarras == q || p.id == q) {
        elegido = p;
        break;
      }
    }
    final lista = _filtrados;
    if (elegido == null && lista.length == 1) elegido = lista.first;
    if (elegido == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              lista.isEmpty ? 'No hay productos con «$q»' : '${lista.length} productos: toca el que quieres',
            ),
          ),
        );
      _focus.requestFocus();
      return;
    }
    _ctrl.clear();
    setState(() {});
    widget.onAgregar(elegido);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    final conteo = <String, int>{};
    for (final p in widget.productos) {
      conteo[p.categoriaId] = (conteo[p.categoriaId] ?? 0) + 1;
    }
    final categorias = widget.categorias.where((c) => (conteo[c.id] ?? 0) > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: widget.autofocus,
          onChanged: (_) => setState(() {}),
          onSubmitted: _enviar,
          textInputAction: TextInputAction.search,
          style: AppTypography.bodyLarge,
          cursorColor: AppColors.naranjaAccion,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, código de barras o ID',
            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textoTenue),
            prefixIcon: const Icon(Icons.search, color: AppColors.textoClaroMedio),
            suffixIcon: _q.isEmpty
                ? const Tooltip(
                    message: 'Puedes usar un lector de código de barras',
                    child: Icon(Icons.qr_code_scanner, color: AppColors.textoTenue),
                  )
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.close, color: AppColors.textoClaroMedio),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {});
                      _focus.requestFocus();
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: AppColors.superficie,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.bordeControl),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.naranjaAccion, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final chips = <Widget>[
              _Filtro(
                texto: 'Todas',
                cantidad: widget.productos.length,
                elegido: _categoriaId == null,
                onTap: () => setState(() => _categoriaId = null),
              ),
              for (final c in categorias)
                _Filtro(
                  texto: c.nombre,
                  cantidad: conteo[c.id] ?? 0,
                  elegido: _categoriaId == c.id,
                  onTap: () => setState(() => _categoriaId = _categoriaId == c.id ? null : c.id),
                ),
            ];
            // En el celular, una sola fila que se desliza; en pantallas anchas, todas a la vista.
            if (c.maxWidth < 600) {
              return SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: chips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => chips[i],
                ),
              );
            }
            return Wrap(spacing: 6, runSpacing: 6, children: chips);
          },
        ),
        const SizedBox(height: 10),
        Text(
          lista.isEmpty
              ? (_q.isEmpty ? 'Sin productos en esta categoría' : 'Sin resultados para «$_q»')
              : '${lista.length} producto${lista.length == 1 ? '' : 's'}',
          style: AppTypography.caption.copyWith(color: AppColors.textoTenue),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Una columna en el celular para que el nombre se lea completo.
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: c.maxWidth < 560 ? c.maxWidth : 300,
              mainAxisExtent: 64,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: lista.length,
            itemBuilder: (_, i) {
              final p = lista[i];
              return _ProductoTile(
                producto: p,
                cantidad: widget.cantidadFn(p.id),
                onAgregar: () => widget.onAgregar(p),
                onQuitar: p.esCompuesto ? null : () => widget.onQuitar(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({required this.texto, required this.cantidad, required this.elegido, required this.onTap});

  final String texto;
  final int cantidad;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: elegido,
    child: Material(
      color: elegido ? AppColors.azulControl : AppColors.superficie,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: elegido ? AppColors.azulTexto : AppColors.bordeControl),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: texto),
                TextSpan(
                  text: '  $cantidad',
                  style: TextStyle(color: elegido ? AppColors.azulTexto : AppColors.textoTenue),
                ),
              ],
            ),
            style: AppTypography.labelLarge.copyWith(fontSize: 13, color: AppColors.textoClaroAlto),
          ),
        ),
      ),
    ),
  );
}

class _ProductoTile extends StatelessWidget {
  const _ProductoTile({required this.producto, required this.cantidad, required this.onAgregar, this.onQuitar});

  final Producto producto;
  final int cantidad;
  final VoidCallback onAgregar;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final enPedido = cantidad > 0;
    final agotado = p.controlaStock && p.stock <= 0;
    return Material(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onAgregar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: enPedido ? AppColors.naranjaAccion : AppColors.borde, width: enPedido ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(fontSize: 13, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _fmt.format(p.precio),
                            style: const TextStyle(color: AppColors.naranjaAccion, fontWeight: FontWeight.w700),
                          ),
                          if (p.controlaStock)
                            TextSpan(
                              text: agotado ? '  · agotado' : '  · ${_cant(p.stock)} ${p.unidad}',
                              style: TextStyle(color: agotado ? AppColors.rojoAlerta : AppColors.textoTenue),
                            ),
                          if (p.esCompuesto)
                            const TextSpan(
                              text: '  · personalizable',
                              style: TextStyle(color: AppColors.azulTexto),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (enPedido && onQuitar != null)
                _BotonIcono(icon: Icons.remove, tooltip: 'Quitar uno', onTap: onQuitar!),
              if (enPedido)
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.naranjaBoton, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '$cantidad',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLarge.copyWith(fontSize: 13),
                  ),
                ),
              _BotonIcono(icon: Icons.add, tooltip: 'Agregar uno', onTap: onAgregar, resaltado: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonIcono extends StatelessWidget {
  const _BotonIcono({required this.icon, required this.tooltip, required this.onTap, this.resaltado = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool resaltado;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    icon: Icon(icon, size: 20, color: resaltado ? AppColors.naranjaAccion : AppColors.textoClaroMedio),
  );
}

/// Fila de una línea del pedido: nombre, detalle, − cantidad +, subtotal.
class LineaPedidoTile extends StatelessWidget {
  const LineaPedidoTile({
    super.key,
    required this.nombre,
    required this.detalle,
    required this.cantidad,
    required this.subtotal,
    required this.onMenos,
    required this.onMas,
    this.detalleResaltado = false,
  });

  final String nombre;
  final String detalle;
  final int cantidad;
  final double subtotal;
  final VoidCallback onMenos;
  final VoidCallback onMas;

  /// El detalle es la configuración del producto (se pinta en azul).
  final bool detalleResaltado;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
    decoration: BoxDecoration(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borde),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(fontSize: 13),
              ),
              if (detalle.isNotEmpty)
                Text(
                  detalle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: detalleResaltado ? AppColors.azulTexto : AppColors.textoTenue,
                  ),
                ),
            ],
          ),
        ),
        _BotonIcono(icon: Icons.remove, tooltip: 'Quitar uno', onTap: onMenos),
        SizedBox(
          width: 24,
          child: Text(
            '$cantidad',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _BotonIcono(icon: Icons.add, tooltip: 'Agregar uno', onTap: onMas),
        SizedBox(
          width: 84,
          child: Text(
            _fmt.format(subtotal),
            textAlign: TextAlign.right,
            style: AppTypography.labelLarge.copyWith(color: AppColors.naranjaAccion, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
