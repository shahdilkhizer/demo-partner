import deleteMapping from "@salesforce/apex/PWChrono_RoleFeatureMappingController.deleteMapping";
import getMappings from "@salesforce/apex/PWChrono_RoleFeatureMappingController.getMappings";
import saveMapping from "@salesforce/apex/PWChrono_RoleFeatureMappingController.saveMapping";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

const COLUMNS = [
  { label: "Role", fieldName: "Role__c", type: "text", sortable: true },
  { label: "Feature", fieldName: "Feature__c", type: "text", sortable: true },
  {
    type: "action",
    typeAttributes: {
      rowActions: [
        { label: "Edit", name: "edit" },
        { label: "Delete", name: "delete" }
      ]
    }
  }
];

// Sample role options - can be extended as needed
const ROLE_OPTIONS = [
  { label: "HR_Admin", value: "HR_Admin" },
  { label: "Manager", value: "Manager" },
  { label: "Employee", value: "Employee" },
  { label: "Payroll_Admin", value: "Payroll_Admin" }
];

export default class PwchronoRoleFeatureMapping extends LightningElement {
  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();
  @track allMappings = [];
  @track mappings = [];
  @track columns = COLUMNS;
  @track isModalOpen = false;
  @track currentRecord = {};
  @track roleOptions = ROLE_OPTIONS;
  @track isLoading = true;
  @track isSaving = false;
  originalMasterLabel;

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  // Filters
  @track roleFilter = "";
  @track featureFilter = "";

  filterRoleOptions = [
    { label: "All Roles", value: "" },
    { label: "HR_Admin", value: "HR_Admin" },
    { label: "Manager", value: "Manager" },
    { label: "Employee", value: "Employee" },
    { label: "Payroll_Admin", value: "Payroll_Admin" }
  ];

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" }
  ];

  connectedCallback() {
    this.loadMappings();
  }

  loadMappings() {
    this.isLoading = true;
    getMappings({
      callerPortalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        this.allMappings = result;
        this.applyFilters();
      })
      .catch(() => {
        this.showToast("Error", "Error loading mappings", "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Filter and Pagination Methods
  applyFilters() {
    let filtered = [...this.allMappings];

    if (this.roleFilter) {
      filtered = filtered.filter((item) => item.Role__c === this.roleFilter);
    }

    if (this.featureFilter) {
      const search = this.featureFilter.toLowerCase();
      filtered = filtered.filter((item) =>
        item.Feature__c?.toLowerCase().includes(search)
      );
    }

    this._filteredMappings = filtered;

    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.mappings = filtered.slice(start, end);
  }

  handleRoleFilter(event) {
    this.roleFilter = event.detail.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handleFeatureFilter(event) {
    this.featureFilter = event.target.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.applyFilters();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.applyFilters();
    }
  }

  get totalRecords() {
    return this._filteredMappings ? this._filteredMappings.length : 0;
  }

  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize) || 1;
  }

  get paginationInfo() {
    if (this.totalRecords === 0) return "0 records";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
    return `${start}-${end} of ${this.totalRecords}`;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get hasMappings() {
    return this.mappings && this.mappings.length > 0;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    switch (actionName) {
      case "edit":
        this.editRecord(row);
        break;
      case "delete":
        this.deleteRecord(row);
        break;
      default:
        break;
    }
  }

  handleNewMapping() {
    this.currentRecord = {};
    this.originalMasterLabel = null;
    this.isModalOpen = true;
  }

  editRecord(row) {
    this.currentRecord = { ...row };
    this.originalMasterLabel = row.MasterLabel;
    this.isModalOpen = true;
  }

  deleteRecord(row) {
    const mappingName = row.MasterLabel.replaceAll(" ", "_");
    deleteMapping({
      mappingName: mappingName,
      callerPortalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Mapping deletion initiated.", "success");
        // Add a delay to allow metadata to refresh
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
          this.loadMappings();
        }, 3000);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error deleting mapping: " +
            (error.body?.message || error.message || "Unknown error"),
          "error"
        );
      });
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleModalClick(event) {
    event.stopPropagation();
  }

  handleInputChange(event) {
    this.currentRecord[event.target.dataset.id] = event.target.value;
  }

  handleSave() {
    const { Role__c, Feature__c } = this.currentRecord;
    if (!Role__c || !Feature__c) {
      this.showToast("Error", "Both Role and Feature are required.", "error");
      return;
    }

    this.isSaving = true;
    const savePromise =
      this.originalMasterLabel &&
      this.originalMasterLabel !== Role__c + " " + Feature__c
        ? deleteMapping({
            mappingName: this.originalMasterLabel.replaceAll(" ", "_"),
            callerPortalUserId: this.portalUserId,
            sessionToken: this.sessionToken
          })
        : Promise.resolve();

    savePromise
      .then(() => {
        return saveMapping({
          role: Role__c,
          feature: Feature__c,
          callerPortalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        });
      })
      .then(() => {
        this.showToast("Success", "Mapping save initiated.", "success");
        this.isModalOpen = false;
        // Add a delay to allow metadata to refresh
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
          this.loadMappings();
        }, 3000);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error saving mapping: " +
            (error.body?.message || error.message || "Unknown error"),
          "error"
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}