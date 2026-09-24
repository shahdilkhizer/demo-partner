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
  @track filter = "all";
  @track searchTerm = "";
  @track savingTaskId;
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
        const due = task.Due_Date__c
          ? new Date(`${task.Due_Date__c}T00:00:00`)
          : null;
        const overdue = !isCompleted && due && due < new Date();
        return {
          ...task,
          isCompleted: isCompleted,
          iconName: isCompleted ? "action:approval" : "action:new_task",
          iconVariant: isCompleted ? "success" : "warning",
          isOverdue: overdue,
          statusLabel: isCompleted
            ? "Completed"
            : overdue
              ? "Overdue"
              : task.Status__c
        };
      });
      this.calculateProgress();
      this.error = undefined;
    } else if (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load onboarding tasks.";
      this.tasks = undefined;
    }
  }

  get hasTasks() {
    return this.filteredTasks.length > 0;
  }

  get filteredTasks() {
    const term = this.searchTerm.trim().toLowerCase();
    return (this.tasks || [])
      .filter((task) => {
        const matchesFilter =
          this.filter === "all" ||
          (this.filter === "open" && !task.isCompleted) ||
          (this.filter === "completed" && task.isCompleted);
        const haystack =
          `${task.Name || ""} ${task.Description__c || ""}`.toLowerCase();
        return matchesFilter && (!term || haystack.includes(term));
      })
      .map((task) => ({ ...task, isSaving: task.Id === this.savingTaskId }));
  }

  get totalCount() {
    return (this.tasks || []).length;
  }
  get completedCount() {
    return (this.tasks || []).filter((task) => task.isCompleted).length;
  }
  get openCount() {
    return this.totalCount - this.completedCount;
  }
  get overdueCount() {
    return (this.tasks || []).filter((task) => task.isOverdue).length;
  }
  get progressStyle() {
    return `--progress:${this.progress}%`;
  }
  get progressLabel() {
    return `${this.progress}% complete`;
  }
  get filterOptions() {
    return [
      {
        value: "all",
        label: `All tasks (${this.totalCount})`,
        selected: this.filter === "all"
      },
      {
        value: "open",
        label: `Open (${this.openCount})`,
        selected: this.filter === "open"
      },
      {
        value: "completed",
        label: `Completed (${this.completedCount})`,
        selected: this.filter === "completed"
      }
    ];
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

  loadTasks() {
    return refreshApex(this.wiredTasksResult);
  }

  handleMarkComplete(event) {
    const taskId = event.currentTarget.dataset.id;
    this.savingTaskId = taskId;
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
            message: "Onboarding task marked as completed.",
            variant: "success"
          })
        );
        return refreshApex(this.wiredTasksResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error updating task",
            message:
              error?.body?.message ||
              error?.message ||
              "Unable to update task.",
            variant: "error"
          })
        );
      })
      .finally(() => {
        this.savingTaskId = undefined;
      });
  }

  handleFilter(event) {
    this.filter = event.target.value;
  }
  handleSearch(event) {
    this.searchTerm = event.target.value;
  }
}