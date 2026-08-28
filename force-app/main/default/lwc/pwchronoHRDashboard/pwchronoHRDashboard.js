import { LightningElement } from "lwc";
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import getDashboardSummary from "@salesforce/apex/PWChrono_HRDashboardController.getDashboardSummary";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";

// Your ZIP static resource name
import SMARTHR_ASSETS from "@salesforce/resourceUrl/smarthr_assets";

// Create a separate static resource for chartjs.js (example name: chartjs)
import CHARTJS from "@salesforce/resourceUrl/chartjs";

export default class PwchronoHRDashboard extends LightningElement {
  _assetsLoaded = false;
  _chartsInitialized = false;
  _chartStore = {};
  summary;
  _loading = false;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();
  _sessionChangedHandler;

  connectedCallback() {
    this._sessionChangedHandler = () => {
      this.employeeId = getEmployeeId();
      this.sessionToken = getSessionToken();
      this.loadSummary();
    };
    try {
      window.addEventListener(SESSION_CHANGED_EVENT, this._sessionChangedHandler);
    } catch (e) {
      // ignore
    }
    this.loadSummary();
  }

  async loadSummary() {
    if (this._loading) return;
    this._loading = true;
    try {
      this.summary = await getDashboardSummary({
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (this._chartsInitialized) {
        this.initCharts();
      }
    } catch {
      this.summary = undefined;
    } finally {
      this._loading = false;
    }
  }

  money(value) {
    const n = Number(value ?? 0);
    const safe = Number.isFinite(n) ? n : 0;
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 0
    }).format(safe);
  }

  get fullTimeEmployees() {
    return this.summary?.fullTimeEmployees ?? 1054;
  }

  get contractEmployees() {
    return this.summary?.contractEmployees ?? 568;
  }

  get probationEmployees() {
    return this.summary?.probationEmployees ?? 80;
  }

  get totalEmployees() {
    return this.summary?.totalEmployees ?? 1848;
  }

  get newJoiners() {
    return this.summary?.newJoiners ?? 1248;
  }

  get lateArrivalsToday() {
    return this.summary?.lateArrivalsToday ?? 12;
  }

  get totalPayrollCostFormatted() {
    return this.money(this.summary?.totalPayrollCost ?? 2400000);
  }

  get sickLeaveCount() {
    return this.summary?.sickLeaveCount ?? 45;
  }

  get casualLeaveCount() {
    return this.summary?.casualLeaveCount ?? 31;
  }

  get unpaidLeaveCount() {
    return this.summary?.unpaidLeaveCount ?? 12;
  }

  get onTimeTotal() {
    return (
      (this.summary?.onTimeTrend || []).reduce(
        (a, b) => a + Number(b || 0),
        0
      ) || 82
    );
  }

  get lateTotal() {
    return (
      (this.summary?.lateTrend || []).reduce((a, b) => a + Number(b || 0), 0) ||
      11
    );
  }

  get absentTotal() {
    return (
      (this.summary?.absentTrend || []).reduce(
        (a, b) => a + Number(b || 0),
        0
      ) || 6
    );
  }

  get trainingInProgress() {
    return this.summary?.trainingInProgress ?? 80;
  }

  get benefitDeductionsFormatted() {
    return this.money(this.summary?.benefitDeductions ?? 56000);
  }

  get recruitmentApplicants() {
    return this.summary?.recruitmentApplicants ?? 487;
  }

  get recruitmentHired() {
    return this.summary?.recruitmentHired ?? 24;
  }

  get recruitmentAvgTimeDays() {
    return this.summary?.recruitmentAvgTimeDays ?? 28;
  }

  get recruitmentApplicantsPercent() {
    return this.summary?.recruitmentApplicantsPercent ?? 55;
  }

  get recruitmentScreeningPercent() {
    return this.summary?.recruitmentScreeningPercent ?? 20;
  }

  get recruitmentHiredPercent() {
    return this.summary?.recruitmentHiredPercent ?? 25;
  }

