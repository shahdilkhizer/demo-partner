import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CONSTANTS } from "c/pwchronoConstants";
import getJobApplicants from "@salesforce/apex/PWChrono_RecruitmentController.getJobApplicants";
import getActiveDesignations from "@salesforce/apex/PWChrono_RecruitmentController.getActiveDesignations";
import generateOfferLetter from "@salesforce/apex/PWChrono_RecruitmentController.generateOfferLetter";

export default class PwchronoOfferLetterGenerator extends LightningElement {
  @track selectedApplicantId;
  @track applicantOptions = [];
  @track designationOptions = [];
  @track isLoading = false;

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
  companyName = CONSTANTS.COMPANY_NAME;
  currencyCode = CONSTANTS.CURRENCY_CODE;

  @wire(getJobApplicants, { jobOpeningId: null, statusFilter: "All" })
  wiredApplicants({ error, data }) {
    if (data) {
      this.applicantOptions = data.map((app) => ({
        label: `${app.Applicant_Name__c} - ${app.Job_Opening__r ? app.Job_Opening__r.Job_Title__c : "General"}`,
        value: app.Id,
        name: app.Applicant_Name__c
      }));
    } else if (error) {
      this.showToast("Error", "Error loading applicants", "error");
    }
  }

  @wire(getActiveDesignations)
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
    // Set status to Sent if generating
    this.offerDetails.Status__c = "Sent";

    generateOfferLetter({ offerLetter: this.offerDetails })
      .then(() => {
        this.showToast(
          "Success",
          "Offer letter generated and sent successfully",
          "success"
        );
        this.resetForm();
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  validateForm() {
    const allValid = [...this.template.querySelectorAll(".offer-input")].reduce(
      (validSoFar, inputCmp) => {
        inputCmp.reportValidity();
        return validSoFar && inputCmp.checkValidity();
      },
      true
    );
    return allValid;
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