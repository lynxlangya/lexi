// prototype-popups.jsx — Lexi prototype popovers
// WordCard, SentenceCard, LoadingCard, ErrorCard — all parameterized.

function _PopShell({ t, theme, children, width = 380, x, y, refEl }) {
  // Clamp x/y to viewport
  const W = width, margin = 12;
  const vw = window.innerWidth, vh = window.innerHeight;
  let left = x - W / 2;
  if (left < margin) left = margin;
  if (left + W > vw - margin) left = vw - W - margin;
  let top = y;
  // shift up if going off bottom (rough — we don't know height; assume max 380)
  if (top + 380 > vh - margin) top = Math.max(margin, y - 380 - 16);
  return (
    <div ref={refEl} style={{
      position:'fixed', left, top, width, zIndex: 50,
      background: t.bgRaised, color: t.ink,
      borderRadius: 12, overflow:'hidden',
      boxShadow: theme === 'dark'
        ? '0 24px 60px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5), inset 0 .5px 0 rgba(255,255,255,.05)'
        : '0 22px 50px rgba(60,40,20,.20), 0 0 0 1px rgba(0,0,0,.08), inset 0 .5px 0 rgba(255,255,255,.6)',
      fontFeatureSettings:'"kern","liga","calt"',
      animation: 'lexiPopIn .14s ease-out',
    }}>{children}</div>
  );
}

function _Hdr({ t, label, right }) {
  return (
    <div style={{
      padding:'9px 14px 8px',
      display:'flex', alignItems:'center', justifyContent:'space-between',
      borderBottom: `1px solid ${t.rule}`,
      fontFamily: SANS, fontSize: 11, color: t.ink3,
      letterSpacing:'.06em', textTransform:'uppercase', fontWeight: 600,
    }}>
      <span>{label}</span>
      {right}
    </div>
  );
}

function _Ftr({ t, children }) {
  return (
    <div style={{
      padding:'8px 12px', borderTop: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', justifyContent:'space-between',
      background: t.bg, gap: 8,
    }}>{children}</div>
  );
}

function _Btn({ children, t, primary, onClick }) {
  return (
    <button onClick={onClick} style={{
      background: primary ? t.accent : 'transparent',
      color: primary ? '#fff' : t.ink2,
      border: primary ? 'none' : `1px solid ${t.rule2}`,
      borderRadius: 5, padding:'3px 10px', fontSize: 11.5, fontFamily: SANS,
      cursor:'pointer', display:'inline-flex', alignItems:'center', gap: 5,
      letterSpacing:'.01em',
    }}>{children}</button>
  );
}

function _Pill({ t, active, label, onClick }) {
  return (
    <span onClick={onClick} style={{
      padding:'2px 8px', borderRadius: 4,
      background: active ? t.accentSoft : 'transparent',
      color: active ? t.accent : t.ink3,
      fontFamily: SANS, fontSize: 10.5, fontWeight: active ? 600 : 500,
      letterSpacing:'.02em', cursor:'pointer',
    }}>{label}</span>
  );
}

// ─────────── word card ───────────

