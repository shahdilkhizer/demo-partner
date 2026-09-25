import { LightningElement, track, wire, api } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getProfileWithAccess from "@salesforce/apex/PWChrono_ProfileController.getProfileWithAccess";
import updateProfileWithAccess from "@salesforce/apex/PWChrono_ProfileController.updateProfileWithAccess";
import uploadProfileImageWithAccess from "@salesforce/apex/PWChrono_ProfileController.uploadProfileImageWithAccess";
import deleteProfilePhotoWithAccess from "@salesforce/apex/PWChrono_ProfileController.deleteProfilePhotoWithAccess";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  getEmployeeId,
  getSessionToken,
  updateSessionUser
} from "c/pwchronoSession";

export default class PwchronoProfileUpdate extends LightningElement {
  static renderMode = "light";
  // Target employee record to view/edit (Portal_Users__c Id). If blank, defaults to the current session portal user.
  @api employeeId;
  @track profile;
  @track error;
  @track isSaving = false;

  @track stagedImageUrl = null;
  @track stagedImageData = null;
  @track stagedFileName = null;
  @track isPhotoRemoved = false;

  // Actor portal user (the verified session user). Used to enforce access on the server.
  portalUserId = getEmployeeId();

  // Track editable fields locally
  @track formState = {
    Name: "",
    Phone__c: "",
    Address__c: "",
    Emergency_Contact_Name__c: "",
    Emergency_Contact_Phone__c: ""
  };

  wiredProfileResult;

  sessionToken;

  updatedFields = {};

  // Target employee ID - use provided value or fall back to current session portal user.
  get targetEmployeeId() {
    return this.employeeId || this.portalUserId;
  }

  connectedCallback() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
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

  get displayedPhotoUrl() {
    if (this.isPhotoRemoved) {
      return null;
    }
    if (this.stagedImageUrl) {
      return this.stagedImageUrl;
    }
    return this.profile?.Photo_Url__c || null;
  }

  get showCancelUploadButton() {
    return Boolean(this.stagedImageUrl || this.isPhotoRemoved);
  }

  get showRemoveButton() {
    return (
      Boolean(this.profile?.Photo_Url__c) &&
      !this.stagedImageUrl &&
      !this.isPhotoRemoved
    );
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
      this.resetFormState();
    } else if (result.error) {
      this.error = result.error;
      this.profile = undefined;
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
    this.handleCancelUpload();
    if (this.profile) {
      this.resetFormState();
    }
  }

  handleImageUpload(event) {
    const file = event.target.files && event.target.files[0];
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
        event.target.value = null;
        return;
      }

      const reader = new FileReader();
      reader.onload = () => {
        this.stagedImageUrl = reader.result;
        this.stagedImageData = reader.result.split(",")[1];
        this.stagedFileName = file.name;
        this.isPhotoRemoved = false;
      };
      reader.readAsDataURL(file);
    }
  }

  handleRemovePhoto() {
    this.stagedImageUrl = null;
    this.stagedImageData = null;
    this.stagedFileName = null;
    this.isPhotoRemoved = true;
    const fileInput = this.querySelector(".image-sign");
    if (fileInput) {
      fileInput.value = null;
    }
  }

  handleCancelUpload() {
    this.stagedImageUrl = null;
    this.stagedImageData = null;
    this.stagedFileName = null;
    this.isPhotoRemoved = false;
    const fileInput = this.querySelector(".image-sign");
    if (fileInput) {
      fileInput.value = null;
    }
  }

  async handleSave() {
    this.isSaving = true;
    try {
      let profileUpdated = false;

      // 1. Photo Removal
      if (this.isPhotoRemoved && this.profile?.Photo_Url__c) {
        await deleteProfilePhotoWithAccess({
          targetEmployeeId: this.targetEmployeeId,
          portalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        });
        if (this.targetEmployeeId === this.portalUserId) {
          updateSessionUser({ Photo_Url__c: null });
        }
        profileUpdated = true;
      } else if (this.stagedImageData) {
        // 2. Photo Upload
        const photoUrl = await uploadProfileImageWithAccess({
          targetEmployeeId: this.targetEmployeeId,
          fileName: this.stagedFileName,
          base64Data: this.stagedImageData,
          portalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        });
        if (this.targetEmployeeId === this.portalUserId && photoUrl) {
          updateSessionUser({ Photo_Url__c: photoUrl });
        }
        profileUpdated = true;
      }

      // 3. Field Updates
      if (Object.keys(this.updatedFields).length > 0) {
        await updateProfileWithAccess({
          profileData: this.updatedFields,
          targetEmployeeId: this.targetEmployeeId,
          portalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        });
        this.updatedFields = {};
        profileUpdated = true;
      }

      if (profileUpdated) {
        this.stagedImageUrl = null;
        this.stagedImageData = null;
        this.stagedFileName = null;
        this.isPhotoRemoved = false;
        const fileInput = this.querySelector(".image-sign");
        if (fileInput) {
          fileInput.value = null;
        }

        await refreshApex(this.wiredProfileResult);

        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Profile updated successfully",
            variant: "success"
          })
        );
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