// tokens.jsx — Lexi design tokens + foundation preview cards.
// Warm palette: light is paper-cream, dark is candlelit-warm-near-black.
// Accent is a muted copper used SPARINGLY (active chapter, selection, link).

const SERIF = '"New York", "Charter", "Iowan Old Style", Georgia, serif';
const SANS  = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif';
const ZH    = '"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", system-ui, sans-serif';
const MONO  = '"SF Mono", ui-monospace, Menlo, monospace';

const TOKENS = {
  light: {
    name: 'Paper · Light',
    // surfaces
    bg:        '#f5f1e8',   // page paper
    bgRaised:  '#fbf8f1',   // sidebar/toolbar
    bgInset:   '#ede7d8',   // inset (search, code)
    chrome:    '#f1ede2',                 // toolbar (opaque — avoids backdrop-filter quirks)
    // ink
    ink:       '#1f1b15',   // primary (en body, headings)
    ink2:      '#7a7163',   // secondary (zh translation body)  → ~28% lighter than ink
    ink3:      '#a59c89',   // tertiary (chrome labels, hints)
    ink4:      '#c8bfac',   // quaternary (disabled, separators)
    // structure
    rule:      '#e3dccb',
    rule2:     '#cfc6b1',
    // accent (muted copper) — sparingly
    accent:    '#b35c2c',
    accentSoft:'rgba(179,92,44,0.10)',
    accentFaint:'rgba(179,92,44,0.05)',
    // state
    sel:       'rgba(179,92,44,0.16)',
    warn:      '#a85a2a',
    danger:    '#9c4a39',
    // shimmer
    shimmer1:  'rgba(167,158,140,0.10)',
    shimmer2:  'rgba(167,158,140,0.22)',
  },
  dark: {
    name: 'Candlelit · Dark',
    bg:        '#1c1915',
    bgRaised:  '#23201a',
    bgInset:   '#16140f',
    chrome:    '#1f1c17',
    ink:       '#ebe3d0',
    ink2:      '#8e8472',   // zh translation
    ink3:      '#6a6353',
    ink4:      '#3f3a30',
    rule:      '#2b271f',
    rule2:     '#3a342a',
    accent:    '#d68a5a',
    accentSoft:'rgba(214,138,90,0.14)',
    accentFaint:'rgba(214,138,90,0.06)',
    sel:       'rgba(214,138,90,0.20)',
    warn:      '#d68a5a',
    danger:    '#c87060',
    shimmer1:  'rgba(255,240,210,0.04)',
    shimmer2:  'rgba(255,240,210,0.10)',
  },
};

const SPACING = {
  paraGap: 28,    // gap between paragraph-groups (en+zh as one unit)
  enZhGap: 6,     // gap between en line and its zh translation
  contentMax: 660,// reading column max-width
  windowPad: 80,  // page padding around content
};

const RADII = {
  control: 5,     // buttons, inputs (small — mac native)
  card:    10,    // floating popup, cards
  window:  10,    // window corner radius
};

// ───────────────────────── primitives ─────────────────────────

function Swatch({ color, label, hex, dark }) {
  return (
    <div style={{display:'flex', alignItems:'center', gap: 10, minWidth: 0}}>
      <div style={{
        width: 36, height: 36, borderRadius: 6, background: color,
        boxShadow: dark ? 'inset 0 0 0 1px rgba(255,255,255,.06)' : 'inset 0 0 0 1px rgba(0,0,0,.05)',
        flex: '0 0 auto',
      }} />
      <div style={{minWidth:0, fontFamily: SANS, fontSize: 11, lineHeight: 1.35}}>
        <div style={{color: dark ? '#ebe3d0' : '#1f1b15', fontWeight: 500}}>{label}</div>
        <div style={{color: dark ? '#8e8472' : '#a59c89', fontFamily: MONO, fontSize: 10.5, letterSpacing: '.01em'}}>{hex}</div>
      </div>
    </div>
  );
}

