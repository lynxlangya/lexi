// menubar-stage.jsx — macOS desktop simulation for the global-popup prototype.
// Renders a fake desktop wallpaper + menu bar + Safari-like window with an
// article whose text the user can select. The popup floats above this scene.

const SANS_UI = '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif';
const SANS_TEXT = '"Charter", "Iowan Old Style", "New York", Georgia, serif';

// ── Menu bar ──────────────────────────────────────────────────────────────

function AppleGlyph({ color }) {
  return (
    <svg width="13" height="14" viewBox="0 0 13 14" fill={color}>
      <path d="M10.8 7.4c-.02-2 1.66-3 1.74-3.04-.94-1.4-2.42-1.6-2.94-1.6-1.25-.13-2.44.74-3.08.74-.64 0-1.62-.72-2.66-.7-1.36.02-2.62.78-3.32 2-1.42 2.45-.36 6.07 1.02 8.06.68.96 1.5 2.04 2.56 2 1.02-.04 1.42-.66 2.66-.66 1.24 0 1.6.66 2.7.64 1.11-.02 1.82-.98 2.5-1.96.8-1.12 1.12-2.22 1.14-2.28-.02-.01-2.16-.83-2.18-3.3M8.84 1.85c.56-.68.94-1.62.84-2.55-.81.03-1.78.54-2.36 1.2-.52.58-.98 1.54-.86 2.46.9.07 1.82-.46 2.38-1.11"/>
    </svg>
  );
}

function LexiGlyph({ color, size = 14 }) {
  // brand mark: two stacked bars (original / translation), top with a tiny
  // accent dot. Intentionally abstract — never literal-book.
  return (
    <svg width={size} height={size} viewBox="0 0 16 16">
      <rect x="2" y="5"  width="10" height="2"   rx="1" fill={color} />
      <rect x="2" y="9"  width="7"  height="2"   rx="1" fill={color} opacity=".55" />
      <circle cx="13"   cy="6" r="1" fill={color} />
    </svg>
  );
}

function MenuBar({ dark, lexiActive, onLexiClick }) {
  const bg  = dark ? 'rgba(34,30,24,0.78)' : 'rgba(245,242,235,0.78)';
  const ink = dark ? '#ebe3d0' : '#1a1612';
  const ink3= dark ? '#9a8f7a' : '#6e6655';
  return (
    <div style={{
      position:'absolute', top: 0, left: 0, right: 0, height: 24,
      background: bg,
      borderBottom: `0.5px solid ${dark ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.08)'}`,
      display:'flex', alignItems:'center', padding:'0 12px',
      fontFamily: SANS_UI, fontSize: 13, color: ink,
      zIndex: 100, userSelect:'none',
    }}>
      <span style={{display:'inline-flex', alignItems:'center', marginRight: 14, marginTop: -1}}>
        <AppleGlyph color={ink} />
      </span>
      <span style={{fontWeight: 600, marginRight: 16, letterSpacing:'-.005em'}}>Safari</span>
      {['File','Edit','View','History','Bookmarks','Develop','Window','Help'].map((m) => (
        <span key={m} style={{marginRight: 13, fontWeight: 400, letterSpacing:'-.003em'}}>{m}</span>
      ))}

      <div style={{marginLeft:'auto', display:'flex', alignItems:'center', gap: 14}}>
        {/* battery */}
        <span style={{display:'inline-flex', alignItems:'center', gap: 4, fontSize: 12}}>
          <span style={{color: ink3, marginRight: 1}}>92%</span>
          <svg width="22" height="11" viewBox="0 0 24 12" fill="none" stroke={ink} strokeOpacity=".55" strokeWidth="1">
            <rect x=".5" y=".5" width="20" height="11" rx="2.5"/>
            <line x1="22" y1="4" x2="22" y2="8" strokeOpacity="1" strokeLinecap="round" strokeWidth="1.5"/>
            <rect x="2" y="2" width="17" height="8" rx="1.2" fill={ink} stroke="none" fillOpacity=".75"/>
          </svg>
        </span>
        {/* wifi */}
        <svg width="14" height="11" viewBox="0 0 16 12" fill="none" stroke={ink} strokeWidth="1.3" strokeLinecap="round">
          <path d="M2 4.6a8 8 0 0 1 12 0" opacity=".5"/>
          <path d="M4 6.6a5.2 5.2 0 0 1 8 0" opacity=".75"/>
          <path d="M6 8.6a2.4 2.4 0 0 1 4 0" opacity="1"/>
          <circle cx="8" cy="10.4" r=".7" fill={ink} stroke="none"/>
        </svg>
        {/* control center */}
        <svg width="14" height="11" viewBox="0 0 16 12" fill="none">
          <rect x="1" y="2" width="6.5" height="3" rx="1.5" fill={ink} opacity=".55"/>
          <rect x="8.5" y="2" width="6.5" height="3" rx="1.5" fill={ink} opacity=".55"/>
          <rect x="1" y="7" width="6.5" height="3" rx="1.5" fill={ink} opacity=".55"/>
          <rect x="8.5" y="7" width="6.5" height="3" rx="1.5" fill={ink} opacity=".55"/>
        </svg>
        {/* Lexi! */}
        <button onClick={onLexiClick} title="Lexi · ⌘⇧L"
          aria-pressed={lexiActive}
          style={{
            background: lexiActive ? (dark ? 'rgba(214,138,90,.20)' : 'rgba(179,92,44,.14)') : 'transparent',
            border:'none', padding:'0 4px', height: 20,
            borderRadius: 4, cursor:'pointer',
            display:'inline-flex', alignItems:'center', gap: 5,
            color: lexiActive ? (dark ? '#d68a5a' : '#b35c2c') : ink,
        }}>
          <LexiGlyph color="currentColor" />
        </button>
        {/* time */}
        <span style={{fontSize: 13, letterSpacing:'-.005em', minWidth: 110, textAlign:'right'}}>
          周五 5月15日 22:48
        </span>
      </div>
    </div>
  );
}

