/**
 * @description Controller for Training Registration LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_TrainingController {
  private static Id resolveCurrentEmployeeId(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      return (Id) PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
    }
    return PWChrono_Utils.getCurrentEmployeeId(UserInfo.getUserId());
  }

  /**
   * @description Get upcoming training events
   * @return List of training events with program details
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Training_Event__c> getUpcomingTrainings() {
    try {
      return [
        SELECT
          Id,
          Name,
          Start_Date__c,
          End_Date__c,
          Location__c,
          Status__c,
          Training_Program__r.Name,
          Training_Program__r.Description__c,
          Training_Program__r.Trainer__c,
          Training_Program__r.Duration_Hours__c
        FROM PWChrono_Training_Event__c
        WHERE
          Start_Date__c >= TODAY
          AND Status__c = :PWChrono_Constants.STATUS_SCHEDULED
        ORDER BY Start_Date__c ASC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching upcoming trainings: '
      );
      ahe.setMessage('Error fetching upcoming trainings: ');
      throw ahe;
    }
  }

  /**
   * @description Get my training registrations
   * @return List of attendance records
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Training_Attendance__c> getMyRegistrations(
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId = resolveCurrentEmployeeId(portalUserId, sessionToken);

      if (employeeId == null) {
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
          Training_Event__c,
          Training_Event__r.Name,
          Training_Event__r.Start_Date__c,
          Training_Event__r.End_Date__c,
          Training_Event__r.Location__c,
          Training_Event__r.Training_Program__r.Name,
          Attended__c,
          Feedback__c,
          Rating__c
        FROM PWChrono_Training_Attendance__c
        WHERE Employees__c = :employeeId
        ORDER BY Training_Event__r.Start_Date__c DESC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching registrations: '
      );
      ahe.setMessage('Error fetching registrations: ');
      throw ahe;
    }
  }

  /**
   * @description Register for a training event
   * @param eventId Training Event ID
   */
  @AuraEnabled
  public static void registerForTraining(
    Id eventId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId = resolveCurrentEmployeeId(portalUserId, sessionToken);

      if (employeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      // Check if already registered
      List<PWChrono_Training_Attendance__c> existing = [
        SELECT Id
        FROM PWChrono_Training_Attendance__c
        WHERE Employees__c = :employeeId AND Training_Event__c = :eventId
      ];

      if (!existing.isEmpty()) {
        AuraHandledException ahe = new AuraHandledException(
          'Already registered for this training.'
        );
        ahe.setMessage('Already registered for this training.');
        throw ahe;
      }

      PWChrono_Training_Attendance__c attendance = new PWChrono_Training_Attendance__c(
        Employees__c = employeeId,
        Training_Event__c = eventId
      );

      insert attendance;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error registering for training: '
      );
      ahe.setMessage('Error registering for training: ');
      throw ahe;
    }
  }

  /**
   * @description Cancel registration
   * @param attendanceId Attendance Record ID
   */
  @AuraEnabled
  public static void cancelRegistration(
    Id attendanceId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId = resolveCurrentEmployeeId(portalUserId, sessionToken);

      PWChrono_Training_Attendance__c attendance = [
        SELECT Id, Training_Event__r.Start_Date__c
        FROM PWChrono_Training_Attendance__c
        WHERE Id = :attendanceId AND Employees__c = :employeeId
        LIMIT 1
      ];

      if (attendance.Training_Event__r.Start_Date__c < Date.today()) {
        AuraHandledException ahe = new AuraHandledException(
          'Cannot cancel past trainings.'
        );
        ahe.setMessage('Cannot cancel past trainings.');
        throw ahe;
      }

      delete attendance;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error cancelling registration: '
      );
      ahe.setMessage('Error cancelling registration: ');
      throw ahe;
    }
  }
}