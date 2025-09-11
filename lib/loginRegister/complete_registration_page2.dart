// lib/complete_registration_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// Firebase
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';

// Permissions
import 'package:permission_handler/permission_handler.dart';

// Your globals (negara, negeri, loggedUser)
import 'package:luckygo_pemandu/global.dart';

/// Stores images at: <negara>/<negeri>/<role>/<loggedUser>/<category>_<timestamp>.jpg
/// Categories used here: 'ic', 'drivers_license', 'road_tax', 'psv', 'insurance',
/// and new: 'selfie', 'car_front', 'car_back'
class CompleteRegistrationPage2 extends StatefulWidget {
  const CompleteRegistrationPage2({
    super.key,
    this.role = 'driver', // or 'passenger'
  });

  final String role;

  @override
  State<CompleteRegistrationPage2> createState() => _CompleteRegistrationPage2State();
}

class _CompleteRegistrationPage2State extends State<CompleteRegistrationPage2> {
  final _formKey = GlobalKey<FormState>();

  // ===== Vehicle fields (top of form)
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  int? _capacity; // dropdown 1..6

  // ===== Existing fields
  final _icController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _roadTaxExpiryController = TextEditingController();
  final _psvExpiryController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();

  // Pickers
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedIcImage;
  XFile? _pickedLicenseImage;
  XFile? _pickedRoadTaxImage;
  XFile? _pickedPsvImage;
  XFile? _pickedInsuranceImage;

  // Additional images
  XFile? _pickedSelfieImage;
  XFile? _pickedCarFrontImage;
  XFile? _pickedCarBackImage;

  bool _submitting = false;

  void d(String msg) => debugPrint('[COMPLETE_REG] ${DateTime.now().toIso8601String()}  $msg');

  @override
  void dispose() {
    // Vehicle
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    // Existing
    _icController.dispose();
    _licenseExpiryController.dispose();
    _roadTaxExpiryController.dispose();
    _psvExpiryController.dispose();
    _insuranceExpiryController.dispose();
    super.dispose();
  }

