import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_design_system.dart';
import '../core/api_exception.dart';
import '../mock/mock_api.dart';
import '../widgets/ancho_maximo.dart';

/// Ventas, costo, utilidad y margen del periodo, por categoría y por producto.
class ReporteVentasScreen extends StatefulWidget {
  const ReporteVentasScreen({super.key, required this.restaurant, required this.user});

  final Restaurant restaurant;
  final AppUser user;

  @override
  State<ReporteVentasScreen> createState() => _ReporteVentasScreenState();
}

enum _Periodo {
  hoy('Hoy'),
  ayer('Ayer'),
  semana('7 días'),
  mes('Este mes'),
  mesPasado('Mes pasado');

  const _Periodo(this.nombre);
  final String nombre;
}

class _ReporteVentasScreenState extends State<ReporteVentasScreen> {
  static final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  static final _dia = DateFormat("EEE d 'de' MMM", 'es');

  _Periodo _periodo = _Periodo.hoy;
  // Negocio nocturno: lo vendido a las 2 a.m. cuenta para la noche anterior.
  bool _diaComercial = true;
  ReporteVentas? _rep;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  (DateTime, DateTime) get _rango {
    final ahora = DateTime.now();
    // Con día comercial, antes de las 6 a.m. todavía es "la noche de ayer".
    final hoy = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    ).subtract(Duration(days: _diaComercial && ahora.hour < 6 ? 1 : 0));
    return switch (_periodo) {
      _Periodo.hoy => (hoy, hoy),
      _Periodo.ayer => (hoy.subtract(const Duration(days: 1)), hoy.subtract(const Duration(days: 1))),
      _Periodo.semana => (hoy.subtract(const Duration(days: 6)), hoy),
      _Periodo.mes => (DateTime(hoy.year, hoy.month, 1), hoy),
      _Periodo.mesPasado => (DateTime(hoy.year, hoy.month - 1, 1), DateTime(hoy.year, hoy.month, 0)),
    };
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final (desde, hasta) = _rango;
    try {
      final r = await StockApi.reporteVentas(
        widget.restaurant.id,
        desde: desde,
        hasta: hasta,
        horaCorte: _diaComercial ? 6 : 0,
      );
      if (!mounted) return;
      setState(() {
        _rep = r;
        _cargando = false;
      });
    } on ApiException catch (e) {
      _fallo(e.message);
    } catch (_) {
      _fallo('Sin conexión con el servidor');
    }
  }

  void _fallo(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (desde, hasta) = _rango;
    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppColors.fondoOscuro,
        elevation: 0,
        title: Text('Reporte de ventas', style: AppTypography.titleLarge),
      ),
      body: AnchoMaximo(
        max: AnchoMaximo.anchoLista,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _Periodo.values)
                ChoiceChip(
                  label: Text(p.nombre),
                  selected: p == _periodo,
                  onSelected: (_) {
                    setState(() => _periodo = p);
                    _cargar();
                  },
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _diaComercial,
            onChanged: (v) {
              setState(() => _diaComercial = v);
              _cargar();
            },
            title: Text('El día cierra a las 6 a.m.', style: AppTypography.bodyMedium),
            subtitle: Text('Lo vendido de madrugada cuenta para la noche anterior', style: AppTypography.caption),
          ),
          Text(
            desde == hasta ? _dia.format(desde) : '${_dia.format(desde)} – ${_dia.format(hasta)}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center, style: AppTypography.bodyMedium),
            )
          else
            ..._contenido(_rep!),
        ],
      ),
      ),
    );
  }

  List<Widget> _contenido(ReporteVentas r) {
    final sinCosto = r.totalVentas - r.ventasConCosto;
    return [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Kpi('Ventas', _fmt.format(r.totalVentas), color: AppColors.naranjaAccion),
          _Kpi('Tickets', '${r.tickets}'),
          _Kpi('Ticket promedio', _fmt.format(r.ticketPromedio)),
          _Kpi('Utilidad', _fmt.format(r.utilidad), color: AppColors.verdeExito),
          _Kpi('Margen', '${(r.margen * 100).toStringAsFixed(1)} %'),
          _Kpi(
            'Salió sin venderse',
            '${r.salidasUnidades.toStringAsFixed(0)} und · ${_fmt.format(r.salidasCosto)}',
            color: r.salidasUnidades > 0 ? AppColors.rojoAlerta : null,
          ),
        ],
      ),
      if (sinCosto > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'La utilidad se calcula sobre ${_fmt.format(r.ventasConCosto)}: '
            '${_fmt.format(sinCosto)} se vendieron sin costo registrado.',
            style: AppTypography.caption,
          ),
        ),
      const SizedBox(height: 20),
      Text('Por categoría', style: AppTypography.titleMedium),
      const SizedBox(height: 6),
      if (r.porCategoria.isEmpty) Text('Sin ventas en el periodo', style: AppTypography.caption),
      for (final f in r.porCategoria) _Fila(f, total: r.totalVentas, fmt: _fmt),
      const SizedBox(height: 20),
      Text('Más vendidos', style: AppTypography.titleMedium),
      const SizedBox(height: 6),
      for (final f in r.masVendidos) _Fila(f, total: r.totalVentas, fmt: _fmt, conCantidad: true),
    ];
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.titulo, this.valor, {this.color});
  final String titulo;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: 165,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: AppTypography.caption),
        const SizedBox(height: 4),
        Text(valor, style: AppTypography.titleMedium.copyWith(color: color)),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila(this.f, {required this.total, required this.fmt, this.conCantidad = false});
  final FilaVentas f;
  final double total;
  final NumberFormat fmt;
  final bool conCantidad;

  @override
  Widget build(BuildContext context) {
    final parte = total > 0 ? f.ventas / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  conCantidad
                      ? '${f.cantidad.toStringAsFixed(0)} × ${f.nombre}'
                      : (f.nombre.isEmpty ? 'Sin categoría' : f.nombre),
                  style: AppTypography.bodyMedium,
                ),
              ),
              Text(fmt.format(f.ventas), style: AppTypography.labelLarge),
              SizedBox(
                width: 110,
                child: Text(
                  'util. ${fmt.format(f.utilidad)}',
                  textAlign: TextAlign.right,
                  style: AppTypography.caption.copyWith(color: AppColors.verdeExito),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: parte.clamp(0, 1),
              minHeight: 5,
              backgroundColor: const Color(0xFF1E293B),
              color: AppColors.naranjaAccion,
            ),
          ),
        ],
      ),
    );
  }
}
