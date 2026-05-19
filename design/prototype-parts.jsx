// prototype.jsx — Lexi interactive reader prototype (Quiet direction)
// Full-bleed: the page IS the macOS window UI.
// Real interactions: chapter nav, theme/font/translation toggles, engine
// switcher, selection → popup, ⌘⇧L, Esc, scroll progress, streaming
// translation when entering an uncached chapter.

const { useState, useEffect, useRef, useMemo, useCallback } = React;

// ───────────────────── helpers ─────────────────────

function rgba(hex, alpha) {
  // expects #rrggbb
  const h = hex.replace('#','');
  const r = parseInt(h.slice(0,2),16), g = parseInt(h.slice(2,4),16), b = parseInt(h.slice(4,6),16);
  return `rgba(${r},${g},${b},${alpha})`;
}

function deriveTokens(base, accent) {
  // override accent + its derived alpha tokens (accentSoft, sel, accentFaint)
  return {
    ...base,
    accent,
    accentSoft: rgba(accent, 0.14),
    accentFaint: rgba(accent, 0.06),
    sel: rgba(accent, 0.20),
  };
}

const ACCENTS = ['#b35c2c', '#a85a2a', '#7d6644', '#9c4a39'];   // copper · amber · olive-brown · brick
const ACCENTS_DARK = ['#d68a5a', '#d6a35a', '#a89678', '#cf7969'];

const SERIF_CHOICES = {
  'New York':     '"New York", "Charter", "Iowan Old Style", Georgia, serif',
  'Charter':      '"Charter", "Iowan Old Style", "New York", Georgia, serif',
  'Iowan':        '"Iowan Old Style", "Charter", Georgia, serif',
  'System':       'ui-serif, "Times New Roman", serif',
};

// ───────────────────── default tweaks ─────────────────────

const DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "dark",
  "paraStyle": "demote",
  "fontSize": 17,
  "transMode": "both",
  "showSidebar": true,
  "accentIdx": 0,
  "serif": "New York",
  "showHints": true
}/*EDITMODE-END*/;

// ───────────────────── small UI atoms ─────────────────────

function CtlBtn({ children, onClick, hot, t, title, w = 28, h = 22, style }) {
  return (
    <button onClick={onClick} title={title} style={{
      width: w, height: h, padding: 0, border: 'none',
      background: hot ? t.accentSoft : 'transparent',
      color: hot ? t.accent : t.ink3,
      borderRadius: 4, cursor: 'pointer',
      display:'flex', alignItems:'center', justifyContent:'center',
      transition: 'background .12s, color .12s',
      ...style,
    }}
    onMouseEnter={(e) => { if (!hot) e.currentTarget.style.background = t.accentFaint; }}
    onMouseLeave={(e) => { if (!hot) e.currentTarget.style.background = 'transparent'; }}
    >{children}</button>
  );
}

function Divider({ t }) {
  return <div style={{width: 1, height: 14, background: t.rule, margin: '0 6px'}} />;
}

// ───────────────────── sidebar ─────────────────────

