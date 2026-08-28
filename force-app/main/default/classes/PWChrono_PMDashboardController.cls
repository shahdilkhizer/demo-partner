/**
 * @description Controller for Project Manager Dashboard (portal)
 */
public inherited sharing class PWChrono_PMDashboardController {
  public class ProjectRow {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String accountName;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String priority;
    @AuraEnabled
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public Decimal totalHours;
    @AuraEnabled
    public Decimal hoursLogged;
    @AuraEnabled
    public Decimal projectValue;
    @AuraEnabled
    public Decimal teamSize;
  }

  public class DashboardDTO {
    @AuraEnabled
    public Integer totalProjects;
    @AuraEnabled
    public Integer activeProjects;
    @AuraEnabled
    public Integer highPriorityActiveProjects;
    @AuraEnabled
    public Integer endingSoonProjects;

    // PM-focused KPIs
    @AuraEnabled
    public Decimal activeProjectValue;
    @AuraEnabled
    public Decimal activeHoursLogged;
    @AuraEnabled
    public Decimal activeHoursPlanned;
    @AuraEnabled
    public Decimal activeTeamSize;
    @AuraEnabled
    public Integer atRiskProjects;
    @AuraEnabled
    public Integer overrunProjects;

    @AuraEnabled
    public List<ProjectRow> recentProjects;
    @AuraEnabled
    public List<ProjectRow> atRiskProjectRows;
    @AuraEnabled
    public List<ProjectRow> overrunProjectRows;
  }

  private static Id resolveAndRequireProjectManager(
    String portalUserId,
    String sessionToken
  ) {
    // Internal Salesforce users: allow for admin/dev usage.
    if (PWChrono_AccessController.isSalesforceInternalUser()) {
      // If an internal user is linked to a portal user/employee record, enforce role.
      // This prevents any random internal user from calling the portal endpoint.
      Id internalEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
        UserInfo.getUserId()
      );
      if (internalEmployeeId != null) {
        Portal_Users__c uInternal = [
          SELECT Id, Role__c
          FROM Portal_Users__c
          WHERE Id = :internalEmployeeId
          LIMIT 1
        ];

        if (
          uInternal.Role__c != PWChrono_Constants.ROLE_PROJECT_MANAGER &&
          uInternal.Role__c != PWChrono_Constants.ROLE_HR_ADMIN
        ) {
          throw new AuraHandledException('Unauthorized.');
        }
      }

      return internalEmployeeId;
    }

    Id employeeId;
    if (UserInfo.getUserType() == 'Guest') {
      employeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
    } else {
      employeeId = PWChrono_Utils.getCurrentEmployeeId(UserInfo.getUserId());
    }

    if (employeeId == null) {
      throw new AuraHandledException('Unauthorized.');
    }

    Portal_Users__c u = [
      SELECT Id, Role__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    // Restrict this endpoint to Project Managers (and HR Admins for oversight).
    if (
      u.Role__c != PWChrono_Constants.ROLE_PROJECT_MANAGER &&
      u.Role__c != PWChrono_Constants.ROLE_HR_ADMIN
    ) {
      throw new AuraHandledException('Unauthorized.');
    }

    return employeeId;
  }

  @AuraEnabled(cacheable=false)
  public static DashboardDTO getDashboardData(
    String portalUserId,
    String sessionToken
  ) {
    try {
      resolveAndRequireProjectManager(portalUserId, sessionToken);

      DashboardDTO dto = new DashboardDTO();

      dto.totalProjects = [SELECT COUNT() FROM PWChrono_Project__c];
      dto.activeProjects = [
        SELECT COUNT()
        FROM PWChrono_Project__c
        WHERE Status__c = :PWChrono_Constants.STATUS_ACTIVE
      ];
      dto.highPriorityActiveProjects = [
        SELECT COUNT()
        FROM PWChrono_Project__c
        WHERE
          Status__c = :PWChrono_Constants.STATUS_ACTIVE
          AND Priority__c = 'High'
      ];
      dto.endingSoonProjects = [
        SELECT COUNT()
        FROM PWChrono_Project__c
        WHERE
          Status__c = :PWChrono_Constants.STATUS_ACTIVE
          AND End_Date__c = NEXT_N_DAYS:14
      ];

      dto.recentProjects = new List<ProjectRow>();
      dto.atRiskProjectRows = new List<ProjectRow>();
      dto.overrunProjectRows = new List<ProjectRow>();

      // Pull a single set of projects for dashboard calculations.
      // NOTE: There's no explicit "Project Manager" lookup field on the object today,
      // so we compute org-wide metrics.
      List<PWChrono_Project__c> projects = [
        SELECT
          Id,
          Name,
          Account__r.Name,
          Status__c,
          Priority__c,
          Start_Date__c,
          End_Date__c,
          Total_Hours__c,
          Hours_Logged__c,
          Amount__c,
          Team_Size__c
        FROM PWChrono_Project__c
        ORDER BY CreatedDate DESC
        LIMIT 200
      ];

      Decimal activeValue = 0;
      Decimal activeHoursLogged = 0;
      Decimal activeHoursPlanned = 0;
      Decimal activeTeamSize = 0;
      Integer atRisk = 0;
      Integer overrun = 0;

      Integer recentAdded = 0;
      for (PWChrono_Project__c p : projects) {
        // Recent projects table (top 10)
        if (recentAdded < 10) {
          dto.recentProjects.add(toRow(p));
          recentAdded++;
        }

        if (p.Status__c == PWChrono_Constants.STATUS_ACTIVE) {
          activeValue += (p.Amount__c == null ? 0 : p.Amount__c);
          activeHoursLogged += (p.Hours_Logged__c == null
            ? 0
            : p.Hours_Logged__c);
          activeHoursPlanned += (p.Total_Hours__c == null
            ? 0
            : p.Total_Hours__c);
          activeTeamSize += (p.Team_Size__c == null ? 0 : p.Team_Size__c);

          // At risk: ending soon and not clearly "on track".
          // (If total hours is missing, treat as risky when ending soon.)
          Boolean endingSoon =
            (p.End_Date__c != null) &&
            (p.End_Date__c <= Date.today().addDays(14)) &&
            (p.End_Date__c >= Date.today());
          Boolean behindHours =
            (p.Total_Hours__c != null) &&
            (p.Hours_Logged__c != null) &&
            (p.Hours_Logged__c < p.Total_Hours__c);
          Boolean missingPlan = (p.Total_Hours__c == null);
          if (endingSoon && (behindHours || missingPlan)) {
            atRisk++;
            if (dto.atRiskProjectRows.size() < 10) {
              dto.atRiskProjectRows.add(toRow(p));
            }
          }

          // Overrun: logged hours exceed planned hours.
          if (
            p.Total_Hours__c != null &&
            p.Hours_Logged__c != null &&
            p.Hours_Logged__c > p.Total_Hours__c
          ) {
            overrun++;
            if (dto.overrunProjectRows.size() < 10) {
              dto.overrunProjectRows.add(toRow(p));
            }
          }
        }
      }

      dto.activeProjectValue = activeValue;
      dto.activeHoursLogged = activeHoursLogged;
      dto.activeHoursPlanned = activeHoursPlanned;
      dto.activeTeamSize = activeTeamSize;
      dto.atRiskProjects = atRisk;
      dto.overrunProjects = overrun;

      return dto;
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching project manager dashboard data: ' + e.getMessage()
      );
      ahe.setMessage(
        'Error fetching project manager dashboard data: ' + e.getMessage()
      );
      throw ahe;
    }
  }

  private static ProjectRow toRow(PWChrono_Project__c p) {
    ProjectRow row = new ProjectRow();
    row.id = p.Id;
    row.name = p.Name;
    row.accountName = p.Account__r != null ? p.Account__r.Name : null;
    row.status = p.Status__c;
    row.priority = p.Priority__c;
    row.startDate = p.Start_Date__c;
    row.endDate = p.End_Date__c;
    row.totalHours = p.Total_Hours__c;
    row.hoursLogged = p.Hours_Logged__c;
    row.projectValue = p.Amount__c;
    row.teamSize = p.Team_Size__c;
    return row;
  }
}