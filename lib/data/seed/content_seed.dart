import '../models/models.dart';
import '../points_rules.dart';

/// Learning content shipped inside the app so every module and quiz works
/// offline from the first launch.
abstract final class ContentSeed {
  static const modules = <LearningModule>[
    LearningModule(
      id: 'MOD_A',
      title: 'The water crisis',
      summary: 'Understanding Day Zero',
      minutes: 8,
      slides: [
        Slide(
          title: 'What is Day Zero?',
          text: 'Day Zero is the day a city shuts off its municipal water supply. Major cities '
              'have already come close: Cape Town in 2018, Chennai in 2019 and Bengaluru in 2024.',
          art: SlideArt.stat('Day 0', 'when a city\'s taps run dry', icon: 'tap'),
        ),
        Slide(
          title: 'The Indian context',
          text: 'Over 163 million Indians lack access to safe drinking water, and around '
              '600 million face high to extreme water stress.',
          art: SlideArt.stat('163M', 'Indians without safe drinking water', icon: 'people'),
        ),
        Slide(
          title: 'Why is it happening?',
          text: 'Over-extraction of groundwater, climate change and pollution of surface water '
              'are the main drivers of the crisis.',
          art: SlideArt.icons(['groundwater', 'heat', 'factory']),
        ),
      ],
    ),
    LearningModule(
      id: 'MOD_B',
      title: 'Waste segregation',
      summary: 'Sorting for sustainability',
      minutes: 10,
      activity: 'sort_game',
      slides: [
        Slide(
          title: 'Colour-coded bins',
          text: 'Segregation starts with colour: green for wet or organic waste, blue for dry '
              'and recyclable waste, red for hazardous waste and yellow for medical waste.',
          art: SlideArt.bins(),
        ),
        Slide(
          title: 'Why segregate?',
          text: 'Mixed waste cannot be recycled. Up to 90% of school waste can be recycled if '
              'it is separated where it is thrown away.',
          art: SlideArt.stat('90%', 'of school waste can be recycled once sorted', icon: 'recycle'),
        ),
      ],
    ),
    LearningModule(
      id: 'MOD_C',
      title: 'Recycling methods',
      summary: 'Giving waste a new life',
      minutes: 12,
      slides: [
        Slide(
          title: 'Paper and plastic',
          text: 'Paper is pulped and pressed into new paper. Plastic bottles can become fabric, '
              'building bricks or new containers.',
          art: SlideArt.icons(['paper', 'cycle', 'bottle', 'shirt']),
        ),
        Slide(
          title: 'Lessons from other countries',
          text: "Japan's \"mottainai\" idea means \"don't waste\". Germany's Pfand system adds a "
              'small deposit to bottles that you get back when you return them.',
          art: SlideArt.icons(['globe', 'bottle', 'coins']),
        ),
      ],
    ),
    LearningModule(
      id: 'MOD_D',
      title: 'The collector system',
      summary: 'The journey of waste',
      minutes: 7,
      slides: [
        Slide(
          title: 'Who collects what?',
          text: 'Collectors specialise: Ramesh takes plastic, Suresh paper, Gopi e-waste, '
              'Murugan glass and Selvi cloth.',
          art: SlideArt.icons(['bottle', 'paper', 'device', 'glass', 'shirt']),
        ),
        Slide(
          title: 'Earn while you sort',
          text: 'Request a pickup in the app, hand over waste that is already segregated, and '
              'earn points towards eco-friendly rewards.',
          art: SlideArt.stat('+${PointRules.pickupHandedOver}', 'points for each handover of sorted waste', icon: 'truck'),
        ),
      ],
    ),
    LearningModule(
      id: 'MOD_E',
      title: 'Water conservation',
      summary: 'Rainwater and greywater',
      minutes: 15,
      slides: [
        Slide(
          title: 'Harvesting rain',
          text: 'A 100 square-metre roof can collect about 55,000 litres of water a year. It is '
              'the simplest way to fight the water crisis.',
          art: SlideArt.stat('55,000 L', 'a year from one 100 m² roof', icon: 'rain'),
        ),
        Slide(
          title: 'Drip and greywater',
          text: 'Drip irrigation uses about 60% less water. Greywater from basins and showers '
              'can water gardens after simple filtering.',
          art: SlideArt.stat('60%', 'less water with drip irrigation', icon: 'sprout'),
        ),
      ],
    ),
    LearningModule(
      id: 'MOD_F',
      title: 'Eco lifestyle',
      summary: 'Sustainability every day',
      minutes: 10,
      slides: [
        Slide(
          title: 'The hidden water cost',
          text: 'Fast fashion is thirsty: a single cotton T-shirt takes about 2,700 litres of '
              'water to produce.',
          art: SlideArt.stat('2,700 L', 'to make one cotton T-shirt', icon: 'shirt'),
        ),
        Slide(
          title: 'Choosing better',
          text: 'Some clothing brands now take back old clothes, and many shops are moving to '
              'eco-packaging. Track your own water footprint and support the ones doing it well.',
          art: SlideArt.icons(['shirt', 'cycle', 'bag']),
        ),
      ],
    ),
  ];

