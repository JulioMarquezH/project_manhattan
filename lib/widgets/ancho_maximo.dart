import 'package:flutter/material.dart';

/// Centra el contenido y le pone un ancho máximo, para que en un computador
/// los campos, listas y botones no se estiren de borde a borde. En el
/// celular no cambia nada.
class AnchoMaximo extends StatelessWidget {
  const AnchoMaximo({super.key, required this.child, this.max = anchoLista});

  /// Para pantallas de listas y paneles.
  static const double anchoLista = 1000;

  /// Para formularios y detalles.
  static const double anchoFormulario = 760;

  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: c.maxWidth < max ? c.maxWidth : max,
        height: c.hasBoundedHeight ? c.maxHeight : null,
        child: child,
      ),
    ),
  );
}
