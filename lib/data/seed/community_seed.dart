// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import '../../core/utils/geo.dart';
import '../models/models.dart';

/// People and places for the Pondicherry pilot.
///
/// Demo secrets are stored only as PBKDF2-SHA256 hashes (100,000 iterations,
/// precomputed). The plain demo credentials are listed in README.md so the
/// app can be tried; change them before any real deployment.
abstract final class CommunitySeed {
  /// Version 3 added the demo college class, version 4 the demo office team.
  /// Devices with version 2 data or later keep everything and only gain the
  /// new entries (see AppStore.load).
  static const int version = 4;

  static const city = GeoPoint(11.9416, 79.8083);

  /// Q8 — the NGO reward desk (Block B, Room 204) and the geofence radius.
  static const rewardDesk = GeoPoint(12.0163, 79.8517);
  static const rewardDeskLabel = 'Block B, Room 204, Pondicherry University';
  static const rewardDeskRadiusMeters = 100.0;

  static const classes = <ClassRoom>[
    ClassRoom(
      code: 'AWA-2024-GHS',
      school: 'Government Higher Secondary School, Pondicherry',
      educatorId: 'EDU001',
      city: 'Pondicherry',
    ),
    ClassRoom(
      code: 'AWA-2024-SJH',
      school: "St. Joseph's Higher Secondary School, Pondicherry",
      educatorId: 'EDU002',
      city: 'Pondicherry',
    ),
    // A demo college (the name is invented) so the college wording can be tried.
    ClassRoom(
      code: 'AWA-2024-CCAS',
      school: 'Coastal College of Arts and Science, Pondicherry',
      educatorId: 'EDU003',
      city: 'Pondicherry',
      kind: InstitutionKind.college,
    ),
    // A demo office team (the company name is invented): AquaAware is for
    // workplaces too, with a team lead, employees and a team code.
    ClassRoom(
      code: 'AWA-2026-CTP',
      school: 'Coastline Tech Park – Green Team, Pondicherry',
      educatorId: 'EDU004',
      city: 'Pondicherry',
      kind: InstitutionKind.office,
    ),
  ];

  static List<Account> accounts() => [
        Account(
          id: 'EDU001',
          role: Role.educator,
          name: 'Mrs. Kavitha Selvaraj',
          loginId: 'kavitha@aquaaware.org',
          secretHash: r'pbkdf2-sha256$100000$vwHRsuWe+t6WPc1PIiaEZw==$E1iw2fVke39D5tLACKb0B0xI/+Sqjd1gfeA9owzEvmI=',
          school: classes[0].school,
          classCode: classes[0].code,
        ),
        Account(
          id: 'EDU002',
          role: Role.educator,
          name: 'Mr. Rajan Pillai',
          loginId: 'rajan@aquaaware.org',
          secretHash: r'pbkdf2-sha256$100000$+xEbtGOOAUrQZ7zBVCnwRQ==$Pr7pMYkdfV7AQ/5nqYJQTZyQgt/rKL64+RxlHs7HSao=',
          school: classes[1].school,
          classCode: classes[1].code,
        ),
        Account(
          id: 'EDU003',
          role: Role.educator,
          name: 'Dr. Anitha Raman',
          loginId: 'anitha@aquaaware.org',
          secretHash: r'pbkdf2-sha256$100000$pRCc7omjlfZFgRL9iQneuw==$Conl2oqavhhJDvHmPzgwnDS/tCMyNx0tBc1fahUDvj0=',
          school: classes[2].school,
          classCode: classes[2].code,
        ),
        Account(
          id: 'EDU004',
          role: Role.educator,
          name: 'Ms. Deepa Krishnan',
          loginId: 'deepa@aquaaware.org',
          secretHash: r'pbkdf2-sha256$100000$CvDzxt/81jH82EsHrBmyrg==$5ZgqwtCeVgf42g7E5BVRPhH/kqLJUqTBFHS6c7ciLNM=',
          school: classes[3].school,
          classCode: classes[3].code,
        ),
        Account(
          id: 'MGR001',
          role: Role.manager,
          name: 'Programme Manager',
          loginId: 'admin@aquaaware.org',
          secretHash: r'pbkdf2-sha256$100000$VHjmYygPJCWdZCK83xSs2Q==$LGe5KTGyfVW3JTXRE3cUF2VZ18IXdtyOJ1nuruKqsbk=',
        ),
        for (final n in ngos)
          Account(
            id: 'DESK-${n.id}',
            role: Role.ngo,
            name: n.name,
            loginId: n.id,
            secretHash: _ngoHashes[n.id]!,
            ngoId: n.id,
          ),
      ];

