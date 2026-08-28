import { LightningElement, api, track } from "lwc";

export default class OvertimeManagement extends LightningElement {
  @api parentOvertimeData = []; // Data from parent
  @track filteredData = [];
  @track isModalOpen = false;
  @track stats = [
    {
      label: "Overtime Employee",
      value: "12",
      iconClass: "ti ti-user-check text-primary fs-18",
      iconBgClass:
        "p-2 br-10 bg-transparent-primary border border-primary d-flex align-items-center justify-content-center"
    },
    {
      label: "Overtime Hours",
      value: "118",
      iconClass: "ti ti-user-edit text-pink fs-18",
      iconBgClass:
        "p-2 br-10 bg-pink-transparent border border-pink d-flex align-items-center justify-content-center"
    },
    {
      label: "Pending Request",
      value: "23",
      iconClass: "ti ti-user-exclamation text-purple fs-18",
      iconBgClass:
        "p-2 br-10 bg-transparent-purple border border-purple d-flex align-items-center justify-content-center"
    },
    {
      label: "Rejected",
      value: "5",
      iconClass: "ti ti-user-exclamation text-skyblue fs-18",
      iconBgClass:
        "p-2 br-10 bg-skyblue-transparent border border-skyblue d-flex align-items-center justify-content-center"
    }
  ];

  employeeOptions = ["Anthony Lewis", "Brian Villalobos", "Harvey Smith"];
  searchTerm = "";

  connectedCallback() {
    this.loadData();
  }

  loadData() {
    if (this.parentOvertimeData && this.parentOvertimeData.length > 0) {
      this.filteredData = [...this.parentOvertimeData];
    } else {
      // Sample data fallback
      this.filteredData = [
        {
          id: 1,
          name: "Anthony Lewis",
          team: "UI/UX Team",
          date: "14 Jan 2024",
          hours: "32",
          project: "Office Management",
          approvedBy: "Michael Walker",
          status: "Accepted",
          statusBadgeClass:
            "badge badge-success d-inline-flex align-items-center badge-xs",
          userImg: "assets/img/users/user-32.jpg",
          approvedByImg: "assets/img/users/user-39.jpg"
        }
      ];
    }
  }

  // Modal Handlers
  openAddModal() {
    this.isModalOpen = true;
  }
  closeModal() {
    this.isModalOpen = false;
  }

  // Logic Handlers
  handleSearch(event) {
    this.searchTerm = event.target.value.toLowerCase();
    this.applyFilters();
  }

  handleFilter(event) {
    const status = event.target.dataset.status;
    this.filteredData = this.parentOvertimeData.filter(
      (item) => item.status === status
    );
  }

  applyFilters() {
    this.filteredData = this.parentOvertimeData.filter(
      (item) =>
        item.name.toLowerCase().includes(this.searchTerm) ||
        item.project.toLowerCase().includes(this.searchTerm)
    );
  }

  handleSave(event) {
    event.preventDefault();
    const formData = new FormData(event.target);
    this.dispatchEvent(
      new CustomEvent("saveovertime", {
        detail: Object.fromEntries(formData),
        bubbles: true,
        composed: true
      })
    );
    this.closeModal();
  }

  // Buttons actions
  exportPDF() {
    this.dispatchEvent(
      new CustomEvent("exportpdf", { bubbles: true, composed: true })
    );
  }
  exportExcel() {
    this.dispatchEvent(
      new CustomEvent("exportexcel", { bubbles: true, composed: true })
    );
  }
  handleEdit(event) {
    this.dispatchEvent(
      new CustomEvent("editovertime", {
        detail: { id: event.currentTarget.dataset.id },
        bubbles: true,
        composed: true
      })
    );
  }
  handleDelete(event) {
    this.dispatchEvent(
      new CustomEvent("deleteovertime", {
        detail: { id: event.currentTarget.dataset.id },
        bubbles: true,
        composed: true
      })
    );
  }
}