function PSidebar({ t, chapterIdx, chapState, onPick, accent, serif, book, onShelf }) {
  return (
    <aside style={{
      width: 240, flex:'0 0 240px', height:'100%',
      background: t.bgRaised, borderRight: `1px solid ${t.rule}`,
      padding: '20px 12px 18px',
      display:'flex', flexDirection:'column', overflow:'hidden',
    }}>
      <div style={{padding:'8px 10px 16px'}}>
        <button onClick={onShelf} style={{
          display:'inline-flex', alignItems:'center', gap: 4,
          background:'transparent', border:'none', cursor:'pointer',
          color: t.ink3, fontFamily: SANS, fontSize: 11.5, padding: 0,
        }}
          onMouseEnter={(e) => { e.currentTarget.style.color = t.accent; }}
          onMouseLeave={(e) => { e.currentTarget.style.color = t.ink3; }}
        ><Icon name="back" size={11} color="currentColor" /> 书架</button>
        <div style={{height: 12}} />
        <div style={{fontFamily: serif, fontSize: 15, color: t.ink, lineHeight: 1.3, letterSpacing:'-.005em', fontWeight: 500}}>
          {book ? book.title : 'The Great Gatsby'}
        </div>
        <div style={{fontFamily: SANS, fontSize: 11.5, color: t.ink3, marginTop: 2}}>
          {book ? book.author : 'F. Scott Fitzgerald'}
        </div>
      </div>

      <div style={{height: 1, background: t.rule, margin: '0 8px 12px'}} />

      <nav style={{display:'flex', flexDirection:'column', gap: 1, overflowY:'auto', flex: 1}}>
        {CHAPTERS.map((c, i) => {
          const s = chapState[i];
          const status = s ? s.status : 'idle';
          const active = chapterIdx === i;
          return (
            <a key={c.n} onClick={() => onPick(i)} style={{
              display:'flex', alignItems:'baseline', gap: 8,
              padding:'7px 10px', borderRadius: 5,
              background: active ? t.accentSoft : 'transparent',
              color: active ? t.accent : (status === 'cached' && i < chapterIdx ? t.ink3 : t.ink),
              fontFamily: SANS, fontSize: 12.5, lineHeight: 1.35,
              cursor:'pointer', textDecoration:'none', transition: 'background .12s',
            }}
              onMouseEnter={(e) => { if (!active) e.currentTarget.style.background = t.accentFaint; }}
              onMouseLeave={(e) => { if (!active) e.currentTarget.style.background = 'transparent'; }}
            >
              <span style={{flex:'0 0 28px', fontFamily: MONO, fontSize: 10.5,
                color: active ? t.accent : t.ink3, letterSpacing:'.04em'}}>{c.n}</span>
              <span style={{flex: 1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap',
                fontWeight: active ? 500 : 400}}>{c.title}</span>
              {status === 'translating' && (
                <span style={{flex:'0 0 auto', color: t.accent, display:'flex'}}>
                  <Icon name="spinner" size={10} color={t.accent} />
                </span>
              )}
              {status === 'idle' && !active && (
                <span style={{flex:'0 0 auto', width: 5, height: 5, borderRadius:'50%', background: t.ink4}} />
              )}
            </a>
          );
        })}
      </nav>

      <div style={{height: 1, background: t.rule, margin: '12px 8px 10px'}} />
      <div style={{padding:'0 10px', fontFamily: SANS, fontSize: 11, color: t.ink3, lineHeight: 1.55}}>
        <div style={{display:'flex', justifyContent:'space-between'}}>
          <span>全书进度</span><span style={{fontFamily: MONO, color: t.ink2}}>{Math.round(((chapterIdx + 0.4) / CHAPTERS.length) * 100)}%</span>
        </div>
      </div>
    </aside>
  );
}

// ───────────────────── title bar ─────────────────────

function PTitleBar({ t, theme, chapterIdx, sidebarOpen, transMode, book, onToggleSidebar, onCycleFont, onShrinkFont, onTheme, onCycleTrans, onEngineMenu, onMoreMenu, moreMenuOpen, engineMenuOpen, hints }) {
  const ch = CHAPTERS[chapterIdx];
  const bookTitle = book ? book.title : 'The Great Gatsby';
  return (
    <div style={{
      height: 44, flex:'0 0 auto', position:'relative',
      background: t.chrome,
      borderBottom: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', padding: '0 12px',
      WebkitAppRegion:'drag',
    }}>
      <div style={{WebkitAppRegion:'no-drag'}}><TrafficLights /></div>

      <div style={{
        position:'absolute', left:'50%', top:'50%', transform:'translate(-50%,-50%)',
        fontFamily: SANS, fontSize: 12, color: t.ink3,
        display:'flex', alignItems:'center', gap: 8,
      }}>
        <span style={{color: t.ink2}}>{bookTitle}</span>
        <span style={{color: t.ink4}}>·</span>
        <span>Chapter {ch.n} · {chapterIdx + 1} / {CHAPTERS.length}</span>
      </div>

      <div style={{marginLeft:'auto', display:'flex', alignItems:'center', gap: 2, WebkitAppRegion:'no-drag'}}>
        <CtlBtn t={t} hot={sidebarOpen} onClick={onToggleSidebar} title="切换侧栏 (⌘0)"><Icon name="sidebar" /></CtlBtn>
        <Divider t={t} />
        <CtlBtn t={t} onClick={onShrinkFont} title="缩小字号"><Icon name="aMinus" /></CtlBtn>
        <CtlBtn t={t} onClick={onCycleFont} title="放大字号"><Icon name="aPlus" /></CtlBtn>
        <Divider t={t} />
        <CtlBtn t={t} hot={transMode !== 'en'} onClick={onCycleTrans}
          title={transMode === 'both' ? '原文+译文' : transMode === 'en' ? '仅原文' : '仅译文'}>
          <Icon name="lang" />
        </CtlBtn>
        <div style={{position:'relative'}}>
          <CtlBtn t={t} hot={engineMenuOpen} onClick={onEngineMenu} title="翻译引擎">
            <Icon name="engine" />
          </CtlBtn>
        </div>
        <CtlBtn t={t} hot={theme === 'dark'} onClick={onTheme} title="暗色 / 亮色">
          <Icon name="moon" />
        </CtlBtn>
        <div style={{position:'relative'}}>
          <CtlBtn t={t} hot={moreMenuOpen} onClick={onMoreMenu} title="更多"><Icon name="more" /></CtlBtn>
        </div>
      </div>
    </div>
  );
}

