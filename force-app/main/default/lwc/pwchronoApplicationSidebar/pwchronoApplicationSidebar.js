import { getSession } from "c/pwchronoSession";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import { api, LightningElement, track } from "lwc";

const NAV_ITEMS = [
  ["dashboard", "Dashboard", "fa-solid fa-house fa-fw", "Dashboard"],
  ["profile", "My Profile", "fa-solid fa-address-card fa-fw", "My Profile"],
  [
    "attendance",
    "Attendance",
    "fa-solid fa-user-clock fa-fw",
    "Attendance Management"
  ],
  [
    "leave",
    "Leave Management",
    "fa-solid fa-calendar-minus fa-fw",
    "Leave Management"
  ],
  ["holidays", "Holidays", "fa-solid fa-plane-departure fa-fw", "Holidays"],
  [
    "directory",
    "Employee Directory",
    "fa-solid fa-address-book fa-fw",
    "Employee Directory"
  ],
  ["recruitment", "Recruitment", "fa-solid fa-user-plus fa-fw", "Recruitment"],
  [
    "onboarding",
    "Onboarding",
    "fa-solid fa-person-circle-check fa-fw",
    "Onboarding"
  ],
  [
    "performance",
    "Performance",
    "fa-solid fa-chart-simple fa-fw",
    "Performance Management"
  ],
  ["goals", "Goals", "fa-solid fa-crosshairs fa-fw", "Goals"],
  [
    "training",
    "Training",
    "fa-solid fa-chalkboard-user fa-fw",
    "Training Management"
  ],
  ["projects", "Projects", "fa-solid fa-folder-tree fa-fw", "Projects"],
  ["expenses", "Expenses", "fa-solid fa-wallet fa-fw", "Expense Management"],
  ["payroll", "Payroll", "fa-solid fa-file-invoice-dollar fa-fw", "Payroll"],
  ["approvals", "Approvals", "fa-solid fa-circle-check fa-fw", "Approvals"],
  [
    "policies",
    "Company Policies",
    "fa-solid fa-file-shield fa-fw",
    "Company Policies"
  ],
  ["reports", "Reports", "fa-solid fa-chart-column fa-fw", "Reports Dashboard"],
  [
    "configuration",
    "Configuration",
    "fa-solid fa-sliders fa-fw",
    "Configuration"
  ]
];

export default class PwchronoApplicationSidebar extends LightningElement {
  static renderMode = "light";

  @api currentRoute = "dashboard";
  @api features = [];
  @track logoErrored = false;

  get logoUrl() {
    return `${smarthrAssets}/assets/img/logo.svg`;
  }

  get items() {
    const featureSet = new Set(this.features || []);
    return NAV_ITEMS.filter(
      ([route, , , feature]) =>
        featureSet.has(feature) &&
        (route !== "projects" ||
          ["HR Admin", "System Administrator", "System Admin"].includes(
            getSession()?.user?.Role__c || getSession()?.user?.role
          ))
    ).map(([route, label, iconClass]) => ({
      route,
      label,
      iconClass,
      href: `#${route}`,
      linkClass: route === this.currentRoute ? "active" : ""
    }));
  }

  handleLogoError() {
    this.logoErrored = true;
  }

  handleNavigate(event) {
    const route = event.currentTarget.dataset.route;
    if (!route) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("routechange", {
        detail: { route },
        bubbles: true,
        composed: true
      })
    );
  }
}