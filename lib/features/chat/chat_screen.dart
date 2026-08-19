import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/locale_controller.dart';
import '../../config/routes.dart';
import '../../core/errors/app_exceptions.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/report.dart';
import '../../models/scenario.dart';
import '../../services/interfaces/i_api_service.dart';
import '../../services/interfaces/i_revenuecat_service.dart';
import '../../services/interfaces/i_voice_service.dart';
import '../../services/mocks/mock_api_service.dart';
import '../../services/mocks/mock_voice_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/service_locator.dart';

/// Faza rozmowy: "intake" (Coach prowadzi wywiad) lub "analyze" (3 persony).
/// Stan lokalny i nietrwały (DEC Fala 1B) — brak persistencji świadomie.
enum _ChatPhase { intake, analyze }

/// Ekran czatu: lista wiadomości (bąbelki), input, mock API z 3 personami.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.apiService, this.revenueCatService, this.voiceService});

  /// Wstrzykiwany serwis API; domyślnie MockApiService (C1).
  final IApiService? apiService;

  /// Wstrzykiwany serwis RevenueCat; domyślnie singleton.
  final IRevenueCatService? revenueCatService;

  /// Wstrzykiwany serwis głosowy (STT/TTS); domyślnie MockVoiceService.
  final IVoiceService? voiceService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Priorytet: parametr → rejestr (ServiceLocator) → Mock (fallback offline).
  late final IApiService _apiService =
      widget.apiService ?? ServiceLocator.apiService ?? MockApiService();
  late final IRevenueCatService _revenueCatService =
      widget.revenueCatService ?? RevenueCatService.instance;
  // Voice (A3): priorytet parametr → rejestr → Mock (fallback offline/test).
  late final IVoiceService _voiceService =
      widget.voiceService ?? ServiceLocator.voiceService ?? MockVoiceService();
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  String? _ttsMessageId;
  Scenario? _scenario;
  // Raport oczekujący na nawigację (autosave 2A.3) — potrzebny przy retry.
  Report? _pendingReport;
  // Faza rozmowy — startuje od wywiadu (intake); przejście do analyze jest
  // świadomą decyzją użytkownika. Stan lokalny, gubi się przy nawigacji.
  _ChatPhase _phase = _ChatPhase.intake;

  @override
  void initState() {
    super.initState();
    // R2: język rozmowy (STT+TTS) aktualizowany przy każdym wejściu do czatu —
    // zmiana w Settings jest widoczna przy kolejnym otwarciu rozmowy.
    _voiceService.setConversationLanguage(
      LocaleController.instance.conversationLanguage.value,
    );
  }

  /// Buduje context wyłącznie z wypowiedzi użytkownika (sender == 'user').
  /// Każda wypowiedź jest oznaczana jako USER_STATEMENT — NIE jest faktem ani
  /// hipotezą (DEC Fala 1B, D1). Odpowiedzi Coacha/modelu NIGDY nie trafiają
  /// do contextu.
  String _buildUserContext() {
    final statements = _messages
        .where((m) => m.sender == 'user')
        .map((m) => m.content.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (statements.isEmpty) return '';
    final numbered = statements.asMap().entries
        .map((e) => 'USER_STATEMENT ${e.key + 1}: ${e.value}')
        .join('\n');
    return numbered;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scenariusz przekazywany z /home przez extra.
    final extra = GoRouterState.of(context).extra;
    if (extra is Scenario) {
      _scenario = extra;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _voiceService.cancelListening();
    _voiceService.stopSpeaking();
    super.dispose();
  }

  /// Brama dostępu Pro (Część D2): przed zapytaniem do llm-gateway sprawdza,
  /// czy użytkownik ma aktywny entitlement 'Benedictum Pro'. Brak Pro →
  /// snackbar z przyciskiem do paywall, bez wywołania API.
  /// Web = tryb demo: pomijamy bramę (RevenueCat nie działa na Web);
  /// ochrona po stronie serwera (JWT + rate-limit) pozostaje.
  Future<bool> _hasProAccess() async {
    if (kIsWeb) return true;
    if (!_revenueCatService.isInitialized) return true; // offline/dev: brak bramy
    return _revenueCatService.checkProAccess();
  }

  void _showProRequired() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.chatProRequired),
          action: SnackBarAction(
            label: l10n.chatGoPro,
            onPressed: () => context.go(AppRoutes.paywall),
          ),
        ),
      );
  }

  void _showChatError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // D2: brama Pro — brak dostępu blokuje wysłanie do llm-gateway.
    if (!await _hasProAccess()) {
      if (!mounted) return;
      _showProRequired();
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _messages.add(Message(
        id: 'user_${DateTime.now().microsecondsSinceEpoch}',
        sender: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _inputController.clear();
    });

    try {
      final isIntake = _phase == _ChatPhase.intake;
      final responses = await _apiService.getPersonaResponses(
        userInput: text,
        scenario: _scenario?.id ?? '',
        context: isIntake ? null : _buildUserContext(),
        mode: isIntake ? 'intake' : 'analyze',
      );

      // Sprawdzenie mounted po operacji asynchronicznej.
      if (!mounted) return;
      setState(() {
        _messages.addAll(responses);
      });
      _scrollToBottom();
    } on RateLimitException catch (e) {
      if (!mounted) return;
      _showChatError(e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showChatError(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showChatError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showChatError('Nieznany błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Głosowe wprowadzanie wiadomości (A3.2): STT → istniejące pole tekstowe.
  /// Użytkownik może poprawić transkrypcję przed wysłaniem (confirm-before-lock);
  /// surowy wynik STT NIGDY nie jest wysyłany automatycznie.
  Future<void> _startVoiceInput() async {
    if (_isLoading || _isListening) return;
    final l10n = AppLocalizations.of(context);
    if (!_voiceService.isSttSupported) {
      _showChatError(l10n.chatMicUnavailable);
      return;
    }

    setState(() => _isListening = true);
    try {
      final transcript = await _voiceService.transcribe();
      if (!mounted) return;
      if (transcript.isEmpty) {
        _showChatError(l10n.chatMicEmpty);
        return;
      }
      _inputController.text = transcript;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: transcript.length),
      );
    } catch (_) {
      if (!mounted) return;
      _showChatError(l10n.chatMicPermissionDenied);
    } finally {
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _stopVoiceInput() async {
    await _voiceService.cancelListening();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  /// Odtwarzanie odpowiedzi persony głosem (A3.3, on-device TTS).
  /// Jedno odtwarzanie naraz; ponowne dotknięcie zatrzymuje.
  Future<void> _toggleTts(Message message) async {
    final l10n = AppLocalizations.of(context);
    if (!_voiceService.isTtsSupported) {
      _showChatError(l10n.chatMicUnavailable);
      return;
    }
    if (_ttsMessageId == message.id && _voiceService.isSpeaking) {
      await _voiceService.stopSpeaking();
      if (mounted) {
        setState(() => _ttsMessageId = null);
      }
      return;
    }
    await _voiceService.stopSpeaking();
    final ok = await _voiceService.speak(message.content);
    if (mounted) {
      setState(() => _ttsMessageId = ok ? message.id : null);
    }
  }

  /// Decyzja użytkownika: przejście z wywiadu (intake) do analizy (analyze).
  /// Nie wysyła zapytania — tylko przełącza fazę; kolejna wiadomość uruchomi
  /// analyze z zebranym contextem. Coach może tylko zaproponować, przejście
  /// zawsze inicjuje użytkownik (zasada UŻYTKOWNIK KONTROLUJE ANALIZĘ).
  void _startAnalysis() {
    setState(() {
      _phase = _ChatPhase.analyze;
    });
  }

  /// Zakończenie sesji: generuje raport (mode:"report" — 1 wywołanie LLM)
  /// z kontekstu wypowiedzi użytkownika, zapisuje sesję (autosave, 2A.3)
  /// i nawiguje do ekranu raportu.
  /// Bezpieczeństwo UX (warunek Operatora): jeżeli autosave nie powiedzie się,
  /// użytkownik otrzymuje czytelną informację z możliwością ponowienia zapisu
  /// albo bezpiecznej nawigacji z ostrzeżeniem. Brak cichego niepowodzenia.
  Future<void> _endSession() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final report = await _apiService.getReport(
        scenario: _scenario?.id ?? '',
        context: _buildUserContext(),
      );
      if (!mounted) return;
      _pendingReport = report;

      // Autosave (2A.3): zapis sesji przez session-proxy. Niepowodzenie nie
      // blokuje raportu — pokazujemy wybór: ponów albo przejdź bez zapisu.
      final saved = await _tryAutosaveSession(report);
      if (!mounted) return;
      if (saved == false) {
        final proceed = await _askSaveRetry();
        if (!mounted) return;
        if (!proceed) return; // dialog zakończony (retry lub anulowanie)
      }
      context.go(AppRoutes.report, extra: report);
    } on RateLimitException catch (e) {
      if (!mounted) return;
      _showChatError(e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showChatError(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showChatError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showChatError('Nieznany błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Próbuje zapisać sesję. Zwraca true = zapisano, false = nieudany,
  /// null = brak potrzeby (np. tryb offline/mock bez zapisu? zawsze próbuje).
  Future<bool?> _tryAutosaveSession(Report report) async {
    try {
      final statements = _messages
          .where((m) => m.sender == 'user')
          .map((m) => m.content.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      await _apiService.saveSession(
        scenarioKey: _scenario?.id ?? '',
        title: _scenario?.titleKey,
        userStatements: statements,
        report: report,
      );
      return true;
    } on RateLimitException catch (e) {
      if (mounted) _showChatError(e.message);
      return false;
    } on AuthException catch (e) {
      if (mounted) _showChatError(e.message);
      return false;
    } on SessionUnavailableException catch (e) {
      if (mounted) _showChatError(e.message);
      return false;
    } on ApiException catch (e) {
      if (mounted) _showChatError(e.message);
      return false;
    } catch (_) {
      if (mounted) _showChatError('Nie udało się zapisać sesji. Spróbuj ponownie.');
      return false;
    }
  }

  /// Dialog przy nieudanym autosave: ponów zapis albo przejdź bez zapisu.
  /// Zwraca true, gdy użytkownik zdecydował kontynuować do raportu.
  Future<bool> _askSaveRetry() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autosaveFailedTitle),
        content: Text(l10n.autosaveFailedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'retry'),
            child: Text(l10n.autosaveRetry),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'proceed'),
            child: Text(l10n.autosaveProceed),
          ),
        ],
      ),
    );
    if (choice == 'retry') {
      // Ponów zapis; przy kolejnym niepowodzeniu pokazujemy komunikat
      // i pozwalamy bezpiecznie przejść (bez zapisu, z ostrzeżeniem).
      final report = _pendingReport;
      if (report != null) {
        final saved = await _tryAutosaveSession(report);
        if (saved == true) return true;
      }
      return _continueAfterFailedRetry();
    }
    return choice == 'proceed';
  }

  /// Po nieudanym ponowieniu zapisu: ostrzeżenie i kontynuacja do raportu
  /// (bez zapisu — użytkownik świadomie wybrał). Brak cichego niepowodzenia.
  bool _continueAfterFailedRetry() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.autosaveProceedWarning)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _scenario != null ? l10n.scenarioPitchTitle : l10n.chatTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _endSession,
            child: Text(l10n.chatEndSession),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  speaking: _ttsMessageId == message.id,
                  onSpeak: message.sender == 'user'
                      ? null
                      : () => _toggleTts(message),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          if (_phase == _ChatPhase.intake && _buildUserContext().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _isLoading ? null : _startAnalysis,
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text(l10n.chatStartAnalysis),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: l10n.chatInputHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      _isLoading ? null : (_isListening ? _stopVoiceInput : _startVoiceInput),
                  tooltip: _isListening ? l10n.chatMicStop : l10n.chatMicTooltip,
                  icon: Icon(
                    _isListening ? Icons.stop_circle_outlined : Icons.mic_none,
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  child: Text(l10n.chatSend),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bąbelek wiadomości: user po prawej, persony po lewej z avatarem.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.speaking = false, this.onSpeak});

  final Message message;
  final bool speaking;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surface;
    final textColor = isUser ? Colors.white : Colors.white70;

    final persona = Persona.values.firstWhere(
      (p) => p.senderId == message.sender,
      orElse: () => Persona.critic,
    );

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _personaName(context, persona),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (onSpeak != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onSpeak,
                      child: Tooltip(
                        message: speaking ? l10nChatTtsStop(context) : l10nChatTtsTooltip(context),
                        child: Icon(
                          speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 4),
            Text(message.content, style: TextStyle(color: textColor)),
          ],
        ),
      ),
    );
  }

  String _personaName(BuildContext context, Persona persona) {
    final l10n = AppLocalizations.of(context);
    switch (persona) {
      case Persona.critic:
        return l10n.personaCritic;
      case Persona.optimist:
        return l10n.personaOptimist;
      case Persona.coach:
        return l10n.personaCoach;
    }
  }

  String l10nChatTtsTooltip(BuildContext context) =>
      AppLocalizations.of(context).chatTtsTooltip;

  String l10nChatTtsStop(BuildContext context) =>
      AppLocalizations.of(context).chatTtsStop;
}
