// lib/profile/my_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Use your globals directly
import 'package:luckygo_pemandu/global.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});
  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  final _money = NumberFormat('#,##0.00');

  Future<DocumentSnapshot<Map<String, dynamic>>> _load() {
    return FirebaseFirestore.instance
        .collection(Gv.negara!)
        .doc(Gv.negeri!)
        .collection('driver_account')
        .doc(Gv.loggedUser!)
        .get();
  }

  String _s(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString();
  }

  String _date(dynamic dt) {
    if (dt == null) return '';
    if (dt is Timestamp) {
      return DateFormat('dd MMM yyyy, HH:mm').format(dt.toDate());
    }
    if (dt is String) return dt;
    return '';
  }

  double _d(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  bool _b(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  int _docCount(Map<String, dynamic> m) {
    const keys = <String>[
      'reg_ic_image_url',
      'reg_selfie_image_url',
      'reg_car_front_image_url',
      'reg_car_back_image_url',
      'reg_road_tax_image_url',
      'reg_insurance_image_url',
      'reg_drivers_license_image_url',
      'reg_psv_image_url',
    ];
    return keys.where((k) => _s(m, k).isNotEmpty).length;
  }

  void _openImage(String url, String title) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenImageView(url: url, title: title),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      );

  Widget _line({
    required String label,
    required String value,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: leading,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: (value.isEmpty)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(value, style: const TextStyle(fontSize: 15)),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _spacer() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _imageIcon(String url, String title) {
    if (url.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.image_outlined),
      tooltip: 'View $title',
      onPressed: () => _openImage(url, title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text(''));
          }

          final data = snap.data!.data()!;
          final photoUrl = _s(data, 'reg_selfie_image_url');
          final name = _s(data, 'fullname');
          final phone = Gv.loggedUser ?? '';
          final email = _s(data, 'email');
          final area = _s(data, 'area');
          final countryStr = _s(data, 'country');
          final stateStr = _s(data, 'state');
          final language = _s(data, 'language');

          final plate = _s(data, 'reg_vehicle_plate');
          final brand = _s(data, 'reg_vehicle_brand');
          final model = _s(data, 'reg_vehicle_model');
          final color = _s(data, 'reg_vehicle_color');
          final capacity = _d(data, 'reg_vehicle_capacity');

          final ab = _d(data, 'account_balance');
          final lastPay = _d(data, 'last_payment_amount');
          final lastPayAt = _date(data['last_payment_timestamp']);

          final regApproved = _b(data, 'registration_approved');
          final regApprovedAt = _date(data['registration_approved_timestamp']);
          final regRemark = _s(data, 'registration_remark');
          final regRemarkAt = _date(data['registration_remark_timestamp']);

          final docsCount = _docCount(data);

          final icNo = _s(data, 'reg_ic_no');
          final dlExp = _s(data, 'reg_drivers_license_expiry');
          final insExp = _s(data, 'reg_insurance_expiry');
          final roadTaxExp = _s(data, 'reg_road_tax_expiry');
          final psvExp = _s(data, 'reg_psv_expiry');

          // image URLs
          final icUrl = _s(data, 'reg_ic_image_url');
          final selfieUrl = _s(data, 'reg_selfie_image_url');
          final carFrontUrl = _s(data, 'reg_car_front_image_url');
          final carBackUrl = _s(data, 'reg_car_back_image_url');
          final roadTaxUrl = _s(data, 'reg_road_tax_image_url');
          final insuranceUrl = _s(data, 'reg_insurance_image_url');
          final dlUrl = _s(data, 'reg_drivers_license_image_url');
          final psvUrl = _s(data, 'reg_psv_image_url');

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Personal
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Personal Information'),
                    _line(
                      label: 'Profile Photo',
                      value: '',
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: (photoUrl.isEmpty && name.isNotEmpty)
                            ? Text(
                                name.trim()[0].toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      trailing: _imageIcon(selfieUrl, 'Profile Photo'),
                    ),
                    _spacer(),
                    _line(label: 'Name', value: name),
                    _spacer(),
                    _line(label: 'Phone Number', value: phone),
                    _spacer(),
                    _line(label: 'Email Address', value: email),
                    _spacer(),
                    _line(label: 'Language', value: language),
                    _spacer(),
                    _line(
                      label: 'Location',
                      value: [
                        if (area.isNotEmpty) area,
                        if (stateStr.isNotEmpty) stateStr,
                        if (countryStr.isNotEmpty) countryStr,
                      ].join(area.isNotEmpty ? ', ' : ''),
                    ),
                  ],
                ),
              ),

              // Vehicle
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Vehicle Information'),
                    _line(
                      label: plate,
                      value: (brand.isEmpty && model.isEmpty)
                          ? ''
                          : [brand, model].where((e) => e.isNotEmpty).join(' '),
                      trailing: regApproved
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox.shrink(),
                    ),
                    _spacer(),
                    _line(label: 'Color', value: color),
                    _spacer(),
                    _line(
                        label: 'Capacity',
                        value: capacity == 0 ? '' : capacity.toStringAsFixed(0)),
                    const SizedBox(height: 8),
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: TextButton(
                        onPressed: () {/* hook up later */},
                        child: const Text('Change Vehicle'),
                      ),
                    ),
                  ],
                ),
              ),

              // Documents
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Documents'),
                    _line(
                        label:
                            docsCount == 0 ? '' : '$docsCount documents',
                        value: ''),
                    _spacer(),
                    _line(
                      label: 'IC Number',
                      value: icNo,
                      trailing: _imageIcon(icUrl, 'IC'),
                    ),
                    _spacer(),
                    _line(
                      label: 'Driver’s License Expiry',
                      value: dlExp,
                      trailing: _imageIcon(dlUrl, 'Driver’s License'),
                    ),
                    _spacer(),
                    _line(
                      label: 'Insurance Expiry',
                      value: insExp,
                      trailing: _imageIcon(insuranceUrl, 'Insurance'),
                    ),
                    _spacer(),
                    _line(
                      label: 'Road Tax Expiry',
                      value: roadTaxExp,
                      trailing: _imageIcon(roadTaxUrl, 'Road Tax'),
                    ),
                    _spacer(),
                    _line(
                      label: 'PSV Expiry',
                      value: psvExp,
                      trailing: _imageIcon(psvUrl, 'PSV'),
                    ),
                    _spacer(),
                    _line(
                      label: 'Car (Front)',
                      value: '',
                      trailing: _imageIcon(carFrontUrl, 'Car Front'),
                    ),
                    _spacer(),
                    _line(
                      label: 'Car (Back)',
                      value: '',
                      trailing: _imageIcon(carBackUrl, 'Car Back'),
                    ),
                  ],
                ),
              ),

              // Wallet
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Wallet'),
                    _line(
                      label: 'Account Balance',
                      value: ab == 0 ? '' : 'RM ${_money.format(ab)}',
                    ),
                    _spacer(),
                    _line(
                      label: 'Last Payment',
                      value: (lastPay == 0 && lastPayAt.isEmpty)
                          ? ''
                          : [
                              if (lastPay != 0) 'RM ${_money.format(lastPay)}',
                              if (lastPayAt.isNotEmpty) lastPayAt,
                            ].join(' • '),
                    ),
                  ],
                ),
              ),

              // Registration
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Registration'),
                    _line(
                      label: 'Approved',
                      value: regApproved ? 'Yes' : '',
                      trailing: regApproved
                          ? const Icon(Icons.verified, color: Colors.green)
                          : const SizedBox.shrink(),
                    ),
                    _spacer(),
                    _line(label: 'Approved At', value: regApprovedAt),
                    _spacer(),
                    _line(label: 'Admin Remark', value: regRemark),
                    _spacer(),
                    _line(label: 'Remark Time', value: regRemarkAt),
                  ],
                ),
              ),

              // Manage account
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Manage Your Account'),
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(''),
                      onTap: () {
                        // Hook up your delete flow here
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full-screen image viewer with a top-right red × button
class FullscreenImageView extends StatelessWidget {
  final String url;
  final String title;
  const FullscreenImageView({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered interactive image
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: url,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Title (optional)
            Positioned(
              left: 16,
              top: 12,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Close (red ×)
            Positioned(
              right: 8,
              top: 4,
              child: IconButton(
                iconSize: 30,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: Colors.redAccent,
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
