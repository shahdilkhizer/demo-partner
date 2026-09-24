/**
 * @description Profile feature catalog and assignment services for the Portal User Profile Manager.
 */
public inherited sharing class PWChrono_ProfileManagerController {
  public class FeatureOption {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Boolean enabled;
  }

  private static void requireAdminSettingsAccessForGuest(
    String callerPortalUserId,
    String sessionToken
  ) {
    Id actorEmployeeId = UserInfo.getUserType() == 'Guest'
      ? PWChrono_GuestSession.requireVerifiedPortalUserId(
          callerPortalUserId,
          sessionToken
        )
      : (String.isBlank(callerPortalUserId)
          ? null
          : PWChrono_RequestValidator.resolveEmployeeId(
              callerPortalUserId,
              sessionToken
            ));
    PWChrono_AccessController.requireFeature(actorEmployeeId, 'Configuration');
  }

  private static List<FeatureOption> buildCatalog() {
    List<FeatureOption> options = new List<FeatureOption>();
    addFeature(
      options,
      'Dashboard',
      'Dashboard',
      'Self Service',
      'Portal landing page and employee summary.'
    );
    addFeature(
      options,
      'My Profile',
      'My Profile',
      'Self Service',
      'View and maintain permitted employee details.'
    );
    addFeature(
      options,
      'Attendance Management',
      'Attendance Management',
      'Self Service',
      'Attendance, overtime, WFH, and timesheet experiences.'
    );
    addFeature(
      options,
      'Leave Management',
      'Leave Management',
      'Self Service',
      'Employee leave requests and status.'
    );
    addFeature(
      options,
      'Holidays',
      'Holidays',
      'Self Service',
      'Company holiday calendar.'
    );
    addFeature(
      options,
      'Company Policies',
      'Company Policies',
      'Self Service',
      'Published policy access.'
    );
    addFeature(
      options,
      'Expense Management',
      'Expense Management',
      'Self Service',
      'Expense submission and status.'
    );
    addFeature(
      options,
      'Tax Declaration',
      'Tax Declaration',
      'Self Service',
      'Employee tax declaration experience.'
    );
    addFeature(
      options,
      'Employee Directory',
      'Employee Directory',
      'HR and Talent',
      'View permitted employee directory information.'
    );
    addFeature(
      options,
      'Manager Dashboard',
      'Manager Dashboard',
      'Team Management',
      'Team-level management summaries.'
    );
    addFeature(
      options,
      'Approvals',
      'Approvals',
      'Team Management',
      'Approve or reject supported employee requests.'
    );
    addFeature(
      options,
      'Performance Management',
      'Performance Management',
      'Team Management',
      'Performance review workflows.'
    );
    addFeature(
      options,
      'Appraisal',
      'Appraisals',
      'Team Management',
      'Employee appraisal workflows.'
    );
    addFeature(
      options,
      'Goals',
      'Goals',
      'Team Management',
      'Employee and team goal management.'
    );
    addFeature(
      options,
      'Recruitment',
      'Recruitment',
      'HR and Talent',
      'Job, applicant, and recruitment workflows.'
    );
    addFeature(
      options,
      'Onboarding',
      'Onboarding',
      'HR and Talent',
      'Employee onboarding workflows.'
    );
    addFeature(
      options,
      PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      'Employee Lifecycle',
      'HR and Talent',
      'Promotions, transfers, separations, exit interviews and final settlements.'
    );
    addFeature(
      options,
      'Training Management',
      'Training Management',
      'HR and Talent',
      'Training catalog and employee training workflows.'
    );
    addFeature(
      options,
      'Projects',
      'Projects',
      'Work Management',
      'Project list and project-related experiences.'
    );
    addFeature(
      options,
      'Payroll',
      'Payroll',
      'Payroll',
      'Payroll and salary-slip experiences.'
    );
    addFeature(
      options,
      'Configuration',
      'Configuration',
      'Administration',
      'Portal configuration center.'
    );
    addFeature(
      options,
      'Admin Settings',
      'Admin Settings',
      'Administration',
      'Administrative settings and maintenance.'
    );
    addFeature(
      options,
      'Reports Dashboard',
      'Reports Dashboard',
      'Administration',
      'Administrative and management reporting.'
    );
    return options;
  }

  private static void addFeature(
    List<FeatureOption> options,
    String key,
    String label,
    String category,
    String description
  ) {
    FeatureOption option = new FeatureOption();
    option.key = key;
    option.label = label;
    option.category = category;
    option.description = description;
    option.enabled = false;
    options.add(option);
  }

  @AuraEnabled(cacheable=true)
  public static List<FeatureOption> getFeatureCatalog(
    Id profileId,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    Set<String> enabledKeys = new Set<String>();
    if (profileId != null) {
      for (Portal_Profile_Feature__c assignment : [
        SELECT Feature_Key__c
        FROM Portal_Profile_Feature__c
        WHERE Portal_User_Profile__c = :profileId AND Is_Enabled__c = TRUE
      ]) {
        enabledKeys.add(assignment.Feature_Key__c);
      }
    }
    List<FeatureOption> result = buildCatalog();
    for (FeatureOption option : result) {
      option.enabled = enabledKeys.contains(option.key);
    }
    return result;
  }

  @AuraEnabled
  public static void saveFeatureAssignments(
    Id profileId,
    String featureKeysJson,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    if (profileId == null) {
      throw new AuraHandledException('A profile is required.');
    }

    Set<String> validKeys = new Set<String>();
    for (FeatureOption option : buildCatalog()) {
      validKeys.add(option.key);
    }
    List<String> requestedKeys = (List<String>) JSON.deserialize(
      featureKeysJson == null ? '[]' : featureKeysJson,
      List<String>.class
    );
    Set<String> selectedKeys = new Set<String>();
    for (String key : requestedKeys) {
      if (String.isBlank(key) || !validKeys.contains(key)) {
        throw new AuraHandledException(
          'The selected feature catalog is invalid. Refresh and try again.'
        );
      }
      selectedKeys.add(key);
    }

    List<Portal_Profile_Feature__c> existing = [
      SELECT Id
      FROM Portal_Profile_Feature__c
      WHERE Portal_User_Profile__c = :profileId
    ];
    if (!existing.isEmpty()) {
      delete existing;
    }

    Map<String, String> labelsByKey = new Map<String, String>();
    for (FeatureOption option : buildCatalog()) {
      labelsByKey.put(option.key, option.label);
    }
    List<Portal_Profile_Feature__c> assignments = new List<Portal_Profile_Feature__c>();
    for (String key : selectedKeys) {
      assignments.add(
        new Portal_Profile_Feature__c(
          Portal_User_Profile__c = profileId,
          Feature_Key__c = key,
          Feature_Label__c = labelsByKey.get(key),
          Is_Enabled__c = true
        )
      );
    }
    if (!assignments.isEmpty()) {
      insert assignments;
    }
  }
}