  // ===== Permissions helpers =====
  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    d('Permission.camera => $status');
    return status.isGranted;
  }

  Future<bool> _ensurePhotosPermissionIfNeeded() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      d('Permission.photos (iOS) => $status');
      return status.isGranted || status.isLimited;
    }
    d('Photos permission not required on this platform');
    return true;
  }

  // ===== Fullscreen sample viewer =====
  void _showFullScreenSample(BuildContext ctx, String sampleAsset, String title) {
    Navigator.of(ctx, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Hero(
                tag: sampleAsset,
                child: Image.asset(
                  sampleAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== Reusable dialog to show sample + enlarge + pick (camera/gallery) =====
  Future<void> _openUploadDialog({
    required String title,
    required String sampleAsset, // e.g. assets/images/doc_ic.png
    required void Function(XFile?) onPicked,
  }) async {
    d('OpenUploadDialog(title="$title", sample="$sampleAsset")');
    await showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        Future<void> _pick(ImageSource source) async {
          d('UploadDialog: $title -> ${source == ImageSource.camera ? 'Camera' : 'Gallery'} tapped, closing dialog...');
          Navigator.of(ctx).pop();
          await Future.delayed(const Duration(milliseconds: 120));

          try {
            if (source == ImageSource.camera) {
              final ok = await _ensureCameraPermission();
              if (!ok) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera permission is required')),
                );
                return;
              }
            } else {
              final ok = await _ensurePhotosPermissionIfNeeded();
              if (!ok) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photos permission is required')),
                );
                return;
              }
            }

            final img = await _picker.pickImage(source: source);
            if (img != null && mounted) {
              d('Picked image path: ${img.path}');
              onPicked(img);
              setState(() {}); // refresh previews
            } else {
              d('Image picking canceled.');
            }
          } catch (e) {
            d('Picker error: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to open ${source == ImageSource.camera ? 'camera' : 'gallery'}')),
            );
          }
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sample image + enlarge
                Stack(
                  children: [
                    Hero(
                      tag: sampleAsset,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.asset(
                            sampleAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              d('Sample asset NOT FOUND: $sampleAsset');
                              return Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_not_supported_outlined, size: 40),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withOpacity(0.45),
                        shape: const CircleBorder(),
                        child: IconButton(
                          splashRadius: 20,
                          iconSize: 20,
                          color: Colors.white,
                          tooltip: 'Enlarge',
                          icon: const Icon(Icons.fullscreen),
                          onPressed: () => _showFullScreenSample(ctx, sampleAsset, title),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Use camera or pick from gallery', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          iconSize: 32,
                          tooltip: 'Take Photo',
                        ),
                        const Text('Camera', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          iconSize: 32,
                          tooltip: 'Pick from Gallery',
                        ),
                        const Text('Gallery', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ===== Date picker helper =====
  Future<void> _pickDate(TextEditingController controller, String label) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
      initialDate: now,
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().split('T').first; // YYYY-MM-DD
      d('$label picked: ${controller.text}');
      setState(() {});
    } else {
      d('$label picker canceled');
    }
  }

  Future<String> _uploadOne({
    required File file,
    required String negara,
    required String negeri,
    required String role,
    required String loggedUser, // phone
    required String category,   // 'ic', 'drivers_license', 'road_tax', 'psv', 'insurance', 'selfie', 'car_front', 'car_back'
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${category}_$ts.jpg';

    final ref = FirebaseStorage.instance
        .ref()
        .child(negara)
        .child(negeri)
        .child(role)
        .child(loggedUser)
        .child(fileName);

    d('UPLOAD PATH => ${ref.fullPath}');

    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'role': role,
          'loggedUser': loggedUser,
          'category': category,
          'negara': negara,
          'negeri': negeri,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      ),
    );

    final url = await ref.getDownloadURL();
    d('Download URL => $url');
    return url;
  }

  // ===== Helpers for "submit with any one field" =====
  bool _hasAnyInput() {
    final anyText = <String>[
      _plateController.text,
      _brandController.text,
      _modelController.text,
      _colorController.text,
      _icController.text,
      _licenseExpiryController.text,
      _roadTaxExpiryController.text,
      _psvExpiryController.text,
      _insuranceExpiryController.text,
    ].any((v) => v.trim().isNotEmpty);

    final anyImage = <XFile?>[
      _pickedIcImage,
      _pickedLicenseImage,
      _pickedRoadTaxImage,
      _pickedPsvImage,
      _pickedInsuranceImage,
      _pickedSelfieImage,
      _pickedCarFrontImage,
      _pickedCarBackImage,
    ].any((x) => x != null);

    return anyText || _capacity != null || anyImage;
  }

  void _putTextIf(Map<String, dynamic> dst, String key, TextEditingController c) {
    final v = c.text.trim();
    if (v.isNotEmpty) dst[key] = v;
  }

  Future<void> _submit() async {
    // ALLOW submit if at least one input exists (any text, capacity, or image)
    if (!_hasAnyInput()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill at least one field or upload one image.')),
      );
      return;
    }

    // (Optional) add format checks ONLY for fields user actually filled:
    // e.g. if (_icController.text.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(_icController.text.trim())) { ... return; }

    setState(() => _submitting = true);

    try {
      final negara = (Gv.negara).isNotEmpty ? Gv.negara : 'UnknownCountry';
      final negeri = (Gv.negeri).isNotEmpty ? Gv.negeri : 'UnknownState';
      final role = widget.role.trim().isNotEmpty ? widget.role.trim() : 'driver';
      final phone = (Gv.loggedUser).isNotEmpty ? Gv.loggedUser : 'unknown_phone';

      d('SUBMIT start (any-one mode): negara=$negara negeri=$negeri role=$role phone=$phone');

      // Conditionally upload ONLY provided images
      Future<String?> up(String cat, XFile? xf) async {
        if (xf == null) return null;
        return _uploadOne(
          file: File(xf.path),
          negara: negara,
          negeri: negeri,
          role: role,
          loggedUser: phone,
          category: cat,
        );
      }

      final icUrl        = await up('ic',              _pickedIcImage);
      final licenseUrl   = await up('drivers_license', _pickedLicenseImage);
      final roadTaxUrl   = await up('road_tax',        _pickedRoadTaxImage);
      final psvUrl       = await up('psv',             _pickedPsvImage);
      final insuranceUrl = await up('insurance',       _pickedInsuranceImage);
      final selfieUrl    = await up('selfie',          _pickedSelfieImage);
      final carFrontUrl  = await up('car_front',       _pickedCarFrontImage);
      final carBackUrl   = await up('car_back',        _pickedCarBackImage);

      // Build payload with ONLY non-empty fields (won’t overwrite with blanks)
      final data = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
        'form2_completed': true, // keep as-is (change if you want partial to NOT mark completed)
      };

      // Vehicle
      _putTextIf(data, 'reg_vehicle_plate', _plateController);
      _putTextIf(data, 'reg_vehicle_brand', _brandController);
      _putTextIf(data, 'reg_vehicle_model', _modelController);
      _putTextIf(data, 'reg_vehicle_color', _colorController);
      if (_capacity != null) data['reg_vehicle_capacity'] = _capacity;

      // IC + docs (text parts)
      _putTextIf(data, 'reg_ic_no', _icController);
      _putTextIf(data, 'reg_drivers_license_expiry', _licenseExpiryController);
      _putTextIf(data, 'reg_road_tax_expiry', _roadTaxExpiryController);
      _putTextIf(data, 'reg_psv_expiry', _psvExpiryController);
      _putTextIf(data, 'reg_insurance_expiry', _insuranceExpiryController);

      // Image URLs (only if uploaded this time)
      if (icUrl        != null) data['reg_ic_image_url'] = icUrl;
      if (licenseUrl   != null) data['reg_drivers_license_image_url'] = licenseUrl;
      if (roadTaxUrl   != null) data['reg_road_tax_image_url'] = roadTaxUrl;
      if (psvUrl       != null) data['reg_psv_image_url'] = psvUrl;
      if (insuranceUrl != null) data['reg_insurance_image_url'] = insuranceUrl;
      if (selfieUrl    != null) data['reg_selfie_image_url'] = selfieUrl;
      if (carFrontUrl  != null) data['reg_car_front_image_url'] = carFrontUrl;
      if (carBackUrl   != null) data['reg_car_back_image_url'] = carBackUrl;

      // Save (merge keeps existing values; we only add what user provided)
      await FirebaseFirestore.instance
          .collection(negara)
          .doc(negeri)
          .collection('driver_account')
          .doc(phone)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _submitting = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Registration submitted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final negara = Gv.negara;
    final negeri = Gv.negeri;
    final role = widget.role;
    final phone = Gv.loggedUser;

    // Reusable builders
    Widget previewRow(XFile picked, VoidCallback onClear) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(picked.path),
              width: 80,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              File(picked.path).path.split(Platform.pathSeparator).last,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: 'Remove image',
          ),
        ],
      );
    }

    ElevatedButton uploadBtn({
      required String logTag,
      required String dialogTitle,
      required String sampleAsset,
      required void Function(XFile?) onPicked,
    }) {
      return ElevatedButton.icon(
        onPressed: () {
          d('UPLOAD ($logTag) tapped: negara=$negara negeri=$negeri role=$role phone=$phone '
              'plate="${_plateController.text}" brand="${_brandController.text}" model="${_modelController.text}" '
              'color="${_colorController.text}" cap="${_capacity?.toString() ?? ''}" '
              'ic="${_icController.text}" lic="${_licenseExpiryController.text}" '
              'road="${_roadTaxExpiryController.text}" psv="${_psvExpiryController.text}" '
              'ins="${_insuranceExpiryController.text}"');
          _openUploadDialog(
            title: dialogTitle,
            sampleAsset: sampleAsset,
            onPicked: onPicked,
          );
        },
        icon: const Icon(Icons.upload_file),
        label: Text(loc.upload),
      );
    }

    InputDecoration _dateDeco(String label) => InputDecoration(
      labelText: label,
      hintText: 'YYYY-MM-DD',
      border: const OutlineInputBorder(),
      suffixIcon: const Icon(Icons.calendar_today),
    );

    InputDecoration _textDeco(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );

    // We wrap the whole Scaffold in a Stack and put a ModalBarrier on top while submitting.
    return Stack(
      children: [
        Scaffold(
          // appBar: AppBar(title: Text(loc.completeReg)),
          appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  title: Text(loc.completeReg, style: const TextStyle(color: Colors.white)),
  actions: [
    IconButton(
      icon: const Text(
        '×',
        style: TextStyle(
          fontSize: 28,
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingPage()),
        );
      },
      tooltip: 'Close',
    ),
  ],
),

          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // ===== Vehicle fields (on top)
                            TextFormField(
                              controller: _plateController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _textDeco(loc.vePlateNo),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _brandController,
                              decoration: _textDeco(loc.veBrand),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _modelController,
                              decoration: _textDeco(loc.veModel),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _colorController,
                              decoration: _textDeco(loc.veColor),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _capacity,
                              decoration: _textDeco(loc.veCapacity),
                              items: List.generate(6, (i) => i + 1)
                                  .map((n) => DropdownMenuItem<int>(
                                        value: n,
                                        child: Text(n.toString()),
                                      ))
                                  .toList(),
                              onChanged: (val) => setState(() => _capacity = val),
                              validator: (val) => (val == null) ? 'Please choose 1–6' : null,
                            ),

                            const SizedBox(height: 20),

                            // ===== Row 1: IC number + Upload
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _icController,
                                    decoration: _textDeco(loc.icNo),
                                    keyboardType: TextInputType.number,
                                    validator: (val) {
                                      final v = (val ?? '').trim();
                                      if (v.isEmpty) return 'IC number is required';
                                      if (!RegExp(r'^\d{12}$').hasMatch(v)) return 'IC must be 12 digits';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: uploadBtn(
                                    logTag: 'IC',
                                    dialogTitle: 'Identity Card',
                                    sampleAsset: 'assets/images/doc_ic.png',
                                    onPicked: (img) => setState(() => _pickedIcImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedIcImage != null)
                              previewRow(_pickedIcImage!, () {
                                d('IC preview cleared');
                                setState(() => _pickedIcImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Row 2: Driver license expiry date + Upload
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _licenseExpiryController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_licenseExpiryController, 'Driver license expiry'),
                                    decoration: _dateDeco(loc.driverLicenseExDate),
                                    validator: (val) {
                                      final v = (val ?? '').trim();
                                      if (v.isEmpty) return 'Driver license expiry date is required';
                                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: uploadBtn(
                                    logTag: 'LICENSE',
                                    dialogTitle: 'Driver License',
                                    sampleAsset: 'assets/images/doc_lesen_memandu.png',
                                    onPicked: (img) => setState(() => _pickedLicenseImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedLicenseImage != null)
                              previewRow(_pickedLicenseImage!, () {
                                d('License preview cleared');
                                setState(() => _pickedLicenseImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Row 3: Road tax expiry + Upload
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _roadTaxExpiryController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_roadTaxExpiryController, 'Road tax expiry'),
                                    decoration: _dateDeco(loc.roadTaxExDate),
                                    validator: (val) {
                                      final v = (val ?? '').trim();
                                      if (v.isEmpty) return 'Road tax expiry date is required';
                                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: uploadBtn(
                                    logTag: 'ROAD_TAX',
                                    dialogTitle: 'Road Tax',
                                    sampleAsset: 'assets/images/doc_roadtax.png',
                                    onPicked: (img) => setState(() => _pickedRoadTaxImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedRoadTaxImage != null)
                              previewRow(_pickedRoadTaxImage!, () {
                                d('Road tax preview cleared');
                                setState(() => _pickedRoadTaxImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Row 4: PSV expiry + Upload
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _psvExpiryController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_psvExpiryController, 'PSV expiry'),
                                    decoration: _dateDeco(loc.psvExDate),
                                    validator: (val) {
                                      final v = (val ?? '').trim();
                                      if (v.isEmpty) return 'PSV expiry date is required';
                                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: uploadBtn(
                                    logTag: 'PSV',
                                    dialogTitle: 'PSV',
                                    sampleAsset: 'assets/images/doc_psv.png',
                                    onPicked: (img) => setState(() => _pickedPsvImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedPsvImage != null)
                              previewRow(_pickedPsvImage!, () {
                                d('PSV preview cleared');
                                setState(() => _pickedPsvImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Row 5: E-hailing insurance expiry + Upload
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _insuranceExpiryController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_insuranceExpiryController, 'Insurance expiry'),
                                    decoration: _dateDeco(loc.eInsExDate),
                                    validator: (val) {
                                      final v = (val ?? '').trim();
                                      if (v.isEmpty) return 'Insurance expiry date is required';
                                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: uploadBtn(
                                    logTag: 'INSURANCE',
                                    dialogTitle: 'Ehailing Insurance',
                                    sampleAsset: 'assets/images/doc_insurance.png',
                                    onPicked: (img) => setState(() => _pickedInsuranceImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedInsuranceImage != null)
                              previewRow(_pickedInsuranceImage!, () {
                                d('Insurance preview cleared');
                                setState(() => _pickedInsuranceImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Selfie (Text + Upload)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(loc.imgSelfie,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 40,
                                  child: uploadBtn(
                                    logTag: 'SELFIE',
                                    dialogTitle: 'Selfie',
                                    sampleAsset: 'assets/images/doc_selfie.png',
                                    onPicked: (img) => setState(() => _pickedSelfieImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedSelfieImage != null)
                              previewRow(_pickedSelfieImage!, () {
                                d('Selfie preview cleared');
                                setState(() => _pickedSelfieImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Car front
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(loc.carFront,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 40,
                                  child: uploadBtn(
                                    logTag: 'CAR_FRONT',
                                    dialogTitle: 'Car Front',
                                    sampleAsset: 'assets/images/doc_front.png',
                                    onPicked: (img) => setState(() => _pickedCarFrontImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedCarFrontImage != null)
                              previewRow(_pickedCarFrontImage!, () {
                                d('Car front preview cleared');
                                setState(() => _pickedCarFrontImage = null);
                              }),

                            const SizedBox(height: 20),

                            // Car back
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(loc.carBack,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 40,
                                  child: uploadBtn(
                                    logTag: 'CAR_BACK',
                                    dialogTitle: 'Car Back',
                                    sampleAsset: 'assets/images/doc_back.png',
                                    onPicked: (img) => setState(() => _pickedCarBackImage = img),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_pickedCarBackImage != null)
                              previewRow(_pickedCarBackImage!, () {
                                d('Car back preview cleared');
                                setState(() => _pickedCarBackImage = null);
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(loc.submit),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // === Blocking overlay while submitting ===
        if (_submitting) ...[
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withOpacity(0.35),
          ),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }
}
