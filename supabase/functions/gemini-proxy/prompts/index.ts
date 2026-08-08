// Agregator promptów Rady Doradczej Benedictum — SOURCE OF TRUTH (D1).
// Jedyny punkt, z którego gemini-proxy/index.ts pobiera system prompty.
// renderSystemPrompt(): interpolacja {scenario} i {user_input} z escape'em
// delimiterów XML — "delimiter escaping / input boundary hardening".
// To NIE jest pełna ochrona przed prompt injection; model nadal może ulec
// manipulacji, ale użytkownik nie może zamknąć tagu <user_input>.

import { systemPrompt as criticPrompt, maxSentences as criticMax, personaName as criticName } from "./critic_prompt.ts";
import { systemPrompt as optimistPrompt, maxSentences as optimistMax, personaName as optimistName } from "./optimist_prompt.ts";
import { systemPrompt as coachPrompt, maxSentences as coachMax, personaName as coachName } from "./coach_prompt.ts";

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

/// Escape < i > (oraz &) — delimiter escaping / input boundary hardening.
/// Zamiana & jako pierwsza, by nie dublować encji.
export function escapeXml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/// Interpolacja szablonu persony: {scenario} i {user_input}.
/// user_input NIGDY nie trafia do promptu w surowej formie — escape delimiterów.
export function renderSystemPrompt(persona: PersonaPrompt, scenario: string, userInput: string): string {
  return persona.systemPrompt
    .replaceAll("{scenario}", escapeXml(scenario))
    .replaceAll("{user_input}", escapeXml(userInput));
}
