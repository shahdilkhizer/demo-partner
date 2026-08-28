public with sharing class PWChrono_ChatController {
  @AuraEnabled
  public static List<PWChrono_ChatContact> getContacts() {
    try {
      return PWChrono_ChatServiceFactory.getProvider().getContacts();
    } catch (Exception e) {
      throw new PWChrono_ChatException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<PWChrono_ChatMessage> getMessages(String recipientId) {
    try {
      return PWChrono_ChatServiceFactory.getProvider().getMessages(recipientId);
    } catch (Exception e) {
      throw new PWChrono_ChatException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void sendMessage(String recipientId, String content) {
    try {
      PWChrono_ChatServiceFactory.getProvider()
        .sendMessage(recipientId, content);
    } catch (Exception e) {
      throw new PWChrono_ChatException(e.getMessage());
    }
  }
}