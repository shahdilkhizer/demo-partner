/**
 * @description Controller for Payroll Management LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexSOQLInjection')
public inherited sharing class PWChrono_PayrollController {
  @TestVisible
  private static String testUserTypeOverride;

  private static Boolean isGuestRuntime() {
    String userType = Test.isRunningTest() && testUserTypeOverride != null
      ? testUserTypeOverride
      : UserInfo.getUserType();
    return userType == 'Guest';
  }

  private static Id resolveVerifiedPortalUserId(
    String portalUserId,
    String sessionToken
  ) {
    return (Id) PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
  }

  private static Id resolveContactIdForPortalUser(Id portalUserId) {
    if (portalUserId == null) {
      return null;
    }

    List<Portal_Users__c> portalUsers = [
      SELECT Contact__c
      FROM Portal_Users__c
      WHERE Id = :portalUserId
      LIMIT 1
    ];
    if (portalUsers.isEmpty() || portalUsers[0].Contact__c == null) {
      throw new AuraHandledException(
        'The portal user is not linked to an employee Contact.'
      );
    }
    return portalUsers[0].Contact__c;
  }

  private static Id resolveVerifiedPayrollPortalUserId(
    String portalUserId,
    String sessionToken
  ) {
    Id verifiedPortalUserId = resolveVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    List<Portal_Users__c> portalUsers = [
      SELECT Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId AND Is_Active__c = TRUE
      LIMIT 1
    ];
    if (
      portalUsers.isEmpty() || portalUsers[0].Portal_User_Profile__c == null
    ) {
      throw new AuraHandledException('Unauthorized.');
    }
    Id profileId = portalUsers[0].Portal_User_Profile__c;
    if (
      [
        SELECT COUNT()
        FROM Portal_Profile_Feature__c
        WHERE
          Portal_User_Profile__c = :profileId
          AND Feature_Key__c = 'Payroll'
          AND Is_Enabled__c = TRUE
      ] == 0
    ) {
      throw new AuraHandledException('Unauthorized.');
    }
    return verifiedPortalUserId;
  }

  private static Id resolveTargetContactIdForNonGuest(String contactId) {
    if (
      String.isNotBlank(contactId) &&
      FeatureManagement.checkPermission('PWChrono_Send_Payslips')
    ) {
      return (Id) contactId;
    }

    Id portalUserId = PWChrono_Utils.getCurrentEmployeeId(UserInfo.getUserId());
    Id currentContactId = resolveContactIdForPortalUser(portalUserId);
    if (String.isBlank(contactId)) {
      return currentContactId;
    }

    Id requestedContactId = (Id) contactId;
    if (requestedContactId != currentContactId) {
      throw new AuraHandledException('Unauthorized employee selection.');
    }
    return requestedContactId;
  }

  private static Id resolveTargetContactId(
    String contactId,
    String portalUserId,
    String sessionToken
  ) {
    if (isGuestRuntime()) {
      // Guest sessions identify a Portal User, but payroll ownership is Contact.
      return resolveContactIdForPortalUser(
        resolveVerifiedPayrollPortalUserId(portalUserId, sessionToken)
      );
    }
    return resolveTargetContactIdForNonGuest(contactId);
  }

  private static List<PWChrono_Salary_Slip__c> getMySalarySlipsCore(
    Integer year,
    Integer month,
    Id targetContactId
  ) {
    String query =
      'SELECT Id, Name, Contact__c, Contact__r.Name, Payroll_Period__c, ' +
      'Gross_Pay__c, Total_Deductions__c, Net_Pay__c, ' +
      'Status__c, CreatedDate ' +
      'FROM PWChrono_Salary_Slip__c ' +
      'WHERE Contact__c = :targetContactId ';

    if (year != null) {
      query += 'AND CALENDAR_YEAR(Payroll_Period__c) = :year ';
    }

    if (month != null) {
      query += 'AND CALENDAR_MONTH(Payroll_Period__c) = :month ';
    }

    query += ' ORDER BY Payroll_Period__c DESC LIMIT 24';

    return Database.query(query);
  }

  /**
   * @description Get salary slips for current employee
   * @param year Filter by year (optional)
   * @param month Filter by month (optional)
   * @param contactId Optional employee Contact ID. If null, resolves the current Portal User's Contact.
   * @return List of salary slips
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Salary_Slip__c> getMySalarySlips(
    Integer year,
    Integer month,
    String contactId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetContactId = resolveTargetContactId(
        contactId,
        portalUserId,
        sessionToken
      );

      if (targetContactId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      return getMySalarySlipsCore(year, month, targetContactId);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching salary slips: '
      );
      ahe.setMessage('Error fetching salary slips: ');
      throw ahe;
    }
  }

  /**
   * @description Get list of employees for dropdown
   * @return Employee Contacts linked to active Portal Users
   */
  private static List<Contact> getEmployeesForDropdownCore() {
    try {
      String query = 'SELECT Id, Name, Email FROM Contact ';

      if (FeatureManagement.checkPermission('PWChrono_Send_Payslips')) {
        query +=
          'WHERE Id IN (SELECT Contact__c FROM Portal_Users__c ' +
          'WHERE Contact__c != NULL AND Is_Active__c = TRUE) ';
      } else {
        Id currentPortalUserId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        Id currentContactId = resolveContactIdForPortalUser(
          currentPortalUserId
        );
        query += 'WHERE Id = :currentContactId ';
      }

      query += 'ORDER BY Name ASC';

      return Database.query(query);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching employees: ');
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Contact> getEmployeesForDropdown(
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (isGuestRuntime()) {
        Id contactId = resolveContactIdForPortalUser(
          resolveVerifiedPayrollPortalUserId(portalUserId, sessionToken)
        );
        return [
          SELECT Id, Name, Email
          FROM Contact
          WHERE Id = :contactId
          ORDER BY Name ASC
        ];
      }

      // Non-Guest: preserve existing behavior.
      return getEmployeesForDropdownCore();
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching employees: ');
    }
  }

  /**
   * @description Get Payroll Configuration (CC Email)
   * @return Map of config values
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, String> getPayrollConfiguration() {
    // Do not default a confidential payslip to an environment-specific CC.
    // A future reviewed configuration can supply one; blank means no CC.
    return new Map<String, String>{ 'ccEmail' => '' };
  }

  /**
   * @description Send Salary Slip via Email
   */
  @AuraEnabled
  public static void sendSalarySlipEmail(
    Id salarySlipId,
    String toEmail,
    String ccEmail,
    String subject,
    String body,
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (
        isGuestRuntime() ||
        !FeatureManagement.checkPermission('PWChrono_Send_Payslips')
      ) {
        throw new AuraHandledException('Unauthorized.');
      }

      PWChrono_Salary_Slip__c slip = [
        SELECT Id, Contact__c, Contact__r.Email
        FROM PWChrono_Salary_Slip__c
        WHERE Id = :salarySlipId AND Contact__c != NULL
        LIMIT 1
      ];
      String employeeEmail = slip.Contact__r != null
        ? slip.Contact__r.Email
        : null;
      if (String.isBlank(employeeEmail)) {
        throw new AuraHandledException('Employee Contact email not found.');
      }
      if (String.isNotBlank(toEmail) && toEmail != employeeEmail) {
        throw new AuraHandledException('Unauthorized recipient.');
      }

      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setToAddresses(new List<String>{ employeeEmail });

      if (String.isNotBlank(ccEmail)) {
        mail.setCcAddresses(new List<String>{ ccEmail });
      }

      mail.setSubject(subject);
      mail.setHtmlBody(body);

      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error sending email: ');
    }
  }

  public class SalaryComponent {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Decimal amount;
  }

  /**
   * @description Get salary slip details with components breakdown
   * @param salarySlipId Salary slip ID
   * @param contactId Optional employee Contact ID. If null, resolves the current Portal User's Contact.
   * @return Salary slip with component details
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getSalarySlipDetails(
    Id salarySlipId,
    String contactId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetContactId = resolveTargetContactId(
        contactId,
        portalUserId,
        sessionToken
      );

      // Ensure the salary slip belongs to the resolved employee.
      PWChrono_Salary_Slip__c salarySlip = [
        SELECT
          Id,
          Name,
          Contact__c,
          Contact__r.Name,
          Contact__r.Email,
          Employee_Name_Snapshot__c,
          Employee_Code_Snapshot__c,
          Payroll_Period__c,
          Gross_Pay__c,
          Total_Deductions__c,
          Net_Pay__c,
          Status__c,
          Earning_Details__c,
          Deduction_Details__c
        FROM PWChrono_Salary_Slip__c
        WHERE Id = :salarySlipId AND Contact__c = :targetContactId
        LIMIT 1
      ];

      Map<String, Object> result = new Map<String, Object>();
      result.put('salarySlip', salarySlip);

      List<SalaryComponent> earnings = new List<SalaryComponent>();
      if (String.isNotBlank(salarySlip.Earning_Details__c)) {
        try {
          earnings = (List<SalaryComponent>) JSON.deserialize(
            salarySlip.Earning_Details__c,
            List<SalaryComponent>.class
          );
        } catch (Exception e) {
          PWChrono_Logger.error('Error deserializing earnings: ');
        }
      }

      List<SalaryComponent> deductions = new List<SalaryComponent>();
      if (String.isNotBlank(salarySlip.Deduction_Details__c)) {
        try {
          deductions = (List<SalaryComponent>) JSON.deserialize(
            salarySlip.Deduction_Details__c,
            List<SalaryComponent>.class
          );
        } catch (Exception e) {
          PWChrono_Logger.error('Error deserializing deductions: ');
        }
      }

      result.put('earnings', earnings);
      result.put('deductions', deductions);

      return result;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching salary slip details: '
      );
      ahe.setMessage('Error fetching salary slip details: ');
      throw ahe;
    }
  }

  /**
   * @description Get salary structure for employee
   * @return Current salary assignment with structure details
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getMySalaryStructure() {
    try {
      Id portalUserId = PWChrono_Utils.getCurrentEmployeeId(
        UserInfo.getUserId()
      );
      Id contactId = resolveContactIdForPortalUser(portalUserId);

      if (contactId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      List<PWChrono_Salary_Assignment__c> assignments = [
        SELECT
          Id,
          Name,
          Contact__c,
          Salary_Structure__c,
          Salary_Structure__r.Name,
          Base_Salary__c,
          From_Date__c
        FROM PWChrono_Salary_Assignment__c
        WHERE Contact__c = :contactId
        ORDER BY From_Date__c DESC
        LIMIT 1
      ];

      if (assignments.isEmpty()) {
        AuraHandledException ahe = new AuraHandledException(
          'No active salary assignment found.'
        );
        ahe.setMessage('No active salary assignment found.');
        throw ahe;
      }

      PWChrono_Salary_Assignment__c assignment = assignments[0];

      List<PWChrono_Structure_Component__c> components = [
        SELECT
          Id,
          Name,
          Salary_Structure__c,
          Salary_Component__c,
          Salary_Component__r.Name,
          Salary_Component__r.Component_Type__c,
          Amount__c
        FROM PWChrono_Structure_Component__c
        WHERE Salary_Structure__c = :assignment.Salary_Structure__c
        ORDER BY Salary_Component__r.Component_Type__c, Salary_Component__r.Name
      ];

      Map<String, Object> result = new Map<String, Object>();
      result.put('assignment', assignment);
      result.put('components', components);

      return result;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching salary structure: '
      );
      ahe.setMessage('Error fetching salary structure: ');
      throw ahe;
    }
  }

  /**
   * @description Get YTD (Year to Date) summary for employee
   * @param year Year for YTD calculation
   * @return YTD summary data
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Decimal> getYTDSummary(Integer year) {
    try {
      Id portalUserId = PWChrono_Utils.getCurrentEmployeeId(
        UserInfo.getUserId()
      );
      Id contactId = resolveContactIdForPortalUser(portalUserId);

      if (contactId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      AggregateResult[] results = [
        SELECT
          SUM(Gross_Pay__c) totalGross,
          SUM(Total_Deductions__c) totalDeductions,
          SUM(Net_Pay__c) totalNet
        FROM PWChrono_Salary_Slip__c
        WHERE
          Contact__c = :contactId
          AND CALENDAR_YEAR(Payroll_Period__c) = :year
          AND Status__c = :PWChrono_Constants.STATUS_PAID
      ];

      Map<String, Decimal> ytdData = new Map<String, Decimal>();
      // Null-safe handling for aggregate results
      Decimal totalGross = results[0].get('totalGross') != null
        ? (Decimal) results[0].get('totalGross')
        : 0;
      Decimal totalDeductions = results[0].get('totalDeductions') != null
        ? (Decimal) results[0].get('totalDeductions')
        : 0;
      Decimal totalNet = results[0].get('totalNet') != null
        ? (Decimal) results[0].get('totalNet')
        : 0;

      ytdData.put('totalGross', totalGross);
      ytdData.put('totalDeductions', totalDeductions);
      ytdData.put('totalNet', totalNet);

      return ytdData;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error calculating YTD summary: '
      );
      ahe.setMessage('Error calculating YTD summary: ');
      throw ahe;
    }
  }

  // Helper Methods
}