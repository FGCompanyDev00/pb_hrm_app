class UserRole {
  static const String john = 'john';
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
  static const String managersbh = 'managersbh';
  static const String adminsb1 = 'adminsb1';
  static const String adminsb2 = 'adminsb2';
  static const String husersbh1 = 'husersbh1';
  static const String usersbh1 = 'usersbh1';
  static const String usersbh2 = 'usersbh2';
  static const String managerkt = 'managerkt';
  static const String adminkt1 = 'adminkt1';
  static const String adminkt2 = 'adminkt2';
  static const String huserkt1 = 'huserkt1';
  static const String userkt1 = 'userkt1';
  static const String userkt2 = 'userkt2';

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
}
