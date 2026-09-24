import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getMyGoals from "@salesforce/apex/PWChrono_PortalApi.getMyGoals";
import saveGoal from "@salesforce/apex/PWChrono_PortalApi.saveGoal";
import updateGoalProgress from "@salesforce/apex/PWChrono_PortalApi.updateGoalProgress";
import { getSession, getSessionToken } from "c/pwchronoSession";

export default class PwchronoGoalManagement extends LightningElement {
  static renderMode = "light";
  @track goals = [];
  @track isLoading = true;
  @track isSaving = false;
  @track error;
  @track isModalOpen = false;
  @track currentGoal = {};
  @track selectedStatus = "All";
  @track searchTerm = "";
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
    statusFilter: "All",
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredGoals(result) {
    this.wiredGoalsResult = result;
    if (result.data) {
      this.goals = result.data.map((goal) => ({
        ...goal,
        badgeClass: this.getBadgeClass(goal.Status__c),
        progressDisabled: ["Completed", "Cancelled"].includes(goal.Status__c),
        formattedDate: goal.Target_Date__c
          ? new Date(goal.Target_Date__c).toLocaleDateString()
          : "No Date",
        progressStyle: `width: ${goal.Progress__c || 0}%`
      }));
      this.error = undefined;
      this.isLoading = false;
    } else if (result.error) {
      this.error = this.extractError(result.error, "Unable to load goals.");
      this.goals = [];
      this.isLoading = false;
    }
  }

  get modalTitle() {
    return this.currentGoal.Id ? "Edit Goal" : "New Goal";
  }

  get saveButtonLabel() {
    return this.isSaving ? "Saving…" : "Save goal";
  }

  get hasGoals() {
    return this.visibleGoals.length > 0;
  }

  get visibleGoals() {
    const term = this.searchTerm.trim().toLowerCase();
    return this.goals.filter((goal) => {
      const matchesStatus =
        this.selectedStatus === "All" || goal.Status__c === this.selectedStatus;
      const haystack =
        `${goal.Name || ""} ${goal.Description__c || ""}`.toLowerCase();
      return matchesStatus && (!term || haystack.includes(term));
    });
  }

  get hasSearchOrFilter() {
    return this.selectedStatus !== "All" || this.searchTerm.trim().length > 0;
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
    this.selectedStatus = event.currentTarget.dataset.status;
  }

  handleSearch(event) {
    this.searchTerm = event.target.value;
  }

  async refreshGoals() {
    this.isLoading = true;
    try {
      await refreshApex(this.wiredGoalsResult);
    } catch (error) {
      this.error = this.extractError(error, "Unable to refresh goals.");
    } finally {
      this.isLoading = false;
    }
  }

  handleModalKeydown(event) {
    if (event.key === "Escape") this.closeModal();
  }

  handleNewGoal() {
    this.currentGoal = {
      Name: "",
      Description__c: "",
      Target_Date__c: null,
      Status__c: "Not Started",
      Progress__c: 0
    };
    this.error = undefined;
    this.isModalOpen = true;
  }

  handleEditGoal(event) {
    const goalId = event.currentTarget.dataset.id;
    const goal = this.goals.find((g) => g.Id === goalId);
    this.currentGoal = { ...goal };
    this.isModalOpen = true;
  }

  closeModal() {
    if (!this.isSaving) this.isModalOpen = false;
  }

  handleInputChange(event) {
    const field = event.target.dataset.field || event.target.name;
    const value = event.detail?.value ?? event.target.value;
    this.currentGoal = { ...this.currentGoal, [field]: value };
  }

  handleSaveGoal() {
    if (this.isSaving || !this.validateForm()) {
      return;
    }

    this.isSaving = true;
    const goalToSave = {
      Id: this.currentGoal.Id,
      Name: this.currentGoal.Name,
      Description__c: this.currentGoal.Description__c,
      Target_Date__c: this.currentGoal.Target_Date__c,
      Status__c: this.currentGoal.Status__c,
      Progress__c: Number(this.currentGoal.Progress__c || 0)
    };
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
        this.isSaving = false;
      });
  }

  handleProgressChange(event) {
    const goalId = event.currentTarget.dataset.id;
    const newProgress = Number(event.detail?.value ?? event.target.value);
    const goal = this.goals.find((g) => g.Id === goalId);
    if (!goal || goal.progressDisabled) return;

    // Optimistic update
    const originalProgress = goal.Progress__c;
    this.goals = this.goals.map((item) => {
      if (item.Id === goalId) {
        return {
          ...item,
          Progress__c: newProgress,
          progressStyle: `width: ${newProgress}%`
        };
      }
      return item;
    });

    let statusProp = "Not Started";
    if (newProgress >= 100) {
      statusProp = "Completed";
    } else if (newProgress > 0) {
      statusProp = "In Progress";
    }

    updateGoalProgress({
      goalId,
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
        this.goals = this.goals.map((item) => {
          if (item.Id === goalId) {
            return {
              ...item,
              Progress__c: originalProgress,
              progressStyle: `width: ${originalProgress || 0}%`
            };
          }
          return item;
        });
        const errorMsg =
          error?.body?.message || error?.message || "Failed to update progress";
        this.showToast("Error updating progress", errorMsg, "error");
      });
  }

  validateForm() {
    const root = this;
    const inputs = root.querySelectorAll
      ? [...root.querySelectorAll(".goal-input")]
      : [];
    const allValid = inputs.reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);
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

  extractError(error, fallback) {
    return (
      error?.body?.message ||
      error?.body?.output?.errors?.[0]?.message ||
      error?.message ||
      fallback
    );
  }
}