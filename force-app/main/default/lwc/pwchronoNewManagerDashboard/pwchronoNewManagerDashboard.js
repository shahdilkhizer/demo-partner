import { LightningElement } from "lwc";
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import Chart from "@salesforce/resourceUrl/chartjs";
import { getSession, SESSION_CHANGED_EVENT } from "c/pwchronoSession";

export default class PwchronoNewManagerDashboard extends LightningElement {
  userData;
  sessionChangedHandler;
  smarthrAssetsAvatar24 = smarthrAssets + "/assets/img/profiles/avatar-24.jpg";
  smarthrAssetsAvatar27 = smarthrAssets + "/assets/img/profiles/avatar-27.jpg";
  smarthrAssetsAvatar30 = smarthrAssets + "/assets/img/profiles/avatar-30.jpg";
  smarthrAssetsAvatar14 = smarthrAssets + "/assets/img/profiles/avatar-14.jpg";
  smarthrAssetsAvatar29 = smarthrAssets + "/assets/img/profiles/avatar-29.jpg";
  smarthrAssetsAvatar24_1 =
    smarthrAssets + "/assets/img/profiles/avatar-24.jpg";
  smarthrAssetsAvatar23 = smarthrAssets + "/assets/img/profiles/avatar-23.jpg";
  smarthrAssetsAvatar27_1 =
    smarthrAssets + "/assets/img/profiles/avatar-27.jpg";
  smarthrAssetsAvatar29_1 =
    smarthrAssets + "/assets/img/profiles/avatar-29.jpg";
  smarthrAssetsApple = smarthrAssets + "/assets/img/icons/apple.svg";
  smarthrAssetsPhp = smarthrAssets + "/assets/img/icons/php.svg";
  smarthrAssetsReact = smarthrAssets + "/assets/img/icons/react.svg";
  smarthrAssetsLaravel = smarthrAssets + "/assets/img/icons/laravel-icon.svg";
  smarthrAssetsUser09 = smarthrAssets + "/assets/img/users/user-09.jpg";
  smarthrAssetsUser32 = smarthrAssets + "/assets/img/users/user-32.jpg";
  smarthrAssetsUser32_1 = smarthrAssets + "/assets/img/users/user-32.jpg";
  smarthrAssetsUser34 = smarthrAssets + "/assets/img/users/user-34.jpg";
  smarthrAssetsUser32_2 = smarthrAssets + "/assets/img/users/user-32.jpg";
  smarthrAssetsUser09_1 = smarthrAssets + "/assets/img/users/user-09.jpg";
  smarthrAssetsUser01 = smarthrAssets + "/assets/img/users/user-01.jpg";
  smarthrAssetsUser34_1 = smarthrAssets + "/assets/img/users/user-34.jpg";
  smarthrAssetsUser37 = smarthrAssets + "/assets/img/users/user-37.jpg";
  smarthrAssetsUser39 = smarthrAssets + "/assets/img/users/user-39.jpg";
  smarthrAssetsUser40 = smarthrAssets + "/assets/img/users/user-40.jpg";
  smarthrAssetsUser55 = smarthrAssets + "/assets/img/users/user-55.jpg";
  smarthrAssetsUser42 = smarthrAssets + "/assets/img/users/user-42.jpg";
  smarthrAssetsUser44 = smarthrAssets + "/assets/img/users/user-44.jpg";
  smarthrAssetsAvatar02 = smarthrAssets + "/assets/img/profiles/avatar-02.jpg";
  smarthrAssetsAvatar03 = smarthrAssets + "/assets/img/profiles/avatar-03.jpg";
  smarthrAssetsAvatar05 = smarthrAssets + "/assets/img/profiles/avatar-05.jpg";
  smarthrAssetsAvatar06 = smarthrAssets + "/assets/img/profiles/avatar-06.jpg";
  smarthrAssetsAvatar07 = smarthrAssets + "/assets/img/profiles/avatar-07.jpg";
  smarthrAssetsAvatar08 = smarthrAssets + "/assets/img/profiles/avatar-08.jpg";
  smarthrAssetsAvatar06_1 =
    smarthrAssets + "/assets/img/profiles/avatar-06.jpg";
  smarthrAssetsAvatar08_1 =
    smarthrAssets + "/assets/img/profiles/avatar-08.jpg";
  smarthrAssetsAvatar09_2 =
    smarthrAssets + "/assets/img/profiles/avatar-09.jpg";
  smarthrAssetsAvatar11 = smarthrAssets + "/assets/img/profiles/avatar-11.jpg";
  smarthrAssetsAvatar12 = smarthrAssets + "/assets/img/profiles/avatar-12.jpg";
  smarthrAssetsAvatar13 = smarthrAssets + "/assets/img/profiles/avatar-13.jpg";
  smarthrAssetsAvatar17 = smarthrAssets + "/assets/img/profiles/avatar-17.jpg";
  smarthrAssetsAvatar18 = smarthrAssets + "/assets/img/profiles/avatar-18.jpg";
  smarthrAssetsAvatar19 = smarthrAssets + "/assets/img/profiles/avatar-19.jpg";
  smarthrAssetsAvatar06_2 =
    smarthrAssets + "/assets/img/profiles/avatar-06.jpg";
  smarthrAssetsAvatar08_2 =
    smarthrAssets + "/assets/img/profiles/avatar-08.jpg";
  smarthrAssetsAvatar09_3 =
    smarthrAssets + "/assets/img/profiles/avatar-09.jpg";
  smarthrAssetsAvatar15 = smarthrAssets + "/assets/img/profiles/avatar-15.jpg";
  smarthrAssetsAvatar16 = smarthrAssets + "/assets/img/profiles/avatar-16.jpg";
  smarthrAssetsAvatar17_1 =
    smarthrAssets + "/assets/img/profiles/avatar-17.jpg";
  smarthrAssetsUser49 = smarthrAssets + "/assets/img/users/user-49.jpg";
  smarthrAssetsUser13_1 = smarthrAssets + "/assets/img/users/user-13.jpg";
  smarthrAssetsUser11_1 = smarthrAssets + "/assets/img/users/user-11.jpg";
  smarthrAssetsUser22 = smarthrAssets + "/assets/img/users/user-22.jpg";
  smarthrAssetsUser58 = smarthrAssets + "/assets/img/users/user-58.jpg";
  smarthrAssetsUser49_1 = smarthrAssets + "/assets/img/users/user-49.jpg";
  smarthrAssetsUser13_2 = smarthrAssets + "/assets/img/users/user-13.jpg";
  smarthrAssetsUser11_2 = smarthrAssets + "/assets/img/users/user-11.jpg";
  smarthrAssetsUser22_1 = smarthrAssets + "/assets/img/users/user-22.jpg";
  smarthrAssetsUser58_1 = smarthrAssets + "/assets/img/users/user-58.jpg";
  smarthrAssetsUser38 = smarthrAssets + "/assets/img/users/user-38.jpg";
  smarthrAssetsUser01_1 = smarthrAssets + "/assets/img/users/user-01.jpg";
  smarthrAssetsUser19_1 = smarthrAssets + "/assets/img/users/user-19.jpg";
  smarthrAssetsUser11_3 = smarthrAssets + "/assets/img/users/user-11.jpg";
  smarthrAssetsUser20 = smarthrAssets + "/assets/img/users/user-20.jpg";
  smarthrAssetsUser08_3 = smarthrAssets + "/assets/img/users/user-08.jpg";
  smarthrAssetsUser38_1 = smarthrAssets + "/assets/img/users/user-38.jpg";
  smarthrAssetsUser10 = smarthrAssets + "/assets/img/users/user-10.jpg";
  smarthrAssetsUser09_4 = smarthrAssets + "/assets/img/users/user-09.jpg";
  smarthrAssetsUser12_1 = smarthrAssets + "/assets/img/users/user-12.jpg";

