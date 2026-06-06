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
    'today':            'Today',
    'history':          'History',
    'manage':           'Manage',
    'viewAlerts':       'View Alerts',
    'allHistory':       'All History',
    'ok':               'OK',

    // Elder home
    'goodMorning':      'Good morning',
    'sanadWith':        'Your Sanad is with you 💚',
    'myMeds':           "Today's Medications",
    'medsTaken':        'Doses taken today',
    'recentAlerts':     'Recent Alerts',
    'viewAll':          'View all',
    'sendMessage':      'Quick Message',
    'tapToSend':        'Tap to send a message to your caregiver:',
    'messageSent':      'Message sent ✓',
    'noMedsToday':      'No medications scheduled today',
    'noAlertsToday':    'No alerts today',
    'noMessages':       'No messages yet',
    'pillBoxAlerts':    'Pill Box Alerts',
    'messages':         'Messages',

    // Slot status labels
    'taken':            'Taken',
    'missed':           'Missed',
    'dueSoon':          'Due Soon',
    'scheduled':        'Scheduled',

    // Preset messages
    'msg_im_okay':       "I'm okay 😊",
    'msg_need_medicine': "I need my medicine 💊",
    'msg_hungry':        "I'm hungry 🍽️",
    'msg_tired':         "I'm tired 😴",
    'msg_not_well':      "I don't feel well 🤒",

    // Caregiver home
    'adherence':            'Medication Adherence',
    'adherenceShort':       'Adherence',
    'todayPills':           "Today's Pills",
    'pillsTaken':           'Taken',
    'pillsMissed':          'Missed',
    'pillsDue':             'Due Soon',
    'falls':                'Falls',
    'fallsToday':           'Falls Today',
    'activity':             'Activity',
    'activityLevel':        'Activity Level',
    'cameraMonitoring':     'Camera Monitoring',
    'notifications':        'Notifications',
    'elderStatus':          'Elder Status',
    'online':               'Online',
    'offline':              'Offline',
    'lastSeen':             'Last seen',
    'noPillsToday':         'No pills scheduled today',

    // Manage pills
    'managePills':      'Manage Pills',
    'slot':             'Slot',
    'addSchedule':      'Add Schedule',
    'editSchedule':     'Edit Schedule',
    'saveChanges':      'Save Changes',
    'scheduleTime':     'Time',
    'startDate':        'Start Date',
    'endDate':          'End Date (optional)',
    'noEndDate':        'Ongoing (no end date)',
    'medicationLabel':  'Label',
    'refillAlert':      'Refill needed — check pill count',
    'slotEmpty':        'No schedule',
    'noScheduleYet':    'No schedules yet. Tap Add to set a time.',
    'removeSchedule':   'Remove Schedule',
    'active':           'Active',
    'inactive':         'Inactive',

    // Notifications / Alerts
    'noAlerts':         'No alerts yet',
    'alertsFromAI':     'Alerts from AI detection will appear here',
    'sosAlert':         'SOS Alert',
    'fallDetected':     'Fall Detected',
    'inactivityAlert':  'Inactivity Alert',
    'sleepingAlert':    'Sleeping Alert',
    'nightRestless':    'Night Restlessness',
    'missedDose':       'Missed Dose',
    'doseTaken':        'Dose Taken',
    'presenceMessage':  'Quick Message',

    // Dashboard
    'dashboard':        'Dashboard',
    'weeklyAdherence':  'Weekly Adherence',
    'weeklyReport':     'Weekly Report',
    'downloadReport':   'Download Weekly Report',
    'generating':       'Generating PDF…',
    'reportReady':      'Report ready',
    'noLogsYet':        'No pill logs yet',

    // Settings
    'language':         'Language',
    'english':          'English',
    'arabic':           'Arabic',
    'textSize':         'Text Size',
    'small':            'Small',
    'medium':           'Medium',
    'large':            'Large Mode',
    'volume':           'Volume',

    // SOS
    'sendSos':          'Send SOS?',
    'sosConfirmBody':   'This will immediately alert your caregiver.',
    'helpOnWay':        'Help is on the way!',
    'helpOnWayBody':    'Your caregiver has been notified and is coming to help you.',
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
    'today':            'اليوم',
    'history':          'السجل',
    'manage':           'إدارة',
    'viewAlerts':       'عرض التنبيهات',
    'allHistory':       'كل السجل',
    'ok':               'حسناً',

    // Elder home
    'goodMorning':      'صباح الخير',
    'sanadWith':        'سندك معك 💚',
    'myMeds':           'أدوية اليوم',
    'medsTaken':        'الجرعات المأخوذة اليوم',
    'recentAlerts':     'التنبيهات الأخيرة',
    'viewAll':          'عرض الكل',
    'sendMessage':      'رسالة سريعة',
    'tapToSend':        'اضغط لإرسال رسالة لمقدم الرعاية:',
    'messageSent':      'تم إرسال الرسالة ✓',
    'noMedsToday':      'لا توجد أدوية مجدولة اليوم',
    'noAlertsToday':    'لا توجد تنبيهات اليوم',
    'noMessages':       'لا توجد رسائل بعد',
    'pillBoxAlerts':    'تنبيهات صندوق الدواء',
    'messages':         'الرسائل',

    // Slot status labels
    'taken':            'تم أخذه',
    'missed':           'فائتة',
    'dueSoon':          'موعده قريب',
    'scheduled':        'مجدولة',

    // Preset messages
    'msg_im_okay':       'أنا بخير 😊',
    'msg_need_medicine': 'أحتاج دوائي 💊',
    'msg_hungry':        'أنا جائع 🍽️',
    'msg_tired':         'أنا متعب 😴',
    'msg_not_well':      'لا أشعر بتحسن 🤒',

    // Caregiver home
    'adherence':            'الالتزام بالدواء',
    'adherenceShort':       'الالتزام',
    'todayPills':           'أدوية اليوم',
    'pillsTaken':           'مأخوذة',
    'pillsMissed':          'فائتة',
    'pillsDue':             'موعدها قريب',
    'falls':                'السقطات',
    'fallsToday':           'السقطات اليوم',
    'activity':             'النشاط',
    'activityLevel':        'مستوى النشاط',
    'cameraMonitoring':     'مراقبة الكاميرا',
    'notifications':        'الإشعارات',
    'elderStatus':          'حالة المسن',
    'online':               'متصل',
    'offline':              'غير متصل',
    'lastSeen':             'آخر ظهور',
    'noPillsToday':         'لا توجد أدوية مجدولة اليوم',

    // Manage pills
    'managePills':      'إدارة الأدوية',
    'slot':             'خانة',
    'addSchedule':      'إضافة جدول',
    'editSchedule':     'تعديل الجدول',
    'saveChanges':      'حفظ التغييرات',
    'scheduleTime':     'الوقت',
    'startDate':        'تاريخ البداية',
    'endDate':          'تاريخ الانتهاء (اختياري)',
    'noEndDate':        'مستمر (بدون تاريخ انتهاء)',
    'medicationLabel':  'الوصف',
    'refillAlert':      'يلزم إعادة التعبئة — تحقق من عدد الحبوب',
    'slotEmpty':        'لا يوجد جدول',
    'noScheduleYet':    'لا توجد جداول بعد. اضغط إضافة لتحديد وقت.',
    'removeSchedule':   'إزالة الجدول',
    'active':           'نشط',
    'inactive':         'غير نشط',

    // Notifications / Alerts
    'noAlerts':         'لا توجد تنبيهات بعد',
    'alertsFromAI':     'ستظهر هنا التنبيهات من الكشف الذكي',
    'sosAlert':         'تنبيه استغاثة',
    'fallDetected':     'تم اكتشاف سقطة',
    'inactivityAlert':  'تنبيه عدم النشاط',
    'sleepingAlert':    'تنبيه النوم',
    'nightRestless':    'اضطراب النوم الليلي',
    'missedDose':       'جرعة فائتة',
    'doseTaken':        'جرعة مأخوذة',
    'presenceMessage':  'رسالة سريعة',

    // Dashboard
    'dashboard':        'لوحة التحكم',
    'weeklyAdherence':  'الالتزام الأسبوعي',
    'weeklyReport':     'التقرير الأسبوعي',
    'downloadReport':   'تنزيل التقرير الأسبوعي',
    'generating':       'جارٍ إنشاء ملف PDF…',
    'reportReady':      'التقرير جاهز',
    'noLogsYet':        'لا توجد سجلات أدوية بعد',

    // Settings
    'language':         'اللغة',
    'english':          'English',
    'arabic':           'العربية',
    'textSize':         'حجم الخط',
    'small':            'صغير',
    'medium':           'متوسط',
    'large':            'كبير',
    'volume':           'الصوت',

    // SOS
    'sendSos':          'إرسال استغاثة؟',
    'sosConfirmBody':   'سيتم تنبيه مقدم الرعاية فوراً.',
    'helpOnWay':        'المساعدة في الطريق!',
    'helpOnWayBody':    'تم إشعار مقدم الرعاية وهو قادم لمساعدتك.',
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

  // ── Shortcuts ────────────────────────────────────────────────────────────
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
  String get today            => get('today');
  String get history          => get('history');
  String get manage           => get('manage');
  String get ok               => get('ok');
  String get allHistory       => get('allHistory');
  String get viewAlerts       => get('viewAlerts');

  // Elder home
  String get goodMorning      => get('goodMorning');
  String get sanadWith        => get('sanadWith');
  String get myMeds           => get('myMeds');
  String get medsTaken        => get('medsTaken');
  String get recentAlerts     => get('recentAlerts');
  String get viewAll          => get('viewAll');
  String get sendMessage      => get('sendMessage');
  String get tapToSend        => get('tapToSend');
  String get messageSent      => get('messageSent');
  String get noMedsToday      => get('noMedsToday');
  String get noAlertsToday    => get('noAlertsToday');
  String get noMessages       => get('noMessages');
  String get pillBoxAlerts    => get('pillBoxAlerts');
  String get messages         => get('messages');

  // Slot statuses
  String get taken            => get('taken');
  String get missed           => get('missed');
  String get dueSoon          => get('dueSoon');
  String get scheduled        => get('scheduled');

  // Preset messages
  String get msgImOkay        => get('msg_im_okay');
  String get msgNeedMedicine  => get('msg_need_medicine');
  String get msgHungry        => get('msg_hungry');
  String get msgTired         => get('msg_tired');
  String get msgNotWell       => get('msg_not_well');

  // Caregiver home
  String get adherence        => get('adherence');
  String get adherenceShort   => get('adherenceShort');
  String get todayPills       => get('todayPills');
  String get pillsTaken       => get('pillsTaken');
  String get pillsMissed      => get('pillsMissed');
  String get pillsDue         => get('pillsDue');
  String get falls            => get('falls');
  String get fallsToday       => get('fallsToday');
  String get activity         => get('activity');
  String get activityLevel    => get('activityLevel');
  String get cameraMonitoring => get('cameraMonitoring');
  String get notifications    => get('notifications');
  String get elderStatus      => get('elderStatus');
  String get online           => get('online');
  String get offline          => get('offline');
  String get lastSeen         => get('lastSeen');
  String get noPillsToday     => get('noPillsToday');

  // Manage pills
  String get managePills      => get('managePills');
  String get slot             => get('slot');
  String get addSchedule      => get('addSchedule');
  String get editSchedule     => get('editSchedule');
  String get saveChanges      => get('saveChanges');
  String get refillAlert      => get('refillAlert');
  String get slotEmpty        => get('slotEmpty');
  String get noScheduleYet    => get('noScheduleYet');
  String get removeSchedule   => get('removeSchedule');
  String get active           => get('active');
  String get inactive         => get('inactive');

  // Notifications
  String get noAlerts         => get('noAlerts');
  String get alertsFromAI     => get('alertsFromAI');
  String get sosAlert         => get('sosAlert');
  String get fallDetected     => get('fallDetected');
  String get inactivityAlert  => get('inactivityAlert');
  String get sleepingAlert    => get('sleepingAlert');
  String get nightRestless    => get('nightRestless');
  String get missedDose       => get('missedDose');
  String get doseTaken        => get('doseTaken');
  String get presenceMessage  => get('presenceMessage');

  // Dashboard
  String get dashboard        => get('dashboard');
  String get weeklyAdherence  => get('weeklyAdherence');
  String get weeklyReport     => get('weeklyReport');
  String get downloadReport   => get('downloadReport');
  String get generating       => get('generating');

  // Settings
  String get language         => get('language');
  String get english          => get('english');
  String get arabic           => get('arabic');
  String get textSize         => get('textSize');
  String get small            => get('small');
  String get medium           => get('medium');
  String get large            => get('large');
  String get volume           => get('volume');

  // SOS
  String get sendSos          => get('sendSos');
  String get sosConfirmBody   => get('sosConfirmBody');
  String get helpOnWay        => get('helpOnWay');
  String get helpOnWayBody    => get('helpOnWayBody');
}
