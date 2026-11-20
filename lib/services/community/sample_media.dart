/// Photos and videos for the sample community posts.
///
/// Every file is bundled with the app (nothing is fetched at run time), is
/// openly licensed (Creative Commons or public domain, from Wikimedia
/// Commons), and is used by exactly one sample post. The credit string is
/// shown with the media. Sample media is demonstration content only: it is
/// never attached to a real user's post or sent to any server.
class SampleMediaItem {
  /// Bundled photo paths. For a video post this is its poster frame.
  final List<String> images;

  /// Bundled video path, or null for a photo-only post.
  final String? videoAsset;

  /// Short name of the video, for the player title.
  final String? videoLabel;

  /// Attribution for the media.
  final String credit;

  const SampleMediaItem({
    required this.images,
    required this.credit,
    this.videoAsset,
    this.videoLabel,
  });
}

class SampleMedia {
  const SampleMedia._();

  static SampleMediaItem? forPost(String postId) => _byPost[postId];

  /// All media items, keyed by sample post id.
  static Map<String, SampleMediaItem> get all => _byPost;

  static const Map<String, SampleMediaItem> _byPost = {
    "sp_alex_1": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_1_poster.jpg"],
      videoAsset: "assets/community/videos/deadlift.mp4",
      videoLabel: "Deadlift demonstration",
      credit:
          "\"Deadlift - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_alex_2": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"GymNation gym interior 2024\" by GymNation, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_alex_3": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_3.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Ham and scrambled eggs\" by stu_spivack, CC BY-SA 2.0, via Wikimedia Commons",
    ),
    "sp_alex_4": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_4.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"US Air Force (USAF) Lieutenant (LT) Jason Wood, Physical Training Leader (PTL), 347th Communications Squadron (CS), Moody Air Force Base (AFB), Georgia (GA), measures the waist of a - DPLA - cf4b437ae7a07ff4e2f83e8647b3c22b\" by Department of Defense. American Forces Information Service. Defense Vi, Public domain, via Wikimedia Commons",
    ),
    "sp_alex_5": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_5.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Bench Press\" by Aditya Oberai, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_alex_6": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_6.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit: "\"Bench press\" by SAgbley, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_alex_7": SampleMediaItem(
      images: ["assets/community/photos/sp_alex_7.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Josh's Squat\" by Mission Essentials, LLC, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_coach_zuala_1": SampleMediaItem(
      images: ["assets/community/photos/sp_coach_zuala_1_poster.jpg"],
      videoAsset: "assets/community/videos/squat.mp4",
      videoLabel: "Squat demonstration",
      credit:
          "\"Squat - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_coach_zuala_3": SampleMediaItem(
      images: ["assets/community/photos/sp_coach_zuala_3.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Alessio Pavone squat European Championships\" by FactNoter, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_coach_zuala_6": SampleMediaItem(
      images: ["assets/community/photos/sp_coach_zuala_6.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Nepali dal-bhat-tarkari\" by Subhashish Panigrahi, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_daniel_1": SampleMediaItem(
      images: ["assets/community/photos/sp_daniel_1_poster.jpg"],
      videoAsset: "assets/community/videos/bench_press.mp4",
      videoLabel: "Bench press demonstration",
      credit:
          "\"Bench press - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_daniel_2": SampleMediaItem(
      images: ["assets/community/photos/sp_daniel_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Marines' voices echo, prompt new gym hours 150927-M-AI083-067\" by Lance Cpl. Jason Jimenez, Public domain, via Wikimedia Commons",
    ),
    "sp_daniel_3": SampleMediaItem(
      images: ["assets/community/photos/sp_daniel_3_poster.jpg"],
      videoAsset: "assets/community/videos/incline_press.mp4",
      videoLabel: "Incline press demonstration",
      credit:
          "\"Incline press - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_daniel_4": SampleMediaItem(
      images: ["assets/community/photos/sp_daniel_4.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Tuna Salad with sweet corn\" by Adesolive, CC0, via Wikimedia Commons",
    ),
    "sp_david_4": SampleMediaItem(
      images: ["assets/community/photos/sp_david_4.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Healthy Breakfast (Unsplash)\" by Federica Diliberto federyka, CC0, via Wikimedia Commons",
    ),
    "sp_david_5": SampleMediaItem(
      images: ["assets/community/photos/sp_david_5_poster.jpg"],
      videoAsset: "assets/community/videos/bent_over_row.mp4",
      videoLabel: "Bent-over row demonstration",
      credit:
          "\"Bent-over row - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_hminga_2": SampleMediaItem(
      images: ["assets/community/photos/sp_hminga_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Trail Running (5603859661)\" by Virginia State Parks staff, CC BY 2.0, via Wikimedia Commons",
    ),
    "sp_hminga_3": SampleMediaItem(
      images: ["assets/community/photos/sp_hminga_3.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"During football match 01\" by Francis ackson soko, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_hminga_5": SampleMediaItem(
      images: ["assets/community/photos/sp_hminga_5_poster.jpg"],
      videoAsset: "assets/community/videos/skipping.mp4",
      videoLabel: "Skipping rope",
      credit:
          "\"Skipping Man - Play and Africa\" by Arch-Angel Raphael the Artist, CC BY-SA 4.0, via Wikimedia Commons (trimmed and cropped)",
    ),
    "sp_hminga_6": SampleMediaItem(
      images: ["assets/community/photos/sp_hminga_6_poster.jpg"],
      videoAsset: "assets/community/videos/chicken_rice.mp4",
      videoLabel: "Cooking chicken and rice",
      credit:
          "\"Cooking Chicken and Rice\" by Alabama Extension, CC0, via Wikimedia Commons (trimmed)",
    ),
    "sp_jenny_1": SampleMediaItem(
      images: ["assets/community/photos/sp_jenny_1_poster.jpg"],
      videoAsset: "assets/community/videos/salad_prep.mp4",
      videoLabel: "Salad prep",
      credit:
          "\"Fresh mixed salad and fridge-ready prep\" by Umabruka, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_jenny_2": SampleMediaItem(
      images: ["assets/community/photos/sp_jenny_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Fitness digital scale weight loss\" by franchise opportunities, CC BY-SA 2.0, via Wikimedia Commons",
    ),
    "sp_jenny_3": SampleMediaItem(
      images: ["assets/community/photos/sp_jenny_3_poster.jpg"],
      videoAsset: "assets/community/videos/burpee.mp4",
      videoLabel: "Burpee",
      credit:
          "\"CrossFit Burpee\" by Taco fleur, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_jenny_5": SampleMediaItem(
      images: ["assets/community/photos/sp_jenny_5.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Protein shake\" by Sandstein, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_jenny_6": SampleMediaItem(
      images: ["assets/community/photos/sp_jenny_6.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"170331-N-ZY039-015 (33869515046)\" by National Museum of the U.S. Navy, Public domain, via Wikimedia Commons",
    ),
    "sp_liam_1": SampleMediaItem(
      images: ["assets/community/photos/sp_liam_1.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Man performs push-ups in a gym during a fitness session in the early evening\" by Shixart1985, CC BY 2.0, via Wikimedia Commons",
    ),
    "sp_liam_2": SampleMediaItem(
      images: ["assets/community/photos/sp_liam_2_poster.jpg"],
      videoAsset: "assets/community/videos/shoulder_press.mp4",
      videoLabel: "Shoulder press demonstration",
      credit:
          "\"Shoulder press - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_liam_4": SampleMediaItem(
      images: ["assets/community/photos/sp_liam_4.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Stir fried Vegetable Tofu broken with rice for dinner\" by Pradeepraajkumar1981, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_liam_5": SampleMediaItem(
      images: ["assets/community/photos/sp_liam_5.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Nago celebrates 52nd annual Cherry Blossom Festival 140125-M-ZH183-042\" by Cpl. Natalie Rostran, Public domain, via Wikimedia Commons",
    ),
    "sp_marcus_1": SampleMediaItem(
      images: ["assets/community/photos/sp_marcus_1.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Workout Srodula Sosnowiec regulamin\" by Stimoroll, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_marcus_2": SampleMediaItem(
      images: ["assets/community/photos/sp_marcus_2_poster.jpg"],
      videoAsset: "assets/community/videos/outdoor_gym.mp4",
      videoLabel: "Park pull-ups and dips",
      credit:
          "\"Video of a free open outdoor gym - Wadala Five Garden nearby Mumbai\" by Jay Palav, CC BY 3.0, via Wikimedia Commons (trimmed)",
    ),
    "sp_marcus_3": SampleMediaItem(
      images: ["assets/community/photos/sp_marcus_3.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Calisthenics in Berlin-Marzahn (Marzahner Promenade) Klimmzugstangen und Barren\" by Singlespeedfahrer, CC0, via Wikimedia Commons",
    ),
    "sp_marcus_4": SampleMediaItem(
      images: ["assets/community/photos/sp_marcus_4_poster.jpg"],
      videoAsset: "assets/community/videos/pull_ups.mp4",
      videoLabel: "Pull-ups demonstration",
      credit:
          "\"Pull-ups - exercise demonstration video\" by FitnessScape, CC BY 3.0, via Wikimedia Commons",
    ),
    "sp_marcus_5": SampleMediaItem(
      images: ["assets/community/photos/sp_marcus_5.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Calisthenics Poststadion Berlin 2v5\" by Singlespeedfahrer, CC0, via Wikimedia Commons",
    ),
    "sp_marcus_6": SampleMediaItem(
      images: ["assets/community/photos/sp_marcus_6.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Healthy Breakfast 1 (Unsplash)\" by Carissa Gan carissagan, CC0, via Wikimedia Commons",
    ),
    "sp_maya_1": SampleMediaItem(
      images: ["assets/community/photos/sp_maya_1_poster.jpg"],
      videoAsset: "assets/community/videos/back_squat.mp4",
      videoLabel: "Barbell back squat",
      credit:
          "\"Barbell back squat exercise demonstration\" by Your Move, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_maya_2": SampleMediaItem(
      images: ["assets/community/photos/sp_maya_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"MCAS Iwakuni Women’s Power Lifting (9352356)\" by U.S. Marine Corps photo by Lance Cpl. Siwan Lewis, Public domain, via Wikimedia Commons",
    ),
    "sp_maya_4": SampleMediaItem(
      images: ["assets/community/photos/sp_maya_4.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Stir-fry spinach with tofu - Golden white jade and Green Parrot (菠菜炒豆腐 - 金鑲白玉板，紅嘴綠鸚哥)(1)\" by NeoBatfreak, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_sophia_2": SampleMediaItem(
      images: ["assets/community/photos/sp_sophia_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Woman doing squat workout in gym with barbell, back view\" by Nenad Stojkovic, CC BY 2.0, via Wikimedia Commons",
    ),
    "sp_sophia_4": SampleMediaItem(
      images: ["assets/community/photos/sp_sophia_4_poster.jpg"],
      videoAsset: "assets/community/videos/rice_cooking.mp4",
      videoLabel: "Cooking rice",
      credit:
          "\"Rice Cooking on a gas stove\" by Shraddhahistory, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_zothanpuii_1": SampleMediaItem(
      images: ["assets/community/photos/sp_zothanpuii_1.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Trail running moscow\" by ValeryGL, CC BY-SA 4.0, via Wikimedia Commons",
    ),
    "sp_zothanpuii_2": SampleMediaItem(
      images: ["assets/community/photos/sp_zothanpuii_2.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Seattle - Garfield High School track 01\" by Joe Mabel, CC BY-SA 3.0, via Wikimedia Commons",
    ),
    "sp_zothanpuii_3": SampleMediaItem(
      images: ["assets/community/photos/sp_zothanpuii_3.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Velká kunratická 2nd hill, Prague\" by Czech Wikipedia user Packa, CC BY-SA 2.5, via Wikimedia Commons",
    ),
    "sp_zothanpuii_4": SampleMediaItem(
      images: ["assets/community/photos/sp_zothanpuii_4.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"OK Foundry Kettlebells (13913670054)\" by OKFoundryCompany from Richmond, USA, CC BY 2.0, via Wikimedia Commons",
    ),
    "sp_zothanpuii_5": SampleMediaItem(
      images: ["assets/community/photos/sp_zothanpuii_5.jpg"],
      videoAsset: null,
      videoLabel: null,
      credit:
          "\"Rice with Lentils\" by Mrsagar105, CC BY-SA 4.0, via Wikimedia Commons",
    ),
  };
}
