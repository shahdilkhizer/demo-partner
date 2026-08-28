import { LightningElement } from "lwc";

export default class PwchronoDashboardBirthdays extends LightningElement {
  birthdays = [
    {
      date: "Today",
      people: [
        {
          id: 1,
          name: "Andrew Jermia",
          role: "IOS Developer",
          avatarUrl: ""
        }
      ]
    },
    {
      date: "Tomorrow",
      people: [
        {
          id: 2,
          name: "Mary Zeen",
          role: "UI/UX Designer",
          avatarUrl: ""
        },
        {
          id: 3,
          name: "Antony Lewis",
          role: "Android Developer",
          avatarUrl: ""
        }
      ]
    },
    {
      date: "25 Jan 2025",
      people: [
        {
          id: 4,
          name: "Doglas Martini",
          role: ".Net Developer",
          avatarUrl: ""
        }
      ]
    }
  ];
}