  static LearningModule module(String id) =>
      modules.firstWhere((m) => m.id == id, orElse: () => modules.first);

  static const quizzes = <String, List<QuizQuestion>>{
    'MOD_A': [
      QuizQuestion('Cape Town declared Day Zero in 2018 when dam levels fell below what threshold?',
          ['10%', '13.5%', '20%', '5%'], 1),
      QuizQuestion('Which city faced a severe water crisis in 2024 due to groundwater depletion?',
          ['Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad'], 2),
      QuizQuestion('How many Indians lack access to safe drinking water?',
          ['80 million', '120 million', '163 million', '200 million'], 2),
      QuizQuestion('What is the main cause of groundwater depletion in urban India?',
          ['Rainfall', 'Over-extraction', 'Temperature rise', 'Migration'], 1),
      QuizQuestion("In which year did Chennai face its major Day Zero crisis?",
          ['2017', '2018', '2019', '2020'], 2),
      QuizQuestion('How many million Indians face high to extreme water stress?',
          ['200', '400', '600', '800'], 2),
      QuizQuestion('Which of these is NOT a driver of the water crisis?',
          ['Climate change', 'Pollution', 'Rainwater harvesting', 'Over-extraction'], 2),
      QuizQuestion('What does Day Zero mean?',
          ['A holiday', 'No municipal water', 'Free water', 'A rainy day'], 1),
      QuizQuestion('Surface water pollution in India is mainly caused by:',
          ['Industrial waste', 'Fishing', 'Boating', 'Swimming'], 0),
      QuizQuestion('Which idea lets AquaAware keep working without internet?',
          ['Cloud sync', 'Offline caching', 'VPN', 'Bluetooth'], 1),
    ],
    'MOD_B': [
      QuizQuestion('Which bin colour is used for hazardous waste in India?',
          ['Green', 'Blue', 'Yellow', 'Red'], 3),
      QuizQuestion('How much school waste can be recycled if it is segregated?',
          ['50%', '70%', '90%', '30%'], 2),
      QuizQuestion('Wet or organic waste goes into which bin?', ['Blue', 'Green', 'Red', 'Yellow'], 1),
      QuizQuestion('Dry, recyclable waste belongs in the:',
          ['Green bin', 'Red bin', 'Blue bin', 'Yellow bin'], 2),
      QuizQuestion('Medical waste must go into:', ['Blue bins', 'Yellow bins', 'Green bins', 'Red bins'], 1),
      QuizQuestion('Mixing batteries with food waste is dangerous because of:',
          ['Smell', 'Toxic metals', 'Weight', 'Colour'], 1),
      QuizQuestion('About how much waste does an Indian student generate each day?',
          ['0.2 kg', '0.5 kg', '1.0 kg', '2.0 kg'], 1),
      QuizQuestion('"Segregation at source" means sorting waste:',
          ['At the dump', 'In the truck', 'At home or school', 'At the factory'], 2),
      QuizQuestion('Old newspapers belong in the:', ['Blue bin', 'Green bin', 'Red bin', 'Yellow bin'], 0),
      QuizQuestion('Which technique makes sure nearby collectors are notified?',
          ['Broadcast to everyone', 'Geofencing', 'NFC', 'Printed notices'], 1),
    ],
    'MOD_C': [
      QuizQuestion('Paper is recycled by turning it back into:', ['Glass', 'Pulp', 'Ash', 'Oil'], 1),
      QuizQuestion('Plastic bottles can be recycled into:',
          ['Fresh water', 'Fabric, bricks and new containers', 'Paper', 'Nothing useful'], 1),
      QuizQuestion('The Japanese idea "mottainai" means:',
          ['Buy more', 'Burn waste', "Don't waste", 'Export waste'], 2),
      QuizQuestion("Germany's Pfand system is a:",
          ['Plastic tax', 'Water meter', 'Recycling truck', 'Bottle deposit scheme'], 3),
      QuizQuestion('Why must waste be clean and sorted before recycling?',
          ['Mixed or dirty waste cannot be recycled', 'It looks nicer', 'It weighs more', 'It is a rule'], 0),
      QuizQuestion('Which item is easiest to recycle?',
          ['A greasy pizza box', 'A used tissue', 'A clean newspaper', 'A chip packet'], 2),
    ],
    'MOD_D': [
      QuizQuestion('Who collects plastic waste in the Pondicherry network?',
          ['Suresh', 'Ramesh', 'Gopi', 'Selvi'], 1),
      QuizQuestion('An old phone charger should go to the collector for:',
          ['Paper', 'Cloth', 'E-waste', 'Glass'], 2),
      QuizQuestion('How do you earn points from a pickup?',
          ['Request and cancel', 'Hand over segregated waste', 'Share the app', 'Skip quizzes'], 1),
      QuizQuestion('Why does AquaAware alert only the three nearest collectors?',
          ['Faster pickups without spamming everyone', 'To save paper', 'Collectors asked for it', 'It is random'], 0),
      QuizQuestion('Cloth waste is handled by:', ['Murugan', 'Gopi', 'Selvi', 'Ramesh'], 2),
      QuizQuestion('What should you do before the collector arrives?',
          ['Mix everything in one bag', 'Segregate waste by type', 'Wash the bin', 'Nothing'], 1),
    ],
    'MOD_E': [
      QuizQuestion('About how much rain can a 100 m² roof collect in a year?',
          ['5,500 L', '55,000 L', '550 L', '5.5 million L'], 1),
      QuizQuestion('Drip irrigation uses about how much less water?', ['10%', '30%', '60%', '90%'], 2),
      QuizQuestion('Filtered greywater can safely be used for:',
          ['Drinking', 'Cooking', 'Gardening', 'Bathing babies'], 2),
      QuizQuestion('Rainwater harvesting mainly helps by:',
          ['Making it rain more', 'Recharging groundwater and storing water', 'Cooling roofs', 'Cleaning sewers'], 1),
      QuizQuestion('Fixing one leaky tap can save up to how much water a year?',
          ['150 L', '1,500 L', '15,000 L', '150,000 L'], 2),
      QuizQuestion('Which of these is greywater?',
          ['Water from washing hands', 'Toilet water', 'Sea water', 'Rain on the roof'], 0),
    ],
    'MOD_F': [
      QuizQuestion('How much water does one cotton T-shirt take to make?',
          ['27 L', '270 L', '2,700 L', '27,000 L'], 2),
      QuizQuestion('Fast fashion is called "thirsty" because:',
          ['Clothes soak up water', 'Making it uses huge amounts of water', 'It is sold near rivers', 'It must be washed often'], 1),
      QuizQuestion('Your water footprint is:',
          ['The water you drink', 'Wet footprints on the floor', 'All the water used to make what you use', 'Your water bill'], 2),
      QuizQuestion('Which choice lowers your water footprint the most?',
          ['Buying fewer, longer-lasting clothes', 'Buying more sale items', 'Washing clothes daily', 'Using more plastic bags'], 0),
      QuizQuestion('Eco-packaging helps by:',
          ['Making gifts heavier', 'Reducing plastic waste', 'Costing more', 'Lasting forever'], 1),
      QuizQuestion('Which habit saves water at home?',
          ['Leaving the tap running while brushing', 'Turning the tap off while brushing', 'Long showers', 'Washing half loads'], 1),
    ],
  };

