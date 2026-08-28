public inherited sharing class PWChrono_ProjectController {
  @AuraEnabled(cacheable=true)
  public static List<Case> getTasks(Id projectId) {
    return [
      SELECT Id, CaseNumber, Subject, Status, Priority, Due_Date__c
      FROM Case
      WHERE Related_to_Opportunity__c = :projectId
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Task> getSubtasks(Id taskId) {
    return [
      SELECT Id, Subject, ActivityDate, Status
      FROM Task
      WHERE WhatId = :taskId
    ];
  }
}