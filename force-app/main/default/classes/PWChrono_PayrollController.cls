/**
 * @description Controller for Payroll Management LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexSOQLInjection')
public inherited sharing class PWChrono_PayrollController {
  private static Id resolveVerifiedPortalEmployeeId(
    String portalUserId,
    String sessionToken
  ) {
    return (Id) PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
  }

  private static Id resolveTargetEmployeeIdForNonGuest(String employeeId) {
    if (String.isNotBlank(employeeId)) {
      return (Id) employeeId;
    }
    return PWChrono_Utils.getCurrentEmployeeId(UserInfo.getUserId());
  }

  private static Id resolveTargetEmployeeId(
    String employeeId,
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      // In Guest runtime, never trust client-supplied employeeId.
      return resolveVerifiedPortalEmployeeId(portalUserId, sessionToken);
    }
    return resolveTargetEmployeeIdForNonGuest(employeeId);
  }

  private static List<PWChrono_Salary_Slip__c> getMySalarySlipsCore(
    Integer year,
    Integer month,
    Id targetEmployeeId
  ) {
    String query =
      'SELECT Id, Name, Employees__c, Payroll_Period__c, ' +
      'Gross_Pay__c, Total_Deductions__c, Net_Pay__c, ' +
      'Status__c, CreatedDate ' +
      'FROM PWChrono_Salary_Slip__c ' +
      'WHERE Employees__c = :targetEmployeeId ';

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
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return List of salary slips
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Salary_Slip__c> getMySalarySlips(
    Integer year,
    Integer month,
    String employeeId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId = resolveTargetEmployeeId(
        employeeId,
        portalUserId,
        sessionToken
      );

      if (targetEmployeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      return getMySalarySlipsCore(year, month, targetEmployeeId);
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
   * @return List of Portal_Users__c
   */
  private static List<Portal_Users__c> getEmployeesForDropdownCore() {
    try {
      // Check if user is Salesforce Standard User
      Boolean isSalesforceUser = UserInfo.getUserType() == 'Standard';

      String query = 'SELECT Id, Name FROM Portal_Users__c ';

      if (!isSalesforceUser) {
        // If not Salesforce user, restrict to current user
        // In future, check for "View All Employees" permission here
        Id currentEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        query += 'WHERE Id = :currentEmployeeId ';
      }

      query += 'ORDER BY Name ASC';

      return Database.query(query);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching employees: ');
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getEmployeesForDropdown(
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        Id employeeId = resolveVerifiedPortalEmployeeId(
          portalUserId,
          sessionToken
        );
        return [
          SELECT Id, Name
          FROM Portal_Users__c
          WHERE Id = :employeeId
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
    // In a real scenario, query a Custom Setting or Custom Metadata Type
    // For now, returning a placeholder or checking a specific setup
    return new Map<String, String>{
      'ccEmail' => 'payroll@lodestonegroup.com' // Default/Placeholder
    };
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
      if (UserInfo.getUserType() == 'Guest') {
        Id targetEmployeeId = resolveTargetEmployeeId(
          null,
          portalUserId,
          sessionToken
        );

        // Verify slip ownership and lock recipient to the employee's email.
        PWChrono_Salary_Slip__c slip = [
          SELECT Id, Employees__c, Employees__r.Email__c
          FROM PWChrono_Salary_Slip__c
          WHERE Id = :salarySlipId AND Employees__c = :targetEmployeeId
          LIMIT 1
        ];

        String employeeEmail = slip.Employees__r != null
          ? slip.Employees__r.Email__c
          : null;
        if (String.isBlank(employeeEmail)) {
          throw new AuraHandledException('Employee email not found.');
        }

        if (String.isBlank(toEmail)) {
          toEmail = employeeEmail;
        }

        if (toEmail != employeeEmail) {
          throw new AuraHandledException('Unauthorized.');
        }
      }

      // Non-Guest: preserve existing behavior (send to requested address).
      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

      mail.setToAddresses(new List<String>{ toEmail });

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
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return Salary slip with component details
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getSalarySlipDetails(
    Id salarySlipId,
    String employeeId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId = resolveTargetEmployeeId(
        employeeId,
        portalUserId,
        sessionToken
      );

      // Ensure the salary slip belongs to the resolved employee.
      PWChrono_Salary_Slip__c salarySlip = [
        SELECT
          Id,
          Name,
          Employees__c,
          Employees__r.Name,
          Payroll_Period__c,
          Gross_Pay__c,
          Total_Deductions__c,
          Net_Pay__c,
          Status__c,
          Earning_Details__c,
          Deduction_Details__c
        FROM PWChrono_Salary_Slip__c
        WHERE Id = :salarySlipId AND Employees__c = :targetEmployeeId
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
      Id currentUserId = UserInfo.getUserId();
      Id employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);

      if (employeeId == null) {
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
          Employees__c,
          Salary_Structure__c,
          Salary_Structure__r.Name,
          Base_Salary__c,
          From_Date__c
        FROM PWChrono_Salary_Assignment__c
        WHERE Employees__c = :employeeId
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
      Id currentUserId = UserInfo.getUserId();
      Id employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);

      if (employeeId == null) {
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
          Employees__c = :employeeId
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