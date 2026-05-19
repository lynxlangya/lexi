// reader.jsx — Lexi reader main window
// Two directions:
//   "quiet"    — Apple Books / Mail: sidebar TOC, hairline rule, traffic lights in the title bar
//   "composed" — iA Writer: chrome nearly invisible, larger margins, only traffic lights remain
//
// Each window: 1200 × 760, renders as a macOS window with traffic-light controls.
// States: idle | translating | error

// ───────────────────── sample content (public-domain Gatsby ch.1) ─────────────────────

const GATSBY = [
  {
    en: 'In my younger and more vulnerable years my father gave me some advice that I\u2019ve been turning over in my mind ever since.',
    zh: '在我年纪尚轻、阅历未深的那些年里，父亲曾给过我一句忠告，我至今仍在心里反复琢磨。',
  },
  {
    en: '\u201CWhenever you feel like criticizing any one,\u201D he told me, \u201Cjust remember that all the people in this world haven\u2019t had the advantages that you\u2019ve had.\u201D',
    zh: '"每当你想批评别人的时候，"他对我说，"记住，这世上并非所有人都拥有过你所拥有的那些条件。"',
  },
  {
    en: 'He didn\u2019t say any more, but we\u2019ve always been unusually communicative in a reserved way, and I understood that he meant a great deal more than that.',
    zh: '他没再多说什么，但我们父子之间向来不必多言便能心领神会，我明白他这话的分量远不止字面那么简单。',
  },
  {
    en: 'In consequence, I\u2019m inclined to reserve all judgments, a habit that has opened up many curious natures to me and also made me the victim of not a few veteran bores.',
    zh: '因此，我习惯了对一切都不轻易下判断，这种习惯让我得以窥见许多有趣的灵魂，也让我成了不少老资格闲谈者的牺牲品。',
  },
  {
    en: 'The abnormal mind is quick to detect and attach itself to this quality when it appears in a normal person, and so it came about that in college I was unjustly accused of being a politician, because I was privy to the secret griefs of wild, unknown men.',
    zh: '怪人善于嗅出常人身上这一品质并迅速亲近过来，于是大学时代我便被人冤枉地称作"政客"——只因我被那些素昧平生的狂人当作秘密苦楚的倾诉对象。',
  },
];

const TOC = [
  { n: 'I',    title: 'In my younger years',        active: false, read: true },
  { n: 'II',   title: 'About half way between West Egg', active: false, read: true },
  { n: 'III',  title: 'There was music from my neighbor\u2019s house', active: true,  read: false },
  { n: 'IV',   title: 'On Sunday morning',          active: false, read: false },
  { n: 'V',    title: 'When I came home to West Egg', active: false, read: false },
  { n: 'VI',   title: 'About this time',             active: false, read: false },
  { n: 'VII',  title: 'It was when curiosity about Gatsby', active: false, read: false },
  { n: 'VIII', title: 'I couldn\u2019t sleep all night',     active: false, read: false },
  { n: 'IX',   title: 'After two years I remember',  active: false, read: false },
];

// ───────────────────────── window chrome ─────────────────────────

