import {useCallback, useEffect, useRef, useState} from 'react';
import {
  App as WearablesApp,
  Button,
  ButtonRail,
  Page,
  Panel,
  ScrollView,
  TextStyle,
  TextView,
} from '@wearables-ui-toolkit/mrbd';
import {INITIAL_NOTEBOOK, NotebookEntry} from './vocabulary';
import {registerTipTongueWebMcpTools} from './webmcp';

export default function App() {
  const [entries, setEntries] = useState<NotebookEntry[]>(INITIAL_NOTEBOOK);
  const [index, setIndex] = useState(0);
  const [showGloss, setShowGloss] = useState(true);

  const safeIndex = entries.length === 0 ? 0 : index % entries.length;
  const currentCard = entries[safeIndex] ?? null;

  const stateRef = useRef({
    currentCard,
    totalCards: entries.length,
  });
  stateRef.current = {
    currentCard,
    totalCards: entries.length,
  };

  const handleNext = useCallback(() => {
    if (entries.length === 0) return;
    setIndex(prev => (prev + 1) % entries.length);
  }, [entries.length]);

  const showWordCard = useCallback((entry: NotebookEntry) => {
    setEntries(prev => {
      const existingIdx = prev.findIndex(
        item => item.word.toLowerCase() === entry.word.toLowerCase(),
      );
      if (existingIdx >= 0) {
        const existing = prev[existingIdx];
        return [existing, ...prev.filter((_, idx) => idx !== existingIdx)];
      }
      return [entry, ...prev];
    });
    setIndex(0);
    setShowGloss(true);
  }, []);

  // Register official Meta Ray-Ban Display WebMCP tools on mount
  useEffect(() => {
    const controller = new AbortController();
    registerTipTongueWebMcpTools(
      {
        getState: () => stateRef.current,
        showWordCard,
      },
      controller.signal,
    );
    return () => controller.abort();
  }, [showWordCard]);

  return (
    <WearablesApp>
      <Page headerText="TipTongue · EN → ES" enableSystemBarInset={false}>
        <div className="action-page-shell">
          <ScrollView insetForHeader ariaLabel="TipTongue notebook cards" tabIndex={0}>
            <Panel width="100%">
              <div className="content-inset">
                <div className="word-row">
                  <TextView as="span" textStyle={TextStyle.META3} className="scenario-meta">
                    Today’s notebook
                  </TextView>
                  <TextView as="span" textStyle={TextStyle.META3} className="scenario-meta">
                    {entries.length > 0 ? `${safeIndex + 1} / ${entries.length}` : '0 / 0'}
                  </TextView>
                </div>

                <TextView as="h1" textStyle={TextStyle.DISPLAY1}>
                  {currentCard ? currentCard.word : 'Lens clear'}
                </TextView>

                <TextView as="p" textStyle={TextStyle.BODY2}>
                  {currentCard
                    ? showGloss
                      ? currentCard.gloss
                      : 'Recall from memory'
                    : 'No saved words yet.'}
                </TextView>
              </div>
            </Panel>
          </ScrollView>

          <div className="action-dock">
            <ButtonRail>
              <Button title="Next word" onClick={handleNext} />
              <Button
                title={showGloss ? 'Hide gloss' : 'Show gloss'}
                onClick={() => setShowGloss(v => !v)}
              />
            </ButtonRail>
          </div>
        </div>
      </Page>
    </WearablesApp>
  );
}
