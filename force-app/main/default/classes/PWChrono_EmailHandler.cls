/**
 * @description Helper class for sending emails
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_EmailHandler {
  /**
   * @description Looks up an active Lightning Email Template by its DeveloperName.
   *              Returns null if the template is not found or if the running user
   *              does not have access to the EmailTemplate object (e.g. Guest user).
   */
  public static Id getEmailTemplateId(String developerName) {
    if (String.isBlank(developerName)) {
      return null;
    }
    try {
      List<EmailTemplate> templates = [
        SELECT Id
        FROM EmailTemplate
        WHERE DeveloperName = :developerName AND IsActive = TRUE
        LIMIT 1
      ];
      return templates.isEmpty() ? null : templates[0].Id;
    } catch (Exception ex) {
      PWChrono_Logger.warn(
        'Could not load email template "' +
          developerName +
          '": ' +
          ex.getMessage()
      );
      return null;
    }
  }

  /**
   * @description Sets the 'Pulse Work Chrono' org-wide email address as the verified
   *              sender on the given message. Falls back to any profile-wide OWA if the
   *              named address is not found. Logs a warning and continues if none exists.
   */
  public static void applyOrgWideEmailAddress(
    Messaging.SingleEmailMessage mail
  ) {
    try {
      List<OrgWideEmailAddress> owas = [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE DisplayName = 'Pulse Work Chrono'
        LIMIT 1
      ];
      if (owas.isEmpty()) {
        owas = [
          SELECT Id
          FROM OrgWideEmailAddress
          WHERE IsAllowAllProfiles = TRUE
          LIMIT 1
        ];
      }
      if (!owas.isEmpty()) {
        mail.setOrgWideEmailAddressId(owas[0].Id);
      } else {
        PWChrono_Logger.warn(
          'No org-wide email address found. Email may be sent from system address.'
        );
      }
    } catch (Exception ex) {
      PWChrono_Logger.warn(
        'Could not apply org-wide email address: ' + ex.getMessage()
      );
    }
  }

  public static void sendAppraisalNotifications(
    List<PWChrono_Appraisal__c> appraisals
  ) {
    Set<Id> appraisalIds = new Set<Id>();
    for (PWChrono_Appraisal__c app : appraisals) {
      appraisalIds.add(app.Id);
    }

    List<PWChrono_Appraisal_Notification__c> recipients = [
      SELECT
        Id,
        Appraisal__c,
        Portal_User__c,
        Portal_User__r.Email__c,
        Portal_User__r.Contact__c,
        Email__c,
        Role__c
      FROM PWChrono_Appraisal_Notification__c
      WHERE Appraisal__c IN :appraisalIds
    ];

    if (recipients.isEmpty()) {
      return;
    }

    Id templateId = getEmailTemplateId('PWChrono_Appraisal_Notification');

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

    for (PWChrono_Appraisal_Notification__c recipient : recipients) {
      String emailAddress = recipient.Email__c;
      if (String.isBlank(emailAddress) && recipient.Portal_User__c != null) {
        emailAddress = recipient.Portal_User__r.Email__c;
      }

      if (String.isNotBlank(emailAddress)) {
        Id contactId = recipient.Portal_User__r?.Contact__c;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ emailAddress });

        if (templateId != null) {
          mail.setTemplateId(templateId);
          mail.setWhatId(recipient.Appraisal__c);
          if (contactId != null) {
            mail.setTargetObjectId(contactId);
            mail.setSaveAsActivity(true);
          } else {
            mail.setSaveAsActivity(false);
          }
        } else {
          mail.setSubject('Appraisal Update Notification');
          mail.setPlainTextBody(
            'An appraisal you are following has been updated. Role: ' +
            recipient.Role__c
          );
          mail.setSaveAsActivity(false);
        }

        applyOrgWideEmailAddress(mail);
        emails.add(mail);
      }
    }

    if (!emails.isEmpty()) {
      Messaging.sendEmail(emails);
    }
  }
}