  static const _ngoHashes = <String, String>{
    'NGO001': r'pbkdf2-sha256$100000$wnawcJrqBdNwKOUw/dzm9w==$P9yXz3v9sukDogAsRcGjggIFo3kAJ8DylbodJlaau6U=',
    'NGO002': r'pbkdf2-sha256$100000$oAIJbNmEJcRWlm2qG9Q0Jg==$wGmZ05eNjVmjJQ37R7UAiBLje/JruT4/Xjh2SdMGD8g=',
    'NGO003': r'pbkdf2-sha256$100000$lMLy8r/mx7HlGNDMVSwa4A==$RBirP1cYTwqNOqbb5pOgkVgyAXHNtJuhU3TNVtIx/K0=',
    'NGO004': r'pbkdf2-sha256$100000$xpISU2fcI9CY0Aii1dQbiA==$kZL9/m6GJuTN12ImDenjPK+Rq8OHBYC6dyo8m9GgOOI=',
    'NGO005': r'pbkdf2-sha256$100000$KA/aYyMn5FH7Umn76VpH5Q==$gbox9le5/Nt47MSBKandjLdIOyrAJkn7hHY68tAuKlg=',
  };

  /// Students carried over from the first version, with their progress.
  /// Each profile is unclaimed until the student signs in and sets a PIN.
  /// Phone numbers are placeholders: personal numbers never belong in source
  /// code. Real contact details are entered on a real deployment only.
  static List<StudentProfile> students() {
    const rows = <(String, String, int, int)>[
      ('Pranil', '+91 00000 00101', 5, 92),
      ('Priya', '+91 00000 00102', 4, 88),
      ('Anbirkavin', '+91 00000 00103', 6, 95),
      ('Anujith Balan', '+91 00000 00104', 3, 78),
      ('Ashmi', '+91 00000 00105', 5, 90),
      ('Dhinesh', '+91 00000 00106', 2, 65),
      ('Reethu', '+91 00000 00107', 6, 98),
      ('Snekha', '+91 00000 00108', 4, 82),
      ('Sri', '+91 00000 00109', 5, 89),
      ('Vishwa', '+91 00000 00110', 6, 94),
      ('Yougaaraj', '+91 00000 00111', 3, 75),
      ('Vishnu', '+91 00000 00112', 5, 91),
      ('Abishek Suresh', '+91 00000 00113', 4, 85),
      ('Bhanu', '+91 00000 00114', 6, 97),
      ('Nantha Kumar', '+91 00000 00115', 2, 60),
      // Demo college students (invented names).
      ('Kavya', '+91 00000 00116', 4, 86),
      ('Arjun', '+91 00000 00117', 3, 79),
      ('Meera', '+91 00000 00118', 5, 91),
      ('Rahul', '+91 00000 00119', 2, 70),
      // Demo office employees (invented names).
      ('Ravi', '+91 00000 00120', 3, 82),
      ('Sneha', '+91 00000 00121', 5, 93),
      ('Karthik', '+91 00000 00122', 1, 64),
      ('Fathima', '+91 00000 00123', 4, 88),
    ];
    final joined = DateTime(2026, 6, 1);
    return [
      for (var i = 0; i < rows.length; i++)
        StudentProfile(
          id: 'STU${(i + 1).toString().padLeft(3, '0')}',
          name: rows[i].$1,
          phone: rows[i].$2,
          classCode: i < 9
              ? classes[0].code
              : i < 15
                  ? classes[1].code
                  : i < 19
                      ? classes[2].code
                      : classes[3].code,
          importedModules: rows[i].$3,
          importedScorePct: rows[i].$4,
          joinedAt: joined,
        ),
    ];
  }

