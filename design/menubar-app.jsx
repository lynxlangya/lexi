// menubar-app.jsx — Interactive standalone-popup prototype.

const { useState: useStateMP, useEffect: useEffectMP, useRef: useRefMP, useMemo: useMemoMP } = React;

const MP_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "dark",
  "popupVariant": "B",
  "triggerStyle": "chip",
  "popupEngine": "GPT",
  "sentenceEngine": "GPT-4",
  "demoState": "ambient"
}/*EDITMODE-END*/;

const MP_ACCENTS_LIGHT = ['#b35c2c', '#a85a2a', '#7d6644', '#9c4a39'];
const MP_ACCENTS_DARK  = ['#d68a5a', '#d6a35a', '#a89678', '#cf7969'];

// Richer dictionary entries for the standalone (Power) popup — adds example
// + related words on top of the minimal entries.
const RICH = {
  novelist: {
    ipa:'/ˈnɒvəlɪst/',
    senses:[
      { pos:'n.', en:'a writer of novels — extended-form prose fiction', zh:'小说家；以写作长篇虚构作品为业的人' },
    ],
    example:{ en:'She is widely regarded as the most innovative novelist of her generation.',
              zh:'她被普遍认为是同辈中最具创新精神的小说家。' },
    related:['novelistic','novelize','novella','memoirist'],
  },
  terse: {
    ipa:'/tɜːrs/',
    senses:[
      { pos:'adj.', en:'sparing in the use of words; using few words and not seeming polite',
        zh:'简洁的；言简意赅的；（言辞）唐突的、冷淡的' },
      { pos:'adj.', en:'concise to the point of being curt',
        zh:'简短到近乎生硬的' },
    ],
    example:{ en:'He gave a terse reply and walked away.',
              zh:'他冷淡地回了一句便走开了。' },
    related:['curt','laconic','concise','succinct','blunt'],
  },
  declarative: {
    ipa:'/dɪˈklærətɪv/',
    senses:[
      { pos:'adj.', en:'(of a sentence or mood) making a statement',
        zh:'陈述性的；声明的' },
      { pos:'adj.', en:'expressing a clear, definitive position',
        zh:'明确表态的；态度鲜明的' },
    ],
    example:{ en:'Her declarative style left no room for ambiguity.',
              zh:'她那种明确的表达方式不给任何含糊的余地。' },
    related:['assertive','explicit','definite'],
  },
  expatriate: {
    ipa:'/eksˈpætriət/',
    senses:[
      { pos:'n.', en:'a person who lives outside their native country',
        zh:'侨居海外的人；侨民' },
      { pos:'v.', en:'to leave one\u2019s native country to live elsewhere',
        zh:'移居国外' },
    ],
    example:{ en:'Hemingway was one of many expatriate writers in Paris in the 1920s.',
              zh:'海明威是 1920 年代旅居巴黎的众多侨居作家之一。' },
    related:['émigré','exile','expat','foreigner'],
  },
  bohemians: {
    ipa:'/boʊˈhiːmiənz/',
    senses:[
      { pos:'n.', en:'unconventional artists, writers, or intellectuals; people who live socially unorthodox lives',
        zh:'波西米亚人；不羁的艺术家或文人；过着不合常规生活的人' },
    ],
    example:{ en:'Montparnasse in the 1920s was a haven for bohemians from across Europe.',
              zh:'1920 年代的蒙帕纳斯是来自欧洲各地不羁艺术家的避风港。' },
    related:['nonconformists','artists','beatniks','dilettantes'],
  },
  inextricably: {
    ipa:'/ˌɪnɪkˈstrɪkəbli/',
    senses:[
      { pos:'adv.', en:'in a way that is impossible to disentangle or separate',
        zh:'难分难解地；密不可分地' },
    ],
    example:{ en:'His private legend and his published work became inextricably entangled.',
              zh:'他的个人传奇与他的作品从此密不可分地纠缠在一起。' },
    related:['inseparably','indissolubly','tightly'],
  },
  understated: {
    ipa:'/ˌʌndərˈsteɪtɪd/',
    senses:[
      { pos:'adj.', en:'presented or done in a subtle, restrained, or unobtrusive way',
        zh:'含蓄的；克制的；不张扬的' },
    ],
    example:{ en:'His understated influence on modern prose remains incalculable.',
              zh:'他对现代散文那种含蓄的影响至今难以估量。' },
    related:['restrained','subtle','low-key','muted'],
  },
  posthumously: {
    ipa:'/ˈpɒstjuməsli/',
    senses:[
      { pos:'adv.', en:'after the death of the originator',
        zh:'死后地；以遗作形式' },
    ],
    example:{ en:'Three of his novels were published posthumously.',
              zh:'他的三部小说是在他去世之后才出版的。' },
    related:['post-mortem','after death'],
  },
};

