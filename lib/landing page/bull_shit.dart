// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/active_jobs_b2_page.dart';
import 'package:luckygo_pemandu/landing%20page/active_job_stream_page.dart';
  Future<void> FetchGroupCapability() async {
    await FirebaseFirestore.instance
      .collection(Gv.negara)
      .doc(Gv.negeri)
      .collection('driver_account')
      .doc(Gv.loggedUser)
      .get()
      .then((doc) {
        if (doc.exists) {
          Gv.groupCapability = (doc.data()?['group_capability'] as int?) ?? 0;
        }
      });
  }

class BullShit extends StatefulWidget {
  const BullShit({super.key});

  @override
  State<BullShit> createState() => _BullShitState();
}

class _BullShitState extends State<BullShit> {

  Future<void> FetchGroupCapability() async {
    await FirebaseFirestore.instance
      .collection(Gv.negara)
      .doc(Gv.negeri)
      .collection('driver_account')
      .doc(Gv.loggedUser)
      .get()
      .then((doc) {
        if (doc.exists) {
          Gv.groupCapability = (doc.data()?['group_capability'] as int?) ?? 0;
        }
      });
  }

  @override
  void initState() {
    super.initState();
    FetchGroupCapability();
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('BullShit')),

      body: 

    Center(
      child: Container(
        width: MediaQuery.of(context).size.width - 16,
        child: Column(
          children: [
Gv.groupCapability >= 1
    ? GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ActiveJobsStreamPage()),
          );  
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Next to you (≤1.5 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 2
    ? GestureDetector(
        onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ActiveJobsB2Page()),
        );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Very near (1.5 – 3.5 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 3
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Near (3.5 – 7 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 4
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quite near (7 – 10 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 5
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'A little far (10 – 15 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 6
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Far (15 – 20 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 7
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quite far (20 – 30 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 8
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Very far (30 – 40 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 9
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Super far (40 – 50 km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

Gv.groupCapability >= 10
    ? GestureDetector(
        onTap: () {
          print('BullShit');
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Extreme far (50+ km)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      )
    : const SizedBox.shrink(),

          ],
        ),
      ),
    )
    );
  }

}
