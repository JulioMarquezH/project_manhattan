import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../core/api_exception.dart';
import '../mock/mock_api.dart';

/// Campo para escanear un código de barras o buscar un producto por nombre.
///
/// Un lector USB/Bluetooth se comporta como un teclado: escribe el código y
/// pulsa Enter. Por eso basta con un campo que mantenga el foco: funciona
/// igual en web, escritorio y en el celular con lector. Si lo escrito no es
/// un código registrado, se busca por nombre y se ofrece elegir.
class ScanField extends StatefulWidget {
  const ScanField({
    super.key,
    required this.restaurantId,
    required this.onProducto,
    this.onCodigoNuevo,
    this.soloConStock = false,
    this.hint = 'Escanea o escribe el nombre…',
  });

  final String restaurantId;
  final ValueChanged<Producto> onProducto;

  /// Si se da, al escanear un código que no existe se llama con ese código
  /// (p. ej. para ofrecer crear el producto).
  final ValueChanged<String>? onCodigoNuevo;

  /// Oculta de los resultados los productos que no controlan stock.
  final bool soloConStock;
  final String hint;

  @override
  State<ScanField> createState() => ScanFieldState();
}

class ScanFieldState extends State<ScanField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _buscando = false;

  static final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  static final _soloDigitos = RegExp(r'^\d{3,}$');

  /// Devuelve el foco al campo (después de un diálogo, un cobro, etc.).
  void enfocar() => _focus.requestFocus();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 2)));
  }

  Future<void> _resolver(String texto) async {
    texto = texto.trim();
    if (texto.isEmpty || _buscando) return;
    setState(() => _buscando = true);
    try {
      if (_soloDigitos.hasMatch(texto)) {
        final p = await StockApi.porCodigo(widget.restaurantId, texto);
        if (p != null) {
          _elegido(p);
          return;
        }
      }
      var lista = await StockApi.buscar(widget.restaurantId, texto);
      if (widget.soloConStock) lista = lista.where((p) => p.controlaStock).toList();
      if (!mounted) return;
      if (lista.length == 1) {
        _elegido(lista.first);
        return;
      }
      if (lista.isEmpty) {
        if (_soloDigitos.hasMatch(texto) && widget.onCodigoNuevo != null) {
          _ctrl.clear();
          widget.onCodigoNuevo!(texto);
        } else {
          _aviso('No hay productos con «$texto»');
          _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
        }
        return;
      }
      final elegido = await _elegir(lista);
      if (elegido != null) _elegido(elegido);
    } on ApiException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('Sin conexión con el servidor');
    } finally {
      if (mounted) {
        setState(() => _buscando = false);
        _focus.requestFocus();
      }
    }
  }

  void _elegido(Producto p) {
    _ctrl.clear();
    widget.onProducto(p);
  }

  Future<Producto?> _elegir(List<Producto> lista) => showModalBottomSheet<Producto>(
    context: context,
    backgroundColor: AppColors.fondoOscuro,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Elige el producto', style: AppTypography.titleMedium),
            ),
            for (final p in lista)
              ListTile(
                title: Text(p.nombre, style: AppTypography.bodyLarge),
                subtitle: Text(
                  [
                    if (p.codigoBarras != null) p.codigoBarras!,
                    if (p.controlaStock) 'Stock ${_cant(p.stock)}',
                  ].join(' · '),
                  style: AppTypography.caption,
                ),
                trailing: Text(_fmt.format(p.precio), style: AppTypography.labelLarge),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    ),
  );

  static String _cant(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onSubmitted: _resolver,
      style: AppTypography.bodyLarge,
      cursorColor: AppColors.naranjaAccion,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textoTenue),
        prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.naranjaAccion),
        suffixIcon: _buscando
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.search, color: AppColors.textoClaroMedio),
                onPressed: () => _resolver(_ctrl.text),
              ),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.naranjaAccion, width: 1.5),
        ),
      ),
    );
  }
}