function MenuApp() {
  const [tw, setTw] = useTweaks(MP_DEFAULTS);

  // popup state — null when no popup is visible
  // { kind: 'word'|'sentence'|'loading'|'error', x, y, word, text, pinned }
  const [popup, setPopup] = useStateMP(null);
  // trigger chip (between selection and popup, when triggerStyle === 'chip')
  const [trigger, setTrigger] = useStateMP(null);  // { word, x, y, hot }
  // history of recent lookups (Power variant shows as chips)
  const [history, setHistory] = useStateMP(['vulnerable','reserved','privy','grotesque']);
  // toast
  const [toast, setToast] = useStateMP(null);
  // vocab count (decorative)
  const [vocab, setVocab] = useStateMP(184);

  const popRef = useRefMP(null);

  const dark = tw.theme === 'dark';
  const accentList = dark ? MP_ACCENTS_DARK : MP_ACCENTS_LIGHT;
  const accent = accentList[0];
  const t = useMemoMP(() => popTokens(dark, accent), [dark, accent]);

  function flash(msg) {
    setToast({ msg });
    setTimeout(() => setToast(null), 1600);
  }

  // ── hot-spot click handler ────────────────────────────────────────────
  function handleHotspot(key, ev) {
    const rect = ev.currentTarget.getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.bottom + 8;
    setTrigger(null);

    if (key === '__sentence') {
      openPopup({ kind:'loading', text: SENTENCE_TARGET, targetKind: 'sentence', x, y });
      return;
    }

    if (key === 'incalculable') {
      // simulate engine call → resolves to sentence-style note (no dict entry)
      openPopup({ kind:'loading', text:'incalculable', targetKind:'word-fallback', x, y, word:'incalculable' });
      return;
    }

    if (tw.triggerStyle === 'chip') {
      // show chip first; user clicks chip → open popup
      setTrigger({ word: key, x: rect.right, y: rect.top, key, openX: x, openY: y });
      return;
    }

    // instant open
    openPopup({ kind:'loading', word: key, x, y, targetKind: 'word' });
  }

  function openPopup(p) {
    setPopup({ ...p, pinned: false });
    if (p.kind === 'loading') {
      const delay = p.targetKind === 'word' ? 380 : p.targetKind === 'word-fallback' ? 480 : 720;
      setTimeout(() => {
        setPopup((cur) => {
          if (!cur || (cur.text || cur.word) !== (p.text || p.word)) return cur;
          if (p.targetKind === 'word-fallback') {
            // pretend the dictionary has no entry; show as sentence-style instead
            return { ...cur, kind: 'sentence',
              text: p.word, zh: '难以估量的；难以计算的（adj. 文中常作为强调修饰语使用）',
              alt: '不可估量的、无法计量的' };
          }
          return { ...cur, kind: p.targetKind };
        });
      }, delay);
    }
  }

  function closePopup() {
    setPopup(null);
    setTrigger(null);
  }

  // ── click outside closes popup (unless pinned) ────────────────────────
  useEffectMP(() => {
    if (!popup) return;
    const onDown = (e) => {
      if (popRef.current && popRef.current.contains(e.target)) return;
      if (e.target.closest('[data-shelf-ctx]') || e.target.closest('[data-trigger-chip]')) return;
      if (popup.pinned) return;
      closePopup();
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [popup]);

  // ── close trigger chip when clicking anywhere else ─────────────────────
  useEffectMP(() => {
    if (!trigger) return;
    const onDown = (e) => {
      if (e.target.closest('[data-trigger-chip]')) return;
      if (e.target.closest('[data-hot]')) return;
      setTrigger(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [trigger]);

  // ── keyboard: ⌘⇧L cycles demo, Esc closes ─────────────────────────────
  useEffectMP(() => {
    const onKey = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'l') {
        e.preventDefault();
        // pick a random hotspot as a demo selection
        const keys = ['terse','expatriate','bohemians','novelist','understated'];
        const k = keys[Math.floor(Math.random() * keys.length)];
        const els = document.querySelectorAll('[data-hot]');
        const target = [...els].find(el => el.dataset.hot === k);
        if (target) {
          target.click();
          target.scrollIntoView && (target.parentElement.scrollTop = 0);
        }
      }
      if (e.key === 'Escape') {
        setMenuOpen(false);
        setTrigger(null);
        if (popup && !popup.pinned) closePopup();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [popup]);

  const [menuOpen, setMenuOpen] = useStateMP(false);

  // ── selection (real text selection) handler — same UX as click hotspot
  useEffectMP(() => {
    function onMouseUp(e) {
      if (e.target.closest('[data-shelf-ctx]') || e.target.closest('[data-tweaks-panel]')) return;
      if (popRef.current && popRef.current.contains(e.target)) return;

      setTimeout(() => {
        const sel = window.getSelection();
        const text = sel ? sel.toString().trim() : '';
        if (!text || text.length < 2) return;
        // only inside the article container
        const anchor = sel.anchorNode && sel.anchorNode.nodeType === 3 ? sel.anchorNode.parentElement : sel.anchorNode;
        if (!anchor || !anchor.closest('article, .lexi-article, [data-article]') && !anchor.closest('iframe, .safari-content')) {
          // still allow if it's inside the Safari content area — be permissive
        }
        const rect = sel.getRangeAt(0).getBoundingClientRect();
        const x = rect.left + rect.width / 2;
        const y = rect.bottom + 8;
        const wordCount = text.split(/\s+/).filter(Boolean).length;
        const isWord = wordCount === 1 && /^[a-zA-Z'\u2019-]+$/.test(text);
        if (isWord) {
          const lower = text.toLowerCase();
          if (tw.triggerStyle === 'chip') {
            setTrigger({ word: lower, x: rect.right, y: rect.top, key: lower, openX: x, openY: y });
          } else {
            openPopup({ kind:'loading', word: lower, x, y, targetKind:'word' });
          }
        } else {
          openPopup({ kind:'loading', text, x, y, targetKind: text === SENTENCE_TARGET ? 'sentence' : 'sentence' });
        }
      }, 10);
    }
    document.addEventListener('mouseup', onMouseUp);
    return () => document.removeEventListener('mouseup', onMouseUp);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tw.triggerStyle]);

  // ── render popup based on state ───────────────────────────────────────
  function renderPopup() {
    if (!popup) return null;
    const ctx = { t, dark, x: popup.x, y: popup.y };
    if (popup.kind === 'loading') {
      return <LoadingPopV2 ctx={ctx} text={popup.word || popup.text} engine={tw.popupEngine}
        popRef={popRef} pinned={popup.pinned} />;
    }
    if (popup.kind === 'word') {
      const key = (popup.word || popup.text).toLowerCase();
      const entry = RICH[key] || ARTICLE_DICT[key] || {
        ipa:'/'+key.replace(/[^a-z]/g,'')+'/',
        senses:[{ pos:'—', en:'no entry — would call engine here', zh:'词典未收录——会调用翻译引擎' }],
      };
      const isB = tw.popupVariant === 'B';
      const common = { ctx, word: popup.word, entry, popRef,
        pinned: popup.pinned, onPin: () => setPopup((p) => ({ ...p, pinned: !p.pinned })),
        onClose: closePopup,
        engine: tw.popupEngine, onEngine: (e) => setTw('popupEngine', e),
        onAdd: () => { setVocab((v) => v + 1); flash(`已加入生词本 · ${popup.word}`);
          setHistory((h) => [popup.word, ...h.filter((x) => x !== popup.word)].slice(0, 8));
          closePopup(); },
      };
      if (isB) {
        return <WordB {...common} history={history.filter((x) => x !== popup.word)}
          onHistoryPick={(w) => openPopup({ kind:'loading', word: w, x: popup.x, y: popup.y, targetKind:'word' })}
          onSend={() => flash('Demo: 发送到 Lexi 阅读器')} />;
      }
      return <WordA {...common} />;
    }
    if (popup.kind === 'sentence') {
      const ctxS = { ...ctx };
      const zh = popup.zh ?? (popup.text === SENTENCE_TARGET ? SENTENCE_ZH : fakeMenubarTranslate(popup.text));
      const alt = popup.alt ?? (popup.text === SENTENCE_TARGET
        ? '此后他余生先后做了作家、战地记者、渔人、猎人——还做了四次丈夫。'
        : '——');
      const isB = tw.popupVariant === 'B';
      const common = { ctx: ctxS, text: popup.text, zh, popRef,
        pinned: popup.pinned, onPin: () => setPopup((p) => ({ ...p, pinned: !p.pinned })),
        onClose: closePopup,
        engine: tw.sentenceEngine, onEngine: (e) => setTw('sentenceEngine', e),
      };
      if (isB) return <SentenceB {...common} alt={alt} onSend={() => flash('Demo: 发送到 Lexi 阅读器')} />;
      return <SentenceA {...common} />;
    }
    if (popup.kind === 'error') {
      return <ErrorPopV2 ctx={ctx} popRef={popRef}
        onRetry={() => openPopup({ ...popup, kind:'loading', targetKind:'sentence' })}
        onClose={closePopup}
        onSettings={() => { closePopup(); flash('设置 → 引擎'); }} />;
    }
    return null;
  }

  function fakeMenubarTranslate(s) {
    return '（演示用占位翻译）' + s.slice(0, 50) + '…';
  }

  return (
    <div style={{
      width:'100vw', height:'100vh', overflow:'hidden',
      fontFeatureSettings:'"kern","liga","calt"',
    }}>
      <Desktop dark={dark} lexiActive={!!popup}
        onLexiClick={() => setMenuOpen(true)}
        onHotspot={handleHotspot}>

        {/* Lexi menu-bar dropdown — appears when Lexi menubar icon is clicked */}
        {menuOpen && (
          <LexiMenu dark={dark} accent={accent} vocab={vocab}
            onClose={() => setMenuOpen(false)}
            onTrigger={(state) => {
              setMenuOpen(false);
              // open a demo popup at a deterministic location (over the article)
              openPopup({ kind: state, word:'expatriate',
                text: state === 'sentence' ? SENTENCE_TARGET : 'expatriate',
                x: window.innerWidth / 2, y: 360,
                targetKind: state, pinned: false });
            }}
          />
        )}

        {/* Hint at bottom-right */}
        <div style={{
          position:'absolute', right: 16, bottom: 14, zIndex: 40,
          fontFamily: SANS_ENT, fontSize: 11, color: dark ? '#a59889' : '#3a3024',
          background: dark ? 'rgba(28,25,21,.7)' : 'rgba(255,253,247,.85)',
          padding:'6px 10px', borderRadius: 6,
          border: `1px solid ${dark ? 'rgba(0,0,0,.6)' : 'rgba(0,0,0,.08)'}`,
          display:'inline-flex', alignItems:'center', gap: 6,
          backdropFilter: 'blur(8px)',
        }}>
          <span>选中任意单词或点击高亮词 · 或按</span>
          <span style={{fontFamily: MONO_ENT, padding:'1px 5px', borderRadius: 3,
            background: dark ? 'rgba(255,255,255,.06)' : 'rgba(0,0,0,.06)'}}>⌘⇧L</span>
        </div>

        {/* trigger chip (PopClip-style) */}
        {trigger && tw.triggerStyle === 'chip' && (
          <div data-trigger-chip>
            <TriggerChip x={trigger.x} y={trigger.y} dark={dark} accent={accent}
              onClick={() => {
                openPopup({ kind:'loading', word: trigger.word, x: trigger.openX, y: trigger.openY,
                  targetKind: trigger.word === 'incalculable' ? 'word-fallback' : 'word' });
                setTrigger(null);
              }} />
          </div>
        )}

        {/* the popup */}
        {renderPopup()}

        {/* toast */}
        {toast && (
          <div style={{
            position:'fixed', left:'50%', bottom: 80,
            transform:'translateX(-50%)', zIndex: 300,
            background: t.bg, color: t.ink, padding:'8px 14px',
            borderRadius: 8, fontFamily: SANS_ENT, fontSize: 12,
            boxShadow: dark
              ? '0 12px 32px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5)'
              : '0 12px 32px rgba(40,28,14,.18), 0 0 0 1px rgba(0,0,0,.10)',
            animation:'lexiPopIn .15s ease-out',
          }}>{toast.msg}</div>
        )}
      </Desktop>

      {/* Tweaks panel */}
      <div data-tweaks-panel>
        <MenuTweaks tw={tw} setTw={setTw} t={t} dark={dark}
          openDemoPopup={(state) => openPopup({
            kind: state, word: 'expatriate',
            text: state === 'sentence' ? SENTENCE_TARGET : 'expatriate',
            x: window.innerWidth / 2, y: 360,
            targetKind: state,
          })}
          openError={() => openPopup({ kind:'error', x: window.innerWidth / 2, y: 360 })}
        />
      </div>
    </div>
  );
}

// ── Lexi menubar dropdown — appears when the Lexi icon in the system bar is clicked ──
function LexiMenu({ dark, accent, vocab, onClose, onTrigger }) {
  const t = popTokens(dark, accent);
  return (
    <div style={{
      position:'fixed', top: 28, right: 96, zIndex: 250,
      width: 280, background: t.bg, color: t.ink,
      borderRadius: 10, overflow:'hidden',
      boxShadow: dark
        ? '0 20px 50px rgba(0,0,0,.65), 0 0 0 1px rgba(0,0,0,.5)'
        : '0 20px 50px rgba(40,28,14,.22), 0 0 0 1px rgba(0,0,0,.10)',
      animation:'lexiPopIn .14s ease-out', fontFamily: SANS_ENT,
    }}>
      {/* header */}
      <div style={{padding:'12px 14px', borderBottom: `1px solid ${t.rule}`}}>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
          <span style={{fontWeight: 600, fontSize: 13, color: t.ink, letterSpacing:'-.005em'}}>Lexi</span>
          <span style={{fontFamily: MONO_ENT, fontSize: 10.5, color: t.ink3, letterSpacing:'.04em'}}>⌘⇧L</span>
        </div>
        <div style={{fontSize: 11.5, color: t.ink3, marginTop: 2}}>全局划词翻译已激活</div>
      </div>

      {/* quick stats */}
      <div style={{padding:'10px 14px', borderBottom: `1px solid ${t.rule}`,
        display:'grid', gridTemplateColumns:'1fr 1fr', gap: 8, fontSize: 11}}>
        <div>
          <div style={{color: t.ink3, fontSize: 10, textTransform:'uppercase', letterSpacing:'.08em', fontWeight: 600, marginBottom: 2}}>生词本</div>
          <div style={{fontFamily: SERIF_ENT, fontSize: 17, color: t.ink, letterSpacing:'-.005em'}}>{vocab} <span style={{fontSize: 11, color: t.ink3, fontFamily: SANS_ENT}}>词</span></div>
        </div>
        <div>
          <div style={{color: t.ink3, fontSize: 10, textTransform:'uppercase', letterSpacing:'.08em', fontWeight: 600, marginBottom: 2}}>今日查询</div>
          <div style={{fontFamily: SERIF_ENT, fontSize: 17, color: t.ink, letterSpacing:'-.005em'}}>14</div>
        </div>
      </div>

      {/* menu items */}
      <div style={{padding: 6}}>
        {[
          { label:'划词翻译', shortcut:'⌘⇧L', onClick: () => onTrigger('word') },
          { label:'即时翻译选中文字', shortcut:'⌘⇧T', onClick: () => onTrigger('sentence') },
          { label:'打开阅读器…', shortcut:'⌘⇧R' },
          { divider: true },
          { label:'生词本…' },
          { label:'今日复习 (5)', hot: true },
          { divider: true },
          { label:'设置…', shortcut:'⌘,' },
          { label:'退出 Lexi', shortcut:'⌘Q', danger: true },
        ].map((it, i) => it.divider ? (
          <div key={i} style={{height: 1, background: t.rule, margin:'4px 6px'}} />
        ) : (
          <button key={i} onClick={() => { it.onClick && it.onClick(); onClose(); }} style={{
            display:'flex', width:'100%', alignItems:'center', justifyContent:'space-between',
            padding:'6px 10px', borderRadius: 5, border:'none', cursor:'pointer',
            background: it.hot ? t.accentSoft : 'transparent',
            color: it.danger ? t.danger : (it.hot ? t.accent : t.ink),
            fontFamily: SANS_ENT, fontSize: 12.5, fontWeight: it.hot ? 500 : 400,
            textAlign:'left',
          }}
            onMouseEnter={(e) => { if (!it.hot) e.currentTarget.style.background = t.accentSoft; }}
            onMouseLeave={(e) => { e.currentTarget.style.background = it.hot ? t.accentSoft : 'transparent'; }}
          >
            <span>{it.label}</span>
            {it.shortcut && <span style={{fontFamily: MONO_ENT, fontSize: 10.5, color: t.ink3}}>{it.shortcut}</span>}
          </button>
        ))}
      </div>

      {/* backdrop click closes */}
      <div onClick={onClose} style={{
        position:'fixed', inset: 0, zIndex: -1,
      }} />
    </div>
  );
}

// ── Tweaks panel (menubar-specific knobs) ─────────────────────────────────

function MenuTweaks({ tw, setTw, t, dark, openDemoPopup, openError }) {
  return (
    <TweaksPanel title="Lexi · 浮窗原型">
      <TweakSection label="状态触发">
        <TweakButton label="单词卡 · WordCard"     onClick={() => openDemoPopup('word')} />
        <TweakButton label="整句卡 · SentenceCard" onClick={() => openDemoPopup('sentence')} />
        <TweakButton label="加载中 · Loading"      onClick={() => openDemoPopup('loading')} />
        <TweakButton label="错误态 · Error"        onClick={openError} />
      </TweakSection>

      <TweakSection label="外观">
        <TweakRadio label="主题" value={tw.theme}
          options={[{label:'亮', value:'light'}, {label:'暗', value:'dark'}]}
          onChange={(v) => setTw('theme', v)} />
        <TweakRadio label="浮窗方向" value={tw.popupVariant}
          options={[{label:'A · 精简', value:'A'}, {label:'B · 完整', value:'B'}]}
          onChange={(v) => setTw('popupVariant', v)} />
      </TweakSection>

      <TweakSection label="行为">
        <TweakRadio label="触发方式" value={tw.triggerStyle}
          options={[{label:'划词显 chip', value:'chip'}, {label:'即弹', value:'instant'}]}
          onChange={(v) => setTw('triggerStyle', v)} />
        <TweakSelect label="划词默认引擎" value={tw.popupEngine}
          options={[{label:'Dict (本地)', value:'Dict'}, {label:'DeepL', value:'DeepL'},
            {label:'GPT-4', value:'GPT'}, {label:'Claude', value:'Claude'}]}
          onChange={(v) => setTw('popupEngine', v)} />
      </TweakSection>
    </TweaksPanel>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<MenuApp />);
