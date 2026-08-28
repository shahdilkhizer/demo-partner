/**
 * Google Chat provider implementation for chat service.
 */
@SuppressWarnings('PMD.AvoidDeeplyNestedIfStmts')
public inherited sharing class PWChrono_GoogleChatProvider implements PWChrono_IChatProvider {
  // Assumes a Named Credential 'Google_Chat_API' is set up in Salesforce
  // Base Endpoint Example: https://chat.googleapis.com
  private static final String ENDPOINT = 'callout:Google_Chat_API';

  /**
   * Sends a message to a Google Chat recipient.
   * @param recipientId Google Chat space or recipient resource id
   * @param content Message body content
   */
  public void sendMessage(String recipientId, String content) {
    // RecipientId here is likely the Space Name or Thread Key
    // Example: spaces/AAAA12345/messages

    HttpRequest req = new HttpRequest();
    // Assuming recipientId passed is the full resource name of the space
    String url = ENDPOINT + '/v1/' + recipientId + '/messages';

    req.setEndpoint(url);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');

    // Google Chat API Message body format
    String body =
      '{"text": "' +
      JSON.serialize(content).removeStart('"').removeEnd('"') +
      '"}';
    req.setBody(body);

    Http http = new Http();
    try {
      HttpResponse res = http.send(req);
      if (res.getStatusCode() != 200) {
        PWChrono_Logger.warn(
          'Google Chat send returned non-200 response: ' + res.getStatusCode()
        );
      }
    } catch (Exception e) {
      PWChrono_Logger.error('Google Chat send callout exception.', e);
      throw new PWChrono_ChatException(
        'Failed to send Google Chat message: ' + e.getMessage()
      );
    }
  }

  /**
   * Retrieves messages from Google Chat.
   * @param recipientId Google Chat space or recipient resource id
   * @return List of mapped chat messages
   */
  public List<PWChrono_ChatMessage> getMessages(String recipientId) {
    List<PWChrono_ChatMessage> messages = new List<PWChrono_ChatMessage>();

    HttpRequest req = new HttpRequest();
    // Example: spaces/AAAA12345/messages
    String url = ENDPOINT + '/v1/' + recipientId + '/messages';

    req.setEndpoint(url);
    req.setMethod('GET');

    Http http = new Http();
    try {
      HttpResponse res = http.send(req);
      if (res.getStatusCode() == 200) {
        // Parse response. This requires a wrapper class or untyped map
        // Simplifying for the example using Map<String, Object>
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
          res.getBody()
        );
        List<Object> msgList = (List<Object>) responseMap.get('messages');

        // You might need a mapping in a custom setting or field.

        if (msgList != null) {
          for (Object obj : msgList) {
            Map<String, Object> msg = (Map<String, Object>) obj;
            Map<String, Object> sender = (Map<String, Object>) msg.get(
              'sender'
            );
            String text = (String) msg.get('text'); // Simplified: real structure is inside 'body'

            // Fallback parsing if structure differs
            if (text == null && msg.get('argumentText') != null) {
              text = (String) msg.get('argumentText');
            }

            String msgName = (String) msg.get('name'); // Google ID
            String senderName = (String) sender.get('displayName');
            String senderId = (String) sender.get('name');

            // Logic to determine 'isMe'.
            // For now, always false unless we map IDs.
            Boolean isMe = false;

            DateTime dt = DateTime.now(); // Parse 'createTime' in real impl

            messages.add(
              new PWChrono_ChatMessage(
                msgName,
                senderId,
                senderName,
                text,
                dt,
                isMe
              )
            );
          }
        }
      }
    } catch (Exception e) {
      PWChrono_Logger.error('Google Chat getMessages callout exception.', e);
    }

    return messages;
  }

  /**
   * Retrieves available Google Chat spaces as contacts.
   * @return List of mapped contacts
   */
  public List<PWChrono_ChatContact> getContacts() {
    // In Google Chat "Contacts" are usually "Spaces" or "Direct Messages"
    List<PWChrono_ChatContact> contacts = new List<PWChrono_ChatContact>();

    HttpRequest req = new HttpRequest();
    req.setEndpoint(ENDPOINT + '/v1/spaces');
    req.setMethod('GET');

    Http http = new Http();
    try {
      HttpResponse res = http.send(req);
      if (res.getStatusCode() == 200) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
          res.getBody()
        );
        List<Object> spaces = (List<Object>) responseMap.get('spaces');

        if (spaces != null) {
          for (Object obj : spaces) {
            Map<String, Object> space = (Map<String, Object>) obj;
            String spaceName = (String) space.get('name'); // Use this as ID for messaging
            String displayName = (String) space.get('displayName');
            if (displayName == null) {
              displayName = 'Direct Message';
            }

            contacts.add(
              new PWChrono_ChatContact(
                spaceName,
                displayName,
                '', // Avatar URL often not directly in list list
                'online'
              )
            );
          }
        }
      }
    } catch (Exception e) {
      PWChrono_Logger.error('Google Chat getContacts callout exception.', e);
    }

    return contacts;
  }
}