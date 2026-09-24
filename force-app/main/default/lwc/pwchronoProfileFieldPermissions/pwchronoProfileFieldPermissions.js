import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getProfileFieldPermissions from "@salesforce/apex/PWChrono_PermissionController.getProfileFieldPermissions";
import saveProfileFieldPermissions from "@salesforce/apex/PWChrono_PermissionController.saveProfileFieldPermissions";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoProfileFieldPermissions extends LightningElement {
  @api recordId;
  permissions = [];
  searchTerm = "";
  isLoading = true;
  isSaving = false;
  errorMessage;
  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  connectedCallback() {
    this.loadPermissions();
  }

  get filteredPermissions() {
    const term = this.searchTerm.toLowerCase();
    return this.permissions.filter(
      (permission) =>
        !term ||
        permission.objectName?.toLowerCase().includes(term) ||
        permission.fieldApiName?.toLowerCase().includes(term)
    );
  }

  get hasPermissions() {
    return this.filteredPermissions.length > 0;
  }

  get isSaveDisabled() {
    return this.isSaving || this.isLoading;
  }

  loadPermissions() {
    this.isLoading = true;
    this.errorMessage = undefined;
    getProfileFieldPermissions({
      profileId: this.recordId,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        this.permissions = (result || []).map((permission) => ({
          ...permission,
          disabled: !permission.isAssigned
        }));
      })
      .catch((error) => {
        this.errorMessage = this.reduceError(error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleSearch(event) {
    this.searchTerm = event.target.value || "";
  }

  handleChange(event) {
    const fieldId = event.target.dataset.id;
    const field = event.target.dataset.field;
    const checked = event.target.checked;
    this.permissions = this.permissions.map((permission) => {
      if (permission.fieldId !== fieldId) return permission;
      const updated = { ...permission, [field]: checked };
      if (field === "isAssigned") {
        updated.disabled = !checked;
        if (!checked) {
          updated.canView = false;
          updated.canEdit = false;
        }
      }
      return updated;
    });
  }

  handleSave() {
    this.isSaving = true;
    this.errorMessage = undefined;
    saveProfileFieldPermissions({
      profileId: this.recordId,
      permissionsJson: JSON.stringify(this.permissions),
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Field permissions saved",
            message: "The profile field restrictions were updated.",
            variant: "success"
          })
        );
      })
      .catch((error) => {
        this.errorMessage = this.reduceError(error);
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  reduceError(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "Unable to load field permissions."
    );
  }
}