// ───────────────────── menus ─────────────────────

function MiniMenu({ t, theme, items, anchorRight = 12, top = 50 }) {
  return (
    <div style={{
      position:'absolute', top, right: anchorRight, zIndex: 30,
      background: t.bgRaised, color: t.ink,
      borderRadius: 8, overflow:'hidden',
      boxShadow: theme === 'dark'
        ? '0 12px 32px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5)'
        : '0 12px 32px rgba(60,40,20,.18), 0 0 0 1px rgba(0,0,0,.08)',
      minWidth: 180, padding: 4, fontFamily: SANS, fontSize: 12.5,
      animation:'lexiPopIn .12s ease-out',
    }}>
      {items.map((it, i) => it.divider ? (
        <div key={i} style={{height: 1, background: t.rule, margin:'4px 6px'}} />
      ) : (
        <button key={i} onClick={it.onClick} disabled={it.disabled} style={{
          display:'flex', width:'100%', alignItems:'center', justifyContent:'space-between',
          padding:'6px 10px', border:'none', background:'transparent',
          color: it.disabled ? t.ink4 : (it.danger ? t.danger : t.ink),
          cursor: it.disabled ? 'default' : 'pointer', fontFamily: SANS, fontSize: 12.5,
          borderRadius: 5, textAlign:'left',
        }}
          onMouseEnter={(e) => { if (!it.disabled) e.currentTarget.style.background = t.accentFaint; }}
          onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent'; }}
        >
          <span style={{display:'inline-flex', alignItems:'center', gap: 8}}>
            {it.check && <span style={{color: t.accent, fontSize: 11}}>✓</span>}
            {!it.check && it.indent && <span style={{display:'inline-block', width: 11}} />}
            {it.label}
          </span>
          {it.shortcut && <span style={{fontFamily: MONO, fontSize: 10.5, color: t.ink3}}>{it.shortcut}</span>}
        </button>
      ))}
    </div>
  );
}

// ───────────────────── paragraph ─────────────────────

function PPara({ p, t, idx, fontSize, lineHeight, paraStyle, transMode, status, done, serif, isLastReadable, anchorRef }) {
  // done = number of paragraphs translated so far in current chapter
  const ready = status === 'cached' || idx < done;
  const failed = status === 'error' && idx === 2;
  const showEn = transMode !== 'zh';
  const showZh = transMode !== 'en';

  // translation wrapper styles by paraStyle
  const wrapStyle = {
    demote: { paddingLeft: 0, borderLeft:'none', background:'transparent', padding: 0, borderRadius: 0 },
    rule:   { paddingLeft: 12, borderLeft: `1.5px solid ${t.rule2}`, background:'transparent', padding:'2px 0 2px 12px', borderRadius: 0 },
    tint:   { paddingLeft: 0, borderLeft:'none', background: t.bgInset, padding:'8px 12px', borderRadius: 4 },
  }[paraStyle];

  return (
    <div ref={isLastReadable ? anchorRef : null} data-para-idx={idx} style={{marginBottom: 28}}>
      {showEn && (
        <p style={{
          margin: 0,
          fontFamily: serif, fontSize, lineHeight,
          color: t.ink, letterSpacing:'-.003em',
        }}>{p.en}</p>
      )}
      {showEn && showZh && <div style={{height: 6}} />}
      {showZh && ready && !failed && (
        <div style={wrapStyle}>
          <p style={{
            margin: 0, fontFamily: ZH,
            fontSize: Math.round(fontSize * 0.83 * 10) / 10,
            lineHeight: 1.78, color: t.ink2, letterSpacing: '.01em',
          }}>{p.zh}</p>
        </div>
      )}
      {showZh && !ready && !failed && (
        <div style={{...wrapStyle, display:'flex', flexDirection:'column', gap: 6}}>
          <div style={{height: fontSize * 0.7, width:'92%', borderRadius: 3,
            background: `linear-gradient(90deg, ${t.shimmer1}, ${t.shimmer2}, ${t.shimmer1})`,
            backgroundSize: '200% 100%', animation: 'lexiShimmer 1.6s linear infinite'}} />
          <div style={{height: fontSize * 0.7, width:'64%', borderRadius: 3,
            background: `linear-gradient(90deg, ${t.shimmer1}, ${t.shimmer2}, ${t.shimmer1})`,
            backgroundSize: '200% 100%', animation: 'lexiShimmer 1.6s linear infinite', animationDelay: '.15s'}} />
        </div>
      )}
      {failed && showZh && (
        <div style={{display:'flex', alignItems:'center', gap: 10, fontFamily: ZH, fontSize: 12.5, color: t.warn}}>
          <Icon name="warn" size={13} color={t.warn} />
          <span style={{color: t.ink3}}>本段翻译失败</span>
          <button style={{
            background:'transparent', border: `1px solid ${t.rule2}`, color: t.ink2,
            fontFamily: SANS, fontSize: 11.5, padding:'2px 8px', borderRadius: 4, cursor:'pointer',
          }}>重试本段</button>
        </div>
      )}
    </div>
  );
}