  chartInitialized = false;
  charts = [];

  connectedCallback() {
    this.refreshUserFromSession();
    this.sessionChangedHandler = () => this.refreshUserFromSession();
    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this.sessionChangedHandler
      );
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  refreshUserFromSession() {
    this.userData = getSession()?.user || null;
  }

  get currentUserName() {
    return this.userData?.Name || "Manager";
  }

  get currentUserAvatarUrl() {
    return this.userData?.Photo_Url__c || null;
  }

  renderedCallback() {
    if (this.chartInitialized) {
      return;
    }
    this.chartInitialized = true;

    Promise.all([
      loadScript(this, Chart),
      loadStyle(this, smarthrAssets + "/assets/css/style.css"),
      loadStyle(
        this,
        smarthrAssets +
          "/assets/plugins/bootstrap-tagsinput/bootstrap-tagsinput.css"
      ),
      loadStyle(
        this,
        smarthrAssets + "/assets/plugins/tabler-icons/tabler-icons.min.css"
      ),
      loadStyle(
        this,
        smarthrAssets + "/assets/plugins/select2/css/select2.min.css"
      ),
      loadStyle(
        this,
        smarthrAssets + "/assets/plugins/flatpickr/flatpickr.min.css"
      ),
      loadStyle(
        this,
        smarthrAssets + "/assets/plugins/daterangepicker/daterangepicker.css"
      ),
      loadStyle(
        this,
        smarthrAssets + "/assets/plugins/fontawesome/css/all.min.css"
      ),
      loadStyle(
        this,
        smarthrAssets + "/assets/plugins/icons/feather/feather.css"
      )
    ])
      .then(() => {
        this.initializeCharts();
      })
      .catch(() => {
        this.chartInitialized = false;
      });
  }

