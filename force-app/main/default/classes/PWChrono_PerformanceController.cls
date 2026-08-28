/**
 * @description Controller for Performance Management LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexSOQLInjection, PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_PerformanceController {
  /**
   * @description Get appraisals for current employee
   * @param statusFilter Status filter
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return List of appraisals
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Appraisal__c> getMyAppraisals(
    String statusFilter,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId;
      if (UserInfo.getUserType() == 'Guest') {
        targetEmployeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          employeeId,
          sessionToken
        );
      } else if (String.isNotBlank(employeeId)) {
        Id currentEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        if (currentEmployeeId != null && employeeId != currentEmployeeId) {
          if (PWChrono_AccessController.isAdmin(currentEmployeeId)) {
            targetEmployeeId = (Id) employeeId;
          } else {
            targetEmployeeId = currentEmployeeId;
          }
        } else {
          targetEmployeeId = (Id) employeeId;
        }
      } else {
        targetEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
      }

      if (targetEmployeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      String query =
        'SELECT Id, Name, Employees__c, ' +
        'Employees__r.Name, Employees__r.Designation__c, Employees__r.Department__c, ' +
        'Appraisal_Period__c, Start_Date__c, End_Date__c, Status__c, ' +
        'Overall_Rating__c, Self_Rating__c, Achievements__c, Feedback__c, ' +
        'Reviewers__c, Reviewer__r.Name, CreatedDate ' +
        'FROM PWChrono_Appraisal__c ' +
        'WHERE Employees__c = :targetEmployeeId ';

      if (statusFilter != null && statusFilter != 'All') {
        query += 'AND Status__c = :statusFilter ';
      }

      query +=
        ' ORDER BY Start_Date__c DESC LIMIT ' +
        PWChrono_Constants.DASHBOARD_QUERY_LIMIT;

      return Database.query(query);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching appraisals: '
      );
      ahe.setMessage('Error fetching appraisals: ');
      throw ahe;
    }
  }

  /**
   * @description Get team appraisals for review (manager view)
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return List of pending appraisals
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Appraisal__c> getTeamAppraisalsForReview(
    String employeeId
  ) {
    try {
      Id targetEmployeeId;
      if (String.isNotBlank(employeeId)) {
        targetEmployeeId = (Id) employeeId;
      } else {
        targetEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
      }

      if (targetEmployeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      return [
        SELECT
          Id,
          Name,
          Employees__c,
          Employees__r.Name,
          Appraisal_Period__c,
          Start_Date__c,
          End_Date__c,
          Status__c,
          Overall_Rating__c,
          Self_Rating__c,
          Achievements__c,
          Feedback__c,
          CreatedDate
        FROM PWChrono_Appraisal__c
        WHERE
          Reviewers__c = :targetEmployeeId
          AND Status__c = :PWChrono_Constants.STATUS_COMPLETED
        ORDER BY CreatedDate DESC
        LIMIT 50
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching team appraisals: '
      );
      ahe.setMessage('Error fetching team appraisals: ');
      throw ahe;
    }
  }

  /**
   * @description Save appraisal
   * @param appraisal Appraisal record
   * @return Saved appraisal
   */
  @AuraEnabled
  public static PWChrono_Appraisal__c saveAppraisal(
    PWChrono_Appraisal__c appraisal,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId;
      Id actorEmployeeId;

      if (UserInfo.getUserType() == 'Guest') {
        targetEmployeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
        actorEmployeeId = targetEmployeeId;
      } else {
        actorEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        targetEmployeeId = actorEmployeeId;
        if (
          String.isNotBlank(portalUserId) &&
          actorEmployeeId != null &&
          portalUserId != actorEmployeeId &&
          PWChrono_AccessController.isAdmin(actorEmployeeId)
        ) {
          targetEmployeeId = (Id) portalUserId;
        }
      }

      if (targetEmployeeId == null) {
        throw new AuraHandledException(
          'No employee record found for current user.'
        );
      }

      if (appraisal.Id == null) {
        appraisal.Employees__c = targetEmployeeId;
      } else {
        PWChrono_Appraisal__c existing = [
          SELECT Employees__c
          FROM PWChrono_Appraisal__c
          WHERE Id = :appraisal.Id
          LIMIT 1
        ];
        if (
          existing.Employees__c != targetEmployeeId &&
          (actorEmployeeId == null ||
          !PWChrono_AccessController.isAdmin(actorEmployeeId))
        ) {
          throw new AuraHandledException('Access Denied.');
        }
        // Do not allow changing Employees__c.
        appraisal.Employees__c = existing.Employees__c;
      }

      if (appraisal.Id == null) {
        insert appraisal;
      } else {
        update appraisal;
      }

      return [
        SELECT
          Id,
          Name,
          Employees__c,
          Appraisal_Period__c,
          Start_Date__c,
          End_Date__c,
          Status__c,
          Overall_Rating__c,
          Self_Rating__c,
          Achievements__c,
          Feedback__c
        FROM PWChrono_Appraisal__c
        WHERE Id = :appraisal.Id
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error saving appraisal: '
      );
      ahe.setMessage('Error saving appraisal: ');
      throw ahe;
    }
  }

  /**
   * @description Get goals for current employee
   * @param statusFilter Status filter
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return List of goals
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Goal__c> getMyGoals(
    String statusFilter,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId;
      if (UserInfo.getUserType() == 'Guest') {
        targetEmployeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          employeeId,
          sessionToken
        );
      } else if (String.isNotBlank(employeeId)) {
        Id currentEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        if (currentEmployeeId != null && employeeId != currentEmployeeId) {
          if (PWChrono_AccessController.isAdmin(currentEmployeeId)) {
            targetEmployeeId = (Id) employeeId;
          } else {
            targetEmployeeId = currentEmployeeId;
          }
        } else {
          targetEmployeeId = (Id) employeeId;
        }
      } else {
        targetEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
      }

      if (targetEmployeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      String query =
        'SELECT Id, Name, Employees__c, Description__c, ' +
        'Target_Date__c, Progress__c, Status__c, ' +
        'CreatedDate ' +
        'FROM PWChrono_Goal__c ' +
        'WHERE Employees__c = :targetEmployeeId ';

      if (statusFilter != null && statusFilter != 'All') {
        query += 'AND Status__c = :statusFilter ';
      }

      query +=
        ' ORDER BY Target_Date__c DESC LIMIT ' +
        PWChrono_Constants.DEFAULT_QUERY_LIMIT;

      return Database.query(query);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching goals: '
      );
      ahe.setMessage('Error fetching goals: ');
      throw ahe;
    }
  }

  /**
   * @description Save goal
   * @param goal Goal record
   * @return Saved goal
   */
  @AuraEnabled
  public static PWChrono_Goal__c saveGoal(
    PWChrono_Goal__c goal,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId;
      Id actorEmployeeId;

      if (UserInfo.getUserType() == 'Guest') {
        targetEmployeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
        actorEmployeeId = targetEmployeeId;
      } else {
        actorEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        targetEmployeeId = actorEmployeeId;
        if (
          String.isNotBlank(portalUserId) &&
          actorEmployeeId != null &&
          portalUserId != actorEmployeeId &&
          PWChrono_AccessController.isAdmin(actorEmployeeId)
        ) {
          targetEmployeeId = (Id) portalUserId;
        }
      }

      if (targetEmployeeId == null) {
        throw new AuraHandledException(
          'No employee record found for current user.'
        );
      }

      if (goal.Id == null) {
        goal.Employees__c = targetEmployeeId;
      } else {
        PWChrono_Goal__c existing = [
          SELECT Employees__c
          FROM PWChrono_Goal__c
          WHERE Id = :goal.Id
          LIMIT 1
        ];
        if (
          existing.Employees__c != targetEmployeeId &&
          (actorEmployeeId == null ||
          !PWChrono_AccessController.isAdmin(actorEmployeeId))
        ) {
          throw new AuraHandledException('Access Denied.');
        }
        // Do not allow changing Employees__c.
        goal.Employees__c = existing.Employees__c;
      }

      if (goal.Id == null) {
        insert goal;
      } else {
        update goal;
      }

      return [
        SELECT
          Id,
          Name,
          Employees__c,
          Description__c,
          Target_Date__c,
          Progress__c,
          Status__c
        FROM PWChrono_Goal__c
        WHERE Id = :goal.Id
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error saving goal: '
      );
      ahe.setMessage('Error saving goal: ');
      throw ahe;
    }
  }

  /**
   * @description Update goal progress
   * @param goalId Goal ID
   * @param progressPercentage New progress percentage
   * @param status New status
   * @return Updated goal
   */
  @AuraEnabled
  public static PWChrono_Goal__c updateGoalProgress(
    Id goalId,
    Decimal progressPercentage,
    String status,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId;
      Id actorEmployeeId;

      if (UserInfo.getUserType() == 'Guest') {
        targetEmployeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
        actorEmployeeId = targetEmployeeId;
      } else {
        actorEmployeeId = PWChrono_Utils.getCurrentEmployeeId(
          UserInfo.getUserId()
        );
        targetEmployeeId = actorEmployeeId;
        if (
          String.isNotBlank(portalUserId) &&
          actorEmployeeId != null &&
          portalUserId != actorEmployeeId &&
          PWChrono_AccessController.isAdmin(actorEmployeeId)
        ) {
          targetEmployeeId = (Id) portalUserId;
        }
      }

      PWChrono_Goal__c goal = [
        SELECT Id, Employees__c, Progress__c, Status__c
        FROM PWChrono_Goal__c
        WHERE Id = :goalId
        LIMIT 1
      ];

      if (
        targetEmployeeId != null &&
        goal.Employees__c != targetEmployeeId &&
        (actorEmployeeId == null ||
        !PWChrono_AccessController.isAdmin(actorEmployeeId))
      ) {
        throw new AuraHandledException('Access Denied.');
      }

      // Validate status transition - prevent updates to finalized goals
      if (
        goal.Status__c == PWChrono_Constants.STATUS_COMPLETED ||
        goal.Status__c == PWChrono_Constants.STATUS_CANCELLED
      ) {
        throw new AuraHandledException(
          'Cannot update finalized goals (Completed/Cancelled).'
        );
      }

      goal.Progress__c = progressPercentage;
      if (status != null) {
        goal.Status__c = status;
      }

      // Auto-complete if 100%
      if (progressPercentage >= 100) {
        goal.Status__c = PWChrono_Constants.STATUS_COMPLETED;
      }

      update goal;
      return goal;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error updating goal progress: '
      );
      ahe.setMessage('Error updating goal progress: ');
      throw ahe;
    }
  }
}