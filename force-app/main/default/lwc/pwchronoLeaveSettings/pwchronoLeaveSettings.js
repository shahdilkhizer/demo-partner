import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import createLeaveType from "@salesforce/apex/PWChrono_PortalApi.createLeaveType";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import updateLeaveType from "@salesforce/apex/PWChrono_PortalApi.updateLeaveType";
import { logError, getErrorMessage } from "c/pwchronoErrorHandler";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoLeaveSettings extends LightningElement {
  static renderMode = "light";
  errorMessage = "";
  successMessage = "";
  get sessionParams() {
    return { employeeId: getEmployeeId(), sessionToken: getSessionToken() };
  }
  get hasLeaveTypes() {
    return this.leaveTypes.length > 0;
  }
  @track leaveTypes = [];
  @track isLoading = true;
  @track showSettingsModal = false;
  @track showCreateModal = false;
  @track selectedLeaveType = {};
  @track newLeaveType = {
    Name: "",
    Max_Days_Allowed__c: 20,
    Is_Carry_Forward__c: false,
    Max_Carry_Forward_Days__c: 0,
    Requires_Approval__c: true,
    Requires_Certificate__c: false,
    Is_Active__c: true
  };

  // Keep this for other potential settings not related to specific leave types
  @track settings = {
    allowHalfDay: true,
    requireApproval: true,
    allowNegative: false
  };

  connectedCallback() {
    this.loadLeaveTypes();
  }

  async loadLeaveTypes() {
    this.isLoading = true;
    try {
      const result = await getActiveLeaveTypes({ includeInactive: true });
      this.leaveTypes = result.map((type) => ({
        ...type,
        carryForwardLimit: type.Is_Carry_Forward__c
          ? (type.Max_Carry_Forward_Days__c ?? "Not configured")
          : "Not allowed",
        statusLabel: type.Is_Active__c ? "Active" : "Inactive",
        statusClass: type.Is_Active__c
          ? "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800"
          : "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800",
        carryForwardIcon: type.Is_Carry_Forward__c
          ? "utility:check"
          : "utility:close",
        carryForwardClass: type.Is_Carry_Forward__c
          ? "text-green-500"
          : "text-gray-400"
      }));
    } catch (error) {
      logError("pwchronoLeaveSettings.loadLeaveTypes", error);
      this.showToast("Error", "Failed to load leave types", "error");
    } finally {
      this.isLoading = false;
    }
  }

  handleAddLeaveType() {
    this.newLeaveType = {
      Name: "",
      Max_Days_Allowed__c: 20,
      Is_Carry_Forward__c: false,
      Max_Carry_Forward_Days__c: 0,
      Requires_Approval__c: true,
      Requires_Certificate__c: false,
      Is_Active__c: true
    };
    this.showCreateModal = true;
  }

  closeCreateModal() {
    this.showCreateModal = false;
  }

  handleCreateChange(event) {
    const field = event.target.dataset.field;
    let value;

    if (event.target.type === "checkbox" || event.target.type === "toggle") {
      value = event.target.checked;
    } else {
      value = event.target.value;
    }

    this.newLeaveType = {
      ...this.newLeaveType,
      [field]: value
    };
  }

  async createLeaveType() {
    if (!this.validateForm()) return;
    if (!this.newLeaveType.Name) {
      this.showToast("Error", "Leave Type Name is required", "error");
      return;
    }

    this.isLoading = true;
    try {
      await createLeaveType({
        leaveType: this.newLeaveType,
        ...this.sessionParams
      });
      this.showToast("Success", "Leave Type created successfully", "success");
      this.closeCreateModal();
      await this.loadLeaveTypes();
    } catch (error) {
      this.showToast(
        "Error",
        "Failed to create leave type: " +
          (error.body ? error.body.message : error.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  handleCustomPolicy(event) {
    const id = event.target.dataset.id;
    this.showToast("Info", `Custom Policy for ${id}`, "info");
  }

  handleSettings(event) {
    const id = event.currentTarget.dataset.id;
    const leaveType = this.leaveTypes.find((lt) => lt.Id === id);
    if (leaveType) {
      this.selectedLeaveType = { ...leaveType };
      this.showSettingsModal = true;
    }
  }

  closeSettingsModal() {
    this.showSettingsModal = false;
    this.selectedLeaveType = {};
  }

  handleSettingChange(event) {
    const field = event.target.dataset.field;
    let value;

    if (event.target.type === "checkbox" || event.target.type === "toggle") {
      value = event.target.checked;
    } else {
      value = event.target.value;
    }

    this.selectedLeaveType = {
      ...this.selectedLeaveType,
      [field]: value
    };
  }

  async saveSettings() {
    if (!this.validateForm()) return;
    this.isLoading = true;
    try {
      // Prepare record for update
      const recordToUpdate = {
        Id: this.selectedLeaveType.Id,
        Name: this.selectedLeaveType.Name,
        Is_Active__c: this.selectedLeaveType.Is_Active__c,
        Max_Days_Allowed__c: this.selectedLeaveType.Max_Days_Allowed__c,
        Is_Carry_Forward__c: this.selectedLeaveType.Is_Carry_Forward__c,
        Max_Carry_Forward_Days__c:
          this.selectedLeaveType.Max_Carry_Forward_Days__c,
        Requires_Approval__c: this.selectedLeaveType.Requires_Approval__c,
        Requires_Certificate__c: this.selectedLeaveType.Requires_Certificate__c
      };

      await updateLeaveType({
        leaveType: recordToUpdate,
        ...this.sessionParams
      });

      this.showToast(
        "Success",
        "Leave type settings updated successfully",
        "success"
      );
      this.closeSettingsModal();
      await this.loadLeaveTypes(); // Reload to refresh UI
    } catch (error) {
      this.showToast(
        "Error",
        "Failed to update settings: " +
          (error.body ? error.body.message : error.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  validateForm() {
    this.errorMessage = "";
    return [...this.querySelectorAll("input")].reduce(
      (valid, input) => input.reportValidity() && valid,
      true
    );
  }

  showToast(title, message, variant) {
    this.errorMessage = variant === "error" ? getErrorMessage({ message }) : "";
    this.successMessage = variant === "success" ? message : "";
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}