  static List<QuizQuestion> quizFor(String moduleId) => quizzes[moduleId] ?? quizzes['MOD_A']!;

  /// Q4 — the daily tip everyone sees (one broadcast, not one message per student).
  static const tips = <String>[
    'Fixing a leaky tap can save up to 15,000 litres of water a year.',
    'A bucket bath uses about 20 litres; a 10-minute shower can use 100.',
    'Turn the tap off while brushing — that alone saves about 6 litres a minute.',
    'Rinse vegetables in a bowl and use that water for plants.',
    'One full washing-machine load uses less water than two half loads.',
    'Rainwater from a single school roof can fill several classroom tanks each monsoon.',
    'Glass bottles can be recycled again and again without losing quality.',
    'Composting wet waste at school cuts what goes to the landfill by almost half.',
    'Carry a steel bottle: one person can avoid over 150 plastic bottles a year.',
    'Report overflowing tanks to your educator — a single overflow can waste hundreds of litres.',
  ];

  static String tipFor(DateTime day) {
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    return tips[dayOfYear % tips.length];
  }

  static const rewards = <Reward>[
    Reward(id: 'R1', name: 'Jute bag', points: 20, blurb: 'A sturdy bag to replace plastic carry bags.'),
    Reward(id: 'R2', name: 'Seed kit', points: 50, blurb: 'Native vegetable seeds for a school or home garden.'),
    Reward(id: 'R3', name: 'Potted plant', points: 100, blurb: 'A tulsi or curry-leaf sapling in a clay pot.'),
    Reward(id: 'R4', name: 'Steel bottle', points: 200, blurb: 'Leak-proof steel bottle — no more plastic.'),
    Reward(id: 'R5', name: 'Certificate', points: 300, blurb: 'A signed Water Guardian certificate from the NGO.'),
    Reward(id: 'R6', name: 'Tree planted in your name', points: 500, blurb: 'Planted on the Pondicherry University campus.'),
  ];

