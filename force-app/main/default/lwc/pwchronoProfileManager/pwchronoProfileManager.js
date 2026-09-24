import { LightningElement, api, wire } from "lwc";
import { getRecord, updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFeatureCatalog from "@salesforce/apex/PWChrono_ProfileManagerController.getFeatureCatalog";
import saveFeatureAssignments from "@salesforce/apex/PWChrono_ProfileManagerController.saveFeatureAssignments";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

const PROFILE_FIELDS = [
  "Portal_User_Profile__c.Name",
  "Portal_User_Profile__c.Developer_Key__c",
  "Portal_User_Profile__c.Display_Name__c",
  "Portal_User_Profile__c.Description__c",
  "Portal_User_Profile__c.Profile_Type__c",
  "Portal_User_Profile__c.Is_Active__c",
  "Portal_User_Profile__c.Is_Template__c",
  "Portal_User_Profile__c.Is_Locked__c",
  "Portal_User_Profile__c.Can_Approve__c",
  "Portal_User_Profile__c.Approval_Scope__c",
  "Portal_User_Profile__c.Default_Approval_Profile__c"
];

const TYPE_OPTIONS = [
  "Employee",
  "Manager",
  "HR Manager",
  "Recruiter",
  "Payroll Administrator",
  "System Administrator",
  "Custom"
].map((value) => ({ label: value, value }));

const APPROVAL_SCOPE_OPTIONS = [
  "None",
  "Direct Reports",
  "Department",
  "All Employees"
].map((value) => ({ label: value, value }));

export default class PwchronoProfileManager extends LightningElement {
  @api recordId;

  profile = {};
  featureCatalog = [];
  typeOptions = TYPE_OPTIONS;
  approvalScopeOptions = APPROVAL_SCOPE_OPTIONS;
  isLoading = true;
  isSaving = false;
  catalogError;
  saveError;
  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  @wire(getRecord, { recordId: "$recordId", fields: PROFILE_FIELDS })
  wiredProfile({ data, error }) {
    if (data) {
      this.profile = {
        id: data.id,
        name: data.fields.Name.value,
        developerKey: data.fields.Developer_Key__c?.value || "",
        displayName: data.fields.Display_Name__c?.value || "",
        description: data.fields.Description__c?.value || "",
        profileType: data.fields.Profile_Type__c?.value || "Employee",
        isActive: data.fields.Is_Active__c?.value ?? true,
        isTemplate: data.fields.Is_Template__c?.value ?? false,
        isLocked: data.fields.Is_Locked__c?.value ?? false,
        canApprove: data.fields.Can_Approve__c?.value ?? false,
        approvalScope: data.fields.Approval_Scope__c?.value || "None",
        defaultApprovalProfileId:
          data.fields.Default_Approval_Profile__c?.value || null
      };
      this.loadFeatures();
    } else if (error) {
      this.isLoading = false;
      this.catalogError = this.reduceError(error);
    }
  }

  get profileHeading() {
    return (
      this.profile.displayName || this.profile.name || "Portal User Profile"
    );
  }

  get statusLabel() {
    return this.profile.isActive ? "Active" : "Inactive";
  }

  get statusClass() {
    return this.profile.isActive
      ? "status status-active"
      : "status status-inactive";
  }

  get isSaveDisabled() {
    return this.isSaving || this.isLoading;
  }

  get isDeveloperKeyLocked() {
    return this.profile.isLocked;
  }

  get groupedFeatures() {
    const groups = new Map();
    this.featureCatalog.forEach((feature) => {
      if (!groups.has(feature.category)) {
        groups.set(feature.category, []);
      }
      groups.get(feature.category).push(feature);
    });
    return Array.from(groups, ([category, features]) => ({
      category,
      features
    }));
  }

  get hasFeatureCatalog() {
    return this.groupedFeatures.length > 0;
  }

  get hasError() {
    return Boolean(this.catalogError || this.saveError);
  }

  loadFeatures() {
    this.isLoading = true;
    this.catalogError = undefined;
    getFeatureCatalog({
      profileId: this.recordId,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then((features) => {
        this.featureCatalog = features || [];
        this.isLoading = false;
      })
      .catch((error) => {
        this.catalogError = this.reduceError(error);
        this.isLoading = false;
      });
  }

  handleProfileChange(event) {
    const field = event.target.dataset.field;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
    this.profile = { ...this.profile, [field]: value };
    this.saveError = undefined;
  }

  handleApprovalProfileChange(event) {
    this.profile = {
      ...this.profile,
      defaultApprovalProfileId: event.detail.recordId || null
    };
    this.saveError = undefined;
  }

  handleFeatureChange(event) {
    const key = event.target.dataset.key;
    const enabled = event.target.checked;
    this.featureCatalog = this.featureCatalog.map((feature) => {
      return feature.key === key ? { ...feature, enabled } : feature;
    });
    this.saveError = undefined;
  }

  handleRetry() {
    this.loadFeatures();
  }

  handleSave() {
    if (!this.profile.displayName?.trim()) {
      this.saveError = "Display Name is required.";
      return;
    }
    if (!this.profile.developerKey?.trim()) {
      this.saveError = "Developer Key is required.";
      return;
    }
    if (
      this.profile.canApprove &&
      this.profile.defaultApprovalProfileId === this.recordId
    ) {
      this.saveError = "A profile cannot route approvals to itself.";
      return;
    }
    this.isSaving = true;
    this.saveError = undefined;
    const fields = {
      Id: this.recordId,
      Developer_Key__c: this.profile.developerKey.trim(),
      Display_Name__c: this.profile.displayName.trim(),
      Description__c: this.profile.description,
      Profile_Type__c: this.profile.profileType,
      Is_Active__c: this.profile.isActive,
      Is_Template__c: this.profile.isTemplate,
      Is_Locked__c: this.profile.isLocked,
      Can_Approve__c: this.profile.canApprove,
      Approval_Scope__c: this.profile.canApprove
        ? this.profile.approvalScope
        : "None",
      Default_Approval_Profile__c: this.profile.defaultApprovalProfileId || null
    };
    const selectedKeys = this.featureCatalog
      .filter((feature) => feature.enabled)
      .map((feature) => feature.key);

    Promise.all([
      updateRecord({ fields }),
      saveFeatureAssignments({
        profileId: this.recordId,
        featureKeysJson: JSON.stringify(selectedKeys),
        portalUserId: this.portalUserId,
        sessionToken: this.sessionToken
      })
    ])
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Profile saved",
            message: `${this.profileHeading} was updated successfully.`,
            variant: "success"
          })
        );
      })
      .catch((error) => {
        this.saveError = this.reduceError(error);
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  reduceError(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "Something went wrong. Refresh and try again."
    );
  }
}