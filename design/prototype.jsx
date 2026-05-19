// prototype.jsx — Lexi interactive prototype top-level component.
// Pulls together state, keyboard shortcuts, selection→popup, and Tweaks.

function Reader() {
  const [tw, setTw] = useTweaks(DEFAULTS);

  // Theme-aware tokens, overridden by user-picked accent.
  const accent = (tw.theme === 'dark' ? ACCENTS_DARK : ACCENTS)[tw.accentIdx] || (tw.theme === 'dark' ? ACCENTS_DARK[0] : ACCENTS[0]);
  const t = useMemo(() => deriveTokens(TOKENS[tw.theme], accent), [tw.theme, accent]);
  const serif = SERIF_CHOICES[tw.serif] || SERIF_CHOICES['New York'];

  // Runtime state
  const [view, setView] = useState('reader');     // 'reader' | 'shelf'
  const [book, setBook] = useState({
    id: 'gatsby', title: 'The Great Gatsby', author: 'F. Scott Fitzgerald',
    cover: { bg: '#d8c4a0', ink: '#1f1b15' },
  });
  const [chapterIdx, setChapterIdx] = useState(2);  // start in Ch III
  const [chapState, setChapState] = useState({
    0: { status: 'cached', done: 999 },
    1: { status: 'cached', done: 999 },
    2: { status: 'cached', done: 999 },
  });
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [popup, setPopup] = useState(null);  // { kind, x, y, text, word }
  const [engineMenuOpen, setEngineMenuOpen] = useState(false);
  const [moreMenuOpen, setMoreMenuOpen] = useState(false);
  const [popupEngine, setPopupEngine] = useState('GPT');
  const [chapterEngine, setChapterEngine] = useState('GPT-4');
  const [scrollPct, setScrollPct] = useState(0);
  const [vocabCount, setVocabCount] = useState(12);
  const [toast, setToast] = useState(null);  // { msg }

  const scrollRef = useRef(null);
  const popRef = useRef(null);

  const currentStatus = chapState[chapterIdx]?.status || 'idle';
  const currentDone = chapState[chapterIdx]?.done || 0;

  // ── chapter switch: scroll to top, kick off streaming translation if idle ──
  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = 0;
    setScrollPct(0);
    if (!chapState[chapterIdx]) {
      // begin streaming translation
      setChapState((s) => ({ ...s, [chapterIdx]: { status: 'translating', done: 0 } }));
    }
    // close any open menus on chapter change
    setMoreMenuOpen(false); setEngineMenuOpen(false); setPopup(null);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chapterIdx]);

  // ── streaming translation effect ──
  useEffect(() => {
    const s = chapState[chapterIdx];
    if (!s || s.status !== 'translating') return;
    const total = CHAPTERS[chapterIdx].paras.length;
    if (s.done >= total) {
      setChapState((cs) => ({ ...cs, [chapterIdx]: { status: 'cached', done: total } }));
      return;
    }
    const id = setTimeout(() => {
      setChapState((cs) => {
        const cur = cs[chapterIdx];
        if (!cur || cur.status !== 'translating') return cs;
        return { ...cs, [chapterIdx]: { ...cur, done: cur.done + 1 } };
      });
    }, 380 + Math.random() * 250);
    return () => clearTimeout(id);
  }, [chapState, chapterIdx]);

  // ── selection → popup ──
  const handleSelectionMouseUp = useCallback(() => {
    setTimeout(() => {
      const sel = window.getSelection();
      const text = sel ? sel.toString().trim() : '';
      if (!text || text.length < 2) return;
      // ignore selection inside popup / menus
      const anchor = sel.anchorNode && sel.anchorNode.nodeType === 3 ? sel.anchorNode.parentElement : sel.anchorNode;
      if (anchor && popRef.current && popRef.current.contains(anchor)) return;

      const range = sel.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      const wordCount = text.split(/\s+/).filter(Boolean).length;
      const isWord = wordCount === 1 && /^[a-zA-Z'\u2019-]+$/.test(text);
      openPopup({
        kind: 'loading',
        x: rect.left + rect.width / 2,
        y: rect.bottom + 8,
        text, word: isWord ? text : null,
        targetKind: isWord ? 'word' : 'sentence',
      });
    }, 10);
  }, []);

  function openPopup(p) {
    setPopup(p);
    // simulate engine round trip
    if (p.kind === 'loading') {
      const delay = p.targetKind === 'word' ? 380 : 720;
      setTimeout(() => {
        setPopup((cur) => {
          if (!cur || cur.text !== p.text) return cur;
          return { ...cur, kind: cur.targetKind };
        });
      }, delay);
    }
  }

  function closePopup() {
    setPopup(null);
    const sel = window.getSelection();
    if (sel) sel.removeAllRanges();
  }

  // ── keyboard ──
  useEffect(() => {
    const onKey = (e) => {
      // ⌘⇧L
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'l') {
        e.preventDefault();
        const sel = window.getSelection();
        const text = sel ? sel.toString().trim() : '';
        if (!text) { flash('请先选中要翻译的文字'); return; }
        const range = sel.getRangeAt(0);
        const rect = range.getBoundingClientRect();
        const wordCount = text.split(/\s+/).filter(Boolean).length;
        const isWord = wordCount === 1 && /^[a-zA-Z'\u2019-]+$/.test(text);
        openPopup({ kind:'loading', x: rect.left + rect.width/2, y: rect.bottom + 8,
          text, word: isWord ? text : null, targetKind: isWord ? 'word' : 'sentence' });
      }
      // Esc
      if (e.key === 'Escape') {
        if (popup) closePopup();
        setMoreMenuOpen(false); setEngineMenuOpen(false);
      }
      // ⌘0 sidebar
      if ((e.metaKey || e.ctrlKey) && e.key === '0') {
        e.preventDefault();
        setTw('showSidebar', !tw.showSidebar);
      }
      // ⌘[ / ⌘] for chapter nav
      if ((e.metaKey || e.ctrlKey) && (e.key === ']' || e.key === '[')) {
        e.preventDefault();
        const delta = e.key === ']' ? 1 : -1;
        const next = Math.max(0, Math.min(CHAPTERS.length - 1, chapterIdx + delta));
        setChapterIdx(next);
      }
      // ⌘+ / ⌘- font
      if ((e.metaKey || e.ctrlKey) && (e.key === '=' || e.key === '+')) {
        e.preventDefault();
        setTw('fontSize', Math.min(22, (tw.fontSize || 17) + 1));
      }
      if ((e.metaKey || e.ctrlKey) && (e.key === '-')) {
        e.preventDefault();
        setTw('fontSize', Math.max(14, (tw.fontSize || 17) - 1));
      }
      // ⌘, open settings
      if ((e.metaKey || e.ctrlKey) && e.key === ',') {
        e.preventDefault();
        setSettingsOpen(true);
      }
      // ⌘B cycle translation mode
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'b' && !e.shiftKey) {
        e.preventDefault();
        cycleTrans();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [popup, tw.showSidebar, tw.fontSize, tw.transMode, chapterIdx]);

  // ── click outside popup closes ──
  useEffect(() => {
    if (!popup) return;
    const onDown = (e) => {
      if (popRef.current && popRef.current.contains(e.target)) return;
      closePopup();
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [popup]);

  // ── menu outside-click ──
  useEffect(() => {
    if (!moreMenuOpen && !engineMenuOpen) return;
    const onDown = (e) => {
      if (e.target.closest('[data-menu]') || e.target.closest('[data-menu-trigger]')) return;
      setMoreMenuOpen(false); setEngineMenuOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [moreMenuOpen, engineMenuOpen]);

  // ── scroll progress ──
  function onScroll(e) {
    const el = e.currentTarget;
    const pct = el.scrollHeight <= el.clientHeight ? 1
      : el.scrollTop / (el.scrollHeight - el.clientHeight);
    setScrollPct(Math.max(0, Math.min(1, pct)));
  }

  // ── flash toast ──
  function flash(msg) {
    setToast({ msg });
    setTimeout(() => setToast(null), 1600);
  }

  // ── line height — settings.lineH ('tight' | 'normal' | 'loose') wins, else font-size derived ──
  const lineHeight = tw.lineH === 'tight' ? 1.55
    : tw.lineH === 'loose' ? 1.85
    : tw.lineH === 'normal' ? 1.72
    : tw.fontSize >= 19 ? 1.78 : tw.fontSize <= 15 ? 1.66 : 1.72;

  // ── book switch ──
  function openBook(b) {
    if (b.id !== book.id) {
      setBook(b);
      // fresh book — clear translation cache so chapter 1 shimmers in
      setChapState({});
      setChapterIdx(0);
      flash(`已打开 · ${b.title}`);
    }
    setView('reader');
  }

  // ── toolbar handlers ──
  const cycleTrans = () => {
    const order = ['both', 'en', 'zh'];
    const next = order[(order.indexOf(tw.transMode) + 1) % 3];
    setTw('transMode', next);
    flash(next === 'both' ? '原文 + 译文' : next === 'en' ? '仅原文' : '仅译文');
  };
  const cycleFont = () => setTw('fontSize', Math.min(22, (tw.fontSize || 17) + 1));
  const shrinkFont = () => setTw('fontSize', Math.max(14, (tw.fontSize || 17) - 1));
  const toggleTheme = () => setTw('theme', tw.theme === 'dark' ? 'light' : 'dark');
  const toggleSidebar = () => setTw('showSidebar', !tw.showSidebar);

  const moreItems = [
    { label: '重新翻译本章',  shortcut:'⌘⇧R', onClick: () => {
      setChapState((s) => ({ ...s, [chapterIdx]: { status: 'translating', done: 0 } }));
      setMoreMenuOpen(false);
    }},
    { label: '清除本章缓存',  onClick: () => {
      setChapState((s) => { const c = {...s}; delete c[chapterIdx]; return c; });
      setMoreMenuOpen(false); flash('本章缓存已清除');
    }},
    { divider: true },
    { label: '导出当前章节 Markdown', disabled: true },
    { label: '查看生词本 ('+vocabCount+')', onClick: () => { flash('生词本 (v2)'); setMoreMenuOpen(false); } },
    { divider: true },
    { label: '设置…', shortcut:'⌘,', onClick: () => { setSettingsOpen(true); setMoreMenuOpen(false); } },
  ];
  const engineItems = [
    { label: 'GPT-4 (Turbo)',  check: chapterEngine==='GPT-4',  onClick: () => { setChapterEngine('GPT-4'); setEngineMenuOpen(false); }},
    { label: 'Claude 3.5',     check: chapterEngine==='Claude', onClick: () => { setChapterEngine('Claude'); setEngineMenuOpen(false); }},
    { label: 'DeepL',          check: chapterEngine==='DeepL',  onClick: () => { setChapterEngine('DeepL'); setEngineMenuOpen(false); }},
    { label: 'Google',         check: chapterEngine==='Google', onClick: () => { setChapterEngine('Google'); setEngineMenuOpen(false); }},
    { divider: true },
    { label: '本地词典 (离线)',  indent: true, disabled: true },
  ];

  return (
    <div style={{
      width:'100vw', height:'100vh', background: t.bg, color: t.ink,
      display:'flex', flexDirection:'column', overflow:'hidden',
      fontFeatureSettings:'"kern","liga","calt"',
    }}>
      {view === 'shelf' ? (
        <ShelfTitleBar t={t} bookCount={SHELF_BOOKS.length}
          onBack={() => setView('reader')} />
      ) : (
        <PTitleBar t={t} theme={tw.theme} chapterIdx={chapterIdx} book={book}
          sidebarOpen={tw.showSidebar} transMode={tw.transMode}
          onToggleSidebar={toggleSidebar}
          onCycleFont={cycleFont} onShrinkFont={shrinkFont}
          onTheme={toggleTheme} onCycleTrans={cycleTrans}
          onEngineMenu={() => { setEngineMenuOpen((v)=>!v); setMoreMenuOpen(false); }}
          onMoreMenu={() => { setMoreMenuOpen((v)=>!v); setEngineMenuOpen(false); }}
          engineMenuOpen={engineMenuOpen} moreMenuOpen={moreMenuOpen}
          hints={tw.showHints}
        />
      )}

      {view === 'reader' && engineMenuOpen && (
        <div data-menu><MiniMenu t={t} theme={tw.theme} items={engineItems} top={48} anchorRight={70} /></div>
      )}
      {view === 'reader' && moreMenuOpen && (
        <div data-menu><MiniMenu t={t} theme={tw.theme} items={moreItems} top={48} anchorRight={12} /></div>
      )}

      {view === 'shelf' ? (
        <ShelfView t={t} theme={tw.theme} currentBookId={book.id}
          onOpenBook={openBook} flash={flash} />
      ) : (
        <div style={{flex: 1, display:'flex', minHeight: 0, position:'relative', transform:'translateZ(0)'}}>
          {tw.showSidebar && (
            <PSidebar t={t} chapterIdx={chapterIdx} chapState={chapState}
              onPick={setChapterIdx} accent={accent} serif={serif}
              book={book} onShelf={() => setView('shelf')} />
          )}

          <ReadingColumn ref={scrollRef}
            t={t} chapterIdx={chapterIdx}
            fontSize={tw.fontSize} lineHeight={lineHeight}
            transMode={tw.transMode} paraStyle={tw.paraStyle}
            status={currentStatus} done={currentDone}
            serif={serif}
            onSelection={handleSelectionMouseUp}
            onScroll={onScroll}
            onPrev={() => setChapterIdx(Math.max(0, chapterIdx - 1))}
            onNext={() => setChapterIdx(Math.min(CHAPTERS.length - 1, chapterIdx + 1))}
          />
        </div>
      )}

      {/* status bar */}
      <div style={{
        flex:'0 0 auto', height: 28, display:'flex', alignItems:'center',
        padding:'0 14px', justifyContent:'space-between',
        fontFamily: SANS, fontSize: 10.5, color: t.ink3,
        borderTop: `1px solid ${t.rule}`, background: t.chrome,
      }}>
        {view === 'shelf' ? (
          <>
            <span>{SHELF_BOOKS.length} 本书 · 翻译缓存 124 MB</span>
            <span style={{fontFamily: MONO, letterSpacing:'.04em'}}>v1.0 · ⌘⇧L 已激活</span>
          </>
        ) : (
          <>
            <span>
              {currentStatus === 'translating'
                ? <span style={{display:'inline-flex', alignItems:'center', gap: 6, color: t.accent}}>
                    <span style={{display:'inline-block', width: 10, height: 10, animation:'lexiSpin 1.2s linear infinite'}}>
                      <Icon name="spinner" size={10} color={t.accent} />
                    </span>
                    正在翻译 · {chapterEngine} · {currentDone}/{CHAPTERS[chapterIdx].paras.length}
                  </span>
                : <span>本章已缓存 · {chapterEngine}</span>}
            </span>
            <span style={{fontFamily: MONO, letterSpacing:'.06em'}}>
              {Math.round(scrollPct * 100)}% · 全书 {Math.round(((chapterIdx + scrollPct) / CHAPTERS.length) * 100)}%
            </span>
          </>
        )}
      </div>

      {/* edge progress hairline above status bar — reader view only */}
      {view === 'reader' && (
        <div style={{
          position:'absolute', left: tw.showSidebar ? 240 : 0, right: 0, bottom: 28, height: 1,
          background: t.rule, pointerEvents:'none', zIndex: 5,
        }}>
          <div style={{height:'100%', width: `${scrollPct * 100}%`, background: t.accent, opacity: .6,
            transition: 'width .15s linear'}} />
        </div>
      )}

      {/* popup */}
      {popup && (() => {
        const common = { t, theme: tw.theme, x: popup.x, y: popup.y, popRef };
        if (popup.kind === 'loading') return <LoadingCard {...common} text={popup.text} engine={popupEngine} />;
        if (popup.kind === 'word')    return <WordCard    {...common} word={popup.word || popup.text}
          engine={popupEngine} onEngine={setPopupEngine} onClose={closePopup}
          onAddVocab={() => { setVocabCount((v)=>v+1); flash('已加入生词本 · ' + (popup.word || popup.text)); closePopup(); }} />;
        if (popup.kind === 'sentence')return <SentenceCard {...common} text={popup.text}
          engine={popupEngine === 'GPT' ? 'GPT-4' : popupEngine} onEngine={setPopupEngine} onClose={closePopup} />;
        if (popup.kind === 'error')   return <ErrorCard    {...common} onClose={closePopup}
          onRetry={() => openPopup({ ...popup, kind:'loading', targetKind:'sentence' })}
          onSettings={() => { closePopup(); setSettingsOpen(true); }} />;
        return null;
      })()}

      {/* toast */}
      {toast && (
        <div style={{
          position:'fixed', left:'50%', bottom: 56,
          transform:'translateX(-50%)', zIndex: 100,
          background: t.bgRaised, color: t.ink, padding:'8px 14px',
          borderRadius: 8, fontFamily: SANS, fontSize: 12,
          boxShadow: tw.theme === 'dark'
            ? '0 12px 32px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5)'
            : '0 12px 32px rgba(60,40,20,.18), 0 0 0 1px rgba(0,0,0,.08)',
          animation:'lexiPopIn .15s ease-out',
        }}>{toast.msg}</div>
      )}

      {/* keyboard hints (peeled-on first-load helper) */}
      {tw.showHints && (
        <KeyHints t={t} onHide={() => setTw('showHints', false)} />
      )}

      {/* Tweaks panel */}
      <LexiTweaks tw={tw} setTw={setTw} t={t} theme={tw.theme}
        chapterEngine={chapterEngine} setChapterEngine={setChapterEngine} />

      {/* Settings sheet — opened from "更多" menu or ⌘, */}
      {settingsOpen && (
        <SettingsSheet t={t} theme={tw.theme}
          tw={tw} setTw={setTw}
          chapterEngine={chapterEngine} setChapterEngine={setChapterEngine}
          accentSwatches={tw.theme === 'dark' ? ACCENTS_DARK : ACCENTS}
          flash={flash}
          onClose={() => setSettingsOpen(false)}
        />
      )}
    </div>
  );
}

// ───────────────────── keyboard hints overlay ─────────────────────

function KeyHints({ t, onHide }) {
  const rows = [
    ['选中文字 / ⌘⇧L', '划词翻译'],
    ['Esc',             '关闭浮窗 / 菜单'],
    ['⌘[ / ⌘]',         '上一章 / 下一章'],
    ['⌘0',              '切换侧栏'],
    ['⌘+ / ⌘-',         '字号大小'],
  ];
  return (
    <div style={{
      position:'fixed', right: 24, bottom: 72, zIndex: 40,
      background: t.bgRaised, color: t.ink, borderRadius: 10, padding: '14px 16px',
      fontFamily: SANS, fontSize: 11.5, lineHeight: 1.55,
      boxShadow: '0 18px 40px rgba(0,0,0,.25), 0 0 0 1px rgba(0,0,0,.10)',
      minWidth: 220, animation:'lexiPopIn .18s ease-out',
    }}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom: 10}}>
        <span style={{fontWeight: 600, color: t.ink}}>试一下</span>
        <button onClick={onHide} style={{background:'transparent', border:'none', color: t.ink3, cursor:'pointer', fontSize: 16, lineHeight: 1, padding: 0}}>×</button>
      </div>
      <div style={{display:'grid', gridTemplateColumns:'auto 1fr', columnGap: 12, rowGap: 6}}>
        {rows.map((r, i) => (
          <React.Fragment key={i}>
            <span style={{fontFamily: MONO, fontSize: 10.5, color: t.ink2, whiteSpace:'nowrap'}}>{r[0]}</span>
            <span style={{color: t.ink3}}>{r[1]}</span>
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}

// ───────────────────── tweaks panel ─────────────────────

function LexiTweaks({ tw, setTw, t, theme, chapterEngine, setChapterEngine }) {
  const accentSwatches = (theme === 'dark' ? ACCENTS_DARK : ACCENTS);
  return (
    <TweaksPanel title="Lexi · 阅读器设置">
      <TweakSection label="外观">
        <TweakRadio label="主题" value={tw.theme}
          options={[{label:'亮 Paper', value:'light'}, {label:'暗 Candlelit', value:'dark'}]}
          onChange={(v) => setTw('theme', v)} />
        <TweakSelect label="正文衬线" value={tw.serif}
          options={Object.keys(SERIF_CHOICES).map((k) => ({label: k, value: k}))}
          onChange={(v) => setTw('serif', v)} />
        <TweakSlider label="正文字号" value={tw.fontSize} min={14} max={22} step={1} unit="pt"
          onChange={(v) => setTw('fontSize', v)} />
        <AccentRow t={t} value={tw.accentIdx} swatches={accentSwatches}
          onChange={(i) => setTw('accentIdx', i)} />
      </TweakSection>

      <TweakSection label="译文">
        <TweakRadio label="显示" value={tw.transMode}
          options={[{label:'原文+译文', value:'both'}, {label:'仅原文', value:'en'}, {label:'仅译文', value:'zh'}]}
          onChange={(v) => setTw('transMode', v)} />
        <TweakRadio label="视觉强度" value={tw.paraStyle}
          options={[{label:'A 字号', value:'demote'}, {label:'B 竖线', value:'rule'}, {label:'C 底色', value:'tint'}]}
          onChange={(v) => setTw('paraStyle', v)} />
      </TweakSection>

      <TweakSection label="布局">
        <TweakToggle label="显示侧栏目录" value={tw.showSidebar}
          onChange={(v) => setTw('showSidebar', v)} />
        <TweakToggle label="键盘提示" value={tw.showHints}
          onChange={(v) => setTw('showHints', v)} />
      </TweakSection>

      <TweakSection label="翻译引擎">
        <TweakSelect label="段落翻译" value={chapterEngine}
          options={[
            {label:'GPT-4', value:'GPT-4'},
            {label:'Claude 3.5', value:'Claude'},
            {label:'DeepL', value:'DeepL'},
            {label:'Google', value:'Google'},
          ]}
          onChange={setChapterEngine} />
      </TweakSection>
    </TweaksPanel>
  );
}

// ───────────────────── accent swatch row (custom — not in TweaksPanel kit) ─────────────────────

function AccentRow({ t, value, swatches, onChange }) {
  return (
    <div className="twk-row twk-row-h">
      <span className="twk-label">重音色</span>
      <div style={{display:'flex', gap: 8, alignItems:'center', marginLeft:'auto'}}>
        {swatches.map((c, i) => (
          <button key={i} onClick={() => onChange(i)} aria-label={c} style={{
            width: 22, height: 22, padding: 0, borderRadius:'50%',
            background: c, cursor:'pointer',
            border: i === value ? `2px solid ${t.ink}` : '2px solid transparent',
            boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.10)',
            transition: 'border-color .12s',
          }} />
        ))}
      </div>
    </div>
  );
}

// ─── final mount ───
ReactDOM.createRoot(document.getElementById('root')).render(<Reader />);
