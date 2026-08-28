import { LightningElement, track, wire, api } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getProfileWithAccess from "@salesforce/apex/PWChrono_ProfileController.getProfileWithAccess";
import updateProfileWithAccess from "@salesforce/apex/PWChrono_ProfileController.updateProfileWithAccess";
import uploadProfileImageWithAccess from "@salesforce/apex/PWChrono_ProfileController.uploadProfileImageWithAccess";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoProfileUpdate extends LightningElement {
  static renderMode = "light";
  // Target employee record to view/edit (Portal_Users__c Id). If blank, defaults to the current session portal user.
  @api employeeId;
  @track profile;
  @track error;
  @track isSaving = false;

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
    if (this.profile) {
      this.resetFormState();
    }
  }

  async handleImageUpload(event) {
    const file = event.target.files[0];
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

      this.isSaving = true;
      const reader = new FileReader();
      reader.onload = async () => {
        const base64 = reader.result.split(",")[1];
        try {
          await uploadProfileImageWithAccess({
            targetEmployeeId: this.targetEmployeeId,
            fileName: file.name,
            base64Data: base64,
            portalUserId: this.portalUserId,
            sessionToken: this.sessionToken
          });
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
          event.target.value = null;
        }
      };
      reader.readAsDataURL(file);
    }
  }

  handleCancelUpload() {
    const fileInput = this.template.querySelector(".image-sign");
    if (fileInput) {
      fileInput.value = null;
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