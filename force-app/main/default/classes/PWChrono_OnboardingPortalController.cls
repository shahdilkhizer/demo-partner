/**
 * Session-validated portal API for the employee onboarding checklist.
 */
public without sharing class PWChrono_OnboardingPortalController {
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Onboarding_Task__c> getOnboardingTasks(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_OnboardingController.getOnboardingTasks(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static void updateOnboardingTaskStatus(
    Id taskId,
    String status,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    PWChrono_OnboardingController.updateTaskStatus(
      taskId,
      status,
      portalUserId,
      sessionToken
    );
  }
}