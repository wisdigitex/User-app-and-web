import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class AppUtils {
  static whatsapp(Uri whatsAppUri) async {
    if (await canLaunchUrl(whatsAppUri)) {
      await launchUrl(whatsAppUri);
    } else {
      debugPrint("Could not launch $whatsAppUri");
    }
  }
}