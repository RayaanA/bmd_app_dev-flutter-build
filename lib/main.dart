import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'bt_app',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        ),
        home: MyHomePage(),
      ),
    );
  }
}
enum ImageSection {
  noBluetoothPermission, // Permission denied, but not forever
  noBluetoothPermissionPermanent, // Permission denied forever
  //browseFiles, // The UI shows the button to pick files
  //imageLoaded, // File picked and shown in the screen
}
class MyAppState extends ChangeNotifier {
  //modes of operation
  bool scanNew = false;
  bool loadSaved = false;
  bool loadFromXML = false;

  //keep track of lists here
  var newDevices = <DiscoveredDevice>[];
  var filteredList = <DiscoveredDevice>[];
  var filterTerm = "";
  bool filterList = false;
  var selectedDevice = <DiscoveredDevice>[];
  bool scanning = false;

  //bleVariables
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> scanStream;
  late StreamSubscription<ConnectionStateUpdate> connectionStream;
  late QualifiedCharacteristic rxCharacteristic;
  //ScannerPage variables
  int progression = 0;
  bool saveNew = false;
  var charactName = "";
  var serviceUUID = "";
  var characteristicUUID = "";
  var charData = <int>[];

  //DataPage variables
  bool connectedToDevice = false;

  void _startScan() async {
    bool permGranted = false;
    scanning = false;

    bool permission = false, location = false;
    bool ble_advt_status = false, ble_scan_status = false, ble_pair_status = false;
    permGranted = true;


    if (Platform.isAndroid) {
      if (await Permission.bluetoothScan.request().isGranted && await Permission.bluetoothAdvertise.request().isGranted && await Permission.bluetoothConnect.request().isGranted) {
        permission = true;
      }
      if(await Permission.location.request().isGranted){
        location = true;
      }
      if ( permission && location == true){
        permGranted = true;
      }
      else{
        openAppSettings();
      }
    }
    else if (Platform.isIOS) {
      permGranted = true;
    }

    //main scanning
    if (permGranted) {
      scanStream = flutterReactiveBle.scanForDevices(
          withServices: [], scanMode: ScanMode.lowPower).listen((device) {
        // _ubiqueDevice = device;
        if (newDevices.every((element) => element.id != device.id)) {
          if (device.id.isNotEmpty) {
            newDevices.add(device);
          }
        }
      });
    }
  }

  void connectToDevice() {
    //delete these variables later
    scanStream.cancel();
    final Uuid serviceUuid = Uuid.parse(serviceUUID);
    final Uuid characteristicUuid = Uuid.parse(characteristicUUID);
    // final Uuid characteristicUuid = Uuid.parse("beb5483e-36e1-4688-b7f5-ea07361b26a8");
    Stream<ConnectionStateUpdate> connectionStream = flutterReactiveBle
        .connectToAdvertisingDevice(
        id: selectedDevice[0].id,
        prescanDuration: const Duration(seconds: 2),
        withServices: [serviceUuid, characteristicUuid]);
    connectionStream.listen((event) {
      switch (event.connectionState) {
      // We're connected and good to go!
        case DeviceConnectionState.connected:
          {
            rxCharacteristic = QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: characteristicUuid,
                deviceId: event.deviceId);
            connectedToDevice = true;
            break;
          }
      // Can add various state state updates on disconnect
        case DeviceConnectionState.disconnected:
          {
            break;
          }
        default:
      }
    });
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  bool timerActive = false;

