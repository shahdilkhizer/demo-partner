@IsTest
private class PWChrono_ProfileManagerController_Test {
  @IsTest
  static void catalogAndAssignmentsRoundTrip() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;

    Test.startTest();
    List<PWChrono_ProfileManagerController.FeatureOption> catalog = PWChrono_ProfileManagerController.getFeatureCatalog(
      profile.Id,
      null,
      null
    );
    PWChrono_ProfileManagerController.saveFeatureAssignments(
      profile.Id,
      '["Dashboard","Leave Management"]',
      null,
      null
    );
    Test.stopTest();

    System.assert(
      catalog.size() > 0,
      'The feature catalog should not be empty.'
    );
    System.assertEquals(
      2,
      [
        SELECT COUNT()
        FROM Portal_Profile_Feature__c
        WHERE Portal_User_Profile__c = :profile.Id AND Is_Enabled__c = TRUE
      ]
    );
  }

  @IsTest
  static void invalidFeatureIsRejected() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;

    try {
      PWChrono_ProfileManagerController.saveFeatureAssignments(
        profile.Id,
        '["NOT_A_FEATURE"]',
        null,
        null
      );
      System.assert(false, 'An unknown feature should be rejected.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }
}