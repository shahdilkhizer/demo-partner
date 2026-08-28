import { LightningElement, api } from "lwc";

export default class PwChronoTaskItem extends LightningElement {
  /**
   * A Case record returned by PWChrono_ProjectController.getTasks.
   * Expected fields: Id, CaseNumber, Subject, Status, Priority, Due_Date__c
   */
  @api task;

  get subject() {
    return this.task?.Subject ?? "";
  }

  get caseNumber() {
    return this.task?.CaseNumber ?? "";
  }

  get status() {
    return this.task?.Status ?? "";
  }

  get priority() {
    return this.task?.Priority ?? "";
  }

  get dueDate() {
    return this.task?.Due_Date__c ?? null;
  }

  get hasDueDate() {
    return Boolean(this.dueDate);
  }
}