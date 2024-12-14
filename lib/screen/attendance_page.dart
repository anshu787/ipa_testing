import 'dart:async';

import 'package:attendancewithfingerprint/model/attendance.dart';
import 'package:attendancewithfingerprint/screen/main_menu_page.dart';
import 'package:attendancewithfingerprint/utils/strings.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_location/trust_location.dart';

import '../database/db_helper.dart';
import '../model/settings.dart';
import '../utils/utils.dart';

class AttendancePage extends StatefulWidget {
  final String query;
  final String title;

  AttendancePage({required this.query, required this.title});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late ProgressDialog pr;
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  final DbHelper dbHelper = DbHelper();
  final Utils utils = Utils();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late Settings settings;
  late String getUrl,
      getKey,
      getQrId,
      getQuery,
      getPath = '/api/attendance/apiSaveAttendance',
      mAccuracy,
      getPathArea = '/api/area/index';
  var getId, _value;
  late bool _isMockLocation, clickButton = false;
  late Position _currentPosition;
  final Geolocator geoLocator = Geolocator();
  late StreamSubscription<Position> subscription;
  double setAccuracy = 200.0;
  List dataArea = [];

  @override
  void initState() {
    super.initState();
    getPref();
    _getCurrentLocation();
    getSettings();
    TrustLocation.start(5);
    checkMockInfo();
  }

  @override
  void dispose() {
    subscription.cancel();
    TrustLocation.stop();
    super.dispose();
  }

  Future<void> getAreaApi() async {
    pr.show();
    final uri = utils.getRealUrl(getUrl, getPathArea);
    Dio dio = Dio();
    try {
      final response = await dio.get(uri);
      var data = response.data;

      if (data['message'] == 'success') {
        setState(() {
          dataArea = data['area'];
        });
      } else {
        setState(() {
          dataArea = [
            {"id": 0, "name": "No Data Area"}
          ];
        });
      }
    } catch (e) {
      print("Error fetching area data: $e");
    } finally {
      if (mounted) {
        setState(() {
          pr.close();
        });
      }
    }
  }

  Future<void> checkMockInfo() async {
    try {
      TrustLocation.onChange.listen((values) {
        setState(() {
          _isMockLocation = values.isMockLocation!;
        });
      });
    } on PlatformException catch (e) {
      print('PlatformException: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter:
          10, // The minimum distance (in meters) before updates are received.
    );

    try {
      subscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (Position position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
            });
            // Call a method to process the address with the current position
            _getAddressFromLatLng(_currentPosition as double);
          }
        },
        onError: (error) {
          // Handle any errors here, such as permissions not granted
          print("Error getting location: $error");
        },
      );
    } catch (e) {
      print("Exception occurred while getting location: $e");
    }
  }

  Future<void> _getAddressFromLatLng(double accuracy) async {
    String strAccuracy = accuracy.toStringAsFixed(1);
    setState(() {
      mAccuracy = (accuracy > setAccuracy)
          ? '$strAccuracy $attendance_not_accurate'
          : '$strAccuracy $attendance_accurate';
    });
  }

  Future<void> getSettings() async {
    var getSettings = await dbHelper.getSettings(1);
    setState(() {
      getUrl = getSettings.url;
      getKey = getSettings.key;
    });
    getAreaApi();
  }

  Future<void> getPref() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    setState(() {
      getId = preferences.getInt("id");
    });
  }

  Future<void> sendData() async {
    if (_value == null) {
      if (mounted) {
        setState(() {
          pr.close();
        });
      }
      utils.showAlertDialog(
          select_area, "warning", AlertType.warning, _scaffoldKey, true);
      return;
    }

    pr.show();

    Map<String, dynamic> body = {
      'key': getKey,
      'worker_id': getId,
      'q': getQuery,
      'lat': _currentPosition.latitude,
      'longt': _currentPosition.longitude,
      'area_id': _value,
    };

    try {
      final uri = utils.getRealUrl(getUrl, getPath);
      Dio dio = Dio();
      FormData formData = FormData.fromMap(body);
      final response = await dio.post(uri, data: formData);
      var data = response.data;

      if (data['message'] == 'Success!') {
        Attendance attendance = Attendance(
          date: data['date'],
          id: data['id'],
          time: data['time'],
          location: data['location'],
          type: data['query'],
        );

        insertAttendance(attendance);

        if (mounted) {
          setState(() {
            subscription.cancel();
            pr.close();
            Alert(
              context: _scaffoldKey.currentContext!,
              type: AlertType.success,
              title: "Success",
              desc: "$attendance_show_alert-$getQuery $attendance_success_ms",
              buttons: [
                DialogButton(
                  child: Text(
                    ok_text,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => MainMenuPage()),
                    (Route<dynamic> route) => false,
                  ),
                  width: 120,
                )
              ],
            ).show();
          });
        }
      } else {
        _handleErrorResponse(data['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pr.close();
        });
      }
      utils.showAlertDialog(
          'Error: $e', "Error", AlertType.error, _scaffoldKey, true);
    }
  }

  void _handleErrorResponse(String message) {
    if (mounted) {
      setState(() {
        pr.close();
      });
    }

    switch (message) {
      case 'cannot attend':
        utils.showAlertDialog(
            outside_area, "warning", AlertType.warning, _scaffoldKey, true);
        break;
      case 'location not found':
        utils.showAlertDialog(location_not_found, "warning", AlertType.warning,
            _scaffoldKey, true);
        break;
      case 'already check-in':
        utils.showAlertDialog(
            already_check_in, "warning", AlertType.warning, _scaffoldKey, true);
        break;
      case 'check-in first':
        utils.showAlertDialog(
            check_in_first, "warning", AlertType.warning, _scaffoldKey, true);
        break;
      case 'Error! Something Went Wrong!':
        utils.showAlertDialog(attendance_error_server, "Error", AlertType.error,
            _scaffoldKey, true);
        break;
      default:
        utils.showAlertDialog(
            message, "Error", AlertType.error, _scaffoldKey, true);
        break;
    }
  }

  Future<void> insertAttendance(Attendance object) async {
    await dbHelper.newAttendances(object);
  }

  Future<bool> _isBiometricAvailable() async {
    try {
      return await _localAuthentication.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('PlatformException: $e');
      return false;
    }
  }

  Future<void> _getListOfBiometricTypes() async {
    try {
      await _localAuthentication.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('PlatformException: $e');
    }
  }

  Future<void> _authenticateUser() async {
    bool isAuthenticated = false;
    try {
      isAuthenticated = await _localAuthentication.authenticate(
        localizedReason: "Please authenticate to attend",
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      print('PlatformException: $e');
    }

    if (isAuthenticated && mounted) {
      await sendData();
    }
  }

  bool isProgressDialogShowing = false;

  Future<void> CheckMockIsNull() async {
    if (clickButton) {
      clickButton = true;
      await _authenticateUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              clickButton = true;
            });
            CheckMockIsNull();
          },
          child: Text("Mark Attendance"),
        ),
      ),
    );
  }
}
