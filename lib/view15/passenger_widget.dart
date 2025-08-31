// ignore_for_file: prefer_const_constructors, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';

class PassengerWidget extends StatefulWidget {
  
  final String description;

  final String ind_adult;
  final int qty_adult;

  final String ind_baby;
  final int qty_baby;

  final int ttl_psg;
  final double price;

 

  const PassengerWidget({
    Key? key,

    required this.description, 
    
    required this.ind_adult,
    required this.qty_adult,

    required this.ind_baby,
    required this.qty_baby,

    required this.ttl_psg,
    required this.price,
    
  }) : super(key: key);

  @override
  State<PassengerWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<PassengerWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom:4),
      child: Row(
        children: [
          // Left: labels + icons + quantities
          Expanded(
            flex: 66,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    widget.description,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  // First indicator with stacked quantity
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/images/${widget.ind_adult}.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 6,
                        right: -6,
                        child: Text('${widget.qty_adult}'),
                      ),
                    ],
                  ),
                  SizedBox(width:14),
      
      
                  // Second indicator + quantity
                  Image.asset(
                    'assets/images/${widget.ind_baby}.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(width: 2),
                  Text('${widget.qty_baby}'),
                ],
              ),
            ),
          ),
      
      
      
          // Right: combined price/total3
          Expanded(
            flex:10,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                '× ${widget.ttl_psg}',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ),      
      
          // Right: combined price/total3
          Expanded(
            flex: 24,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.price.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
      
      
        ],
      ),
    );
  }
}
