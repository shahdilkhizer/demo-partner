import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getAvailableFeatures from "@salesforce/apex/PWChrono_ConfigurationController.getAvailableFeatures";
import createPortalUser from "@salesforce/apex/PWChrono_ConfigurationController.createPortalUser";

export default class PwchronoNewUserForm extends LightningElement {
  @track newUser = {
    Name: "",
    Email__c: "",
    Role__c: "Employee",
    Designation__c: "",
    Department__c: ""
  };
  @track features = [];
  @track isSaving = false;
  @track isLoadingFeatures = true;
  @track featureLoadError = null;
  baseFeatures = [];

  connectedCallback() {
    this.loadFeatures();
  }

  async loadFeatures() {
    this.isLoadingFeatures = true;
    this.featureLoadError = null;
    try {
      const data = await getAvailableFeatures();
      if (data && data.length > 0) {
        this.baseFeatures = data;
        this.features = this.baseFeatures.map((f) => ({
          name: f,
          hasAccess: false
        }));
      } else {
        // Distinguish between no features and loading error
        this.featureLoadError =
          "No features are available in the system. Please contact your administrator.";
        this.features = [];
      }
    } catch (error) {
      // Capture specific error message from Apex
      const errorMsg =
        error?.body?.message ||
        error?.message ||
        "Failed to load features. Please try again.";
      this.featureLoadError = errorMsg;
      this.features = [];
      this.showToast("Error", errorMsg, "error");
    } finally {
      this.isLoadingFeatures = false;
    }
  }

  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.newUser[field] = event.target.value;
  }

  handleFeatureToggle(event) {
    const featureName = event.target.dataset.name;
    const isChecked = event.target.checked;

    this.features = this.features.map((f) => {
      if (f.name === featureName) {
        return { ...f, hasAccess: isChecked };
      }
      return f;
    });
  }

  async handleSave() {
    if (!this.validateInput()) {
      return;
    }

    this.isSaving = true;
    const activeFeatures = this.features
      .filter((f) => f.hasAccess)
      .map((f) => f.name);

    try {
      const userId = await createPortalUser({
        userRecord: this.newUser,
        featureNames: activeFeatures
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
      ...this.template.querySelectorAll("lightning-input")
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