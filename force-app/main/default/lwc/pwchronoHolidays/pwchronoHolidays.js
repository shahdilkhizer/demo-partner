import getUpcomingHolidays from "@salesforce/apex/PWChrono_HolidayController.getUpcomingHolidays";
import { LightningElement, track, wire } from "lwc";

const DAY_NAMES = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday"
];
const MONTH_NAMES = [
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
];

export default class PwchronoHolidays extends LightningElement {
  static renderMode = "light";

  @track holidays = [];
  @track isLoading = true;
  @track loadError = null;

  @wire(getUpcomingHolidays)
  wiredHolidays({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.holidays = data.map((h) => this.formatHoliday(h));
      this.loadError = null;
    } else if (error) {
      this.loadError = error?.body?.message || "Failed to load holidays";
      this.holidays = [];
    }
  }

  formatHoliday(holiday) {
    let formattedDate = holiday.Holiday_Date__c;
    let dayName = "";
    try {
      const d = new Date(holiday.Holiday_Date__c);
      const day = d.getUTCDate();
      const month = MONTH_NAMES[d.getUTCMonth()];
      const year = d.getUTCFullYear();
      formattedDate = `${String(day).padStart(2, "0")} ${month} ${year}`;
      dayName = DAY_NAMES[d.getUTCDay()];
    } catch {
      // keep raw value if parse fails
    }
    return { ...holiday, formattedDate, dayName };
  }

  get hasHolidays() {
    return this.holidays.length > 0;
  }

  get totalCount() {
    return this.holidays.length;
  }
}