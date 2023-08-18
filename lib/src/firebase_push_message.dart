/* ********************************************************************
 *
 * Firebase Push Message - 파이어베이스 푸시 메시지 패키지
 * 
 * 2022.06.16   TaekMin Kwon    firebase sms auth 기능 구현
 * 2022.07.18   TaekMin Kwon    firebase in app messaging 기능 구현
 * 2022.08.29   TaekMin Kwon    코드 주석 추가 작업 중
 * 
******************************************************************** */

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter_keychain/flutter_keychain.dart';
import 'package:flutter_lg_health/network/environment.dart';
import 'package:flutter_lg_health/network/restful_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// main.dart에 초기화 함수를 추가해야 합니다.
///
/// DefalutFirebaseOptions.currentPlatform을 사용하기 위해서는 'package:{$YOUR_PATH}/firebase_options.dart'를 import해야 합니다.
/// 'package:{$YOUR_PATH}/firebase_options.dart'를 import하기 위해서는 FlutterFire 환경을 설정해야 합니다.
/// FlutterFire 환경 구축은 https://firebase.flutter.dev/docs/overview 페이지를 참고하여 할 수 있습니다.
///
/// ```dart
/// Future<void> main() async {
///   ...
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp(
///     options: DefaultFirebaseOptions.currentPlatform // 'firebase_options.dart' import 필요
///   );
///   ...
///   runApp(MyApp());
/// }
/// ```

Future<void> onBackgroundMessage(RemoteMessage message) async {
  print("########## onBackgroundMessage ##########");
  print(message.toMap().toString());
  if (message.data.containsKey('payload')) {
    // Handle data message
    final data = message.data['payload'];
    print(data);
  }

  if (message.data.containsKey('notification')) {
    // Handle notification message
    final notification = message.data['notification'];
    print(notification);
  }
  // Or do other work.
}

// 2023-08-04, Sangwon Kim
Future<void> setupInteractedMessage(StreamController streamCtlr) async {
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessage(initialMessage, streamCtlr);
  }
}

Future<void> _handleMessage(
    RemoteMessage message, StreamController streamCtlr) async {
  if (message.data.containsKey('payload')) {
    // Handle data message
    streamCtlr.sink.add(message.data['payload']);
  }
  if (message.data.containsKey('notification')) {
    // Handle notification message
    streamCtlr.sink.add(message.data['notification']);
  }
}

class FirebasePushMessage {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _firebaseInAppMessaging = FirebaseInAppMessaging.instance;

  final streamCtlr = StreamController<String>.broadcast();
  // final titleCtlr = StreamController<String>.broadcast();
  // final bodyCtlr = StreamController<String>.broadcast();

  /// FCM 서비스 사용 시 Notification setting 값을 설정합니다.
  Future<void> setNotifications() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
    FirebaseMessaging.onMessage.listen(
      (message) async {
        print("########## onMessage ##########");
        if (message.data.containsKey('payload')) {
          // Handle data message
          streamCtlr.sink.add(message.data['payload']);
        }
        if (message.data.containsKey('notification')) {
          // Handle notification message
          streamCtlr.sink.add(message.data['notification']);
        }
        // Or do other work.
        // titleCtlr.sink.add(message.notification!.title!);
        // bodyCtlr.sink.add(message.notification!.body!);
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("########## onMessageOpenedApp ##########");

      if (message.data.containsKey('payload')) {
        // Handle data message
        streamCtlr.sink.add(message.data['payload']);
      }
      if (message.data.containsKey('notification')) {
        // Handle notification message
        streamCtlr.sink.add(message.data['notification']);
      }
      // titleCtlr.sink.add(message.notification!.title!);
      // bodyCtlr.sink.add(message.notification!.body!);
    });

    // 2023-08-04, Sangwon Kim
    setupInteractedMessage(streamCtlr);

    // With this token you can test it easily on your phone
    _firebaseMessaging.getToken().then((fcmToken) => {
          // Token은 서버에 전송
          saveToken(fcmToken),
        });

    _firebaseMessaging.onTokenRefresh.listen((fcmToken) {
      saveToken(fcmToken);
    }).onError((error) {
      print('Token refresh error: $error');
    });

    print('User granted permission: ${settings.authorizationStatus}');

    /// Analytics 데이터 수집을 일시중지(false)합니다.
    _firebaseInAppMessaging.setAutomaticDataCollectionEnabled(false);

    /// Firebase in app messaging 억제를 비활성화(false)합니다.
    _firebaseInAppMessaging.setMessagesSuppressed(false);
  }

  Future<String> getDeviceUniqueId() async {
    var deviceIdentifier = 'unknown';
    var deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      deviceIdentifier = androidInfo.androidId!;
    } else if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      deviceIdentifier = iosInfo.identifierForVendor!;
    }

    return deviceIdentifier;
  }

  Future<void> saveToken(token) async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setString("token", token);

    var deviceId = await getDeviceUniqueId();
    var serviceAccountId = await FlutterKeychain.get(key: "serviceAccountId");
    var url = environment.apiLgServer +
        '/users/' +
        serviceAccountId.toString() +
        '/push/devices';
    print('########## [Firebase] url : $url');

    Map<String, dynamic> dataModel = {
      "deviceUniqueId": deviceId,
      "devicePlatform": Platform.isAndroid ? "Andorid" : "iOS",
      "token": token
    };
    print('########## [Firebase] dataModel : ' + dataModel.toString());
    try {
      Map<String, dynamic> responseData = await RestfulService()
          .lgApi(url: url, requestBody: dataModel, method: 'POST');
      print('########## [Firebase] responseData : ' + responseData.toString());
      // for ios badge handling API, 2023-08-02, Sangwon Kim
      prefs.setInt('deviceId', responseData["deviceId"]);
    } catch (e) {
      print('########## [Firebase] error : ' + e.toString());
    }
  }

  dispose() {
    streamCtlr.close();
  }
}
