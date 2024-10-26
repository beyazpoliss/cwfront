import 'package:cwfront/worker_creation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static List<dynamic> workers = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
    try {
      final String? token = await StorageService.read("jwt_token");
      final response = await http.get(
        Uri.parse('${StorageService.url}/workers'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          workers = jsonDecode(response.body);
        });
      } else {
        throw Exception('Failed to load workers');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching workers: $e')),
      );
    }
  }

  Future<void> _deleteWorker(String username) async {
    try {
      final String? token = await StorageService.read("jwt_token");
      final response = await http.delete(
        Uri.parse('${StorageService.url}/workers/$username'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker deleted successfully')),
        );
        _fetchWorkers(); // Refresh the list
      } else {
        throw Exception('Failed to delete worker');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting worker: $e')),
      );
    }
  }

  Future<void> _confirmDeleteWorker(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('$username will be deleted. Do you want to proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteWorker(username);
    }
  }

  Widget _buildWorkerCard(dynamic worker) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkerDetailPage(worker: worker),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(worker['username'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _confirmDeleteWorker(worker['username']);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Home'),
      ),
      body: ListView.builder(
        itemCount: workers.length,
        itemBuilder: (context, index) {
          return _buildWorkerCard(workers[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerCreationPage(),
            ),
          );
          if (result == true) {
            _fetchWorkers(); // Refresh the list if a new worker was created
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}


class WorkerDetailPage extends StatelessWidget {
  final dynamic worker;

  const WorkerDetailPage({Key? key, required this.worker}) : super(key: key);

  String _getStatusText(int status) {
    switch (status) {
      case 0:
        return 'Clocked Out';
      case 1:
        return 'Working';
      case 2:
        return 'Lunch Break';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestLog = worker['dailyLogs'].isNotEmpty ? worker['dailyLogs'].last : null;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(worker['username']),
        backgroundColor: Color.fromARGB(48, 20, 48,100),
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker['username'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (latestLog != null) Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(latestLog["status"]),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Status: ${_getStatusText(latestLog["status"])}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Logs Section
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color:         Color.fromARGB(48, 20, 48,100),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: TabBar(
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.login),
                          text: "Clock-Ins",
                        ),
                        Tab(
                          icon: Icon(Icons.lunch_dining),
                          text: "Lunch",
                        ),
                        Tab(
                          icon: Icon(Icons.logout),
                          text: "Clock-Outs",
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Clock-Ins Tab
                        _buildLogList(
                          context,
                          worker['dailyLogs'],
                              (log) => log['clockIns'],
                              (entry) => LogEntryCard(
                            title: 'Clock-In',
                            time: entry['clockInTime'],
                            location: entry['gpsLocations'][0],
                            icon: Icons.login,
                            color: Colors.blue,
                          ),
                        ),

                        // Lunch Breaks Tab
                        _buildLogList(
                          context,
                          worker['dailyLogs'],
                              (log) => log['lunchBreaks'],
                              (entry) => LogEntryCard(
                            title: 'Lunch Break',
                            time: entry['lunchStartTime'],
                            endTime: entry['lunchEndTime'],
                            icon: Icons.lunch_dining,
                            color: Colors.orange,
                          ),
                        ),

                        // Clock-Outs Tab
                        _buildLogList(
                          context,
                          worker['dailyLogs'],
                              (log) => log['clockOuts'],
                              (entry) => LogEntryCard(
                            title: 'Clock-Out',
                            time: entry['clockOutTime'],
                            location: entry['gpsLocations'],
                            icon: Icons.logout,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(
      BuildContext context,
      List dailyLogs,
      List Function(dynamic) getEntries,
      Widget Function(dynamic) buildCard,
      ) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: dailyLogs.length,
      itemBuilder: (context, index) {
        final log = dailyLogs[index];
        final entries = getEntries(log);
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                DateFormat.yMMMd().format(DateTime.parse(log['date'])),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...entries.map((entry) => buildCard(entry)).toList(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class LogEntryCard extends StatelessWidget {
  final String title;
  final String time;
  final String? endTime;
  final dynamic location;
  final IconData icon;
  final Color color;

  const LogEntryCard({
    Key? key,
    required this.title,
    required this.time,
    this.endTime,
    this.location,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              endTime == null
                  ? DateFormat.jm().format(DateTime.parse(time))
                  : '${DateFormat.jm().format(DateTime.parse(time))} - ${DateFormat.jm().format(DateTime.parse(endTime!))}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (location != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<String?>(
                future: _getLocationName(
                  location['lat'].toDouble(),
                  location['lon'].toDouble(),
                ),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Loading location...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        return [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
      return 'Location unavailable';
    } catch (e) {
      return 'Error fetching location';
    }
  }
}