// // class UserRole {
// //   static const String john = 'john';
// //   static const String committeehq1 = 'committeehq1';
// //   static const String committeehq2 = 'committeehq2';
// //   static const String committeehq3 = 'committeehq3';
// //   static const String adminhq1 = 'adminhq1';
// //   static const String adminhq2 = 'adminhq2';
// //   static const String huserhq = 'huserhq';
// //   static const String userhq1 = 'userhq1';
// //   static const String userhq2 = 'userhq2';
// //   static const String managersst = 'managersst';
// //   static const String adminsst1 = 'adminsst1';
// //   static const String adminsst2 = 'adminsst2';
// //   static const String husersst1 = 'husersst1';
// //   static const String usersst1 = 'usersst1';
// //   static const String usersst2 = 'usersst2';
// //   static const String managersbh = 'managersbh';
// //   static const String adminsb1 = 'adminsb1';
// //   static const String adminsb2 = 'adminsb2';
// //   static const String husersbh1 = 'husersbh1';
// //   static const String usersbh1 = 'usersbh1';
// //   static const String usersbh2 = 'usersbh2';
// //   static const String managerkt = 'managerkt';
// //   static const String adminkt1 = 'adminkt1';
// //   static const String adminkt2 = 'adminkt2';
// //   static const String huserkt1 = 'huserkt1';
// //   static const String userkt1 = 'userkt1';
// //   static const String userkt2 = 'userkt2';

// //   static const Map<String, List<String>> permissions = {
// //     john: ['allAccess'],
// //     committeehq1: ['committeeAccess'],
// //     committeehq2: ['committeeAccess'],
// //     committeehq3: ['committeeAccess'],
// //     adminhq1: ['adminHQAccess'],
// //     adminhq2: ['adminHQAccess'],
// //     huserhq: ['huserHQAccess'],
// //     userhq1: ['userHQAccess'],
// //     userhq2: ['userHQAccess'],
// //     managersst: ['managerSSTAccess'],
// //     adminsst1: ['adminSSTAccess'],
// //     adminsst2: ['adminSSTAccess'],
// //     husersst1: ['huserSSTAccess'],
// //     usersst1: ['userSSTAccess'],
// //     usersst2: ['userSSTAccess'],
// //     managersbh: ['managerBHAccess'],
// //     adminsb1: ['adminBHAccess'],
// //     adminsb2: ['adminBHAccess'],
// //     husersbh1: ['huserBHAccess'],
// //     usersbh1: ['userBHAccess'],
// //     usersbh2: ['userBHAccess'],
// //     managerkt: ['managerKTAccess'],
// //     adminkt1: ['adminKTAccess'],
// //     adminkt2: ['adminKTAccess'],
// //     huserkt1: ['huserKTAccess'],
// //     userkt1: ['userKTAccess'],
// //     userkt2: ['userKTAccess'],
// //   };
// // }

// class UserRole {
//   static const String john = 'john';
//   static const String committeehq1 = 'committeehq1';
//   static const String committeehq2 = 'committeehq2';
//   static const String committeehq3 = 'committeehq3';
//   static const String adminhq1 = 'adminhq1';
//   static const String adminhq2 = 'adminhq2';
//   static const String huserhq = 'huserhq';
//   static const String userhq1 = 'userhq1';
//   static const String userhq2 = 'userhq2';
//   static const String managersst = 'managersst';
//   static const String adminsst1 = 'adminsst1';
//   static const String adminsst2 = 'adminsst2';
//   static const String husersst1 = 'husersst1';
//   static const String usersst1 = 'usersst1';
//   static const String usersst2 = 'usersst2';
//   static const String managersbh = 'managersbh';
//   static const String adminsb1 = 'adminsb1';
//   static const String adminsb2 = 'adminsb2';
//   static const String husersbh1 = 'husersbh1';
//   static const String usersbh1 = 'usersbh1';
//   static const String usersbh2 = 'usersbh2';
//   static const String managerkt = 'managerkt';
//   static const String adminkt1 = 'adminkt1';
//   static const String adminkt2 = 'adminkt2';
//   static const String huserkt1 = 'huserkt1';
//   static const String userkt1 = 'userkt1';
//   static const String userkt2 = 'userkt2';

