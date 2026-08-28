import { LightningElement, track } from "lwc";
import getFeatureSettings from "@salesforce/apex/PWChrono_AdminController.getFeatureSettings";
import saveFeatureSettings from "@salesforce/apex/PWChrono_AdminController.saveFeatureSettings";
import getGlobalSettings from "@salesforce/apex/PWChrono_AdminController.getGlobalSettings";
import searchPortalUsers from "@salesforce/apex/PWChrono_AdminController.searchPortalUsers";
import updatePortalUserAccess from "@salesforce/apex/PWChrono_AdminController.updatePortalUserAccess";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoAdminSettings extends LightningElement {
  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  @track featureSettings;
  @track globalSettings;
  @track error;
  @track isSaving = false;
  @track hasAccess = false;

  connectedCallback() {
    this.checkAccess();
  }

  async checkAccess() {
    try {
      this.employeeId = getEmployeeId();
      this.sessionToken = getSessionToken();
      const accessData = await getUserAccessById({
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (accessData.features.includes("Admin Settings")) {
        this.hasAccess = true;
        await this.loadSettings();
      }
    } catch (error) {
      this.hasAccess = false;
      this.error = error?.body?.message || error?.message;
    }
  }

  async loadSettings() {
    try {
      const [featureData, globalData] = await Promise.all([
        getFeatureSettings({
          portalUserId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getGlobalSettings({
          portalUserId: this.employeeId,
          sessionToken: this.sessionToken
        })
      ]);

      if (featureData) {
        this.featureSettings = { ...featureData };
        this.error = undefined;
      }

      if (globalData) {
        this.globalSettings = globalData;
        this.error = undefined;
      }
    } catch (error) {
      this.error = error.body?.message || error.message;
    }
  }

  @track userSearchTerm = "";
  @track userSearchResults = [];
  @track selectedUser = null;
  @track selectedRole = "";
  @track selectedFeatures = [];

  roleOptions = [
    { label: "Employee", value: "Employee" },
    { label: "Manager", value: "Manager" },
    { label: "HR Admin", value: "HR Admin" },
    { label: "Payroll Admin", value: "Payroll Admin" }
  ];

  featureOptions = [
    { label: "Dashboard", value: "Dashboard" },
    { label: "Leave Management", value: "Leave Management" },
    { label: "Attendance Management", value: "Attendance Management" },
    { label: "Employee Directory", value: "Employee Directory" },
    { label: "Expense Management", value: "Expense Management" },
    { label: "Payroll", value: "Payroll" },
    { label: "Performance Management", value: "Performance Management" },
    { label: "Training Management", value: "Training Management" },
    { label: "Recruitment", value: "Recruitment" },
    { label: "Onboarding", value: "Onboarding" },
    { label: "Manager Dashboard", value: "Manager Dashboard" },
    { label: "Admin Settings", value: "Admin Settings" },
    { label: "Appraisal", value: "Appraisal" },
    { label: "Approvals", value: "Approvals" },
    { label: "Company Policies", value: "Company Policies" },
    { label: "Goals", value: "Goals" },
    { label: "Holidays", value: "Holidays" },
    { label: "My Profile", value: "My Profile" },
    { label: "Tax Declaration", value: "Tax Declaration" }
  ];

  handleFeatureChange(event) {
    const fieldName = event.target.name;
    const value =
      event.target.type === "toggle"
        ? event.target.checked
        : event.target.value;

    this.featureSettings = {
      ...this.featureSettings,
      [fieldName]: value
    };
  }

  handleUserFeatureChange(event) {
    this.selectedFeatures = event.detail.value;
  }

  handleUserSearch(event) {
    this.userSearchTerm = event.target.value;
    if (this.userSearchTerm.length > 2) {
      searchPortalUsers({
        searchTerm: this.userSearchTerm,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      })
        .then((result) => {
          this.userSearchResults = result;
        })
        .catch(() => {
          /* Error searching users */
        });
    } else {
      this.userSearchResults = [];
    }
  }

  selectUser(event) {
    const userId = event.currentTarget.dataset.id;
    this.selectedUser = this.userSearchResults.find((u) => u.Id === userId);
    this.selectedRole = this.selectedUser.Role__c || "Employee";
    this.selectedFeatures = this.selectedUser.Access_Features__c
      ? this.selectedUser.Access_Features__c.split(";")
      : [];
    this.userSearchResults = []; // Clear search results
    this.userSearchTerm = "";
  }

  handleRoleChange(event) {
    this.selectedRole = event.detail.value;
  }

  saveUserAccess() {
    this.isSaving = true;
    updatePortalUserAccess({
      portalUserId: this.selectedUser.Id,
      role: this.selectedRole,
      features: this.selectedFeatures,
      callerPortalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "User access updated successfully",
            variant: "success"
          })
        );
        this.selectedUser = null; // Reset selection
      })
      .catch(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "Failed to update user access",
            variant: "error"
          })
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  cancelUserEdit() {
    this.selectedUser = null;
  }

  handleSave() {
    this.isSaving = true;
    saveFeatureSettings({
      settings: this.featureSettings,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Feature settings updated successfully",
            variant: "success"
          })
        );
        return this.loadSettings();
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error saving settings",
            message: error.body.message,
            variant: "error"
          })
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }
}