import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/view_job_details/tips_widget.dart';// adjust path as needed

class TipsColumn extends StatelessWidget {
  final String tip1;
  final String tip2;

  const TipsColumn({
    super.key,
    required this.tip1,
    required this.tip2,
  });

  @override
  Widget build(BuildContext context) {
    final showTip1 = tip1 != '0';
    final showTip2 = tip2 != '0';

    if (!showTip1 && !showTip2) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTip1) TipsWidget(value: tip1),
        if (showTip2) ...[
          const SizedBox(height: 2),
          TipsWidget(value: tip2),
        ],
      ],
    );
  }
}
