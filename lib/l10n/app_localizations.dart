import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_lo.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('lo'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PSVB Next'**
  String get appTitle;

  /// No description provided for @welcomeTopsvb.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PSVB Next'**
  String get welcomeTopsvb;

  /// No description provided for @welcomeSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'You\'re not just another customer.'**
  String get welcomeSubtitle1;

  /// No description provided for @welcomeSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'We\'re not just another Bank...'**
  String get welcomeSubtitle2;

  /// No description provided for @emptyCredentialsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username and password.'**
  String get emptyCredentialsMessage;

  /// No description provided for @networkErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again later.'**
  String get networkErrorMessage;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication Failed'**
  String get authenticationFailed;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get rememberMe;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get login;

  /// No description provided for @forgetPassword.
  ///
  /// In en, this message translates to:
  /// **'Forget Password?'**
  String get forgetPassword;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language From'**
  String get chooseLanguage;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @weWantToSendYou.
  ///
  /// In en, this message translates to:
  /// **'We want to send you various information notifications, whether it is leave approval, making various items in the system, evaluation...'**
  String get weWantToSendYou;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @locationInformation.
  ///
  /// In en, this message translates to:
  /// **'Location Information'**
  String get locationInformation;

  /// No description provided for @weCollectInformation.
  ///
  /// In en, this message translates to:
  /// **'We collect information about your location when using it to provide the best service near you...'**
  String get weCollectInformation;

  /// No description provided for @cameraAndPhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera and Photo'**
  String get cameraAndPhoto;

  /// No description provided for @manyFunctions.
  ///
  /// In en, this message translates to:
  /// **'Many functions in our app require access to the camera or gallery...'**
  String get manyFunctions;

  /// No description provided for @readyToGo.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready to go!'**
  String get readyToGo;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission Denied'**
  String get permissionDenied;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to proceed.'**
  String get locationPermissionRequired;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to proceed.'**
  String get cameraPermissionRequired;

  /// No description provided for @notificationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required to proceed.'**
  String get notificationPermissionRequired;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get newEvent;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add Event'**
  String get addEvent;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search Events'**
  String get searchEvents;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous Month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next Month'**
  String get nextMonth;

  /// No description provided for @eventCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Event Created Successfully'**
  String get eventCreatedSuccessfully;

  /// No description provided for @noTitle.
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get noTitle;

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get noName;

  /// No description provided for @maybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get maybe;

  /// No description provided for @noEventsForThisDay.
  ///
  /// In en, this message translates to:
  /// **'No events for this day'**
  String get noEventsForThisDay;

  /// No description provided for @approval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get approval;

  /// No description provided for @viewMore.
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// No description provided for @meetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Meeting'**
  String get meetingTitle;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @meetingRoomBookings.
  ///
  /// In en, this message translates to:
  /// **'Meeting Room Bookings'**
  String get meetingRoomBookings;

  /// No description provided for @bookingCar.
  ///
  /// In en, this message translates to:
  /// **'Booking Car'**
  String get bookingCar;

  /// No description provided for @minutesOfMeeting.
  ///
  /// In en, this message translates to:
  /// **'Minutes Of Meeting'**
  String get minutesOfMeeting;

  /// No description provided for @outMeeting.
  ///
  /// In en, this message translates to:
  /// **'Out Meeting'**
  String get outMeeting;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @detailCalendarEvent.
  ///
  /// In en, this message translates to:
  /// **'Detail Calendar Event'**
  String get detailCalendarEvent;

  /// No description provided for @meetingDate.
  ///
  /// In en, this message translates to:
  /// **'Date: 01-05-2024, 8:30 To 01-05-2024, 12:00'**
  String get meetingDate;

  /// No description provided for @meetingRoom.
  ///
  /// In en, this message translates to:
  /// **'Room: Back canyon 2F'**
  String get meetingRoom;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Status: Pending'**
  String get statusPending;

  /// No description provided for @approvalTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting and Booking meeting room'**
  String get approvalTitle;

  /// No description provided for @approvalDate.
  ///
  /// In en, this message translates to:
  /// **'Date: 01-05-2024, 8:30 To 01-05-2024, 12:00'**
  String get approvalDate;

  /// No description provided for @approvalType.
  ///
  /// In en, this message translates to:
  /// **'Type: Sick Leave'**
  String get approvalType;

  /// No description provided for @calender.
  ///
  /// In en, this message translates to:
  /// **'Calender'**
  String get calender;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @office.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get office;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @leaveManagement.
  ///
  /// In en, this message translates to:
  /// **'Leave Management'**
  String get leaveManagement;

  /// No description provided for @typeOfBooking.
  ///
  /// In en, this message translates to:
  /// **'Type of Booking'**
  String get typeOfBooking;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @startDateTime.
  ///
  /// In en, this message translates to:
  /// **'Start date-Time'**
  String get startDateTime;

  /// No description provided for @endDateTime.
  ///
  /// In en, this message translates to:
  /// **'End date-Time'**
  String get endDateTime;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @addPeople.
  ///
  /// In en, this message translates to:
  /// **'Add People'**
  String get addPeople;

  /// No description provided for @actionMenu.
  ///
  /// In en, this message translates to:
  /// **'Action Menu'**
  String get actionMenu;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvals;

  /// No description provided for @kPI.
  ///
  /// In en, this message translates to:
  /// **'KPI'**
  String get kPI;

  /// No description provided for @workTracking.
  ///
  /// In en, this message translates to:
  /// **'Work Tracking'**
  String get workTracking;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @myHistory.
  ///
  /// In en, this message translates to:
  /// **'My History'**
  String get myHistory;

  /// No description provided for @myHistoryItems.
  ///
  /// In en, this message translates to:
  /// **'My History Items'**
  String get myHistoryItems;

  /// No description provided for @noPendingItems.
  ///
  /// In en, this message translates to:
  /// **'No Pending Items'**
  String get noPendingItems;

  /// No description provided for @noPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get noPhoneNumber;

  /// No description provided for @infoLabel.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoLabel;

  /// No description provided for @noPurpose.
  ///
  /// In en, this message translates to:
  /// **'No Purpose'**
  String get noPurpose;

  /// No description provided for @noRoomInfo.
  ///
  /// In en, this message translates to:
  /// **'No Room Info'**
  String get noRoomInfo;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @tel.
  ///
  /// In en, this message translates to:
  /// **'Tel'**
  String get tel;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @submittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted on'**
  String get submittedOn;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @myProject.
  ///
  /// In en, this message translates to:
  /// **'My Project'**
  String get myProject;

  /// No description provided for @allProject.
  ///
  /// In en, this message translates to:
  /// **'All Project'**
  String get allProject;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @remarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Remark'**
  String get remarkLabel;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Email'**
  String get enterYourEmail;

  /// No description provided for @attendant.
  ///
  /// In en, this message translates to:
  /// **'Attendant'**
  String get attendant;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @room.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get room;

  /// No description provided for @typeOfLeave.
  ///
  /// In en, this message translates to:
  /// **'Type of leave'**
  String get typeOfLeave;

  /// No description provided for @requestor.
  ///
  /// In en, this message translates to:
  /// **'Requestor'**
  String get requestor;

  /// No description provided for @registerYourPresence.
  ///
  /// In en, this message translates to:
  /// **'Register Your Presence and Start Your Work'**
  String get registerYourPresence;

  /// No description provided for @checkinTime.
  ///
  /// In en, this message translates to:
  /// **'Check in time can be late by 01:00'**
  String get checkinTime;

  /// No description provided for @checkin.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkin;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Check Out'**
  String get checkout;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// No description provided for @hi.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get hi;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @qrMyProfile.
  ///
  /// In en, this message translates to:
  /// **'QR My Profile'**
  String get qrMyProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @profileDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile Details'**
  String get profileDetails;

  /// No description provided for @enableTouchID.
  ///
  /// In en, this message translates to:
  /// **'Enable Touch ID/FaceID'**
  String get enableTouchID;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @surname.
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get surname;

  /// No description provided for @telephone.
  ///
  /// In en, this message translates to:
  /// **'Tel.'**
  String get telephone;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @unknownRoom.
  ///
  /// In en, this message translates to:
  /// **'Unknown Room'**
  String get unknownRoom;

  /// No description provided for @unknownType.
  ///
  /// In en, this message translates to:
  /// **'Unknown Type'**
  String get unknownType;

  /// No description provided for @leaveType.
  ///
  /// In en, this message translates to:
  /// **'Leave Type'**
  String get leaveType;

  /// No description provided for @updatedMembers.
  ///
  /// In en, this message translates to:
  /// **'Updated Members'**
  String get updatedMembers;

  /// No description provided for @pleaseSelectLeaveType.
  ///
  /// In en, this message translates to:
  /// **'Please select a leave type'**
  String get pleaseSelectLeaveType;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login Failed'**
  String get loginFailed;

  /// No description provided for @loginFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Login failed: '**
  String get loginFailedMessage;

  /// No description provided for @biometricDisabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication Disabled'**
  String get biometricDisabled;

  /// No description provided for @enableBiometric.
  ///
  /// In en, this message translates to:
  /// **'Please enable biometric authentication in settings.'**
  String get enableBiometric;

  /// No description provided for @authenticateToLogin.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to login'**
  String get authenticateToLogin;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication Failed'**
  String get authFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed. Please try again.'**
  String get tryAgain;

  /// No description provided for @emptyFieldsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get emptyFieldsMessage;

  /// No description provided for @newNotification.
  ///
  /// In en, this message translates to:
  /// **'New Notification'**
  String get newNotification;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications about assignments, project updates, and member changes in psvb Next app.'**
  String get notificationChannelDescription;

  /// No description provided for @pageIndicator1of3.
  ///
  /// In en, this message translates to:
  /// **'1 of 3'**
  String get pageIndicator1of3;

  /// No description provided for @pageIndicator2of3.
  ///
  /// In en, this message translates to:
  /// **'2 of 3'**
  String get pageIndicator2of3;

  /// No description provided for @pageIndicator3of3.
  ///
  /// In en, this message translates to:
  /// **'3 of 3'**
  String get pageIndicator3of3;

  /// No description provided for @permissionRestricted.
  ///
  /// In en, this message translates to:
  /// **'Permission status: restricted'**
  String get permissionRestricted;

  /// No description provided for @locationAccessPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is permanently denied. Please open your settings to enable it.'**
  String get locationAccessPermanentlyDenied;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @cameraAccessPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is permanently denied. Please open your settings to enable it.'**
  String get cameraAccessPermanentlyDenied;

  /// No description provided for @permissionStatus.
  ///
  /// In en, this message translates to:
  /// **'Permission Status'**
  String get permissionStatus;

  /// No description provided for @registerPresenceStartWork.
  ///
  /// In en, this message translates to:
  /// **'Register Your Presence and Start Your Work'**
  String get registerPresenceStartWork;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @noWeeklyRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No weekly records found.'**
  String get noWeeklyRecordsFound;

  /// No description provided for @locationDetected.
  ///
  /// In en, this message translates to:
  /// **'Location Detected'**
  String get locationDetected;

  /// No description provided for @youAreCurrentlyAtHome.
  ///
  /// In en, this message translates to:
  /// **'You are currently at Home.'**
  String get youAreCurrentlyAtHome;

  /// No description provided for @youAreCurrentlyAtOffice.
  ///
  /// In en, this message translates to:
  /// **'You are currently at the Office.'**
  String get youAreCurrentlyAtOffice;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Location Error'**
  String get locationError;

  /// No description provided for @unableToRetrieveLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to retrieve your location.'**
  String get unableToRetrieveLocation;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @checkInOutSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Check-in/check-out successful.'**
  String get checkInOutSuccessful;

  /// No description provided for @failedToCheckInOut.
  ///
  /// In en, this message translates to:
  /// **'Failed to check in/check out: '**
  String get failedToCheckInOut;

  /// No description provided for @workSummary.
  ///
  /// In en, this message translates to:
  /// **'Work Summary'**
  String get workSummary;

  /// No description provided for @youWorkedForHoursToday.
  ///
  /// In en, this message translates to:
  /// **'You worked for {hours} hours today.'**
  String youWorkedForHoursToday(Object hours);

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkIn;

  /// No description provided for @checkOut.
  ///
  /// In en, this message translates to:
  /// **'Check Out'**
  String get checkOut;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @offsite.
  ///
  /// In en, this message translates to:
  /// **'Offsite'**
  String get offsite;

  /// No description provided for @checkInNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Check-In Not Allowed'**
  String get checkInNotAllowed;

  /// No description provided for @checkInNotAllowedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your location is not available. please come to the office area'**
  String get checkInNotAllowedMessage;

  /// No description provided for @checkInLateNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Check-In not allowed now.'**
  String get checkInLateNotAllowed;

  /// No description provided for @biometricNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric Not Enabled'**
  String get biometricNotEnabled;

  /// No description provided for @enableBiometricFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enable biometric authentication in the settings first.'**
  String get enableBiometricFirst;

  /// No description provided for @authenticateToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to continue.'**
  String get authenticateToContinue;

  /// No description provided for @checkInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-In Success'**
  String get checkInSuccess;

  /// No description provided for @checkInSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'You have successfully checked in.'**
  String get checkInSuccessMessage;

  /// No description provided for @checkOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-Out Success'**
  String get checkOutSuccess;

  /// No description provided for @checkOutSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'You have successfully checked out.'**
  String get checkOutSuccessMessage;

  /// No description provided for @alreadyCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Already Checked In'**
  String get alreadyCheckedIn;

  /// No description provided for @alreadyCheckedInMessage.
  ///
  /// In en, this message translates to:
  /// **'You have already checked in. For check out, please wait at least 6 hours before you can do check-out'**
  String get alreadyCheckedInMessage;

  /// No description provided for @deviceIdError.
  ///
  /// In en, this message translates to:
  /// **'Device ID is missing or invalid.'**
  String get deviceIdError;

  /// No description provided for @invalidDate.
  ///
  /// In en, this message translates to:
  /// **'Invalid Date'**
  String get invalidDate;

  /// No description provided for @noTokenFound.
  ///
  /// In en, this message translates to:
  /// **'No token found. Please log in again.'**
  String get noTokenFound;

  /// No description provided for @failedToLoadWeeklyRecords.
  ///
  /// In en, this message translates to:
  /// **'Failed to load weekly records.'**
  String get failedToLoadWeeklyRecords;

  /// No description provided for @failedToLoadHistoryData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history data.'**
  String get failedToLoadHistoryData;

  /// No description provided for @youAreCurrentlyAt.
  ///
  /// In en, this message translates to:
  /// **'You are currently at {location}.'**
  String youAreCurrentlyAt(Object location);

  /// Error message with dynamic details
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithDetails(Object error);

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// Greeting message with the user's name
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String greeting(Object name);

  /// No description provided for @noBannersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No banners available'**
  String get noBannersAvailable;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT'**
  String get logoutTitle;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yesLogout.
  ///
  /// In en, this message translates to:
  /// **'Yes, Logout'**
  String get yesLogout;

  /// No description provided for @scanToSaveContact.
  ///
  /// In en, this message translates to:
  /// **'Scan to Save Contact'**
  String get scanToSaveContact;

  /// No description provided for @saveImage.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get saveImage;

  /// No description provided for @saveImageConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save this image to your gallery?'**
  String get saveImageConfirmation;

  /// No description provided for @errorSharingQRCode.
  ///
  /// In en, this message translates to:
  /// **'Error sharing QR code'**
  String get errorSharingQRCode;

  /// No description provided for @qrCodeNotRendered.
  ///
  /// In en, this message translates to:
  /// **'QR Code is not rendered yet. Please wait and try again.'**
  String get qrCodeNotRendered;

  /// No description provided for @errorDownloadingQRCode.
  ///
  /// In en, this message translates to:
  /// **'Error downloading QR code: {e}'**
  String errorDownloadingQRCode(Object e);

  /// No description provided for @errorSavingQRCode.
  ///
  /// In en, this message translates to:
  /// **'Error saving QR code: {e}'**
  String errorSavingQRCode(Object e);

  /// No description provided for @qrCodeDownloadedSuccess.
  ///
  /// In en, this message translates to:
  /// **'QR Code downloaded successfully'**
  String get qrCodeDownloadedSuccess;

  /// No description provided for @qrCodeSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'QR Code saved to gallery'**
  String get qrCodeSavedToGallery;

  /// No description provided for @errorDownloadingQRCodeGeneral.
  ///
  /// In en, this message translates to:
  /// **'Error downloading QR code. Please try again.'**
  String get errorDownloadingQRCodeGeneral;

  /// No description provided for @errorSavingQRCodeGeneral.
  ///
  /// In en, this message translates to:
  /// **'Error saving QR code. Please try again.'**
  String get errorSavingQRCodeGeneral;

  /// No description provided for @errorFetchingMembers.
  ///
  /// In en, this message translates to:
  /// **'Error fetching members: {e}'**
  String errorFetchingMembers(Object e);

  /// No description provided for @errorFetchingGroups.
  ///
  /// In en, this message translates to:
  /// **'Error fetching groups: {e}'**
  String errorFetchingGroups(Object e);

  /// No description provided for @shareQRCodeText.
  ///
  /// In en, this message translates to:
  /// **'Check out my QR code!'**
  String get shareQRCodeText;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @saveImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get saveImageTitle;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @enableBiometricAuth.
  ///
  /// In en, this message translates to:
  /// **'Enable Touch ID / Face ID'**
  String get enableBiometricAuth;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'PSBV Next Demo v1.0.15'**
  String get appVersion;

  /// No description provided for @biometricNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available.'**
  String get biometricNotAvailable;

  /// No description provided for @authenticateToEnableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to enable biometric login'**
  String get authenticateToEnableBiometrics;

  /// No description provided for @errorEnablingBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Error enabling biometrics: {e}'**
  String errorEnablingBiometrics(Object e);

  /// No description provided for @failedToLoadUserProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user profile: {reasonPhrase}'**
  String failedToLoadUserProfile(Object reasonPhrase);

  /// No description provided for @exampleNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Example Notification'**
  String get exampleNotificationTitle;

  /// No description provided for @exampleNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'This is an example notification'**
  String get exampleNotificationBody;

  /// No description provided for @officeEventAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Office Event Add Members'**
  String get officeEventAddMembers;

  /// No description provided for @failedToLoadMembers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load members'**
  String get failedToLoadMembers;

  /// No description provided for @failedToLoadGroups.
  ///
  /// In en, this message translates to:
  /// **'Failed to load groups'**
  String get failedToLoadGroups;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get addButton;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @selectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Group'**
  String get selectGroup;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @rolesLabel.
  ///
  /// In en, this message translates to:
  /// **'Roles:'**
  String get rolesLabel;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @nameAndSurname.
  ///
  /// In en, this message translates to:
  /// **'Name & Surname'**
  String get nameAndSurname;

  /// No description provided for @dateStartWork.
  ///
  /// In en, this message translates to:
  /// **'Date Start Work'**
  String get dateStartWork;

  /// No description provided for @probationEndDate.
  ///
  /// In en, this message translates to:
  /// **'Passes Probation Date'**
  String get probationEndDate;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @emails.
  ///
  /// In en, this message translates to:
  /// **'Emails'**
  String get emails;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @noRolesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No roles available'**
  String get noRolesAvailable;

  /// No description provided for @noUserProfileData.
  ///
  /// In en, this message translates to:
  /// **'No user profile data found'**
  String get noUserProfileData;

  /// No description provided for @failedToLoadRoles.
  ///
  /// In en, this message translates to:
  /// **'Failed to load roles'**
  String get failedToLoadRoles;

  /// No description provided for @invalidResponseStructure.
  ///
  /// In en, this message translates to:
  /// **'Invalid response structure received from the server.'**
  String get invalidResponseStructure;

  /// No description provided for @failedToLoadProfileData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile data.'**
  String get failedToLoadProfileData;

  /// No description provided for @failedToLoadDisplayData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load display data.'**
  String get failedToLoadDisplayData;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password.'**
  String get incorrectCredentials;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @checkInSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Your check-in has been saved and will be synced when you\'re back online.'**
  String get checkInSavedOffline;

  /// No description provided for @checkOutSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Your check-out has been saved and will be synced when you\'re back online.'**
  String get checkOutSavedOffline;

  /// No description provided for @loginErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials and try again.'**
  String get loginErrorMessage;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @roomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomLabel;

  /// No description provided for @fromDateLabel.
  ///
  /// In en, this message translates to:
  /// **'From Date'**
  String get fromDateLabel;

  /// No description provided for @toDateLabel.
  ///
  /// In en, this message translates to:
  /// **'To Date'**
  String get toDateLabel;

  /// No description provided for @pleaseSelectRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Please select a room'**
  String get pleaseSelectRoomLabel;

  /// No description provided for @employeeTelephone.
  ///
  /// In en, this message translates to:
  /// **'Employee Telephone'**
  String get employeeTelephone;

  /// No description provided for @employeeId.
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get employeeId;

  /// No description provided for @purposeLabel.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get purposeLabel;

  /// No description provided for @placeLabel.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeLabel;

  /// No description provided for @dateInLabel.
  ///
  /// In en, this message translates to:
  /// **'Date In'**
  String get dateInLabel;

  /// No description provided for @dateOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Out'**
  String get dateOutLabel;

  /// No description provided for @unknownEventType.
  ///
  /// In en, this message translates to:
  /// **'Unknown event type'**
  String get unknownEventType;

  /// No description provided for @updateLabel.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateLabel;

  /// No description provided for @editOfficeEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Office Event'**
  String get editOfficeEvent;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get locationServicesDisabled;

  /// No description provided for @pleaseEnableLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Please enable location services.'**
  String get pleaseEnableLocationServices;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @pleaseGrantLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Please grant location permission.'**
  String get pleaseGrantLocationPermission;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied permanently.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @pleaseEnableLocationPermissionFromSettings.
  ///
  /// In en, this message translates to:
  /// **'Please enable location permission from settings.'**
  String get pleaseEnableLocationPermissionFromSettings;

  /// No description provided for @carReturn.
  ///
  /// In en, this message translates to:
  /// **'Car Return'**
  String get carReturn;

  /// No description provided for @apiErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'API Error'**
  String get apiErrorTitle;

  /// No description provided for @apiErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The API is currently unavailable. Please try again later.'**
  String get apiErrorMessage;

  /// No description provided for @serverIssueMessage.
  ///
  /// In en, this message translates to:
  /// **'There is an issue with the server.'**
  String get serverIssueMessage;

  /// No description provided for @noInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'No Internet'**
  String get noInternetTitle;

  /// No description provided for @noInternetMessage.
  ///
  /// In en, this message translates to:
  /// **'You are currently offline.'**
  String get noInternetMessage;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login Successful'**
  String get loginSuccess;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okay;

  /// No description provided for @credentialsNotFound.
  ///
  /// In en, this message translates to:
  /// **'CREDENTIAL NOT FOUND'**
  String get credentialsNotFound;

  /// No description provided for @kpi.
  ///
  /// In en, this message translates to:
  /// **'KPI'**
  String get kpi;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get incorrectPassword;

  /// No description provided for @apiError.
  ///
  /// In en, this message translates to:
  /// **'API Error'**
  String get apiError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get unknownError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server Error'**
  String get serverError;

  /// No description provided for @serverErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'There was an issue connecting to the server. Please try again later.'**
  String get serverErrorMessage;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternet;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'You are currently offline. Would you like to continue in offline mode?'**
  String get offlineMessage;

  /// No description provided for @unauthorizedError.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized'**
  String get unauthorizedError;

  /// No description provided for @offlineAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'You cannot use offline mode without authorization.'**
  String get offlineAccessDenied;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @offsiteModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Offsite Mode'**
  String get offsiteModeTitle;

  /// No description provided for @offsiteModeMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re in offsite attendance mode.'**
  String get offsiteModeMessage;

  /// No description provided for @officeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Office/Home Mode'**
  String get officeModeTitle;

  /// No description provided for @officeModeMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re in office/home attendance mode.'**
  String get officeModeMessage;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'The PIN entered is incorrect.'**
  String get incorrectPin;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set your PIN'**
  String get setPin;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get enterPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get confirmPin;

  /// No description provided for @pinCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'PIN cannot be empty.'**
  String get pinCannotBeEmpty;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match.'**
  String get pinsDoNotMatch;

  /// No description provided for @pinSetSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'PIN has been set successfully.'**
  String get pinSetSuccessfully;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @tokenExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get tokenExpiredTitle;

  /// No description provided for @tokenExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get tokenExpiredMessage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'lo', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'lo': return AppLocalizationsLo();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
