import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream.dart';
import 'package:luckygo_pemandu/landing page/disclosure_accepted_page.dart';
import 'package:luckygo_pemandu/landing%20page/pending_review_page.dart';
import 'package:luckygo_pemandu/landing%20page/presenter_page.dart';
import 'package:luckygo_pemandu/loginRegister/complete_registration_page.dart';
import 'package:luckygo_pemandu/loginRegister/login_page.dart';
import 'package:luckygo_pemandu/main.dart';
import 'package:luckygo_pemandu/translate_bahasa.dart';
import 'package:permission_handler/permission_handler.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _checking = true;
  bool checkingDriverGps = true;



  Future<void> checkDisclosureAcceptance() async {
    if (!mounted) return;
    setState(() => _checking = true); // show spinner

    try {
      if (Gv.negara.isEmpty || Gv.negeri.isEmpty || Gv.loggedUser.isEmpty) {
        debugPrint("⚠ Missing negara/negeri/loggedUser");
        return; // will fall to finally and hide spinner
      }

      final snap = await FirebaseFirestore.instance
          .collection(Gv.negara)
          .doc(Gv.negeri)
          .collection('driver_account')
          .doc(Gv.loggedUser)
          .get();

      final accepted = (snap.data()?['disclosureAccepted'] as bool?) ?? false;
      if (!accepted && mounted) {
        debugPrint("🚪 disclosureAccepted=false → navigating to DisclosureAcceptedPage");
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DisclosureAcceptedPage()),
        );
        return; // replaced by new page; no need to unset _checking here
      }

      debugPrint("✅ disclosureAccepted=true → staying on LandingPage");
    } catch (e) {
      debugPrint("❌ Error checking disclosureAccepted: $e");
    } finally {
      if (mounted) setState(() => _checking = false); // hide spinner
    }
  }

  bool _started = false;
  Future<void>? _driverPermissionInFlight;

  Future<void> requestDriverPermissionAndFetchJobs() {

    if (_driverPermissionInFlight != null) return _driverPermissionInFlight!;

    _driverPermissionInFlight = () async {
      try {
        // 1️⃣ Permission check
        var status = await Permission.location.status;
        if (status.isDenied || status.isRestricted) {
          final results = await [Permission.location].request();
          status = results[Permission.location] ?? status;
        }

        if (status.isPermanentlyDenied) {
          debugPrint("⚠ Location permission permanently denied. Opening settings…");
          await openAppSettings();
          return;
        }

        if (!status.isGranted) {
          debugPrint("❌ Location permission not granted.");
          return;
        }

        // 2️⃣ Location service check
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint("⚠ Location services are OFF.");
          return;
        }

        // 3️⃣ Get GPS position
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // 4️⃣ Save to global GeoPoint
        Gv.driverGp = GeoPoint(pos.latitude, pos.longitude);
        Gv.driverLat = pos.latitude;
        Gv.driverLng = pos.longitude;
        print("📍🔴 Driver LatLng: ${pos.latitude}, ${pos.longitude}");
        
        // 5️⃣ Fetch jobs now that location is ready
        // await fetchAllJobs();
      } catch (e) {
        debugPrint("❌ Error requesting GPS permission/location: $e");
      }
    }();

    return _driverPermissionInFlight!.whenComplete(() {
      _driverPermissionInFlight = null;
      setState(() {
        checkingDriverGps = false;
      });
    });
  }

  Future<void> seedTestJobs() async {
    final rnd = Random();
    final firestore = FirebaseFirestore.instance;

    const driverLat = 5.992976057618301;
    const driverLng = 116.13490015392537;

    final sabahCities = [
      {"name": "Kudat", "lat": 6.8833, "lng": 116.8333},
      {"name": "Sandakan", "lat": 5.8380, "lng": 118.1173},
      {"name": "Tawau", "lat": 4.2440, "lng": 117.8919},
      {"name": "Lahad Datu", "lat": 5.0209, "lng": 118.3280},
      {"name": "Semporna", "lat": 4.4818, "lng": 118.6116},
      {"name": "Tambunan", "lat": 5.7094, "lng": 116.3500},
      {"name": "Keningau", "lat": 5.3378, "lng": 116.1606},
    ];

    final names = [
      "Chuck Norris","Bruce Lee","Jackie Chan","Michelle Yeoh","Tony Jaa",
      "Jet Li","Donnie Yen","Iko Uwais","Jason Statham","Keanu Reeves"
    ];

    final now = DateTime.now();
    final Map<String, String> jobsMap = {};
    const totalJobs = 100;
    final nearQuota = (totalJobs * 0.70).round();

    bool hit(double p) => rnd.nextDouble() < p;
    int countIf(double p, int max) => hit(p) ? (rnd.nextInt(max) + 1) : 0;

    Map<String, double> _destPoint(double latDeg, double lngDeg, double distKm, double bearingRad) {
      const R = 6371.0088;
      final lat1 = latDeg * pi / 180.0;
      final lon1 = lngDeg * pi / 180.0;
      final angDist = distKm / R;

      final sinLat1 = sin(lat1), cosLat1 = cos(lat1);
      final sinAng = sin(angDist), cosAng = cos(angDist);
      final sinLat2 = sinLat1 * cosAng + cosLat1 * sinAng * cos(bearingRad);
      final lat2 = asin(sinLat2);
      final y = sin(bearingRad) * sinAng * cosLat1;
      final x = cosAng - sinLat1 * sinLat2;
      final lon2 = lon1 + atan2(y, x);

      return {
        "lat": lat2 * 180.0 / pi,
        "lng": (lon2 * 180.0 / pi + 540) % 360 - 180,
      };
    }

    for (int i = 0; i < totalJobs; i++) {
      final driverPhone = '01${rnd.nextInt(90000000) + 10000000}';
      final jobDate = now.subtract(Duration(minutes: rnd.nextInt(1440)));
      final dateStr = DateFormat('ddMMyy').format(jobDate);
      final timeStr = DateFormat('hhmmss').format(jobDate) + (jobDate.hour >= 12 ? 'PM' : 'AM');
      final liteJobId = "$dateStr $timeStr ($driverPhone)";

      final passengerPhone = '01${rnd.nextInt(90000000) + 10000000}';
      final name = names[rnd.nextInt(names.length)];

      final airKm = (rnd.nextDouble() * 20 + 1);
      final kmStr = airKm.toStringAsFixed(1);
      final priceStr = (airKm * (rnd.nextDouble() * 3 + 2)).toStringAsFixed(2);

      double srcLat, srcLng;
      String cityNameForAddr;

      if (i < nearQuota) {
        final distKm = rnd.nextDouble() * (50 - 1) + 1;
        final bearing = rnd.nextDouble() * 2 * pi;
        final p = _destPoint(driverLat, driverLng, distKm, bearing);
        srcLat = p["lat"]!;
        srcLng = p["lng"]!;
        cityNameForAddr = "Kota Kinabalu";
      } else {
        final city = sabahCities[rnd.nextInt(sabahCities.length)];
        final baseLat = city["lat"] as double;
        final baseLng = city["lng"] as double;
        srcLat = baseLat + (rnd.nextDouble() - 0.5) * 0.3;
        srcLng = baseLng + (rnd.nextDouble() - 0.5) * 0.3;
        cityNameForAddr = city['name'] as String;
      }

      final dstBearing = rnd.nextDouble() * 2 * pi;
      final dstDistKm = rnd.nextDouble() * 30;
      final dstPoint = _destPoint(srcLat, srcLng, dstDistKm, dstBearing);
      final dstLat = dstPoint["lat"]!;
      final dstLng = dstPoint["lng"]!;

      final markerCount = rnd.nextDouble() < 0.80 ? 2 : (rnd.nextInt(5) + 3);

      List<dynamic> specialFields;
      final none = rnd.nextDouble() < 0.85;
      if (none) {
        specialFields = [
          false, false, false,
          0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0,
          0,
        ];
      } else {
        bool hitP(double p) => rnd.nextDouble() < p;
        int cnt(double p, int max) => hitP(p) ? (rnd.nextInt(max) + 1) : 0;

        final blind = hitP(0.05);
        final deaf = hitP(0.03);
        final mute = hitP(0.02);

        final wheelchair   = cnt(0.04, 1);
        final supportStick = cnt(0.08, 1);
        final stroller     = cnt(0.06, 1);

        final shoppingBags = cnt(0.30, 2);
        final luggage      = cnt(0.25, 2);

        final hasPets = hitP(0.10);
        final dog     = hasPets && hitP(0.80) ? 1 : 0;
        final goat    = hitP(0.02) ? 1 : 0;
        final rooster = hitP(0.02) ? 1 : 0;
        final snake   = hitP(0.01) ? 1 : 0;

        final durian      = cnt(0.03, 1);
        final odourFruits = cnt(0.05, 1);
        final wetFood     = cnt(0.10, 2);
        final tupperware  = cnt(0.20, 2);
        final gasTank     = cnt(0.02, 1);

        specialFields = [
          blind, deaf, mute,
          wheelchair, supportStick, stroller,
          shoppingBags, luggage, hasPets ? 1 : 0,
          dog, goat, rooster, snake,
          durian, odourFruits, wetFood, tupperware,
          gasTank,
        ];
      }

      final fields = [
        liteJobId,
        passengerPhone,
        name,
        rnd.nextInt(4) + 1,
        kmStr,
        priceStr,
        markerCount,
        "Pickup Street $i",
        "$cityNameForAddr, Sabah",
        "Drop Street $i",
        "$cityNameForAddr, Sabah",
        srcLat.toStringAsFixed(6),
        srcLng.toStringAsFixed(6),
        dstLat.toStringAsFixed(6),
        dstLng.toStringAsFixed(6),
        ...specialFields,
      ];

      if (fields.length != 33) {
        continue;
      }

      final jobString = fields.join(' ·');
      jobsMap[liteJobId] = jobString;
    }

    await firestore
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('active_job')
        .doc('active_job_lite')
        .set(jobsMap);

    print("✅ Seeded ${jobsMap.length} jobs (≈70% within 1–50 km of driver)");
  }

