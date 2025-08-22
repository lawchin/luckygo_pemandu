// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

class DesWidget extends StatefulWidget {
  final String img1;
  final String img2;
  final double desKm;
  final double desCharges;
  final bool visible;

  const DesWidget({
    Key? key,
    required this.img1,
    required this.img2,
    required this.desKm,
    required this.desCharges,
    required this.visible,
  }) : super(key: key);

  @override
  State<DesWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<DesWidget> {
  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.visible,
      child: Container(
        child: Column(
          children: [
            SizedBox(height:6),
            
            SizedBox(
              height: 30,
              child: Row(
                children: [
      
                  Expanded(
                    flex: 44,
                    child: Row(
                      children: [
                        SizedBox(width:7),
                        Image.asset(
                          'assets/images/${widget.img1}.png',
                          width: 20,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                          Padding(
                            padding: const EdgeInsets.only(left:4.0, right:4.0),
                            child: Text(
                                '⟶',
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.red,
                                    height:0.8
                                  ),
                                ),
                          ),                            
                        Image.asset(
                          'assets/images/${widget.img2}.png',
                          width: 20,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left:6, right:6),
                          child: Text(
                          '${widget.desKm.toString()} km',
                          style: TextStyle(
                          ),
                          ),
                        ),
                      ],
                    ),
                  ), 
                  Expanded(
                    flex: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                        '${widget.desCharges.toString()}',
                        style: TextStyle(
                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6,)
          
      
          ],
        ),
      ),
    );
  }
}
