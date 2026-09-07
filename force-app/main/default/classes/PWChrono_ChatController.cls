public with sharing class PWChrono_ChatController {
  public class ChatAccessState {
    @AuraEnabled
    public Boolean authenticated;
    @AuraEnabled
    public String currentUserId;
    @AuraEnabled
    public String currentUserName;
    @AuraEnabled
    public String loginUrl;
  }

  @AuraEnabled(cacheable=true)
  public static ChatAccessState getAccessState() {
    ChatAccessState state = new ChatAccessState();
    state.authenticated = UserInfo.getUserType() != 'Guest';
    if (state.authenticated) {
      state.currentUserId = UserInfo.getUserId();
      state.currentUserName = UserInfo.getName();
    } else {
      String networkId = Network.getNetworkId();
      state.loginUrl = String.isBlank(networkId)
        ? '/login'
        : Network.getLoginUrl(networkId);
    }
    return state;
  }

  @AuraEnabled
  public static List<PWChrono_ChatContact> getContacts() {
    try {
      return PWChrono_ChatServiceFactory.getProvider().getContacts();
    } catch (Exception error) {
      throw new PWChrono_ChatException(error.getMessage());
    }
  }

  @AuraEnabled
  public static List<PWChrono_ChatMessage> getMessages(String recipientId) {
    try {
      return PWChrono_ChatServiceFactory.getProvider().getMessages(recipientId);
    } catch (Exception error) {
      throw new PWChrono_ChatException(error.getMessage());
    }
  }

  @AuraEnabled
  public static void sendMessage(String recipientId, String content) {
    try {
      PWChrono_ChatServiceFactory.getProvider()
        .sendMessage(recipientId, content);
    } catch (Exception error) {
      throw new PWChrono_ChatException(error.getMessage());
    }
  }
}