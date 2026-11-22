import {
  knownLookupConcepts,
  lookupSpanishWord,
  NotebookEntry,
} from './vocabulary';

/**
 * Official Meta Ray-Ban Display WebMCP surface (document.modelContext).
 * Never polyfilled: when absent (e.g. desktop browser or Dev Mode off),
 * registration is a clean no-op and the D-pad path remains 100% functional.
 */
interface ModelContextTool {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, {type: string; description: string}>;
    required?: string[];
  };
  annotations?: {readOnlyHint?: boolean};
  execute: (
    args: Record<string, unknown>,
    context?: {signal?: AbortSignal},
  ) => Promise<string> | string;
}

interface ModelContext {
  registerTool: (
    tool: ModelContextTool,
    options?: {signal?: AbortSignal},
  ) => unknown;
}

declare global {
  interface Document {
    modelContext?: ModelContext;
  }
}

export interface TipTongueWebMcpBridge {
  getState: () => {
    currentCard: NotebookEntry | null;
    totalCards: number;
  };
  showWordCard: (entry: NotebookEntry) => void;
}

function problem(message: string, next_action: string): string {
  return JSON.stringify({error: true, message, next_action});
}

function safeRegister(
  ctx: ModelContext,
  tool: ModelContextTool,
  signal?: AbortSignal,
): void {
  try {
    const result = ctx.registerTool(tool, signal ? {signal} : undefined);
    if (typeof (result as PromiseLike<unknown>)?.then === 'function') {
      (result as PromiseLike<unknown>).then(undefined, (err: unknown) => {
        console.error(`${tool.name} registration failed`, err);
      });
    }
  } catch (err) {
    console.error(`${tool.name} registration failed`, err);
  }
}

export function registerTipTongueWebMcpTools(
  bridge: TipTongueWebMcpBridge,
  signal?: AbortSignal,
): void {
  const ctx = document.modelContext;
  if (!ctx?.registerTool) return;

  // 1. Read-only orientation tool required by WebMCP guidelines
  safeRegister(
    ctx,
    {
      name: 'tiptongue_state',
      description:
        'Read the currently displayed EN->ES open-domain vocabulary card in TipTongue.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
      annotations: {readOnlyHint: true},
      execute: async () => {
        const state = bridge.getState();
        return JSON.stringify({
          current_word: state.currentCard?.word ?? null,
          current_gloss: state.currentCard?.gloss ?? null,
          total_saved_words: state.totalCards,
          next_action:
            'State retrieved. Answer the wearer concisely in one short sentence.',
        });
      },
    },
    signal,
  );

  // 2. Open-domain single-word contextual lookup rendered directly on the 600x600 lens
  safeRegister(
    ctx,
    {
      name: 'tiptongue_lookup',
      description:
        'Look up a single ready-to-speak Spanish word (already conjugated/declined, no grammar tags, works in any everyday context) for an English concept, display it on the TipTongue lens card, and save it to today’s notebook.',
      inputSchema: {
        type: 'object',
        properties: {
          concept: {
            type: 'string',
            description:
              'English word or short concept from any real-world conversation to translate into Spanish.',
          },
        },
        required: ['concept'],
      },
      execute: async ({concept}) => {
        const query = String(concept ?? '').trim();
        const hit = lookupSpanishWord(query);
        if (!hit) {
          return problem(
            `No offline TipTongue card matched "${query}".`,
            `Say you did not find an offline card and suggest one of: ${knownLookupConcepts().slice(0, 6).join(', ')}.`,
          );
        }

        const entry: NotebookEntry = {
          id: `webmcp_${hit.word}`,
          word: hit.word,
          gloss: hit.gloss,
        };
        bridge.showWordCard(entry);

        return JSON.stringify({
          word: entry.word,
          gloss: entry.gloss,
          next_action:
            'Speak only the Spanish word and its short English meaning in one brief phrase, then stop.',
        });
      },
    },
    signal,
  );
}
