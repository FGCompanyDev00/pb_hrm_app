import 'package:flutter/material.dart';

class OfficeAddEventPage extends StatefulWidget {
  const OfficeAddEventPage({super.key});

  @override
  _OfficeAddEventPageState createState() => _OfficeAddEventPageState();
}

class _OfficeAddEventPageState extends State<OfficeAddEventPage> {
  String? _selectedBookingType;
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  void _showBookingTypeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1. Add meeting'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '1. Add meeting';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('2. Meeting and Booking meeting room'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '2. Meeting and Booking meeting room';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('3. Booking car'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '3. Booking car';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: picked.hour, minute: picked.minute),
      );

      if (time != null) {
        setState(() {
          final selectedDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (isStartDate) {
            _startDateTime = selectedDateTime;
          } else {
            _endDateTime = selectedDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              // Background Image for AppBar
              Container(
                height: 130,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0),
                  ),
                ),
              ),
              Positioned(
                top: 60.0,
                left: 16.0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const Positioned(
                top: 60.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Office',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
                        ),
                        child: const Text(
                          '+ Add',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    const Text(
                      'Type of Booking*',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: () => _showBookingTypeModal(context),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: Colors.grey),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedBookingType ?? 'Select Booking Type'),
                            const Icon(Icons.menu),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Title*',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start date-Time',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                              ),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _selectDate(context, true),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_startDateTime == null
                                          ? 'Start date'
                                          : '${_startDateTime!.toLocal()}'.split(' ')[0]),
                                      const Icon(Icons.calendar_today),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End date-Time',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                              ),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _selectDate(context, false),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_endDateTime == null
                                          ? 'End date'
                                          : '${_endDateTime!.toLocal()}'.split(' ')[0]),
                                      const Icon(Icons.calendar_today),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1. Local office'),
                          Icon(Icons.menu),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1. meeting at local office'),
                          Icon(Icons.menu),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1. Notify me 30 min before meeting'),
                          Icon(Icons.menu),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle add people logic
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                        ),
                        child: const Text(
                          '+ Add People',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundImage: AssetImage('assets/person1.png'),
                            radius: 20.0,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            backgroundImage: AssetImage('assets/person2.png'),
                            radius: 20.0,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            backgroundImage: AssetImage('assets/person3.png'),
                            radius: 20.0,
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            backgroundColor: Colors.grey,
                            radius: 20.0,
                            child: Text('+3'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
