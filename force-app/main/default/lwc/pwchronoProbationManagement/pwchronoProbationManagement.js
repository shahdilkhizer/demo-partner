import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import {
  INITIAL_PROBATION_RECORDS,
  DESIGNATION_OPTIONS,
  REVIEWER_OPTIONS
} from "./pwchronoProbationConstants";

export default class PwchronoProbationManagement extends LightningElement {
  @track records = [];
  @track searchKeyword = "";
  @track selectedDesignation = "";
  @track currentSort = "Last 7 Days";

  @track isExportOpen = false;
  @track isDesigOpen = false;
  @track isSortOpen = false;
  @track isCollapsed = false;

  @track isDetailsOpen = false;
  @track isAddModalOpen = false;
  @track isEditModalOpen = false;
  @track isDeleteModalOpen = false;

  @track activeRecord = null;
  @track deletingId = null;
  @track addForm = {};
  @track editForm = {};

  connectedCallback() {
    this.records = INITIAL_PROBATION_RECORDS.map((r) => ({
      ...r,
      selected: false,
      team: this.resolveTeam(r.designation),
      avatarUrl: `${smarthrAssets}/assets/img/users/${r.img || "user-11.jpg"}`,
      reviewerAvatarUrl: `${smarthrAssets}/assets/img/users/${r.reviewerImg || "user-01.jpg"}`,
      badgeClass: this.resolveBadgeClass(r.status)
    }));
  }

  resolveTeam(designation) {
    if (!designation) return "Operations";
    if (designation.includes("Developer") || designation.includes("Technician")) return "Engineering";
    if (designation.includes("Account")) return "Finance";
    if (designation.includes("Sales") || designation.includes("SEO")) return "Marketing";
    return "HR & Admin";
  }

  resolveBadgeClass(status) {
    const s = (status || "").toLowerCase();
    if (s === "completed") return "badge badge-soft-success d-inline-flex align-items-center badge-xs";
    if (s === "in review") return "badge badge-soft-warning d-inline-flex align-items-center badge-xs";
    if (s === "failed") return "badge badge-soft-danger d-inline-flex align-items-center badge-xs";
    if (s === "extended") return "badge badge-soft-secondary d-inline-flex align-items-center badge-xs";
    return "badge badge-soft-info d-inline-flex align-items-center badge-xs";
  }

  get collapseIcon() {
    return this.isCollapsed ? "ti ti-chevrons-down" : "ti ti-chevrons-up";
  }

  get designationOptions() {
    return DESIGNATION_OPTIONS;
  }

  get reviewerOptions() {
    return REVIEWER_OPTIONS;
  }

  get selectedDesignationLabel() {
    return this.selectedDesignation || "Designation";
  }

  get displayedRecords() {
    let list = [...this.records];
    if (this.searchKeyword && this.searchKeyword.trim()) {
      const q = this.searchKeyword.toLowerCase().trim();
      list = list.filter(
        (r) =>
          r.name.toLowerCase().includes(q) ||
          r.empId.toLowerCase().includes(q) ||
          r.designation.toLowerCase().includes(q) ||
          r.reviewerName.toLowerCase().includes(q)
      );
    }
    if (this.selectedDesignation) {
      list = list.filter((r) => r.designation === this.selectedDesignation);
    }
    if (this.currentSort === "Ascending") {
      list.sort((a, b) => a.name.localeCompare(b.name));
    } else if (this.currentSort === "Descending") {
      list.sort((a, b) => b.name.localeCompare(a.name));
    }
    return list;
  }

  get displayedCount() {
    return this.displayedRecords.length;
  }

  get isAllSelected() {
    const list = this.displayedRecords;
    return list.length > 0 && list.every((r) => r.selected);
  }

  toggleCollapse() {
    this.isCollapsed = !this.isCollapsed;
  }

  toggleExportDropdown() {
    this.isExportOpen = !this.isExportOpen;
  }

  toggleDesigDropdown() {
    this.isDesigOpen = !this.isDesigOpen;
  }

  toggleSortDropdown() {
    this.isSortOpen = !this.isSortOpen;
  }

  selectDesignation(e) {
    this.selectedDesignation = e.currentTarget.dataset.desig;
    this.isDesigOpen = false;
  }

  selectSort(e) {
    this.currentSort = e.currentTarget.dataset.sort;
    this.isSortOpen = false;
  }