  static final ngos = <Ngo>[
    Ngo(
      id: 'NGO001',
      name: 'Pondicherry Science Forum',
      focus: 'Environment, water conservation, science awareness',
      address: 'No. 10, II Street, PR Gardens, Reddiarpalayam, Pondicherry 605010',
      phone: '+91 94432 25288',
      email: 'psf@pondicherryscienceforum.org',
      location: const GeoPoint(11.9380, 79.8120),
      area: 'Reddiarpalayam',
      activities: [
        NgoActivity(id: 'A1', name: 'Water awareness campaign', date: DateTime(2026, 10, 18), participants: 120),
        NgoActivity(id: 'A2', name: 'School education programme', date: DateTime(2026, 10, 25), participants: 85),
        NgoActivity(id: 'A3', name: 'Waste management drive', date: DateTime(2026, 11, 2), participants: 45),
      ],
    ),
    Ngo(
      id: 'NGO002',
      name: 'Centre for Environment and Agricultural Development (CEAD)',
      focus: 'Environment, agriculture, water resources',
      address: 'No. 72, Nallavadu Road, Thavalakuppam, Pondicherry 605007',
      phone: '+91 413 2618941',
      email: 'cead@pondicherry.org',
      location: const GeoPoint(11.9290, 79.8050),
      area: 'Thavalakuppam',
      activities: [
        NgoActivity(id: 'B1', name: 'Rainwater harvesting build', date: DateTime(2026, 11, 5), participants: 30),
        NgoActivity(id: 'B2', name: 'Beach clean-up', date: DateTime(2026, 11, 12), participants: 200),
        NgoActivity(id: 'B3', name: 'Waste segregation drive', date: DateTime(2026, 11, 18), participants: 60),
      ],
    ),
    Ngo(
      id: 'NGO003',
      name: 'Community Seva Centre',
      focus: 'Community development, environment, beach clean-ups',
      address: 'No. 25 Seva Illam, Seva Nagar, Poorankuppam, Beach Road, Pondicherry 605007',
      phone: '+91 94431 57759',
      email: 'communitysevacentre@gmail.com',
      location: const GeoPoint(11.9250, 79.8310),
      area: 'Thavalakuppam Beach',
      activities: [
        NgoActivity(id: 'C1', name: 'Beach clean-up', date: DateTime(2026, 10, 15), participants: 350),
        NgoActivity(id: 'C2', name: 'Ocean waste collection', date: DateTime(2026, 10, 28), participants: 90),
        NgoActivity(id: 'C3', name: 'Community awareness walk', date: DateTime(2026, 11, 8), participants: 110),
      ],
    ),
    Ngo(
      id: 'NGO004',
      name: 'Pondicherry Multipurpose Social Service Society',
      focus: 'Social service, environment, education',
      address: 'No. 81, Laporte Street, Pondicherry Bazaar, Pondicherry 605001',
      phone: '+91 413 2235655',
      email: 'pmsss@pondicherry.org',
      location: const GeoPoint(11.9344, 79.8298),
      area: 'White Town',
      activities: [
        NgoActivity(id: 'D1', name: 'Waste collection drive', date: DateTime(2026, 12, 1), participants: 75),
        NgoActivity(id: 'D2', name: 'Water conservation talk', date: DateTime(2026, 12, 10), participants: 150),
        NgoActivity(id: 'D3', name: 'School programme', date: DateTime(2026, 12, 15), participants: 200),
      ],
    ),
    Ngo(
      id: 'NGO005',
      name: 'Puducherry Social Service Software Research Foundation (PSSSRF)',
      focus: 'Health, education, environment technology',
      address: '18, Chetty Street, Pondicherry 605110',
      phone: '+91 413 2918492',
      email: 'contact@psssrf.org.in',
      location: const GeoPoint(12.0150, 79.8530),
      area: 'Pondicherry University, Kalapet',
      activities: [
        NgoActivity(id: 'E1', name: 'Digital awareness session', date: DateTime(2027, 1, 8), participants: 50),
        NgoActivity(id: 'E2', name: 'Water education day', date: DateTime(2027, 1, 15), participants: 300),
        NgoActivity(id: 'E3', name: 'Community tech programme', date: DateTime(2027, 1, 22), participants: 120),
      ],
    ),
  ];

  static Ngo ngo(String id) => ngos.firstWhere((n) => n.id == id, orElse: () => ngos.first);

  static const collectors = <Collector>[
    Collector(id: 'COL001', name: 'Ramesh Kumar', phone: '+91 98765 43210', wasteType: 'Plastic',
        available: true, location: GeoPoint(11.9344, 79.8298), area: 'White Town'),
    Collector(id: 'COL002', name: 'Suresh Babu', phone: '+91 87654 32109', wasteType: 'Paper',
        available: true, location: GeoPoint(11.9612, 79.8108), area: 'Lawspet'),
    Collector(id: 'COL003', name: 'Gopi Shankar', phone: '+91 76543 21098', wasteType: 'E-waste',
        available: false, location: GeoPoint(12.0230, 79.8580), area: 'Kalapet'),
    Collector(id: 'COL004', name: 'Murugan', phone: '+91 00000 00204', wasteType: 'Glass',
        available: true, location: GeoPoint(11.9502, 79.8201), area: 'Mudaliarpet'),
    Collector(id: 'COL005', name: 'Selvi Rani', phone: '+91 00000 00205', wasteType: 'Cloth',
        available: false, location: GeoPoint(11.9680, 79.8170), area: 'Oulgaret'),
  ];

  static Collector collector(String id) =>
      collectors.firstWhere((c) => c.id == id, orElse: () => collectors.first);

  static const schools = <SchoolSite>[
    SchoolSite(id: 'SCH001', name: 'Government Higher Secondary School', location: GeoPoint(11.9344, 79.8270)),
    SchoolSite(id: 'SCH002', name: "St. Joseph's Higher Secondary School", location: GeoPoint(11.9395, 79.8260)),
    SchoolSite(id: 'SCH003', name: 'Pondicherry University', location: rewardDesk, type: 'University'),
    SchoolSite(
      id: 'SCH004',
      name: 'Coastal College of Arts and Science',
      location: GeoPoint(11.9585, 79.8155),
      type: 'College',
    ),
    SchoolSite(
      id: 'SCH005',
      name: 'Coastline Tech Park',
      location: GeoPoint(11.9470, 79.8030),
      type: 'Office',
    ),
  ];

  static const landmarks = <(String, GeoPoint)>[
    ('Rock Beach', GeoPoint(11.9344, 79.8365)),
  ];
}