function PalettePanel({ mode }) {
  const t = TOKENS[mode];
  const dark = mode === 'dark';
  const groups = [
    { title: 'Surface', items: [['bg','Page'], ['bgRaised','Raised'], ['bgInset','Inset'], ['chrome','Chrome (a)']] },
    { title: 'Ink',     items: [['ink','Primary · 原文'], ['ink2','Secondary · 译文'], ['ink3','Tertiary · chrome'], ['ink4','Quaternary']] },
    { title: 'Rule',    items: [['rule','Hairline'], ['rule2','Divider']] },
    { title: 'Accent',  items: [['accent','Copper'], ['accentSoft','Soft'], ['sel','Selection']] },
  ];
  return (
    <div style={{
      background: t.bg, color: t.ink, padding: 24, fontFamily: SANS,
      border: `1px solid ${t.rule}`, borderRadius: 8, height: '100%',
      display:'flex', flexDirection:'column', gap: 18,
    }}>
      <div style={{display:'flex', alignItems:'baseline', justifyContent:'space-between'}}>
        <div style={{fontSize: 13, fontWeight: 600, letterSpacing:'-.005em'}}>{t.name}</div>
        <div style={{fontSize: 10.5, color: t.ink3, fontFamily: MONO, textTransform:'uppercase', letterSpacing:'.08em'}}>{mode}</div>
      </div>
      {groups.map((g) => (
        <div key={g.title}>
          <div style={{fontSize: 10, color: t.ink3, textTransform:'uppercase', letterSpacing:'.1em', marginBottom: 10, fontWeight: 600}}>{g.title}</div>
          <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap: '10px 14px'}}>
            {g.items.map(([k, label]) => (
              <Swatch key={k} dark={dark} color={t[k]} label={label} hex={t[k]} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function TypeSpecimen({ mode }) {
  const t = TOKENS[mode];
  const dark = mode === 'dark';
  return (
    <div style={{
      background: t.bg, color: t.ink, padding: '28px 32px', fontFamily: SANS,
      border: `1px solid ${t.rule}`, borderRadius: 8, height: '100%',
      display:'flex', flexDirection:'column', gap: 18,
    }}>
      <div style={{fontSize: 13, fontWeight: 600}}>Type · {mode === 'dark' ? '暗色' : '亮色'}</div>

      <div>
        <div style={{fontSize: 10, color: t.ink3, fontFamily: MONO, marginBottom: 6, letterSpacing:'.06em'}}>EN · BODY · 17/29 New York</div>
        <div style={{fontFamily: SERIF, fontSize: 17, lineHeight: 1.72, color: t.ink, letterSpacing: '-.003em'}}>
          In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.
        </div>
        <div style={{height: 4}} />
        <div style={{fontFamily: ZH, fontSize: 13.5, lineHeight: 1.78, color: t.ink2, letterSpacing: '.01em'}}>
          在我年纪尚轻、阅历未深的那些年里，父亲曾给过我一句忠告，我至今仍反复琢磨。
        </div>
      </div>

      <div style={{height: 1, background: t.rule}} />

      <div style={{display:'grid', gridTemplateColumns:'auto 1fr', columnGap: 18, rowGap: 12, alignItems:'baseline'}}>
        <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.05em'}}>H1 · 28/34</div>
        <div style={{fontFamily: SERIF, fontSize: 28, lineHeight: 1.2, color: t.ink, letterSpacing:'-.012em'}}>Chapter I</div>

        <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.05em'}}>H2 · 20/28</div>
        <div style={{fontFamily: SERIF, fontSize: 20, lineHeight: 1.4, color: t.ink}}>A New Beginning</div>

        <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.05em'}}>UI · 13/18</div>
        <div style={{fontFamily: SANS, fontSize: 13, color: t.ink}}>第 3 章 / 共 18 章</div>

        <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.05em'}}>Caption · 11</div>
        <div style={{fontFamily: SANS, fontSize: 11, color: t.ink3, letterSpacing:'.04em', textTransform:'uppercase'}}>The Great Gatsby · F. Scott Fitzgerald</div>

        <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.05em'}}>Mono · 11</div>
        <div style={{fontFamily: MONO, fontSize: 11, color: t.ink2}}>--ink-secondary: {t.ink2}</div>
      </div>
    </div>
  );
}

function SpacingCard({ mode }) {
  const t = TOKENS[mode];
  return (
    <div style={{
      background: t.bg, color: t.ink, padding: '24px 28px', fontFamily: SANS,
      border: `1px solid ${t.rule}`, borderRadius: 8, height: '100%',
      display:'flex', flexDirection:'column', gap: 18,
    }}>
      <div style={{fontSize: 13, fontWeight: 600}}>Rhythm · 段落节律</div>

      <div>
        <div style={{fontSize: 10, color: t.ink3, fontFamily: MONO, marginBottom: 10, letterSpacing:'.06em'}}>PARA GROUP · 28 GAP / 6 INNER GAP</div>
        <div style={{position:'relative', paddingLeft: 18}}>
          <div style={{position:'absolute', left: 0, top: 0, bottom: 0, width: 1, background: t.rule2}} />
          <div style={{fontFamily: SERIF, fontSize: 17, lineHeight: 1.72, color: t.ink}}>He didn't say any more, but we've always been unusually communicative in a reserved way…</div>
          <div style={{height: 6}} />
          <div style={{fontFamily: ZH, fontSize: 13.5, lineHeight: 1.78, color: t.ink2}}>他没再多说什么，但我们父子之间向来不必多言便能心领神会……</div>
          <div style={{height: 28}} />
          <div style={{fontFamily: SERIF, fontSize: 17, lineHeight: 1.72, color: t.ink}}>In consequence, I'm inclined to reserve all judgments.</div>
          <div style={{height: 6}} />
          <div style={{fontFamily: ZH, fontSize: 13.5, lineHeight: 1.78, color: t.ink2}}>因此，我习惯了对一切不轻易下判断。</div>
        </div>
      </div>

      <div style={{height: 1, background: t.rule}} />

      <div style={{display:'grid', gridTemplateColumns:'auto 1fr', columnGap: 14, rowGap: 6, fontFamily: MONO, fontSize: 11, color: t.ink2}}>
        <span style={{color: t.ink3}}>content-max</span><span>660 px</span>
        <span style={{color: t.ink3}}>window-pad</span><span>80 px (顶/底 64 px)</span>
        <span style={{color: t.ink3}}>para-gap</span><span>28 px</span>
        <span style={{color: t.ink3}}>en→zh gap</span><span>6 px</span>
        <span style={{color: t.ink3}}>radius/window</span><span>10 px</span>
        <span style={{color: t.ink3}}>radius/control</span><span>5 px</span>
      </div>
    </div>
  );
}

Object.assign(window, { TOKENS, SERIF, SANS, ZH, MONO, SPACING, RADII, PalettePanel, TypeSpecimen, SpacingCard });
