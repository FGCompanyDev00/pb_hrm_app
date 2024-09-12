import 'package:flutter/material.dart';

class EventDetailView extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailView({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    // Calculate avatar size and spacing dynamically based on screen size
    double avatarRadius = MediaQuery.of(context).size.width * 0.06; // Smaller size for compactness
    double horizontalPadding = MediaQuery.of(context).size.width * 0.05; // Dynamic padding for compact layout

    return Scaffold(
      // Custom AppBar with background image and centered title
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90), // Custom height for AppBar
        child: AppBar(
          automaticallyImplyLeading: false, // Disable default back button
          flexibleSpace: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              Image.asset(
                'assets/background.png',
                fit: BoxFit.cover, // Ensure the image covers the entire AppBar area
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Text(
                      'Calendar Event Details', // Centered title
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.06, // Responsive text size
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // Modern style text color
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // Custom back button
              Positioned(
                left: 16,
                top: 60,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.black, // Back button color
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event title
              Text(
                event['title'] ?? 'No Title',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.055, // Responsive title size
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Event time
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.grey, size: 18), // Adjusted icon size for compactness
                  const SizedBox(width: 6),
                  Text(
                    'Time: ${event['time'] ?? 'No Time'}',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.04, // Responsive text size
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Event location
              if (event['location'] != '')
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      event['location'] ?? 'No Location',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16), // Compact spacing

              // Attendees section
              const Text(
                'Attendees',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Display attendees using a wrap layout
              Wrap(
                spacing: 8.0, // Reduced space between avatars for compactness
                runSpacing: 8.0, // Vertical space between rows of avatars
                children: (event['attendees'] as List<String>).map((avatar) {
                  return CircleAvatar(
                    radius: avatarRadius,
                    backgroundImage: AssetImage(avatar),
                    onBackgroundImageError: (exception, stackTrace) => const Icon(Icons.error),
                    // Optional tooltip to display attendee name (if available)
                    child: const Tooltip(
                      message: "Attendee", // You can change this based on the event data
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
