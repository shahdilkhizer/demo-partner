public interface PWChrono_IChatProvider {
  /**
   * Send a message to a recipient (user or channel)
   */
  void sendMessage(String recipientId, String content);

  /**
   * Retrieve conversation history
   */
  List<PWChrono_ChatMessage> getMessages(String recipientId);

  /**
   * Get list of active conversations/contacts
   */
  List<PWChrono_ChatContact> getContacts();
}