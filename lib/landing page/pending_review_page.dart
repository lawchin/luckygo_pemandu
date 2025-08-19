// lib/pending_review_page.dart
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';

class PandingReview extends StatelessWidget {
  const PandingReview({super.key});

  @override
  Widget build(BuildContext context) {
    
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.pendingReview)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            loc.pendingReviewText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