function WordCard({ t, theme, x, y, word, engine, onEngine, onClose, popRef, onAddVocab }) {
  const entry = (DICT[(word || '').toLowerCase()]) || {
    ipa: '/'+(word || '').toLowerCase().replace(/[^a-z]/g,'')+'/',
    senses: [{ pos: '—', en: 'word card not in seed dictionary — would call engine here', zh: '种子词典中未收录——实际会调用翻译引擎' }],
  };
  return (
    <_PopShell t={t} theme={theme} x={x} y={y} refEl={popRef}>
      <_Hdr t={t} label="Lexi · 单词" right={
        <span style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em'}}>⌘⇧L · Esc 关闭</span>
      } />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{display:'flex', alignItems:'baseline', gap: 10, flexWrap:'wrap'}}>
          <span style={{fontFamily: SERIF, fontSize: 26, color: t.ink, letterSpacing:'-.01em', fontWeight: 500}}>{word}</span>
          <span style={{fontFamily: MONO, fontSize: 12.5, color: t.ink3, letterSpacing:'.02em'}}>{entry.ipa}</span>
          <button style={{border:'none', background:'transparent', color: t.ink3, padding: 2, cursor:'pointer', display:'flex'}}>
            <Icon name="speaker" size={14} />
          </button>
        </div>
        <div style={{height: 12}} />
        <div style={{display:'flex', flexDirection:'column', gap: 10}}>
          {entry.senses.map((s, i) => (
            <div key={i} style={{display:'flex', gap: 10, alignItems:'flex-start'}}>
              <span style={{flex:'0 0 32px', fontFamily: SERIF, fontStyle:'italic',
                fontSize: 12, color: t.accent, lineHeight: 1.5, paddingTop: 1}}>{s.pos}</span>
              <div style={{flex: 1, minWidth: 0}}>
                <div style={{fontFamily: SERIF, fontSize: 13.5, color: t.ink, lineHeight: 1.5}}>{s.en}</div>
                <div style={{fontFamily: ZH, fontSize: 12.5, color: t.ink2, lineHeight: 1.6, marginTop: 2}}>{s.zh}</div>
              </div>
            </div>
          ))}
        </div>
        <div style={{height: 14}} />
      </div>
      <_Ftr t={t}>
        <div style={{display:'flex', gap: 2, alignItems:'center'}}>
          {['Dict','DeepL','GPT'].map((e) => (
            <_Pill key={e} t={t} active={engine===e} label={e} onClick={() => onEngine(e)} />
          ))}
        </div>
        <div style={{display:'flex', gap: 6}}>
          <_Btn t={t} onClick={() => navigator.clipboard?.writeText(word)}><Icon name="copy" size={11} /> 复制</_Btn>
          <_Btn t={t} primary onClick={onAddVocab}><Icon name="plus" size={11} /> 生词本</_Btn>
        </div>
      </_Ftr>
    </_PopShell>
  );
}

// ─────────── sentence card ───────────

function SentenceCard({ t, theme, x, y, text, engine, onEngine, onClose, popRef }) {
  // a "translation" placeholder — for the prototype, fake it
  const zh = fakeTranslate(text);
  return (
    <_PopShell t={t} theme={theme} x={x} y={y} refEl={popRef}>
      <_Hdr t={t} label="Lexi · 整句" right={
        <span style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em'}}>EN → ZH</span>
      } />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{fontFamily: SERIF, fontSize: 14, color: t.ink2, lineHeight: 1.6, fontStyle:'italic'}}>
          "{text}"
        </div>
        <div style={{height: 1, background: t.rule, margin: '14px 0'}} />
        <div style={{fontFamily: ZH, fontSize: 14.5, color: t.ink, lineHeight: 1.78, letterSpacing:'.01em'}}>
          {zh}
        </div>
      </div>
      <_Ftr t={t}>
        <div style={{display:'flex', gap: 2, alignItems:'center'}}>
          {['DeepL','GPT-4','Google'].map((e) => (
            <_Pill key={e} t={t} active={engine===e} label={e} onClick={() => onEngine(e)} />
          ))}
        </div>
        <div style={{display:'flex', gap: 6}}>
          <_Btn t={t}><Icon name="speaker" size={11} /></_Btn>
          <_Btn t={t} onClick={() => navigator.clipboard?.writeText(zh)}><Icon name="copy" size={11} /> 复制</_Btn>
        </div>
      </_Ftr>
    </_PopShell>
  );
}

// ─────────── loading card ───────────

