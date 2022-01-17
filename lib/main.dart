import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await SystemChrome.setPreferredOrientations(
  //     [DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);

  runApp(MainScreen());
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Button with BLE',
      debugShowCheckedModeBanner: false,
      home: JoyPad(),
    );
  }
}

class JoyPad extends StatefulWidget {
  @override _JoyPadState createState() => _JoyPadState();
}

class _JoyPadState extends State<JoyPad> {

  final String serviceUuid = "63b803e2-9201-47ee-968b-1405602a1b8e";
  final String characteristicUuid = "46bfca8b-b8d8-40b1-87e7-c22116324c01";
  final String targetDeviceName = "SAMPLE ESP32 DEVICE";

  FlutterBlue flutterBlue = FlutterBlue.instance;
  late StreamSubscription<ScanResult> scanSubscription;
  bool isScanSubscription = false;

  late BluetoothDevice targetDevice;
  late BluetoothCharacteristic targetCharacteristic;
  bool isTargetDevice = false;
  bool isTargetCharacteristic = false;

  String connectionText = "";

  @override
  void initState() {
    super.initState();
    startScan();
  }

  startScan() {
    print("start scan");
    setState(() {
      connectionText = "Start Scanning";
    });

    scanSubscription = flutterBlue.scan().listen((scanResult) {
      if (scanResult.device.name == targetDeviceName) {
        print("DEVICE found");
        stopScan();
        setState(() {
          connectionText = "Found Target Device";
        });

        targetDevice = scanResult.device;
        isTargetDevice = true;
        connectToDevice();
      }
    }, onDone: () => stopScan());
  }

  stopScan() {
    scanSubscription.cancel();
    isScanSubscription = false;
  }

  connectToDevice() async {
    if (isTargetDevice != true) return;

    setState(() {
      connectionText = "Device Connecting";
    });

    await targetDevice.connect();
    print("DEVICE CONNECTED");
    setState(() {
      connectionText = "Device Connected";
    });

    discoverServices();
  }

  disconnectFromDevice() {
    if (isTargetDevice != true) return;

    targetDevice.disconnect();

    setState(() {
      connectionText = "Device Disconnected";
    });
  }

  discoverServices() async {
    if (isTargetDevice != true) return;

    List<BluetoothService> services = await targetDevice.discoverServices();
    services.forEach((service) {
      // do something with service
      if (service.uuid.toString() == serviceUuid) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == characteristicUuid) {
            targetCharacteristic = characteristic;
            isTargetCharacteristic = true;
            writeData("Hi there, ESP32!!");
            setState(() {
              connectionText = "All Ready with ${targetDevice.name}";
            });
          }
        });
      }
    });
  }

  writeData(String data) async{
    if (isTargetCharacteristic != true) return;

    List<int> bytes = utf8.encode(data);
    targetCharacteristic.write(bytes);
  }

  readData() async{
    if (isTargetCharacteristic != true) return;

    List<int> bytes = await targetCharacteristic.read();
    String data = utf8.decode(bytes);
    print(data);
  }

  notifyData() async{
    if (isTargetCharacteristic != true) return;

    await targetCharacteristic.setNotifyValue(true);
    targetCharacteristic.value.listen((bytes) {
      String data = utf8.decode(bytes);
      print(data);
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('ESP CONTROLLER'),
      ),
      body: Container(
          child: isTargetCharacteristic != true
              ? Center(
            child: Text(
              "Waiting...",
              style: TextStyle(fontSize: 24, color: Colors.red),
            ),
          ) :
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children:<Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    ElevatedButton(
                      child: const Text('Write'),
                      onPressed: () { writeData("RE:GT0.001,RF:LT0.002,PE:LT0.003,PF:GT0.001"); },
                    ),
                    ElevatedButton(
                      child: const Text('Read'),
                      onPressed: () { readData(); },
                    ),
                    ElevatedButton(
                      child: const Text('Notify'),
                      onPressed: () { notifyData(); },
                    ),
                  ],
                )
              ]
          )
      ),
    );
  }
}