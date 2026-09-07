import { LightningElement, track, wire, api } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getProfileWithAccess from "@salesforce/apex/PWChrono_ProfileController.getProfileWithAccess";
import updateProfileWithAccess from "@salesforce/apex/PWChrono_ProfileController.updateProfileWithAccess";
import uploadProfileImageWithAccess from "@salesforce/apex/PWChrono_ProfileController.uploadProfileImageWithAccess";
import removeProfileImageWithAccess from "@salesforce/apex/PWChrono_ProfileController.removeProfileImageWithAccess";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { logError } from "c/pwchronoErrorHandler";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT,
  updateSessionUser
} from "c/pwchronoSession";

export default class PwchronoProfileUpdate extends LightningElement {
  static renderMode = "light";
  // Target employee record to view/edit (Portal_Users__c Id). If blank, defaults to the current session portal user.
  @api employeeId;
  @track profile;
  @track error;
  @track errorMessage = "";
  @track isLoading = true;
  @track isSaving = false;
  @track isRemovingPhoto = false;

  // Actor portal user (the verified session user). Used to enforce access on the server.
  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  // Track editable fields locally
  @track formState = {
    Name: "",
    Phone__c: "",
    Address__c: "",
    Emergency_Contact_Name__c: "",
    Emergency_Contact_Phone__c: ""
  };

  wiredProfileResult;
  updatedFields = {};
  _boundSessionChanged;

  // Target employee ID - use provided value or fall back to current session portal user.
  get targetEmployeeId() {
    return this.employeeId || this.portalUserId || undefined;
  }

  connectedCallback() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();

    this._boundSessionChanged = this.handleSessionChanged.bind(this);
    try {
      globalThis?.addEventListener?.(
        SESSION_CHANGED_EVENT,
        this._boundSessionChanged
      );
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      globalThis?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this._boundSessionChanged
      );
    } catch {
      // no-op
    }
  }

  handleSessionChanged() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
    if (this.wiredProfileResult) {
      this.isLoading = true;
      refreshApex(this.wiredProfileResult);
    }
  }

  handleRetry() {
    this.isLoading = true;
    this.errorMessage = "";
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
    if (this.wiredProfileResult) {
      refreshApex(this.wiredProfileResult);
    }
  }

  // Computed Properties
  get initials() {
    if (!this.profile?.Name) return "?";
    const parts = this.profile.Name.split(" ");
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return this.profile.Name.substring(0, 2).toUpperCase();
  }

  resetFormState() {
    this.formState = {
      Name: this.profile?.Name || "",
      Phone__c: this.profile?.Phone__c || "",
      Address__c: this.profile?.Address__c || "",
      Emergency_Contact_Name__c: this.profile?.Emergency_Contact_Name__c || "",
      Emergency_Contact_Phone__c: this.profile?.Emergency_Contact_Phone__c || ""
    };
  }

  @wire(getProfileWithAccess, {
    targetEmployeeId: "$targetEmployeeId",
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredProfile(result) {
    this.wiredProfileResult = result;
    if (result.data) {
      this.profile = { ...result.data };
      this.error = undefined;
      this.errorMessage = "";
      this.isLoading = false;
      this.resetFormState();
    } else if (result.error) {
      this.error = result.error;
      this.profile = undefined;
      this.isLoading = false;
      this.errorMessage =
        result.error?.body?.message ||
        result.error?.message ||
        "Unable to load profile details. Please try again or re-authenticate.";
      logError("pwchronoProfileUpdate.wiredProfile", result.error);
    }
  }

  handleFieldChange(event) {
    const fieldName = event.target.name;
    const value = event.target.value;

    this.formState[fieldName] = value;

    // Only add to updatedFields if it's a Salesforce field
    if (
      [
        "Name",
        "Phone__c",
        "Address__c",
        "Emergency_Contact_Name__c",
        "Emergency_Contact_Phone__c"
      ].includes(fieldName)
    ) {
      this.updatedFields[fieldName] = value;
    }
  }

  handleCancelEdit() {
    this.updatedFields = {};
    if (this.profile) {
      this.resetFormState();
    }
  }

  async handleImageUpload(event) {
    const fileInput = event?.target;
    const file = fileInput?.files?.[0];
    if (file) {
      // Validate file size (e.g., 5MB limit)
      if (file.size > 5 * 1024 * 1024) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "File size exceeds 5MB limit",
            variant: "error"
          })
        );
        if (fileInput) {
          fileInput.value = null;
        }
        return;
      }

      this.isSaving = true;
      const reader = new FileReader();
      reader.onload = async () => {
        const base64 = reader.result.split(",")[1];
        try {
          const photoUrl = await uploadProfileImageWithAccess({
            targetEmployeeId: this.targetEmployeeId,
            fileName: file.name,
            base64Data: base64,
            portalUserId: this.portalUserId,
            sessionToken: this.sessionToken
          });
          if (this.targetEmployeeId === this.portalUserId && photoUrl) {
            updateSessionUser({ Photo_Url__c: photoUrl });
          }
          if (this.profile && photoUrl) {
            this.profile = {
              ...this.profile,
              Photo_Url__c: photoUrl
            };
          }
          await refreshApex(this.wiredProfileResult);
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Success",
              message: "Profile photo uploaded successfully",
              variant: "success"
            })
          );
        } catch (error) {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Error uploading photo",
              message: error.body ? error.body.message : error.message,
              variant: "error"
            })
          );
        } finally {
          this.isSaving = false;
          // Clear input so same file can be selected again if needed
          if (fileInput) {
            fileInput.value = null;
          }
        }
      };
      reader.readAsDataURL(file);
    }
  }

  get hasPhoto() {
    return !!this.profile?.Photo_Url__c;
  }

  get isRemoveDisabled() {
    return this.isRemovingPhoto || this.isSaving || !this.hasPhoto;
  }

  handleCancelUpload() {
    const fileInput = this.querySelector
      ? this.querySelector(".image-sign")
      : this.template?.querySelector?.(".image-sign");
    if (fileInput) {
      fileInput.value = null;
    }
  }

  async handleRemovePhoto() {
    this.handleCancelUpload();

    if (!this.profile?.Photo_Url__c) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Info",
          message: "No profile photo to remove.",
          variant: "info"
        })
      );
      return;
    }

    this.isRemovingPhoto = true;
    try {
      await removeProfileImageWithAccess({
        targetEmployeeId: this.targetEmployeeId,
        portalUserId: this.portalUserId,
        sessionToken: this.sessionToken
      });

      if (this.profile) {
        this.profile = {
          ...this.profile,
          Photo_Url__c: null
        };
      }

      if (this.targetEmployeeId === this.portalUserId) {
        updateSessionUser({ Photo_Url__c: null });
      }

      await refreshApex(this.wiredProfileResult);

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Profile photo removed successfully",
          variant: "success"
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error removing photo",
          message: error.body ? error.body.message : error.message,
          variant: "error"
        })
      );
    } finally {
      this.isRemovingPhoto = false;
    }
  }

  async handleSave() {
    this.isSaving = true;
    try {
      if (Object.keys(this.updatedFields).length > 0) {
        await updateProfileWithAccess({
          profileData: this.updatedFields,
          targetEmployeeId: this.targetEmployeeId,
          portalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        });

        await refreshApex(this.wiredProfileResult);

        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Profile updated successfully",
            variant: "success"
          })
        );
        this.updatedFields = {};
      } else {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Profile updated (No changes to persisted fields)",
            variant: "success"
          })
        );
      }
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error updating profile",
          message: error.body ? error.body.message : error.message,
          variant: "error"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }
}