import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'Bluetooth App',
        home: MyHomePage(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> devices = [];

  Future<void> startScan() async {
    devices.clear();
    final location = await Permission.location.request();
    final advertise = await Permission.bluetoothAdvertise.request();
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (location.isGranted && advertise.isGranted && scan.isGranted && connect.isGranted){
      flutterReactiveBle.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowPower,
      ).listen((device) {
        if (!devices.contains(device)) {
          devices.add(device);
          notifyListeners();
        }
      });
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    // Implement your connection logic here
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Devices'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              await appState.startScan();
            },
            child: Text('Scan for Devices'),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: appState.devices.length,
            itemBuilder: (context, index) {
              final device = appState.devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.id),
                onTap: () async {
                  await appState.connectToDevice(device);
                  // Navigate to the DataPage
                  // Implement this navigation as needed
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Implement the DataPage and connection logic as needed
