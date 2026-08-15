// Agregator promptów Rady Doradczej Benedictum — SOURCE OF TRUTH (D1).
// Jedyny punkt, z którego gemini-proxy/index.ts pobiera system prompty.
// renderSystemPrompt(): interpolacja {scenario}, {user_input}, {context}
// i {safety_note} z escape'em delimiterów XML — "delimiter escaping / input
// boundary hardening".
// To NIE jest pełna ochrona przed prompt injection; model nadal może ulec
// manipulacji, ale użytkownik nie może zamknąć tagu <user_input>.
//
// Tryby (mode):
//  - "intake"  → Coach prowadzący wywiad (coach_intake_prompt).
//  - "analyze" → standardowa analiza person (domyślny).
// routing wybiera prompt na podstawie mode + persona.

import { systemPrompt as criticPrompt, maxSentences as criticMax, personaName as criticName } from "./critic_prompt.ts";
import { systemPrompt as optimistPrompt, maxSentences as optimistMax, personaName as optimistName } from "./optimist_prompt.ts";
import { systemPrompt as coachPrompt, maxSentences as coachMax, personaName as coachName } from "./coach_prompt.ts";
import { systemPrompt as coachIntakePrompt } from "./coach_intake_prompt.ts";

export type PersonaPrompt = {
  senderId: string;
  systemPrompt: string;
  maxSentences: number;
  personaName: string;
};

export const PERSONAS: PersonaPrompt[] = [
  { senderId: "critic", systemPrompt: criticPrompt, maxSentences: criticMax, personaName: criticName },
  { senderId: "optimist", systemPrompt: optimistPrompt, maxSentences: optimistMax, personaName: optimistName },
  { senderId: "coach", systemPrompt: coachPrompt, maxSentences: coachMax, personaName: coachName }
];

/// Dozwolone tryby rozmowy.
export type PromptMode = "intake" | "analyze";

/// Opcje renderowania promptu.
export type RenderOptions = {
  /// Tryb rozmowy. Domyślnie "analyze" (zachowanie wstecznie kompatybilne).
  mode?: PromptMode;
  /// Ustrukturyzowany kontekst zebrany przez Coacha (opcjonalny).
  context?: string;
  /// Nota bezpieczeństwa / disclaimer (opcjonalna, zalążek pod przyszłość).
  safetyNote?: string;
};

/// Escape < i > (oraz &) — delimiter escaping / input boundary hardening.
/// Zamiana & jako pierwsza, by nie dublować encji.
export function escapeXml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/// Wybiera prompt bazowy wg trybu i persony.
function resolveBasePrompt(persona: PersonaPrompt, mode: PromptMode): string {
  if (mode === "intake") {
    // Wywiad prowadzi wyłącznie Coach; wymaga persona === 'coach'.
    return coachIntakePrompt;
  }
  return persona.systemPrompt;
}

/// Interpolacja szablonu promptu: {scenario}, {user_input}, {context}, {safety_note}.
/// Wszystkie dane wejściowe są escape'owane przed interpolacją.
export function renderSystemPrompt(
  persona: PersonaPrompt,
  scenario: string,
  userInput: string,
  options: RenderOptions = {},
): string {
  const mode = options.mode ?? "analyze";
  const base = resolveBasePrompt(persona, mode);

  let out = base
    .replaceAll("{scenario}", escapeXml(scenario))
    .replaceAll("{user_input}", escapeXml(userInput));

  if (options.context && options.context.trim().length > 0) {
    out = out.replaceAll("{context}", escapeXml(options.context.trim()));
  } else {
    out = out.replaceAll("{context}", "");
  }

  if (options.safetyNote && options.safetyNote.trim().length > 0) {
    out = out.replaceAll("{safety_note}", escapeXml(options.safetyNote.trim()));
  } else {
    out = out.replaceAll("{safety_note}", "");
  }

  return out;
}
