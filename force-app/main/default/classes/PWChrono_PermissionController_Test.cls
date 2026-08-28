@IsTest
private class PWChrono_PermissionController_Test {
  @IsTest
  static void getPortalUsersForProfile_returnsAssignedUsers() {
    // Arrange
    // Name may be auto-number on this object in some orgs; avoid setting it in tests.
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;

    Portal_Users__c u1 = new Portal_Users__c(
      Name = 'Alice Admin',
      Email__c = 'alice@example.com',
      Is_Active__c = true,
      Portal_User_Profile__c = profile.Id
    );
    Portal_Users__c u2 = new Portal_Users__c(
      Name = 'Bob User',
      Email__c = 'bob@example.com',
      Is_Active__c = false,
      Portal_User_Profile__c = profile.Id
    );
    insert new List<Portal_Users__c>{ u1, u2 };

    Test.startTest();
    List<PWChrono_PermissionController.PortalUserRow> rows = PWChrono_PermissionController.getPortalUsersForProfile(
      profile.Id,
      null,
      null
    );
    Test.stopTest();

    // Assert
    System.assertEquals(
      2,
      rows.size(),
      'Should return portal users assigned to the profile'
    );
    System.assertNotEquals(null, rows[0].id, 'Row should include id');
    System.assertNotEquals(null, rows[0].name, 'Row should include name');
  }

  @IsTest
  static void getPortalUsersForProfile_nullProfile_returnsEmpty() {
    Test.startTest();
    List<PWChrono_PermissionController.PortalUserRow> rows = PWChrono_PermissionController.getPortalUsersForProfile(
      null,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(
      0,
      rows.size(),
      'Null profileId should return empty list'
    );
  }

  @IsTest
  static void getProfilePermissions_mergesExistingAndDefaults() {
    // Arrange
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;

    // Name may be auto-number on Portal_Object__c; avoid setting it directly.
    // Try to create an object without Object_API_Name__c to exercise the Name fallback; if not allowed,
    // fall back to setting Object_API_Name__c.
    Portal_Object__c objA = new Portal_Object__c(
      Object_API_Name__c = 'Portal_Users__c'
    );
    insert objA;

    Portal_Object__c objB;
    try {
      objB = new Portal_Object__c();
      insert objB;
    } catch (DmlException e) {
      objB = new Portal_Object__c(Object_API_Name__c = 'Time_Entries__c');
      insert objB;
    }

    // Re-query to ensure we have the same values the controller will read (auto-number Name, etc.)
    objB = [
      SELECT Id, Name, Object_API_Name__c
      FROM Portal_Object__c
      WHERE Id = :objB.Id
      LIMIT 1
    ];

    Portal_Object_Permission__c existing = new Portal_Object_Permission__c(
      Portal_User_Profile__c = profile.Id,
      Portal_Object__c = objA.Id,
      Can_View__c = true,
      Can_Create__c = false,
      Can_Edit__c = true,
      Can_Delete__c = false
    );
    insert existing;

    Test.startTest();
    List<PWChrono_PermissionController.PermissionWrapper> perms = PWChrono_PermissionController.getProfilePermissions(
      profile.Id,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(
      2,
      perms.size(),
      'Should return wrappers for all portal objects'
    );

    Map<String, PWChrono_PermissionController.PermissionWrapper> byApi = new Map<String, PWChrono_PermissionController.PermissionWrapper>();
    Set<String> keys = new Set<String>();
    for (PWChrono_PermissionController.PermissionWrapper w : perms) {
      byApi.put(w.objectApiName, w);
      keys.add(w.objectApiName);
    }

    System.assert(
      byApi.containsKey('Portal_Users__c'),
      'Should include explicit API name object'
    );
    System.assertEquals(
      true,
      byApi.get('Portal_Users__c').isAssigned,
      'Existing permission should be assigned'
    );
    System.assertEquals(true, byApi.get('Portal_Users__c').canView);
    System.assertEquals(true, byApi.get('Portal_Users__c').canEdit);

    String objBKey = String.isNotBlank(objB.Object_API_Name__c)
      ? objB.Object_API_Name__c
      : objB.Name;
    System.assert(
      byApi.containsKey(objBKey),
      'Should include second portal object. Keys seen: ' +
      String.join(new List<String>(keys), ', ')
    );
    System.assertEquals(
      false,
      byApi.get(objBKey).isAssigned,
      'Missing permission should default to unassigned'
    );
    System.assertEquals(false, byApi.get(objBKey).canView);
  }

  @IsTest
  static void saveProfilePermissions_upsertsAndDeletes() {
    // Arrange
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;

    Portal_Object__c objA = new Portal_Object__c(
      Object_API_Name__c = 'Obj_A__c'
    );
    insert objA;

    Portal_Object__c objB;
    try {
      objB = new Portal_Object__c();
      insert objB;
    } catch (DmlException e) {
      objB = new Portal_Object__c(Object_API_Name__c = 'Obj_B__c');
      insert objB;
    }

    // Re-query to ensure we have the values the controller will map on.
    objB = [
      SELECT Id, Name, Object_API_Name__c
      FROM Portal_Object__c
      WHERE Id = :objB.Id
      LIMIT 1
    ];

    Portal_Object_Permission__c permA = new Portal_Object_Permission__c(
      Portal_User_Profile__c = profile.Id,
      Portal_Object__c = objA.Id,
      Can_View__c = true,
      Can_Create__c = true,
      Can_Edit__c = false,
      Can_Delete__c = false
    );
    insert permA;

    // Delete objA permission, add objB permission
    PWChrono_PermissionController.PermissionWrapper wDelete = new PWChrono_PermissionController.PermissionWrapper();
    wDelete.id = permA.Id;
    wDelete.objectName = 'Obj_A__c';
    wDelete.objectApiName = 'Obj_A__c';
    wDelete.isAssigned = false;

    PWChrono_PermissionController.PermissionWrapper wUpsert = new PWChrono_PermissionController.PermissionWrapper();
    wUpsert.id = null;
    String objBKey = String.isNotBlank(objB.Object_API_Name__c)
      ? objB.Object_API_Name__c
      : objB.Name;
    wUpsert.objectName = objBKey;
    wUpsert.objectApiName = objBKey;
    wUpsert.canView = true;
    wUpsert.canCreate = false;
    wUpsert.canEdit = true;
    wUpsert.canDelete = false;
    wUpsert.isAssigned = true;

    String jsonPayload = JSON.serialize(
      new List<PWChrono_PermissionController.PermissionWrapper>{
        wDelete,
        wUpsert
      }
    );

    Test.startTest();
    PWChrono_PermissionController.saveProfilePermissions(
      profile.Id,
      jsonPayload,
      null,
      null
    );
    Test.stopTest();

    List<Portal_Object_Permission__c> remaining = [
      SELECT Id, Portal_Object__c
      FROM Portal_Object_Permission__c
      WHERE Portal_User_Profile__c = :profile.Id
    ];
    System.assertEquals(
      1,
      remaining.size(),
      'Should have exactly one remaining permission'
    );
    System.assertEquals(
      objB.Id,
      remaining[0].Portal_Object__c,
      'Remaining permission should be for Obj B'
    );
  }

  @IsTest
  static void saveProfilePermissions_invalidJson_throwsAuraHandled() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;

    Test.startTest();
    try {
      PWChrono_PermissionController.saveProfilePermissions(
        profile.Id,
        'not-json',
        null,
        null
      );
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(
        null,
        e,
        'Should throw AuraHandledException for UI'
      );
    }
    Test.stopTest();
  }
}