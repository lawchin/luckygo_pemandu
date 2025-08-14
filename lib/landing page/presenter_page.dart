import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/global.dart';

class PresenterPage extends StatefulWidget {
  const PresenterPage({Key? key}) : super(key: key);

  @override
  State<PresenterPage> createState() => _PresenterPageState();
}

class _PresenterPageState extends State<PresenterPage> {
  bool _isVisible = false;
  bool _isVisibleWelcome = false;

  

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
      Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) {
        setState(() {
          _isVisibleWelcome = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double imageHeight = constraints.maxHeight * 0.5;

        return Stack(
          children: [
            AnimatedSlide(
              offset: _isVisible ? Offset.zero : const Offset(-1.0, 0.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: imageHeight,
                  child: Image.asset(
                    'assets/images/presenter.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: _isVisibleWelcome ? 1.0 : 0.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc?.welcome ?? '',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        Gv.userName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
