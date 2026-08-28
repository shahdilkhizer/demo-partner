import { LightningElement, api, track } from "lwc";

export default class TrainingManagement extends LightningElement {
  @api pageTitle = "Training";
  @api breadcrumbParent = "Performance";
  @api breadcrumbActive = "Add Training";
  @api addBtnLabel = "Add Training";
  @api listTitle = "Training List";
  @api sortByLabel = "Sort By : Last 7 Days";

  @track trainingData = [];
  @track isModalOpen = false;
  @track isEditing = false; // Logical flag for Edit vs Add
  @track selectedTraining = {};

  connectedCallback() {
    this.loadComponent();
  }

  @api
  loadComponent() {
    const mockRecords = [
      {
        id: "1",
        type: "Git Training",
        trainerName: "Anthony Lewis",
        trainerImg: "assets/img/users/user-32.jpg",
        duration: "12 Jan 2024 - 12 Feb 2024",
        cost: "$200",
        status: "Active",
        description: "Version control and code collaboration.",
        employees: [{ id: "e1", img: "assets/img/users/user-01.jpg" }],
        extraCount: "+4"
      }
    ];
    this.refreshTable(mockRecords);
  }

  // Helper to apply badge classes
  refreshTable(data) {
    this.trainingData = data.map((item) => ({
      ...item,
      statusClass:
        item.status === "Active" ? "badge badge-success" : "badge badge-danger"
    }));
  }

  handleActionClick(event) {
    const action = event.currentTarget.dataset.action;
    const recordId = event.currentTarget.dataset.id;

    switch (action) {
      case "openAdd":
        this.isEditing = false;
        this.selectedTraining = {
          id: Date.now().toString(),
          status: "Active",
          employees: [],
          extraCount: "+0"
        };
        this.isModalOpen = true;
        break;
      case "edit": {
        this.isEditing = true;
        const record = this.trainingData.find((item) => item.id === recordId);
        this.selectedTraining = { ...record };
        this.isModalOpen = true;
        break;
      }
      case "delete": {
        const filtered = this.trainingData.filter(
          (item) => item.id !== recordId
        );
        this.refreshTable(filtered);
        break;
      }
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
    this.selectedTraining[event.target.name] = event.target.value;
  }

  handleSave() {
    let updatedList = [...this.trainingData];
    if (this.isEditing) {
      // Logic for EDIT
      updatedList = updatedList.map((item) => {
        if (item.id === this.selectedTraining.id) {
          return { ...this.selectedTraining };
        }
        return item;
      });
    } else {
      // Logic for ADD
      updatedList.push({ ...this.selectedTraining });
    }
    this.refreshTable(updatedList);
    this.isModalOpen = false;
  }
}