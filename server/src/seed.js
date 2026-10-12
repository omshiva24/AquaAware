// Generated from lib/data/seed/community_seed.dart so the app and the server
// share the same pilot accounts. Secrets are stored as PBKDF2-SHA256 hashes only.

export const classes = [
  {
    "code": "AWA-2024-GHS",
    "school": "Government Higher Secondary School, Pondicherry",
    "educatorId": "EDU001",
    "city": "Pondicherry"
  },
  {
    "code": "AWA-2024-SJH",
    "school": "St. Joseph's Higher Secondary School, Pondicherry",
    "educatorId": "EDU002",
    "city": "Pondicherry"
  }
];

export const accounts = [
  {
    "id": "EDU001",
    "role": "educator",
    "name": "Mrs. Kavitha Selvaraj",
    "loginId": "kavitha@aquaaware.org",
    "secretHash": "pbkdf2-sha256$100000$vwHRsuWe+t6WPc1PIiaEZw==$E1iw2fVke39D5tLACKb0B0xI/+Sqjd1gfeA9owzEvmI=",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "EDU002",
    "role": "educator",
    "name": "Mr. Rajan Pillai",
    "loginId": "rajan@aquaaware.org",
    "secretHash": "pbkdf2-sha256$100000$+xEbtGOOAUrQZ7zBVCnwRQ==$Pr7pMYkdfV7AQ/5nqYJQTZyQgt/rKL64+RxlHs7HSao=",
    "classCode": "AWA-2024-SJH"
  },
  {
    "id": "MGR001",
    "role": "manager",
    "name": "Programme Manager",
    "loginId": "admin@aquaaware.org",
    "secretHash": "pbkdf2-sha256$100000$VHjmYygPJCWdZCK83xSs2Q==$LGe5KTGyfVW3JTXRE3cUF2VZ18IXdtyOJ1nuruKqsbk="
  },
  {
    "id": "DESK-NGO001",
    "role": "ngo",
    "name": "Pondicherry Science Forum",
    "loginId": "NGO001",
    "secretHash": "pbkdf2-sha256$100000$wnawcJrqBdNwKOUw/dzm9w==$P9yXz3v9sukDogAsRcGjggIFo3kAJ8DylbodJlaau6U=",
    "ngoId": "NGO001"
  },
  {
    "id": "DESK-NGO002",
    "role": "ngo",
    "name": "Centre for Environment and Agricultural Development (CEAD)",
    "loginId": "NGO002",
    "secretHash": "pbkdf2-sha256$100000$oAIJbNmEJcRWlm2qG9Q0Jg==$wGmZ05eNjVmjJQ37R7UAiBLje/JruT4/Xjh2SdMGD8g=",
    "ngoId": "NGO002"
  },
  {
    "id": "DESK-NGO003",
    "role": "ngo",
    "name": "Community Seva Centre",
    "loginId": "NGO003",
    "secretHash": "pbkdf2-sha256$100000$lMLy8r/mx7HlGNDMVSwa4A==$RBirP1cYTwqNOqbb5pOgkVgyAXHNtJuhU3TNVtIx/K0=",
    "ngoId": "NGO003"
  },
  {
    "id": "DESK-NGO004",
    "role": "ngo",
    "name": "Pondicherry Multipurpose Social Service Society",
    "loginId": "NGO004",
    "secretHash": "pbkdf2-sha256$100000$xpISU2fcI9CY0Aii1dQbiA==$kZL9/m6GJuTN12ImDenjPK+Rq8OHBYC6dyo8m9GgOOI=",
    "ngoId": "NGO004"
  },
  {
    "id": "DESK-NGO005",
    "role": "ngo",
    "name": "Puducherry Social Service Software Research Foundation (PSSSRF)",
    "loginId": "NGO005",
    "secretHash": "pbkdf2-sha256$100000$KA/aYyMn5FH7Umn76VpH5Q==$gbox9le5/Nt47MSBKandjLdIOyrAJkn7hHY68tAuKlg=",
    "ngoId": "NGO005"
  }
];

// Guardians' phone numbers are deliberately not copied to the server.
export const students = [
  {
    "id": "STU001",
    "name": "Pranil",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU002",
    "name": "Priya",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU003",
    "name": "Anbirkavin",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU004",
    "name": "Anujith Balan",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU005",
    "name": "Ashmi",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU006",
    "name": "Dhinesh",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU007",
    "name": "Reethu",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU008",
    "name": "Snekha",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU009",
    "name": "Sri",
    "classCode": "AWA-2024-GHS"
  },
  {
    "id": "STU010",
    "name": "Vishwa",
    "classCode": "AWA-2024-SJH"
  },
  {
    "id": "STU011",
    "name": "Yougaaraj",
    "classCode": "AWA-2024-SJH"
  },
  {
    "id": "STU012",
    "name": "Vishnu",
    "classCode": "AWA-2024-SJH"
  },
  {
    "id": "STU013",
    "name": "Abishek Suresh",
    "classCode": "AWA-2024-SJH"
  },
  {
    "id": "STU014",
    "name": "Bhanu",
    "classCode": "AWA-2024-SJH"
  },
  {
    "id": "STU015",
    "name": "Nantha Kumar",
    "classCode": "AWA-2024-SJH"
  }
];

export const collectorIds = ['COL001', 'COL002', 'COL003', 'COL004', 'COL005'];

// The two notices every device starts with (see AppStore._seed), so
// completing them on a device can be recorded and rewarded on the server.
export const announcements = [
  {
    id: 'ANN-seed-1',
    senderId: 'DESK-NGO003',
    senderName: 'Community Seva Centre',
    senderRole: 'ngo',
    audience: 'ALL',
    hoursAgo: 5,
    message:
      'Beach clean-up at Rock Beach this Saturday, 7 am. Bring gloves and a water bottle; we will provide bags. ' +
      'Mark this done once you have registered with your educator.',
  },
  {
    id: 'ANN-seed-2',
    senderId: 'EDU001',
    senderName: 'Mrs. Kavitha Selvaraj',
    senderRole: 'educator',
    audience: 'AWA-2024-GHS',
    hoursAgo: 26,
    message:
      'Please finish module B (Waste segregation) before Friday. We will try the sorting challenge together in class.',
  },
];
