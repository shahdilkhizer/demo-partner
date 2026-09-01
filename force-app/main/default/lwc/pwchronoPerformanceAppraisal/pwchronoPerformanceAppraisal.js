import { LightningElement, track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  DOGLAS_MARTINI_AVATAR,
  INITIAL_PERFORMANCE_INDICATORS
} from "./pwchronoPerformanceConstants";

const DESIGNATION_LIST = [
  "Web Designer",
  "Web Developer",
  "IOS Developer",
  "Android Developer",
  "DevOps Engineer"
];

const DESIGNATION_DEPT_MAP = {
  "Web Designer": "Designing",
  "Web Developer": "Developer",
  "IOS Developer": "Developer",
  "Android Developer": "Developer",
  "DevOps Engineer": "DevOps"
};

export default class PerformanceAppraisal extends LightningElement {
  @track indicators = [];
  @track currentSort = "Last 7 Days";
  @track isSortDropdownOpen = false;
  @track searchKeyword = "";
  @track pageSize = 10;
  @track isCollapsed = false;

  @track isAddModalOpen = false;
  @track isEditModalOpen = false;
  @track isDeleteModalOpen = false;
  @track deletingId = null;

  @track addForm = {};
  @track editForm = {};

  connectedCallback() {
    this.indicators = INITIAL_PERFORMANCE_INDICATORS.map((item) => ({
      ...item,
      avatarUrl: DOGLAS_MARTINI_AVATAR
    }));
  }

  get collapseIcon() {
    return this.isCollapsed ? "ti ti-chevrons-down" : "ti ti-chevrons-up";
  }

  get displayedIndicators() {
    let result = [...this.indicators];

    if (this.searchKeyword && this.searchKeyword.trim()) {
      const q = this.searchKeyword.toLowerCase().trim();
      result = result.filter(
        (i) =>
          (i.designation && i.designation.toLowerCase().includes(q)) ||
          (i.department && i.department.toLowerCase().includes(q)) ||
          (i.approvedByName && i.approvedByName.toLowerCase().includes(q)) ||
          (i.status && i.status.toLowerCase().includes(q))
      );
    }

    if (this.currentSort === "Ascending") {
      result.sort((a, b) => a.designation.localeCompare(b.designation));
    } else if (this.currentSort === "Descending") {
      result.sort((a, b) => b.designation.localeCompare(a.designation));
    }

    return result.slice(0, this.pageSize);
  }

  get displayedCount() {
    return this.displayedIndicators.length;
  }

  get hasData() {
    return this.displayedIndicators.length > 0;
  }

  get isAllSelected() {
    const list = this.displayedIndicators;
    return list.length > 0 && list.every((item) => item.selected);
  }

  get designationOptions() {
    const current = this.editForm.designation || "";
    return DESIGNATION_LIST.map((d) => ({
      value: d,
      label: d,
      selected: d === current
    }));
  }

  get isCustExpAdv() {
    return (this.editForm.customerExperience || "Advanced") === "Advanced";
  }
  get isCustExpInt() {
    return this.editForm.customerExperience === "Intermediate";
  }
  get isCustExpAvg() {
    return this.editForm.customerExperience === "Average";
  }

  get isMktgExp() {
    return (this.editForm.marketing || "Expert/Leader") === "Expert/Leader";
  }
  get isMktgInt() {
    return this.editForm.marketing === "Intermediate";
  }
  get isMktgAvg() {
    return this.editForm.marketing === "Average";
  }

  get isMgmtInt() {
    return (this.editForm.management || "Intermediate") === "Intermediate";
  }
  get isMgmtMed() {
    return this.editForm.management === "Medium";
  }
  get isMgmtAvg() {
    return this.editForm.management === "Average";
  }

  get isAdminAdv() {
    return (this.editForm.administration || "Advanced") === "Advanced";
  }
  get isAdminInt() {
    return this.editForm.administration === "Intermediate";
  }
  get isAdminAvg() {
    return this.editForm.administration === "Average";
  }

  get isPresNone() {
    return (this.editForm.presentationSkills || "None") === "None";
  }
  get isPresInt() {
    return this.editForm.presentationSkills === "Intermediate";
  }
  get isPresAvg() {
    return this.editForm.presentationSkills === "Average";
  }

  get isQualityNone() {
    return (this.editForm.qualityOfWork || "None") === "None";
  }
  get isQualityInt() {
    return this.editForm.qualityOfWork === "Intermediate";
  }
  get isQualityAvg() {
    return this.editForm.qualityOfWork === "Average";
  }

  get isEffNone() {
    return (this.editForm.efficiency || "None") === "None";
  }
  get isEffInt() {
    return this.editForm.efficiency === "Intermediate";
  }
  get isEffAvg() {
    return this.editForm.efficiency === "Average";
  }

  get isIntegNone() {
    return (this.editForm.integrity || "None") === "None";
  }
  get isIntegInt() {
    return this.editForm.integrity === "Intermediate";
  }
  get isIntegAvg() {
    return this.editForm.integrity === "Average";
  }

  get isProfAdv() {
    return (this.editForm.professionalism || "Advanced") === "Advanced";
  }
  get isProfInt() {
    return this.editForm.professionalism === "Intermediate";
  }
  get isProfAvg() {
    return this.editForm.professionalism === "Average";
  }

  get isTeamNone() {
    return (this.editForm.teamWork || "None") === "None";
  }
  get isTeamInt() {
    return this.editForm.teamWork === "Intermediate";
  }
  get isTeamAvg() {
    return this.editForm.teamWork === "Average";
  }

