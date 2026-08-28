import chartjs from "@salesforce/resourceUrl/chartjs";
import { loadScript } from "lightning/platformResourceLoader";
import { LightningElement, api, track } from "lwc";

export default class PwchronoDashboardAttendanceSection extends LightningElement {
  @api attendanceOverview;
  @api projects;
  @api taskStatistics;
  @track chart;
  chartjsLoaded = false;
  lastAttendanceSignature;
  chartInitialized = false;

  /**
   * Clean up Chart.js instance to prevent memory leaks
   */
  disconnectedCallback() {
    this.destroyChart();
  }

  destroyChart() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
    this.chartInitialized = false;
  }

  renderedCallback() {
    if (!this.chartjsLoaded) {
      this.chartjsLoaded = true;
      loadScript(this, chartjs)
        .then(() => {
          this.tryCreateAttendanceChart();
        })
        .catch(() => {
          /* Chart.js load failed */
        });
      return;
    }
    this.tryCreateAttendanceChart();
  }

  tryCreateAttendanceChart() {
    if (!globalThis.Chart) return;
    if (!this.attendanceOverview) return;

    const total =
      this.attendanceOverview.present +
      this.attendanceOverview.late +
      this.attendanceOverview.permission +
      this.attendanceOverview.absent;
    if (total === 0) return;

    const signature = `${this.attendanceOverview.present}:${this.attendanceOverview.late}:${this.attendanceOverview.permission}:${this.attendanceOverview.absent}`;
    if (this.chartInitialized && signature === this.lastAttendanceSignature)
      return;

    this.lastAttendanceSignature = signature;
    this.createAttendanceChart();
  }

  createAttendanceChart() {
    const canvas = this.template.querySelector('[data-chart="attendance"]');
    if (!canvas || !this.attendanceOverview) return;

    const total =
      this.attendanceOverview.present +
      this.attendanceOverview.late +
      this.attendanceOverview.permission +
      this.attendanceOverview.absent;
    if (total === 0) return;

    // Destroy existing chart properly before creating new one
    this.destroyChart();

    // Get existing chart instance on this canvas and destroy it
    const existingChart = globalThis.Chart.getChart(canvas);
    if (existingChart) {
      existingChart.destroy();
    }

    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    // Colors matching the reference design:
    // Present = Dark teal/navy, Late = Green, Permission = Yellow/Orange, Absent = Red
    const segments = [
      {
        label: "Present",
        value: this.attendanceOverview.present,
        color: "#0f766e"
      }, // Teal-700
      { label: "Late", value: this.attendanceOverview.late, color: "#22c55e" }, // Green-500
      {
        label: "Permission",
        value: this.attendanceOverview.permission,
        color: "#f59e0b"
      }, // Amber-500
      {
        label: "Absent",
        value: this.attendanceOverview.absent,
        color: "#ef4444"
      } // Red-500
    ];

    this.chart = new globalThis.Chart(ctx, {
      type: "doughnut",
      data: {
        labels: segments.map((s) => s.label),
        datasets: [
          {
            data: segments.map((s) => s.value),
            backgroundColor: segments.map((s) => s.color),
            borderWidth: 0
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        rotation: -90,
        circumference: 180,
        cutout: "70%",
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (context) => `${context.label}: ${context.parsed}`
            }
          }
        }
      }
    });
    this.chartInitialized = true;
  }

  get attendanceDateLabel() {
    return this.attendanceOverview?.day || "Today";
  }

  get totalAttendance() {
    if (!this.attendanceOverview) return 0;
    return (
      this.attendanceOverview.present +
      this.attendanceOverview.late +
      this.attendanceOverview.permission +
      this.attendanceOverview.absent
    );
  }

  get absentCount() {
    return this.attendanceOverview?.absent || 0;
  }

  get hasAbsentees() {
    return this.absentCount > 0;
  }

  get absenteeAvatars() {
    // Stacked avatars matching Temp.html classes.
    const avatarStyles = [
      {
        initials: "JD",
        cls: "avatar bg-danger avatar-rounded text-fixed-white fs-10"
      },
      {
        initials: "SM",
        cls: "avatar bg-secondary avatar-rounded text-fixed-white fs-10"
      },
      {
        initials: "AK",
        cls: "avatar bg-primary avatar-rounded text-fixed-white fs-10"
      },
      {
        initials: "RB",
        cls: "avatar bg-warning avatar-rounded text-fixed-white fs-10"
      }
    ];
    const displayCount = Math.min(this.absentCount, 4);
    const avatars = [];
    for (let i = 0; i < displayCount; i++) {
      const style = avatarStyles[i];
      avatars.push({
        key: `absentee-${i}`,
        initials: style.initials,
        name: `Employee ${i + 1}`,
        className: style.cls
      });
    }
    return avatars;
  }

  get hasMoreAbsentees() {
    return this.absentCount > 4;
  }

  get moreAbsenteesCount() {
    return this.absentCount - 4;
  }

  get attendanceStatusRows() {
    if (!this.attendanceOverview) return [];
    const total =
      this.attendanceOverview.present +
      this.attendanceOverview.late +
      this.attendanceOverview.permission +
      this.attendanceOverview.absent;
    if (total === 0) return [];

    return [
      {
        key: "present",
        label: "Present",
        value: this.attendanceOverview.present,
        percentLabel: `${Math.round((this.attendanceOverview.present / total) * 100)}%`,
        iconClass: "fa-solid fa-circle text-success me-1"
      },
      {
        key: "late",
        label: "Late",
        value: this.attendanceOverview.late,
        percentLabel: `${Math.round((this.attendanceOverview.late / total) * 100)}%`,
        iconClass: "fa-solid fa-circle text-secondary me-1"
      },
      {
        key: "permission",
        label: "Permission",
        value: this.attendanceOverview.permission,
        percentLabel: `${Math.round((this.attendanceOverview.permission / total) * 100)}%`,
        iconClass: "fa-solid fa-circle text-warning me-1"
      },
      {
        key: "absent",
        label: "Absent",
        value: this.attendanceOverview.absent,
        percentLabel: `${Math.round((this.attendanceOverview.absent / total) * 100)}%`,
        iconClass: "fa-solid fa-circle text-danger me-1"
      }
    ];
  }

  handleViewDetails() {
    this.dispatchEvent(new CustomEvent("viewattendancedetails"));
  }
}