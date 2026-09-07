/**
 * Salesforce-native private chat backed exclusively by Chatter Messages.
 *
 * ConnectApi executes in the current Salesforce user's context. This provider
 * intentionally never queries Portal_Users__c or Portal_Chatter__c, so Chatter
 * Free/External users do not receive access to PWChrono HR data through chat.
 */
public inherited sharing class PWChrono_SalesforceChatProvider implements PWChrono_IChatProvider {
  private static final Integer PAGE_SIZE = 100;
  private final String communityId;
  private final String currentUserId;

  public PWChrono_SalesforceChatProvider() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new PWChrono_ChatException(
        'Sign in with your assigned Chatter account to use private chat.'
      );
    }
    communityId = Network.getNetworkId();
    currentUserId = UserInfo.getUserId();
  }

  public void sendMessage(String recipientId, String content) {
    String recipient = requireRecipient(recipientId);
    String body = String.valueOf(content).trim();
    if (String.isBlank(body)) {
      throw new PWChrono_ChatException('Message cannot be empty.');
    }
    if (body.length() > 10000) {
      throw new PWChrono_ChatException(
        'Message cannot exceed 10,000 characters.'
      );
    }

    if (String.isBlank(communityId)) {
      ConnectApi.ChatterMessages.sendMessage(body, recipient);
    } else {
      ConnectApi.ChatterMessages.sendMessage(communityId, body, recipient);
    }
  }

  public List<PWChrono_ChatMessage> getMessages(String recipientId) {
    String recipient = requireRecipient(recipientId);
    ConnectApi.ChatterConversationSummary summary = findConversation(recipient);
    if (summary == null) {
      return new List<PWChrono_ChatMessage>();
    }

    ConnectApi.ChatterConversation conversation = String.isBlank(communityId)
      ? ConnectApi.ChatterMessages.getConversation(summary.id, null, PAGE_SIZE)
      : ConnectApi.ChatterMessages.getConversation(
          communityId,
          summary.id,
          null,
          PAGE_SIZE
        );

    List<PWChrono_ChatMessage> messages = new List<PWChrono_ChatMessage>();
    List<ConnectApi.ChatterMessage> nativeMessages = conversation.messages ==
      null
      ? null
      : conversation.messages.messages;
    if (nativeMessages != null) {
      for (Integer index = nativeMessages.size() - 1; index >= 0; index--) {
        messages.add(toMessage(nativeMessages[index]));
      }
    }

    if (summary.read == false) {
      if (String.isBlank(communityId)) {
        ConnectApi.ChatterMessages.markConversationRead(summary.id, true);
      } else {
        ConnectApi.ChatterMessages.markConversationRead(
          communityId,
          summary.id,
          true
        );
      }
    }
    return messages;
  }

  public List<PWChrono_ChatContact> getContacts() {
    Map<String, ConnectApi.ChatterConversationSummary> conversationByUser = new Map<String, ConnectApi.ChatterConversationSummary>();
    ConnectApi.ChatterConversationPage conversations = getConversationPage();
    if (conversations.conversations != null) {
      for (
        ConnectApi.ChatterConversationSummary summary : conversations.conversations
      ) {
        if (summary.members == null) {
          continue;
        }
        for (ConnectApi.UserSummary member : summary.members) {
          if (member.id != currentUserId) {
            conversationByUser.put(member.id, summary);
          }
        }
      }
    }

    List<PWChrono_ChatContact> contacts = new List<PWChrono_ChatContact>();
    ConnectApi.UserPage userPage = ConnectApi.ChatterUsers.getUsers(
      communityId,
      0,
      PAGE_SIZE
    );
    if (userPage.users == null) {
      return contacts;
    }
    for (ConnectApi.UserDetail user : userPage.users) {
      if (
        user.id == currentUserId ||
        user.isActive == false ||
        !user.hasChatter
      ) {
        continue;
      }
      PWChrono_ChatContact contact = new PWChrono_ChatContact(
        user.id,
        user.name,
        user.photo == null ? null : user.photo.smallPhotoUrl,
        'Chatter user'
      );
      ConnectApi.ChatterConversationSummary summary = conversationByUser.get(
        user.id
      );
      if (summary != null && summary.latestMessage != null) {
        contact.lastMessage = extractText(summary.latestMessage.body);
        contact.lastMessageTime = summary.latestMessage.sentDate;
        contact.unreadCount = summary.read == false ? 1 : 0;
      }
      contacts.add(contact);
    }
    return contacts;
  }

  private ConnectApi.ChatterConversationPage getConversationPage() {
    return String.isBlank(communityId)
      ? ConnectApi.ChatterMessages.getConversations(null, PAGE_SIZE)
      : ConnectApi.ChatterMessages.getConversations(
          communityId,
          null,
          PAGE_SIZE
        );
  }

  private ConnectApi.ChatterConversationSummary findConversation(
    String recipientId
  ) {
    ConnectApi.ChatterConversationPage page = getConversationPage();
    if (page.conversations == null) {
      return null;
    }
    for (ConnectApi.ChatterConversationSummary summary : page.conversations) {
      if (summary.members == null) {
        continue;
      }
      Boolean containsCurrentUser = false;
      Boolean containsRecipient = false;
      for (ConnectApi.UserSummary member : summary.members) {
        containsCurrentUser = containsCurrentUser || member.id == currentUserId;
        containsRecipient = containsRecipient || member.id == recipientId;
      }
      if (
        containsCurrentUser &&
        containsRecipient &&
        summary.members.size() == 2
      ) {
        return summary;
      }
    }
    return null;
  }

  private String requireRecipient(String recipientId) {
    String recipient = String.valueOf(recipientId).trim();
    if (String.isBlank(recipient) || !recipient.startsWith('005')) {
      throw new PWChrono_ChatException(
        'The selected Chatter recipient is invalid.'
      );
    }
    if (recipient == currentUserId) {
      throw new PWChrono_ChatException(
        'Select another Chatter user to start a conversation.'
      );
    }
    return recipient;
  }

  private PWChrono_ChatMessage toMessage(ConnectApi.ChatterMessage message) {
    String senderId = message.sender == null ? null : message.sender.id;
    return new PWChrono_ChatMessage(
      message.id,
      senderId,
      message.sender == null ? 'Unknown user' : message.sender.name,
      extractText(message.body),
      message.sentDate,
      senderId == currentUserId
    );
  }

  private static String extractText(ConnectApi.MessageBody body) {
    if (body == null || body.messageSegments == null) {
      return '';
    }
    List<String> parts = new List<String>();
    for (ConnectApi.MessageSegment segment : body.messageSegments) {
      if (String.isNotBlank(segment.text)) {
        parts.add(segment.text);
      }
    }
    return String.join(parts, '');
  }
}