import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Camera test in background mode',
      themeMode: ThemeMode.light,
      home: MyHomePage(title: 'Camera test in background mode'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? cameraSettingsForeground;
  String? cameraSettingsBackground;
  ReceivePort? foregroundMessageReceiverPort;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _initForegroundListener();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'notification_channel_id',
        channelName: 'Foreground Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions:
          const ForegroundTaskOptions(interval: 5000, isOnceEvent: false),
    );

    FlutterForegroundTask.startService(
        notificationTitle: "RUNNING ISOLATE",
        notificationText: "SIMPLY TEST",
        callback: startCallback);
  }

  void _initForegroundListener() async {
    foregroundMessageReceiverPort = ReceivePort();

    IsolateNameServer.registerPortWithName(
      foregroundMessageReceiverPort!.sendPort,
      "foreground-messaging-channel",
    );

    foregroundMessageReceiverPort?.listen((message) async {
      print("GOT MESSAGE ON UI THREAD");
      setState(() {
        cameraSettingsBackground = message;
      });
    });
  }

  Future<void> getCameraSettings() async {
    final newCameraSettings = await availableCameras();
    setState(() {
      cameraSettingsForeground =
          newCameraSettings.map((e) => e.toString()).toString();
    });

    IsolateNameServer.lookupPortByName("background-messaging-channel")
        ?.send("getCameraConfig");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                cameraSettingsForeground != null
                    ? Column(
                        children: [
                          const Text("FOREGROUND REQUEST: "),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.black)),
                            child: Text(cameraSettingsForeground!),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      )
                    : Container(),
                cameraSettingsBackground != null
                    ? Column(
                        children: [
                          const Text("BACKGROUND REQUEST: "),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.black)),
                            child: Text(cameraSettingsBackground!),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      )
                    : Container(),
                TextButton(
                    onPressed: getCameraSettings,
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.black)),
                    child: const Text("GET CAMERA SETTINGS"))
              ]),
        ),
      ),
    );
  }
}

// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  ReceivePort? backgroundMessageReceiverPort;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    print("I'am started here in BG");

    backgroundMessageReceiverPort = ReceivePort();

    IsolateNameServer.registerPortWithName(
      backgroundMessageReceiverPort!.sendPort,
      "background-messaging-channel",
    );

    backgroundMessageReceiverPort?.listen((message) async {
      print("GOT MESSAGE ON ISOLATE THREAD: $message");
      // final decodedJson = json.decode(utf8.decode(message));
      // conlog("GOT MESSAGE ON ISOLATE THREAD2:" + decodedJson.toString());
      if (message == "getCameraConfig") {
        WidgetsFlutterBinding.ensureInitialized();
        DartPluginRegistrant.ensureInitialized();
        var response = "nothing";
        try {
          response =
              (await availableCameras()).map((e) => e.toString()).toString();
        } catch (exception, stacktrace) {
          response = "$exception\n\r$stacktrace";
        }
        IsolateNameServer.lookupPortByName("foreground-messaging-channel")
            ?.send(response);
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // You can use the clearAllData function to clear all the stored data.
    await FlutterForegroundTask.clearAllData();
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {}
}
