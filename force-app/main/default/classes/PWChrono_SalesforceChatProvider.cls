/**
 * Salesforce-native chat provider (mock/placeholder implementation).
 */
public inherited sharing class PWChrono_SalesforceChatProvider implements PWChrono_IChatProvider {
  /**
   * Sends a chat message.
   * @param recipientId Target recipient identifier
   * @param content Message body content
   */
  public void sendMessage(String recipientId, String content) {
    // TODO: Implement logic to save message to Salesforce Custom Object (e.g., Chat_Message__c)
    // For now, this is a mock implementation
    PWChrono_Logger.info('Mock Salesforce chat send invoked.');
  }

  /**
   * Retrieves chat messages for a recipient.
   * @param recipientId Target recipient identifier
   * @return List of chat messages
   */
  public List<PWChrono_ChatMessage> getMessages(String recipientId) {
    // Mock data
    List<PWChrono_ChatMessage> messages = new List<PWChrono_ChatMessage>();
    messages.add(
      new PWChrono_ChatMessage(
        '1',
        recipientId,
        'Jane Doe',
        'Hey, are you free?',
        DateTime.now().addMinutes(-50),
        false
      )
    );
    messages.add(
      new PWChrono_ChatMessage(
        '2',
        UserInfo.getUserId(),
        'Me',
        'Yes, what is up?',
        DateTime.now().addMinutes(-45),
        true
      )
    );
    messages.add(
      new PWChrono_ChatMessage(
        '3',
        recipientId,
        'Jane Doe',
        'Can we discuss the project?',
        DateTime.now().addMinutes(-40),
        false
      )
    );
    return messages;
  }

  /**
   * Retrieves chat contacts.
   * @return List of chat contacts
   */
  public List<PWChrono_ChatContact> getContacts() {
    // Mock contacts - In real separate implementation this might query Users
    List<PWChrono_ChatContact> contacts = new List<PWChrono_ChatContact>();
    contacts.add(
      new PWChrono_ChatContact('0050000000001', 'Jane Doe', '', 'online')
    );
    contacts.add(
      new PWChrono_ChatContact('0050000000002', 'John Smith', '', 'offline')
    );
    return contacts;
  }
}