  handleSearch(e) {
    this.searchKeyword = e.target.value;
  }

  handleSelectAll(e) {
    const isChecked = e.target.checked;
    this.records = this.records.map((r) => ({ ...r, selected: isChecked }));
  }

  handleSelectRow(e) {
    const id = e.target.dataset.id;
    const isChecked = e.target.checked;
    this.records = this.records.map((r) =>
      r.id === id ? { ...r, selected: isChecked } : r
    );
  }

  openDetails(e) {
    const id = e.currentTarget.dataset.id;
    const item = this.records.find((r) => r.id === id);
    if (item) {
      this.activeRecord = item;
      this.isDetailsOpen = true;
    }
  }

  closeDetails() {
    this.isDetailsOpen = false;
    this.activeRecord = null;
  }

  openAddModal() {
    this.addForm = {
      name: "",
      designation: "Accountant",
      joiningDate: new Date().toISOString().split("T")[0],
      endDate: new Date(Date.now() + 90 * 86400000).toISOString().split("T")[0],
      reviewerName: "William Parsons",
      status: "Pending"
    };
    this.isAddModalOpen = true;
  }

  closeAddModal() {
    this.isAddModalOpen = false;
  }

  handleAddFormChange(e) {
    const field = e.target.dataset.field;
    this.addForm[field] = e.target.value;
  }

  saveNewEmployee() {
    if (!this.addForm.name) {
      this.showToast("Required", "Please enter Employee Name", "error");
      return;
    }
    const nextIdx = this.records.length + 1;
    const newRecord = {
      id: "emp-" + Date.now(),
      empId: "Emp-" + String(nextIdx).padStart(3, "0"),
      name: this.addForm.name,
      img: "user-11.jpg",
      avatarUrl: `${smarthrAssets}/assets/img/users/user-11.jpg`,
      reviewerImg: "user-01.jpg",
      reviewerAvatarUrl: `${smarthrAssets}/assets/img/users/user-01.jpg`,
      designation: this.addForm.designation || "Accountant",
      team: this.resolveTeam(this.addForm.designation),
      joiningDate: this.addForm.joiningDate,
      endDate: this.addForm.endDate,
      reviewerName: this.addForm.reviewerName || "William Parsons",
      status: this.addForm.status || "Pending",
      badgeClass: this.resolveBadgeClass(this.addForm.status || "Pending"),
      selected: false
    };
    this.records = [newRecord, ...this.records];
    this.isAddModalOpen = false;
    this.showToast("Success", "Employee added to Probation List", "success");
  }

  openEditModal(e) {
    const id = e.currentTarget.dataset.id;
    const item = this.records.find((r) => r.id === id);
    if (item) {
      this.editForm = { ...item };
      this.isEditModalOpen = true;
    }
  }

  closeEditModal() {
    this.isEditModalOpen = false;
  }

  handleEditFormChange(e) {
    const field = e.target.dataset.field;
    this.editForm[field] = e.target.value;
  }

  saveEditEmployee() {
    this.records = this.records.map((r) => {
      if (r.id === this.editForm.id) {
        return {
          ...r,
          name: this.editForm.name,
          designation: this.editForm.designation,
          joiningDate: this.editForm.joiningDate,
          endDate: this.editForm.endDate,
          reviewerName: this.editForm.reviewerName,
          status: this.editForm.status,
          badgeClass: this.resolveBadgeClass(this.editForm.status)
        };
      }
      return r;
    });
    this.isEditModalOpen = false;
    this.showToast("Success", "Employee record updated successfully", "success");
  }

  openDeleteModal(e) {
    this.deletingId = e.currentTarget.dataset.id;
    this.isDeleteModalOpen = true;
  }

  closeDeleteModal() {
    this.isDeleteModalOpen = false;
    this.deletingId = null;
  }

  confirmDelete() {
    if (this.deletingId) {
      this.records = this.records.filter((r) => r.id !== this.deletingId);
    } else {
      this.records = this.records.filter((r) => !r.selected);
    }
    this.isDeleteModalOpen = false;
    this.deletingId = null;
    this.showToast("Success", "Record deleted successfully", "success");
  }

  exportPDF() {
    this.isExportOpen = false;
    window.print();
  }

  exportExcel() {
    this.isExportOpen = false;
    this.showToast("Export", "Export to Excel started", "info");
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