  get recruitmentApplicantsEmployees() {
    return this.summary?.recruitmentApplicantsEmployees ?? 7;
  }

  get recruitmentScreeningEmployees() {
    return this.summary?.recruitmentScreeningEmployees ?? 36;
  }

  get recruitmentHiredEmployees() {
    return this.summary?.recruitmentHiredEmployees ?? 18;
  }

  get recruitmentApplicantsWidthStyle() {
    return `width: ${this.recruitmentApplicantsPercent}%`;
  }

  get recruitmentScreeningWidthStyle() {
    return `width: ${this.recruitmentScreeningPercent}%`;
  }

  get recruitmentHiredWidthStyle() {
    return `width: ${this.recruitmentHiredPercent}%`;
  }

  userAvatarPath(fileName) {
    return `${SMARTHR_ASSETS}/assets/img/users/${fileName}`;
  }

  get lateArrivalRows() {
    const rows = this.summary?.lateArrivals;
    if (Array.isArray(rows) && rows.length) {
      return rows.map((row, idx) => ({
        key: row.key || `late-${idx}`,
        employeeName: row.employeeName || "Employee",
        department: row.department || "Department",
        arrivalTime: row.arrivalTime || "--:--",
        lateBy: row.lateBy || "+0 Min",
        avatar: this.userAvatarPath(`user-0${(idx % 5) + 1}.jpg`)
      }));
    }

    return [
      {
        key: "late-1",
        employeeName: "Jessica Brown",
        department: "Customer Support",
        arrivalTime: "10:15 AM",
        lateBy: "+15 Min",
        avatar: this.userAvatarPath("user-01.jpg")
      },
      {
        key: "late-2",
        employeeName: "Amanda Lewis",
        department: "HR Admin",
        arrivalTime: "10:25 AM",
        lateBy: "+25 Min",
        avatar: this.userAvatarPath("user-02.jpg")
      },
      {
        key: "late-3",
        employeeName: "James Clark",
        department: "Sales",
        arrivalTime: "11:00 AM",
        lateBy: "+1 Hr",
        avatar: this.userAvatarPath("user-03.jpg")
      },
      {
        key: "late-4",
        employeeName: "Amanda Davis",
        department: "Administration",
        arrivalTime: "09:40 AM",
        lateBy: "+20 Min",
        avatar: this.userAvatarPath("user-04.jpg")
      },
      {
        key: "late-5",
        employeeName: "Lisa Anderson",
        department: "Finance",
        arrivalTime: "09:35 AM",
        lateBy: "+15 Min",
        avatar: this.userAvatarPath("user-05.jpg")
      }
    ];
  }

  get pendingApprovalRows() {
    const rows = this.summary?.pendingApprovals;
    if (Array.isArray(rows) && rows.length) {
      return rows.map((row, idx) => ({
        key: row.key || `pending-${idx}`,
        employeeName: row.employeeName || "Employee",
        dateAndDays: row.dateAndDays || "N/A",
        reason: row.reason || "N/A",
        avatar: this.userAvatarPath(`user-${16 + idx}.jpg`)
      }));
    }

    return [
      {
        key: "pending-1",
        employeeName: "Hendrik Markel",
        dateAndDays: "12 Jan 2024 • 4 days",
        reason: "Family Trip",
        avatar: this.userAvatarPath("user-16.jpg")
      },
      {
        key: "pending-2",
        employeeName: "Michael Brown",
        dateAndDays: "11 Jan 2024 • 2 days",
        reason: "Medical Appointment",
        avatar: this.userAvatarPath("user-17.jpg")
      },
      {
        key: "pending-3",
        employeeName: "Daniel Martinez",
        dateAndDays: "10 Jan 2024 • 2 days",
        reason: "Personal Work",
        avatar: this.userAvatarPath("user-18.jpg")
      }
    ];
  }

