import 'package:attendancewithfingerprint/database/db_helper.dart';
import 'package:attendancewithfingerprint/model/attendance.dart';
import 'package:attendancewithfingerprint/utils/strings.dart';
import 'package:flutter/material.dart';

class ReportPage extends StatefulWidget {
  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final DbHelper dbHelper = DbHelper();
  late Future<List<Attendance>> attendances;

  @override
  void initState() {
    super.initState();
    getData();
  }

  void getData() {
    setState(() {
      attendances = dbHelper.getAttendances();
    });
  }

  SingleChildScrollView dataTable(List<Attendance> attendances) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(
              label: Text(
                report_date,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                report_time,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                report_type,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                report_location,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: attendances
              .map(
                (attendance) => DataRow(
                  cells: [
                    DataCell(
                      Text(attendance.date),
                    ),
                    DataCell(
                      Text(attendance.time),
                    ),
                    DataCell(
                      Text(attendance.type),
                    ),
                    DataCell(
                      Text(attendance.location),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget list() {
    return Expanded(
      child: FutureBuilder<List<Attendance>>(
        future: attendances,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return dataTable(snapshot.data!);
          }

          return Center(child: Text(report_no_data));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(report_title),
      ),
      body: Column(
        children: <Widget>[
          list(),
        ],
      ),
    );
  }
}
