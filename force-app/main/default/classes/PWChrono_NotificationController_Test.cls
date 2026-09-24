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

  @isTest
  static void testGuestNotificationsRequireMatchingToken() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Notification Owner',
      Email__c = 'notification@example.com',
      Is_Active__c = true,
      Portal_User_Profile__c = profile.Id,
      User__c = UserInfo.getUserId(),
      Session_Token__c = 'notification-token',
      Session_Expires_At__c = System.now().addHours(1)
    );
    insert employee;
    TLG_Task_Notifications__c notification = new TLG_Task_Notifications__c(
      TLG_Notification_Title__c = 'Private notification',
      TLG_Notified__c = false,
      OwnerId = UserInfo.getUserId()
    );
    insert notification;
    PWChrono_NotificationController.testUserTypeOverride = 'Guest';
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      System.assertEquals(
        1,
        PWChrono_NotificationController.getRecentNotifications(
            String.valueOf(employee.Id),
            'notification-token'
          )
          .size()
      );
      Boolean rejected = false;
      try {
        PWChrono_NotificationController.markAllAsRead(
          String.valueOf(employee.Id),
          'wrong-token'
        );
      } catch (AuraHandledException expected) {
        rejected = true;
      }
      System.assert(
        rejected,
        'Invalid credentials must not update notifications'
      );
      notification = [
        SELECT TLG_Notified__c
        FROM TLG_Task_Notifications__c
        WHERE Id = :notification.Id
      ];
      System.assertEquals(false, notification.TLG_Notified__c);
      PWChrono_NotificationController.markAsRead(
        String.valueOf(notification.Id),
        String.valueOf(employee.Id),
        'notification-token'
      );
      notification = [
        SELECT TLG_Notified__c
        FROM TLG_Task_Notifications__c
        WHERE Id = :notification.Id
      ];
      System.assertEquals(true, notification.TLG_Notified__c);
    } finally {
      PWChrono_NotificationController.testUserTypeOverride = null;
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  @isTest
  static void testNotificationOwnershipIsolation() {
    PWChrono_TestDataFactory.createTestUsers();
    User otherUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(new User(Id = UserInfo.getUserId())) {
      TLG_Task_Notifications__c mine = new TLG_Task_Notifications__c(
        TLG_Notification_Title__c = 'Mine',
        TLG_Notified__c = false,
        OwnerId = UserInfo.getUserId()
      );
      TLG_Task_Notifications__c other = new TLG_Task_Notifications__c(
        TLG_Notification_Title__c = 'Other',
        TLG_Notified__c = false,
        OwnerId = otherUser.Id
      );
      insert new List<TLG_Task_Notifications__c>{ mine, other };
      List<PWChrono_NotificationController.NotificationWrapper> visible = PWChrono_NotificationController.getRecentNotifications(
        null,
        null
      );
      System.assertEquals(1, visible.size());
      System.assertEquals(mine.Id, visible[0].Id);
      Boolean denied = false;
      try {
        PWChrono_NotificationController.markAsRead(
          String.valueOf(other.Id),
          null,
          null
        );
      } catch (QueryException expected) {
        denied = true;
      }
      System.assert(denied, 'Cannot mark another owner notification as read');
      PWChrono_NotificationController.markAllAsRead(null, null);
      other = [
        SELECT TLG_Notified__c
        FROM TLG_Task_Notifications__c
        WHERE Id = :other.Id
      ];
      System.assertEquals(false, other.TLG_Notified__c);
    }
  }
}