  @override
  Widget build(BuildContext context) {
    Widget page;
    timerActive
        ? (null)
        : (Timer.periodic(const Duration(seconds: 3), (timer) {
            setState(() {
              // print("Refreshing screen");
            });
          }));
    timerActive = true;
    switch (selectedIndex) {
      case 0:
        page = ScannerPage();
        break;
      case 1:
        page = DataPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >= 600,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Scanner'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.analytics),
                    label: Text('Data'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class ScannerPage extends StatefulWidget {
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  //text controller should be outside build function to avoid timer erasing user's search
  final TextEditingController cntlr = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    //for scenario of scanning a new device
    if (appState.scanNew == true) {
      //if progression is 1 and appState filterList is false should display new devices
      if (appState.progression == 1 && appState.filterList == false) {
        return Scaffold(
            appBar: AppBar(
              title: const Text("Device Search/Selection"),
            ),
            body: Column(
              children: <Widget>[
                TextField(
                  controller: cntlr,
                  onSubmitted: (value) {
                    appState.filterTerm = value;
                    appState.newDevices.forEach((element) {
                      if (element.name.contains(appState.filterTerm) ||
                          element.id.contains(appState.filterTerm)) {
                        appState.filteredList.add(element);
                      }
                    });
                    cntlr.clear();
                    setState(() {
                      appState.filterList = true;
                    });
                  },
                ),
                Expanded(
                    child: ListView.builder(
                  itemCount: appState.newDevices.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(
                          "${appState.newDevices[index].name}\n${appState.newDevices[index].id}"),
                      onTap: () {
                        appState.selectedDevice.add(appState.newDevices[index]);
                        setState(() {
                          appState.progression = 2;
                        });
                      },
                    );
                  },
                ))
              ],
            ));
      }

      //display the filtered list if needed and allow return to regular search function
      if (appState.progression == 1 && appState.filterList == true) {
        return Scaffold(
            appBar: AppBar(
              title: const Text("Device Search/Selection"),
            ),
            body: Column(
              children: <Widget>[
                TextField(
                  controller: cntlr,
                  onSubmitted: (value) {
                    appState.filterTerm = value;
                    appState.filteredList.clear();
                    if (appState.filterTerm == "") {
                      appState.filterList = false;
                      appState.filteredList.clear();
                    } else {
                      appState.newDevices.forEach((element) {
                        if (element.name.contains(appState.filterTerm) ||
                            element.id.contains(appState.filterTerm)) {
                          appState.filteredList.add(element);
                        }
                      });
                    }
                    cntlr.clear();
                    setState(() {});
                  },
                ),
                Expanded(
                    child: ListView.builder(
                  itemCount: appState.filteredList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(
                          "${appState.filteredList[index].name}\n${appState.filteredList[index].id}"),
                      onTap: () {
                        appState.selectedDevice
                            .add(appState.filteredList[index]);
                        setState(() {
                          appState.progression = 2;
                        });
                      },
                    );
                  },
                ))
              ],
            ));
      }

      //if progression is 2 allow user to confirm device and either save or not save it
      //allow user to select a different device or cancel search entirely
      //4 total options
      if (appState.progression == 2) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // connectToDevice();
                      appState.scanStream.cancel();
                      appState.newDevices.clear();
                      appState.filteredList.clear();
                      setState(() {
                        appState.saveNew = false;
                        appState.progression = 3;
                      });
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: Text(
                        "Connect to ${appState.selectedDevice[0].id}?\n${appState.selectedDevice[0].name}"),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // connectToDevice();
                      appState.scanStream.cancel();
                      appState.newDevices.clear();
                      appState.filteredList.clear();
                      setState(() {
                        appState.saveNew = true;
                        appState.progression = 3;
                      });
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: Text(
                        "Save & Connect to ${appState.selectedDevice[0].id}?\n${appState.selectedDevice[0].name}"),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // connectToDevice();
                      appState.newDevices.clear();
                      appState.filteredList.clear();
                      appState.selectedDevice.clear();
                      setState(() {
                        appState.progression = 1;
                      });
                    },
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text("Select another Device"),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // connectToDevice();
                      appState.scanStream.cancel();
                      appState.newDevices.clear();
                      appState.filteredList.clear();
                      appState.selectedDevice.clear();
                      setState(() {
                        appState.progression = 0;
                      });
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text("Cancel Search"),
                  ),
                  SizedBox(width: 10),
                ],
              ),
            ],
          ),
        );
      }
      //if progression is 3 then proceed to manual entry, use variable to determine if user wants to save data
      //pre entered data is for personal arduino testing.
      //improvement to be made is allowing multiple characteristics, see what method would be best to allow that
      if (appState.progression == 3) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(
                  icon: Icon(Icons.create),
                  hintText: 'Enter desired label for characteristic',
                  labelText: 'Characteristic Name',
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a name';
                  }
                  appState.charactName = value;
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  icon: Icon(Icons.create),
                  hintText: 'Enter Service Uuid',
                  labelText: 'Service Uuid',
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please input a valid Service Uuid';
                  }
                  appState.serviceUUID = value;
                  return null;
                },
                initialValue: "4fafc201-1fb5-459e-8fcc-c5c9c331914b",
              ),
              TextFormField(
                decoration: const InputDecoration(
                  icon: Icon(Icons.create),
                  hintText: 'Enter Characteristic Uuid',
                  labelText: 'Characteristic Uuid',
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a valid Characteristic Uuid';
                  }
                  appState.characteristicUUID = value;
                  return null;
                },
                initialValue: "beb5483e-36e1-4688-b7f5-ea07361b26a8",
              ),
              Container(
                  padding: const EdgeInsets.only(left: 150.0, top: 40.0),
                  child: ElevatedButton(
                    child: const Text('Submit'),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          appState.connectToDevice();
                          appState.progression = 4;
                          if (appState.saveNew == true) {
                            //implement saving of device here
                          }
                        });
                      }
                    },
                  )),
            ],
          ),
        );
      }

      //finally for progression 4 tell the user that the data tab is displaying the data, include a button to return to main
      //menu and clean up all variables for proper reinitialization
      if (appState.progression == 4) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Data Tab now displaying Data Stream"),
                  SizedBox(width: 10),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // connectToDevice();
                      appState.connectionStream.cancel();
                      appState.selectedDevice.clear();
                      appState.serviceUUID = "";
                      appState.characteristicUUID = "";
                      setState(() {
                        appState.saveNew = false;
                        appState.progression = 0;
                        appState.connectedToDevice = false;
                      });
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: Text("Disconnect"),
                  ),
                  SizedBox(width: 10),
                ],
              ),
            ],
          ),
        );
      }
    }

    //for scenario of loading from a saved device
    //there exist sql libraries to enable this to work
    // if (appState.loadSaved == true) {

    // }

    //for scenario of loading from xml file
    //needed more time to research particulars but should function
    // if (appState.loadFromXML == true) {

    // }

    //this below is the default state, should have buttons, new scan and connect to saved device
    //make sure to enable switching to other routes
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState._startScan();

                  setState(() {
                    appState.progression = 1;
                    appState.scanNew = true;
                  });
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('New Device Scan'),
              ),
              SizedBox(width: 10),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    // appState.loadSaved = true;
                  });
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('Connect to Saved Device'),
              ),
              SizedBox(width: 10),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    // appState.loadFromXML = true;
                  });
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('Connect using XML file'),
              ),
              SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class DataPage extends StatefulWidget {
  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.connectedToDevice == true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${appState.charactName} :   ${appState.charData}'),
                SizedBox(width: 10),
              ],
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Text('Not connected to a device'),
    );
  }
}