function TrafficLights() {
  return (
    <div style={{display:'flex', gap: 8, alignItems:'center'}}>
      <span style={{width: 12, height: 12, borderRadius: '50%', background:'#ff5f57', boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
      <span style={{width: 12, height: 12, borderRadius: '50%', background:'#febc2e', boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
      <span style={{width: 12, height: 12, borderRadius: '50%', background:'#28c840', boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
    </div>
  );
}

// minimal SF-Symbol-ish glyphs (stroked, 14px)
function Icon({ name, size = 15, color = 'currentColor' }) {
  const s = { width: size, height: size, fill:'none', stroke: color, strokeWidth: 1.4, strokeLinecap:'round', strokeLinejoin:'round' };
  switch (name) {
    case 'sidebar':
      return <svg {...s} viewBox="0 0 16 16"><rect x="2" y="3.5" width="12" height="9" rx="1.5"/><line x1="6.2" y1="3.5" x2="6.2" y2="12.5"/></svg>;
    case 'aMinus':
      return <svg {...s} viewBox="0 0 16 16"><text x="2" y="11" fontFamily="-apple-system" fontSize="9" fontWeight="500" stroke="none" fill={color}>A</text><line x1="9" y1="9" x2="13" y2="9"/></svg>;
    case 'aPlus':
      return <svg {...s} viewBox="0 0 16 16"><text x="1" y="12" fontFamily="-apple-system" fontSize="12" fontWeight="500" stroke="none" fill={color}>A</text><line x1="10.5" y1="9" x2="14" y2="9"/><line x1="12.25" y1="7.25" x2="12.25" y2="10.75"/></svg>;
    case 'moon':
      return <svg {...s} viewBox="0 0 16 16"><path d="M12.5 9.2A5 5 0 1 1 6.8 3.5a4 4 0 0 0 5.7 5.7Z"/></svg>;
    case 'sun':
      return <svg {...s} viewBox="0 0 16 16"><circle cx="8" cy="8" r="2.6"/><path d="M8 1.5v1.7M8 12.8v1.7M1.5 8h1.7M12.8 8h1.7M3.4 3.4l1.2 1.2M11.4 11.4l1.2 1.2M3.4 12.6l1.2-1.2M11.4 4.6l1.2-1.2"/></svg>;
    case 'lang':
      return <svg {...s} viewBox="0 0 16 16"><path d="M2 4h6M5 2.5v1.5M3.6 4c.3 2.4 1.6 4 3.4 5M6.4 4c-.3 2.4-1.8 4-3.6 5"/><path d="M8.5 13.5l2.3-5.5h.4l2.3 5.5M9.4 11.7h3.2"/></svg>;
    case 'engine':
      return <svg {...s} viewBox="0 0 16 16"><circle cx="8" cy="8" r="2"/><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"/></svg>;
    case 'more':
      return <svg {...s} viewBox="0 0 16 16"><circle cx="3.5" cy="8" r=".7" fill={color} stroke="none"/><circle cx="8" cy="8" r=".7" fill={color} stroke="none"/><circle cx="12.5" cy="8" r=".7" fill={color} stroke="none"/></svg>;
    case 'back':
      return <svg {...s} viewBox="0 0 16 16"><path d="M9.5 3.5 5 8l4.5 4.5"/></svg>;
    case 'warn':
      return <svg {...s} viewBox="0 0 16 16"><path d="M8 2 14 13H2Z"/><line x1="8" y1="6.5" x2="8" y2="9.5"/><circle cx="8" cy="11.2" r=".4" fill={color} stroke="none"/></svg>;
    case 'speaker':
      return <svg {...s} viewBox="0 0 16 16"><path d="M3 6h2l3-2.5v9L5 10H3z"/><path d="M10.5 6c.8.5 1.2 1.2 1.2 2s-.4 1.5-1.2 2"/></svg>;
    case 'copy':
      return <svg {...s} viewBox="0 0 16 16"><rect x="5" y="5" width="8" height="8" rx="1.5"/><path d="M3 11V4a1 1 0 0 1 1-1h7"/></svg>;
    case 'plus':
      return <svg {...s} viewBox="0 0 16 16"><line x1="8" y1="3.5" x2="8" y2="12.5"/><line x1="3.5" y1="8" x2="12.5" y2="8"/></svg>;
    case 'spinner':
      return <svg {...s} viewBox="0 0 16 16"><circle cx="8" cy="8" r="5.5" strokeOpacity=".25"/><path d="M13.5 8a5.5 5.5 0 0 0-5.5-5.5"/></svg>;
    default: return null;
  }
}

function IconBtn({ name, t, hot }) {
  return (
    <button style={{
      width: 26, height: 22, padding: 0, border: 'none', background: hot ? t.accentSoft : 'transparent',
      color: hot ? t.accent : t.ink3, borderRadius: 4, cursor: 'pointer',
      display:'flex', alignItems:'center', justifyContent:'center',
    }}>
      <Icon name={name} />
    </button>
  );
}

// ─────────────────────── paragraph block ───────────────────────

function Para({ p, t, idx, state, selectedIdx }) {
  const selected = selectedIdx === idx;
  // states for translation slot: 'ready' | 'loading' | 'error'
  let zhState = 'ready';
  if (state === 'translating' && idx >= 3) zhState = 'loading';
  if (state === 'error' && idx === 2) zhState = 'error';
  return (
    <div style={{marginBottom: 28}}>
      <p style={{
        margin: 0,
        fontFamily: SERIF, fontSize: 17, lineHeight: 1.72, color: t.ink,
        letterSpacing:'-.003em',
      }}>
        {selected ? (
          <>
            {p.en.slice(0, 84)}
            <span style={{background: t.sel, padding:'1px 0', borderRadius: 2}}>{p.en.slice(84, 106)}</span>
            {p.en.slice(106)}
          </>
        ) : p.en}
      </p>
      <div style={{height: 6}} />
      {zhState === 'ready' && (
        <p style={{
          margin: 0, fontFamily: ZH, fontSize: 13.5, lineHeight: 1.78,
          color: t.ink2, letterSpacing: '.01em',
        }}>{p.zh}</p>
      )}
      {zhState === 'loading' && (
        <div style={{display:'flex', flexDirection:'column', gap: 6}}>
          <div style={{height: 11, width:'92%', borderRadius: 3,
            background: `linear-gradient(90deg, ${t.shimmer1}, ${t.shimmer2}, ${t.shimmer1})`,
            backgroundSize: '200% 100%', animation: 'lexiShimmer 1.6s linear infinite',
          }} />
          <div style={{height: 11, width:'64%', borderRadius: 3,
            background: `linear-gradient(90deg, ${t.shimmer1}, ${t.shimmer2}, ${t.shimmer1})`,
            backgroundSize: '200% 100%', animation: 'lexiShimmer 1.6s linear infinite',
            animationDelay: '.15s',
          }} />
        </div>
      )}
      {zhState === 'error' && (
        <div style={{
          display:'flex', alignItems:'center', gap: 10,
          fontFamily: ZH, fontSize: 12.5, color: t.warn,
        }}>
          <Icon name="warn" size={13} color={t.warn} />
          <span style={{color: t.ink3}}>本段翻译失败</span>
          <button style={{
            background:'transparent', border: `1px solid ${t.rule2}`, color: t.ink2,
            fontFamily: SANS, fontSize: 11.5, padding:'2px 8px', borderRadius: 4,
            cursor:'pointer',
          }}>重试本段</button>
        </div>
      )}
    </div>
  );
}

// ─────────────────────── sidebar ───────────────────────

function Sidebar({ t, direction }) {
  return (
    <aside style={{
      width: 232, flex:'0 0 232px',
      background: direction === 'quiet' ? t.bgRaised : 'transparent',
      borderRight: `1px solid ${direction === 'quiet' ? t.rule : 'transparent'}`,
      padding: '52px 14px 24px',
      display:'flex', flexDirection:'column', gap: 18,
    }}>
      <div style={{padding:'0 8px'}}>
        <div style={{fontFamily: SANS, fontSize: 10.5, color: t.ink3,
          textTransform:'uppercase', letterSpacing:'.1em', fontWeight: 600, marginBottom: 6}}>Book</div>
        <div style={{fontFamily: SERIF, fontSize: 14, color: t.ink, lineHeight: 1.3, letterSpacing:'-.005em'}}>The Great Gatsby</div>
        <div style={{fontFamily: SANS, fontSize: 11.5, color: t.ink3, marginTop: 2}}>F. Scott Fitzgerald</div>
      </div>

      <div style={{height: 1, background: t.rule, margin: '0 8px'}} />

      <nav style={{display:'flex', flexDirection:'column', gap: 1}}>
        {TOC.map((c) => (
          <a key={c.n} style={{
            display:'flex', alignItems:'baseline', gap: 10,
            padding:'6px 10px', borderRadius: 5,
            background: c.active ? t.accentSoft : 'transparent',
            color: c.active ? t.accent : (c.read ? t.ink3 : t.ink),
            fontFamily: SANS, fontSize: 12.5, lineHeight: 1.35,
            textDecoration:'none', cursor:'pointer',
          }}>
            <span style={{
              flex:'0 0 28px', fontFamily: MONO, fontSize: 10.5,
              color: c.active ? t.accent : t.ink3, letterSpacing:'.04em',
            }}>{c.n}</span>
            <span style={{flex: 1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap',
              fontWeight: c.active ? 500 : 400,
            }}>{c.title}</span>
          </a>
        ))}
      </nav>
    </aside>
  );
}

// ─────────────────────── reader window ───────────────────────

function ReaderWindow({ theme = 'light', direction = 'quiet', state = 'idle', selectedIdx = null, showSidebar = true }) {
  const t = TOKENS[theme];
  const W = 1200, H = 760;
  const composed = direction === 'composed';
  const sidebarVisible = showSidebar && !composed;

  return (
    <div style={{
      width: W, height: H, background: t.bg, color: t.ink,
      borderRadius: RADII.window, overflow:'hidden',
      boxShadow: theme === 'dark'
        ? '0 1px 0 rgba(255,255,255,.04) inset, 0 30px 80px rgba(0,0,0,.45), 0 0 0 1px rgba(0,0,0,.6)'
        : '0 30px 80px rgba(60,40,20,.18), 0 0 0 1px rgba(0,0,0,.08)',
      display:'flex', flexDirection:'column', position:'relative',
      fontFeatureSettings:'"kern","liga","calt"',
    }}>
      {/* title bar */}
      <div style={{
        height: composed ? 38 : 44,
        background: t.chrome, backdropFilter:'blur(20px)',
        borderBottom: composed ? 'none' : `1px solid ${t.rule}`,
        display:'flex', alignItems:'center',
        padding: '0 16px', position:'relative', flex:'0 0 auto',
      }}>
        <TrafficLights />

        {/* center label (chapter title / progress) */}
        <div style={{
          position:'absolute', left:'50%', top:'50%', transform:'translate(-50%,-50%)',
          fontFamily: SANS, fontSize: 12, color: t.ink3,
          display:'flex', alignItems:'center', gap: 8,
        }}>
          {!composed && (
            <>
              <Icon name="back" size={12} color={t.ink3} />
              <span style={{color: t.ink2}}>The Great Gatsby</span>
              <span style={{color: t.ink4}}>·</span>
            </>
          )}
          <span style={{
            fontFamily: composed ? MONO : SANS,
            fontSize: composed ? 10.5 : 12,
            color: t.ink3,
            letterSpacing: composed ? '.12em' : 0,
            textTransform: composed ? 'uppercase' : 'none',
          }}>Chapter III · 3 / 9</span>
        </div>

        {/* right tools */}
        <div style={{marginLeft:'auto', display:'flex', alignItems:'center', gap: 2}}>
          {!composed && <IconBtn name="sidebar" t={t} hot={sidebarVisible} />}
          {!composed && <div style={{width: 1, height: 14, background: t.rule, margin: '0 6px'}} />}
          <IconBtn name="aMinus" t={t} />
          <IconBtn name="aPlus" t={t} />
          <div style={{width: 1, height: 14, background: t.rule, margin: '0 4px'}} />
          <IconBtn name="lang" t={t} hot={true} />
          {!composed && <IconBtn name="moon" t={t} hot={theme === 'dark'} />}
          {!composed && <IconBtn name="more" t={t} />}
        </div>
      </div>

      {/* body */}
      <div style={{flex: 1, display:'flex', minHeight: 0, position:'relative'}}>
        {sidebarVisible && <Sidebar t={t} direction={direction} />}

        {/* reading column */}
        <main style={{
          flex: 1, overflow:'hidden', position:'relative',
          padding: composed ? '88px 80px 56px' : '64px 80px 48px',
        }}>
          <div style={{
            maxWidth: SPACING.contentMax, margin:'0 auto',
            position:'relative',
          }}>
            {/* chapter header */}
            <header style={{marginBottom: 44}}>
              <div style={{
                fontFamily: composed ? MONO : SANS,
                fontSize: composed ? 10.5 : 11,
                color: t.ink3, letterSpacing: composed ? '.16em' : '.08em',
                textTransform:'uppercase', marginBottom: 12, fontWeight: 600,
              }}>{composed ? 'Chapter Three' : 'Chapter III'}</div>
              <h1 style={{
                margin: 0,
                fontFamily: SERIF, fontSize: composed ? 32 : 28,
                lineHeight: 1.18, letterSpacing: '-.014em',
                color: t.ink, fontWeight: composed ? 400 : 500,
                fontStyle: composed ? 'italic' : 'normal',
              }}>There was music from my neighbor's house through the summer nights.</h1>
              <div style={{height: 14}} />
              <div style={{
                fontFamily: ZH, fontSize: 14, color: t.ink2, letterSpacing:'.01em',
                lineHeight: 1.6,
              }}>整个夏夜，邻家始终乐声不息。</div>
            </header>

            {GATSBY.map((p, i) => <Para key={i} p={p} t={t} idx={i} state={state} selectedIdx={selectedIdx} />)}
          </div>

          {/* edge progress hairline */}
          <div style={{
            position:'absolute', left: 0, right: 0, bottom: 0, height: 1,
            background: t.rule,
          }}>
            <div style={{height:'100%', width: '34%', background: t.accent, opacity: .55}} />
          </div>
        </main>
      </div>

      {/* bottom status row */}
      <div style={{
        flex:'0 0 auto', height: composed ? 24 : 28,
        display:'flex', alignItems:'center', justifyContent:'space-between',
        padding:'0 18px',
        fontFamily: SANS, fontSize: 10.5, color: t.ink3,
        borderTop: composed ? 'none' : `1px solid ${t.rule}`,
        background: composed ? 'transparent' : t.chrome,
      }}>
        <span style={{letterSpacing:'.02em'}}>
          {state === 'translating'
            ? <span style={{display:'inline-flex', alignItems:'center', gap: 6, color: t.accent}}>
                <span style={{display:'inline-block', width: 10, height: 10, animation:'lexiSpin 1.2s linear infinite'}}>
                  <Icon name="spinner" size={10} color={t.accent} />
                </span>
                正在翻译第 4-5 段
              </span>
            : `阅读约剩 38 分钟`}
        </span>
        <span style={{fontFamily: MONO, letterSpacing:'.06em'}}>
          34% · 全书 12%
        </span>
      </div>
    </div>
  );
}

Object.assign(window, { ReaderWindow, Icon, TrafficLights, GATSBY });
