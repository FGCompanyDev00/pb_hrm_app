
class UserRole {
  static const String lineManager = 'Line manager';
  static const String hr = 'HR';
  static const String headOfHR = 'HeadOfHR';
  static const String meetingAdmin = 'MeetingAdmin';
  static const String carPermitAdmin = 'CarPermitAdmin';
  static const String carReturnAdmin = 'CarReturnAdmin';
  static const String branchManager = 'Branch manager';
  static const String adminBR = 'AdminBR';
  static const String adminHQ = 'AdminHQ';
  static const String checker = 'Checker';

  static const Map<String, List<String>> permissions = {
    lineManager: ['leaveApproval'],
    hr: ['leaveApproval', 'inventoryRequestHQ'],
    headOfHR: ['leaveApproval', 'inventoryRequestHQ'],
    meetingAdmin: ['meetingRoomReserve'],
    carPermitAdmin: ['carReserve'],
    carReturnAdmin: ['carReturn'],
    branchManager: ['inventoryRequestBranch', 'inventoryRequestBranchToHQ'],
    adminBR: ['inventoryRequestBranch', 'inventoryRequestBranchToHQ'],
    adminHQ: ['inventoryRequestHQ'],
    checker: []
  };
}
