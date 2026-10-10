import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'VADESİ logosu', image: true,
    child: Container(
      width: size, height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [BoxShadow(color: const Color(0xFF102F32).withValues(alpha: .12),
          blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * .18),
        child: Image.asset('assets/images/vadesi_mark.png', fit: BoxFit.contain,
          excludeFromSemantics: true)),
    ),
  );
}
