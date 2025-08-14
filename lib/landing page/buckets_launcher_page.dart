import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/active_jobs_buckets_page.dart';
// ⬇️ import where you put loadAndBucketJobs / NearbyBuckets
import 'package:luckygo_pemandu/jobFilter/job_bucketing.dart';

class BucketsLauncherPage extends StatefulWidget {
  const BucketsLauncherPage({super.key});

  @override
  State<BucketsLauncherPage> createState() => _BucketsLauncherPageState();
}

class _BucketsLauncherPageState extends State<BucketsLauncherPage> {
  late Future<_BucketCounts> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCounts();
  }

  Future<_BucketCounts> _loadCounts() async {
    final buckets = await loadAndBucketJobs(
      negara: Gv.negara,
      negeri: Gv.negeri,
    );
    // map each bucket index 1..14 to its count
    final counts = <int, int>{
      1: buckets.bucket01.length,
      2: buckets.bucket02.length,
      3: buckets.bucket03.length,
      4: buckets.bucket04.length,
      5: buckets.bucket05.length,
      6: buckets.bucket06.length,
      7: buckets.bucket07.length,
      8: buckets.bucket08.length,
      9: buckets.bucket09.length,
      10: buckets.bucket10.length,
      11: buckets.bucket11.length,
      12: buckets.bucket12.length,
      13: buckets.bucket13.length,
      14: buckets.bucket14.length,
    };
    return _BucketCounts(counts);
  }

  void _refresh() {
    setState(() {
      _future = _loadCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cap = Gv.groupCapability.clamp(0, 14);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Buckets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: cap <= 0
          ? const _EmptyAccess()
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<_BucketCounts>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40),
                            const SizedBox(height: 8),
                            const Text('Failed to load buckets.'),
                            const SizedBox(height: 6),
                            Text('${snap.error}', textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final counts = snap.data!;
                  final visible = <int>[];
                  for (var i = 1; i <= cap; i++) {
                    final c = counts[i];
                    if (c != null && c > 0) visible.add(i);
                  }

                  if (visible.isEmpty) {
                    return const _NoJobsEnabled();
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final bucketIndex = visible[idx];
                      final meta = _bucketMeta(bucketIndex);
                      final count = counts[bucketIndex] ?? 0;

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActiveJobsBucketsPage(bucketIndex: bucketIndex),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // icon
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(meta.icon, size: 20, color: Colors.black87),
                              ),
                              const SizedBox(width: 12),

                              // two-line label
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meta.name, // 14sp
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      meta.range, // 10sp
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // trailing count chip (real number)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyAccess extends StatelessWidget {
  const _EmptyAccess();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No buckets enabled for this driver.'),
      ),
    );
  }
}

class _NoJobsEnabled extends StatelessWidget {
  const _NoJobsEnabled();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No nearby jobs in your enabled buckets.'),
      ),
    );
  }
}

/// simple wrapper to access counts like counts[1], counts[2], ...
class _BucketCounts {
  final Map<int, int> _counts;
  _BucketCounts(this._counts);
  int? operator [](int index) => _counts[index];
}

/// metadata for label + range + icon
class _BucketMeta {
  final String name;   // e.g., "Next to you"
  final String range;  // e.g., "(≤ 1.5 km)"
  final IconData icon;
  const _BucketMeta(this.name, this.range, this.icon);
}

_BucketMeta _bucketMeta(int index) {
  const names = <int, String>{
    1:  'Next to you',
    2:  'Very near',
    3:  'Near',
    4:  'Quite near',
    5:  'A little far',
    6:  'Far',
    7:  'Quite far',
    8:  'Very far',
    9:  'Super far',
    10: 'Extreme far',
    11: 'Long haul',
    12: 'Long haul+',
    13: 'Ultra long',
    14: 'Epic',
  };

  const ranges = <int, String>{
    1:  '(≤ 1.5 km)',
    2:  '(1.51 – 2.5 km)',
    3:  '(2.51 – 5 km)',
    4:  '(5.1 – 7.5 km)',
    5:  '(7.51 – 10 km)',
    6:  '(10.1 – 20 km)',
    7:  '(20.1 – 30 km)',
    8:  '(30.1 – 50 km)',
    9:  '(50.1 – 100 km)',
    10: '(100.1 – 200 km)',
    11: '(200.1 – 500 km)',
    12: '(500.1 – 1000 km)',
    13: '(1000.1 – 2000 km)',
    14: '(2000.1 – 5000 km)',
  };

  final icons = <IconData>[
    Icons.place_outlined,
    Icons.directions_walk,
    Icons.directions_bike,
    Icons.directions_car,
    Icons.local_taxi,
    Icons.route,
    Icons.alt_route,
    Icons.signpost_outlined,
    Icons.fork_right,
    Icons.rocket_launch_outlined,
    Icons.public,
    Icons.flight_takeoff,
    Icons.flight,
    Icons.public_off,
  ];
  final icon = icons[(index - 1) % icons.length];

  return _BucketMeta(
    names[index] ?? 'Bucket $index',
    ranges[index] ?? '',
    icon,
  );
}
