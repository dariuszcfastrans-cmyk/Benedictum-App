// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Benedictum';

  @override
  String get splashContinue => 'Continue';

  @override
  String get authTitle => 'Sign in';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authLogin => 'Sign in';

  @override
  String get authRegister => 'Sign up';

  @override
  String get authSwitchToLogin => 'Already have an account? Sign in';

  @override
  String get authSwitchToRegister => 'Don\'t have an account? Sign up';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeScenarios => 'Scenarios';

  @override
  String get scenarioPitchTitle => 'Pitch to an Investor';

  @override
  String get scenarioPitchSubtitle =>
      'Practice your investor pitch in front of a virtual board';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatInputHint => 'Type your argument...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatEndSession => 'End session';

  @override
  String get chatStartAnalysis => 'Start analysis';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportStrengths => 'Strengths';

  @override
  String get reportRisks => 'Gaps and risks';

  @override
  String get reportTips => 'Tips';

  @override
  String get reportRating => 'Overall rating';

  @override
  String get reportEmpty =>
      'No report yet. End a session in chat to generate one.';

  @override
  String get reportViewHistory => 'View history';

  @override
  String get reportUnlockMore => 'Unlock more';

  @override
  String get homeHistory => 'Saved sessions';

  @override
  String get homeHistoryTitle => 'History';

  @override
  String get homeHistorySubtitle => 'Open or delete your past sessions';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmpty =>
      'No saved sessions yet. End a chat session to save a report.';

  @override
  String get historyRetry => 'Retry';

  @override
  String get historyUntitled => 'Untitled session';

  @override
  String get historyDeleteTitle => 'Delete session';

  @override
  String get historyDeleteBody =>
      'This permanently deletes the session and its report. This cannot be undone.';

  @override
  String get historyDeleteCancel => 'Cancel';

  @override
  String get historyDeleteConfirm => 'Delete';

  @override
  String get historyDeleteTooltip => 'Delete session';

  @override
  String get autosaveFailedTitle => 'Could not save session';

  @override
  String get autosaveFailedBody =>
      'Your report is ready, but saving to history failed. You can retry or continue without saving.';

  @override
  String get autosaveRetry => 'Retry';

  @override
  String get autosaveProceed => 'Continue without saving';

  @override
  String get autosaveProceedWarning => 'Session was not saved to history.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get personaCritic => 'The Critic';

  @override
  String get personaOptimist => 'The Optimist';

  @override
  String get personaCoach => 'The Coach';

  @override
  String get paywallTitle => 'Benedictum Pro';

  @override
  String get paywallSubtitle =>
      'Unlock full access to 3 AI coaches and reports';

  @override
  String get paywallMonthly => 'Monthly';

  @override
  String get paywallSixMonth => 'Six months';

  @override
  String get paywallYearly => 'Yearly';

  @override
  String get paywallSubscribe => 'Subscribe';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallLoading => 'Loading offers...';

  @override
  String get paywallError => 'Could not load offers. Please try again.';

  @override
  String get paywallRetry => 'Try again';

  @override
  String get paywallPurchaseSuccess =>
      'Subscription active! Welcome to Benedictum Pro.';

  @override
  String get paywallPurchaseCancelled => 'Purchase cancelled.';

  @override
  String get paywallRestoreSuccess => 'Purchases restored.';

  @override
  String get paywallRestoreNone => 'No active purchases to restore.';

  @override
  String get chatProRequired =>
      'This feature requires a Benedictum Pro subscription.';

  @override
  String get chatGoPro => 'Unlock Pro';

  @override
  String get settingsSubscription => 'Subscription';

  @override
  String get settingsTier => 'Tier';

  @override
  String get settingsTierFree => 'Free';

  @override
  String get settingsTierPro => 'Pro';

  @override
  String get settingsExpiry => 'Expires';

  @override
  String get settingsManage => 'Manage subscription';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteTitle => 'Delete account';

  @override
  String get settingsDeleteBody =>
      'Your account, session history and reports will be permanently deleted. This cannot be undone.';

  @override
  String get settingsDeleteConfirm => 'Delete';

  @override
  String get settingsDeleteCancel => 'Cancel';

  @override
  String get settingsDeleteError =>
      'Could not delete your account. Please try again.';

  @override
  String get chatMicTooltip => 'Voice input';

  @override
  String get chatMicListening => 'Listening...';

  @override
  String get chatMicStop => 'Stop recording';

  @override
  String get chatTtsTooltip => 'Read aloud';

  @override
  String get chatTtsStop => 'Stop playback';

  @override
  String get chatMicPermissionDenied =>
      'Microphone access was denied. You can still type your messages.';

  @override
  String get chatMicUnavailable =>
      'Speech recognition is not available on this device. Please use text input.';

  @override
  String get chatMicEmpty =>
      'No speech recognized. Try again or type your message.';
}
