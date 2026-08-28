/**
 * DTO for chat message payloads returned to UI.
 */
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
public inherited sharing class PWChrono_ChatMessage {
  @AuraEnabled
  public String id;
  @AuraEnabled
  public String senderId;
  @AuraEnabled
  public String senderName;
  @AuraEnabled
  public String content;
  @AuraEnabled
  public DateTime timestamp;
  @AuraEnabled
  public Boolean isMe;

  /**
   * Creates a message DTO.
   * @param id Message id
   * @param senderId Sender id
   * @param senderName Sender display name
   * @param content Message content
   * @param timestamp Message timestamp
   * @param isMe True when sent by current user
   */
  public PWChrono_ChatMessage(
    String id,
    String senderId,
    String senderName,
    String content,
    DateTime timestamp,
    Boolean isMe
  ) {
    this.id = id;
    this.senderId = senderId;
    this.senderName = senderName;
    this.content = content;
    this.timestamp = timestamp;
    this.isMe = isMe;
  }
}