// ───────────────────── reading column ─────────────────────

const ReadingColumn = React.forwardRef(function ReadingColumn(props, ref) {
  const { t, chapterIdx, fontSize, lineHeight, transMode, paraStyle, status, done, serif, onSelection, onScroll } = props;
  const ch = CHAPTERS[chapterIdx];
  return (
    <main
      ref={ref}
      onScroll={onScroll}
      onMouseUp={onSelection}
      style={{
        flex: 1, overflow:'auto', position:'relative',
        padding: '56px 80px 96px',
        scrollBehavior:'smooth',
      }}
    >
      <div style={{maxWidth: 660, margin:'0 auto', position:'relative'}}>
        <header style={{marginBottom: 44}}>
          <div style={{
            fontFamily: SANS, fontSize: 11, color: t.ink3,
            letterSpacing:'.08em', textTransform:'uppercase', marginBottom: 12, fontWeight: 600,
          }}>Chapter {ch.n}</div>
          <h1 style={{margin: 0, fontFamily: serif, fontSize: Math.round(fontSize * 1.65),
            lineHeight: 1.2, letterSpacing:'-.014em', color: t.ink, fontWeight: 500,
          }}>{ch.title}</h1>
        </header>

        {ch.paras.map((p, i) => (
          <PPara key={i} p={p} t={t} idx={i}
            fontSize={fontSize} lineHeight={lineHeight}
            paraStyle={paraStyle} transMode={transMode}
            status={status} done={done} serif={serif}
          />
        ))}

        {/* end-of-chapter nav */}
        <div style={{
          marginTop: 48, paddingTop: 24, borderTop: `1px solid ${t.rule}`,
          display:'flex', justifyContent:'space-between', alignItems:'center',
          fontFamily: SANS, fontSize: 12.5,
        }}>
          <button onClick={() => props.onPrev()} disabled={chapterIdx === 0} style={{
            background:'transparent', border:'none', color: chapterIdx === 0 ? t.ink4 : t.ink2,
            cursor: chapterIdx === 0 ? 'default' : 'pointer', fontFamily: SANS, fontSize: 12.5,
            display:'inline-flex', alignItems:'center', gap: 6,
          }}>
            <Icon name="back" size={12} color={chapterIdx === 0 ? t.ink4 : t.ink2} /> 上一章
          </button>
          <button onClick={() => props.onNext()} disabled={chapterIdx >= CHAPTERS.length - 1} style={{
            background:'transparent', border:'none',
            color: chapterIdx >= CHAPTERS.length - 1 ? t.ink4 : t.accent,
            cursor: chapterIdx >= CHAPTERS.length - 1 ? 'default' : 'pointer',
            fontFamily: SANS, fontSize: 12.5, fontWeight: 500,
          }}>
            下一章 · {CHAPTERS[Math.min(chapterIdx + 1, CHAPTERS.length - 1)].title.slice(0, 28)}… →
          </button>
        </div>
      </div>
    </main>
  );
});

Object.assign(window, { PSidebar, PTitleBar, MiniMenu, PPara, ReadingColumn, deriveTokens, ACCENTS, ACCENTS_DARK, SERIF_CHOICES });
