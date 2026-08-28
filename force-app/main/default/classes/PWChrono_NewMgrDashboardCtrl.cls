/**
 * @description Dashboard controller for the Manager role portal page.
 *              All SOQL runs in system context intentionally — guest user
 *              access is gated by session token validation before data is returned.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_NewMgrDashboardCtrl {
  /**
   * @description Returns manager dashboard data for the authenticated portal user.
   * @param portalUserId Id of the Portal_Users__c record for the requesting user
   * @param sessionToken Active session token for the requesting user
   * @return JSON string with welcome message and dashboard data
   */
  @AuraEnabled
  public static String getDashboardData(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      Id verifiedId = PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      Portal_Users__c caller = [
        SELECT Role__c
        FROM Portal_Users__c
        WHERE Id = :verifiedId
        LIMIT 1
      ];
      if (
        caller.Role__c != PWChrono_Constants.ROLE_MANAGER &&
        caller.Role__c != PWChrono_Constants.ROLE_HR_ADMIN
      ) {
        throw new AuraHandledException('Unauthorized.');
      }
    }
    // This is a placeholder.
    // In a real implementation, you would query data from Salesforce objects.
    return '{"message":"Welcome to the new Manager Dashboard"}';
  }
}