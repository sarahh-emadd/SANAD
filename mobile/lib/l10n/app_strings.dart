// lib/l10n/app_strings.dart
//
// Manual bilingual string table — no code generation needed.
// Usage:  S.of(context).home  or  S.of(context).pillsTaken

import 'package:flutter/material.dart';

// ── String table ────────────────────────────────────────────────────────────
const Map<String, Map<String, String>> _t = {
  'en': {
    // General
    'appName':          'Sanad',
    'home':             'Home',
    'alerts':           'Alerts',
    'settings':         'Settings',
    'save':             'Save',
    'cancel':           'Cancel',
    'edit':             'Edit',
    'add':              'Add',
    'delete':           'Delete',
    'confirm':          'Confirm',
    'loading':          'Loading…',
    'refresh':          'Refresh',
    'noData':           'No data yet',
    'retry':            'Retry',

    // Elder home
    'goodMorning':      'Good morning',
    'myMeds':           'My Medications',
    'medsTaken':        'Doses taken today',
    'recentAlerts':     'Recent Alerts',
    'viewAll':          'View all',
    'sendMessage':      'Send a quick message',
    'messageSent':      'Message sent ✓',

    // Preset messages
    'msg_im_okay':       "I'm okay 😊",
    'msg_need_medicine': "I need my medicine 💊",
    'msg_hungry':        "I'm hungry 🍽️",
    'msg_tired':         "I'm tired 😴",
    'msg_not_well':      "I don't feel well 🤒",

    // Caregiver home
    'adherence':        'Adherence',
    'todayPills':       "Today's Pills",
    'pillsTaken':       'Taken',
    'pillsMissed':      'Missed',
    'pillsDue':         'Due soon',
    'falls':            'Falls',
    'activity':         'Activity',

    // Manage pills
    'managePills':      'Manage Pills',
    'slot':             'Slot',
    'addSchedule':      'Add Schedule',
    'editSchedule':     'Edit Schedule',
    'scheduleTime':     'Time',
    'startDate':        'Start Date',
    'endDate':          'End Date (optional)',
    'noEndDate':        'Ongoing (no end date)',
    'medicationLabel':  'Label',
    'refillAlert':      'Refill needed — slot running low',
    'slotEmpty':        'No schedule',

    // Notifications
    'noAlerts':         'No alerts yet',
    'sosAlert':         'SOS Alert',
    'fallDetected':     'Fall Detected',
    'inactivityAlert':  'Inactivity Alert',
    'sleepingAlert':    'Sleeping Alert',
    'missedDose':       'Missed Dose',
    'doseTaken':        'Dose Taken',
    'presenceMessage':  'Quick Message',

    // Dashboard
    'weeklyAdherence':  'Weekly Adherence',
    'weeklyReport':     'Weekly Report',
    'downloadReport':   'Download Report',
    'generating':       'Generating PDF…',
    'reportReady':      'Report ready',

    // Settings
    'language':         'Language',
    'english':          'English',
    'arabic':           'Arabic',
    'textSize':         'Text Size',
    'small':            'Small',
    'medium':           'Medium',
    'large':            'Large',
    'volume':           'Volume',
    'notifications':    'Notifications',
  },

  'ar': {
    // General
    'appName':          'سند',
    'home':             'الرئيسية',
    'alerts':           'التنبيهات',
    'settings':         'الإعدادات',
    'save':             'حفظ',
    'cancel':           'إلغاء',
    'edit':             'تعديل',
    'add':              'إضافة',
    'delete':           'حذف',
    'confirm':          'تأكيد',
    'loading':          'جارٍ التحميل…',
    'refresh':          'تحديث',
    'noData':           'لا توجد بيانات بعد',
    'retry':            'إعادة المحاولة',

    // Elder home
    'goodMorning':      'صباح الخير',
    'myMeds':           'أدويتي',
    'medsTaken':        'الجرعات المأخوذة اليوم',
    'recentAlerts':     'التنبيهات الأخيرة',
    'viewAll':          'عرض الكل',
    'sendMessage':      'أرسل رسالة سريعة',
    'messageSent':      'تم إرسال الرسالة ✓',

    // Preset messages
    'msg_im_okay':       'أنا بخير 😊',
    'msg_need_medicine': 'أحتاج دوائي 💊',
    'msg_hungry':        'أنا جائع 🍽️',
    'msg_tired':         'أنا متعب 😴',
    'msg_not_well':      'لا أشعر بتحسن 🤒',

    // Caregiver home
    'adherence':        'الالتزام',
    'todayPills':       'أدوية اليوم',
    'pillsTaken':       'مأخوذة',
    'pillsMissed':      'فائتة',
    'pillsDue':         'موعدها قريب',
    'falls':            'السقطات',
    'activity':         'النشاط',

    // Manage pills
    'managePills':      'إدارة الأدوية',
    'slot':             'خانة',
    'addSchedule':      'إضافة جدول',
    'editSchedule':     'تعديل الجدول',
    'scheduleTime':     'الوقت',
    'startDate':        'تاريخ البداية',
    'endDate':          'تاريخ الانتهاء (اختياري)',
    'noEndDate':        'مستمر (بدون تاريخ انتهاء)',
    'medicationLabel':  'الوصف',
    'refillAlert':      'يلزم إعادة تعبئة الخانة',
    'slotEmpty':        'لا يوجد جدول',

    // Notifications
    'noAlerts':         'لا توجد تنبيهات بعد',
    'sosAlert':         'تنبيه استغاثة',
    'fallDetected':     'تم اكتشاف سقطة',
    'inactivityAlert':  'تنبيه عدم النشاط',
    'sleepingAlert':    'تنبيه النوم',
    'missedDose':       'جرعة فائتة',
    'doseTaken':        'جرعة مأخوذة',
    'presenceMessage':  'رسالة سريعة',

    // Dashboard
    'weeklyAdherence':  'الالتزام الأسبوعي',
    'weeklyReport':     'التقرير الأسبوعي',
    'downloadReport':   'تنزيل التقرير',
    'generating':       'جارٍ إنشاء ملف PDF…',
    'reportReady':      'التقرير جاهز',

    // Settings
    'language':         'اللغة',
    'english':          'English',
    'arabic':           'العربية',
    'textSize':         'حجم الخط',
    'small':            'صغير',
    'medium':           'متوسط',
    'large':            'كبير',
    'volume':           'الصوت',
    'notifications':    'الإشعارات',
  },
};

