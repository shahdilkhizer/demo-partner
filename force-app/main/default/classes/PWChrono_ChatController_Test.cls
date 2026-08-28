@isTest
private class PWChrono_ChatController_Test {
  @isTest
  static void testGetContacts_ReturnsMockContacts() {
    Test.startTest();
    List<PWChrono_ChatContact> contacts = PWChrono_ChatController.getContacts();
    Test.stopTest();

    System.assertNotEquals(null, contacts, 'Contacts list should not be null.');
    System.assertEquals(
      2,
      contacts.size(),
      'Mock Salesforce provider should return 2 contacts.'
    );
  }

  @isTest
  static void testGetMessages_ReturnsMockMessages() {
    String recipientId = '0050000000001';

    Test.startTest();
    List<PWChrono_ChatMessage> messages = PWChrono_ChatController.getMessages(
      recipientId
    );
    Test.stopTest();

    System.assertNotEquals(null, messages, 'Messages list should not be null.');
    System.assertEquals(
      3,
      messages.size(),
      'Mock Salesforce provider should return 3 messages.'
    );
  }

  @isTest
  static void testSendMessage_CompletesWithoutException() {
    Test.startTest();
    PWChrono_ChatController.sendMessage('0050000000001', 'Hello from test');
    Test.stopTest();

    System.assert(true, 'sendMessage should complete in mock provider path.');
  }
}