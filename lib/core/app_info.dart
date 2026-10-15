// Copyright (c) 2026 P Om Shiva. All rights reserved.
// Unauthorised copying, modification or distribution of this file, by any
// means, is prohibited without the author's written permission. See LICENSE.

/// Who made AquaAware, and why. Shown on the sign-in screen, the About page,
/// the licences page and the website, so it is defined once, here.
abstract final class AppInfo {
  static const appName = 'AquaAware';
  static const version = '2.0';

  static const author = 'P Om Shiva';
  static const authorDegree = 'M.Tech CSE (2nd year)';
  static const authorDegreeLong = 'M.Tech, Computer Science and Engineering (2nd year)';
  static const authorInstitution = 'Pondicherry University';
  static const authorGitHub = 'https://github.com/omshiva24';

  static const year = 2026;
  static const copyright = '© $year $author. All rights reserved.';

  /// The licence in plain words (the full text is in LICENSE).
  static const licenceSummary =
      'AquaAware, its design, code, lessons and artwork are the original work of $author. '
      'No part of it may be copied, changed, republished or used in another project, '
      'in whole or in part, without the written permission of the author.';

  /// The author's message: why AquaAware exists.
  static const missionTitle = 'Why I made AquaAware';
  static const mission = <String>[
    'Chennai ran out of water in 2019. Bengaluru faced the same fear in 2024. '
        'More than 163 million Indians still live without safe drinking water, '
        'and the waste we throw away every day ends up in our rivers and our sea.',
    'Posters and speeches tell people about the problem, but they rarely change what anyone does '
        'the next morning. I wanted something that turns knowing into doing: learn for a few minutes, '
        'act on it the same day, and see your effort count.',
    'That is AquaAware. Every lesson finished, every bin sorted correctly, every tap closed and every '
        'litre saved fills your own reservoir, and your whole group’s. It works in a school, a college, '
        'an office or a street, on any phone or computer, even without the internet.',
    'Water does not wait for someone else to act. Neither should we.',
  ];
  static const missionSignature = '$author, $authorDegree, $authorInstitution';
}
