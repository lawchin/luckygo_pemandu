import 'package:flutter/widgets.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';

Map<int, String> bucketLabels(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return {
  1: l.nextToYou,
  2: l.veryNear,
  3: l.quiteNear,
  4: l.stillReachable,
  5: l.nearbyZone,
  6: 'Short Drive',
  7: 'Medium Drive',
  8: 'Long Drive',
  9: 'Far Away',
  10: 'Distant Job',
  11: 'Remote Area',
  12: 'Far Region',
  13: 'Cross-State',
  14: 'Cross-Country',
  15: 'Very Far',
  };
}
