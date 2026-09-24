/**
 * @description Controller for Profile Update LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_ProfileController {
  /**
   * @description Resolve the target employee record Id for a profile operation.
   *              - Guest: portalUserId+sessionToken identify the actor; targetEmployeeId can be another employee only if actor is admin.
   *              - Non-Guest: uses current mapped employee; targetEmployeeId can be another employee only if actor is admin.
   */
  private static Id resolveTargetEmployeeId(
    String targetEmployeeId,
    String portalUserId,
    String sessionToken
  ) {
    // Guest runtime: validate actor identity via session token.
    if (UserInfo.getUserType() == 'Guest') {
      Id actorId = PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      Boolean actorIsAdmin = PWChrono_AccessController.isAdmin(actorId);

      if (String.isBlank(targetEmployeeId)) {
        return actorId;
      }

      if (targetEmployeeId == String.valueOf(actorId)) {
        return actorId;
      }

      if (!actorIsAdmin) {
        throw new AuraHandledException(
          'Not authorized to access this profile.'
        );
      }

      return (Id) targetEmployeeId;
    }

    // Non-Guest: map current Salesforce user to employee record.
    Id currentEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
      UserInfo.getUserId()
    );
    Boolean actorIsAdmin = PWChrono_AccessController.isAdmin(currentEmployeeId);

    if (String.isBlank(targetEmployeeId)) {
      if (currentEmployeeId == null) {
        throw new AuraHandledException('Employee mapping not found.');
      }
      return currentEmployeeId;
    }

    if (
      currentEmployeeId != null &&
      targetEmployeeId == String.valueOf(currentEmployeeId)
    ) {
      return currentEmployeeId;
    }

    if (!actorIsAdmin) {
      throw new AuraHandledException('Not authorized to access this profile.');
    }

    return (Id) targetEmployeeId;
  }

  /**
   * @description Get an employee profile with access enforcement.
   *              Pass portalUserId+sessionToken for guest runtime; admins may request other employees.
   */
  @AuraEnabled(cacheable=true)
  public static Portal_Users__c getProfileWithAccess(
    String targetEmployeeId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id resolvedId = resolveTargetEmployeeId(
        targetEmployeeId,
        portalUserId,
        sessionToken
      );
      if (resolvedId == null) {
        return null;
      }

      List<Portal_Users__c> employees = [
        SELECT
          Id,
          Name,
          Email__c,
          Phone__c,
          Address__c,
          Emergency_Contact_Name__c,
          Emergency_Contact_Phone__c,
          Designation__c,
          Department__c,
          Reports_To__r.Name,
          Photo_Url__c
        FROM Portal_Users__c
        WHERE Id = :resolvedId
        LIMIT 1
      ];

      return employees.isEmpty() ? null : employees[0];
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching profile (with access)', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching profile.'
      );
      ahe.setMessage('Error fetching profile.');
      throw ahe;
    }
  }
  /**
   * @description Get current employee profile
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return Employee record
   */
  @AuraEnabled(cacheable=true)
  public static Portal_Users__c getProfile(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id portalUserId;

      if (UserInfo.getUserType() == 'Guest') {
        // Guest must supply a valid portal session token; only own profile is accessible.
        portalUserId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          employeeId,
          sessionToken
        );
      } else if (String.isNotBlank(employeeId)) {
        Id currentEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        if (currentEmployeeId != null && employeeId != currentEmployeeId) {
          // Only admins can view other employees.
          if (PWChrono_AccessController.isAdmin(currentEmployeeId)) {
            portalUserId = (Id) employeeId;
          } else {
            portalUserId = currentEmployeeId;
          }
        } else {
          portalUserId = (Id) employeeId;
        }
      } else {
        Id currentUserId = UserInfo.getUserId();
        List<Portal_Users__c> users = [
          SELECT Id
          FROM Portal_Users__c
          WHERE User__c = :currentUserId
          LIMIT 1
        ];
        if (!users.isEmpty()) {
          portalUserId = users[0].Id;
        }
      }

      if (portalUserId == null) {
        return null;
      }

      List<Portal_Users__c> employees = [
        SELECT
          Id,
          Name,
          Email__c,
          Phone__c,
          Address__c,
          Emergency_Contact_Name__c,
          Emergency_Contact_Phone__c,
          Designation__c,
          Department__c,
          Reports_To__r.Name,
          Photo_Url__c
        FROM Portal_Users__c
        WHERE Id = :portalUserId
        LIMIT 1
      ];

      return employees.isEmpty() ? null : employees[0];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching profile: '
      );
      ahe.setMessage('Error fetching profile: ');
      throw ahe;
    }
  }

  /**
   * @description Update employee profile with access enforcement.
   */
  @AuraEnabled
  public static void updateProfileWithAccess(
    Map<String, Object> profileData,
    String targetEmployeeId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id resolvedId = resolveTargetEmployeeId(
        targetEmployeeId,
        portalUserId,
        sessionToken
      );
      if (resolvedId == null) {
        throw new AuraHandledException('Employee record not found.');
      }

      Portal_Users__c emp = new Portal_Users__c(Id = resolvedId);

      if (profileData != null) {
        if (profileData.containsKey('Name')) {
          emp.Name = (String) profileData.get('Name');
        }
        if (profileData.containsKey('Phone__c')) {
          emp.Phone__c = (String) profileData.get('Phone__c');
        }
        if (profileData.containsKey('Address__c')) {
          emp.Address__c = (String) profileData.get('Address__c');
        }
        if (profileData.containsKey('Emergency_Contact_Name__c')) {
          emp.Emergency_Contact_Name__c = (String) profileData.get(
            'Emergency_Contact_Name__c'
          );
        }
        if (profileData.containsKey('Emergency_Contact_Phone__c')) {
          emp.Emergency_Contact_Phone__c = (String) profileData.get(
            'Emergency_Contact_Phone__c'
          );
        }
      }

      update emp;
    } catch (Exception e) {
      PWChrono_Logger.error('Error updating profile (with access)', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error updating profile.'
      );
      ahe.setMessage('Error updating profile.');
      throw ahe;
    }
  }

  /**
   * @description Update employee profile
   * @param profileData Map of fields to update
   */
  @AuraEnabled
  public static void updateProfile(
    Map<String, Object> profileData,
    String portalUserId,
    String sessionToken
  ) {
    try {
      // Legacy method: treat portalUserId as the target employee record id.
      // Guest: only self is allowed. Non-Guest: only self unless admin.
      Id resolvedId = resolveTargetEmployeeId(
        portalUserId,
        portalUserId,
        sessionToken
      );
      Portal_Users__c emp = new Portal_Users__c(Id = resolvedId);

      if (profileData.containsKey('Name')) {
        emp.Name = (String) profileData.get('Name');
      }
      if (profileData.containsKey('Phone__c')) {
        emp.Phone__c = (String) profileData.get('Phone__c');
      }
      if (profileData.containsKey('Address__c')) {
        emp.Address__c = (String) profileData.get('Address__c');
      }
      if (profileData.containsKey('Emergency_Contact_Name__c')) {
        emp.Emergency_Contact_Name__c = (String) profileData.get(
          'Emergency_Contact_Name__c'
        );
      }
      if (profileData.containsKey('Emergency_Contact_Phone__c')) {
        emp.Emergency_Contact_Phone__c = (String) profileData.get(
          'Emergency_Contact_Phone__c'
        );
      }

      update emp;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error updating profile: '
      );
      ahe.setMessage('Error updating profile: ');
      throw ahe;
    }
  }

  /**
   * @description Upload profile image with access enforcement.
   */
  @AuraEnabled
  public static String uploadProfileImageWithAccess(
    String targetEmployeeId,
    String fileName,
    String base64Data,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id resolvedId = resolveTargetEmployeeId(
        targetEmployeeId,
        portalUserId,
        sessionToken
      );
      if (resolvedId == null) {
        throw new AuraHandledException('Employee record not found');
      }

      return storeProfileImage(resolvedId, fileName, base64Data);
    } catch (Exception e) {
      PWChrono_Logger.error('Error uploading profile image (with access)', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error uploading profile image.'
      );
      ahe.setMessage('Error uploading profile image.');
      throw ahe;
    }
  }

  /**
   * @description Upload profile image
   * @param employeeId Optional employee ID
   * @param fileName Name of the file
   * @param base64Data Base64 encoded file data
   */
  @AuraEnabled
  public static String uploadProfileImage(
    String employeeId,
    String fileName,
    String base64Data,
    String portalUserId,
    String sessionToken
  ) {
    try {
      // Legacy method: employeeId is the target employee record id.
      // Guest: only self is allowed. Non-Guest: only self unless admin.
      String idCandidate = String.isNotBlank(employeeId)
        ? employeeId
        : portalUserId;
      Id targetEmployeeId = resolveTargetEmployeeId(
        idCandidate,
        portalUserId,
        sessionToken
      );

      if (targetEmployeeId == null) {
        throw new AuraHandledException('Employee record not found');
      }

      return storeProfileImage(targetEmployeeId, fileName, base64Data);
    } catch (Exception e) {
      PWChrono_Logger.error('Error uploading profile image', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error uploading profile image: '
      );
      ahe.setMessage('Error uploading profile image: ');
      throw ahe;
    }
  }

  private static String storeProfileImage(
    Id employeeId,
    String fileName,
    String base64Data
  ) {
    ContentVersion cv = new ContentVersion(
      VersionData = EncodingUtil.base64Decode(base64Data),
      Title = fileName,
      PathOnClient = fileName,
      FirstPublishLocationId = employeeId
    );
    insert cv;

    ContentDistribution cd = new ContentDistribution(
      Name = fileName,
      ContentVersionId = cv.Id,
      PreferencesAllowViewInBrowser = true,
      PreferencesLinkLatestVersion = true,
      PreferencesNotifyOnVisit = false,
      PreferencesPasswordRequired = false,
      PreferencesAllowOriginalDownload = true
    );
    insert cd;

    cd = [
      SELECT ContentDownloadUrl
      FROM ContentDistribution
      WHERE Id = :cd.Id
    ];

    update new Portal_Users__c(
      Id = employeeId,
      Photo_Url__c = cd.ContentDownloadUrl
    );
    return cd.ContentDownloadUrl;
  }
}