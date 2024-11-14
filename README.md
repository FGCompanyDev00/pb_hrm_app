HR Mobile App - Phongsavanh Bank

Overview
The HR Mobile App for Phongsavanh Bank is designed to streamline and enhance HR management by providing comprehensive functionalities such as user authentication, attendance tracking, leave management, meeting room booking, calendar integrations, user settings, etc.

Platform and Framework
Framework: Flutter 3
Supported Platforms:
iOS 12 or later
Android SDK 20 or later

Architecture
Data Sync: REST API for server synchronization
Backend:
Frontend Path: demo.flexiflows.co
REST API: demo-application-api.flexiflows.co
UI Design Reference: Figma Design

Core Features

1. User Authentication
Log-In
Username via Email
Password
Option to change to biometric-based authentication
Change Language: English, Laos, Chinese
Forgot Password: Reset via Email
Settings
Profile Management
Language Preferences
Theme Selection: Dark/Light
Notification Preferences: Email/In-App
Fingerprint Setup
Terms and Conditions, Privacy Policy
Log-Out Option

3. Calendar Integration
Display leave and meeting periods
Daily and detailed single-day views
Add personal events and agenda
Push notifications for event reminders

5. Attendance and Work Tracking
Place
Stamp-able Locations: Home, Office
Biometric Authentication for clock in/out within 50m of premises
Work Tracking
Project and Task Management: View, create, edit, delete
Project completion tracking
Calendar integration for due dates
Summary
Daily and monthly attendance details

7. Leave Management
Request
Leave Types: Annual, Sick
Form with start/end dates, number of days, reason
Track Request
Detailed view of leave requests with approval status and actions
Request Approval
Line Manager and HR workflow for leave approval
Request Summary
History of leave requests and leave balance

Data Synchronization

Local Storage: SQLite for temporary data storage
Server Sync: REST API for data synchronization with background sync support
Security Measures
Root and Jailbreak Detection: Prevent app execution on compromised devices
Secure Data Storage: Encrypt sensitive data locally
Network Security: HTTPS for API communications and certificate pinning
Authentication Security: Secure token storage and session management
Biometric Security: Device biometric APIs for authentication
Code Obfuscation: Protect against reverse engineering
Intrusion Detection: Anomaly detection for unusual activities
Logging: Secure logging with encryption and data redaction
Secure Configuration: Use platform-provided secure storage for keys and configuration
Compliance: Adherence to relevant regulations (e.g., GDPR, PCI DSS)

Performance Requirements
Responsiveness: Load and respond to actions within 2 seconds
Offline Capability: Full functionality offline with data synchronization when online
Scalability: Support up to 10,000 users simultaneously
Testing and Quality Assurance
Unit Testing: Extensive tests for business logic
Integration Testing: Ensure smooth integration between components
UI/UX Testing: Consistent and intuitive interface across devices
Performance Testing: Load and stress testing for peak performance
Security Testing: Regular audits and penetration testing

Deployment and Maintenance
Source Code Management: Git repository on GitHub
Deployment: CI/CD pipeline for automated builds and deployments
Monitoring: Implement health and performance monitoring
Updates: Regular updates for new features, security patches, and improvements
User Support: In-app support and feedback mechanisms

Conclusion:
The HR Mobile App for Phongsavanh Bank leverages the latest in mobile development frameworks and security measures to provide a seamless and secure experience for both HR managers and employees. The app’s comprehensive features ensure efficient HR management and user satisfaction.
