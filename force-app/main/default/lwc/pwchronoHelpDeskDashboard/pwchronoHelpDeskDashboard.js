import { LightningElement } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";

import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import chartjs from "@salesforce/resourceUrl/chartjs";
import getDashboardSummary from "@salesforce/apex/PWChrono_HelpDeskDashboardController.getDashboardSummary";
import {
  initBootstrapCompat,
  teardownBootstrapCompat
} from "c/pwchronoBootstrapCompat";

export default class PwchronoHelpDeskDashboard extends LightningElement {
  assetsBase = smarthrAssets;

  _chartJsLoaded = false;
  _charts = [];
  summary;
  _summaryLoaded = false;
  _loading = false;

  get avatar01() {
    return `${this.assetsBase}/assets/img/avatar/avatar-01.png`;
  }
  get avatar02() {
    return `${this.assetsBase}/assets/img/avatar/avatar-02.png`;
  }
  get avatar03() {
    return `${this.assetsBase}/assets/img/avatar/avatar-03.jpg`;
  }
  get avatar04() {
    return `${this.assetsBase}/assets/img/avatar/avatar-04.png`;
  }

  connectedCallback() {
    this.loadSummary();
  }

  async loadSummary() {
    if (this._loading) return;
    this._loading = true;
    try {
      this.summary = await getDashboardSummary();
      this._summaryLoaded = true;
      if (this._chartJsLoaded) {
        this.initCharts();
      }
    } catch {
      // keep UI functional even if Apex fails
      this.summary = undefined;
      this._summaryLoaded = false;
    } finally {
      this._loading = false;
    }
  }

  get totalTickets() {
    return this.summary?.totalTickets ?? 0;
  }

  get openTickets() {
    return this.summary?.openTickets ?? 0;
  }

  get resolvedToday() {
    return this.summary?.resolvedToday ?? 0;
  }

  get overdueTickets() {
    return this.summary?.overdueTickets ?? 0;
  }

  get avgTimeDisplay() {
    const h = Number(this.summary?.avgResolutionHours ?? 0);
    if (!Number.isFinite(h)) return "0h";
    return `${h.toFixed(1)}h`;
  }

  get activeAgents() {
    return this.summary?.activeAgents ?? 0;
  }

  get statusOpen() {
    return this.summary?.statusCounts?.open ?? 0;
  }
  get statusInProgress() {
    return this.summary?.statusCounts?.inProgress ?? 0;
  }
  get statusOnHold() {
    return this.summary?.statusCounts?.onHold ?? 0;
  }
  get statusClosed() {
    return this.summary?.statusCounts?.closed ?? 0;
  }

  get statusTotal() {
    return (
      this.statusOpen +
      this.statusInProgress +
      this.statusOnHold +
      this.statusClosed
    );
  }

  renderedCallback() {
    initBootstrapCompat(this);

    if (this._chartJsLoaded) return;
    this._chartJsLoaded = true;

    loadScript(this, chartjs)
      .then(() => {
        this.initCharts();
      })
      .catch(() => {
        // Ignore error
      });
  }

  disconnectedCallback() {
    this.destroyCharts();
    teardownBootstrapCompat(this);
  }

  destroyCharts() {
    try {
      this._charts.forEach((c) => c && c.destroy && c.destroy());
    } catch {
      // ignore
    }
    this._charts = [];
  }

  initCharts() {
    const Chart = globalThis?.Chart;
    if (!Chart) return;

    this.destroyCharts();

    const ticketTrendsCanvas = this.template.querySelector(
      "canvas#ticket-trends-chart"
    );
    const ticketStatusCanvas = this.template.querySelector(
      "canvas#ticket-status-chart"
    );
    const slaCanvas = this.template.querySelector(
      "canvas#sla-compliance-chart"
    );
    const backlogCanvas = this.template.querySelector(
      "canvas#backlog-growth-chart"
    );
    const categoryCanvas = this.template.querySelector(
      "canvas#ticket-category"
    );

    // Global defaults (keep minimal so SmartHR styling stays dominant)
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = false;
    Chart.defaults.plugins.legend.display = false;

    // Ticket Trends (line)
    if (ticketTrendsCanvas) {
      ticketTrendsCanvas.parentElement.style.height = "240px";

      const labels = this.summary?.trendLabels || [
        "Mon",
        "Tue",
        "Wed",
        "Thu",
        "Fri",
        "Sat",
        "Sun"
      ];
      const created = this.summary?.createdTrend || [
        140, 155, 190, 150, 160, 175, 180
      ];
      const resolved = this.summary?.resolvedTrend || [
        40, 65, 105, 70, 85, 75, 90
      ];

      const c = new Chart(ticketTrendsCanvas.getContext("2d"), {
        type: "line",
        data: {
          labels,
          datasets: [
            {
              label: "Created",
              data: created,
              tension: 0.35,
              pointRadius: 2,
              borderWidth: 2
            },
            {
              label: "Resolved",
              data: resolved,
              tension: 0.35,
              pointRadius: 2,
              borderWidth: 2
            }
          ]
        },
        options: {
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { display: false } },
            y: { beginAtZero: true }
          }
        }
      });