// ── Safari window ─────────────────────────────────────────────────────────

function SafariWindow({ dark, children, x = 'center', y = 64, w = 920, h = 600 }) {
  const ink = dark ? '#ebe3d0' : '#1a1612';
  const chromeBg = dark ? '#2a2620' : '#e8e3d6';
  const chromeBg2= dark ? '#2f2a23' : '#efeadd';
  const surface  = dark ? '#1c1814' : '#fbf8f1';
  const rule     = dark ? 'rgba(255,255,255,.06)' : 'rgba(0,0,0,.10)';
  return (
    <div style={{
      position:'absolute',
      left: x === 'center' ? '50%' : x, top: y,
      transform: x === 'center' ? 'translateX(-50%)' : 'none',
      width: w, height: h,
      background: surface,
      borderRadius: 10,
      boxShadow: dark
        ? '0 30px 100px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.7)'
        : '0 30px 80px rgba(40,28,14,.30), 0 0 0 1px rgba(0,0,0,.12)',
      overflow:'hidden',
      fontFamily: SANS_UI, color: ink,
      display:'flex', flexDirection:'column',
    }}>
      {/* title bar with traffic lights + navigation arrows + URL bar */}
      <div style={{
        height: 40, flex:'0 0 auto', background: chromeBg,
        borderBottom: `0.5px solid ${rule}`,
        display:'flex', alignItems:'center', padding:'0 12px', gap: 10,
      }}>
        {/* lights */}
        <div style={{display:'flex', gap: 8, alignItems:'center'}}>
          <span style={{width: 12, height: 12, borderRadius:'50%', background:'#ff5f57', boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
          <span style={{width: 12, height: 12, borderRadius:'50%', background:'#febc2e', boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
          <span style={{width: 12, height: 12, borderRadius:'50%', background:'#28c840', boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
        </div>

        {/* nav arrows */}
        <div style={{display:'flex', gap: 4, marginLeft: 8}}>
          {[true, false].map((enabled, i) => (
            <button key={i} style={{
              width: 26, height: 22, padding: 0, borderRadius: 5,
              background:'transparent', border:'none', cursor:'pointer',
              display:'flex', alignItems:'center', justifyContent:'center',
              opacity: enabled ? .85 : .35,
            }}>
              <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke={ink} strokeWidth="1.5" strokeLinecap="round">
                <path d={i === 0 ? "M9.5 3.5 5 8l4.5 4.5" : "M6.5 3.5 11 8l-4.5 4.5"} />
              </svg>
            </button>
          ))}
        </div>

        {/* sidebar toggle */}
        <button style={{
          width: 26, height: 22, padding: 0, borderRadius: 5,
          background:'transparent', border:'none', cursor:'pointer',
          display:'flex', alignItems:'center', justifyContent:'center',
        }}>
          <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke={ink} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
            <rect x="2" y="3.5" width="12" height="9" rx="1.5"/>
            <line x1="6.2" y1="3.5" x2="6.2" y2="12.5"/>
          </svg>
        </button>

        {/* URL bar */}
        <div style={{
          flex: 1, maxWidth: 560, margin:'0 auto',
          height: 24, borderRadius: 6,
          background: chromeBg2, border: `0.5px solid ${rule}`,
          display:'flex', alignItems:'center', padding:'0 10px', gap: 6,
          fontSize: 12,
        }}>
          <svg width="10" height="10" viewBox="0 0 16 16" fill={ink} fillOpacity=".55">
            <path d="M8 1.5a4 4 0 0 0-4 4v1.7H3a.8.8 0 0 0-.8.8v5.5c0 .44.36.8.8.8h10a.8.8 0 0 0 .8-.8V8a.8.8 0 0 0-.8-.8h-1V5.5a4 4 0 0 0-4-4Zm-2.5 4a2.5 2.5 0 1 1 5 0v1.7h-5V5.5Z"/>
          </svg>
          <span style={{flex: 1, color: ink, opacity:.85, letterSpacing:'-.005em',
            textOverflow:'ellipsis', overflow:'hidden', whiteSpace:'nowrap'}}>
            essays.thereader.io <span style={{opacity:.45}}>/notes/hemingway-a-life-in-brief</span>
          </span>
          <svg width="10" height="10" viewBox="0 0 16 16" fill="none" stroke={ink} strokeOpacity=".6" strokeWidth="1.4" strokeLinecap="round">
            <path d="M4.5 7 8 3.5 11.5 7M8 3.5v9"/>
          </svg>
        </div>

        {/* right side: tabs btn + extensions */}
        <button style={{
          width: 26, height: 22, padding: 0, borderRadius: 5,
          background:'transparent', border:'none', cursor:'pointer',
          display:'flex', alignItems:'center', justifyContent:'center', marginLeft:'auto',
        }}>
          <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke={ink} strokeWidth="1.4" strokeLinecap="round">
            <rect x="2" y="3" width="5" height="5" rx="1"/>
            <rect x="9" y="3" width="5" height="5" rx="1"/>
            <rect x="2" y="10" width="5" height="3" rx="1"/>
            <rect x="9" y="10" width="5" height="3" rx="1"/>
          </svg>
        </button>
      </div>

      {/* tab strip */}
      <div style={{
        height: 32, flex:'0 0 auto', background: chromeBg,
        borderBottom: `0.5px solid ${rule}`,
        display:'flex', alignItems:'stretch', padding:'4px 6px 0', gap: 4,
      }}>
        {[
          { title:'Hemingway · A Life in Brief',          active: true },
          { title:'The Sun Also Rises — Wikipedia',       active: false },
          { title:'Lost Generation expats in 1920s Paris', active: false },
          { title:'Pinterest · vintage typography',       active: false },
        ].map((tab, i) => (
          <div key={i} style={{
            flex: '1 1 0', maxWidth: 200,
            background: tab.active ? surface : 'transparent',
            borderRadius: 5,
            display:'flex', alignItems:'center', padding:'0 10px', gap: 6,
            fontSize: 11.5, letterSpacing:'-.003em',
            color: tab.active ? ink : `${ink}aa`,
            borderLeft: i > 0 && !tab.active ? `0.5px solid ${rule}` : 'none',
          }}>
            <span style={{flex: 1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{tab.title}</span>
            <span style={{opacity: .4, cursor:'pointer'}}>×</span>
          </div>
        ))}
        <button style={{
          flex:'0 0 28px', background:'transparent', border:'none', cursor:'pointer',
          color: ink, opacity:.5, fontSize: 16, lineHeight: 1,
        }}>+</button>
      </div>

      {/* page content */}
      <div style={{flex: 1, overflow:'auto', position:'relative'}}>
        {children}
      </div>
    </div>
  );
}

// ── Article content with click-to-lookup hot spots ────────────────────────

// hot spots in the article — clicking these triggers a popup near the spot
// with state determined by the hotspot's kind.
const ARTICLE_HOT = {
  novelist:           { kind:'word' },
  terse:              { kind:'word' },
  declarative:        { kind:'word' },
  expatriate:         { kind:'word' },
  bohemians:          { kind:'word' },
  inextricably:       { kind:'word' },
  understated:        { kind:'word' },
  posthumously:       { kind:'word' },
  // a sentence
  '__sentence':       { kind:'sentence' },
  // an out-of-dict word
  incalculable:       { kind:'loading' },
};

const ARTICLE_DICT = {
  novelist:    { ipa:'/ˈnɒvəlɪst/',    senses:[{ pos:'n.', en:'a writer of novels', zh:'小说家' }]},
  terse:       { ipa:'/tɜːrs/',         senses:[{ pos:'adj.', en:'sparing in the use of words; abrupt', zh:'简洁的；言简意赅的；（言辞）唐突的' }]},
  declarative: { ipa:'/dɪˈklærətɪv/',   senses:[
                  { pos:'adj.', en:'(of a sentence) making a statement', zh:'陈述性的；声明的' },
                  { pos:'adj.', en:'expressing a clear position', zh:'明确表态的' },
                ]},
  expatriate:  { ipa:'/eksˈpætriət/',   senses:[
                  { pos:'n.',   en:'a person who lives outside their native country', zh:'侨居海外的人；侨民' },
                  { pos:'v.',   en:'to settle oneself abroad', zh:'移居国外' },
                ]},
  bohemians:   { ipa:'/boʊˈhiːmiənz/',  senses:[
                  { pos:'n.', en:'unconventional artists or intellectuals; (cap.) people of Bohemia',
                    zh:'波西米亚人；不羁的艺术家或文人' },
                ]},
  inextricably:{ ipa:'/ˌɪnɪkˈstrɪkəbli/', senses:[
                  { pos:'adv.', en:'in a way impossible to disentangle or separate',
                    zh:'难分难解地；密不可分地' },
                ]},
  understated: { ipa:'/ˌʌndərˈsteɪtɪd/', senses:[
                  { pos:'adj.', en:'presented or done in a subtle, restrained way', zh:'含蓄的；克制的；不张扬的' },
                ]},
  posthumously:{ ipa:'/ˈpɒstjuməsli/', senses:[
                  { pos:'adv.', en:'after the death of the originator', zh:'死后地；遗著式地' },
                ]},
};

const SENTENCE_TARGET = 'He worked through the rest of his life as a writer, a war correspondent, a fisherman, a hunter, and a husband — four times over.';
const SENTENCE_ZH     = '此后余生，他先后做过作家、战地记者、渔人、猎人——以及四次丈夫。';

function Article({ dark, onHotspot }) {
  const ink   = dark ? '#ebe3d0' : '#1a1612';
  const ink2  = dark ? '#8e8472' : '#5e564a';
  const ink3  = dark ? '#6a6353' : '#9a9282';
  const rule  = dark ? '#2a2620' : '#e6dfc9';
  const accent= dark ? '#d68a5a' : '#b35c2c';

  // helper to render a hot-spot word inline, indistinguishable from
  // regular text until hovered (no underline, no color tint).
  const hot = (word, key) => (
    <span data-hot={key} onClick={(e) => onHotspot(key || word, e)}
      style={{
        cursor:'pointer', borderRadius: 2, padding:'1px 1px', margin:'-1px -1px',
        transition:'background .12s',
      }}
      onMouseEnter={(e) => { e.currentTarget.style.background = dark ? 'rgba(214,138,90,.10)' : 'rgba(179,92,44,.08)'; }}
      onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent'; }}
    >{word}</span>
  );

  return (
    <div style={{
      padding:'56px 80px 88px', maxWidth: 720, margin:'0 auto',
      fontFamily: SANS_TEXT, color: ink, fontSize: 17, lineHeight: 1.68,
      letterSpacing:'-.003em',
    }}>
      <div style={{
        fontFamily: SANS_UI, fontSize: 11, color: ink3,
        textTransform:'uppercase', letterSpacing:'.14em', fontWeight: 600,
        marginBottom: 14,
      }}>essays · biography · 9 min read</div>
      <h1 style={{
        margin: 0, fontFamily: SANS_TEXT, fontSize: 36, lineHeight: 1.12,
        letterSpacing:'-.018em', fontWeight: 500, color: ink,
      }}>Ernest Hemingway: A Life in Brief</h1>
      <div style={{height: 8}} />
      <div style={{fontFamily: SANS_UI, fontSize: 12, color: ink3, letterSpacing:'.01em'}}>
        Margaret Reade · April 1989
      </div>
      <div style={{height: 36}} />

      <p style={{margin:'0 0 24px'}}>
        Ernest Miller Hemingway was an American {hot('novelist')}, short-story writer, and journalist
        whose {hot('terse')}, {hot('declarative')} prose reshaped twentieth-century fiction.
        He was born on July 21, 1899, in the quiet Chicago suburb of Oak Park,
        and died by his own hand on July 2, 1961, in Idaho.
      </p>

      <p style={{margin:'0 0 24px'}}>
        After serving as an ambulance driver in Italy during the First World War,
        Hemingway moved to Paris in the early 1920s, where he became part of the circle of
        {' '}{hot('expatriate')} writers that Gertrude Stein famously called the "Lost Generation."
        His first novel, published in 1926, drew on his time among bullfighters and
        {' '}{hot('bohemians')} in Spain and France, and made his name almost overnight.
      </p>

      <p style={{margin:'0 0 24px'}}>
        <span data-hot="__sentence"
          onClick={(e) => onHotspot('__sentence', e)}
          style={{cursor:'pointer', borderRadius: 2, padding:'1px', margin:'-1px',
            transition:'background .12s'}}
          onMouseEnter={(e) => { e.currentTarget.style.background = dark ? 'rgba(214,138,90,.08)' : 'rgba(179,92,44,.06)'; }}
          onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent'; }}
        >{SENTENCE_TARGET}</span>{' '}
        He produced seven novels, six short-story collections, and two works of non-fiction
        during his lifetime; three more novels and several volumes were published
        {' '}{hot('posthumously')}. In 1954 he was awarded the Nobel Prize in Literature, an honor
        that crowned a body of work whose {hot('understated')} influence on modern prose remains
        {' '}{hot('incalculable')} — the legend and the work, by then, {hot('inextricably')} entangled.
      </p>

      {/* pull quote */}
      <blockquote style={{
        margin:'40px 0 32px', padding:'18px 0 18px 24px',
        borderLeft: `2px solid ${rule}`,
        fontFamily: SANS_TEXT, fontStyle:'italic', fontSize: 19, lineHeight: 1.55,
        color: ink2, letterSpacing:'-.005em',
      }}>
        Write the truest sentence that you know.
        <div style={{
          fontFamily: SANS_UI, fontStyle:'normal', fontSize: 11.5,
          color: ink3, marginTop: 10, letterSpacing:'.04em', textTransform:'uppercase',
        }}>— attributed</div>
      </blockquote>

      <p style={{margin:'0 0 24px'}}>
        What is harder to capture, in a brief life, is the specific gravity of his sentences.
        Read aloud, they fall like nails: each clause perfectly weighted, each adjective
        absent unless absolutely earned. He inherited the long flowing periods of the
        nineteenth century and pared them, paragraph by paragraph, into something closer
        to bone.
      </p>

      <p style={{margin:'0 0 24px', color: ink3, fontSize: 14, fontStyle:'italic'}}>
        Continue reading: <span style={{color: accent, cursor:'pointer'}}>Hemingway in Paris, 1922 →</span>
      </p>
    </div>
  );
}

// ── Desktop frame (composes all above) ────────────────────────────────────

function Desktop({ dark, lexiActive, onLexiClick, onHotspot, children }) {
  return (
    <div style={{
      width:'100vw', height:'100vh', position:'relative', overflow:'hidden',
      background: dark
        ? 'radial-gradient(120% 80% at 70% 0%, #2e231a 0%, #1a130e 60%, #110c08 100%)'
        : 'radial-gradient(120% 80% at 70% 0%, #d9caa3 0%, #b8a079 55%, #876c44 100%)',
    }}>
      <MenuBar dark={dark} lexiActive={lexiActive} onLexiClick={onLexiClick} />
      <SafariWindow dark={dark} y={56} w={Math.min(940, window.innerWidth - 80)} h={Math.min(680, window.innerHeight - 100)}>
        <Article dark={dark} onHotspot={onHotspot} />
      </SafariWindow>
      {children}
    </div>
  );
}

Object.assign(window, { Desktop, ARTICLE_HOT, ARTICLE_DICT, SENTENCE_TARGET, SENTENCE_ZH, LexiGlyph });
