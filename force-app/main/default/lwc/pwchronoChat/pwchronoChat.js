import { LightningElement, track } from "lwc";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";

const INITIAL_CONTACTS = [
  {
    id: "c-1",
    name: "Anthony Lewis",
    avatar: "avatar-29.jpg",
    isOnline: true,
    time: "02:40 PM",
    lastMessage: "is typing...",
    unreadCount: 0
  },
  {
    id: "c-2",
    name: "Elliot Murray",
    avatar: "avatar-01.jpg",
    isOnline: true,
    time: "06:12 AM",
    lastMessage: "Document",
    unreadCount: 0
  },
  {
    id: "c-3",
    name: "Stephan Peralt",
    avatar: "avatar-02.jpg",
    isOnline: false,
    time: "03:15 AM",
    lastMessage: "Missed Video Call",
    unreadCount: 0
  },
  {
    id: "c-4",
    name: "Rebecca Smtih",
    avatar: "avatar-18.jpg",
    isOnline: true,
    time: "Sunday",
    lastMessage: "Hi How are you ðŸ”¥",
    unreadCount: 25
  },
  {
    id: "c-5",
    name: "Harvey Smith",
    avatar: "avatar-14.jpg",
    isOnline: false,
    time: "03:15 AM",
    lastMessage: "Haha oh man ðŸ”¥",
    unreadCount: 12
  },
  {
    id: "c-6",
    name: "Lori Broaddus",
    avatar: "avatar-03.jpg",
    isOnline: false,
    time: "02:40 PM",
    lastMessage: "Do you know which...",
    unreadCount: 0
  },
  {
    id: "c-7",
    name: "Brian Villalobos",
    avatar: "avatar-15.jpg",
    isOnline: true,
    time: "06:12 AM",
    lastMessage: "Do you know which...",
    unreadCount: 0
  },
  {
    id: "c-8",
    name: "Linda Ray",
    avatar: "avatar-08.jpg",
    isOnline: false,
    time: "Wednesday",
    lastMessage: "Photo",
    unreadCount: 12
  },
  {
    id: "c-9",
    name: "Doglas Martini",
    avatar: "avatar-07.jpg",
    isOnline: true,
    time: "02:40 PM",
    lastMessage: "Incoming Video Call",
    unreadCount: 0
  }
];

const INITIAL_MESSAGES = [
  {
    id: "m-1",
    isOutgoing: false,
    text: "Hi John, I wanted to update you on a new company policy regarding remote work.",
    time: "08:00 AM"
  },
  {
    id: "m-2",
    isOutgoing: false,
    text: "Do you have a moment?",
    time: "08:00 AM"
  },
  {
    id: "m-3",
    isOutgoing: true,
    text: "Sure, Sarah. What's the new policy?",
    time: "08:00 AM"
  },
  {
    id: "m-4",
    isOutgoing: false,
    text: "Starting next month, we'll be implementing a hybrid work model. Employees can work from home up to three days a week.",
    time: "08:00 AM"
  },
  {
    id: "m-5",
    isOutgoing: true,
    text: "That sounds great! Are there any specific requirements for tracking our hours when working remotely?",
    time: "08:00 AM"
  },
  {
    id: "m-6",
    isOutgoing: false,
    text: "Yes, we'll be using a time-tracking tool to log hours. You'll need to ensure you're available during your usual working hours and keep your manager updated if anything changes.",
    time: "08:00 AM"
  }
];

export default class PwchronoChat extends LightningElement {
  @track contacts = [];
  @track activeContactId = "c-1";
  @track messages = [];
  @track messageInput = "";
  @track searchKeyword = "";

  connectedCallback() {
    this.contacts = INITIAL_CONTACTS.map((c) => ({
      ...c,
      avatarUrl: `${smarthrAssets}/assets/img/profiles/${c.avatar}`
    }));

    this.messages = INITIAL_MESSAGES.map((m) => this.formatMessage(m));
  }

  get userAvatarUrl() {
    return `${smarthrAssets}/assets/img/profiles/avatar-02.jpg`;
  }

  get activeContact() {
    return (
      this.contacts.find((c) => c.id === this.activeContactId) ||
      this.contacts[0] ||
      {}
    );
  }

  get filteredContacts() {
    const q = (this.searchKeyword || "").toLowerCase().trim();
    return this.contacts
      .filter((c) => !q || c.name.toLowerCase().includes(q) || c.lastMessage.toLowerCase().includes(q))
      .map((c) => ({
        ...c,
        itemClass:
          c.id === this.activeContactId
            ? "chat-contact-item active d-flex align-items-center p-3 border-bottom cursor-pointer"
            : "chat-contact-item d-flex align-items-center p-3 border-bottom cursor-pointer"
      }));
  }

  formatMessage(m) {
    return {
      ...m,
      containerClass: m.isOutgoing
        ? "d-flex justify-content-end mb-3 chat-row-outgoing"
        : "d-flex justify-content-start mb-3 chat-row-incoming",
      bubbleClass: m.isOutgoing
        ? "chat-bubble bg-primary-soft text-dark p-3 rounded-4"
        : "chat-bubble bg-white text-dark p-3 rounded-4 shadow-sm border",
      metaClass: m.isOutgoing
        ? "text-end mt-1 d-flex align-items-center justify-content-end"
        : "text-start mt-1 d-flex align-items-center"
    };
  }

  selectContact(e) {
    this.activeContactId = e.currentTarget.dataset.id;
  }

  handleSearch(e) {
    this.searchKeyword = e.target.value;
  }

  handleMessageInput(e) {
    this.messageInput = e.target.value;
  }

  handleKeyDown(e) {
    if (e.key === "Enter") {
      this.handleSend();
    }
  }

  handleSend() {
    const text = (this.messageInput || "").trim();
    if (!text) return;

    const now = new Date();
    const hours = now.getHours();
    const minutes = String(now.getMinutes()).padStart(2, "0");
    const ampm = hours >= 12 ? "PM" : "AM";
    const timeStr = `${hours % 12 || 12}:${minutes} ${ampm}`;

    const newMsg = this.formatMessage({
      id: "m-" + Date.now(),
      isOutgoing: true,
      text: text,
      time: timeStr
    });

    this.messages = [...this.messages, newMsg];
    this.messageInput = "";

    // Auto-scroll to bottom
    setTimeout(() => {
      const stream = this.template.querySelector("#chat-stream");
      if (stream) {
        stream.scrollTop = stream.scrollHeight;
      }
    }, 100);
  }
}