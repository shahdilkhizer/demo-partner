/**
 * @description Shared comment persistence for request-based modules.
 */
public inherited sharing class PWChrono_RequestCommentService {

  public static final String TYPE_COMMENT = 'Comment';
  public static final String TYPE_SYSTEM = 'System';

  @AuraEnabled(cacheable=true)
  public static List<RequestCommentDTO> getComments(Id recordId, String objectApiName) {
    if (recordId == null || String.isBlank(objectApiName)) {
      return new List<RequestCommentDTO>();
    }

    List<RequestCommentDTO> results = new List<RequestCommentDTO>();
    for (PWChrono_Request_Comment__c commentRecord : [
      SELECT Id, Comment_Text__c, Comment_Type__c,
             Author_Employee__c, Author_Employee__r.Name,
             CreatedDate
      FROM PWChrono_Request_Comment__c
      WHERE Related_Record_Id__c = :String.valueOf(recordId)
        AND Object_Api_Name__c = :objectApiName
      ORDER BY CreatedDate ASC
    ]) {
      results.add(mapComment(commentRecord));
    }

    return results;
  }

  @AuraEnabled
  public static RequestCommentDTO addComment(
    Id recordId,
    String objectApiName,
    String commentText,
    Id authorEmployeeId
  ) {
    return insertComment(recordId, objectApiName, commentText, authorEmployeeId, TYPE_COMMENT);
  }

  public static RequestCommentDTO addSystemComment(
    Id recordId,
    String objectApiName,
    String commentText,
    Id authorEmployeeId
  ) {
    return insertComment(recordId, objectApiName, commentText, authorEmployeeId, TYPE_SYSTEM);
  }

  private static RequestCommentDTO insertComment(
    Id recordId,
    String objectApiName,
    String commentText,
    Id authorEmployeeId,
    String commentType
  ) {
    if (recordId == null) {
      throw new AuraHandledException('Record Id is required.');
    }
    if (String.isBlank(objectApiName)) {
      throw new AuraHandledException('Object API name is required.');
    }
    if (String.isBlank(commentText)) {
      throw new AuraHandledException('Comment text is required.');
    }

    PWChrono_Request_Comment__c commentRecord = new PWChrono_Request_Comment__c(
      Related_Record_Id__c = String.valueOf(recordId),
      Object_Api_Name__c = objectApiName,
      Comment_Text__c = commentText.trim(),
      Author_Employee__c = authorEmployeeId,
      Comment_Type__c = commentType
    );
    insert commentRecord;

    commentRecord = [
      SELECT Id, Comment_Text__c, Comment_Type__c,
             Author_Employee__c, Author_Employee__r.Name,
             CreatedDate
      FROM PWChrono_Request_Comment__c
      WHERE Id = :commentRecord.Id
      LIMIT 1
    ];

    return mapComment(commentRecord);
  }

  private static RequestCommentDTO mapComment(PWChrono_Request_Comment__c commentRecord) {
    RequestCommentDTO dto = new RequestCommentDTO();
    dto.commentId = commentRecord.Id;
    dto.text = commentRecord.Comment_Text__c;
    dto.commentType = commentRecord.Comment_Type__c;
    dto.authorEmployeeId = commentRecord.Author_Employee__c;
    dto.authorName = commentRecord.Author_Employee__r != null
      ? commentRecord.Author_Employee__r.Name
      : 'System';
    dto.createdDate = commentRecord.CreatedDate;
    return dto;
  }

  public class RequestCommentDTO {
    @AuraEnabled public Id commentId;
    @AuraEnabled public String text;
    @AuraEnabled public String commentType;
    @AuraEnabled public Id authorEmployeeId;
    @AuraEnabled public String authorName;
    @AuraEnabled public Datetime createdDate;
  }
}