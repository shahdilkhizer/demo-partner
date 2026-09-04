import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getProfilePermissions from "@salesforce/apex/PWChrono_PermissionController.getProfilePermissions";
import saveProfilePermissions from "@salesforce/apex/PWChrono_PermissionController.saveProfilePermissions";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoProfilePermissions extends LightningElement {
  @api recordId; // Portal_User_Profile__c Id
  @track permissions = [];
  @track isLoading = true;
  @track searchTerm = "";
  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  get filteredPermissions() {
    if (!this.searchTerm) {
      return this.permissions;
    }
    const lowerTerm = this.searchTerm.toLowerCase();
    return this.permissions.filter((perm) =>
      perm.objectName.toLowerCase().includes(lowerTerm)
    );
  }

  get hasPermissions() {
    return this.filteredPermissions.length > 0;
  }

  connectedCallback() {
    this.loadPermissions();
  }

  handleSearch(event) {
    this.searchTerm = event.target.value;
  }

  loadPermissions() {
    this.isLoading = true;
    getProfilePermissions({
      profileId: this.recordId,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        this.permissions = result.map((perm) => ({
          ...perm,
          disabled: !perm.isAssigned,
          rowClass: perm.isAssigned ? "row-assigned" : ""
        }));
        this.isLoading = false;
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error loading permissions: " + error.body.message,
          "error"
        );
        this.isLoading = false;
      });
  }

  handleChange(event) {
    const objectName = event.target.dataset.id;
    const field = event.target.dataset.field;
    const checked = event.target.checked;

    this.permissions = this.permissions.map((perm) => {
      if (perm.objectName === objectName) {
        let updatedPerm = { ...perm, [field]: checked };

        if (field === "isAssigned") {
          updatedPerm.disabled = !checked;
          updatedPerm.rowClass = checked ? "row-assigned" : "";
          if (!checked) {
            updatedPerm.canView = false;
            updatedPerm.canCreate = false;
            updatedPerm.canEdit = false;
            updatedPerm.canDelete = false;
            updatedPerm.canViewAll = false;
            updatedPerm.canModifyAll = false;
          }
        }
        return updatedPerm;
      }
      return perm;
    });
  }

  handleSave() {
    this.isLoading = true;
    saveProfilePermissions({
      profileId: this.recordId,
      permissionsJson: JSON.stringify(this.permissions),
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Permissions saved successfully", "success");
        this.isLoading = false;
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error saving permissions: " + error.body.message,
          "error"
        );
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}