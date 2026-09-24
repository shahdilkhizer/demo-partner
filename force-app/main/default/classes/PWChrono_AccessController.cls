/**
 * @description Central server-side RBAC policy for the PWChrono portal.
 *              Profile features are grants; role policies are hard ceilings.
 *              Client-side menu filtering is never treated as authorization.
 */
public inherited sharing class PWChrono_AccessController {
  public static final String ROLE_EMPLOYEE = 'Employee';
  public static final String ROLE_MANAGER = 'Manager';
  public static final String ROLE_HR_MANAGER = 'HR Manager';
  public static final String ROLE_HR_ADMIN = 'HR Admin';
  public static final String ROLE_SYSTEM_ADMIN = 'System Administrator';
  public static final String ROLE_PROJECT_MANAGER = 'Project Manager';
  public static final String ROLE_PAYROLL_ADMIN = 'Payroll Admin';

  public static final String FEATURE_ATTENDANCE_TEAM = 'Attendance Team';
  public static final String FEATURE_ATTENDANCE_ADMIN = 'Attendance Administration';
  public static final String FEATURE_EMPLOYEE_LIFECYCLE = 'Employee Lifecycle';

  public static final List<String> ALL_FEATURES = new List<String>{
    'Dashboard',
    'Leave Management',
    'Attendance Management',
    FEATURE_ATTENDANCE_TEAM,
    FEATURE_ATTENDANCE_ADMIN,
    'My Profile',
    'Admin Settings',
    'Configuration',
    'Employee Directory',
    'Expense Management',
    'Payroll',
    'Performance Management',
    'Appraisal',
    'Goals',
    'Training Management',
    'Recruitment',
    'Onboarding',
    FEATURE_EMPLOYEE_LIFECYCLE,
    'Manager Dashboard',
    'Approvals',
    'Company Policies',
    'Holidays',
    'Tax Declaration',
    'Projects'
  };

  private static final Set<String> EMPLOYEE_FEATURES = new Set<String>{
    'Dashboard',
    'Leave Management',
    'Attendance Management',
    'My Profile',
    'Expense Management',
    'Payroll',
    'Performance Management',
    'Appraisal',
    'Goals',
    'Training Management',
    'Company Policies',
    'Holidays',
    'Tax Declaration',
    'Projects'
  };

  private static final Set<String> MANAGER_FEATURES = new Set<String>{
    'Dashboard',
    'Leave Management',
    'Attendance Management',
    FEATURE_ATTENDANCE_TEAM,
    'My Profile',
    'Employee Directory',
    'Expense Management',
    'Payroll',
    'Performance Management',
    'Appraisal',
    'Goals',
    'Training Management',
    'Manager Dashboard',
    'Approvals',
    'Company Policies',
    'Holidays',
    'Tax Declaration',
    'Projects'
  };

  private static final Set<String> HR_MANAGER_FEATURES = new Set<String>{
    'Dashboard',
    'Leave Management',
    'Attendance Management',
    FEATURE_ATTENDANCE_TEAM,
    'My Profile',
    'Employee Directory',
    'Expense Management',
    'Performance Management',
    'Appraisal',
    'Goals',
    'Training Management',
    'Recruitment',
    'Onboarding',
    FEATURE_EMPLOYEE_LIFECYCLE,
    'Manager Dashboard',
    'Approvals',
    'Company Policies',
    'Holidays',
    'Tax Declaration',
    'Projects',
    'Reports Dashboard'
  };

  public class AccessContext {
    public Id portalUserId;
    public String role;
    public Id profileId;
    public String profileType;
    public Boolean canApprove;
    public String approvalScope;
    public String department;
    public Boolean isPlatformAdministrator;
    public List<String> features = new List<String>();
  }

  public static Boolean isSalesforceInternalUser() {
    String userType = UserInfo.getUserType();
    return userType == 'Standard' || userType == 'AdminUser';
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getUserAccess() {
    return getUserAccessImpl(null);
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getUserAccessById(
    Id employeeId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      if (employeeId == null) {
        return deniedAccess('Guest', false);
      }
      return PWChrono_GuestSession.getVerifiedUserAccess(
        (String) employeeId,
        sessionToken
      );
    }
    return getUserAccessImpl(employeeId);
  }

  /** Returns role-capped access after another boundary verified identity. */
  public static Map<String, Object> getVerifiedPortalUserAccess(Id employeeId) {
    AccessContext context = getAccessContext(employeeId);
    return toAccessMap(context, false);
  }

  public static Boolean isAdmin(Id employeeId) {
    return isAdminContext(getAccessContext(employeeId));
  }

  public static Boolean isManager(Id employeeId) {
    return isManagerRole(getAccessContext(employeeId).role);
  }

  public static Boolean canManageProjects(Id employeeId) {
    AccessContext context = getAccessContext(employeeId);
    return isAdminContext(context) || context.role == ROLE_PROJECT_MANAGER;
  }

  public static Boolean hasFeature(Id employeeId, String featureName) {
    if (String.isBlank(featureName)) {
      return false;
    }
    return getAccessContext(employeeId).features.contains(featureName);
  }

  public static void requireFeature(Id employeeId, String featureName) {
    if (!hasFeature(employeeId, featureName)) {
      throw handledException(
        'Access denied: ' + featureName + ' access is required.'
      );
    }
  }

  /**
   * @description Returns active employees visible to the actor. Admins see all;
   *              managers are constrained by approval scope; employees see self.
   */
  public static Set<Id> getVisibleEmployeeIds(Id actorEmployeeId) {
    AccessContext context = getAccessContext(actorEmployeeId);
    Set<Id> ids = new Set<Id>();
    if (context.portalUserId == null) {
      return ids;
    }

    if (isAdminContext(context) || context.approvalScope == 'All Employees') {
      for (Portal_Users__c employee : [
        SELECT Id
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
      ]) {
        ids.add(employee.Id);
      }
      return ids;
    }

    ids.add(context.portalUserId);
    if (!isManagerRole(context.role)) {
      return ids;
    }

    if (
      context.approvalScope == 'Department' &&
      String.isNotBlank(context.department)
    ) {
      for (Portal_Users__c employee : [
        SELECT Id
        FROM Portal_Users__c
        WHERE
          Is_Active__c = TRUE
          AND (Department__c = :context.department
          OR Contact__r.Department = :context.department)
      ]) {
        ids.add(employee.Id);
      }
      return ids;
    }

    for (Portal_Users__c employee : [
      SELECT Id
      FROM Portal_Users__c
      WHERE Is_Active__c = TRUE AND Reports_To__c = :context.portalUserId
    ]) {
      ids.add(employee.Id);
    }
    return ids;
  }

  public static Boolean canViewEmployee(
    Id actorEmployeeId,
    Id targetEmployeeId
  ) {
    if (actorEmployeeId == null || targetEmployeeId == null) {
      return false;
    }
    return getVisibleEmployeeIds(actorEmployeeId).contains(targetEmployeeId);
  }

  public static Boolean canApproveForEmployee(
    Id actorEmployeeId,
    Id targetEmployeeId,
    Id assignedApproverId
  ) {
    if (actorEmployeeId == null || actorEmployeeId == targetEmployeeId) {
      return false;
    }
    AccessContext context = getAccessContext(actorEmployeeId);
    if (isAdminContext(context)) {
      return true;
    }
    if (!context.canApprove || !isManagerRole(context.role)) {
      return false;
    }
    return assignedApproverId == actorEmployeeId ||
      getVisibleEmployeeIds(actorEmployeeId).contains(targetEmployeeId);
  }

  private static Map<String, Object> getUserAccessImpl(Id employeeId) {
    return getUserAccessImpl(employeeId, UserInfo.getUserType());
  }

  @TestVisible
  private static Map<String, Object> getUserAccessImpl(
    Id employeeId,
    String effectiveUserType
  ) {
    try {
      Boolean internalUser =
        effectiveUserType == 'Standard' ||
        effectiveUserType == 'AdminUser';
      Boolean platformAdmin = internalUser && isPlatformAdministrator();

      Portal_Users__c portalUser;
      if (employeeId != null && (!internalUser || platformAdmin)) {
        portalUser = findPortalUserById(employeeId);
      }
      if (portalUser == null && internalUser) {
        portalUser = findPortalUserBySalesforceUser(UserInfo.getUserId());
      }
      if (portalUser == null && employeeId != null && !internalUser) {
        portalUser = findPortalUserById(employeeId);
      }

      if (portalUser != null) {
        return toAccessMap(
          buildContext(portalUser, platformAdmin),
          platformAdmin
        );
      }
      if (platformAdmin) {
        AccessContext administrator = new AccessContext();
        administrator.role = ROLE_SYSTEM_ADMIN;
        administrator.profileType = ROLE_SYSTEM_ADMIN;
        administrator.isPlatformAdministrator = true;
        administrator.canApprove = true;
        administrator.approvalScope = 'All Employees';
        administrator.features = new List<String>(ALL_FEATURES);
        return toAccessMap(administrator, true);
      }
      return deniedAccess(effectiveUserType == 'Guest' ? 'Guest' : null, false);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error resolving PWChrono access', e);
      throw handledException('Error fetching user access. Please try again.');
    }
  }

  private static AccessContext getAccessContext(Id employeeId) {
    if (employeeId != null) {
      Portal_Users__c portalUser = findPortalUserById(employeeId);
      if (portalUser != null) {
        // An explicit portal identity is always evaluated using that employee's
        // role. This prevents a system administrator's execution context from
        // silently elevating an employee/manager passed into a service method.
        return buildContext(portalUser, false);
      }
    }

    if (isSalesforceInternalUser()) {
      Portal_Users__c linkedUser = findPortalUserBySalesforceUser(
        UserInfo.getUserId()
      );
      if (linkedUser != null) {
        return buildContext(linkedUser, isPlatformAdministrator());
      }
      if (isPlatformAdministrator()) {
        AccessContext administrator = new AccessContext();
        administrator.role = ROLE_SYSTEM_ADMIN;
        administrator.profileType = ROLE_SYSTEM_ADMIN;
        administrator.isPlatformAdministrator = true;
        administrator.canApprove = true;
        administrator.approvalScope = 'All Employees';
        administrator.features = new List<String>(ALL_FEATURES);
        return administrator;
      }
    }
    return new AccessContext();
  }

  private static Portal_Users__c findPortalUserById(Id employeeId) {
    List<Portal_Users__c> users = [
      SELECT
        Id,
        Role__c,
        Department__c,
        Contact__r.Department,
        Portal_User_Profile__c,
        Portal_User_Profile__r.Profile_Type__c,
        Portal_User_Profile__r.Can_Approve__c,
        Portal_User_Profile__r.Approval_Scope__c,
        Portal_User_Profile__r.Is_Active__c,
        Portal_User_Profile__r.Is_Locked__c
      FROM Portal_Users__c
      WHERE Id = :employeeId AND Is_Active__c = TRUE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0];
  }

  private static Portal_Users__c findPortalUserBySalesforceUser(
    Id salesforceUserId
  ) {
    List<Portal_Users__c> users = [
      SELECT
        Id,
        Role__c,
        Department__c,
        Contact__r.Department,
        Portal_User_Profile__c,
        Portal_User_Profile__r.Profile_Type__c,
        Portal_User_Profile__r.Can_Approve__c,
        Portal_User_Profile__r.Approval_Scope__c,
        Portal_User_Profile__r.Is_Active__c,
        Portal_User_Profile__r.Is_Locked__c
      FROM Portal_Users__c
      WHERE User__c = :salesforceUserId AND Is_Active__c = TRUE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0];
  }

  private static AccessContext buildContext(
    Portal_Users__c portalUser,
    Boolean platformAdmin
  ) {
    AccessContext context = new AccessContext();
    context.portalUserId = portalUser.Id;
    context.profileId = portalUser.Portal_User_Profile__c;
    context.profileType = portalUser.Portal_User_Profile__r?.Profile_Type__c;
    context.role = normalizeRole(portalUser.Role__c, context.profileType);
    context.department = String.isNotBlank(portalUser.Department__c)
      ? portalUser.Department__c
      : portalUser.Contact__r?.Department;
    context.isPlatformAdministrator = platformAdmin;
    context.approvalScope = resolveApprovalScope(portalUser, context.role);
    context.canApprove =
      isAdminRole(context.role) ||
      isManagerRole(context.role) ||
      portalUser.Portal_User_Profile__r?.Can_Approve__c == true;
    context.features = getEffectiveFeatures(
      context.profileId,
      context.role,
      portalUser.Portal_User_Profile__r?.Is_Active__c,
      portalUser.Portal_User_Profile__r?.Is_Locked__c
    );
    return context;
  }

  private static String normalizeRole(String userRole, String profileType) {
    if (profileType == ROLE_HR_MANAGER || profileType == ROLE_SYSTEM_ADMIN) {
      return profileType;
    }
    if (String.isNotBlank(userRole)) {
      return userRole;
    }
    return String.isNotBlank(profileType) ? profileType : ROLE_EMPLOYEE;
  }

  private static String resolveApprovalScope(
    Portal_Users__c portalUser,
    String role
  ) {
    if (isAdminRole(role)) {
      return 'All Employees';
    }
    String configuredScope = portalUser.Portal_User_Profile__r
      ?.Approval_Scope__c;
    if (role == ROLE_HR_MANAGER) {
      return configuredScope == 'All Employees'
        ? 'Department'
        : (String.isBlank(configuredScope) || configuredScope == 'None'
            ? 'Department'
            : configuredScope);
    }
    if (role == ROLE_MANAGER || role == ROLE_PROJECT_MANAGER) {
      return configuredScope == 'Department' ? 'Department' : 'Direct Reports';
    }
    return 'None';
  }

  private static List<String> getEffectiveFeatures(
    Id profileId,
    String role,
    Boolean profileActive,
    Boolean profileLocked
  ) {
    if (isAdminRole(role)) {
      return new List<String>(ALL_FEATURES);
    }
    if (profileId == null || profileActive == false || profileLocked == true) {
      return new List<String>();
    }

    Set<String> ceiling = getRoleFeatureCeiling(role);
    Set<String> configured = new Set<String>(getFeaturesForProfile(profileId));
    List<String> effective = new List<String>();
    for (String feature : ALL_FEATURES) {
      if (configured.contains(feature) && ceiling.contains(feature)) {
        effective.add(feature);
      }
    }
    if (ceiling.contains('Dashboard') && !effective.contains('Dashboard')) {
      effective.add('Dashboard');
    }
    if (ceiling.contains('My Profile') && !effective.contains('My Profile')) {
      effective.add('My Profile');
    }
    if (
      effective.contains('Attendance Management') &&
      ceiling.contains(FEATURE_ATTENDANCE_TEAM)
    ) {
      effective.add(FEATURE_ATTENDANCE_TEAM);
    }
    return effective;
  }

  @TestVisible
  private static Set<String> getRoleFeatureCeiling(String role) {
    if (role == ROLE_HR_MANAGER) {
      return new Set<String>(HR_MANAGER_FEATURES);
    }
    if (role == ROLE_MANAGER || role == ROLE_PROJECT_MANAGER) {
      return new Set<String>(MANAGER_FEATURES);
    }
    if (role == ROLE_PAYROLL_ADMIN) {
      return new Set<String>(EMPLOYEE_FEATURES);
    }
    return new Set<String>(EMPLOYEE_FEATURES);
  }

  private static List<String> getFeaturesForProfile(Id profileId) {
    List<String> features = new List<String>();
    if (profileId == null) {
      return features;
    }
    for (Portal_Profile_Feature__c assignment : [
      SELECT Feature_Key__c
      FROM Portal_Profile_Feature__c
      WHERE Portal_User_Profile__c = :profileId AND Is_Enabled__c = TRUE
      ORDER BY Feature_Key__c
    ]) {
      if (String.isNotBlank(assignment.Feature_Key__c)) {
        features.add(assignment.Feature_Key__c);
      }
    }
    return features;
  }

  private static Boolean isAdminContext(AccessContext context) {
    return context != null &&
      (context.isPlatformAdministrator == true || isAdminRole(context.role));
  }

  private static Boolean isAdminRole(String role) {
    return role == ROLE_HR_ADMIN ||
      role == ROLE_SYSTEM_ADMIN ||
      role == 'System Admin';
  }

  private static Boolean isManagerRole(String role) {
    return role == ROLE_MANAGER ||
      role == ROLE_HR_MANAGER ||
      role == ROLE_PROJECT_MANAGER;
  }

  private static Boolean isPlatformAdministrator() {
    List<Profile> profiles = [
      SELECT PermissionsModifyAllData
      FROM Profile
      WHERE Id = :UserInfo.getProfileId()
      LIMIT 1
    ];
    return !profiles.isEmpty() && profiles[0].PermissionsModifyAllData;
  }

  private static Map<String, Object> toAccessMap(
    AccessContext context,
    Boolean isSalesforceAdministrator
  ) {
    Boolean hasAccess = context != null && !context.features.isEmpty();
    return new Map<String, Object>{
      'hasAccess' => hasAccess,
      'role' => context?.role,
      'profileType' => context?.profileType,
      'features' => context == null ? new List<String>() : context.features,
      'canApprove' => context?.canApprove == true,
      'approvalScope' => context?.approvalScope,
      'isAdmin' => isAdminContext(context),
      'isSalesforceUser' => isSalesforceAdministrator
    };
  }

  private static Map<String, Object> deniedAccess(
    String role,
    Boolean isSalesforceUser
  ) {
    return new Map<String, Object>{
      'hasAccess' => false,
      'role' => role,
      'features' => new List<String>(),
      'canApprove' => false,
      'approvalScope' => 'None',
      'isAdmin' => false,
      'isSalesforceUser' => isSalesforceUser
    };
  }

  private static AuraHandledException handledException(String message) {
    AuraHandledException accessException = new AuraHandledException(message);
    accessException.setMessage(message);
    return accessException;
  }
}