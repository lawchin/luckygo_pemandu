import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For GeoPoint

// Global variables for user session and profile
class Gv {
  static String loggedUser = '';
  static String userName = '';
  static String negara = '';
  static String negeri = '';
  static String kawasan = '';
  static String bahasa = '';

  // New variable to store current location
  static GeoPoint? driverGp;
  static double driverLat = 0.0;
  static double driverLng = 0.0;

  // Lite job core details
  static String liteJobId        = '';   // 0
  static String passengerPhone   = '';   // 1
  static String passengerName    = '';   // 2
  static int    passengerCount   = 0;    // 3
  static double totalKm          = 0.0;  // 4
  static double totalPrice       = 0.0;  // 5
  static int    markerCount      = 0;    // 6

  // Addresses
  static String sAdd1            = '';   // 7
  static String sAdd2            = '';   // 8
  static String dAdd1            = '';   // 9
  static String dAdd2            = '';   // 10

  // Coordinates
  static double sLat             = 0.0;  // 11
  static double sLng             = 0.0;  // 12
  static double dLat             = 0.0;  // 13
  static double dLng             = 0.0;  // 14

  // Passenger disabilities
  static bool   isBlind          = false; // 15
  static bool   isDeaf           = false; // 16
  static bool   isMute           = false; // 17

  // Item counts
  static int wheelchairCount     = 0;    // 18
  static int supportStickCount   = 0;    // 19
  static int babyStrollerCount   = 0;    // 20
  static int shoppingBagCount    = 0;    // 21
  static int luggageCount        = 0;    // 22
  static int petsCount           = 0;    // 23
  static int dogCount            = 0;    // 24
  static int goatCount           = 0;    // 25
  static int roosterCount        = 0;    // 26
  static int snakeCount          = 0;    // 27
  static int durianCount         = 0;    // 28
  static int odourFruitsCount    = 0;    // 29
  static int wetFoodCount        = 0;    // 30
  static int tupperwareCount     = 0;    // 31
  static int gasTankCount        = 0;    // 32

  static int groupCapability     = 0;
  

  static ValueNotifier<bool> showPresenter = ValueNotifier(false);
  static double distanceDriverToPickup = 0.0;  // 14
  static String googleApiKey = 'AIzaSyDa5S3_IbRkjAJsH53VIXca0ZPLm9WcSHw';



}
