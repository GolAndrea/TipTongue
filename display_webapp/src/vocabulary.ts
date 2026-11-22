export interface NotebookEntry {
  id: string;
  word: string;
  gloss: string;
}

/**
 * Open-domain starter EN -> Español lexical notebook entries (ready-to-speak
 * surface forms without preset scenario toggles or grammar tags).
 */
export const INITIAL_NOTEBOOK: NotebookEntry[] = [
  {id: 'w1', word: 'servilletas', gloss: 'napkins'},
  {id: 'w2', word: 'receta', gloss: 'prescription'},
  {id: 'w3', word: 'enchufe', gloss: 'power outlet'},
  {id: 'w4', word: 'llegué', gloss: 'I arrived'},
  {id: 'w5', word: 'plazo', gloss: 'deadline'},
  {id: 'w6', word: 'cuenta', gloss: 'bill / check'},
  {id: 'w7', word: 'fluidez', gloss: 'fluency'},
];

const BUILTIN_LOOKUP: Record<string, {word: string; gloss: string}> = {
  napkins: {word: 'servilletas', gloss: 'napkins'},
  napkin: {word: 'servilleta', gloss: 'napkin'},
  prescription: {word: 'receta', gloss: 'prescription'},
  doctor: {word: 'médico', gloss: 'doctor'},
  outlet: {word: 'enchufe', gloss: 'power outlet'},
  charger: {word: 'cargador', gloss: 'charger'},
  arrived: {word: 'llegué', gloss: 'I arrived'},
  bill: {word: 'cuenta', gloss: 'bill / check'},
  check: {word: 'cuenta', gloss: 'bill / check'},
  tip: {word: 'propina', gloss: 'tip'},
  deadline: {word: 'plazo', gloss: 'deadline'},
  budget: {word: 'presupuesto', gloss: 'budget'},
  meeting: {word: 'reunión', gloss: 'meeting'},
  platform: {word: 'andén', gloss: 'train platform'},
  luggage: {word: 'equipaje', gloss: 'luggage'},
  ticket: {word: 'billete', gloss: 'ticket'},
  fluency: {word: 'fluidez', gloss: 'fluency'},
  appointment: {word: 'cita', gloss: 'appointment'},
  receipt: {word: 'recibo', gloss: 'receipt'},
};

export function lookupSpanishWord(concept: string): {
  word: string;
  gloss: string;
} | null {
  const normalized = concept.trim().toLowerCase();
  if (!normalized) return null;

  if (BUILTIN_LOOKUP[normalized]) {
    return BUILTIN_LOOKUP[normalized];
  }

  for (const [key, entry] of Object.entries(BUILTIN_LOOKUP)) {
    if (normalized.includes(key) || entry.word.toLowerCase() === normalized) {
      return entry;
    }
  }
  return null;
}

export function knownLookupConcepts(): string[] {
  return Object.keys(BUILTIN_LOOKUP);
}
