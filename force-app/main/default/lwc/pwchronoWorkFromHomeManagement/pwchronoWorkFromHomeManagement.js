import { LightningElement, api, track } from "lwc";

export default class WfhChildManagement extends LightningElement {
  @api parentData = []; // Data passed from parent
  @track allRequests = [];
  @track visibleRequests = [];
  @track isAddModalOpen = false;

  // Filters and UI Config
  filterConfigs = [
    {
      label: "Designation",
      type: "designation",
      options: ["Accountant", "App Developer", "Technician", "Web Developer"]
    },
    { label: "Shift", type: "shift", options: ["Regular", "Night"] },
    {
      label: "Status",
      type: "status",
      options: ["Approved", "Pending", "Rejected", "Completed"]
    }
  ];

  connectedCallback() {
    this.loadInitialData();
  }

  // Initialize with data from parent or sample if empty
  loadInitialData() {
    if (this.parentData && this.parentData.length > 0) {
      this.allRequests = [...this.parentData];
    } else {
      // Sample Data for Load UI demonstration
      this.allRequests = [
        {
          id: 1,
          empId: "Emp-001",
          name: "Anthony Lewis",
          userImage: "/assets/img/users/user-11.jpg",
          designation: "Accountant",
          shift: "Regular",
          reason: "Mild health issue",
          date: "14 Jun 2025",
          status: "Approved",
          statusClass:
            "badge badge-soft-success d-inline-flex align-items-center badge-xs"
        },
        {
          id: 2,
          empId: "Emp-002",
          name: "Brian Villalobos",
          userImage: "/assets/img/users/user-12.jpg",
          designation: "App Developer",
          shift: "Regular",
          reason: "Internet issue",
          date: "25 May 2025",
          status: "Pending",
          statusClass:
            "badge badge-soft-info d-inline-flex align-items-center badge-xs"
        }
      ];
    }
    this.visibleRequests = [...this.allRequests];
  }

  get totalRecords() {
    return this.visibleRequests.length;
  }

  // Actions & Handlers
  handleSearch(event) {
    const key = event.target.value.toLowerCase();
    this.visibleRequests = this.allRequests.filter(
      (req) =>
        req.name.toLowerCase().includes(key) ||
        req.empId.toLowerCase().includes(key)
    );
  }

  handleDropdownFilter(event) {
    const type = event.currentTarget.dataset.type;
    const value = event.currentTarget.dataset.value;
    this.visibleRequests = this.allRequests.filter(
      (req) => req[type] === value
    );
  }

  handleSelectAll(event) {
    const isChecked = event.target.checked;
    this.visibleRequests = this.visibleRequests.map((req) => ({
      ...req,
      selected: isChecked
    }));
  }

  handleOpenAddModal() {
    this.isAddModalOpen = true;
  }

  handleCloseModal() {
    this.isAddModalOpen = false;
  }

  handleSaveNewRequest(event) {
    event.preventDefault();
    const inputs = event.target.elements;
    const newReq = {
      id: Math.random(),
      empId: "Emp-" + Math.floor(100 + Math.random() * 900),
      name: inputs.name.value,
      designation: inputs.designation.value,
      shift: inputs.shift.value,
      reason: inputs.reviewer.value, // Mapping reviewer text to reason for sample
      date: new Date().toLocaleDateString(),
      status: "Pending",
      statusClass:
        "badge badge-soft-info d-inline-flex align-items-center badge-xs"
    };

    this.allRequests = [newReq, ...this.allRequests];
    this.visibleRequests = [...this.allRequests];
    this.handleCloseModal();
  }

  handleExportPDF() {
    this.dispatchEvent(
      new CustomEvent("exportpdf", { bubbles: true, composed: true })
    );
  }

  handleExportExcel() {
    this.dispatchEvent(
      new CustomEvent("exportexcel", { bubbles: true, composed: true })
    );
  }

  handleEdit(event) {
    this.dispatchEvent(
      new CustomEvent("editrequest", {
        detail: { id: event.currentTarget.dataset.id },
        bubbles: true,
        composed: true
      })
    );
  }

  handleFilterChange(event) {
    this.dispatchEvent(
      new CustomEvent("datefilterchange", {
        detail: { value: event.target.value },
        bubbles: true,
        composed: true
      })
    );
  }

  handlePageSizeChange(event) {
    this.dispatchEvent(
      new CustomEvent("pagesizechange", {
        detail: { value: event.target.value },
        bubbles: true,
        composed: true
      })
    );
  }
}