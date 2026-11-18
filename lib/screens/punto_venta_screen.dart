import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../core/api_exception.dart';
import '../mock/mock_api.dart';
import '../widgets/scan_field.dart';

/// Venta de mostrador (licorera/tienda): se escanea o busca cada producto,
/// se cobra con un método de pago y el backend descuenta el stock.
class PuntoVentaScreen extends StatefulWidget {
  const PuntoVentaScreen({super.key, required this.restaurant, required this.user});

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<PuntoVentaScreen> createState() => _PuntoVentaScreenState();
}

class _PuntoVentaScreenState extends State<PuntoVentaScreen> {
  static final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  final _scan = GlobalKey<ScanFieldState>();
  final _recibidoCtrl = TextEditingController();
  final List<LineaVenta> _lineas = [];
  late final List<String> _metodos;
  late String _metodo;
  bool _cobrando = false;
  String? _ultimaVenta; // resumen de la venta anterior, para el cajero

  @override
  void initState() {
    super.initState();
    _metodos = widget.restaurant.paymentMethods.isEmpty ? const ['efectivo'] : widget.restaurant.paymentMethods;
    _metodo = _metodos.first;
  }

  @override
  void dispose() {
    _recibidoCtrl.dispose();
    super.dispose();
  }

  double get _total => _lineas.fold(0, (s, l) => s + l.subtotal);
  int get _unidades => _lineas.fold(0, (s, l) => s + l.cantidad);
  bool get _esEfectivo => _metodo.toLowerCase().contains('efectivo');
  double get _recibido => double.tryParse(_recibidoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  double get _cambio => _recibido - _total;

  void _agregar(Producto p) {
    setState(() {
      final i = _lineas.indexWhere((l) => l.producto.id == p.id);
      if (i >= 0) {
        final l = _lineas.removeAt(i);
        l.cantidad++;
        _lineas.insert(0, l); // lo último escaneado arriba
      } else {
        _lineas.insert(0, LineaVenta(p));
      }
      _ultimaVenta = null;
    });
  }

  void _cambiarCantidad(LineaVenta l, int delta) {
    setState(() {
      l.cantidad += delta;
      if (l.cantidad <= 0) _lineas.remove(l);
    });
    _scan.currentState?.enfocar();
  }

  Future<void> _cobrar() async {
    if (_lineas.isEmpty || _cobrando) return;
    if (_esEfectivo && _recibidoCtrl.text.isNotEmpty && _cambio < 0) {
      _aviso('El efectivo recibido no alcanza');
      return;
    }
    setState(() => _cobrando = true);
    try {
      await StockApi.venderMostrador(widget.restaurant.id, lineas: _lineas, metodoPago: _metodo);
      final resumen = StringBuffer('Venta de ${_fmt.format(_total)} en $_metodo');
      if (_esEfectivo && _recibidoCtrl.text.isNotEmpty) {
        resumen.write(' · cambio ${_fmt.format(_cambio)}');
      }
      setState(() {
        _ultimaVenta = resumen.toString();
        _lineas.clear();
        _recibidoCtrl.clear();
      });
    } on ApiException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('Sin conexión: la venta NO se registró');
    } finally {
      if (mounted) setState(() => _cobrando = false);
      _scan.currentState?.enfocar();
    }
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width >= 900;
    final carrito = _Carrito(lineas: _lineas, fmt: _fmt, onCantidad: _cambiarCantidad);
    final resumen = _resumen();

    return CallbackShortcuts(
      // F9 cobra sin soltar el lector (atajo habitual en cajas)
      bindings: {const SingleActivator(LogicalKeyboardKey.f9): _cobrar},
      child: Scaffold(
        backgroundColor: AppColors.fondoOscuro,
        appBar: AppBar(
          backgroundColor: AppColors.fondoOscuro,
          elevation: 0,
          title: Text('Venta rápida', style: AppTypography.titleLarge),
          actions: [
            if (_lineas.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(_lineas.clear),
                icon: const Icon(Icons.delete_outline, color: AppColors.rojoAlerta, size: 18),
                label: Text('Vaciar', style: AppTypography.labelLarge.copyWith(color: AppColors.rojoAlerta)),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScanField(key: _scan, restaurantId: widget.restaurant.id, onProducto: _agregar),
              if (_ultimaVenta != null) ...[const SizedBox(height: 10), _Banner(texto: _ultimaVenta!)],
              const SizedBox(height: 12),
              Expanded(
                child: ancho
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: carrito),
                          const SizedBox(width: 16),
                          SizedBox(width: 340, child: SingleChildScrollView(child: resumen)),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: carrito),
                          resumen,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumen() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Total', style: AppTypography.titleMedium),
              const SizedBox(width: 8),
              Text('$_unidades und', style: AppTypography.caption),
              const Spacer(),
              Text(_fmt.format(_total), style: AppTypography.headlineLarge.copyWith(color: AppColors.naranjaAccion)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _metodos)
                ChoiceChip(
                  label: Text(m),
                  selected: m == _metodo,
                  onSelected: (_) {
                    setState(() => _metodo = m);
                    _scan.currentState?.enfocar();
                  },
                ),
            ],
          ),
          if (_esEfectivo) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _recibidoCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _cobrar(),
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Efectivo recibido (opcional)',
                filled: true,
                fillColor: AppColors.fondoOscuro,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixText: _recibidoCtrl.text.isEmpty ? null : 'Cambio ${_fmt.format(_cambio < 0 ? 0 : _cambio)}',
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _lineas.isEmpty || _cobrando ? null : _cobrar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeBoton,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _cobrando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.point_of_sale, color: AppColors.textoClaroAlto),
              label: Text(MediaQuery.of(context).size.width >= 900 ? 'Cobrar (F9)' : 'Cobrar', style: AppTypography.labelLarge.copyWith(color: AppColors.textoClaroAlto)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Carrito extends StatelessWidget {
  const _Carrito({required this.lineas, required this.fmt, required this.onCantidad});

  final List<LineaVenta> lineas;
  final NumberFormat fmt;
  final void Function(LineaVenta, int) onCantidad;

  @override
  Widget build(BuildContext context) {
    if (lineas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2, size: 64, color: AppColors.textoTenue),
            const SizedBox(height: 8),
            Text('Escanea un producto para empezar', style: AppTypography.bodyMedium),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: lineas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final l = lineas[i];
        final p = l.producto;
        final falta = p.controlaStock && l.cantidad > p.stock;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: AppTypography.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      falta
                          ? '${fmt.format(p.precio)} c/u · en sistema quedan ${p.stock.toStringAsFixed(0)}'
                          : '${fmt.format(p.precio)} c/u',
                      style: AppTypography.caption.copyWith(color: falta ? AppColors.naranjaAccion : null),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar uno',
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.textoClaroMedio),
                onPressed: () => onCantidad(l, -1),
              ),
              SizedBox(
                width: 28,
                child: Text('${l.cantidad}', textAlign: TextAlign.center, style: AppTypography.titleMedium),
              ),
              IconButton(
                tooltip: 'Agregar uno',
                icon: const Icon(Icons.add_circle_outline, color: AppColors.naranjaAccion),
                onPressed: () => onCantidad(l, 1),
              ),
              SizedBox(
                width: 96,
                child: Text(fmt.format(l.subtotal), textAlign: TextAlign.right, style: AppTypography.titleMedium),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.verdeExito.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.verdeExito.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.verdeExito, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: AppTypography.bodyMedium)),
      ],
    ),
  );
}
