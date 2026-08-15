import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';
import '../../core/errors/app_exceptions.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/scenario.dart';
import '../../services/interfaces/i_api_service.dart';
import '../../services/interfaces/i_revenuecat_service.dart';
import '../../services/mocks/mock_api_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/service_locator.dart';

/// Faza rozmowy: "intake" (Coach prowadzi wywiad) lub "analyze" (3 persony).
/// Stan lokalny i nietrwały (DEC Fala 1B) — brak persistencji świadomie.
enum _ChatPhase { intake, analyze }

/// Ekran czatu: lista wiadomości (bąbelki), input, mock API z 3 personami.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.apiService, this.revenueCatService});

  /// Wstrzykiwany serwis API; domyślnie MockApiService (C1).
  final IApiService? apiService;

  /// Wstrzykiwany serwis RevenueCat; domyślnie singleton.
  final IRevenueCatService? revenueCatService;

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
  final List<Message> _messages = [];
  bool _isLoading = false;
  Scenario? _scenario;
  // Faza rozmowy — startuje od wywiadu (intake); przejście do analyze jest
  // świadomą decyzją użytkownika. Stan lokalny, gubi się przy nawigacji.
  _ChatPhase _phase = _ChatPhase.intake;

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
    super.dispose();
  }

  /// Brama dostępu Pro (Część D2): przed zapytaniem do gemini-proxy sprawdza,
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

    // D2: brama Pro — brak dostępu blokuje wysłanie do gemini-proxy.
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

  /// Decyzja użytkownika: przejście z wywiadu (intake) do analizy (analyze).
  /// Nie wysyła zapytania — tylko przełącza fazę; kolejna wiadomość uruchomi
  /// analyze z zebranym contextem. Coach może tylko zaproponować, przejście
  /// zawsze inicjuje użytkownik (zasada UŻYTKOWNIK KONTROLUJE ANALIZĘ).
  void _startAnalysis() {
    setState(() {
      _phase = _ChatPhase.analyze;
    });
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
            onPressed: () => context.go(AppRoutes.report),
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
                return _MessageBubble(message: _messages[index]);
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
  const _MessageBubble({required this.message});

  final Message message;

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
}
