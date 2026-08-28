import getContacts from "@salesforce/apex/PWChrono_ChatController.getContacts";
import getMessages from "@salesforce/apex/PWChrono_ChatController.getMessages";
import sendMessage from "@salesforce/apex/PWChrono_ChatController.sendMessage";
import { logError } from "c/pwchronoErrorHandler";
import { getSession } from "c/pwchronoSession";
import { LightningElement, track } from "lwc";

export default class PwchronoChat extends LightningElement {
  @track contacts = [];
  @track messages = [];
  @track selectedContactId = null;
  @track messageInput = "";
  @track isSending = false;
  @track currentUser = null;
  @track searchTerm = "";

  _refreshInterval;

  connectedCallback() {
    const session = getSession();
    this.currentUser = session?.user;
    this.loadContacts();

    // Simple polling for new messages if active
    // this._refreshInterval = setInterval(() => {
    //     if(this.selectedContactId) this.loadMessages();
    // }, 5000);
  }

  disconnectedCallback() {
    if (this._refreshInterval) clearInterval(this._refreshInterval);
  }

  get showSidebar() {
    // On mobile, hide sidebar if chat is open
    // For simplicity/desktop first: always true or responsive CSS handles it
    return true;
  }

  get filteredContacts() {
    if (!this.searchTerm) return this.contacts;
    const lower = this.searchTerm.toLowerCase();
    return this.contacts.filter((c) => c.name.toLowerCase().includes(lower));
  }

  get selectedContact() {
    return this.contacts.find((c) => c.id === this.selectedContactId);
  }

  get currentUserName() {
    return this.currentUser?.Name || "User";
  }

  get currentUserRole() {
    return this.currentUser?.Role__c || "Employee";
  }

  async loadContacts() {
    try {
      const result = await getContacts();
      this.contacts = result.map((c) => ({
        ...c,
        itemClass: `d-flex align-items-center p-2 rounded ${c.id === this.selectedContactId ? "bg-light" : ""}`,
        lastMessageTimeFormatted: c.lastMessageTime
          ? new Date(c.lastMessageTime).toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit"
            })
          : ""
      }));
    } catch (error) {
      logError("pwchronoChat.loadContacts", error);
    }
  }

  async loadMessages() {
    if (!this.selectedContactId) return;
    try {
      const result = await getMessages({ recipientId: this.selectedContactId });
      this.messages = result.map((m) => ({
        ...m,
        wrapperClass: m.isMe ? "message-right" : "message-left",
        timeFormatted: new Date(m.timestamp).toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit"
        })
      }));
      this.scrollToBottom();
    } catch (error) {
      logError("pwchronoChat.loadMessages", error);
    }
  }

  handleSearchContacts(event) {
    this.searchTerm = event.target.value;
  }

  handleSelectContact(event) {
    const contactId = event.currentTarget.dataset.id;
    this.selectedContactId = contactId;

    // Update active class
    this.contacts = this.contacts.map((c) => ({
      ...c,
      itemClass: `d-flex align-items-center p-2 rounded ${c.id === this.selectedContactId ? "bg-light" : ""}`
    }));

    this.loadMessages();
  }

  handleInputKeyup(event) {
    this.messageInput = event.target.value;
    if (event.key === "Enter") {
      this.handleSendMessage();
    }
  }

  handleInputChange(event) {
    this.messageInput = event.target.value;
  }

  async handleSendMessage() {
    if (!this.messageInput.trim() || !this.selectedContactId) return;

    this.isSending = true;
    try {
      await sendMessage({
        recipientId: this.selectedContactId,
        content: this.messageInput
      });
      this.messageInput = "";
      // Refresh messages
      await this.loadMessages();
    } catch (error) {
      logError("pwchronoChat.handleSendMessage", error);
    } finally {
      this.isSending = false;
    }
  }

  scrollToBottom() {
    // Wait for DOM update before scrolling
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const chatBody = this.template.querySelector(".chat-body");
      if (chatBody) {
        chatBody.scrollTop = chatBody.scrollHeight;
      }
    }, 50);
  }
}