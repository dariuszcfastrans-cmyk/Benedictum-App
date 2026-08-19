import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Benedictum'**
  String get appTitle;

  /// No description provided for @splashContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get splashContinue;

  /// No description provided for @authTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authTitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authRegister;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authSwitchToLogin;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get authSwitchToRegister;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeScenarios.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get homeScenarios;

  /// No description provided for @scenarioPitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Pitch to an Investor'**
  String get scenarioPitchTitle;

  /// No description provided for @scenarioPitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Practice your investor pitch in front of a virtual board'**
  String get scenarioPitchSubtitle;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type your argument...'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatEndSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get chatEndSession;

  /// No description provided for @chatStartAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start analysis'**
  String get chatStartAnalysis;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths'**
  String get reportStrengths;

  /// No description provided for @reportRisks.
  ///
  /// In en, this message translates to:
  /// **'Gaps and risks'**
  String get reportRisks;

  /// No description provided for @reportTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get reportTips;

  /// No description provided for @reportRating.
  ///
  /// In en, this message translates to:
  /// **'Overall rating'**
  String get reportRating;

  /// No description provided for @reportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No report yet. End a session in chat to generate one.'**
  String get reportEmpty;

  /// No description provided for @reportViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get reportViewHistory;

  /// No description provided for @reportUnlockMore.
  ///
  /// In en, this message translates to:
  /// **'Unlock more'**
  String get reportUnlockMore;

  /// No description provided for @homeHistory.
  ///
  /// In en, this message translates to:
  /// **'Saved sessions'**
  String get homeHistory;

  /// No description provided for @homeHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get homeHistoryTitle;

  /// No description provided for @homeHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open or delete your past sessions'**
  String get homeHistorySubtitle;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved sessions yet. End a chat session to save a report.'**
  String get historyEmpty;

  /// No description provided for @historyRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get historyRetry;

  /// No description provided for @historyUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get historyUntitled;

  /// No description provided for @historyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get historyDeleteTitle;

  /// No description provided for @historyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the session and its report. This cannot be undone.'**
  String get historyDeleteBody;

  /// No description provided for @historyDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get historyDeleteCancel;

  /// No description provided for @historyDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get historyDeleteConfirm;

  /// No description provided for @historyDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get historyDeleteTooltip;

  /// No description provided for @autosaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not save session'**
  String get autosaveFailedTitle;

  /// No description provided for @autosaveFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your report is ready, but saving to history failed. You can retry or continue without saving.'**
  String get autosaveFailedBody;

  /// No description provided for @autosaveRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get autosaveRetry;

  /// No description provided for @autosaveProceed.
  ///
  /// In en, this message translates to:
  /// **'Continue without saving'**
  String get autosaveProceed;

  /// No description provided for @autosaveProceedWarning.
  ///
  /// In en, this message translates to:
  /// **'Session was not saved to history.'**
  String get autosaveProceedWarning;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @personaCritic.
  ///
  /// In en, this message translates to:
  /// **'The Critic'**
  String get personaCritic;

  /// No description provided for @personaOptimist.
  ///
  /// In en, this message translates to:
  /// **'The Optimist'**
  String get personaOptimist;

  /// No description provided for @personaCoach.
  ///
  /// In en, this message translates to:
  /// **'The Coach'**
  String get personaCoach;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Benedictum Pro'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock full access to 3 AI coaches and reports'**
  String get paywallSubtitle;

  /// No description provided for @paywallMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallMonthly;

  /// No description provided for @paywallSixMonth.
  ///
  /// In en, this message translates to:
  /// **'Six months'**
  String get paywallSixMonth;

  /// No description provided for @paywallYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallYearly;

  /// No description provided for @paywallSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get paywallSubscribe;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// No description provided for @paywallLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading offers...'**
  String get paywallLoading;

  /// No description provided for @paywallError.
  ///
  /// In en, this message translates to:
  /// **'Could not load offers. Please try again.'**
  String get paywallError;

  /// No description provided for @paywallRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paywallRetry;

  /// No description provided for @paywallPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscription active! Welcome to Benedictum Pro.'**
  String get paywallPurchaseSuccess;

  /// No description provided for @paywallPurchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get paywallPurchaseCancelled;

  /// No description provided for @paywallRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get paywallRestoreSuccess;

  /// No description provided for @paywallRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'No active purchases to restore.'**
  String get paywallRestoreNone;

  /// No description provided for @chatProRequired.
  ///
  /// In en, this message translates to:
  /// **'This feature requires a Benedictum Pro subscription.'**
  String get chatProRequired;

  /// No description provided for @chatGoPro.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro'**
  String get chatGoPro;

  /// No description provided for @settingsSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSubscription;

  /// No description provided for @settingsTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get settingsTier;

  /// No description provided for @settingsTierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get settingsTierFree;

  /// No description provided for @settingsTierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get settingsTierPro;

  /// No description provided for @settingsExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get settingsExpiry;

  /// No description provided for @settingsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get settingsManage;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteTitle;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your account, session history and reports will be permanently deleted. This cannot be undone.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDeleteConfirm;

  /// No description provided for @settingsDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsDeleteCancel;

  /// No description provided for @settingsDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Please try again.'**
  String get settingsDeleteError;

  /// No description provided for @chatMicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatMicTooltip;

  /// No description provided for @chatMicListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get chatMicListening;

  /// No description provided for @chatMicStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get chatMicStop;

  /// No description provided for @chatTtsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get chatTtsTooltip;

  /// No description provided for @chatTtsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get chatTtsStop;

  /// No description provided for @chatMicPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access was denied. You can still type your messages.'**
  String get chatMicPermissionDenied;

  /// No description provided for @chatMicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available on this device. Please use text input.'**
  String get chatMicUnavailable;

  /// No description provided for @chatMicEmpty.
  ///
  /// In en, this message translates to:
  /// **'No speech recognized. Try again or type your message.'**
  String get chatMicEmpty;

  /// No description provided for @settingsConversationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Conversation language'**
  String get settingsConversationLanguage;

  /// No description provided for @settingsConversationHint.
  ///
  /// In en, this message translates to:
  /// **'Used for voice input and read-aloud. Independent of your device and interface language.'**
  String get settingsConversationHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
