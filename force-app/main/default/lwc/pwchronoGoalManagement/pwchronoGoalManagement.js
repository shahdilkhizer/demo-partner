import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getMyGoals from "@salesforce/apex/PWChrono_PerformanceController.getMyGoals";
import saveGoal from "@salesforce/apex/PWChrono_PerformanceController.saveGoal";
import updateGoalProgress from "@salesforce/apex/PWChrono_PerformanceController.updateGoalProgress";
import { getSession, getSessionToken } from "c/pwchronoSession";

export default class PwchronoGoalManagement extends LightningElement {
  static renderMode = "light";
  @track goals = [];
  @track filteredGoals = [];
  @track isLoading = true;
  @track isModalOpen = false;
  @track currentGoal = {};
  @track selectedStatus = "All";
  @track employeeId;
  @track sessionToken;

  wiredGoalsResult;

  statusOptions = [
    { label: "All", value: "All" },
    { label: "Not Started", value: "Not Started" },
    { label: "In Progress", value: "In Progress" },
    { label: "Completed", value: "Completed" },
    { label: "Cancelled", value: "Cancelled" }
  ];

  goalStatusOptions = [
    { label: "Not Started", value: "Not Started" },
    { label: "In Progress", value: "In Progress" },
    { label: "Completed", value: "Completed" },
    { label: "Cancelled", value: "Cancelled" }
  ];

  connectedCallback() {
    const session = getSession();
    if (session?.user) {
      this.employeeId = session.user.Id;
    }
    this.sessionToken = getSessionToken();
  }

  @wire(getMyGoals, {
    statusFilter: "$selectedStatus",
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredGoals(result) {
    this.wiredGoalsResult = result;
    if (result.data) {
      this.goals = result.data.map((goal) => ({
        ...goal,
        badgeClass: this.getBadgeClass(goal.Status__c),
        formattedDate: goal.Target_Date__c
          ? new Date(goal.Target_Date__c).toLocaleDateString()
          : "No Date",
        progressStyle: `width: ${goal.Progress__c || 0}%`
      }));
      this.filteredGoals = this.goals;
      this.isLoading = false;
    } else if (result.error) {
      this.showToast("Error", "Error loading goals", "error");
      this.isLoading = false;
    }
  }

  get modalTitle() {
    return this.currentGoal.Id ? "Edit Goal" : "New Goal";
  }

  get hasGoals() {
    return this.goals && this.goals.length > 0;
  }

  get totalGoals() {
    return this.goals ? this.goals.length : 0;
  }

  get inProgressCount() {
    return this.goals
      ? this.goals.filter((g) => g.Status__c === "In Progress").length
      : 0;
  }

  get completedCount() {
    return this.goals
      ? this.goals.filter((g) => g.Status__c === "Completed").length
      : 0;
  }

  get averageProgress() {
    if (!this.goals || this.goals.length === 0) return 0;
    const total = this.goals.reduce((sum, g) => sum + (g.Progress__c || 0), 0);
    return Math.round(total / this.goals.length);
  }

  get currentGoalProgressStyle() {
    return `width: ${this.currentGoal.Progress__c || 0}%`;
  }

  get allFilterClass() {
    return this.selectedStatus === "All" ? "filter-tab active" : "filter-tab";
  }

  get notStartedFilterClass() {
    return this.selectedStatus === "Not Started"
      ? "filter-tab active"
      : "filter-tab";
  }

  get inProgressFilterClass() {
    return this.selectedStatus === "In Progress"
      ? "filter-tab active"
      : "filter-tab";
  }

  get completedFilterClass() {
    return this.selectedStatus === "Completed"
      ? "filter-tab active"
      : "filter-tab";
  }

  stopPropagation(event) {
    event.stopPropagation();
  }

  handleStatusFilterChange(event) {
    this.isLoading = true;
    this.selectedStatus = event.currentTarget.dataset.status;
    // The wire service will automatically refresh because selectedStatus is reactive
  }

  handleNewGoal() {
    this.currentGoal = {
      Name: "",
      Description__c: "",
      Target_Date__c: null,
      Status__c: "Not Started",
      Progress__c: 0
    };
    this.isModalOpen = true;
  }

  handleEditGoal(event) {
    const goalId = event.currentTarget.dataset.id;
    const goal = this.goals.find((g) => g.Id === goalId);
    this.currentGoal = { ...goal };
    this.isModalOpen = true;
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleInputChange(event) {
    const field = event.target.name;
    this.currentGoal[field] = event.target.value;
  }

  handleSaveGoal() {
    if (!this.validateForm()) {
      return;
    }

    this.isLoading = true;
    const goalToSave = { ...this.currentGoal };
    if (this.employeeId) {
      goalToSave.Employees__c = this.employeeId;
    }

    saveGoal({
      goal: goalToSave,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Goal saved successfully", "success");
        this.isModalOpen = false;
        return refreshApex(this.wiredGoalsResult);
      })
      .catch((error) => {
        const errorMsg =
          error?.body?.message || error?.message || "Failed to save goal";
        this.showToast("Error saving goal", errorMsg, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleProgressChange(event) {
    const goalId = event.target.dataset.id;
    const newProgress = event.target.value;
    const goal = this.goals.find((g) => g.Id === goalId);

    // Optimistic update
    const originalProgress = goal.Progress__c;
    goal.Progress__c = newProgress;

    let statusProp = "Not Started";
    if (newProgress >= 100) {
      statusProp = "Completed";
    } else if (newProgress > 0) {
      statusProp = "In Progress";
    }

    updateGoalProgress({
      goalId: goalId,
      progressPercentage: newProgress,
      status: statusProp,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        return refreshApex(this.wiredGoalsResult);
      })
      .catch((error) => {
        // Revert on error
        goal.Progress__c = originalProgress;
        const errorMsg =
          error?.body?.message || error?.message || "Failed to update progress";
        this.showToast("Error updating progress", errorMsg, "error");
      });
  }

  validateForm() {
    const allValid = [...this.template.querySelectorAll(".goal-input")].reduce(
      (validSoFar, inputCmp) => {
        inputCmp.reportValidity();
        return validSoFar && inputCmp.checkValidity();
      },
      true
    );
    return allValid;
  }

  getBadgeClass(status) {
    switch (status) {
      case "Not Started":
        return "status-badge status-not-started";
      case "In Progress":
        return "status-badge status-in-progress";
      case "Completed":
        return "status-badge status-completed";
      case "Cancelled":
        return "status-badge status-cancelled";
      default:
        return "status-badge";
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}