  get upcomingInterviewRows() {
    const rows = this.summary?.upcomingInterviews;
    if (Array.isArray(rows) && rows.length) {
      return rows.map((row, idx) => ({
        key: row.key || `interview-${idx}`,
        title: row.title || "Interview",
        timeRange: row.timeRange || "TBD"
      }));
    }

    return [
      {
        key: "interview-1",
        title: "UI/UX Design Interview",
        timeRange: "11:00 AM - 11:30 AM"
      },
      {
        key: "interview-2",
        title: "Senior Developer React",
        timeRange: "01:00 PM - 02:00 PM"
      }
    ];
  }

  get topEmployeeRows() {
    const rows = this.summary?.topEmployees;
    if (Array.isArray(rows) && rows.length) {
      return rows.map((row, idx) => ({
        key: row.key || `top-${idx}`,
        employeeName: row.employeeName || "Employee",
        avatar:
          row.photoUrl ||
          this.userAvatarPath(`user-${String(idx + 6).padStart(2, "0")}.jpg`)
      }));
    }

    return [
      {
        key: "top-1",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-06.jpg")
      },
      {
        key: "top-2",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-07.jpg")
      },
      {
        key: "top-3",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-08.jpg")
      },
      {
        key: "top-4",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-09.jpg")
      },
      {
        key: "top-5",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-10.jpg")
      },
      {
        key: "top-6",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-11.jpg")
      },
      {
        key: "top-7",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-12.jpg")
      },
      {
        key: "top-8",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-13.jpg")
      },
      {
        key: "top-9",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-14.jpg")
      },
      {
        key: "top-10",
        employeeName: "Employee",
        avatar: this.userAvatarPath("user-15.jpg")
      }
    ];
  }

  async renderedCallback() {
    if (this._assetsLoaded) {
      if (!this._chartsInitialized) {
        this._chartsInitialized = true;
        this.initCharts();
      }
      return;
    }

    this._assetsLoaded = true;

    try {
      // Core SmartHR CSS
      await Promise.all([
        loadStyle(this, `${SMARTHR_ASSETS}/assets/css/bootstrap.min.css`),
        loadStyle(
          this,
          `${SMARTHR_ASSETS}/assets/plugins/fontawesome/css/all.min.css`
        ),
        loadStyle(
          this,
          `${SMARTHR_ASSETS}/assets/plugins/icons/feather/feather.css`
        ),
        loadStyle(
          this,
          `${SMARTHR_ASSETS}/assets/plugins/tabler-icons/tabler-icons.min.css`
        ),
        loadStyle(this, `${SMARTHR_ASSETS}/assets/css/style.css`)
      ]);

      // Chart.js
      await loadScript(this, CHARTJS);

      // Init charts after libraries are ready
      this._chartsInitialized = true;
      this.initCharts();
    } catch {
      // Ignore error
    }
  }

