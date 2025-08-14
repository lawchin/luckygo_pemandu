import 'package:flutter/material.dart';

Locale? localeFromLanguageName(String? name) {
  final n = name?.toLowerCase().trim();
  if (n == null || n.isEmpty) return null;

  switch (n) {
    case 'english':
      return const Locale('en');
    case 'malay':
      return const Locale('ms');
    case 'chinese':
      return const Locale('zh'); // Simplified Chinese
    case 'indonesian':
      return const Locale('id');
    case 'portuguese':
      return const Locale('pt');
    case 'tetum':
      return const Locale('tet'); // Requires you to add app_tet.arb
    case 'javanese':
      return const Locale('jv');  // Requires you to add app_jv.arb
    case 'dusun':
      return const Locale('dtp'); // Custom locale code
    case 'fataluku':
      return const Locale('ddg'); // Custom locale code
    default:
      return null;
  }
}
