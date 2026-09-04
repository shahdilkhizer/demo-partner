import { api, LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createPortalUser from "@salesforce/apex/PWChrono_ReportingManagerController.createPortalUser";
import getAvailableProfiles from "@salesforce/apex/PWChrono_ConfigurationController.getAvailableProfiles";
import getReportingOptions from "@salesforce/apex/PWChrono_ReportingManagerController.getReportingOptions";

export default class PwchronoNewUserForm extends LightningElement {
  @api callerPortalUserId;
  @api sessionToken;
  @track newUser = {
    Name: "",
    Email__c: "",
    Role__c: "Employee",
    Designation__c: "",
    Department__c: "",
    Reports_To__c: null,
    Is_Active__c: true
  };
  @track selectedProfileId = "";
  @track profileOptions = [];
  @track managerOptions = [];
  @track isSaving = false;
  @track isLoadingProfiles = true;
  @track profileLoadError = null;

  connectedCallback() {
    this.loadProfiles();
    this.loadManagers();
  }

  async loadManagers() {
    try {
      const data = await getReportingOptions({
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      this.managerOptions = [
        { label: "No manager (top-level)", value: "" },
        ...(data || [])
          .filter((manager) => manager.isActive)
          .map((manager) => ({
            label: manager.designation
              ? `${manager.portalUserName} — ${manager.designation}`
              : manager.portalUserName,
            value: manager.portalUserId
          }))
      ];
    } catch (error) {
      const errorMsg =
        error?.body?.message || error?.message || "Failed to load managers";
      this.showToast("Error", errorMsg, "error");
    }
  }

  async loadProfiles() {
    this.isLoadingProfiles = true;
    this.profileLoadError = null;
    try {
      const data = await getAvailableProfiles({
        portalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      if (data && data.length > 0) {
        this.profileOptions = data.map((profile) => ({
          label: profile.profileName,
          value: profile.profileId
        }));
      } else {
        this.profileLoadError =
          "No Portal User Profiles are available. Create a profile before adding users.";
        this.profileOptions = [];
      }
    } catch (error) {
      const errorMsg =
        error?.body?.message ||
        error?.message ||
        "Failed to load Portal User Profiles. Please try again.";
      this.profileLoadError = errorMsg;
      this.profileOptions = [];
      this.showToast("Error", errorMsg, "error");
    } finally {
      this.isLoadingProfiles = false;
    }
  }

  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.newUser[field] = event.target.value;
  }

  handleProfileChange(event) {
    this.selectedProfileId = event.detail.value;
  }

  handleManagerChange(event) {
    this.newUser = {
      ...this.newUser,
      Reports_To__c: event.detail.value || null
    };
  }

  async handleSave() {
    if (!this.validateInput()) {
      return;
    }

    this.isSaving = true;
    try {
      const userId = await createPortalUser({
        userRecord: this.newUser,
        profileId: this.selectedProfileId,
        managerPortalUserId: this.newUser.Reports_To__c,
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });

      this.showToast(
        "Success",
        `User ${this.newUser.Name} created successfully.`,
        "success"
      );
      this.dispatchEvent(new CustomEvent("usersaved", { detail: userId }));
      this.closeModal();
    } catch (error) {
      this.showToast(
        "Error",
        `Failed to create user: ${error.body.message}`,
        "error"
      );
    } finally {
      this.isSaving = false;
    }
  }

  validateInput() {
    const allValid = [
      ...this.template.querySelectorAll("lightning-input, lightning-combobox")
    ].reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);

    if (!allValid) {
      this.showToast("Error", "Please fill all required fields.", "error");
      return false;
    }
    return true;
  }

  closeModal() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}