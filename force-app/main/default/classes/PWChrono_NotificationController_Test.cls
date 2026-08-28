@isTest
private class PWChrono_NotificationController_Test {
  @isTest
  static void testGetNotifications() {
    // Create test data
    TLG_Task_Notifications__c notification = new TLG_Task_Notifications__c(
      TLG_Notification_Title__c = 'Test Notification',
      TLG_Task_Detail__c = 'Test Message',
      TLG_Notified__c = false,
      OwnerId = UserInfo.getUserId()
    );
    insert notification;

    Test.startTest();
    List<PWChrono_NotificationController.NotificationWrapper> results = PWChrono_NotificationController.getNotifications(
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return 1 notification');
    System.assertEquals('Test Notification', results[0].Subject);
    System.assertEquals('Test Message', results[0].Message);
    System.assertEquals(false, results[0].IsRead);
  }

  @isTest
  static void testMarkAsRead() {
    TLG_Task_Notifications__c notification = new TLG_Task_Notifications__c(
      TLG_Notification_Title__c = 'Test Notification',
      TLG_Notified__c = false,
      OwnerId = UserInfo.getUserId()
    );
    insert notification;

    Test.startTest();
    PWChrono_NotificationController.markAsRead(notification.Id, null, null);
    Test.stopTest();

    TLG_Task_Notifications__c updated = [
      SELECT TLG_Notified__c
      FROM TLG_Task_Notifications__c
      WHERE Id = :notification.Id
    ];
    System.assertEquals(
      true,
      updated.TLG_Notified__c,
      'Notification should be marked as read'
    );
  }

  @isTest
  static void testMarkAllAsRead() {
    List<TLG_Task_Notifications__c> notifications = new List<TLG_Task_Notifications__c>();
    for (Integer i = 0; i < 3; i++) {
      notifications.add(
        new TLG_Task_Notifications__c(
          TLG_Notification_Title__c = 'Test ' + i,
          TLG_Notified__c = false,
          OwnerId = UserInfo.getUserId()
        )
      );
    }
    insert notifications;

    Test.startTest();
    PWChrono_NotificationController.markAllAsRead(null, null);
    Test.stopTest();

    List<TLG_Task_Notifications__c> updated = [
      SELECT Id
      FROM TLG_Task_Notifications__c
      WHERE TLG_Notified__c = TRUE
    ];
    System.assertEquals(
      3,
      updated.size(),
      'All notifications should be marked as read'
    );
  }
}