  initializeCharts() {
    this.initializeEmpDepartmentChart();
    this.initializeAttendanceChart();
    this.initializeSalesIncomeChart();
    this.initializeMySemiDonutChart();
  }

  initializeEmpDepartmentChart() {
    const ctx = this.template
      .querySelector("canvas.emp-department")
      .getContext("2d");
    const chart = new window.Chart(ctx, {
      type: "bar",
      data: {
        labels: [
          "UI/UX",
          "Development",
          "Management",
          "HR",
          "Testing",
          "Marketing"
        ],
        datasets: [
          {
            label: "Employee",
            data: [80, 110, 80, 20, 60, 100],
            backgroundColor: "rgba(255, 111, 40, 0.85)",
            borderColor: "#ff6f28",
            borderWidth: 0,
            borderRadius: 5
          }
        ]
      },
      options: {
        indexAxis: "y",
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    });
    this.charts.push(chart);
  }

  initializeAttendanceChart() {
    const ctx = this.template
      .querySelector("canvas.attendance")
      .getContext("2d");
    const chart = new window.Chart(ctx, {
      type: "doughnut",
      data: {
        labels: ["Present", "Late", "Permission", "Absent"],
        datasets: [
          {
            data: [59, 21, 2, 15],
            backgroundColor: ["#28a745", "#ffc107", "#ffc107", "#dc3545"]
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "70%",
        plugins: {
          legend: {
            display: false
          }
        }
      }
    });
    this.charts.push(chart);
  }

  initializeSalesIncomeChart() {
    const ctx = this.template
      .querySelector("canvas.sales-income")
      .getContext("2d");
    const chart = new window.Chart(ctx, {
      type: "bar",
      data: {
        labels: [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec"
        ],
        datasets: [
          {
            label: "Income",
            data: [40, 30, 45, 80, 85, 90, 80, 80, 85, 20, 80, 20],
            backgroundColor: "rgba(255, 111, 40, 1)",
            borderColor: "#ff6f28",
            borderWidth: 1,
            borderRadius: 5
          },
          {
            label: "Expenses",
            data: [60, 70, 55, 20, 15, 10, 20, 20, 15, 80, 20, 80],
            backgroundColor: "rgba(248, 249, 250, 1)",
            borderColor: "#f8f9fa",
            borderWidth: 1,
            borderRadius: 5
          }
        ]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    });
    this.charts.push(chart);
  }

  initializeMySemiDonutChart() {
    const ctx = this.template
      .querySelector("canvas.mySemiDonutChart")
      .getContext("2d");
    const chart = new window.Chart(ctx, {
      type: "doughnut",
      data: {
        labels: ["Ongoing", "On Hold", "Overdue", "Completed"],
        datasets: [
          {
            data: [24, 10, 16, 40],
            backgroundColor: ["#ffc107", "#17a2b8", "#dc3545", "#28a745"]
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "70%",
        plugins: {
          legend: {
            display: false
          }
        }
      }
    });
    this.charts.push(chart);
  }
}