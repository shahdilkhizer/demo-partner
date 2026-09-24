/**
 * @description Utility for validating a portal user's session in Guest runtime.
 *              This keeps Guest DML possible while ensuring the caller proves
 *              they have a valid, server-issued session token.
 */
public without sharing class PWChrono_GuestSession {
  @TestVisible
  private static String testUserTypeOverride;
  @TestVisible
  private static Datetime testNowOverride;

  /** Revoke only the presented token, never a newer session issued after it. */
  public static void revokeSession(String portalUserId, String sessionToken) {
    if (String.isBlank(portalUserId) || String.isBlank(sessionToken))
      return;
    Id pid;
    try {
      pid = (Id) portalUserId;
    } catch (Exception e) {
      throw handledException('Session invalid.');
    }
    List<Portal_Users__c> users = [
      SELECT Id, Session_Token__c, Session_Expires_At__c
      FROM Portal_Users__c
      WHERE Id = :pid
      LIMIT 1
      FOR UPDATE
    ];
    if (
      users.isEmpty() ||
      users[0].Session_Token__c == null ||
      !users[0].Session_Token__c.equals(sessionToken)
    )
      return;
    users[0].Session_Token__c = null;
    users[0].Session_Expires_At__c = null;
    update users[0];
  }

  /**
   * @description Resolve the effective portal user Id for the current context.
   *              - Non-Guest: uses provided portalUserId if present, otherwise maps current Salesforce user.
   *              - Guest: requires portalUserId + sessionToken and validates against Portal_Users__c.
   */
  public static Id requireVerifiedPortalUserId(
    String portalUserId,
    String sessionToken
  ) {
    // Internal Salesforce users or authenticated Experience users.
    if (currentUserType() != 'Guest') {
      if (String.isNotBlank(portalUserId)) {
        try {
          return (Id) portalUserId;
        } catch (Exception e) {
          throw handledException('Session invalid.');
        }
      }
      return PWChrono_Utils.getCurrentEmployeeId(UserInfo.getUserId());
    }

    // Guest runtime MUST prove identity with a server-issued token.
    if (String.isBlank(portalUserId) || String.isBlank(sessionToken)) {
      throw handledException(
        'Session invalid or expired. Please log in again.'
      );
    }

    Id pid;
    try {
      pid = (Id) portalUserId;
    } catch (Exception e) {
      throw handledException('Session invalid.');
    }

    List<Portal_Users__c> users = [
      SELECT
        Id,
        Is_Active__c,
        Session_Token__c,
        Session_Expires_At__c,
        Session_Failed_Attempts__c,
        Session_Locked_Until__c
      FROM Portal_Users__c
      WHERE Id = :pid
      LIMIT 1
    ];

    if (users.isEmpty()) {
      throw handledException('Session invalid.');
    }

    Portal_Users__c u = users[0];
    if (u.Is_Active__c != true) {
      throw handledException('Account is inactive.');
    }

    if (
      u.Session_Locked_Until__c != null &&
      u.Session_Locked_Until__c > currentNow()
    ) {
      throw handledException(
        'Too many invalid session attempts. Please try again later.'
      );
    }

    if (String.isBlank(u.Session_Token__c) || u.Session_Expires_At__c == null) {
      throw handledException('Session expired. Please log in again.');
    }

    if (u.Session_Expires_At__c <= currentNow()) {
      clearSessionValidationState(u);
      throw handledException('Session expired. Please log in again.');
    }

    if (u.Session_Token__c != sessionToken) {
      registerFailedSessionAttempt(u);
      throw handledException('Session invalid. Please log in again.');
    }

    clearSessionValidationState(u);

    return u.Id;
  }

  /**
   * @description Resolve feature access for a verified OTP portal session.
   *              This method intentionally runs in this without-sharing security
   *              utility because Portal Users and their profile children use a
   *              private external sharing model. Identity is verified before
   *              any access configuration is returned.
   */
  public static Map<String, Object> getVerifiedUserAccess(
    String portalUserId,
    String sessionToken
  ) {
    Id verifiedPortalUserId = requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );

    return PWChrono_AccessController.getVerifiedPortalUserAccess(
      verifiedPortalUserId
    );
  }

  @TestVisible
  private static void registerFailedSessionAttempt(Portal_Users__c userRecord) {
    if (Limits.getLimitDmlStatements() == 0) {
      return;
    }

    Integer attempts = (userRecord.Session_Failed_Attempts__c == null)
      ? 0
      : Integer.valueOf(userRecord.Session_Failed_Attempts__c);
    attempts++;

    userRecord.Session_Failed_Attempts__c = attempts;
    if (attempts >= PWChrono_Constants.PORTAL_SESSION_MAX_FAILED_ATTEMPTS) {
      userRecord.Session_Failed_Attempts__c = 0;
      userRecord.Session_Locked_Until__c = currentNow()
        .addMinutes(PWChrono_Constants.PORTAL_SESSION_LOCKOUT_MINUTES);
      userRecord.Session_Token__c = null;
      userRecord.Session_Expires_At__c = null;
    }
    update userRecord;
  }

  @TestVisible
  private static void clearSessionValidationState(Portal_Users__c userRecord) {
    if (Limits.getLimitDmlStatements() == 0) {
      return;
    }

    if (
      userRecord.Session_Failed_Attempts__c == null &&
      userRecord.Session_Locked_Until__c == null
    ) {
      return;
    }

    userRecord.Session_Failed_Attempts__c = 0;
    userRecord.Session_Locked_Until__c = null;
    update userRecord;
  }

  private static AuraHandledException handledException(String message) {
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(message);
    return ex;
  }

  private static String currentUserType() {
    return Test.isRunningTest() && testUserTypeOverride != null
      ? testUserTypeOverride
      : UserInfo.getUserType();
  }

  private static Datetime currentNow() {
    return Test.isRunningTest() && testNowOverride != null
      ? testNowOverride
      : System.now();
  }
}