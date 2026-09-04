@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_ApprovalController {
  public class ApprovalRequestWrapper {
    @AuraEnabled
    public Id workItemId;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String recordName;
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public String submitterName;
    @AuraEnabled
    public DateTime dateSubmitted;
    @AuraEnabled
    public String comments;
  }

  @AuraEnabled(cacheable=true)
  public static List<ApprovalRequestWrapper> getPendingApprovals() {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        throw new AuraHandledException('Unauthorized.');
      }
      List<ApprovalRequestWrapper> wrappers = new List<ApprovalRequestWrapper>();
      Id currentUserId = UserInfo.getUserId();

      List<ProcessInstanceWorkitem> workItems = [
        SELECT
          Id,
          ProcessInstance.TargetObjectId,
          ProcessInstance.TargetObject.Name,
          ProcessInstance.Status,
          ProcessInstance.SubmittedBy.Name,
          ProcessInstance.CreatedDate,
          ProcessInstance.TargetObject.Type
        FROM ProcessInstanceWorkitem
        WHERE ActorId = :currentUserId
        ORDER BY ProcessInstance.CreatedDate DESC
      ];

      Set<Id> targetObjectIds = new Set<Id>();
      for (ProcessInstanceWorkitem item : workItems) {
        targetObjectIds.add(item.ProcessInstance.TargetObjectId);
      }

      // We can try to get more specific details if needed, but TargetObject.Name is often sufficient.
      // However, TargetObject.Type gives us the SObjectType.

      for (ProcessInstanceWorkitem item : workItems) {
        ApprovalRequestWrapper wrapper = new ApprovalRequestWrapper();
        wrapper.workItemId = item.Id;
        wrapper.recordId = item.ProcessInstance.TargetObjectId;
        wrapper.recordName = item.ProcessInstance.TargetObject.Name;
        wrapper.submitterName = item.ProcessInstance.SubmittedBy.Name;
        wrapper.dateSubmitted = item.ProcessInstance.CreatedDate;

        // Determine Object Type Label (Simplified)
        Id targetId = item.ProcessInstance.TargetObjectId;
        String sObjName = targetId.getSObjectType().getDescribe().getLabel();
        wrapper.objectType = sObjName;

        wrappers.add(wrapper);
      }

      return wrappers;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'Error fetching pending approvals: ' + e.getMessage()
      );
      PWChrono_Logger.error('Stack trace: ' + e.getStackTraceString());
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching pending approvals: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching pending approvals: ' + e.getMessage());
      throw ahe;
    }
  }

  @AuraEnabled
  public static void processRequest(
    Id workItemId,
    String action,
    String comments
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        throw new AuraHandledException('Unauthorized.');
      }
      // Validate work item still exists and is pending
      List<ProcessInstanceWorkitem> workItems = [
        SELECT Id, ProcessInstance.Status
        FROM ProcessInstanceWorkitem
        WHERE Id = :workItemId
        LIMIT 1
      ];

      if (workItems.isEmpty()) {
        String message = 'Approval request not found or already processed.';
        AuraHandledException notFound = new AuraHandledException(message);
        notFound.setMessage(message);
        throw notFound;
      }

      if (workItems[0].ProcessInstance.Status != 'Pending') {
        String message = 'This approval request has already been processed.';
        AuraHandledException alreadyProcessed = new AuraHandledException(
          message
        );
        alreadyProcessed.setMessage(message);
        throw alreadyProcessed;
      }

      Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
      req.setComments(comments);
      req.setAction(action); // 'Approve', 'Reject', 'Removed'
      req.setWorkitemId(workItemId);

      Approval.ProcessResult result = Approval.process(req);

      if (!result.isSuccess()) {
        String errorMsg = 'Approval processing failed';
        if (!result.getErrors().isEmpty()) {
          errorMsg += ': ' + result.getErrors()[0].getMessage();
        }
        AuraHandledException processingError = new AuraHandledException(
          errorMsg
        );
        processingError.setMessage(errorMsg);
        throw processingError;
      }
    } catch (Exception e) {
      PWChrono_Logger.error(
        'Error processing approval request: ' + e.getMessage()
      );
      PWChrono_Logger.error('Stack trace: ' + e.getStackTraceString());
      AuraHandledException ahe = new AuraHandledException(
        'Error processing approval request: ' + e.getMessage()
      );
      ahe.setMessage('Error processing approval request: ' + e.getMessage());
      throw ahe;
    }
  }
}