import 'package:flutter/material.dart';

class KbIconHelper {
  static IconData getIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.menu_book_rounded;
    final name = iconName.toLowerCase();

    if (name.contains('truck') || name.contains('camion') || name.contains('ruta')) {
      return Icons.local_shipping_outlined;
    }
    if (name.contains('receipt') || name.contains('factura') || name.contains('porte') || name.contains('cfdi')) {
      return Icons.receipt_long_outlined;
    }
    if (name.contains('box') || name.contains('paquete') || name.contains('envio')) {
      return Icons.inventory_2_outlined;
    }
    if (name.contains('user') || name.contains('operador') || name.contains('perfil')) {
      return Icons.person_outline_rounded;
    }
    if (name.contains('alert') || name.contains('incidencia') || name.contains('warning')) {
      return Icons.warning_amber_rounded;
    }
    if (name.contains('check') || name.contains('checklist') || name.contains('task')) {
      return Icons.fact_check_outlined;
    }
    if (name.contains('money') || name.contains('wallet') || name.contains('dispersion') || name.contains('tarjeta')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (name.contains('camera') || name.contains('foto') || name.contains('evidencia')) {
      return Icons.camera_alt_outlined;
    }
    if (name.contains('help') || name.contains('question') || name.contains('faq')) {
      return Icons.help_outline_rounded;
    }
    if (name.contains('settings') || name.contains('config')) {
      return Icons.settings_outlined;
    }
    return Icons.menu_book_rounded;
  }
}
