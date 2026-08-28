import { LightningElement, wire, track } from "lwc";
import getUpcomingHolidays from "@salesforce/apex/PWChrono_HolidayController.getUpcomingHolidays";

export default class PwchronoHolidayCalendar extends LightningElement {
  @track holidays;
  @track error;
  @track isLoading = true;

  @wire(getUpcomingHolidays)
  wiredHolidays({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.holidays = data;
      this.error = undefined;
    } else if (error) {
      this.error = error.body.message;
      this.holidays = undefined;
    }
  }

  get hasHolidays() {
    return this.holidays && this.holidays.length > 0;
  }
}