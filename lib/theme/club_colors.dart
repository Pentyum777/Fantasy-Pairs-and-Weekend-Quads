import 'package:flutter/material.dart';

class ClubColors {
  static const Map<String, Color> colors = {
    "Adelaide": Color(0xFF002B5C),
    "Brisbane": Color(0xFF7A003C),
    "Carlton": Color(0xFF031A29),
    "Collingwood": Color(0xFF000000),
    "Essendon": Color(0xFFCC2031),
    "Fremantle": Color(0xFF2A0D54),
    "Geelong": Color(0xFF001C3F),
    "Gold Coast": Color(0xFFFF0000),
    "GWS": Color(0xFFFF6600),
    "Hawthorn": Color(0xFF4D2000),
    "Melbourne": Color(0xFF0F1131),
    "North Melbourne": Color(0xFF0033A0),
    "Port Adelaide": Color(0xFF01B2AF),
    "Richmond": Color(0xFFFFD200),
    "St Kilda": Color(0xFFED0A3F),
    "Sydney": Color(0xFFED1C24),
    "West Coast": Color(0xFF003087),
    "Western Bulldogs": Color(0xFF0033A0),
  };

  static Color forClub(String club) {
    return colors[club] ?? Colors.grey.shade300;
  }
}