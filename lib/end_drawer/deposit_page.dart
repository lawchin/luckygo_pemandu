import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
import 'processing_deposit.dart'; // keep next to this file or adjust path

class DepositPage extends StatefulWidget {
  const DepositPage({Key? key}) : super(key: key);

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _proofImage;

  final TextEditingController depositAmountController = TextEditingController();
  final TextEditingController last4DigitsController = TextEditingController();

  bool _submitting = false;
  bool _progressVisible = false;

  @override
  void dispose() {
    depositAmountController.dispose();
    last4DigitsController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchBankData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection(Gv.negara!)
        .doc(Gv.negeri)
        .collection('information')
        .doc('banking')
        .collection('banking_data')
        .get();

    return snapshot.docs
        .where((doc) => doc.data()['is_active'] == true)
        .map((doc) => doc.data())
        .toList();
  }

  Future<void> _pickFromCamera() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (img != null) setState(() => _proofImage = img);
    } catch (e) {
      _showSnack('Failed to open camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (img != null) setState(() => _proofImage = img);
    } catch (e) {
      _showSnack('Failed to open gallery: $e');
    }
  }

  void _clearImage() => setState(() => _proofImage = null);

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showProcessingDialog(String message) async {
    _progressVisible = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Processing deposit…')),
            ],
          ),
        ),
      ),
    );
    _progressVisible = false;
  }

  void _closeProcessingDialogIfOpen() {
    if (_progressVisible && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _progressVisible = false;
    }
  }

  String _safeStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// ===== Logo helpers =====

  /// Big, full-width logo box (no crop; keeps aspect ratio).
  Widget _logoBox(Widget child, double maxHeight) {
    return Container(
      width: double.infinity,
      height: maxHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: FittedBox(
        fit: BoxFit.contain, // show entire logo
        child: child,
      ),
    );
  }

  /// Fallback avatar with bank initials if no logo.
  Widget _fallbackLogo(String? bankName, {double size = 72}) {
    final initials = (bankName ?? '??')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: double.infinity,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: CircleAvatar(
        radius: size / 2.6,
        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Build logo from url/asset/storage path (assets are under assets/images/).
  Widget _buildBankLogoTop(Map<String, dynamic> bank, {double maxHeight = 72}) {
    final String? url = bank['bank_logo_url'];
    final String? assetName = bank['bank_logo']; // e.g. "cimb_bank.png"
    final String? storagePath = bank['bank_logo_storage_path'];

    if (url != null && url.isNotEmpty) {
      return _logoBox(Image.network(url), maxHeight);
    }

    if (assetName != null && assetName.isNotEmpty) {
      // **Your requested path:** assets/images/<file>
      return _logoBox(Image.asset('assets/images/$assetName'), maxHeight);
    }

    if (storagePath != null && storagePath.isNotEmpty) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.ref(storagePath).getDownloadURL(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.done && snap.hasData) {
            return _logoBox(Image.network(snap.data!), maxHeight);
          }
          if (snap.hasError) {
            return _fallbackLogo(bank['name'], size: maxHeight);
          }
          return Container(
            width: double.infinity,
            height: maxHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return _fallbackLogo(bank['name'], size: maxHeight);
  }

  /// ===== Submit deposit flow =====
  Future<void> processDeposit() async {
    if (_submitting) return;

    final amount = depositAmountController.text.trim();
    final last4 = last4DigitsController.text.trim();

    if (amount.isEmpty) {
      _showSnack('Please enter deposit amount.');
      return;
    }
    if (last4.length != 4 || int.tryParse(last4) == null) {
      _showSnack('Please enter the last 4 digits of your phone number.');
      return;
    }
    if (_proofImage == null) {
      _showSnack('Please attach your receipt image.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    // ignore: unawaited_futures
    Future.microtask(() => _showProcessingDialog('Processing deposit…'));

    final stamp = _safeStamp();
    final docId = '$stamp(${Gv.loggedUser})';
    final storageObjectPath =
        '${Gv.negara}/${Gv.negeri}/driver/${Gv.loggedUser}/$docId.jpg';

    try {
      // Upload image
      final file = File(_proofImage!.path);
      final storageRef = FirebaseStorage.instance.ref().child(storageObjectPath);
      await storageRef.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

      // Firestore batch
      final payload = {
        'deposit_amount': amount,
        'deposit_date': FieldValue.serverTimestamp(),
        'driver_or_passenger': 'driver',
        'last_4d_phone': last4,
        'receipt_image_url': downloadUrl,
        'receipt_storage_path': storageObjectPath,
        'uid': Gv.loggedUser,
        'negara': Gv.negara,
        'negeri': Gv.negeri,
      };

      final adminRef = FirebaseFirestore.instance
          .collection(Gv.negara!)
          .doc(Gv.negeri)
          .collection('information')
          .doc('banking')
          .collection('deposit_data')
          .doc(docId);

      final historyRef = FirebaseFirestore.instance
          .collection(Gv.negara!)
          .doc(Gv.negeri)
          .collection('driver_account')
          .doc('${Gv.loggedUser}')
          .collection('deposit_history')
          .doc('($stamp)${Gv.loggedUser}');

      final batch = FirebaseFirestore.instance.batch();
      batch.set(adminRef, payload);
      batch.set(historyRef, {...payload, 'deposit_status': 'pending'});
      await batch.commit();

      final String? localPath = _proofImage?.path;

      // close dialog, then navigate
      if (!mounted) return;
      _closeProcessingDialogIfOpen();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProcessingDeposit(
            imageUrl: downloadUrl,
            amount: amount,
            last4: last4,
            localImagePath: localPath,
          ),
        ),
      );

      // reset locals
      depositAmountController.clear();
      last4DigitsController.clear();
      _proofImage = null;
    } catch (e) {
      if (mounted) {
        _closeProcessingDialogIfOpen();
        _showSnack('Failed to submit: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Deposit Page')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchBankData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final banks = snapshot.data ?? [];
          if (banks.isEmpty) {
            return const Center(child: Text('No active banks found.'));
          }

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    'Available Banks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Bank list (Logo top, name mid, account bottom)
              SliverList.builder(
                itemCount: banks.length,
                itemBuilder: (context, index) {
                  final Map<String, dynamic> bank = banks[index];
                  final bankName = bank['name'] ?? 'Unknown Bank';
                  final accountNo = bank['account_no'] ?? '-';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top: Full-width logo
                            _buildBankLogoTop(bank, maxHeight: 72),
                            const SizedBox(height: 10),

                            // Mid: Bank name
                            Text(
                              bankName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Bottom: Account number
                            Text(
                              'Account Number: $accountNo',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Deposit Instructions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Choose a bank from the list above.'),
                      Text('2. Deposit with cash deposit machine (CDM) or online transfer.'),
                      Text('3. Enter deposit amount and last 4 digits of phone number.'),
                      Text('4. Upload the receipt and press Submit.'),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Deposit Amount
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: depositAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Deposit Amount',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // Last 4 digits
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: last4DigitsController,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 Digits of Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      counterText: '',
                    ),
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Photo buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Picture'),
                          onPressed: _pickFromCamera,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          onPressed: _pickFromGallery,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Preview + Clear
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      if (_proofImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_proofImage!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _clearImage,
                            icon: const Icon(Icons.clear),
                            label: const Text('Remove'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Submit
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () async => processDeposit(),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 84)),
            ],
          );
        },
      ),
    );
  }
}


// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:luckygo_pemandu/global.dart';
// import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
// import 'processing_deposit.dart'; // keep next to this file or adjust path

// class DepositPage extends StatefulWidget {
//   const DepositPage({Key? key}) : super(key: key);

//   @override
//   State<DepositPage> createState() => _DepositPageState();
// }

// class _DepositPageState extends State<DepositPage> {
//   final ImagePicker _picker = ImagePicker();
//   XFile? _proofImage;

//   final TextEditingController depositAmountController = TextEditingController();
//   final TextEditingController last4DigitsController = TextEditingController();

//   bool _submitting = false;
//   bool _progressVisible = false;

//   @override
//   void dispose() {
//     depositAmountController.dispose();
//     last4DigitsController.dispose();
//     super.dispose();
//   }

//   Future<List<Map<String, dynamic>>> fetchBankData() async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection(Gv.negara!)
//         .doc(Gv.negeri)
//         .collection('information')
//         .doc('banking')
//         .collection('banking_data')
//         .get();

//     return snapshot.docs
//         .where((doc) => doc.data()['is_active'] == true)
//         .map((doc) => doc.data())
//         .toList();
//   }

//   Future<void> _pickFromCamera() async {
//     try {
//       final img = await _picker.pickImage(
//         source: ImageSource.camera,
//         preferredCameraDevice: CameraDevice.rear,
//         imageQuality: 80,
//         maxWidth: 2000,
//         maxHeight: 2000,
//       );
//       if (img != null) setState(() => _proofImage = img);
//     } catch (e) {
//       _showSnack('Failed to open camera: $e');
//     }
//   }

//   Future<void> _pickFromGallery() async {
//     try {
//       final img = await _picker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 80,
//         maxWidth: 2000,
//         maxHeight: 2000,
//       );
//       if (img != null) setState(() => _proofImage = img);
//     } catch (e) {
//       _showSnack('Failed to open gallery: $e');
//     }
//   }

//   void _clearImage() => setState(() => _proofImage = null);

//   void _showSnack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   Future<void> _showProcessingDialog(String message) async {
//     _progressVisible = true;
//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => WillPopScope(
//         onWillPop: () async => false,
//         child: AlertDialog(
//           content: Row(
//             children: const [
//               SizedBox(
//                 width: 24,
//                 height: 24,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               ),
//               SizedBox(width: 16),
//               Expanded(child: Text('Processing deposit…')),
//             ],
//           ),
//         ),
//       ),
//     );
//     _progressVisible = false;
//   }

//   void _closeProcessingDialogIfOpen() {
//     if (_progressVisible && mounted) {
//       Navigator.of(context, rootNavigator: true).pop();
//       _progressVisible = false;
//     }
//   }

//   // filename-safe timestamp for IDs
//   String _safeStamp() {
//     final now = DateTime.now();
//     String two(int v) => v.toString().padLeft(2, '0');
//     return '${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
//   }

//   /// Submit deposit (DRIVER):
//   /// 1) Show blocking progress dialog
//   /// 2) Upload image to Storage: <negara>/<negeri>/driver/<Gv.loggedUser>/<docId>.jpg
//   /// 3) Firestore batch:
//   ///    - information/banking/deposit_data/{docId}
//   ///    - driver_account/{uid}/deposit_history/(<stamp>)uid  (with deposit_status: pending)
//   /// 4) Close dialog, navigate to ProcessingDeposit() with details
//   Future<void> processDeposit() async {
//     if (_submitting) return;

//     final amount = depositAmountController.text.trim();
//     final last4 = last4DigitsController.text.trim();

//     if (amount.isEmpty) {
//       _showSnack('Please enter deposit amount.');
//       return;
//     }
//     if (last4.length != 4 || int.tryParse(last4) == null) {
//       _showSnack('Please enter the last 4 digits of your phone number.');
//       return;
//     }
//     if (_proofImage == null) {
//       _showSnack('Please attach your receipt image.');
//       return;
//     }

//     FocusScope.of(context).unfocus();
//     setState(() => _submitting = true);
//     // Show progress (non-blocking await via Future.microtask so we can proceed)
//     // ignore: unawaited_futures
//     Future.microtask(() => _showProcessingDialog('Processing deposit…'));

//     final stamp = _safeStamp();
//     final docId = '$stamp(${Gv.loggedUser})';
//     final storageObjectPath =
//         '${Gv.negara}/${Gv.negeri}/driver/${Gv.loggedUser}/$docId.jpg';

//     try {
//       // 2) Upload to Firebase Storage
//       final file = File(_proofImage!.path);
//       final storageRef = FirebaseStorage.instance.ref().child(storageObjectPath);
//       await storageRef.putFile(
//         file,
//         SettableMetadata(contentType: 'image/jpeg'),
//       );
//       final downloadUrl = await storageRef.getDownloadURL();

//       // 3) Firestore batch (atomic)
//       final payload = {
//         'deposit_amount': amount,
//         'deposit_date': FieldValue.serverTimestamp(),
//         'driver_or_passenger': 'driver',
//         'last_4d_phone': last4,
//         'receipt_image_url': downloadUrl,
//         'receipt_storage_path': storageObjectPath,
//         'uid': Gv.loggedUser,
//         'negara': Gv.negara,
//         'negeri': Gv.negeri,
//       };

//       final adminRef = FirebaseFirestore.instance
//           .collection(Gv.negara!)
//           .doc(Gv.negeri)
//           .collection('information')
//           .doc('banking')
//           .collection('deposit_data')
//           .doc(docId);

//       final historyRef = FirebaseFirestore.instance
//           .collection(Gv.negara!)
//           .doc(Gv.negeri)
//           .collection('driver_account')
//           .doc('${Gv.loggedUser}')
//           .collection('deposit_history')
//           .doc('($stamp)${Gv.loggedUser}');

//       final batch = FirebaseFirestore.instance.batch();
//       batch.set(adminRef, payload);
//       batch.set(historyRef, {...payload, 'deposit_status': 'pending'});
//       await batch.commit();

//       // capture local path BEFORE clearing state
//       final String? localPath = _proofImage?.path;

//       // 4) close progress dialog, then navigate
//       if (!mounted) return;
//       _closeProcessingDialogIfOpen();

//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(
//           builder: (_) => ProcessingDeposit(
//             imageUrl: downloadUrl,
//             amount: amount,
//             last4: last4,
//             localImagePath: localPath, // nullable & safe
//           ),
//         ),
//       );

//       // optional: reset locals after navigating
//       depositAmountController.clear();
//       last4DigitsController.clear();
//       _proofImage = null;
//     } catch (e) {
//       if (mounted) {
//         _closeProcessingDialogIfOpen();
//         _showSnack('Failed to submit: $e');
//       }
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Driver Deposit Page')),
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: fetchBankData(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }

//           final banks = snapshot.data ?? [];
//           if (banks.isEmpty) {
//             return const Center(child: Text('No active banks found.'));
//           }

//           return CustomScrollView(
//             slivers: [
//               const SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
//                   child: Text(
//                     'Available Banks',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),

//               // Bank list
//               SliverList.builder(
//                 itemCount: banks.length,
//                 itemBuilder: (context, index) {
//                   final bank = banks[index];
//                   return Padding(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                     child: Card(
//                       child: ListTile(
//                         title: Text(bank['name'] ?? 'Unknown Bank'),
//                         subtitle: Text(
//                             'Account Number: ${bank['account_no'] ?? '-'}'),
//                       ),
//                     ),
//                   );
//                 },
//               ),

//               const SliverToBoxAdapter(child: SizedBox(height: 12)),
//               const SliverToBoxAdapter(child: Divider(height: 1)),
//               const SliverToBoxAdapter(child: SizedBox(height: 12)),

//               const SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Text(
//                     'Deposit Instructions',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 10)),
//               const SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('1. Choose a bank from the list above.'),
//                       Text(
//                           '2. Deposit with cash deposit machine (CDM) or online transfer.'),
//                       Text(
//                           '3. Enter deposit amount and last 4 digits of phone number.'),
//                       Text('4. Upload the receipt and press Submit.'),
//                     ],
//                   ),
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 20)),

