// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'المنبه المتقدم';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get sectionAppearance => 'المظهر';

  @override
  String get sectionAlarms => 'المنبهات';

  @override
  String get sectionDanger => 'إجراءات خطرة';

  @override
  String get themeMode => 'السمة';

  @override
  String get themeSystem => 'وضع النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get timeFormat => 'تنسيق الوقت';

  @override
  String get timeFormat24 => '24 ساعة';

  @override
  String get timeFormat12 => '12 ساعة';

  @override
  String get defaultSnooze => 'مدة الغفوة الافتراضية';

  @override
  String snoozeMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get defaultRingtone => 'نغمة المنبه الافتراضية';

  @override
  String get ringtoneClassic => 'جرس كلاسيكي';

  @override
  String get ringtoneDigital => 'صفير رقمي';

  @override
  String get ringtoneGentle => 'أنغام هادئة';

  @override
  String get ringtoneRooster => 'صياح الديك';

  @override
  String get ringtoneOcean => 'أمواج المحيط';

  @override
  String get resetAllAlarms => 'حذف جميع المنبهات';

  @override
  String get resetAllAlarmsDescription =>
      'حذف نهائي لجميع المنبهات. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get resetConfirmTitle => 'حذف جميع المنبهات؟';

  @override
  String get resetConfirmMessage =>
      'سيتم حذف جميع المنبهات نهائياً. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get alarmsResetSnack => 'تم حذف جميع المنبهات.';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get homeNoSettingsHint => 'اضغط على أيقونة الترس لفتح الإعدادات.';
}
