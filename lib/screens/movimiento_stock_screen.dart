import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_design_system.dart';
import '../core/api_exception.dart';
import '../mock/mock_api.dart';
import '../widgets/scan_field.dart';
import 'productos_stock_screen.dart';

/// Qué hace la pantalla con lo escaneado.
enum TipoMovimiento {
  /// Llega mercancía: suma stock y, si trae costo, actualiza el costo promedio.
  entrada('Entrada de mercancía', 'Cantidad que llega', 'Registrar entrada', AppColors.verdeExito),

  /// Sale sin venderse (merma, consumo, cortesía, vencido).
  salida('Salida sin venta', 'Cantidad que sale', 'Registrar salida', AppColors.rojoAlerta),

  /// Conteo físico: el stock pasa a ser lo contado.
  conteo('Conteo de inventario', 'Cantidad contada', 'Guardar conteo', Color(0xFF60A5FA));

  const TipoMovimiento(this.titulo, this.etiquetaCantidad, this.boton, this.color);
  final String titulo;
  final String etiquetaCantidad;
  final String boton;
  final Color color;
}

class _Linea {
  _Linea(this.producto, {String cantidad = '1', String costo = ''})
    : cantidad = TextEditingController(text: cantidad),
      costo = TextEditingController(text: costo);

  final Producto producto;
  final TextEditingController cantidad;
  final TextEditingController costo;

  double? get valor => double.tryParse(cantidad.text.replaceAll(',', '.'));
  double? get costoValor => costo.text.trim().isEmpty ? null : double.tryParse(costo.text.replaceAll(',', '.'));

  void dispose() {
    cantidad.dispose();
    costo.dispose();
  }
}

class MovimientoStockScreen extends StatefulWidget {
  const MovimientoStockScreen({super.key, required this.restaurant, required this.tipo});

  final Restaurant restaurant;
  final TipoMovimiento tipo;

  @override
  State<MovimientoStockScreen> createState() => _MovimientoStockScreenState();
}

class _MovimientoStockScreenState extends State<MovimientoStockScreen> {
  static const _motivos = ['merma', 'consumo propio', 'cortesía', 'vencido', 'otro'];

  final _scan = GlobalKey<ScanFieldState>();
  final _nota = TextEditingController();
  final List<_Linea> _lineas = [];
  String _motivo = _motivos.first;
  bool _guardando = false;

  TipoMovimiento get _tipo => widget.tipo;
  String get _rid => widget.restaurant.id;

  @override
  void dispose() {
    for (final l in _lineas) {
      l.dispose();
    }
    _nota.dispose();
    super.dispose();
  }

  String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _agregar(Producto p) {
    setState(() {
      final i = _lineas.indexWhere((l) => l.producto.id == p.id);
      if (i >= 0) {
        // Escanear dos veces el mismo producto suma uno más (como contar botellas)
        final l = _lineas[i];
        l.cantidad.text = _num((l.valor ?? 0) + 1);
        _lineas.insert(0, _lineas.removeAt(i));
      } else {
        _lineas.insert(
          0,
          _Linea(p, cantidad: '1', costo: _tipo == TipoMovimiento.entrada && p.costo > 0 ? _num(p.costo) : ''),
        );
      }
    });
  }

  Future<void> _codigoNuevo(String codigo) async {
    if (_tipo != TipoMovimiento.entrada) {
      _aviso('El código $codigo no está registrado');
      return;
    }
    final p = await mostrarFormProducto(context, _rid, codigo: codigo);
    if (p != null) _agregar(p);
    _scan.currentState?.enfocar();
  }

  void _aviso(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _guardar() async {
    if (_lineas.isEmpty || _guardando) return;
    final invalida = _lineas.where((l) {
      final v = l.valor;
      return v == null || v < 0 || (_tipo != TipoMovimiento.conteo && v == 0);
    });
    if (invalida.isNotEmpty) {
      _aviso('Revisa la cantidad de «${invalida.first.producto.nombre}»');
      return;
    }
    setState(() => _guardando = true);
    try {
      switch (_tipo) {
        case TipoMovimiento.entrada:
          await StockApi.entrada(_rid, [
            for (final l in _lineas) {'productoId': l.producto.id, 'cantidad': l.valor, 'costoUnitario': ?l.costoValor},
          ], nota: _nota.text.trim());
        case TipoMovimiento.salida:
          await StockApi.salida(
            _rid,
            [
              for (final l in _lineas) {'productoId': l.producto.id, 'cantidad': l.valor},
            ],
            motivo: _motivo,
            nota: _nota.text.trim(),
          );
        case TipoMovimiento.conteo:
          await StockApi.ajuste(_rid, [
            for (final l in _lineas) {'productoId': l.producto.id, 'stockReal': l.valor},
          ], nota: _nota.text.trim());
      }
      if (!mounted) return;
      _aviso('${_tipo.titulo}: ${_lineas.length} producto(s) guardado(s)');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _aviso(e.message);
      setState(() => _guardando = false);
    } catch (_) {
      _aviso('Sin conexión: no se guardó');
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        title: Text(_tipo.titulo, style: AppTypography.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScanField(
              key: _scan,
              restaurantId: _rid,
              soloConStock: true,
              onProducto: _agregar,
              onCodigoNuevo: _codigoNuevo,
            ),
            if (_tipo == TipoMovimiento.salida) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in _motivos)
                    ChoiceChip(label: Text(m), selected: m == _motivo, onSelected: (_) => setState(() => _motivo = m)),
                ],
              ),
            ],
            if (_tipo == TipoMovimiento.conteo) ...[
              const SizedBox(height: 8),
              Text(
                'Escanea cada botella: cada lectura suma 1. Al guardar, el stock de esos '
                'productos pasa a ser lo contado; los que no escanees no cambian.',
                style: AppTypography.caption,
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _lineas.isEmpty
                  ? Center(child: Text('Escanea o busca los productos', style: AppTypography.bodyMedium))
                  : ListView.separated(
                      itemCount: _lineas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _fila(_lineas[i]),
                    ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nota,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: _tipo == TipoMovimiento.entrada ? 'Nota (proveedor, factura…)' : 'Nota (opcional)',
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _lineas.isEmpty || _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tipo.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _guardando ? 'Guardando…' : '${_tipo.boton} (${_lineas.length})',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.textoClaroAlto),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(_Linea l) {
    final p = l.producto;
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.fondoOscuro,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
    final numeros = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    String detalle = 'En sistema: ${_num(p.stock)}';
    if (_tipo == TipoMovimiento.conteo && l.valor != null) {
      final diff = l.valor! - p.stock;
      if (diff != 0) detalle += ' · diferencia ${diff > 0 ? '+' : ''}${_num(diff)}';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre, style: AppTypography.bodyLarge),
                const SizedBox(height: 2),
                Text(detalle, style: AppTypography.caption),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: l.cantidad,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numeros,
              onChanged: (_) => setState(() {}),
              style: AppTypography.bodyLarge,
              decoration: deco(_tipo == TipoMovimiento.conteo ? 'Contado' : 'Cantidad'),
            ),
          ),
          if (_tipo == TipoMovimiento.entrada) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: l.costo,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numeros,
                style: AppTypography.bodyLarge,
                decoration: deco('Costo c/u'),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.close, color: AppColors.textoClaroMedio, size: 20),
            onPressed: () => setState(() {
              _lineas.remove(l);
              l.dispose();
            }),
          ),
        ],
      ),
    );
  }
}
