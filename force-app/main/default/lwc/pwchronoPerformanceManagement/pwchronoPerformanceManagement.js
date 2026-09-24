import { LightningElement, api, track } from "lwc";

export default class PwchronoPerformanceManagement extends LightningElement {
  // Label placeholders (No hardcoding)
  pageTitle;
  breadcrumbParent;
  breadcrumbActive;
  addBtnLabel;
  listTitle;
  sortByLabel;

  // Table Header Labels
  colDesignation;
  colDepartment;
  colApprovedBy;
  colCreatedDate;
  colStatus;

  @track indicatorData = [];
  @track isModalOpen = false;
  @track isEditing = false;
  @track selectedIndicator = {};

  connectedCallback() {
    this.loadComponentData();
  }

  /**
   * LOAD FUNCTION: Initializes all labels and mock data
   */
  @api
  loadComponentData() {
    // Labels initialization
    this.pageTitle = "Performance Indicator";
    this.breadcrumbParent = "Performance";
    this.breadcrumbActive = "Performance Indicator";
    this.addBtnLabel = "Add New Indicator";
    this.listTitle = "Performance Indicator List";
    this.sortByLabel = "Sort By : Last 7 Days";

    this.colDesignation = "Designation";
    this.colDepartment = "Department";
    this.colApprovedBy = "Approved By";
    this.colCreatedDate = "Created Date";
    this.colStatus = "Status";

    // Mock Data
    const mockData = [
      {
        id: "1",
        designation: "Web Designer",
        department: "Designing",
        approvedByName: "Doglas Martini",
        approvedByRole: "Manager",
        approvedByImg: "assets/img/users/user-34.jpg",
        createdDate: "14 Jan 2024",
        status: "Active"
      }
    ];

    this.refreshTable(mockData);
  }

  refreshTable(data) {
    this.indicatorData = data.map((item) => ({
      ...item,
      statusClass:
        item.status === "Active"
          ? "badge badge-success d-inline-flex align-items-center badge-xs"
          : "badge badge-danger d-inline-flex align-items-center badge-xs"
    }));
  }

  handleActionClick(event) {
    const action = event.currentTarget.dataset.action;
    const recordId = event.currentTarget.dataset.id;

    switch (action) {
      case "openAdd":
        this.isEditing = false;
        this.selectedIndicator = { status: "Active" };
        this.isModalOpen = true;
        break;
      case "edit": {
        this.isEditing = true;
        const record = this.indicatorData.find((item) => item.id === recordId);
        this.selectedIndicator = { ...record };
        this.isModalOpen = true;
        break;
      }
      case "delete":
        this.refreshTable(
          this.indicatorData.filter((item) => item.id !== recordId)
        );
        break;
      case "closeModal":
        this.isModalOpen = false;
        break;
      case "save":
        this.handleSave();
        break;
      default:
        break;
    }
  }

  handleInputChange(event) {
    this.selectedIndicator[event.target.name] = event.target.value;
  }

  handleSave() {
    let currentData = [...this.indicatorData];
    if (this.isEditing) {
      currentData = currentData.map((item) => {
        if (item.id === this.selectedIndicator.id) {
          return { ...this.selectedIndicator };
        }
        return item;
      });
    } else {
      currentData.push({
        ...this.selectedIndicator,
        id: Date.now().toString(),
        createdDate: "Today"
      });
    }
    this.refreshTable(currentData);
    this.isModalOpen = false;
  }
}