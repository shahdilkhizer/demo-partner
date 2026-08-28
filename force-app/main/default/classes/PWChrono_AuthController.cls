/**
 * @description Controller for Portal Authentication and session bootstrap
 * @author PWChrono Team
 */
@SuppressWarnings('PMD')
public inherited sharing class PWChrono_AuthController {
  /**
   * @description Returns portal user context for the currently authenticated Salesforce user.
   *              This supports running PWChrono as a Lightning App/Tab without requiring OTP.
   * @return Map with keys: user (Portal_Users__c), permissions (empty compatibility map)
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getCurrentUserContext() {
    try {
      // Guest users don't have a Salesforce user context we can map.
      if (UserInfo.getUserType() == 'Guest') {
        return new Map<String, Object>{ 'user' => null, 'permissions' => null };
      }

      Id userId = UserInfo.getUserId();
      List<Portal_Users__c> users = [
        SELECT Id, Name, Email__c, Role__c, Portal_User_Profile__c, User__c
        FROM Portal_Users__c
        WHERE User__c = :userId
        LIMIT 1
      ];

      if (users.isEmpty()) {
        return new Map<String, Object>{ 'user' => null, 'permissions' => null };
      }

      Portal_Users__c portalUser = users[0];
      return new Map<String, Object>{
        'user' => portalUser,
        'permissions' => new Map<String, Object>()
      };
    } catch (Exception e) {
      PWChrono_Logger.error('Failed to build current user context.', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error building user context.'
      );
      ahe.setMessage('Error building user context.');
      throw ahe;
    }
  }

  /**
   * @description Sends an OTP to the user's email
   * @param email The email address of the user
   * @return String 'Success' if email sent, or OTP code in dev mode
   */
  @AuraEnabled(cacheable=false)
  public static String sendOTP(String email) {
    try {
      Portal_Users__c user = validateAndGetUserForOTP(email);

      // Secure OTP Generation - 6 digit code
      Integer randomInt = Crypto.getRandomInteger();
      String otp = String.valueOf(
        Math.mod(Math.abs(randomInt), 900000) + 100000
      );

      // Store OTP
      user.One_Time_Password__c = otp;
      user.OTP_Generated_Time__c = System.now();

      // Save OTP to database first
      try {
        new PortalUserLookup().updatePortalUser(user);
      } catch (Exception updateEx) {
        PWChrono_Logger.error('Failed to persist OTP fields.', updateEx);
        throw new IllegalArgumentException(
          'Could not save OTP: ' + getDmlErrorMessage(updateEx)
        );
      }

      // Send OTP via email
      Boolean emailSent = sendOTPEmail(email, otp);

      if (emailSent) {
        return 'Success';
      } else {
        // Email failed but OTP is stored - return indicator for debugging
        PWChrono_Logger.warn('OTP stored but email delivery failed.');
        return 'Success_NoEmail';
      }
    } catch (IllegalArgumentException iae) {
      throw new AuraHandledException(iae.getMessage());
    } catch (Exception e) {
      PWChrono_Logger.error('Unhandled sendOTP error.', e);
      throw new AuraHandledException('An error occurred while sending OTP.');
    }
  }

  private static Portal_Users__c validateAndGetUserForOTP(String email) {
    if (String.isBlank(email)) {
      throw new IllegalArgumentException('Email cannot be empty.');
    }

    email = normalizeEmail(email);
    Portal_Users__c user = getUserByEmail(email);

    if (user == null) {
      throw new IllegalArgumentException(
        'Invalid email or password. Please try again.'
      );
    }

    checkRateLimiting(user);

    return user;
  }

  private static void checkRateLimiting(Portal_Users__c user) {
    // Rate Limiting: Check if OTP was generated recently (e.g., last 1 minute)
    if (
      user.OTP_Generated_Time__c != null &&
      user.OTP_Generated_Time__c >
      System.now().addMinutes(-PWChrono_Constants.OTP_RESEND_COOLDOWN_MINUTES)
    ) {
      throw new IllegalArgumentException(
        'Please wait before requesting another OTP.'
      );
    }
  }

  private static Boolean sendOTPEmail(String email, String otp) {
    Boolean emailSent = false;
    try {
      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setToAddresses(new List<String>{ email });
      mail.setSubject('Your PWChrono Login Code');
      mail.setPlainTextBody(
        'Your one-time password (OTP) for PWChrono Portal login is: ' +
          otp +
          '\n\n' +
          'This code will expire in ' +
          PWChrono_Constants.OTP_EXPIRATION_MINUTES +
          ' minutes.\n\n' +
          'If you did not request this code, please ignore this email.'
      );
      mail.setHtmlBody(
        '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">' +
          '<h2 style="color: #4e73df;">PWChrono Portal</h2>' +
          '<p>Your one-time password (OTP) for login is:</p>' +
          '<div style="background: #f8f9fc; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">' +
          '<span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #4e73df;">' +
          otp +
          '</span>' +
          '</div>' +
          '<p style="color: #666;">This code will expire in ' +
          PWChrono_Constants.OTP_EXPIRATION_MINUTES +
          ' minutes.</p>' +
          '<p style="color: #999; font-size: 12px;">If you did not request this code, please ignore this email.</p>' +
          '</div>'
      );

      Messaging.SendEmailResult[] results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ mail }
      );

      if (results[0].isSuccess()) {
        emailSent = true;
        PWChrono_Logger.info('OTP email sent successfully.');
      } else {
        for (Messaging.SendEmailError err : results[0].getErrors()) {
          PWChrono_Logger.warn(
            'OTP email error: ' + err.getStatusCode() + ' - ' + err.getMessage()
          );
        }
      }
    } catch (Exception emailEx) {
      PWChrono_Logger.error('OTP email send exception.', emailEx);
    }
    return emailSent;
  }

  /**
   * @description Verify OTP and authenticate user
   * @param email The email address of the user
   * @param otp The OTP entered by the user
   * @return Portal_Users__c The authenticated user record
   */
  @AuraEnabled(cacheable=false)
  public static Portal_Users__c verifyOTP(String email, String otp) {
    try {
      email = normalizeEmail(email);
      otp = String.isBlank(otp) ? otp : otp.replaceAll('[^0-9]', '');

      Portal_Users__c user = getUserByEmail(email);

      if (user == null) {
        throw new IllegalArgumentException('User not found.');
      }

      validateOTP(user, otp);

      // Issue a server-side session token for Guest runtime.
      // This allows subsequent Apex calls (DML) to validate identity without trusting client-supplied IDs.
      String raw =
        String.valueOf(user.Id) +
        ':' +
        String.valueOf(System.now().getTime()) +
        ':' +
        String.valueOf(Crypto.getRandomLong());
      String token = EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(raw))
      );
      user.Session_Token__c = token;
      user.Session_Expires_At__c = System.now()
        .addMinutes(PWChrono_Constants.PORTAL_SESSION_EXPIRATION_MINUTES);
      user.Session_Failed_Attempts__c = 0;
      user.Session_Locked_Until__c = null;
      user.Is_Verification__c = true;

      // Clear OTP after successful login
      user.One_Time_Password__c = null;
      user.OTP_Generated_Time__c = null;
      new PortalUserLookup().updatePortalUser(user); // NOPMD - Auth bypass

      return user;
    } catch (IllegalArgumentException iae) {
      throw new AuraHandledException(iae.getMessage());
    } catch (Exception e) {
      PWChrono_Logger.error('Unhandled verifyOTP error.', e);
      throw new AuraHandledException('An error occurred during verification.');
    }
  }

  private static void validateOTP(Portal_Users__c user, String otp) {
    // Compare provided OTP with stored OTP
    if (user.One_Time_Password__c != otp) {
      user.One_Time_Password__c = null;
      user.OTP_Generated_Time__c = System.now();
      new PortalUserLookup().updatePortalUser(user);
      throw new IllegalArgumentException(
        'Invalid OTP. Please request a new code.'
      );
    }

    // Check for OTP expiration (10 minutes)
    if (
      user.OTP_Generated_Time__c == null ||
      user.OTP_Generated_Time__c.addMinutes(
        PWChrono_Constants.OTP_EXPIRATION_MINUTES
      ) < System.now()
    ) {
      throw new IllegalArgumentException(
        'OTP has expired. Please request a new one.'
      );
    }
  }

  /**
   * @description Retrieves permissions for the given profile
   * @param profileId The ID of the Portal_User_Profile__c
   * @return Map<String, Object> A map of object and field permissions
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getPermissions(String profileId) {
    Map<String, Object> permissions = new Map<String, Object>();

    List<Portal_Object_Permission__c> perms = [
      // NOPMD
      SELECT
        Id,
        Portal_Object__c,
        Portal_Object__r.Name,
        Can_Create__c,
        Can_View__c,
        Can_Edit__c,
        Can_Delete__c
      FROM Portal_Object_Permission__c
      WHERE Portal_User_Profile__c = :profileId
    ]; // NOPMD - Auth bypass

    Set<Id> objectIds = new Set<Id>();
    for (Portal_Object_Permission__c p : perms) {
      objectIds.add(p.Portal_Object__c);
    }

    for (Portal_Object_Permission__c p : perms) {
      Map<String, Object> objPerms = new Map<String, Object>();
      objPerms.put('create', p.Can_Create__c);
      objPerms.put('read', p.Can_View__c);
      objPerms.put('edit', p.Can_Edit__c);
      objPerms.put('delete', p.Can_Delete__c);
      objPerms.put('fields', new Map<String, Object>());

      permissions.put(p.Portal_Object__r.Name, objPerms);
    }

    // Field Permissions
    List<Portal_Field_Permission__c> fieldPerms = [
      // NOPMD
      SELECT
        Portal_Object_Field__r.Field_API_Name__c,
        Portal_Object_Field__r.Portal_Object__r.Name,
        Can_View__c,
        Can_Edit__c
      FROM Portal_Field_Permission__c
      WHERE
        Portal_User_Profile__c = :profileId
        AND Portal_Object_Field__r.Portal_Object__c IN :objectIds
    ]; // NOPMD - Auth bypass

    for (Portal_Field_Permission__c fp : fieldPerms) {
      // NOPMD
      String objName = fp.Portal_Object_Field__r.Portal_Object__r.Name;
      String fieldName = fp.Portal_Object_Field__r.Field_API_Name__c;

      if (String.isBlank(fieldName)) {
        fieldName = 'Unknown_Field';
      }

      if (permissions.containsKey(objName)) {
        Map<String, Object> objPermMap = (Map<String, Object>) permissions.get(
          objName
        );
        Map<String, Object> fieldsMap = (Map<String, Object>) objPermMap.get(
          'fields'
        );

        fieldsMap.put(
          fieldName,
          new Map<String, Object>{
            'read' => fp.Can_View__c,
            'edit' => fp.Can_Edit__c
          }
        );
      }
    }

    return permissions;
  }

  /**
   * @description Helper method to get user by email
   * @param email The email address of the user
   * @return Portal_Users__c The user record or null if not found
   */
  private static Portal_Users__c getUserByEmail(String email) {
    if (String.isBlank(email)) {
      return null;
    }

    return new PortalUserLookup().getActiveUserByEmail(email);
  }

  private static String normalizeEmail(String email) {
    return String.isBlank(email) ? email : email.trim().toLowerCase();
  }

  private static String getDmlErrorMessage(Exception ex) {
    if (ex instanceof DmlException) {
      DmlException dmlEx = (DmlException) ex;
      if (dmlEx.getNumDml() > 0) {
        return dmlEx.getDmlMessage(0);
      }
    }

    String message = ex.getMessage();
    return String.isBlank(message) ? 'Unknown DML error' : message;
  }

  private without sharing class PortalUserLookup {
    private Portal_Users__c getActiveUserByEmail(String email) {
      List<Portal_Users__c> users = [
        // NOPMD
        SELECT
          Id,
          Name,
          Email__c,
          Role__c,
          Portal_User_Profile__c,
          Portal_User_Profile__r.Name,
          One_Time_Password__c,
          OTP_Generated_Time__c,
          Session_Token__c,
          Session_Expires_At__c,
          Is_Verification__c,
          Is_Active__c
        FROM Portal_Users__c
        WHERE Email__c = :email AND Is_Active__c = TRUE
        ORDER BY LastModifiedDate DESC
        LIMIT 1
      ]; // NOPMD - Auth bypass

      return users.isEmpty() ? null : users[0];
    }

    private void updatePortalUser(Portal_Users__c user) {
      update user;
    }
  }
}