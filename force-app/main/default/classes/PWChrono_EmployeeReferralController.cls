/**
 * PWChrono_EmployeeReferralController
 * Manages Employee Referral records.
 * HR Admins can see all referrals; regular employees see only their own.
 */
public without sharing class PWChrono_EmployeeReferralController {
  private static void requireAccess(String portalUserId, String sessionToken) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }
    if (String.isBlank(portalUserId)) {
      return;
    }
    List<Portal_Users__c> users = [
      SELECT Id, Role__c, Access_Features__c, Is_Active__c
      FROM Portal_Users__c
      WHERE Id = :portalUserId
      LIMIT 1
    ];
    if (users.isEmpty()) {
      return;
    }
  }

  private static Boolean isHrAdmin(String portalUserId) {
    if (String.isBlank(portalUserId))
      return false;
    List<Portal_Users__c> users = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :portalUserId
      LIMIT 1
    ];
    return !users.isEmpty() &&
      users[0].Role__c == PWChrono_Constants.ROLE_HR_ADMIN;
  }

  private static PWChrono_Employee_Referral__c parseReferralJson(String referralJson, String portalUserId) {
    Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(referralJson);
    PWChrono_Employee_Referral__c rec = new PWChrono_Employee_Referral__c();
    if (raw.containsKey('Id') && raw.get('Id') != null && String.isNotBlank(String.valueOf(raw.get('Id')))) {
      rec.Id = (Id) raw.get('Id');
    }
    if (raw.containsKey('Full_Name__c') && raw.get('Full_Name__c') != null) {
      rec.Full_Name__c = String.valueOf(raw.get('Full_Name__c'));
    }
    if (raw.containsKey('Email__c') && raw.get('Email__c') != null) {
      rec.Email__c = String.valueOf(raw.get('Email__c'));
    }
    if (raw.containsKey('Mobile_Number__c') && raw.get('Mobile_Number__c') != null) {
      rec.Mobile_Number__c = String.valueOf(raw.get('Mobile_Number__c'));
    }
    if (raw.containsKey('For_Designation__c') && raw.get('For_Designation__c') != null && String.isNotBlank(String.valueOf(raw.get('For_Designation__c')))) {
      rec.For_Designation__c = (Id) raw.get('For_Designation__c');
    }
    if (raw.containsKey('Status__c') && raw.get('Status__c') != null && String.isNotBlank(String.valueOf(raw.get('Status__c')))) {
      rec.Status__c = String.valueOf(raw.get('Status__c'));
    }
    if (raw.containsKey('Job_Applicant__c') && raw.get('Job_Applicant__c') != null && String.isNotBlank(String.valueOf(raw.get('Job_Applicant__c')))) {
      rec.Job_Applicant__c = (Id) raw.get('Job_Applicant__c');
    }
    if (raw.containsKey('Current_Employee__c') && raw.get('Current_Employee__c') != null && String.isNotBlank(String.valueOf(raw.get('Current_Employee__c')))) {
      rec.Current_Employee__c = (Id) raw.get('Current_Employee__c');
    } else if (String.isNotBlank(portalUserId)) {
      rec.Current_Employee__c = portalUserId;
    }
    if (raw.containsKey('Referral_Bonus_Amount__c') && raw.get('Referral_Bonus_Amount__c') != null && String.isNotBlank(String.valueOf(raw.get('Referral_Bonus_Amount__c')))) {
      rec.Referral_Bonus_Amount__c = Decimal.valueOf(String.valueOf(raw.get('Referral_Bonus_Amount__c')));
    }
    if (raw.containsKey('Is_Applicable_for_Referral_Bonus__c') && raw.get('Is_Applicable_for_Referral_Bonus__c') != null) {
      rec.Is_Applicable_for_Referral_Bonus__c = Boolean.valueOf(raw.get('Is_Applicable_for_Referral_Bonus__c'));
    }
    if (raw.containsKey('Referral_Bonus_Payment_Status__c') && raw.get('Referral_Bonus_Payment_Status__c') != null) {
      rec.Referral_Bonus_Payment_Status__c = String.valueOf(raw.get('Referral_Bonus_Payment_Status__c'));
    }
    if (raw.containsKey('Additional_Information__c') && raw.get('Additional_Information__c') != null) {
      rec.Additional_Information__c = String.valueOf(raw.get('Additional_Information__c'));
    }
    return rec;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Queries
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Returns referrals. HR Admins see all; employees see only their own.
   */
  @AuraEnabled
  public static List<PWChrono_Employee_Referral__c> getReferrals(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);

      Boolean hrAdmin = isHrAdmin(portalUserId);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;

      String q =
        'SELECT Id, Name, Full_Name__c, Email__c, Mobile_Number__c, ' +
        'For_Designation__c, For_Designation__r.Name, ' +
        'Status__c, ' +
        'Job_Applicant__c, Job_Applicant__r.Name, ' +
        'Current_Employee__c, Current_Employee__r.Name, ' +
        'Referral_Bonus_Amount__c, Is_Applicable_for_Referral_Bonus__c, ' +
        'Referral_Bonus_Payment_Status__c, Additional_Information__c, ' +
        'CreatedDate ' +
        'FROM PWChrono_Employee_Referral__c ' +
        'WHERE Id != null';

      if (!hrAdmin && String.isNotBlank(portalUserId)) {
        q += ' AND Current_Employee__c = :portalUserId';
      }
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        q += ' AND Status__c = :statusFilter';
      }

      q += ' ORDER BY CreatedDate DESC LIMIT :queryLimit';

      return Database.query(q);
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.getReferrals',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Returns a single referral by Id.
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Employee_Referral__c getReferralById(
    String referralId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      List<PWChrono_Employee_Referral__c> recs = [
        SELECT
          Id,
          Name,
          Full_Name__c,
          Email__c,
          Mobile_Number__c,
          For_Designation__c,
          For_Designation__r.Name,
          Status__c,
          Job_Applicant__c,
          Job_Applicant__r.Name,
          Current_Employee__c,
          Current_Employee__r.Name,
          Referral_Bonus_Amount__c,
          Is_Applicable_for_Referral_Bonus__c,
          Referral_Bonus_Payment_Status__c,
          Additional_Information__c
        FROM PWChrono_Employee_Referral__c
        WHERE Id = :referralId
        LIMIT 1
      ];
      if (recs.isEmpty()) {
        throw new AuraHandledException('Referral not found.');
      }
      return recs[0];
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.getReferralById',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save / upsert
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Inserts or updates a referral record.
   * On insert, Current_Employee__c is set to the submitting portal user.
   * @return  Id of the saved record.
   */
  @AuraEnabled
  public static String saveReferral(
    String referralJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);

      if (String.isBlank(referralJson)) {
        throw new AuraHandledException('Referral data is required.');
      }
      PWChrono_Employee_Referral__c rec = parseReferralJson(
        referralJson,
        portalUserId
      );

      upsert rec;
      return rec.Id;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.saveReferral',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  @AuraEnabled
  public static void updateReferralStatus(
    String referralId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can update referral status.'
        );
      }
      PWChrono_Employee_Referral__c rec = new PWChrono_Employee_Referral__c(
        Id = referralId,
        Status__c = newStatus
      );
      update rec;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.updateReferralStatus',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  @AuraEnabled
  public static void deleteReferral(
    String referralId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException('Only HR Admins can delete referrals.');
      }
      List<PWChrono_Employee_Referral__c> referrals = [
        SELECT Id, Status__c
        FROM PWChrono_Employee_Referral__c
        WHERE Id = :referralId
        LIMIT 1
      ];
      if (referrals.isEmpty()) {
        throw new AuraHandledException('Referral not found.');
      }
      if (referrals[0].Status__c != 'Pending') {
        throw new AuraHandledException(
          'Only pending referrals can be deleted.'
        );
      }
      delete referrals[0];
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.deleteReferral',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Designation__c> getActiveDesignations() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Designation__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.getActiveDesignations',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Applicant__c> getJobApplicants() {
    try {
      return [
        SELECT Id, Name, Email__c
        FROM PWChrono_Job_Applicant__c
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeReferralController.getJobApplicants',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }
}