import { LightningElement, api, track } from "lwc";

export default class TimesheetManager extends LightningElement {
  // 1. Receive data from parent via @api
  @api timesheetDataFromParent = [];

  @track filteredData = [];
  @track isModalOpen = false;
  @track projectOptions = [
    "Office Management",
    "Project Management",
    "Hospital Administration"
  ];

  searchTerm = "";
  sortDirection = "asc";

  // 2. Load data from parent into tracked variable
  connectedCallback() {
    this.loadData();
  }

  loadData() {
    if (
      this.timesheetDataFromParent &&
      this.timesheetDataFromParent.length > 0
    ) {
      this.filteredData = [...this.timesheetDataFromParent];
    } else {
      this.filteredData = [];
    }
  }

  // 3. Search logic
  handleSearch(event) {
    this.searchTerm = event.target.value.toLowerCase();
    this.applyFilters();
  }

  // 4. Project Filter logic
  handleProjectFilter(event) {
    const projectName = event.target.dataset.name;
    this.filteredData = this.timesheetDataFromParent.filter(
      (item) => item.projectName === projectName
    );
  }

  // 5. Global Filter and Refresh
  applyFilters() {
    this.filteredData = this.timesheetDataFromParent.filter((row) => {
      return (
        row.employeeName.toLowerCase().includes(this.searchTerm) ||
        row.projectName.toLowerCase().includes(this.searchTerm)
      );
    });
  }

  // 6. Table Sorting logic (Toggle ASC/DESC)
  handleSort(event) {
    const field = event.currentTarget.dataset.field || "employeeName";
    this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";

    const data = [...this.filteredData];
    data.sort((a, b) => {
      let valA = a[field] ? a[field].toLowerCase() : "";
      let valB = b[field] ? b[field].toLowerCase() : "";

      if (this.sortDirection === "asc") {
        return valA > valB ? 1 : -1;
      }
      return valA < valB ? 1 : -1;
    });
    this.filteredData = data;
  }

  // 7. Modal Handlers
  openAddModal() {
    this.isModalOpen = true;
  }

  closeAddModal() {
    this.isModalOpen = false;
  }

  handleFormSubmit(event) {
    event.preventDefault();
    // Capture form data
    this.closeAddModal();
    // Fire custom event to parent to save data
  }

  // 8. Action buttons (no-op until wired to Apex)
  exportPDF() {
    return undefined;
  }
  exportExcel() {
    return undefined;
  }
  handleEdit() {
    return undefined;
  }
  handleDelete() {
    return undefined;
  }
}