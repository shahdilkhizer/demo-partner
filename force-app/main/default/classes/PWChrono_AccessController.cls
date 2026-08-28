public inherited sharing class PWChrono_AccessController {
  /**
   * @description All available features in the PWChrono Portal.
   *              Salesforce internal users get access to ALL these features.
   */
  private static final List<String> ALL_FEATURES = new List<String>{
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
    'Tax Declaration'
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
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getUserAccess() {
    return getUserAccessImpl(null);
  }

  /**
   * @description Get access details for a specific employee/portal user
   * @param employeeId The Portal_Users__c record ID
   * @return Map containing role and accessible features
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getUserAccessById(
    Id employeeId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      if (employeeId != null) {
        Id verifiedPortalUserId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          (String) employeeId,
          sessionToken
        );
        return getUserAccessImpl(verifiedPortalUserId);
      }
      // Allow null employeeId for the pre-login flow.
      return getUserAccessImpl(null);
    }

    return getUserAccessImpl(employeeId);
  }

  /**
   * @description Check if the given employee has Admin privileges
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
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    if (users.isEmpty()) {
      return false;
    }

    return users[0].Role__c == 'HR Admin' || users[0].Role__c == 'System Admin';
  }

  /**
   * @description Internal implementation for getUserAccess
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return Map containing role and accessible features
   */
  private static Map<String, Object> getUserAccessImpl(Id employeeId) {
    try {
      Id userId = UserInfo.getUserId();
      String userType = UserInfo.getUserType();

      // SALESFORCE INTERNAL USERS: Grant FULL ACCESS to all features
      // This allows Salesforce users to use the portal without any permission restrictions
      if (isSalesforceInternalUser()) {
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

            // Get features from User Feature Access or Role mapping
            List<PWChrono_User_Feature_Access__c> accessRecords = [
              SELECT Feature_Name__c
              FROM PWChrono_User_Feature_Access__c
              WHERE
                Portal_User__c = :portalUser.Id
                AND Is_Active__c = TRUE
                AND Access_Level__c != 'No Access'
            ];

            if (!accessRecords.isEmpty()) {
              for (PWChrono_User_Feature_Access__c access : accessRecords) {
                features.add(access.Feature_Name__c);
              }
            } else if (portalUser.Role__c != null) {
              features = getFeaturesForRole(portalUser.Role__c);
            }

            // If no specific features configured, give basic access
            if (features.isEmpty()) {
              features = new List<String>{
                'Dashboard',
                'My Profile',
                'Leave Management',
                'Attendance Management'
              };
            }

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

      // If employeeId is provided, use it directly
      if (employeeId != null) {
        List<Portal_Users__c> users = [
          SELECT Id, Role__c
          FROM Portal_Users__c
          WHERE Id = :employeeId
          LIMIT 1
        ];
        if (!users.isEmpty()) {
          portalUserId = users[0].Id;
          userRole = users[0].Role__c;
        }
      } else {
        // Look up Portal_Users__c record linked to current Salesforce user
        List<Portal_Users__c> users = [
          SELECT Id, Role__c
          FROM Portal_Users__c
          WHERE User__c = :userId
          LIMIT 1
        ];
        if (!users.isEmpty()) {
          portalUserId = users[0].Id;
          userRole = users[0].Role__c;
        }
      }

      if (portalUserId == null || userRole == null) {
        return new Map<String, Object>{
          'hasAccess' => false,
          'role' => null,
          'features' => new List<String>(),
          'isSalesforceUser' => false
        };
      }

      List<String> features = new List<String>();

      // 1. Check for User-Specific Feature Access
      List<PWChrono_User_Feature_Access__c> accessRecords = [
        SELECT Feature_Name__c
        FROM PWChrono_User_Feature_Access__c
        WHERE
          Portal_User__c = :portalUserId
          AND Is_Active__c = TRUE
          AND Access_Level__c != 'No Access'
      ];

      if (!accessRecords.isEmpty()) {
        for (PWChrono_User_Feature_Access__c access : accessRecords) {
          features.add(access.Feature_Name__c);
        }
      } else {
        // 2. Fallback to Role-based defaults if no specific config exists
        features = getFeaturesForRole(userRole);
      }

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
   * @description Get features for a given role from Custom Metadata
   * @param roleName The role name
   * @return List of feature names
   */
  private static List<String> getFeaturesForRole(String roleName) {
    Set<String> features = new Set<String>();
    List<PWChrono_Role_Feature_Mapping__mdt> mappings;

    if (roleName == PWChrono_Constants.ROLE_HR_ADMIN) {
      // HR Admins get all features
      mappings = [SELECT Feature__c FROM PWChrono_Role_Feature_Mapping__mdt];
    } else {
      mappings = [
        SELECT Feature__c
        FROM PWChrono_Role_Feature_Mapping__mdt
        WHERE Role__c = :roleName
      ];
    }

    for (PWChrono_Role_Feature_Mapping__mdt mapping : mappings) {
      features.add(mapping.Feature__c);
    }

    return new List<String>(features);
  }
}