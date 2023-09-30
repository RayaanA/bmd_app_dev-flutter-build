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
    if (location.isGranted && advertise.isGranted && scan.isGranted && connect.isGranted) {
      flutterReactiveBle.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowPower,
      ).listen((device) {
// Check if the device is not already in the list before adding it
        if (!devices.any((d) => d.id == device.id)) {
          devices.add(device);
          notifyListeners();
        }
      });
    }
  }

    Future<void> connectToDevice(DiscoveredDevice selectedDevice) async {
      try {
        flutterReactiveBle.connectToDevice(id: selectedDevice.id);
        Uuid serviceUUID = Uuid.parse("5e662170-8abd-4a9c-9c00-1587fce1633b");
        Uuid characteristicUUID = Uuid.parse("5e662171-8abd-4a9c-9c00-1587fce1633b");
        //Uuid serviceUUID = Uuid.parse("d9deb300-a6f5-4452-a3a3-58eaa32eaba1");
        //Uuid characteristicUUID = Uuid.parse("d9deb301-a6f5-4452-a3a3-58eaa32eaba1");
        print("THE DEVICE IS CONNECTED");
        final characteristic = QualifiedCharacteristic(serviceId: serviceUUID, characteristicId: characteristicUUID, deviceId: selectedDevice.id);
        print("THE DEVICE IS QUALIFIED");
        flutterReactiveBle.subscribeToCharacteristic(characteristic).listen((data) {
          // code to handle incoming data
          print("THE DEVICE IS SUBSCRIBED");
          for (int x=0; x < data.length; x++){
            print("Received Data: ${data[x]}");
          }

        }, onError: (dynamic error) {
          print("NO DATA");
        });
        // Connection successful, you can now communicate with the device
      } catch (e) {
        // Handle connection errors
        print('Connection error: $e');
      }
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
          Expanded( // Wrap the ListView.builder with Expanded
            child: ListView.builder(
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
          ),
        ],
      ),
    );
  }
}

// Implement the DataPage and connection logic as needed
