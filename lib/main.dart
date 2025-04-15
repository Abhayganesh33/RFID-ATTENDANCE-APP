import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimeEntryScreen(),
    );
  }
}

class TimeEntryScreen extends StatefulWidget {
  const TimeEntryScreen({super.key});

  @override
  _TimeEntryScreenState createState() => _TimeEntryScreenState();
}

class _TimeEntryScreenState extends State<TimeEntryScreen> {
  TimeOfDay? punchInTime;
  TimeOfDay? lateTime;
  TimeOfDay? punchOutTime;

  String? selectedPeriod = 'I';
  final List<String> periods = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadTimesForPeriod();
  }

  Future<void> _loadTimesForPeriod() async {
    final snapshot = await _database.child('time_entries/$selectedPeriod').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        punchInTime = _convertStringToTimeOfDay(data['punch_in']);
        lateTime = _convertStringToTimeOfDay(data['late_time']);
        punchOutTime = _convertStringToTimeOfDay(data['punch_out']);
      });
    } else {
      setState(() {
        punchInTime = null;
        lateTime = null;
        punchOutTime = null;
      });
    }
  }

  TimeOfDay _convertStringToTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _selectTime(BuildContext context, Function(TimeOfDay) onTimePicked) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        onTimePicked(picked);
      });
    }
  }

  String _convertTo24HourFormat(TimeOfDay time) {
    final hour = time.hourOfPeriod + (time.period == DayPeriod.pm ? 12 : 0);
    final minute = time.minute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  void _saveToRealtimeDatabase() {
    if (punchInTime != null && lateTime != null && punchOutTime != null) {
      _database.child('time_entries/$selectedPeriod').set({
        'punch_in': _convertTo24HourFormat(punchInTime!),
        'late_time': _convertTo24HourFormat(lateTime!),
        'punch_out': _convertTo24HourFormat(punchOutTime!),
      }).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time saved successfully!')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving time: $error')),
        );
      });
    }
  }

  Future<void> _clearCategory(String category) async {
    final snapshot = await _database.child(category).get();
    if (snapshot.exists) {
      final data = snapshot.value;
      if (data is Map<dynamic, dynamic>) {
        final updatedData = data.map((key, value) => MapEntry(key, ""));
        await _database.child(category).set(updatedData);
      }
    }
  }

  Widget _buildAttendanceTable(String category) {
    return Expanded(
      child: Column(
        children: [
          Text(
            category.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          StreamBuilder<DatabaseEvent>(
            stream: _database.child(category).onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return const CircularProgressIndicator();
              }

              final value = snapshot.data!.snapshot.value;

              List<String> names = [];
              if (value is Map<dynamic, dynamic>) {
                names = value.values.map((e) => e.toString()).toList();
              } else if (value is List<dynamic>) {
                names = value.map((e) => e.toString()).toList();
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: names.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(names[index].isNotEmpty ? names[index] : "No Name"));
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Time Entry for Attendance")),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: periods.map((period) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ChoiceChip(
                          label: Text(period),
                          selected: selectedPeriod == period,
                          onSelected: (selected) {
                            setState(() {
                              selectedPeriod = period;
                              _loadTimesForPeriod();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                Text('Punch In: ${punchInTime?.format(context) ?? "Not Set"}'),
                ElevatedButton(
                  onPressed: () => _selectTime(context, (pickedTime) {
                    punchInTime = pickedTime;
                  }),
                  child: const Text('Select Punch In Time'),
                ),
                const SizedBox(height: 20),
                Text('Late Time: ${lateTime?.format(context) ?? "Not Set"}'),
                ElevatedButton(
                  onPressed: () => _selectTime(context, (pickedTime) {
                    lateTime = pickedTime;
                  }),
                  child: const Text('Select Late Time'),
                ),
                const SizedBox(height: 20),
                Text('Punch Out: ${punchOutTime?.format(context) ?? "Not Set"}'),
                ElevatedButton(
                  onPressed: () => _selectTime(context, (pickedTime) {
                    punchOutTime = pickedTime;
                  }),
                  child: const Text('Select Punch Out Time'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveToRealtimeDatabase,
                  child: const Text('Save Time'),
                ),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendanceTable('present'),
                    _buildAttendanceTable('late'),
                    _buildAttendanceTable('absent'),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _clearCategory('present'),
                      child: const Text("Clear Present"),
                    ),
                    ElevatedButton(
                      onPressed: () => _clearCategory('late'),
                      child: const Text("Clear Late"),
                    ),
                    ElevatedButton(
                      onPressed: () => _clearCategory('absent'),
                      child: const Text("Clear Absent"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