function LoadingCard({ t, theme, x, y, text, engine, popRef }) {
  return (
    <_PopShell t={t} theme={theme} x={x} y={y} refEl={popRef}>
      <_Hdr t={t} label="Lexi · 翻译中" right={
        <span style={{display:'inline-flex', alignItems:'center', gap: 5, color: t.accent, fontSize: 10.5}}>
          <span style={{display:'inline-block', width: 10, height: 10, animation:'lexiSpin 1.2s linear infinite'}}>
            <Icon name="spinner" size={10} color={t.accent} />
          </span>
          {engine}
        </span>
      } />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{fontFamily: SERIF, fontSize: 14, color: t.ink2, lineHeight: 1.6, fontStyle:'italic', maxHeight: 72, overflow:'hidden'}}>
          "{text}"
        </div>
        <div style={{height: 1, background: t.rule, margin: '14px 0'}} />
        <div style={{display:'flex', flexDirection:'column', gap: 8}}>
          {[100, 92, 64].map((w, i) => (
            <div key={i} style={{
              height: 12, width: `${w}%`, borderRadius: 3,
              background: `linear-gradient(90deg, ${t.shimmer1}, ${t.shimmer2}, ${t.shimmer1})`,
              backgroundSize: '200% 100%',
              animation: `lexiShimmer 1.6s linear infinite`,
              animationDelay: `${i * 0.12}s`,
            }} />
          ))}
        </div>
        <div style={{height: 10}} />
      </div>
    </_PopShell>
  );
}

// ─────────── error card ───────────

function ErrorCard({ t, theme, x, y, popRef, onRetry, onClose, onSettings }) {
  return (
    <_PopShell t={t} theme={theme} x={x} y={y} refEl={popRef}>
      <_Hdr t={t} label="Lexi" right={
        <span style={{display:'inline-flex', alignItems:'center', gap: 5, color: t.warn, fontSize: 10.5, textTransform:'none'}}>
          <Icon name="warn" size={11} color={t.warn} /> 翻译失败
        </span>
      } />
      <div style={{padding:'18px 16px 8px'}}>
        <div style={{fontFamily: SANS, fontSize: 13.5, color: t.ink, fontWeight: 500}}>连接 OpenAI 超时</div>
        <div style={{height: 4}} />
        <div style={{fontFamily: ZH, fontSize: 12.5, color: t.ink2, lineHeight: 1.65}}>
          请求 8 秒未响应。检查网络，或在设置中切换到 DeepL / 本地词典作为后备。
        </div>
        <div style={{marginTop: 12, padding:'8px 10px', borderRadius: 5,
          background: t.bgInset, border: `1px solid ${t.rule}`,
          fontFamily: MONO, fontSize: 10.5, color: t.ink3, letterSpacing:'.02em'}}>
          ETIMEDOUT · api.openai.com:443
        </div>
      </div>
      <_Ftr t={t}>
        <button onClick={onSettings} style={{background:'transparent', border:'none', color: t.ink3,
          fontFamily: SANS, fontSize: 11.5, cursor:'pointer', padding: 0}}>去设置 →</button>
        <div style={{display:'flex', gap: 6}}>
          <_Btn t={t} onClick={onClose}>关闭</_Btn>
          <_Btn t={t} primary onClick={onRetry}>重试</_Btn>
        </div>
      </_Ftr>
    </_PopShell>
  );
}

// ─────────── poor man's translation (prototype only) ───────────
// Looks up first word in DICT; otherwise returns a templated zh string.
function fakeTranslate(text) {
  const lower = text.toLowerCase().trim();
  // try to match against full paragraphs in CHAPTERS for the perfect demo path
  for (const ch of CHAPTERS) {
    for (const p of ch.paras) {
      if (p.en.toLowerCase().includes(lower) && lower.length > 12) {
        // return a slice of the corresponding zh
        return p.zh;
      }
    }
  }
  // word-by-word stub
  const words = text.split(/\s+/).slice(0, 8);
  const stubs = words.map((w) => {
    const ent = DICT[w.toLowerCase().replace(/[^a-z]/gi,'')];
    return ent ? ent.senses[0].zh.split(/[；;，,]/)[0] : '…';
  });
  return stubs.join('，') + '。';
}

Object.assign(window, { WordCard, SentenceCard, LoadingCard, ErrorCard, fakeTranslate });
