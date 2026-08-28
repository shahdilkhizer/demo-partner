import { LightningElement, track } from "lwc";
import getMyShiftAssignments from "@salesforce/apex/PWChrono_AttendanceController.getMyShiftAssignments";
import { showErrorToast, logError } from "c/pwchronoErrorHandler";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoShiftRosterView extends LightningElement {
  static renderMode = "light";
  @track currentWeekStart;
  @track weekDays = [];
  @track isLoading = true;

  connectedCallback() {
    this.setCurrentWeek();
    this.loadShifts();
  }

  get weekLabel() {
    if (!this.currentWeekStart) return "";
    const end = new Date(this.currentWeekStart);
    end.setDate(end.getDate() + 6);
    return `${this.formatDate(this.currentWeekStart)} - ${this.formatDate(end)}`;
  }

  get workingDaysCount() {
    return this.weekDays.filter((day) => day.shift).length;
  }

  get offDaysCount() {
    return this.weekDays.filter((day) => !day.shift).length;
  }

  formatDate(date) {
    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric"
    });
  }

  setCurrentWeek() {
    const today = new Date();
    const day = today.getDay(); // 0 is Sunday
    const start = new Date(today);
    start.setDate(today.getDate() - day); // Start on Sunday
    this.currentWeekStart = start;
    this.generateWeekDays();
  }

  generateWeekDays() {
    const days = [];
    const start = new Date(this.currentWeekStart);
    for (let i = 0; i < 7; i++) {
      const d = new Date(start);
      d.setDate(start.getDate() + i);
      days.push({
        date: d,
        dayName: d.toLocaleDateString("en-US", { weekday: "short" }),
        dateString: d.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric"
        }),
        isoDate: d.toISOString().split("T")[0],
        isToday: new Date().toDateString() === d.toDateString()
      });
    }
    this.weekDays = days;
  }

  handlePrevWeek() {
    const newStart = new Date(this.currentWeekStart);
    newStart.setDate(newStart.getDate() - 7);
    this.currentWeekStart = newStart;
    this.generateWeekDays();
    this.loadShifts();
  }

  handleNextWeek() {
    const newStart = new Date(this.currentWeekStart);
    newStart.setDate(newStart.getDate() + 7);
    this.currentWeekStart = newStart;
    this.generateWeekDays();
    this.loadShifts();
  }

  loadShifts() {
    this.isLoading = true;
    const endDate = new Date(this.currentWeekStart);
    endDate.setDate(endDate.getDate() + 6);

    getMyShiftAssignments({
      startDate: this.currentWeekStart.toISOString().split("T")[0],
      endDate: endDate.toISOString().split("T")[0],
      employeeId: getEmployeeId(),
      sessionToken: getSessionToken()
    })
      .then((data) => {
        this.processShifts(data);
      })
      .catch((error) => {
        logError("ShiftRosterView.loadShifts", error);
        showErrorToast(
          this.dispatchEvent.bind(this),
          "Error",
          "Failed to load shifts"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  processShifts(data) {
    const shiftMap = {};
    data.forEach((shift) => {
      if (!shift.Shift_Type__r) {
        return; // Skip records without shift type to avoid errors
      }
      const start = new Date(shift.From_Date__c);
      const end = new Date(shift.To_Date__c);

      // Normalize dates to midnight for comparison
      const s = new Date(
        start.getFullYear(),
        start.getMonth(),
        start.getDate()
      );
      const e = new Date(end.getFullYear(), end.getMonth(), end.getDate());

      this.weekDays.forEach((day) => {
        const d = new Date(
          day.date.getFullYear(),
          day.date.getMonth(),
          day.date.getDate()
        );

        if (d >= s && d <= e) {
          shiftMap[day.isoDate] = {
            name: shift.Shift_Type__r.Name || "Shift",
            start: this.formatTime(shift.Shift_Type__r.Start_Time__c),
            end: this.formatTime(shift.Shift_Type__r.End_Time__c)
          };
        }
      });
    });

    this.weekDays = this.weekDays.map((day) => {
      const hasShift = !!shiftMap[day.isoDate];
      let cardClass = "day-card";
      if (day.isToday) cardClass += " today";
      if (hasShift) cardClass += " working";
      else cardClass += " off";

      return {
        ...day,
        shift: shiftMap[day.isoDate],
        cardClass
      };
    });
  }

  formatTime(ms) {
    if (ms === undefined || ms === null) return "";

    try {
      // Handle milliseconds from midnight
      if (typeof ms === "number") {
        const date = new Date();
        date.setHours(0, 0, 0, 0);
        date.setMilliseconds(ms);
        return date.toLocaleTimeString("en-US", {
          hour: "2-digit",
          minute: "2-digit",
          hour12: true
        });
      }

      // Handle string format "HH:mm:ss" or "HH:mm:ss.SSSZ"
      if (typeof ms === "string") {
        const timeParts = ms.split(":");
        if (timeParts.length >= 2) {
          const hours = Number.parseInt(timeParts[0], 10);
          const minutes = Number.parseInt(timeParts[1], 10);
          const date = new Date();
          date.setHours(hours, minutes, 0);
          return date.toLocaleTimeString("en-US", {
            hour: "2-digit",
            minute: "2-digit",
            hour12: true
          });
        }
      }

      return ms;
    } catch (error) {
      logError("ShiftRosterView.formatTime", error);
      return ms;
    }
  }
}