// ── Accessor ────────────────────────────────────────────────────────────────
class S {
  final String _lang;
  const S._(this._lang);

  static S of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return S._((_t.containsKey(code)) ? code : 'en');
  }

  /// Returns the translated string for [key], falls back to English.
  String get(String key) =>
      _t[_lang]?[key] ?? _t['en']?[key] ?? key;

  // ── Shortcuts (the most-used keys) ──────────────────────────────────────
  String get appName          => get('appName');
  String get home             => get('home');
  String get alerts           => get('alerts');
  String get settings         => get('settings');
  String get save             => get('save');
  String get cancel           => get('cancel');
  String get edit             => get('edit');
  String get add              => get('add');
  String get loading          => get('loading');
  String get refresh          => get('refresh');
  String get noData           => get('noData');

  // Elder home
  String get goodMorning      => get('goodMorning');
  String get myMeds           => get('myMeds');
  String get medsTaken        => get('medsTaken');
  String get recentAlerts     => get('recentAlerts');
  String get viewAll          => get('viewAll');
  String get sendMessage      => get('sendMessage');
  String get messageSent      => get('messageSent');

  // Preset messages
  String get msgImOkay        => get('msg_im_okay');
  String get msgNeedMedicine  => get('msg_need_medicine');
  String get msgHungry        => get('msg_hungry');
  String get msgTired         => get('msg_tired');
  String get msgNotWell       => get('msg_not_well');

  // Caregiver
  String get adherence        => get('adherence');
  String get todayPills       => get('todayPills');
  String get pillsTaken       => get('pillsTaken');
  String get pillsMissed      => get('pillsMissed');
  String get pillsDue         => get('pillsDue');
  String get falls            => get('falls');
  String get activity         => get('activity');

  // Manage pills
  String get managePills      => get('managePills');
  String get slot             => get('slot');
  String get addSchedule      => get('addSchedule');
  String get editSchedule     => get('editSchedule');
  String get scheduleTime     => get('scheduleTime');
  String get startDate        => get('startDate');
  String get endDate          => get('endDate');
  String get noEndDate        => get('noEndDate');
  String get refillAlert      => get('refillAlert');
  String get slotEmpty        => get('slotEmpty');

  // Notifications
  String get noAlerts         => get('noAlerts');
  String get sosAlert         => get('sosAlert');
  String get fallDetected     => get('fallDetected');
  String get inactivityAlert  => get('inactivityAlert');
  String get sleepingAlert    => get('sleepingAlert');
  String get missedDose       => get('missedDose');
  String get doseTaken        => get('doseTaken');
  String get presenceMessage  => get('presenceMessage');

  // Dashboard / Reports
  String get weeklyAdherence  => get('weeklyAdherence');
  String get weeklyReport     => get('weeklyReport');
  String get downloadReport   => get('downloadReport');
  String get generating       => get('generating');
  String get reportReady      => get('reportReady');

  // Settings
  String get language         => get('language');
  String get english          => get('english');
  String get arabic           => get('arabic');
  String get textSize         => get('textSize');
  String get small            => get('small');
  String get medium           => get('medium');
  String get large            => get('large');
  String get volume           => get('volume');
  String get notifications    => get('notifications');
}
