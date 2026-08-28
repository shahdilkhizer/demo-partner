import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMyAppraisals from "@salesforce/apex/PWChrono_PerformanceController.getMyAppraisals";
import saveAppraisal from "@salesforce/apex/PWChrono_PerformanceController.saveAppraisal";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

const RATING_MAP = { Beginner: 1, Intermediate: 2, Advanced: 3, Expert: 4, Leader: 5 };

const TECHNICAL_COMPETENCIES = [
  { key: "customer_experience", label: "Customer Experience", expected: "Advanced" },
  { key: "technical_knowledge", label: "Technical Knowledge", expected: "Expert" },
  { key: "problem_solving", label: "Problem Solving", expected: "Advanced" },
  { key: "code_quality", label: "Code Quality", expected: "Intermediate" },
  { key: "system_design", label: "System Design", expected: "Advanced" },
  { key: "documentation", label: "Documentation", expected: "Intermediate" },
  { key: "testing", label: "Testing & QA", expected: "Intermediate" }
];

const ORGANISATIONAL_COMPETENCIES = [
  { key: "communication", label: "Communication", expected: "Advanced" },
  { key: "teamwork", label: "Teamwork", expected: "Advanced" },
  { key: "leadership", label: "Leadership", expected: "Intermediate" },
  { key: "time_management", label: "Time Management", expected: "Advanced" },
  { key: "adaptability", label: "Adaptability", expected: "Intermediate" },
  { key: "initiative", label: "Initiative & Ownership", expected: "Advanced" },
  { key: "professionalism", label: "Professionalism", expected: "Expert" }
];

export default class PerformanceAppraisal extends LightningElement {
  @api pageTitle = "Performance Appraisal";
  @api breadcrumbParent = "Performance";
  @api breadcrumbActive = "Performance Appraisal";
  @api addBtnLabel = "Add Appraisal";
  @api listTitle = "Performance Appraisal List";
  @api sortByLabel = "Sort By : Last 7 Days";

  @api colName = "Name";
  @api colDesignation = "Designation";
  @api colDepartment = "Department";
  @api colAppraisalDate = "Appraisal Date";
  @api colStatus = "Status";

  @track appraisalData = [];
  @track isModalOpen = false;
  @track isSaving = false;
  @track isLoading = true;
  @track ratings = {};
  @track formFields = { appraisalDate: "" };
  @track selectedAppraisalId = null;

  @track employeeId;
  @track sessionToken;

  wiredAppraisalsResult;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getMyAppraisals, {
    statusFilter: "All",
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredAppraisals(result) {
    this.wiredAppraisalsResult = result;
    this.isLoading = false;
    if (result.data) {
      this.appraisalData = result.data.map((record) => ({
        ...record,
        id: record.Id,
        name: record.Employees__r ? record.Employees__r.Name : record.Name,
        designation: record.Employees__r?.Designation__c || "--",
        department: record.Employees__r?.Department__c || "--",
        appraisalDate: record.Appraisal_Period__c || record.Start_Date__c || "--",
        status: record.Status__c || "Draft",
        initials: this.getInitials(record.Employees__r?.Name || record.Name || ""),
        statusClass:
          record.Status__c === "Completed" || record.Status__c === "Active"
            ? "badge badge-success d-inline-flex align-items-center badge-xs"
            : "badge badge-danger d-inline-flex align-items-center badge-xs"
      }));
    } else if (result.error) {
      this.appraisalData = [];
      this.showToast("Error", "Failed to load appraisals", "error");
    }
  }

  get technicalCompetencies() {
    return TECHNICAL_COMPETENCIES;
  }

  get organisationalCompetencies() {
    return ORGANISATIONAL_COMPETENCIES;
  }

  get hasData() {
    return this.appraisalData.length > 0;
  }

  getInitials(name) {
    if (!name) return "?";
    const parts = name.trim().split(" ");
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
    return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
  }

  computeSelfRating() {
    const values = Object.values(this.ratings)
      .map((v) => RATING_MAP[v] || 0)
      .filter((v) => v > 0);
    if (values.length === 0) return null;
    return Math.round(values.reduce((a, b) => a + b, 0) / values.length);
  }

  handleActionClick(event) {
    const action = event.currentTarget.dataset.action;
    const recordId = event.currentTarget.dataset.id;

    switch (action) {
      case "openAdd":
      case "edit":
        this.ratings = {};
        this.formFields = { appraisalDate: "" };
        this.selectedAppraisalId = action === "edit" ? recordId : null;
        this.isModalOpen = true;
        break;
      case "saveModal":
        this.handleSave();
        break;
      case "closeModal":
        this.isModalOpen = false;
        break;
      case "delete":
        this.appraisalData = this.appraisalData.filter((item) => item.id !== recordId);
        break;
      default:
        break;
    }
  }

  handleFieldChange(event) {
    const field = event.target.name;
    if (field) {
      this.formFields = { ...this.formFields, [field]: event.target.value };
    }
  }

  handleRatingChange(event) {
    const key = event.currentTarget.dataset.key;
    const value = event.detail ? event.detail.value : event.target.value;
    this.ratings = { ...this.ratings, [key]: value };
  }

  async handleSave() {
    if (!this.formFields.appraisalDate) {
      this.showToast("Validation", "Please select an appraisal date.", "warning");
      return;
    }
    this.isSaving = true;
    try {
      const appraisal = {
        Id: this.selectedAppraisalId || undefined,
        Appraisal_Period__c: this.formFields.appraisalDate,
        Start_Date__c: this.formFields.appraisalDate,
        Status__c: "Draft",
        Self_Rating__c: this.computeSelfRating(),
        Achievements__c: Object.keys(this.ratings).length
          ? JSON.stringify(this.ratings)
          : null
      };

      await saveAppraisal({
        appraisal,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });

      this.isModalOpen = false;
      this.showToast("Success", "Appraisal saved successfully", "success");
      await refreshApex(this.wiredAppraisalsResult);
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}