public inherited sharing class PWChrono_NotificationController {
  private static Id resolveNotificationOwnerUserId(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return UserInfo.getUserId();
    }

    Id verifiedPortalUserId = (Id) PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );

    Portal_Users__c pu = [
      SELECT User__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];

    return pu.User__c;
  }

  @AuraEnabled(cacheable=true)
  public static List<NotificationWrapper> getNotifications(
    String portalUserId,
    String sessionToken
  ) {
    Id ownerUserId = resolveNotificationOwnerUserId(portalUserId, sessionToken);
    if (ownerUserId == null) {
      return new List<NotificationWrapper>();
    }

    List<TLG_Task_Notifications__c> records = [
      SELECT
        Id,
        TLG_Notification_Title__c,
        TLG_Task_Detail__c,
        TLG_Notified__c,
        CreatedDate,
        TLG_Tasks__c,
        TLG_Task_Category__c
      FROM TLG_Task_Notifications__c
      WHERE OwnerId = :ownerUserId
      ORDER BY CreatedDate DESC
      LIMIT 15
    ];

    List<NotificationWrapper> notifications = new List<NotificationWrapper>();
    for (TLG_Task_Notifications__c record : records) {
      NotificationWrapper wrapper = new NotificationWrapper();
      wrapper.Id = record.Id;
      wrapper.Subject = record.TLG_Notification_Title__c;
      wrapper.Message = record.TLG_Task_Detail__c;
      wrapper.IsRead = record.TLG_Notified__c;
      wrapper.CreatedDate = record.CreatedDate;
      wrapper.TargetURL = record.TLG_Tasks__c != null
        ? '/' + record.TLG_Tasks__c
        : '';
      wrapper.Type = record.TLG_Task_Category__c;
      notifications.add(wrapper);
    }
    return notifications;
  }

  @AuraEnabled
  public static void markAsRead(
    String notificationId,
    String portalUserId,
    String sessionToken
  ) {
    Id ownerUserId = resolveNotificationOwnerUserId(portalUserId, sessionToken);
    if (ownerUserId == null) {
      throw new AuraHandledException('Unauthorized.');
    }

    TLG_Task_Notifications__c notification = [
      SELECT Id, TLG_Notified__c
      FROM TLG_Task_Notifications__c
      WHERE Id = :notificationId AND OwnerId = :ownerUserId
    ];
    notification.TLG_Notified__c = true;
    update notification;
  }

  @AuraEnabled
  public static void markAllAsRead(String portalUserId, String sessionToken) {
    Id ownerUserId = resolveNotificationOwnerUserId(portalUserId, sessionToken);
    if (ownerUserId == null) {
      throw new AuraHandledException('Unauthorized.');
    }

    List<TLG_Task_Notifications__c> notificationsToUpdate = [
      SELECT Id, TLG_Notified__c
      FROM TLG_Task_Notifications__c
      WHERE OwnerId = :ownerUserId AND TLG_Notified__c = FALSE
    ];

    for (TLG_Task_Notifications__c notification : notificationsToUpdate) {
      notification.TLG_Notified__c = true;
    }

    if (!notificationsToUpdate.isEmpty()) {
      update notificationsToUpdate;
    }
  }

  public class NotificationWrapper {
    @AuraEnabled
    public String Id;
    @AuraEnabled
    public String Subject;
    @AuraEnabled
    public String Message;
    @AuraEnabled
    public Boolean IsRead;
    @AuraEnabled
    public DateTime CreatedDate;
    @AuraEnabled
    public String TargetURL;
    @AuraEnabled
    public String Type;
  }
}