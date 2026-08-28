import { LightningElement, api } from "lwc";

export default class PwchronoEmployeeStatusCard extends LightningElement {
  @api employeeStatus = {
    total: 154,
    fulltime: 112,
    contract: 112,
    probation: 12,
    wfh: 4
  };

  @api topPerformer = {
    name: "Daniel Esbella",
    role: "iOS Developer",
    score: 99,
    initials: "DE"
  };

  get totalEmployees() {
    return this.employeeStatus?.total || 0;
  }

  get fulltimeCount() {
    return this.employeeStatus?.fulltime || 0;
  }

  get contractCount() {
    return this.employeeStatus?.contract || 0;
  }

  get probationCount() {
    return this.employeeStatus?.probation || 0;
  }

  get wfhCount() {
    return this.employeeStatus?.wfh || 0;
  }

  get fulltimePercent() {
    const total = this.totalEmployees || 1;
    return Math.round((this.fulltimeCount / total) * 100);
  }

  get contractPercent() {
    const total = this.totalEmployees || 1;
    return Math.round((this.contractCount / total) * 100);
  }

  get probationPercent() {
    const total = this.totalEmployees || 1;
    return Math.round((this.probationCount / total) * 100);
  }

  get wfhPercent() {
    const total = this.totalEmployees || 1;
    return Math.round((this.wfhCount / total) * 100);
  }

  renderedCallback() {
    this.setBarStyle(".bar-fulltime", this.fulltimePercent);
    this.setBarStyle(".bar-contract", this.contractPercent);
    this.setBarStyle(".bar-probation", this.probationPercent);
    this.setBarStyle(".bar-wfh", this.wfhPercent);
  }

  setBarStyle(selector, percent) {
    const el = this.template.querySelector(selector);
    if (el) {
      el.style.width = `${percent}%`;
      el.style.setProperty("--tw-content", "''");
    }
  }

  get topPerformerName() {
    return this.topPerformer?.name || "N/A";
  }

  get topPerformerRole() {
    return this.topPerformer?.role || "";
  }

  get topPerformerScore() {
    return this.topPerformer?.score || 0;
  }

  get topPerformerInitials() {
    if (this.topPerformer?.initials) {
      return this.topPerformer.initials;
    }
    const name = this.topPerformerName;
    if (!name || name === "N/A") return "?";
    const parts = name.split(" ");
    return parts
      .map((p) => p.charAt(0).toUpperCase())
      .join("")
      .substring(0, 2);
  }

  handleViewAllEmployees() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "employees" },
        bubbles: true,
        composed: true
      })
    );
  }
}