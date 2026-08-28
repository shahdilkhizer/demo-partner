import { LightningElement, track, wire } from "lwc";
import getLeaveCalendarData from "@salesforce/apex/PWChrono_LeaveController.getLeaveCalendarData";
import getHolidays from "@salesforce/apex/PWChrono_LeaveController.getHolidays";

const MONTH_NAMES = [
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

export default class PwchronoLeaveCalendar extends LightningElement {
  @track currentDate = new Date();
  @track calendarDays = [];
  @track isLoading = true;

  leaves = [];
  holidays = [];

  get currentMonthName() {
    return MONTH_NAMES[this.currentDate.getMonth()];
  }

  get currentYear() {
    return this.currentDate.getFullYear();
  }

  get startDate() {
    const date = new Date(
      this.currentDate.getFullYear(),
      this.currentDate.getMonth(),
      1
    );
    // Adjust to start of week (Sunday)
    date.setDate(date.getDate() - date.getDay());
    return date;
  }

  get endDate() {
    const date = new Date(
      this.currentDate.getFullYear(),
      this.currentDate.getMonth() + 1,
      0
    );
    // Adjust to end of week (Saturday)
    date.setDate(date.getDate() + (6 - date.getDay()));
    return date;
  }

  get hasLeaveOrHolidays() {
    return (
      (this.leaves && this.leaves.length > 0) ||
      (this.holidays && this.holidays.length > 0)
    );
  }

  @wire(getLeaveCalendarData, { startDate: "$startDate", endDate: "$endDate" })
  wiredLeaves({ error, data }) {
    if (data) {
      this.leaves = data;
      this.generateCalendar();
      this.isLoading = false;
    } else if (error) {
      this.isLoading = false;
      /* Error loading leaves */
    }
  }

  @wire(getHolidays, { startDate: "$startDate", endDate: "$endDate" })
  wiredHolidays({ error, data }) {
    if (data) {
      this.holidays = data;
      this.generateCalendar();
    } else if (error) {
      /* Error loading holidays */
    }
  }

  connectedCallback() {
    this.generateCalendar();
  }

  handlePrevMonth() {
    this.currentDate = new Date(
      this.currentDate.getFullYear(),
      this.currentDate.getMonth() - 1,
      1
    );
    this.generateCalendar();
  }

  handleNextMonth() {
    this.currentDate = new Date(
      this.currentDate.getFullYear(),
      this.currentDate.getMonth() + 1,
      1
    );
    this.generateCalendar();
  }

  generateCalendar() {
    const days = [];
    const start = new Date(this.startDate);
    const end = new Date(this.endDate);
    const currentMonth = this.currentDate.getMonth();

    let loopDate = new Date(start);

    while (loopDate.getTime() <= end.getTime()) {
      const dateStr = loopDate.toISOString().split("T")[0];
      const isCurrentMonth = loopDate.getMonth() === currentMonth;
      const isToday = new Date().toDateString() === loopDate.toDateString();

      let cssClass = "calendar-day";
      if (!isCurrentMonth) cssClass += " other-month";
      if (isToday) cssClass += " today";

      const dayEvents = [];

      // Add Holidays
      this.holidays.forEach((holiday) => {
        if (holiday.Holiday_Date__c === dateStr) {
          dayEvents.push({
            id: holiday.Id,
            title: holiday.Name,
            cssClass: "event holiday"
          });
        }
      });

      // Add Leaves
      this.leaves.forEach((leave) => {
        if (leave.From_Date__c <= dateStr && leave.To_Date__c >= dateStr) {
          dayEvents.push({
            id: leave.Id,
            title: leave.Leave_Type__r ? leave.Leave_Type__r.Name : "Leave",
            cssClass: "event leave"
          });
        }
      });

      days.push({
        id: dateStr,
        number: loopDate.getDate(),
        cssClass: cssClass,
        events: dayEvents
      });

      loopDate.setDate(loopDate.getDate() + 1);
    }

    this.calendarDays = days;
  }
}