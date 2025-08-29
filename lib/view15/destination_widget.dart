// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';

class DesWidget extends StatefulWidget {
  final String description01;
  final String desEta;
  final String desKm;
  final String desCharges;

  const DesWidget({
    Key? key,
    required this.description01,
    required this.desKm,
    required this.desEta,
    required this.desCharges,
  }) : super(key: key);

  @override
  State<DesWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<DesWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        color: Colors.amberAccent,
        child: Column(
          children: [
            SizedBox(height: 6),
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.description01}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 0.7,
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    flex: 34,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${widget.desKm} km',
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 33,
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        '${widget.desEta} min',
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 33,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        widget.desCharges,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

