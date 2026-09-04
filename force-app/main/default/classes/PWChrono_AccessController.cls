public inherited sharing class PWChrono_AccessController {
  /**
   * @description All available features in the PWChrono Portal.
   *              Salesforce internal users get access to ALL these features.
   */
  public static final List<String> ALL_FEATURES = new List<String>{
    'Dashboard',
    'Leave Management',
    'Attendance Management',
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
    'Manager Dashboard',
    'Approvals',
    'Company Policies',
    'Holidays',
    'Tax Declaration',
    'Projects',
    'Reports Dashboard'
  };

  /**
   * @description Check if the current user is a Salesforce internal user (not Guest, not Portal user logging via OTP)
   * @return true if this is a Salesforce internal user with full access
   */
  public static Boolean isSalesforceInternalUser() {
    String userType = UserInfo.getUserType();
    // Standard = regular Salesforce user, AdminUser = system admin
    // PowerPartner/PowerCustomerSuccess/CSPLitePortal/CustomerSuccess = portal/community users
    // Guest = unauthenticated guest
    return userType == 'Standard' || userType == 'AdminUser';
  }

  /**
   * @description Get access details for the current user (no parameter version)
   * @return Map containing role and accessible features
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getUserAccess() {
    return getUserAccessImpl(null);
  }

  /**
   * @description Get access details for a specific employee/portal user
   * @param employeeId The Portal_Users__c record ID
   * @return Map containing role and accessible features
   */
  // Profile assignments are administrator-managed runtime data. Do not let the
  // Lightning client reuse a stale authorization response after they change.
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getUserAccessById(
    Id employeeId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      if (employeeId != null) {
        return PWChrono_GuestSession.getVerifiedUserAccess(
          (String) employeeId,
          sessionToken
        );
      }
      // Allow null employeeId for the pre-login flow.
      return getUserAccessImpl(null);
    }

    return getUserAccessImpl(employeeId);
  }

  /**
   * @description Check if the given employee has Admin feature access
   * @param employeeId The Portal_Users__c record ID
   * @return true if the user is an HR Admin or System Admin
   */
  public static Boolean isAdmin(Id employeeId) {
    if (isSalesforceInternalUser()) {
      return true;
    }

    if (employeeId == null) {
      return false;
    }

    List<Portal_Users__c> users = [
      SELECT Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    if (users.isEmpty()) {
      return false;
    }

    for (
      String feature : getFeaturesForProfile(users[0].Portal_User_Profile__c)
    ) {
      if (feature == 'Admin Settings' || feature == 'Admin') {
        return true;
      }
    }
    return false;
  }

  /**
   * @description Internal implementation for getUserAccess
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return Map containing role and accessible features
   */
  private static Map<String, Object> getUserAccessImpl(Id employeeId) {
    return getUserAccessImpl(employeeId, UserInfo.getUserType());
  }

  @TestVisible
  private static Map<String, Object> getUserAccessImpl(
    Id employeeId,
    String effectiveUserType
  ) {
    try {
      Id userId = UserInfo.getUserId();
      String userType = effectiveUserType;

      // SALESFORCE INTERNAL USERS: Grant FULL ACCESS to all features
      // This allows Salesforce users to use the portal without any permission restrictions
      if (userType == 'Standard' || userType == 'AdminUser') {
        return new Map<String, Object>{
          'hasAccess' => true,
          'role' => 'Salesforce User',
          'features' => ALL_FEATURES,
          'isSalesforceUser' => true
        };
      }

      // GUEST USERS: For Portal Users accessing via Experience Cloud
      // Guest users are the portal users - they access via OTP login
      // Since the portal uses sessionStorage and custom permission system,
      // Guest users with a valid employeeId should get full access to features
      // based on their Portal_User_Profile__c settings
      if (userType == 'Guest') {
        // If employeeId is provided (from client session), use it to get access
        if (employeeId != null) {
          List<Portal_Users__c> users = [
            SELECT Id, Role__c, Portal_User_Profile__c
            FROM Portal_Users__c
            WHERE Id = :employeeId AND Is_Active__c = TRUE
            LIMIT 1
          ];
          if (!users.isEmpty()) {
            Portal_Users__c portalUser = users[0];
            List<String> features = new List<String>();

            features = getFeaturesForProfile(portalUser.Portal_User_Profile__c);

            return new Map<String, Object>{
              'hasAccess' => true,
              'role' => portalUser.Role__c,
              'features' => features,
              'isSalesforceUser' => false
            };
          }
        }

        // No valid employeeId provided - allow basic access for login flow
        // The login component and auth flow need to work for unauthenticated guests
        return new Map<String, Object>{
          'hasAccess' => true,
          'role' => 'Guest',
          'features' => new List<String>{ 'Dashboard', 'My Profile' },
          'isSalesforceUser' => false
        };
      }

      // PORTAL USERS: Enforce permission-based access
      Id portalUserId;
      String userRole;
      Id profileId;

      // If employeeId is provided, use it directly
      if (employeeId != null) {
        List<Portal_Users__c> users = [
          SELECT Id, Role__c, Portal_User_Profile__c
          FROM Portal_Users__c
          WHERE Id = :employeeId
          LIMIT 1
        ];
        if (!users.isEmpty()) {
          portalUserId = users[0].Id;
          userRole = users[0].Role__c;
          profileId = users[0].Portal_User_Profile__c;
        }
      } else {
        // Look up Portal_Users__c record linked to current Salesforce user
        List<Portal_Users__c> users = [
          SELECT Id, Role__c, Portal_User_Profile__c
          FROM Portal_Users__c
          WHERE User__c = :userId
          LIMIT 1
        ];
        if (!users.isEmpty()) {
          portalUserId = users[0].Id;
          userRole = users[0].Role__c;
          profileId = users[0].Portal_User_Profile__c;
        }
      }

      if (portalUserId == null || profileId == null) {
        return new Map<String, Object>{
          'hasAccess' => false,
          'role' => null,
          'features' => new List<String>(),
          'isSalesforceUser' => false
        };
      }

      List<String> features = new List<String>();

      features = getFeaturesForProfile(profileId);

      return new Map<String, Object>{
        'hasAccess' => !features.isEmpty(),
        'role' => userRole,
        'features' => features,
        'isSalesforceUser' => false
      };
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching user access: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching user access: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Resolves enabled component features from the user's assigned profile.
   */
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
}