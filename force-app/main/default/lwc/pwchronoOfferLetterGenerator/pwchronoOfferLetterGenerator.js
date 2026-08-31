import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { CONSTANTS } from "c/pwchronoConstants";
import getJobApplicants from "@salesforce/apex/PWChrono_RecruitmentController.getJobApplicants";
import getActiveDesignations from "@salesforce/apex/PWChrono_RecruitmentController.getActiveDesignations";
import generateOfferLetter from "@salesforce/apex/PWChrono_RecruitmentController.generateOfferLetter";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoOfferLetterGenerator extends LightningElement {
  static renderMode = "light";

  @track portalUserId = getEmployeeId();
  @track sessionToken = getSessionToken();
  @track selectedApplicantId;
  @track applicantOptions = [];
  @track designationOptions = [];
  @track isLoading = false;

  _wiredApplicantsResult;

  @track offerDetails = {
    Job_Applicant__c: null,
    Designation__c: null,
    Offered_CTC__c: null,
    Joining_Date__c: null,
    Expiry_Date__c: null,
    Offer_Date__c: new Date().toISOString().split("T")[0],
    Status__c: "Draft"
  };

  selectedApplicantName = "";
  selectedDesignationName = "";
  @track successMessage = null;
  companyName = CONSTANTS.COMPANY_NAME;
  currencyCode = CONSTANTS.CURRENCY_CODE;

  connectedCallback() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getJobApplicants, {
    jobOpeningId: null,
    statusFilter: "All",
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredApplicants(result) {
    this._wiredApplicantsResult = result;
    if (result.data) {
      this.applicantOptions = result.data.map((app) => {
        const applicantName = app.Name || app.Applicant_Name__c || "Candidate";
        const jobTitle =
          app.Job_Opening__r?.Name ||
          app.Job_Opening__r?.Job_Title__c ||
          "General Application";
        return {
          label: `${applicantName} - ${jobTitle}`,
          value: app.Id,
          name: applicantName
        };
      });
    } else if (error) {
      this.showToast("Error", "Error loading applicants", "error");
    }
  }

  @wire(getActiveDesignations, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredDesignations({ error, data }) {
    if (data) {
      this.designationOptions = data.map((des) => ({
        label: des.Name,
        value: des.Id
      }));
    } else if (error) {
      this.showToast("Error", "Error loading designations", "error");
    }
  }

  handleApplicantChange(event) {
    this.selectedApplicantId = event.detail.value;
    this.offerDetails.Job_Applicant__c = this.selectedApplicantId;

    const selectedOption = this.applicantOptions.find(
      (opt) => opt.value === this.selectedApplicantId
    );
    this.selectedApplicantName = selectedOption ? selectedOption.name : "";
  }

  handleInputChange(event) {
    const field = event.target.name;
    this.offerDetails[field] = event.target.value;

    if (field === "Designation__c") {
      const selectedOption = this.designationOptions.find(
        (opt) => opt.value === event.target.value
      );
      this.selectedDesignationName = selectedOption ? selectedOption.label : "";
    }
  }

  handleGenerateOffer() {
    if (!this.validateForm()) {
      return;
    }

    this.isLoading = true;
    this.offerDetails.Status__c = "Sent";

    generateOfferLetter({
      offerLetter: this.offerDetails,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        const offerNumber = result?.Name || "OFR";
        this.successMessage = `Offer Letter #${offerNumber} has been successfully generated & marked as "Sent". Candidate status has been automatically moved to "Offer Extended" in Candidate Pipeline.`;
        this.showToast(
          "Success",
          `Offer letter #${offerNumber} generated and sent successfully`,
          "success"
        );
        this.resetForm();
        if (this._wiredApplicantsResult) {
          refreshApex(this._wiredApplicantsResult);
        }
      })
      .catch((error) => {
        this.showToast("Error", error.body?.message || error.message || "Failed to generate offer", "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  dismissSuccessMessage() {
    this.successMessage = null;
  }

  validateForm() {
    const root = this.template || this;
    const inputs = [
      ...(root.querySelectorAll ? root.querySelectorAll("lightning-combobox") : []),
      ...(root.querySelectorAll ? root.querySelectorAll("lightning-input") : [])
    ];
    return inputs.reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);
  }

  resetForm() {
    this.selectedApplicantId = null;
    this.selectedApplicantName = "";
    this.selectedDesignationName = "";
    this.offerDetails = {
      Job_Applicant__c: null,
      Designation__c: null,
      Offered_CTC__c: null,
      Joining_Date__c: null,
      Expiry_Date__c: null,
      Offer_Date__c: new Date().toISOString().split("T")[0],
      Status__c: "Draft"
    };
  }

  get todayDate() {
    return new Date().toLocaleDateString();
  }

  get isGenerateDisabled() {
    return (
      !this.selectedApplicantId ||
      !this.offerDetails.Designation__c ||
      !this.offerDetails.Offered_CTC__c
    );
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}