//   // Permissions map
//   static const Map<String, List<String>> permissions = {
//     john: ['allAccess'],
//     committeehq1: ['committeeAccess'],
//     committeehq2: ['committeeAccess'],
//     committeehq3: ['committeeAccess'],
//     adminhq1: ['adminHQAccess'],
//     adminhq2: ['adminHQAccess'],
//     huserhq: ['huserHQAccess'],
//     userhq1: ['userHQAccess'],
//     userhq2: ['userHQAccess'],
//     managersst: ['managerSSTAccess'],
//     adminsst1: ['adminSSTAccess'],
//     adminsst2: ['adminSSTAccess'],
//     husersst1: ['huserSSTAccess'],
//     usersst1: ['userSSTAccess'],
//     usersst2: ['userSSTAccess'],
//     managersbh: ['managerBHAccess'],
//     adminsb1: ['adminBHAccess'],
//     adminsb2: ['adminBHAccess'],
//     husersbh1: ['huserBHAccess'],
//     usersbh1: ['userBHAccess'],
//     usersbh2: ['userBHAccess'],
//     managerkt: ['managerKTAccess'],
//     adminkt1: ['adminKTAccess'],
//     adminkt2: ['adminKTAccess'],
//     huserkt1: ['huserKTAccess'],
//     userkt1: ['userKTAccess'],
//     userkt2: ['userKTAccess'],
//   };

//   // A method to get permissions for a given role
//   static List<String> getPermissions(String role) {
//     return permissions[role] ?? [];
//   }
// }

class UserRole {
  // Define the roles as constants
  static const String john = 'john';
  static const String managersbh = 'managersbh';
  static const String managerkt = 'managerkt';
  static const String committeehq1 = 'committeehq1';
  static const String committeehq2 = 'committeehq2';
  static const String committeehq3 = 'committeehq3';
  static const String adminhq1 = 'adminhq1';
  static const String adminhq2 = 'adminhq2';
  static const String huserhq = 'huserhq';
  static const String userhq1 = 'userhq1';
  static const String userhq2 = 'userhq2';
  static const String managersst = 'managersst';
  static const String adminsst1 = 'adminsst1';
  static const String adminsst2 = 'adminsst2';
  static const String husersst1 = 'husersst1';
  static const String usersst1 = 'usersst1';
  static const String usersst2 = 'usersst2';
  static const String adminsb1 = 'adminsb1';
  static const String adminsb2 = 'adminsb2';
  static const String husersbh1 = 'husersbh1';
  static const String usersbh1 = 'usersbh1';
  static const String usersbh2 = 'usersbh2';
  static const String adminkt1 = 'adminkt1';
  static const String adminkt2 = 'adminkt2';
  static const String huserkt1 = 'huserkt1';
  static const String userkt1 = 'userkt1';
  static const String userkt2 = 'userkt2';

  // Mapping API roles to internal roles
  static const Map<String, String> roleMapping = {
    'HR': managersbh,
    'AdminHQ': john,
    'Committee': committeehq1,
    'HeadOfHR': adminhq1,
    'Procurement': 'procurementRole', 
    'OfficeAdmin': 'officeAdminRole', 
    'Checker': 'checkerRole', 
    'SuperAdmin': 'superAdminRole', 
    'MobileAdmin': 'mobileAdminRole', 
    'user':usersst1,
    // Add more mappings as needed
  };

  // Permissions map
  static const Map<String, List<String>> permissions = {
    john: ['allAccess'],
    committeehq1: ['committeeAccess'],
    committeehq2: ['committeeAccess'],
    committeehq3: ['committeeAccess'],
    adminhq1: ['adminHQAccess'],
    adminhq2: ['adminHQAccess'],
    huserhq: ['huserHQAccess'],
    userhq1: ['userHQAccess'],
    userhq2: ['userHQAccess'],
    managersst: ['managerSSTAccess'],
    adminsst1: ['adminSSTAccess'],
    adminsst2: ['adminSSTAccess'],
    husersst1: ['huserSSTAccess'],
    usersst1: ['userSSTAccess'],
    usersst2: ['userSSTAccess'],
    managersbh: ['managerBHAccess'],
    adminsb1: ['adminBHAccess'],
    adminsb2: ['adminBHAccess'],
    husersbh1: ['huserBHAccess'],
    usersbh1: ['userBHAccess'],
    usersbh2: ['userBHAccess'],
    managerkt: ['managerKTAccess'],
    adminkt1: ['adminKTAccess'],
    adminkt2: ['adminKTAccess'],
    huserkt1: ['huserKTAccess'],
    userkt1: ['userKTAccess'],
    userkt2: ['userKTAccess'],
  };

  // Method to map API roles to internal roles
  static String mapApiRole(String apiRole) {
    return roleMapping[apiRole] ?? apiRole;
  }

  // Method to get permissions for a given role
  static List<String> getPermissions(String role) {
    return permissions[role] ?? [];
  }
}

class User {
  String id;
  String name;
  List<String> roles;

  // Constructor maps API roles to internal roles automatically
  User({required this.id, required this.name, required List<String> roles})
      : roles = roles.map((role) => UserRole.mapApiRole(role)).toList();

  // Method to check if the user has a specific role
  bool hasRole(String role) {
    return roles.contains(role);
  }

  // Method to check if the user has a specific permission
  bool hasPermission(String permission) {
    for (String role in roles) {
      if (UserRole.getPermissions(role).contains(permission)) {
        return true;
      }
    }
    return false;
  }
}

