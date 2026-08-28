import { LightningElement, api, track } from "lwc";

export default class PerformanceReview extends LightningElement {
  // Standard Labels
  @api pageTitle = "Performance Review";
  @api breadcrumbParent = "Performance";
  @api breadcrumbActive = "Performance Review";

  // Section Titles
  @api basicInfoTitle = "Employee Basic Information";
  @api profExcellenceTitle = "Professional Excellence";
  @api personalExcellenceTitle = "Personal Excellence";
  @api achievementsTitle =
    "Special Initiatives, Achievements, contributions if any";

  // Dynamic Data for Parent to Control
  @track basicInfoFields = [];
  @track profExcellenceRows = [];
  @track personalExcellenceRows = [];
  @track achievementRows = [];
  @track signatureRows = [];

  connectedCallback() {
    this.loadComponentData();
  }

  @api
  loadComponentData() {
    // 1. Basic Info Fields (3 columns format)
    this.basicInfoFields = [
      { label: "Name", name: "name", value: "" },
      { label: "Department", name: "dept", value: "" },
      { label: "Designation", name: "desig", value: "" },
      { label: "Emp ID", name: "eid", value: "DGT-009" },
      { label: "Date of Join", name: "doj", value: "" },
      { label: "RO Name", name: "roName", value: "" }
    ];

    // 2. Professional Excellence (KRA/KPI)
    this.profExcellenceRows = [
      {
        id: 1,
        kra: "Production",
        kpi: "Quality",
        weight: 30,
        isParent: true,
        rowSpan: 2
      },
      {
        id: 2,
        kra: "Production",
        kpi: "TAT (turn around time)",
        weight: 30,
        isParent: false
      },
      {
        id: 3,
        kra: "Process Improvement",
        kpi: "PMS, New Ideas",
        weight: 10,
        isParent: true
      }
    ];

    // 3. Personal Excellence
    this.personalExcellenceRows = [
      {
        id: 1,
        attr: "Attendance",
        indicator: "Planned/Unplanned Leaves",
        weight: 2,
        rowSpan: 2,
        isParent: true
      },
      {
        id: 2,
        attr: "Attendance",
        indicator: "Time Consciousness",
        weight: 2,
        isParent: false
      }
    ];

    // 4. Achievement Rows (Clean Structure)
    this.achievementRows = [
      { id: 1, self: "", ro: "", hod: "" },
      { id: 2, self: "", ro: "", hod: "" },
      { id: 3, self: "", ro: "", hod: "" }
    ];

    // 5. Signature Table
    this.signatureRows = [
      { role: "Employee", name: "", sig: "", date: "" },
      { role: "Reporting Officer", name: "", sig: "", date: "" },
      { role: "HOD", name: "", sig: "", date: "" },
      { role: "HRD", name: "", sig: "", date: "" }
    ];
  }

  // Dynamic Row Addition Logic
  handleAddRow(event) {
    const table = event.currentTarget.dataset.id;
    if (table === "achievements") {
      const newId = this.achievementRows.length + 1;
      this.achievementRows = [
        ...this.achievementRows,
        { id: newId, self: "", ro: "", hod: "" }
      ];
    }
  }
}