//               // Deposit Amount
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: TextField(
//                     controller: depositAmountController,
//                     decoration: const InputDecoration(
//                       labelText: 'Deposit Amount',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.attach_money),
//                     ),
//                     keyboardType:
//                         const TextInputType.numberWithOptions(decimal: true),
//                     inputFormatters: [
//                       FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
//                     ],
//                   ),
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 10)),

//               // Last 4 digits
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: TextField(
//                     controller: last4DigitsController,
//                     decoration: const InputDecoration(
//                       labelText: 'Last 4 Digits of Phone Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                       counterText: '',
//                     ),
//                     maxLength: 4,
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   ),
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 12)),

//               // Photo buttons
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           icon: const Icon(Icons.camera_alt),
//                           label: const Text('Take Picture'),
//                           onPressed: _pickFromCamera,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           icon: const Icon(Icons.photo_library),
//                           label: const Text('Gallery'),
//                           onPressed: _pickFromGallery,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               // Preview + Clear
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//                   child: Column(
//                     children: [
//                       if (_proofImage != null) ...[
//                         ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: Image.file(
//                             File(_proofImage!.path),
//                             fit: BoxFit.cover,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: TextButton.icon(
//                             onPressed: _clearImage,
//                             icon: const Icon(Icons.clear),
//                             label: const Text('Remove'),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),

//               const SliverToBoxAdapter(child: SizedBox(height: 20)),

//               // Submit
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Center(
//                     child: ElevatedButton(
//                       onPressed:
//                           _submitting ? null : () async => processDeposit(),
//                       child: _submitting
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           : const Text('Submit'),
//                     ),
//                   ),
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 84)),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }

