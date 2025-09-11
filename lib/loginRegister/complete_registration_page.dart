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
class CompleteRegistrationPage extends StatefulWidget {
  const CompleteRegistrationPage({
    super.key,
    this.role = 'driver', // or 'passenger'
  });

  final String role;

  @override
  State<CompleteRegistrationPage> createState() => _CompleteRegistrationPageState();
}

class _CompleteRegistrationPageState extends State<CompleteRegistrationPage> {
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Ensure all required images are provided
    if (_pickedIcImage == null ||
        _pickedLicenseImage == null ||
        _pickedRoadTaxImage == null ||
        _pickedPsvImage == null ||
        _pickedInsuranceImage == null ||
        _pickedSelfieImage == null ||
        _pickedCarFrontImage == null ||
        _pickedCarBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required images.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Vehicle fields
      final plate = _plateController.text.trim();
      final brand = _brandController.text.trim();
      final model = _modelController.text.trim();
      final color = _colorController.text.trim();
      final capacity = _capacity ?? 0;

      // Other fields
      final icNumber = _icController.text.trim();
      final licenseExpiry = _licenseExpiryController.text.trim();
      final roadTaxExpiry = _roadTaxExpiryController.text.trim();
      final psvExpiry = _psvExpiryController.text.trim();
      final insuranceExpiry = _insuranceExpiryController.text.trim();

      final negara = (Gv.negara).isNotEmpty ? Gv.negara : 'UnknownCountry';
      final negeri = (Gv.negeri).isNotEmpty ? Gv.negeri : 'UnknownState';
      final role = widget.role.trim().isNotEmpty ? widget.role.trim() : 'driver';
      final phone = (Gv.loggedUser).isNotEmpty ? Gv.loggedUser : 'unknown_phone';

      d('SUBMIT start: negara=$negara negeri=$negeri role=$role phone=$phone plate=$plate cap=$capacity');

      // Upload all images
      final icUrl = await _uploadOne(file: File(_pickedIcImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'ic');
      final licenseUrl = await _uploadOne(file: File(_pickedLicenseImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'drivers_license');
      final roadTaxUrl = await _uploadOne(file: File(_pickedRoadTaxImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'road_tax');
      final psvUrl = await _uploadOne(file: File(_pickedPsvImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'psv');
      final insuranceUrl = await _uploadOne(file: File(_pickedInsuranceImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'insurance');
      final selfieUrl = await _uploadOne(file: File(_pickedSelfieImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'selfie');
      final carFrontUrl = await _uploadOne(file: File(_pickedCarFrontImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'car_front');
      final carBackUrl = await _uploadOne(file: File(_pickedCarBackImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'car_back');

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection(negara)
          .doc(negeri)
          .collection('driver_account')
          .doc(phone)
          .set({
        // Vehicle details
        'reg_vehicle_plate': plate,
        'reg_vehicle_brand': brand,
        'reg_vehicle_model': model,
        'reg_vehicle_color': color,
        'reg_vehicle_capacity': capacity,

        // IC + docs
        'reg_ic_no': icNumber,
        'reg_ic_image_url': icUrl,

        'reg_drivers_license_expiry': licenseExpiry,
        'reg_drivers_license_image_url': licenseUrl,

        'reg_road_tax_expiry': roadTaxExpiry,
        'reg_road_tax_image_url': roadTaxUrl,

        'reg_psv_expiry': psvExpiry,
        'reg_psv_image_url': psvUrl,

        'reg_insurance_expiry': insuranceExpiry,
        'reg_insurance_image_url': insuranceUrl,

        // New images (no dates)
        'reg_selfie_image_url': selfieUrl,
        'reg_car_front_image_url': carFrontUrl,
        'reg_car_back_image_url': carBackUrl,
        'form2_completed': true,

        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Done → remove overlay, show success, navigate
      if (!mounted) return;
      setState(() => _submitting = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Registration successfully submitted.'),
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
          appBar: AppBar(title: Text(loc.completeReg)),
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
                                  child: Text(loc.imgSelfie, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                                  child: Text(loc.carFront, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                                  child: Text(loc.carBack, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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



// // lib/complete_registration_page.dart
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';

// // Firebase
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// // Permissions
// import 'package:permission_handler/permission_handler.dart';

// // Your globals (negara, negeri, loggedUser)
// import 'package:luckygo_pemandu/global.dart';

// /// Stores images at: <negara>/<negeri>/<role>/<loggedUser>/<category>_<timestamp>.jpg
// /// Categories used here: 'ic', 'drivers_license', 'road_tax', 'psv', 'insurance',
// /// and new: 'selfie', 'car_front', 'car_back'
// class CompleteRegistrationPage extends StatefulWidget {
//   const CompleteRegistrationPage({
//     super.key,
//     this.role = 'driver', // or 'passenger'
//   });

//   final String role;

//   @override
//   State<CompleteRegistrationPage> createState() => _CompleteRegistrationPageState();
// }

// class _CompleteRegistrationPageState extends State<CompleteRegistrationPage> {
//   final _formKey = GlobalKey<FormState>();

//   // ===== New vehicle fields (top of form)
//   final _plateController = TextEditingController();
//   final _brandController = TextEditingController();
//   final _modelController = TextEditingController();
//   final _colorController = TextEditingController();
//   int? _capacity; // dropdown 1..6

//   // ===== Existing fields
//   final _icController = TextEditingController();
//   final _licenseExpiryController = TextEditingController();
//   final _roadTaxExpiryController = TextEditingController();
//   final _psvExpiryController = TextEditingController();
//   final _insuranceExpiryController = TextEditingController();

//   // Pickers
//   final ImagePicker _picker = ImagePicker();
//   XFile? _pickedIcImage;
//   XFile? _pickedLicenseImage;
//   XFile? _pickedRoadTaxImage;
//   XFile? _pickedPsvImage;
//   XFile? _pickedInsuranceImage;

//   // NEW picker states (label + button only)
//   XFile? _pickedSelfieImage;
//   XFile? _pickedCarFrontImage;
//   XFile? _pickedCarBackImage;

//   bool _submitting = false;

//   // logger
//   void d(String msg) => debugPrint('[COMPLETE_REG] ${DateTime.now().toIso8601String()}  $msg');

//   @override
//   void dispose() {
//     // Vehicle fields
//     _plateController.dispose();
//     _brandController.dispose();
//     _modelController.dispose();
//     _colorController.dispose();

//     // Existing
//     _icController.dispose();
//     _licenseExpiryController.dispose();
//     _roadTaxExpiryController.dispose();
//     _psvExpiryController.dispose();
//     _insuranceExpiryController.dispose();
//     super.dispose();
//   }

//   // ===== Permissions helpers =====
//   Future<bool> _ensureCameraPermission() async {
//     final status = await Permission.camera.request();
//     d('Permission.camera => $status');
//     return status.isGranted;
//   }

//   Future<bool> _ensurePhotosPermissionIfNeeded() async {
//     if (Platform.isIOS) {
//       final status = await Permission.photos.request();
//       d('Permission.photos (iOS) => $status');
//       return status.isGranted || status.isLimited;
//     }
//     d('Photos permission not required on this platform');
//     return true;
//   }

//   // ===== Fullscreen sample viewer =====
//   void _showFullScreenSample(BuildContext ctx, String sampleAsset, String title) {
//     Navigator.of(ctx, rootNavigator: true).push(
//       MaterialPageRoute(
//         builder: (_) => Scaffold(
//           backgroundColor: Colors.black,
//           appBar: AppBar(
//             backgroundColor: Colors.black,
//             foregroundColor: Colors.white,
//             title: Text(title, style: const TextStyle(color: Colors.white)),
//           ),
//           body: Center(
//             child: InteractiveViewer(
//               minScale: 0.5,
//               maxScale: 5.0,
//               child: Hero(
//                 tag: sampleAsset,
//                 child: Image.asset(
//                   sampleAsset,
//                   fit: BoxFit.contain,
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ===== Reusable dialog to show sample + enlarge + pick (camera/gallery) =====
//   Future<void> _openUploadDialog({
//     required String title,
//     required String sampleAsset, // e.g. assets/images/doc_ic.png
//     required void Function(XFile?) onPicked,
//   }) async {
//     d('OpenUploadDialog(title="$title", sample="$sampleAsset")');
//     await showDialog(
//       context: context,
//       useRootNavigator: true,
//       builder: (ctx) {
//         Future<void> _pick(ImageSource source) async {
//           d('UploadDialog: $title -> ${source == ImageSource.camera ? 'Camera' : 'Gallery'} tapped, closing dialog...');
//           // Close the dialog first, then pick (prevents hang)
//           Navigator.of(ctx).pop();
//           await Future.delayed(const Duration(milliseconds: 120));

//           try {
//             if (source == ImageSource.camera) {
//               final ok = await _ensureCameraPermission();
//               if (!ok) {
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Camera permission is required')),
//                 );
//                 return;
//               }
//             } else {
//               final ok = await _ensurePhotosPermissionIfNeeded();
//               if (!ok) {
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Photos permission is required')),
//                 );
//                 return;
//               }
//             }

//             final img = await _picker.pickImage(source: source);
//             if (img != null && mounted) {
//               d('Picked image path: ${img.path}');
//               onPicked(img);
//               setState(() {}); // refresh previews
//             } else {
//               d('Image picking canceled.');
//             }
//           } catch (e) {
//             d('Picker error: $e');
//             if (!mounted) return;
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Failed to open ${source == ImageSource.camera ? 'camera' : 'gallery'}')),
//             );
//           }
//         }

//         // finite width prevents IntrinsicWidth assertion
//         return AlertDialog(
//           title: Text(title),
//           content: SizedBox(
//             width: 360,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Sample image with ENLARGE button (top-right)
//                 Stack(
//                   children: [
//                     Hero(
//                       tag: sampleAsset,
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: AspectRatio(
//                           aspectRatio: 16 / 9,
//                           child: Image.asset(
//                             sampleAsset,
//                             fit: BoxFit.cover, // preview can crop
//                             errorBuilder: (_, __, ___) {
//                               d('Sample asset NOT FOUND: $sampleAsset');
//                               return Container(
//                                 alignment: Alignment.center,
//                                 decoration: BoxDecoration(
//                                   border: Border.all(color: Colors.grey.shade400),
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     const Icon(Icons.image_not_supported_outlined, size: 40),
//                                     const SizedBox(height: 6),
//                                     Text(
//                                       'Sample asset not found:\n$sampleAsset',
//                                       textAlign: TextAlign.center,
//                                       style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       top: 6,
//                       right: 6,
//                       child: Material(
//                         color: Colors.black.withOpacity(0.45),
//                         shape: const CircleBorder(),
//                         child: IconButton(
//                           splashRadius: 20,
//                           iconSize: 20,
//                           color: Colors.white,
//                           tooltip: 'Enlarge',
//                           icon: const Icon(Icons.fullscreen),
//                           onPressed: () {
//                             d('Enlarge tapped for $sampleAsset');
//                             _showFullScreenSample(ctx, sampleAsset, title);
//                           },
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 14),
//                 const Text('Use camera or pick from gallery', style: TextStyle(color: Colors.grey)),
//                 const SizedBox(height: 14),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     Column(
//                       children: [
//                         IconButton(
//                           onPressed: () => _pick(ImageSource.camera),
//                           icon: const Icon(Icons.photo_camera),
//                           iconSize: 32,
//                           tooltip: 'Take Photo',
//                         ),
//                         const Text('Camera', style: TextStyle(fontSize: 12)),
//                       ],
//                     ),
//                     Column(
//                       children: [
//                         IconButton(
//                           onPressed: () => _pick(ImageSource.gallery),
//                           icon: const Icon(Icons.photo_library),
//                           iconSize: 32,
//                           tooltip: 'Pick from Gallery',
//                         ),
//                         const Text('Gallery', style: TextStyle(fontSize: 12)),
//                       ],
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 d('UploadDialog: "$title" -> Close pressed');
//                 Navigator.of(ctx, rootNavigator: true).pop();
//               },
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // ===== Date picker helper =====
//   Future<void> _pickDate(TextEditingController controller, String label) async {
//     final now = DateTime.now();
//     final picked = await showDatePicker(
//       context: context,
//       firstDate: DateTime(now.year - 1),
//       lastDate: DateTime(now.year + 15),
//       initialDate: now,
//     );
//     if (picked != null) {
//       controller.text = picked.toIso8601String().split('T').first; // YYYY-MM-DD
//       d('$label picked: ${controller.text}');
//       setState(() {});
//     } else {
//       d('$label picker canceled');
//     }
//   }

//   Future<String> _uploadOne({
//     required File file,
//     required String negara,
//     required String negeri,
//     required String role,
//     required String loggedUser, // phone
//     required String category,   // 'ic', 'drivers_license', 'road_tax', 'psv', 'insurance', 'selfie', 'car_front', 'car_back'
//   }) async {
//     final ts = DateTime.now().millisecondsSinceEpoch;
//     final fileName = '${category}_$ts.jpg';

//     final ref = FirebaseStorage.instance
//         .ref()
//         .child(negara)
//         .child(negeri)
//         .child(role)       // 'driver' or 'passenger'
//         .child(loggedUser) // phone folder
//         .child(fileName);

//     d('UPLOAD PATH => ${ref.fullPath}');

//     await ref.putFile(
//       file,
//       SettableMetadata(
//         contentType: 'image/jpeg',
//         customMetadata: {
//           'role': role,
//           'loggedUser': loggedUser,
//           'category': category,
//           'negara': negara,
//           'negeri': negeri,
//           'uploaded_at': DateTime.now().toIso8601String(),
//         },
//       ),
//     );

//     final url = await ref.getDownloadURL();
//     d('Download URL => $url');
//     return url;
//   }

//   Future<void> _submit() async {
//     if (!(_formKey.currentState?.validate() ?? false)) return;

//     // Ensure all required images are provided (including the 3 new ones)
//     if (_pickedIcImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload an IC image.')));
//       return;
//     }
//     if (_pickedLicenseImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Driver License image.')));
//       return;
//     }
//     if (_pickedRoadTaxImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Road Tax image.')));
//       return;
//     }
//     if (_pickedPsvImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a PSV image.')));
//       return;
//     }
//     if (_pickedInsuranceImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload an Insurance image.')));
//       return;
//     }
//     if (_pickedSelfieImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Selfie image.')));
//       return;
//     }
//     if (_pickedCarFrontImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Car front image.')));
//       return;
//     }
//     if (_pickedCarBackImage == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a Car back image.')));
//       return;
//     }

//     setState(() => _submitting = true);

//     try {
//       // Vehicle top fields
//       final plate = _plateController.text.trim();
//       final brand = _brandController.text.trim();
//       final model = _modelController.text.trim();
//       final color = _colorController.text.trim();
//       final capacity = _capacity ?? 0;

//       // Other fields
//       final icNumber = _icController.text.trim();
//       final licenseExpiry = _licenseExpiryController.text.trim();
//       final roadTaxExpiry = _roadTaxExpiryController.text.trim();
//       final psvExpiry = _psvExpiryController.text.trim();
//       final insuranceExpiry = _insuranceExpiryController.text.trim();

//       final negara = (Gv.negara).isNotEmpty ? Gv.negara : 'UnknownCountry';
//       final negeri = (Gv.negeri).isNotEmpty ? Gv.negeri : 'UnknownState';
//       final role = widget.role.trim().isNotEmpty ? widget.role.trim() : 'driver';
//       final phone = (Gv.loggedUser).isNotEmpty ? Gv.loggedUser : 'unknown_phone';

//       d('SUBMIT start: negara=$negara negeri=$negeri role=$role phone=$phone plate=$plate cap=$capacity');

//       // Upload all images (existing)
//       final icUrl = await _uploadOne(
//         file: File(_pickedIcImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'ic',
//       );
//       final licenseUrl = await _uploadOne(
//         file: File(_pickedLicenseImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'drivers_license',
//       );
//       final roadTaxUrl = await _uploadOne(
//         file: File(_pickedRoadTaxImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'road_tax',
//       );
//       final psvUrl = await _uploadOne(
//         file: File(_pickedPsvImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'psv',
//       );
//       final insuranceUrl = await _uploadOne(
//         file: File(_pickedInsuranceImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'insurance',
//       );

//       // Upload new images
//       final selfieUrl = await _uploadOne(
//         file: File(_pickedSelfieImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'selfie',
//       );
//       final carFrontUrl = await _uploadOne(
//         file: File(_pickedCarFrontImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'car_front',
//       );
//       final carBackUrl = await _uploadOne(
//         file: File(_pickedCarBackImage!.path), negara: negara, negeri: negeri, role: role, loggedUser: phone, category: 'car_back',
//       );

//       // Save all fields to Firestore driver doc
//       await FirebaseFirestore.instance
//           .collection(negara)
//           .doc(negeri)
//           .collection('driver_account')
//           .doc(phone)
//           .set({
//         // Vehicle details
//         'reg_vehicle_plate': plate,
//         'reg_vehicle_brand': brand,
//         'reg_vehicle_model': model,
//         'reg_vehicle_color': color,
//         'reg_vehicle_capacity': capacity,

//         // IC + docs
//         'reg_ic_no': icNumber,
//         'reg_ic_image_url': icUrl,

//         'reg_drivers_license_expiry': licenseExpiry,
//         'reg_drivers_license_image_url': licenseUrl,

//         'reg_road_tax_expiry': roadTaxExpiry,
//         'reg_road_tax_image_url': roadTaxUrl,

//         'reg_psv_expiry': psvExpiry,
//         'reg_psv_image_url': psvUrl,

//         'reg_insurance_expiry': insuranceExpiry,
//         'reg_insurance_image_url': insuranceUrl,

//         // New images (no dates)
//         'reg_selfie_image_url': selfieUrl,
//         'reg_car_front_image_url': carFrontUrl,
//         'reg_car_back_image_url': carBackUrl,

//         'updated_at': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));

//       d('Firestore updated for $phone under $negara/$negeri');

//       if (!mounted) return;
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text('Submitted'),
//           content: const Text('All details uploaded successfully.'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('OK'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       d('SUBMIT error: $e');
//       if (!mounted) return;
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text('Error'),
//           content: Text(e.toString()),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('OK'),
//             ),
//           ],
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final negara = Gv.negara;
//     final negeri = Gv.negeri;
//     final role = widget.role;
//     final phone = Gv.loggedUser;

//     // Reusable builders
//     Widget previewRow(XFile picked, VoidCallback onClear) {
//       return Row(
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(6),
//             child: Image.file(
//               File(picked.path),
//               width: 80,
//               height: 50,
//               fit: BoxFit.cover,
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               File(picked.path).path.split(Platform.pathSeparator).last,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           IconButton(
//             onPressed: onClear,
//             icon: const Icon(Icons.close),
//             tooltip: 'Remove image',
//           ),
//         ],
//       );
//     }

//     ElevatedButton uploadBtn({
//       required String logTag,
//       required String dialogTitle,
//       required String sampleAsset,
//       required void Function(XFile?) onPicked,
//     }) {
//       return ElevatedButton.icon(
//         onPressed: () {
//           d('UPLOAD BUTTON ($logTag) tapped: negara=$negara negeri=$negeri role=$role phone=$phone '
//               'plate="${_plateController.text}" brand="${_brandController.text}" model="${_modelController.text}" '
//               'color="${_colorController.text}" cap="${_capacity?.toString() ?? ''}" '
//               'ic="${_icController.text}" lic="${_licenseExpiryController.text}" '
//               'road="${_roadTaxExpiryController.text}" psv="${_psvExpiryController.text}" '
//               'ins="${_insuranceExpiryController.text}"');
//           _openUploadDialog(
//             title: dialogTitle,
//             sampleAsset: sampleAsset,
//             onPicked: onPicked,
//           );
//         },
//         icon: const Icon(Icons.upload_file),
//         label: const Text('Upload'),
//       );
//     }

//     InputDecoration _dateDeco(String label) => InputDecoration(
//       labelText: label,
//       hintText: 'YYYY-MM-DD',
//       border: const OutlineInputBorder(),
//       suffixIcon: const Icon(Icons.calendar_today),
//     );

//     InputDecoration _textDeco(String label) => InputDecoration(
//       labelText: label,
//       border: const OutlineInputBorder(),
//     );

//     return Scaffold(
//       appBar: AppBar(title: const Text('Complete Registration')),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       children: [
//                         SizedBox(height:6),
//                         // ===== NEW: Vehicle fields (on top)
//                         TextFormField(
//                           controller: _plateController,
//                           textCapitalization: TextCapitalization.characters,
//                           decoration: _textDeco('Vehicle plate number'),
//                           validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _brandController,
//                           decoration: _textDeco('Vehicle brand'),
//                           validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _modelController,
//                           decoration: _textDeco('Vehicle model'),
//                           validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _colorController,
//                           decoration: _textDeco('Vehicle color'),
//                           validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                         ),
//                         const SizedBox(height: 12),
//                         DropdownButtonFormField<int>(
//                           value: _capacity,
//                           decoration: _textDeco('Vehicle capacity'),
//                           items: List.generate(6, (i) => i + 1)
//                               .map((n) => DropdownMenuItem<int>(
//                                     value: n,
//                                     child: Text(n.toString()),
//                                   ))
//                               .toList(),
//                           onChanged: (val) => setState(() => _capacity = val),
//                           validator: (val) => (val == null) ? 'Please choose 1–6' : null,
//                         ),

//                         const SizedBox(height: 20),

//                         // ===== Row 1: IC number + Upload
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _icController,
//                                 decoration: _textDeco('IC number'),
//                                 keyboardType: TextInputType.number,
//                                 validator: (val) {
//                                   final v = (val ?? '').trim();
//                                   if (v.isEmpty) return 'IC number is required';
//                                   if (!RegExp(r'^\d{12}$').hasMatch(v)) return 'IC must be 12 digits';
//                                   return null;
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 56,
//                               child: uploadBtn(
//                                 logTag: 'IC',
//                                 dialogTitle: 'Identity Card',
//                                 sampleAsset: 'assets/images/doc_ic.png',
//                                 onPicked: (img) => setState(() => _pickedIcImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedIcImage != null)
//                           previewRow(_pickedIcImage!, () {
//                             d('IC preview cleared');
//                             setState(() => _pickedIcImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 2: Driver license expiry date + Upload
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _licenseExpiryController,
//                                 readOnly: true,
//                                 onTap: () => _pickDate(_licenseExpiryController, 'Driver license expiry'),
//                                 decoration: _dateDeco('Enter driver license expiry date'),
//                                 validator: (val) {
//                                   final v = (val ?? '').trim();
//                                   if (v.isEmpty) return 'Driver license expiry date is required';
//                                   if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
//                                   return null;
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 56,
//                               child: uploadBtn(
//                                 logTag: 'LICENSE',
//                                 dialogTitle: 'Driver License',
//                                 sampleAsset: 'assets/images/doc_lesen_memandu.png',
//                                 onPicked: (img) => setState(() => _pickedLicenseImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedLicenseImage != null)
//                           previewRow(_pickedLicenseImage!, () {
//                             d('License preview cleared');
//                             setState(() => _pickedLicenseImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 3: Road tax expiry + Upload
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _roadTaxExpiryController,
//                                 readOnly: true,
//                                 onTap: () => _pickDate(_roadTaxExpiryController, 'Road tax expiry'),
//                                 decoration: _dateDeco('Enter road tax expiry date'),
//                                 validator: (val) {
//                                   final v = (val ?? '').trim();
//                                   if (v.isEmpty) return 'Road tax expiry date is required';
//                                   if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
//                                   return null;
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 56,
//                               child: uploadBtn(
//                                 logTag: 'ROAD_TAX',
//                                 dialogTitle: 'Road Tax',
//                                 sampleAsset: 'assets/images/doc_roadtax.png',
//                                 onPicked: (img) => setState(() => _pickedRoadTaxImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedRoadTaxImage != null)
//                           previewRow(_pickedRoadTaxImage!, () {
//                             d('Road tax preview cleared');
//                             setState(() => _pickedRoadTaxImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 4: PSV expiry + Upload
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _psvExpiryController,
//                                 readOnly: true,
//                                 onTap: () => _pickDate(_psvExpiryController, 'PSV expiry'),
//                                 decoration: _dateDeco('Enter PSV expiry date'),
//                                 validator: (val) {
//                                   final v = (val ?? '').trim();
//                                   if (v.isEmpty) return 'PSV expiry date is required';
//                                   if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
//                                   return null;
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 56,
//                               child: uploadBtn(
//                                 logTag: 'PSV',
//                                 dialogTitle: 'PSV',
//                                 sampleAsset: 'assets/images/doc_psv.png',
//                                 onPicked: (img) => setState(() => _pickedPsvImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedPsvImage != null)
//                           previewRow(_pickedPsvImage!, () {
//                             d('PSV preview cleared');
//                             setState(() => _pickedPsvImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 5: E-hailing insurance expiry + Upload
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _insuranceExpiryController,
//                                 readOnly: true,
//                                 onTap: () => _pickDate(_insuranceExpiryController, 'Insurance expiry'),
//                                 decoration: _dateDeco('Enter e-hailing insurance expiry date'),
//                                 validator: (val) {
//                                   final v = (val ?? '').trim();
//                                   if (v.isEmpty) return 'Insurance expiry date is required';
//                                   if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return 'Use format YYYY-MM-DD';
//                                   return null;
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 56,
//                               child: uploadBtn(
//                                 logTag: 'INSURANCE',
//                                 dialogTitle: 'Ehailing Insurance',
//                                 sampleAsset: 'assets/images/doc_insurance.png',
//                                 onPicked: (img) => setState(() => _pickedInsuranceImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedInsuranceImage != null)
//                           previewRow(_pickedInsuranceImage!, () {
//                             d('Insurance preview cleared');
//                             setState(() => _pickedInsuranceImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 6: Image selfie (Text label + Upload)
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             const Expanded(
//                               child: Text(
//                                 'Image selfie',
//                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 40,
//                               child: uploadBtn(
//                                 logTag: 'SELFIE',
//                                 dialogTitle: 'Selfie',
//                                 sampleAsset: 'assets/images/doc_selfie.png',
//                                 onPicked: (img) => setState(() => _pickedSelfieImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedSelfieImage != null)
//                           previewRow(_pickedSelfieImage!, () {
//                             d('Selfie preview cleared');
//                             setState(() => _pickedSelfieImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 7: Car infront (Text label + Upload)
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             const Expanded(
//                               child: Text(
//                                 'Car infront',
//                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 40,
//                               child: uploadBtn(
//                                 logTag: 'CAR_FRONT',
//                                 dialogTitle: 'Car Front',
//                                 sampleAsset: 'assets/images/doc_front.png',
//                                 onPicked: (img) => setState(() => _pickedCarFrontImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedCarFrontImage != null)
//                           previewRow(_pickedCarFrontImage!, () {
//                             d('Car front preview cleared');
//                             setState(() => _pickedCarFrontImage = null);
//                           }),

//                         const SizedBox(height: 20),

//                         // Row 8: Car back (Text label + Upload)
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             const Expanded(
//                               child: Text(
//                                 'Car back',
//                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             SizedBox(
//                               height: 40,
//                               child: uploadBtn(
//                                 logTag: 'CAR_BACK',
//                                 dialogTitle: 'Car Back',
//                                 sampleAsset: 'assets/images/doc_back.png',
//                                 onPicked: (img) => setState(() => _pickedCarBackImage = img),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         if (_pickedCarBackImage != null)
//                           previewRow(_pickedCarBackImage!, () {
//                             d('Car back preview cleared');
//                             setState(() => _pickedCarBackImage = null);
//                           }),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),

//               // Submit
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _submitting ? null : _submit,
//                   child: _submitting
//                       ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
//                       : const Text('Submit'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