  initCharts() {
    if (!window.Chart) return;

    this.destroyCharts();

    // Status chart (Employee Status & Type)
    this.createChart("statusChart", {
      type: "bar",
      data: {
        labels: ["Full-Time", "Contract", "Probation"],
        datasets: [
          {
            label: "Employees",
            data: [
              this.fullTimeEmployees,
              this.contractEmployees,
              this.probationEmployees
            ],
            borderWidth: 0
          }
        ]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false } },
          y: { beginAtZero: true }
        }
      }
    });

    // Leave type distribution
    this.createChart("leaveChart", {
      type: "doughnut",
      data: {
        labels: ["Sick Leave", "Casual Leave", "Unpaid"],
        datasets: [
          {
            data: [
              this.sickLeaveCount,
              this.casualLeaveCount,
              this.unpaidLeaveCount
            ],
            borderWidth: 0
          }
        ]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        cutout: "70%"
      }
    });

    // Attendance Trend
    this.createChart("attendanceChart", {
      type: "bar",
      data: {
        labels: this.summary?.attendanceLabels || [
          "Mon",
          "Tue",
          "Wed",
          "Thu",
          "Fri",
          "Sat",
          "Sun"
        ],
        datasets: [
          {
            label: "On-Time",
            data: this.summary?.onTimeTrend || [
              520, 320, 280, 640, 410, 600, 590
            ],
            borderWidth: 0
          },
          {
            label: "Late",
            data: this.summary?.lateTrend || [90, 70, 120, 80, 140, 110, 130],
            borderWidth: 0
          },
          {
            label: "Absent",
            data: this.summary?.absentTrend || [30, 25, 20, 35, 18, 22, 28],
            borderWidth: 0
          }
        ]
      },
      options: {
        responsive: true,
        plugins: { legend: { position: "top" } },
        scales: {
          x: { stacked: false, grid: { display: false } },
          y: { beginAtZero: true }
        }
      }
    });

    // Top Employee Distribution (Today/Week/Month/Year)
    const distConfig = (values) => ({
      type: "bar",
      data: {
        labels: this.summary?.distributionLabels || [
          "Sales",
          "Front End",
          "React",
          "UI"
        ],
        datasets: [{ label: "Distribution", data: values, borderWidth: 0 }]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false } },
          y: { beginAtZero: true, max: 100 }
        }
      }
    });

    this.createChart(
      "imageChart",
      distConfig(this.summary?.distributionToday || [40, 25, 36, 19])
    );
    this.createChart(
      "imageChartWeek",
      distConfig(this.summary?.distributionWeek || [38, 22, 31, 17])
    );
    this.createChart(
      "imageChartMonth",
      distConfig(this.summary?.distributionMonth || [42, 28, 34, 21])
    );
    this.createChart(
      "imageChartQuarter",
      distConfig(this.summary?.distributionQuarter || [41, 24, 33, 20])
    );
    this.createChart(
      "imageChartYear",
      distConfig(this.summary?.distributionYear || [45, 26, 33, 18])
    );

    // Training mini chart (donut)
    this.createChart("training-chart", {
      type: "doughnut",
      data: {
        labels: ["In Training", "Completed"],
        datasets: [
          {
            data: [
              this.summary?.trainingInProgress ?? 80,
              this.summary?.trainingCompleted ?? 120
            ],
            borderWidth: 0
          }
        ]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        cutout: "72%"
      }
    });

    // Benefit Deductions sparkline-style
    this.createChart("deductionChart", {
      type: "line",
      data: {
        labels: ["W1", "W2", "W3", "W4", "W5", "W6"],
        datasets: [
          {
            label: "Deductions",
            data: this.summary?.deductionSparkline || [8, 10, 9, 12, 11, 13],
            tension: 0.35,
            pointRadius: 0
          }
        ]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { x: { display: false }, y: { display: false } }
      }
    });

    // Total Payroll sparkline-style
    this.createChart("payrollChart", {
      type: "line",
      data: {
        labels: ["W1", "W2", "W3", "W4", "W5", "W6"],
        datasets: [
          {
            label: "Payroll",
            data: this.summary?.payrollSparkline || [
              2.1, 2.2, 2.18, 2.25, 2.32, 2.4
            ],
            tension: 0.35,
            pointRadius: 0
          }
        ]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { x: { display: false }, y: { display: false } }
      }
    });
  }

  disconnectedCallback() {
    try {
      window.removeEventListener(
        SESSION_CHANGED_EVENT,
        this._sessionChangedHandler
      );
    } catch (e) {
      // ignore
    }
    this._sessionChangedHandler = null;
    this.destroyCharts();
    this._chartsInitialized = false;
  }

  destroyCharts() {
    Object.keys(this._chartStore || {}).forEach((key) => {
      const chart = this._chartStore[key];
      if (chart && typeof chart.destroy === "function") {
        chart.destroy();
      }
    });
    this._chartStore = {};
  }

  createChart(canvasId, config) {
    const el = this.template.querySelector(`#${canvasId}`);
    if (!el) return;

    // Prevent duplicate chart instances on re-render
    if (this._chartStore[canvasId]) {
      this._chartStore[canvasId].destroy();
    }

    const ctx = el.getContext("2d");
    this._chartStore[canvasId] = new window.Chart(ctx, config);
  }
}