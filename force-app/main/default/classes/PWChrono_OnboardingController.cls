/**
 * @description Controller for Onboarding Management LWC Components
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_OnboardingController {
  /**
   * @description Get onboarding tasks for the current user
   * @return List of onboarding tasks
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Onboarding_Task__c> getOnboardingTasks(
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId;
      if (UserInfo.getUserType() == 'Guest') {
        employeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
      } else {
        Id currentUserId = UserInfo.getUserId();
        employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);
      }

      if (employeeId == null) {
        return new List<PWChrono_Onboarding_Task__c>();
      }

      return [
        SELECT Id, Name, Description__c, Status__c, Due_Date__c, Is_Mandatory__c
        FROM PWChrono_Onboarding_Task__c
        WHERE Assigned_Tos__c = :employeeId
        ORDER BY Due_Date__c ASC, Name ASC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching onboarding tasks: '
      );
      ahe.setMessage('Error fetching onboarding tasks: ');
      throw ahe;
    }
  }

  /**
   * @description Update task status
   * @param taskId Task ID
   * @param status New Status
   */
  @AuraEnabled
  public static void updateTaskStatus(
    Id taskId,
    String status,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId;
      if (UserInfo.getUserType() == 'Guest') {
        employeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
      } else {
        Id currentUserId = UserInfo.getUserId();
        employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);
      }

      List<PWChrono_Onboarding_Task__c> tasks = [
        SELECT Id, Status__c
        FROM PWChrono_Onboarding_Task__c
        WHERE Id = :taskId AND Assigned_Tos__c = :employeeId
        LIMIT 1
      ];

      if (tasks.isEmpty()) {
        throw new AuraHandledException(
          'Task not found or you do not have permission to update it.'
        );
      }

      PWChrono_Onboarding_Task__c task = tasks[0];
      task.Status__c = status;
      update task;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error updating task status: '
      );
      ahe.setMessage('Error updating task status: ');
      throw ahe;
    }
  }
}