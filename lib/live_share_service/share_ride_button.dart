import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/driver_location_service.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/live_share_service/live_share_service.dart';

class ShareRideButton extends StatelessWidget {
  const ShareRideButton({super.key});

  Future<void> _shareRide(BuildContext context) async {
    final svc = LiveShareService();

    try {
      // Example: get coords from your job data or Gv.*
    // replace with destination longitude

      // 1) Create share doc
      final sid = await svc.createShareDoc(
        negara: Gv.negara,
        negeri: Gv.negeri,
        ownerPhone: Gv.loggedUser ?? '',
        jobId: "currentJobId", // replace with your job id if you have one
        srcLat: Gv.passengerGp.latitude,
        srcLng: Gv.passengerGp.longitude,
        dstLat: Gv.destinationGp.latitude,
        dstLng: Gv.destinationGp.longitude,
      );

      // 2) Build the web tracking URL (always use luckygo.web.app)
      final url = svc.buildWebTrackingUrl(
        webHost: 'https://luckygo.web.app',
        sid: sid,
        negara: Gv.negara,
        negeri: Gv.negeri,
      );

      // 3) Start mirroring driver GPS to live_shares/{sid}/positions
      await DriverLocationService.instance.enableLiveShare(
        negara: Gv.negara,
        negeri: Gv.negeri,
        sid: sid,
        distanceFilterForShare: 20,
      );

      // 4) Open the system share sheet
      await svc.shareLinkViaSystemSheet(
        url: url,
        subject: 'LuckyGo • Live Ride Tracking',
        extraText: 'Track my ride live here:',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.share_location),
        label: const Text('Share Ride'),
        onPressed: () => _shareRide(context),
      ),
    );
  }
}
