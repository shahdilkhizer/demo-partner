import { LightningElement, wire, track } from "lwc";
import getNotifications from "@salesforce/apex/PWChrono_NotificationController.getNotifications";
import markAsRead from "@salesforce/apex/PWChrono_NotificationController.markAsRead";
import markAllAsRead from "@salesforce/apex/PWChrono_NotificationController.markAllAsRead";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";

export default class PwchronoNotificationBell extends NavigationMixin(
  LightningElement
) {
  @track isPanelOpen = false;
  @track notifications = [];
  wiredNotificationsResult;

  @wire(getNotifications)
  wiredNotifications(result) {
    this.wiredNotificationsResult = result;
    if (result.data) {
      this.notifications = result.data.map((n) => ({
        ...n,
        itemClass: `notification-item ${n.IsRead ? "" : "unread"}`,
        iconName: this.getIconName(n.Type),
        timeAgo: this.getTimeAgo(n.CreatedDate)
      }));
    }
  }

  get unreadCount() {
    return this.notifications.filter((n) => !n.IsRead).length;
  }

  togglePanel() {
    this.isPanelOpen = !this.isPanelOpen;
  }

  handleNotificationClick(event) {
    const { id, url } = event.currentTarget.dataset;
    markAsRead({ notificationId: id }).then(() => {
      refreshApex(this.wiredNotificationsResult);
    });

    if (url) {
      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: {
          url: url
        }
      });
    }
    this.isPanelOpen = false;
  }

  handleMarkAllRead() {
    markAllAsRead().then(() => {
      refreshApex(this.wiredNotificationsResult);
    });
  }

  getIconName(type) {
    switch (type) {
      case "Success":
        return "utility:success";
      case "Warning":
        return "utility:warning";
      case "Alert":
        return "utility:error";
      default:
        return "utility:info";
    }
  }

  getTimeAgo(dateString) {
    const date = new Date(dateString);
    const seconds = Math.floor((Date.now() - date) / 1000);
    let interval = seconds / 31536000;
    if (interval > 1) return Math.floor(interval) + " years ago";
    interval = seconds / 2592000;
    if (interval > 1) return Math.floor(interval) + " months ago";
    interval = seconds / 86400;
    if (interval > 1) return Math.floor(interval) + " days ago";
    interval = seconds / 3600;
    if (interval > 1) return Math.floor(interval) + " hours ago";
    interval = seconds / 60;
    if (interval > 1) return Math.floor(interval) + " minutes ago";
    return Math.floor(seconds) + " seconds ago";
  }
}