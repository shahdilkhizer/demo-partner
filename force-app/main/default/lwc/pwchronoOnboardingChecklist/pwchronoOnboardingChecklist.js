import { LightningElement, wire, track } from "lwc";
import getOnboardingTasks from "@salesforce/apex/PWChrono_OnboardingController.getOnboardingTasks";
import updateTaskStatus from "@salesforce/apex/PWChrono_OnboardingController.updateTaskStatus";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoOnboardingChecklist extends LightningElement {
  @track tasks;
  @track error;
  @track progress = 0;
  @track isLoading = true;
  wiredTasksResult;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  @wire(getOnboardingTasks, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredTasks(result) {
    this.wiredTasksResult = result;
    this.isLoading = false;
    const { data, error } = result;
    if (data) {
      this.tasks = data.map((task) => {
        const isCompleted = task.Status__c === "Completed";
        return {
          ...task,
          isCompleted: isCompleted,
          iconName: isCompleted ? "action:approval" : "action:new_task",
          iconVariant: isCompleted ? "success" : "warning"
        };
      });
      this.calculateProgress();
      this.error = undefined;
    } else if (error) {
      this.error = error.body.message;
      this.tasks = undefined;
    }
  }

  get hasTasks() {
    return this.tasks && this.tasks.length > 0;
  }

  calculateProgress() {
    if (!this.tasks || this.tasks.length === 0) {
      this.progress = 0;
      return;
    }
    const completedCount = this.tasks.filter(
      (t) => t.Status__c === "Completed"
    ).length;
    this.progress = Math.round((completedCount / this.tasks.length) * 100);
  }

  handleMarkComplete(event) {
    const taskId = event.target.dataset.id;
    updateTaskStatus({
      taskId: taskId,
      status: "Completed",
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Task marked as completed",
            variant: "success"
          })
        );
        return refreshApex(this.wiredTasksResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error updating task",
            message: error.body.message,
            variant: "error"
          })
        );
      });
  }
}