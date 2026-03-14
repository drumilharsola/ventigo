/// 45 curated quotes for daily inspiration on the Home tab.
/// Selected deterministically by day-of-year so the quote changes daily
/// but remains consistent throughout the same day.
const List<String> dailyQuotes = [
  'You don\'t have to carry everything alone.',
  'Healing is not linear, and that\'s okay.',
  'Your feelings are valid - every single one of them.',
  'Sometimes the bravest thing you can do is ask for help.',
  'You are more than your worst day.',
  'It\'s okay to not be okay.',
  'Vulnerability is not weakness - it is courage.',
  'The only way out is through.',
  'You are allowed to take up space.',
  'Progress, not perfection.',
  'Rest is not a reward. It is a necessity.',
  'You are worthy of love and belonging.',
  'Speak your truth, even if your voice shakes.',
  'One day at a time. One breath at a time.',
  'Your story isn\'t over yet.',
  'Being heard is so close to being loved that most people can\'t tell the difference.',
  'What lies behind us and what lies before us are tiny matters compared to what lies within us.',
  'You don\'t have to see the whole staircase - just take the first step.',
  'The wound is the place where the light enters you.',
  'No feeling is final.',
  'You are not a burden. You are a human being.',
  'Courage doesn\'t always roar. Sometimes it\'s the quiet voice at the end of the day saying, "I will try again tomorrow."',
  'Stars can\'t shine without darkness.',
  'You were never meant to carry this alone.',
  'There is a crack in everything. That\'s how the light gets in.',
  'Feelings are just visitors. Let them come and go.',
  'Talking about our problems is our greatest addiction. Break the habit. Talk about your joys.',
  'Out of suffering have emerged the strongest souls.',
  'The greatest glory is not in never falling, but in rising every time we fall.',
  'Self-care is not selfish. It is necessary.',
  'You are braver than you believe, stronger than you seem, and smarter than you think.',
  'Every storm runs out of rain.',
  'You are enough. You have always been enough.',
  'Inhale courage, exhale fear.',
  'Your mental health is a priority. Your happiness is essential. Your self-care is a necessity.',
  'Sometimes you need to step outside, get some air, and remind yourself of who you are.',
  'What people think of you is none of your business.',
  'The sun will rise and we will try again.',
  'Be gentle with yourself. You\'re doing the best you can.',
  'You can\'t pour from an empty cup. Take care of yourself first.',
  'Not everything that weighs you down is yours to carry.',
  'Let go of who you think you should be and embrace who you are.',
  'Tomorrow is a new day with no mistakes in it yet.',
  'Difficult roads often lead to beautiful destinations.',
  'You survived every bad day so far. You\'re doing great.',
];

/// Returns the quote for today based on the day of the year.
String quoteOfTheDay() {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  return dailyQuotes[dayOfYear % dailyQuotes.length];
}
