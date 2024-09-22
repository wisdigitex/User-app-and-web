import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sixam_mart/common/widgets/demo_reset_dialog_widget.dart';
import 'package:sixam_mart/features/chat/controllers/chat_controller.dart';
import 'package:sixam_mart/features/chat/enums/user_type_enum.dart';
import 'package:sixam_mart/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sixam_mart/features/dashboard/screens/dashboard_screen.dart';
import 'package:sixam_mart/features/notification/widgets/notifiation_popup_dialog_widget.dart';

class NotificationHelper {

  static Future<void> initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()!.requestNotificationsPermission();
    flutterLocalNotificationsPlugin.initialize(initializationsSettings, onDidReceiveNotificationResponse: (NotificationResponse load) async {
      try{
        NotificationBodyModel payload;
        if(load.payload!.isNotEmpty) {
          payload = NotificationBodyModel.fromJson(jsonDecode(load.payload!));
          if(payload.notificationType == NotificationType.order) {
            if(AuthHelper.isGuestLoggedIn()){
              Get.to(()=> const DashboardScreen(pageIndex: 3, fromSplash: false));
            } else {
              Get.offAllNamed(RouteHelper.getOrderDetailsRoute(int.parse(payload.orderId.toString()), fromNotification: true));
            }
          } else if(payload.notificationType == NotificationType.general) {
            Get.offAllNamed(RouteHelper.getNotificationRoute(fromNotification: true));
          }else if(payload.notificationType == NotificationType.otp || payload.notificationType == NotificationType.block || payload.notificationType == NotificationType.unblock) {
          }else if(payload.notificationType == NotificationType.add_fund){
            Get.offAllNamed(RouteHelper.getWalletRoute());
          }else{
            Get.offAllNamed(RouteHelper.getChatRoute(notificationBody: payload, conversationID: payload.conversationId, fromNotification: true));
          }
        }
      }catch (_) {}
      return;
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("onMessage: ${message.data['type']}/${message.data}");
      }
      if(message.data['type'] == 'demo_reset') {
        Get.dialog(const DemoResetDialogWidget(), barrierDismissible: false);
      }
      if(message.data['type'] == 'message' && Get.currentRoute.startsWith(RouteHelper.messages)) {
        if(AuthHelper.isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
          if(Get.find<ChatController>().messageModel!.conversation!.id.toString() == message.data['conversation_id'].toString()) {
            Get.find<ChatController>().getMessages(
              1, NotificationBodyModel(
              notificationType: NotificationType.message, adminId: message.data['sender_type'] == UserType.admin.name ? 0 : null,
              restaurantId: message.data['sender_type'] == UserType.vendor.name ? 0 : null,
              deliverymanId: message.data['sender_type'] == UserType.delivery_man.name ? 0 : null,
            ),
              null, int.parse(message.data['conversation_id'].toString()),
            );
          }else {
            NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
          }
        }
      }else if(message.data['type'] == 'message' && Get.currentRoute.startsWith(RouteHelper.conversation)) {
        if(AuthHelper.isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
        }
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
      }else {
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
        if(AuthHelper.isLoggedIn()) {
          Get.find<OrderController>().getRunningOrders(1);
          Get.find<OrderController>().getHistoryOrders(1);
          Get.find<NotificationController>().getNotificationList(true);

        }
      }

      Map<String, String> payloadData = {
        'title' : '${message.data['title']}',
        'body' : '${message.data['body']}',
        'order_id' : '${message.data['order_id']}',
        'image' : '${message.data['image']}',
        'type' : '${message.data['type']}',
      };

      PayloadModel payload = PayloadModel.fromJson(payloadData);

      if(kIsWeb) {
        showDialog(
            context: Get.context!,
            builder: (context) => Center(
              child: NotificationPopUpDialogWidget(payload),
            )
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("onOpenApp: ${message.data}");
      }
      try{
        if(message.data.isNotEmpty) {
          NotificationBodyModel notificationBody = convertNotification(message.data);
          if(notificationBody.notificationType == NotificationType.order) {
            Get.offAllNamed(RouteHelper.getOrderDetailsRoute(int.parse(message.data['order_id']), fromNotification: true));
          } else if(notificationBody.notificationType == NotificationType.general) {
            Get.offAllNamed(RouteHelper.getNotificationRoute(fromNotification: true));
          } else if(notificationBody.notificationType == NotificationType.otp || notificationBody.notificationType == NotificationType.block || notificationBody.notificationType == NotificationType.unblock) {
          }else if(notificationBody.notificationType == NotificationType.add_fund){
            Get.offAllNamed(RouteHelper.getWalletRoute());
          }else{
            Get.offAllNamed(RouteHelper.getChatRoute(notificationBody: notificationBody, conversationID: notificationBody.conversationId, fromNotification: true));
          }
        }
      }catch (_) {}
    });
  }

  static Future<void> showNotification(RemoteMessage message, FlutterLocalNotificationsPlugin fln) async {
    if(!GetPlatform.isIOS) {
      String? title;
      String? body;
      String? orderID;
      String? image;
      NotificationBodyModel notificationBody = convertNotification(message.data);

      title = message.data['title'];
      body = message.data['body'];
      orderID = message.data['order_id'];
      image = (message.data['image'] != null && message.data['image'].isNotEmpty) ? message.data['image'].startsWith('http') ? message.data['image']
        : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}' : null;

      if(image != null && image.isNotEmpty) {
        try{
          await showBigPictureNotificationHiddenLargeIcon(title, body, orderID, notificationBody, image, fln);
        }catch(e) {
          await showBigTextNotification(title, body!, orderID, notificationBody, fln);
        }
      }else {
        await showBigTextNotification(title, body!, orderID, notificationBody, fln);
      }
    }
  }

  static Future<void> showTextNotification(String title, String body, String orderID, NotificationBodyModel? notificationBody, FlutterLocalNotificationsPlugin fln) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', '6ammart', playSound: true,
      importance: Importance.max, priority: Priority.max, sound: RawResourceAndroidNotificationSound('notification'),
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: notificationBody != null ? jsonEncode(notificationBody.toJson()) : null);
  }

  static Future<void> showBigTextNotification(String? title, String body, String? orderID, NotificationBodyModel? notificationBody, FlutterLocalNotificationsPlugin fln) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body, htmlFormatBigText: true,
      contentTitle: title, htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', '6ammart', importance: Importance.max,
      styleInformation: bigTextStyleInformation, priority: Priority.max, playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: notificationBody != null ? jsonEncode(notificationBody.toJson()) : null);
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(String? title, String? body, String? orderID, NotificationBodyModel? notificationBody, String image, FlutterLocalNotificationsPlugin fln) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile(image, 'bigPicture');
    final BigPictureStyleInformation bigPictureStyleInformation = BigPictureStyleInformation(
      FilePathAndroidBitmap(bigPicturePath), hideExpandedLargeIcon: true,
      contentTitle: title, htmlFormatContentTitle: true,
      summaryText: body, htmlFormatSummaryText: true,
    );
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', '6ammart',
      largeIcon: FilePathAndroidBitmap(largeIconPath), priority: Priority.max, playSound: true,
      styleInformation: bigPictureStyleInformation, importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: notificationBody != null ? jsonEncode(notificationBody.toJson()) : null);
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static NotificationBodyModel convertNotification(Map<String, dynamic> data){
    if(data['type'] == 'general' || data['type'] == 'referral_code' || data['type'] == 'referral_earn' || data['type'] == 'cashback') {
      return NotificationBodyModel(notificationType: NotificationType.general);
    }else if(data['type'] == 'otp') {
      return NotificationBodyModel(notificationType: NotificationType.otp);
    }else if(data['type'] == 'add_fund') {
      return NotificationBodyModel(notificationType: NotificationType.add_fund);
    }else if(data['type'] == 'block'){
      return NotificationBodyModel(notificationType: NotificationType.block);
    }else if(data['type'] == 'unblock'){
      return NotificationBodyModel(notificationType: NotificationType.unblock);
    }else if(data['type'] == 'order_status') {
      return NotificationBodyModel(notificationType: NotificationType.order, orderId: int.parse(data['order_id']));
    }else {
      return NotificationBodyModel(
        notificationType: NotificationType.message,
        deliverymanId: data['sender_type'] == 'delivery_man' ? 0 : null,
        adminId: data['sender_type'] == 'admin' ? 0 : null,
        restaurantId: data['sender_type'] == 'vendor' ? 0 : null,
        conversationId: int.parse(data['conversation_id'].toString()),
      );
    }
  }

}

@pragma('vm:entry-point')
Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("onBackground: ${message.data}");
  }
}


class PayloadModel {
  PayloadModel({
    this.title,
    this.body,
    this.orderId,
    this.image,
    this.type,
  });

  String? title;
  String? body;
  String? orderId;
  String? image;
  String? type;

  factory PayloadModel.fromRawJson(String str) => PayloadModel.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PayloadModel.fromJson(Map<String, dynamic> json) => PayloadModel(
    title: json["title"],
    body: json["body"],
    orderId: json["order_id"],
    image: json["image"],
    type: json["type"],
  );

  Map<String, dynamic> toJson() => {
    "title": title,
    "body": body,
    "order_id": orderId,
    "image": image,
    "type": type,
  };
}
