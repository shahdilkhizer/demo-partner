import { LightningElement, track, api } from "lwc";
import getAttendanceTrackerData from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceTrackerData";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoAttendanceCalendar extends LightningElement {
  @api targetEmployeeId;
  @track currentMonth;
  @track currentYear;
  @track calendarDays = [];
  @track isLoading = true;

  currentDate = new Date();
  employeeId;
  sessionToken;
  monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ];

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.currentMonth = this.currentDate.getMonth();
    this.currentYear = this.currentDate.getFullYear();
    this.loadCalendarData();
  }

  get monthLabel() {
    return `${this.monthNames[this.currentMonth]} ${this.currentYear}`;
  }

  handlePreviousMonth() {
    if (this.currentMonth === 0) {
      this.currentMonth = 11;
      this.currentYear -= 1;
    } else {
      this.currentMonth -= 1;
    }
    this.loadCalendarData();
  }

  handleNextMonth() {
    if (this.currentMonth === 11) {
      this.currentMonth = 0;
      this.currentYear += 1;
    } else {
      this.currentMonth += 1;
    }
    this.loadCalendarData();
  }

  loadCalendarData() {
    this.isLoading = true;
    const firstDay = new Date(this.currentYear, this.currentMonth, 1);
    const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0);

    // Adjust start date to include previous month's days to fill the first week row
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - startDate.getDay()); // Start from Sunday

    // Adjust end date to include next month's days to fill the last week row
    const endDate = new Date(lastDay);
    const daysToAdd = 6 - endDate.getDay();
    endDate.setDate(endDate.getDate() + daysToAdd);

    const startStr = `${startDate.getFullYear()}-${String(startDate.getMonth() + 1).padStart(2, "0")}-${String(startDate.getDate()).padStart(2, "0")}`;
    const endStr = `${endDate.getFullYear()}-${String(endDate.getMonth() + 1).padStart(2, "0")}-${String(endDate.getDate()).padStart(2, "0")}`;

    getAttendanceTrackerData({
      startDate: startStr,
      endDate: endStr,
      employeeId: this.targetEmployeeId || this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((data) => {
        this.processCalendarData(data);
      })
      .catch(() => {
        /* Error loading calendar data */
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  processCalendarData(data) {
    const days = [];
    // We need to iterate from the calculated start date (which might be in prev month)
    // But for simplicity in rendering, let's just iterate through the data returned
    // The data returned covers the full range we requested.

    data.forEach((dayData) => {
      const date = new Date(dayData.attendanceDate);
      const isCurrentMonth = date.getMonth() === this.currentMonth;
      const isToday = new Date().toDateString() === date.toDateString();

      days.push({
        ...dayData,
        dayNumber: date.getDate(),
        isCurrentMonth: isCurrentMonth,
        isToday: isToday,
        cssClass: `calendar-day ${isToday ? "today" : ""} ${!isCurrentMonth ? "muted" : ""}`,

        statusClass: `status-badge status-${dayData.status}`
      });
    });

    this.calendarDays = days;
  }
}