  get isCritAdv() {
    return (this.editForm.criticalThinking || "Advanced") === "Advanced";
  }
  get isCritInt() {
    return this.editForm.criticalThinking === "Intermediate";
  }
  get isCritAvg() {
    return this.editForm.criticalThinking === "Average";
  }

  get isConfAdv() {
    return (this.editForm.conflictManagement || "Advanced") === "Advanced";
  }
  get isConfInt() {
    return this.editForm.conflictManagement === "Intermediate";
  }
  get isConfAvg() {
    return this.editForm.conflictManagement === "Average";
  }

  get isAttAdv() {
    return (this.editForm.attendance || "Advanced") === "Advanced";
  }
  get isAttInt() {
    return this.editForm.attendance === "Intermediate";
  }
  get isAttAvg() {
    return this.editForm.attendance === "Average";
  }

  get isDeadAdv() {
    return (this.editForm.abilityToMeetDeadline || "Advanced") === "Advanced";
  }
  get isDeadInt() {
    return this.editForm.abilityToMeetDeadline === "Intermediate";
  }
  get isDeadAvg() {
    return this.editForm.abilityToMeetDeadline === "Average";
  }

  get isEditActive() {
    return (this.editForm.status || "Active") === "Active";
  }
  get isEditInactive() {
    return this.editForm.status === "Inactive";
  }

  toggleCollapse() {
    this.isCollapsed = !this.isCollapsed;
  }

  toggleSortDropdown() {
    this.isSortDropdownOpen = !this.isSortDropdownOpen;
  }

  selectSort(e) {
    this.currentSort = e.currentTarget.dataset.sort;
    this.isSortDropdownOpen = false;
  }

  handleSearch(e) {
    this.searchKeyword = e.target.value;
  }

  handlePageSizeChange(e) {
    this.pageSize = parseInt(e.target.value, 10) || 10;
  }

  handleSelectAll(e) {
    const isChecked = e.target.checked;
    this.indicators = this.indicators.map((item) => ({
      ...item,
      selected: isChecked
    }));
  }

  handleSelectRow(e) {
    const id = e.target.dataset.id;
    const isChecked = e.target.checked;
    this.indicators = this.indicators.map((item) =>
      item.id === id ? { ...item, selected: isChecked } : item
    );
  }

  openAddModal() {
    this.addForm = {
      designation: "Web Designer",
      customerExperience: "Advanced",
      marketing: "Expert/Leader",
      management: "Intermediate",
      administration: "Advanced",
      presentationSkills: "None",
      qualityOfWork: "None",
      efficiency: "None",
      integrity: "None",
      professionalism: "Advanced",
      teamWork: "None",
      criticalThinking: "Advanced",
      conflictManagement: "Advanced",
      attendance: "Advanced",
      abilityToMeetDeadline: "Advanced",
      status: "Active"
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

  saveNewIndicator() {
    const des = this.addForm.designation || "Web Designer";
    const dept = DESIGNATION_DEPT_MAP[des] || "Developer";
    const newRecord = {
      id: "ind-" + Date.now(),
      designation: des,
      department: dept,
      approvedByName: "Doglas Martini",
      approvedByRole: "Manager",
      createdDate: new Date().toLocaleDateString("en-GB", {
        day: "2-digit",
        month: "short",
        year: "numeric"
      }),
      status: this.addForm.status || "Active",
      selected: false,
      avatarUrl: DOGLAS_MARTINI_AVATAR,
      technical: { ...this.addForm },
      organizational: { ...this.addForm }
    };

    this.indicators = [newRecord, ...this.indicators];
    this.isAddModalOpen = false;
    this.showToast("Success", "Performance Indicator added successfully", "success");
  }

  openEditModal(e) {
    const id = e.currentTarget.dataset.id;
    const item = this.indicators.find((i) => i.id === id);
    if (item) {
      this.editForm = {
        id: item.id,
        designation: item.designation,
        status: item.status,
        ...(item.technical || {}),
        ...(item.organizational || {})
      };
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

  saveEditIndicator() {
    const des = this.editForm.designation;
    const dept = DESIGNATION_DEPT_MAP[des] || "Developer";

    this.indicators = this.indicators.map((item) => {
      if (item.id === this.editForm.id) {
        return {
          ...item,
          designation: des,
          department: dept,
          status: this.editForm.status || item.status,
          technical: {
            customerExperience: this.editForm.customerExperience,
            marketing: this.editForm.marketing,
            management: this.editForm.management,
            administration: this.editForm.administration,
            presentationSkills: this.editForm.presentationSkills,
            qualityOfWork: this.editForm.qualityOfWork,
            efficiency: this.editForm.efficiency
          },
          organizational: {
            integrity: this.editForm.integrity,
            professionalism: this.editForm.professionalism,
            teamWork: this.editForm.teamWork,
            criticalThinking: this.editForm.criticalThinking,
            conflictManagement: this.editForm.conflictManagement,
            attendance: this.editForm.attendance,
            abilityToMeetDeadline: this.editForm.abilityToMeetDeadline
          }
        };
      }
      return item;
    });

    this.isEditModalOpen = false;
    this.showToast("Success", "Indicator updated successfully", "success");
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
      this.indicators = this.indicators.filter((i) => i.id !== this.deletingId);
    } else {
      this.indicators = this.indicators.filter((i) => !i.selected);
    }
    this.isDeleteModalOpen = false;
    this.deletingId = null;
    this.showToast("Success", "Record deleted successfully", "success");
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}