@override
void initState() {
  super.initState();
  if (_started) return;
  _started = true;

  WidgetsBinding.instance.addPostFrameCallback((_) async {


    final loc = localeFromLanguageName(Gv.bahasa);
    final currentCode = Localizations.maybeLocaleOf(context)?.languageCode;
    if (loc != null && loc.languageCode != currentCode) {
      MyApp.setLocale(context, loc); // no-op if same (guard MyApp)
    }

    // This may navigate away – so check mounted after it returns
    await checkDisclosureAcceptance();
    if (!mounted) return;

    // Request GPS ONCE (gated). Do not also call another request function.
    await requestDriverPermissionAndFetchJobs();
    

  });
}

Future<void> _logout() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to log in again to continue.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  // Capture email BEFORE signOut
  final user = FirebaseAuth.instance.currentUser;
  final authEmail = user?.email ??
      (Gv.loggedUser.isNotEmpty ? '${Gv.loggedUser}@driver.com' : '');

  // Remove from login_sessions (if we have region + email)
  if (Gv.negara.isNotEmpty && Gv.negeri.isNotEmpty && authEmail.isNotEmpty) {
    try {
      final ref = FirebaseFirestore.instance
          .collection(Gv.negara)
          .doc(Gv.negeri)
          .collection('login_sessions')
          .doc(authEmail);
      await ref.delete();
    } catch (e) {
      debugPrint('login_sessions delete error: $e'); // non-fatal
    }
  }

  // Now sign out
  try {
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Sign out error: $e');
  }

  // Clear globals
  Gv.loggedUser = '';
  Gv.userName = '';

  if (!mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

  void _openEndDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    
    final t = AppLocalizations.of(context)!;
    final regionLabel = (Gv.negara.isNotEmpty && Gv.negeri.isNotEmpty)
        ? '${Gv.negara} • ${Gv.negeri}'
        : 'Region not set';

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Landing Page'),
        actions: [
          IconButton(
            tooltip: 'Menu',
            onPressed: _openEndDrawer,
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                margin: EdgeInsets.zero,
                currentAccountPicture: CircleAvatar(
                  child: Text(
                    (Gv.userName.isNotEmpty ? Gv.userName[0] : 'D').toUpperCase(),
                  ),
                ),
                accountName: Text(Gv.userName),
                accountEmail: Text(Gv.loggedUser.isNotEmpty
                    ? Gv.loggedUser
                    : 'Not signed in'),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Region'),
                subtitle: Text(regionLabel),
              ),

              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
body: Stack(
  children: [
    // ---- Background + main content ----
    Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF107572), Color(0xFFCDE989)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: ValueListenableBuilder<bool>(
              valueListenable: Gv.showPresenter,
              builder: (context, isVisible, _) {
                // if (Gv.form2Completed == false) {
                //   // Navigate to CompleteRegistrationPage (CRP)
                //   WidgetsBinding.instance.addPostFrameCallback((_) {
                //     if (Navigator.canPop(context)) {
                //       Navigator.pop(context);
                //     }
                //     Navigator.of(context).pushReplacement(
                //       MaterialPageRoute(builder: (_) => const CompleteRegistrationPage()),
                //     );
                //   });
                //   return const SizedBox.shrink();
                // }
                return isVisible ? const SizedBox.shrink() : const PresenterPage();
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.work_outline),
                  label: const Text('View Active Jobs'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      // MaterialPageRoute(builder: (_) => const BucketsLauncherPage()),
                      MaterialPageRoute(builder: (_) => const FilterJobsOneStream()),
                    );
                  },
                ),
              ],
            ),
          ),
        
        ],
      ),
    ),

    // ---- GPS overlay ----
    if (checkingDriverGps)
      Positioned.fill(
        child: AbsorbPointer(
          absorbing: true,
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Fetching driver GPS to match jobs distance",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

    // ---- Firestore listener (non-blocking UI layer) ----
    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Gv.negara)
          .doc(Gv.negeri)
          .collection('active_job')
          .doc('active_job_lite')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Keep UI visible; just show small indicator in corner if you want
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // No data: nothing to overlay
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data()!;
        // TODO: do whatever you need with `data` (e.g., cache, counts, etc.)
        // debugPrint('active_job_lite keys: ${data.keys.length}');

        // Not drawing anything; just listening.
        return const SizedBox.shrink();
      },
    ),
  


StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection(Gv.negara)
      .doc(Gv.negeri)
      .collection('driver_account')
      .doc(Gv.loggedUser)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const SizedBox.shrink();
    }

    final data = snapshot.data!.data()!;
    Gv.form2Completed = (data['form2_completed'] as bool?) ?? false;
    Gv.registrationApproved = (data['registration_approved'] as bool?) ?? false;

if (!Gv.form2Completed && !Gv.registrationApproved) {
  // Go to CompleteRegistrationPage
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CompleteRegistrationPage()),
    );
  });
  return const SizedBox.shrink();
}

if (Gv.form2Completed && !Gv.registrationApproved) {
  // Go to PendingReview (your class name is PandingReview)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PandingReview()),
    );
  });
  return const SizedBox.shrink();
}

    return const SizedBox.shrink();
  },
)






























  
  ],
),

    );
  }
}