      this._charts.push(c);
    }

    // Tickets by Status (doughnut)
    if (ticketStatusCanvas) {
      ticketStatusCanvas.parentElement.style.height = "230px";

      const statusData = [
        this.statusOpen,
        this.statusInProgress,
        this.statusOnHold,
        this.statusClosed
      ];

      const c = new Chart(ticketStatusCanvas.getContext("2d"), {
        type: "doughnut",
        data: {
          labels: ["Open", "In Progress", "On Hold", "Closed"],
          datasets: [
            {
              data: statusData,
              borderWidth: 0,
              cutout: "70%"
            }
          ]
        },
        options: {
          plugins: { legend: { display: false } }
        }
      });

      this._charts.push(c);
    }

    // SLA Compliance (semi-doughnut gauge)
    if (slaCanvas) {
      slaCanvas.parentElement.style.height = "200px";

      const open = Number(this.openTickets || 0);
      const overdue = Number(this.overdueTickets || 0);
      const slaValue =
        open > 0
          ? Math.max(0, Math.min(100, ((open - overdue) / open) * 100))
          : 100;
      const c = new Chart(slaCanvas.getContext("2d"), {
        type: "doughnut",
        data: {
          labels: ["SLA", "Remaining"],
          datasets: [
            {
              data: [slaValue, 100 - slaValue],
              borderWidth: 0,
              cutout: "78%"
            }
          ]
        },
        options: {
          rotation: -90,
          circumference: 180,
          plugins: { legend: { display: false } }
        }
      });

      this._charts.push(c);
    }

    // Backlog Growth (bar)
    if (backlogCanvas) {
      backlogCanvas.parentElement.style.height = "200px";

      const labels = this.summary?.trendLabels || [
        "Mon",
        "Tue",
        "Wed",
        "Thu",
        "Fri",
        "Sat",
        "Sun"
      ];
      const created = this.summary?.createdTrend || [
        120, 300, 340, 410, 460, 520, 560
      ];
      const resolved = this.summary?.resolvedTrend || [0, 0, 0, 0, 0, 0, 0];
      const backlog = [];
      let running = 0;
      for (let i = 0; i < labels.length; i++) {
        running += Number(created[i] || 0) - Number(resolved[i] || 0);
        backlog.push(Math.max(0, running));
      }

      const c = new Chart(backlogCanvas.getContext("2d"), {
        type: "bar",
        data: {
          labels,
          datasets: [
            {
              label: "Backlog",
              data: backlog,
              borderWidth: 0,
              borderRadius: 8
            }
          ]
        },
        options: {
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { display: false } },
            y: { beginAtZero: true }
          }
        }
      });

      this._charts.push(c);
    }

    // Tickets by Category (semi-doughnut)
    if (categoryCanvas) {
      categoryCanvas.parentElement.style.height = "200px";

      const cc = this.summary?.categoryCounts;
      const categoryData = cc
        ? [
            cc.itSupport ?? 0,
            cc.hr ?? 0,
            cc.payroll ?? 0,
            cc.access ?? 0,
            cc.hardware ?? 0,
            cc.other ?? 0
          ]
        : [485, 342, 268, 195, 412, 145];

      const c = new Chart(categoryCanvas.getContext("2d"), {
        type: "doughnut",
        data: {
          labels: [
            "IT Support",
            "HR",
            "Payroll",
            "Access",
            "Hardware",
            "Other"
          ],
          datasets: [
            {
              data: categoryData,
              borderWidth: 0,
              cutout: "75%"
            }
          ]
        },
        options: {
          rotation: -90,
          circumference: 180,
          plugins: { legend: { display: false } }
        }
      });

      this._charts.push(c);
    }
  }
}