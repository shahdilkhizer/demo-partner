import createLeaveType from "@salesforce/apex/PWChrono_LeaveController.createLeaveType";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import updateLeaveType from "@salesforce/apex/PWChrono_LeaveController.updateLeaveType";
import { logError } from "c/pwchronoErrorHandler";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoLeaveSettings extends LightningElement {
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
      const result = await getActiveLeaveTypes();
      this.leaveTypes = result.map((type) => ({
        ...type,
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
    if (!this.newLeaveType.Name) {
      this.showToast("Error", "Leave Type Name is required", "error");
      return;
    }

    this.isLoading = true;
    try {
      await createLeaveType({ leaveType: this.newLeaveType });
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
    this.isLoading = true;
    try {
      // Prepare record for update
      const recordToUpdate = {
        Id: this.selectedLeaveType.Id,
        Max_Days_Allowed__c: this.selectedLeaveType.Max_Days_Allowed__c,
        Is_Carry_Forward__c: this.selectedLeaveType.Is_Carry_Forward__c,
        Max_Carry_Forward_Days__c:
          this.selectedLeaveType.Max_Carry_Forward_Days__c,
        Requires_Approval__c: this.selectedLeaveType.Requires_Approval__c,
        Requires_Certificate__c: this.selectedLeaveType.Requires_Certificate__c
      };

      await updateLeaveType({ leaveType: recordToUpdate });

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

  handleToggleActive(event) {
    const id = event.target.dataset.id;
    const checked = event.target.checked;
    this.showToast("Info", `Toggle Active for ${id}: ${checked}`, "info");
    // Here we would call Apex to update the record
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}