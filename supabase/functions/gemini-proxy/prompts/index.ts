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
//  - "report"  → raport końcowy sesji (report_prompt) — 1 wywołanie LLM.
// routing wybiera prompt na podstawie mode + persona.

import { systemPrompt as criticPrompt, maxSentences as criticMax, personaName as criticName } from "./critic_prompt.ts";
import { systemPrompt as optimistPrompt, maxSentences as optimistMax, personaName as optimistName } from "./optimist_prompt.ts";
import { systemPrompt as coachPrompt, maxSentences as coachMax, personaName as coachName } from "./coach_prompt.ts";
import { systemPrompt as coachIntakePrompt } from "./coach_intake_prompt.ts";
import { systemPrompt as reportSystemPrompt } from "./report_prompt.ts";

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
export type PromptMode = "intake" | "analyze" | "report";

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

/// Interpolacja promptu raportu: {scenario} i {context} (escape'owane).
export function renderReportPrompt(scenario: string, context: string): string {
  let out = reportSystemPrompt
    .replaceAll("{scenario}", escapeXml(scenario))
    .replaceAll("{context}", escapeXml(context));
  // Usuń ewentualne nieobsłużone placeholdery (defensywnie).
  out = out.replaceAll("{scenario}", "").replaceAll("{context}", "");
  return out;
}

/// Kontrakt raportu (Dyrektywa 2A §3).
export type ReportContract = {
  strengths: string[];
  gaps: string[];
  action_items: string[];
  overall_rating: number;
};

/// Walidacja odpowiedzi raportu. Zwraca kontrakt albo null (422 INVALID_REPORT).
/// overall_rating musi być liczbą całkowitą 1–5; tablice — tablicami stringów.
export function parseReport(text: string): ReportContract | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  // Usuń ewentualne ramki markdown ```json ... ```.
  const json = trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
  let data: unknown;
  try {
    data = JSON.parse(json);
  } catch {
    return null;
  }
  if (typeof data !== "object" || data === null || Array.isArray(data)) return null;
  const obj = data as Record<string, unknown>;
  if (!Array.isArray(obj.strengths) || !obj.strengths.every((s) => typeof s === "string")) {
    return null;
  }
  if (!Array.isArray(obj.gaps) || !obj.gaps.every((s) => typeof s === "string")) {
    return null;
  }
  if (!Array.isArray(obj.action_items) || !obj.action_items.every((s) => typeof s === "string")) {
    return null;
  }
  const rating = obj.overall_rating;
  if (typeof rating !== "number" || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    return null;
  }
  return {
    strengths: obj.strengths as string[],
    gaps: obj.gaps as string[],
    action_items: obj.action_items as string[],
    overall_rating: rating,
  };
}
