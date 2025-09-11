import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/landing page/landing_page.dart';

class DisclosureAcceptedPage extends StatefulWidget {
  const DisclosureAcceptedPage({Key? key}) : super(key: key);

  @override
  State<DisclosureAcceptedPage> createState() => _DisclosureAcceptedPageState();
}

class _DisclosureAcceptedPageState extends State<DisclosureAcceptedPage> {
  bool _accepted = false;
  bool _loading = false;

  Future<void> _handleAcceptance() async {
    print('${Gv.negara}');
    print('${Gv.negeri}');
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection(Gv.negara)
          .doc(Gv.negeri)
          .collection('driver_account')
          .doc(Gv.loggedUser)
          .update({'disclosureAccepted': true});
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update acceptance. Please try again.')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.privacy_tip, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      t.td,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      t.beforeUsing,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      value: _accepted,
                      title: Text(t.iAccept),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) => setState(() => _accepted = value ?? false),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(t.cont),
                      onPressed: _accepted && !_loading ? _handleAcceptance : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
