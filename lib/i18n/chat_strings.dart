import 'strings.dart';

/// The chat screen's words, kept apart from `strings.dart` so the chat can be
/// added without touching the main dictionary.
///
/// Where the website already says something, the wording follows the
/// website's `chat.*` keys so a patient using both reads the same sentence.
class ChatStrings {
  const ChatStrings._();

  static const Map<String, Map<String, String>> _map = {
    'chat.title': {'en': 'Chat consultation', 'ur': 'چیٹ مشاورت'},
    'chat.messageDoctor': {'en': 'Message your doctor', 'ur': 'اپنے ڈاکٹر کو پیغام بھیجیں'},
    'chat.messagePatient': {'en': 'Message patient', 'ur': 'مریض کو پیغام بھیجیں'},
    'chat.you': {'en': 'You', 'ur': 'آپ'},
    'chat.clinic': {'en': 'TLC Med Clinics', 'ur': 'TLC میڈ کلینکس'},
    'chat.doctor': {'en': 'Doctor', 'ur': 'ڈاکٹر'},
    'chat.patient': {'en': 'Patient', 'ur': 'مریض'},
    'chat.encrypted': {
      'en': 'Messages are encrypted and read only by you, your doctor and the clinic. '
          'This chat is not for emergencies — if you or someone else is in danger, '
          'call 1122 or go to the nearest emergency room.',
      'ur': 'پیغامات خفیہ کردہ ہیں اور صرف آپ، آپ کا ڈاکٹر اور کلینک انہیں پڑھ سکتے ہیں۔ '
          'یہ چیٹ ہنگامی حالت کے لیے نہیں ہے — اگر آپ یا کوئی اور خطرے میں ہو تو '
          '1122 پر کال کریں یا قریبی ایمرجنسی میں جائیں۔',
    },
    'chat.unlocking': {'en': 'Unlocking secure conversation…', 'ur': 'محفوظ گفتگو کھولی جا رہی ہے…'},
    'chat.empty': {'en': 'No messages yet — say hello', 'ur': 'ابھی کوئی پیغام نہیں — سلام کہہ کر شروع کریں'},
    'chat.emptySub': {
      'en': 'Your doctor will see your message here.',
      'ur': 'آپ کا پیغام یہیں دکھائی دے گا۔',
    },
    'chat.placeholder': {'en': 'Type a message…', 'ur': 'پیغام لکھیں…'},
    'chat.send': {'en': 'Send', 'ur': 'بھیجیں'},
    'chat.loadError': {
      'en': "Couldn't load chat messages. Check your connection and try again.",
      'ur': 'پیغامات لوڈ نہیں ہو سکے۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔',
    },
    'chat.keyError': {
      'en': "Couldn't open this secure conversation.",
      'ur': 'یہ محفوظ گفتگو نہیں کھل سکی۔',
    },
    'chat.sendError': {
      'en': "Message couldn't be sent. Please try again.",
      'ur': 'پیغام نہیں بھیجا جا سکا۔ دوبارہ کوشش کریں۔',
    },
    'chat.undecryptable': {
      'en': '[Unable to decrypt this message]',
      'ur': '[یہ پیغام کھولا نہیں جا سکا]',
    },
    'chat.retry': {'en': 'Try again', 'ur': 'دوبارہ کوشش کریں'},
    'chat.jumpToLatest': {'en': 'Latest', 'ur': 'تازہ ترین'},
    'chat.sending': {'en': 'Sending…', 'ur': 'بھیجا جا رہا ہے…'},

    // Why the chat is closed. Shown on the appointment and inside the screen.
    'chat.closed.notChat': {
      'en': 'Chat is only available for chat consultations.',
      'ur': 'چیٹ صرف چیٹ مشاورت کے لیے دستیاب ہے۔',
    },
    'chat.closed.noDoctor': {
      'en': 'Chat opens once a doctor is assigned to this appointment.',
      'ur': 'ڈاکٹر مقرر ہونے کے بعد چیٹ کھلے گی۔',
    },
    'chat.closed.notConfirmed': {
      'en': 'Chat opens once this appointment is confirmed.',
      'ur': 'اپائنٹمنٹ کی تصدیق ہونے کے بعد چیٹ کھلے گی۔',
    },
    'chat.closed.notYet': {
      'en': 'Chat opens at your appointment time. The clinic can open it early if needed.',
      'ur': 'چیٹ آپ کی اپائنٹمنٹ کے وقت کھلے گی۔ ضرورت ہو تو کلینک اسے پہلے بھی کھول سکتا ہے۔',
    },
    'chat.closed.ended': {
      'en': 'This session has ended.',
      'ur': 'یہ نشست ختم ہو چکی ہے۔',
    },
  };

  /// English when the key has no Urdu, and the key itself if it is missing
  /// altogether — never an exception in the middle of a build.
  static String t(String key) {
    final entry = _map[key];
    if (entry == null) return key;
    if (LocaleController.urdu) return entry['ur'] ?? entry['en'] ?? key;
    return entry['en'] ?? key;
  }
}
