import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';
import '../../core/errors/app_exceptions.dart';
import '../../models/session_summary.dart';
import '../../services/interfaces/i_api_service.dart';
import '../../services/mocks/mock_api_service.dart';
import '../../services/service_locator.dart';

/// Historia własnych sesji (Fala 2A.3 — VIEW, Dyrektywa 2A §15).
/// Lista sesji użytkownika (GET /sessions), odczyt raportu (GET /sessions/:id)
/// i usunięcie sesji (DELETE /sessions/:id — kaskada) z potwierdzeniem.
/// RESUME nie jest częścią 2A.3 (OPEN) — VIEW nie uruchamia AI.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.apiService});

  final IApiService? apiService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final IApiService _apiService =
      widget.apiService ?? ServiceLocator.apiService ?? MockApiService();
  List<SessionSummary>? _sessions;
  String? _error;
  bool _loading = true;
  // Identyfikator sesji w trakcie usuwania (spinner na liście).
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _apiService.getSessionHistory();
      if (!mounted) return;
      setState(() {
        _sessions = List.of(sessions); // kopia mutowalna (mock: unmodifiable)
        _loading = false;
      });
    } on RateLimitException catch (e) {
      _setError(e.message);
    } on AuthException catch (e) {
      _setError(e.message);
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('Nie udało się pobrać historii.');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  /// Odczyt raportu wybranej sesji. Obsługa 404/403/niedostępnej sesji:
  /// komunikat + powrót do listy — brak pustego ekranu i crasha (warunek UX).
  Future<void> _openSession(SessionSummary session) async {
    try {
      final (_, report) = await _apiService.getSessionReport(session.id);
      if (!mounted) return;
      context.go(AppRoutes.report, extra: report);
    } on SessionUnavailableException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } on RateLimitException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSessionMessage('Nie udało się otworzyć sesji.');
    }
  }

  void _showSessionMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Usunięcie sesji: obowiązkowe potwierdzenie (DELETE jest destrukcyjny
  /// i kaskadowy — warunek UX). Po usunięciu lista jest odświeżana.
  Future<void> _deleteSession(SessionSummary session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.historyDeleteTitle),
        content: Text(l10n.historyDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.historyDeleteCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.historyDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _deletingId = session.id;
    });
    try {
      await _apiService.deleteSession(session.id);
      if (!mounted) return;
      setState(() {
        _sessions?.removeWhere((s) => s.id == session.id);
      });
    } on SessionUnavailableException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } on RateLimitException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSessionMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSessionMessage('Nie udało się usunąć sesji.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.historyRetry),
              ),
            ],
          ),
        ),
      );
    }
    final sessions = _sessions ?? const <SessionSummary>[];
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.historyEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _SessionTile(
            session: session,
            deleting: _deletingId == session.id,
            onOpen: () => _openSession(session),
            onDelete: () => _deleteSession(session),
          );
        },
      ),
    );
  }
}

/// Pojedyncza pozycja historii: tytuł/scenariusz, data, przycisk usunięcia.
class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  final SessionSummary session;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = session.title?.isNotEmpty == true
        ? session.title!
        : (session.scenarioKey ?? l10n.historyUntitled);
    final date = _formatDate(context, session.completedAt ?? session.createdAt);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(date),
        trailing: deleting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.historyDeleteTooltip,
                    onPressed: onDelete,
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: deleting ? null : onOpen,
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}