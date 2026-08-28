import { LightningElement } from "lwc";

export default class PwchronoDashboardEmployeesTable extends LightningElement {
  employees = [
    {
      id: 1,
      name: "Anthony Lewis",
      role: "UI/UX Designer",
      department: "UI/UX Design",
      badgeClass: "badge badge-pink-transparent badge-xs",
      avatarUrl: ""
    },
    {
      id: 2,
      name: "Brian Villalobos",
      role: "Developer",
      department: "Development",
      badgeClass: "badge badge-purple-transparent badge-xs",
      avatarUrl: ""
    },
    {
      id: 3,
      name: "Harvey Smith",
      role: "QA Tester",
      department: "Testing",
      badgeClass: "badge badge-info-transparent badge-xs",
      avatarUrl: ""
    },
    {
      id: 4,
      name: "Stephan Peralt",
      role: "Team Lead",
      department: "Management",
      badgeClass: "badge badge-success-transparent badge-xs",
      avatarUrl: ""
    },
    {
      id: 5,
      name: "Doglas Martini",
      role: "Product Manager",
      department: "Product",
      badgeClass: "badge badge-warning-transparent badge-xs",
      avatarUrl: ""
    }
  ];
}