  static Reward reward(String id) => rewards.firstWhere((r) => r.id == id, orElse: () => rewards.first);

  static const gallery = <GalleryItem>[
    GalleryItem(id: 'G1', imageSeed: 'beach', title: 'Rock Beach clean-up',
        description: 'Volunteers and students keeping Rock Beach clean.'),
    GalleryItem(id: 'G2', imageSeed: 'workshop', title: 'Segregation workshop',
        description: 'Educators teaching the difference between dry and wet waste.'),
    GalleryItem(id: 'G3', imageSeed: 'trees', title: 'Tree plantation drive',
        description: 'Growing the green cover around partner schools.'),
    GalleryItem(id: 'G4', imageSeed: 'recycling', title: 'Plastic recycling centre',
        description: 'Collected plastic turned into reusable eco-bricks.'),
    GalleryItem(id: 'G5', imageSeed: 'community', title: 'Community awareness',
        description: 'Spreading the message of saving water across Pondicherry.'),
    GalleryItem(id: 'G6', imageSeed: 'ocean', title: 'Protecting the coast',
        description: 'Keeping plastic out of the Bay of Bengal.'),
  ];

  /// Items for the drag-and-drop sorting activity in module B.
  static const sortItems = <SortItem>[
    SortItem('Banana peel', BinColor.green, 'Food scraps rot naturally and make compost.'),
    SortItem('Vegetable peelings', BinColor.green, 'Kitchen scraps are wet, organic waste.'),
    SortItem('Used tea leaves', BinColor.green, 'Tea leaves compost quickly.'),
    SortItem('Old newspaper', BinColor.blue, 'Clean, dry paper can be pulped and recycled.'),
    SortItem('Plastic bottle', BinColor.blue, 'Rinsed bottles are dry recyclables.'),
    SortItem('Cardboard box', BinColor.blue, 'Flattened cardboard is recyclable.'),
    SortItem('Used battery', BinColor.red, 'Batteries leak toxic metals — hazardous.'),
    SortItem('Paint tin', BinColor.red, 'Paint residue is chemical, hazardous waste.'),
    SortItem('Broken tube light', BinColor.red, 'Tube lights contain mercury — hazardous.'),
    SortItem('Used bandage', BinColor.yellow, 'Anything with blood or fluids is medical waste.'),
    SortItem('Expired tablets', BinColor.yellow, 'Medicines must not reach water or soil.'),
    SortItem('Syringe', BinColor.yellow, 'Sharps are medical waste and need safe handling.'),
  ];
}
