// bookshelf.jsx — Lexi bookshelf / open page
// Window: 1100 × 760
// States: default | empty | drag | search

const BOOKS_DATA = [
  { id: 'gatsby',       title: 'The Great Gatsby',         author: 'F. Scott Fitzgerald',
    cover: { bg: '#d8c4a0', ink: '#1f1b15' }, progress: 0.34, recent: '昨天',  cached: 8,  open: true  },
  { id: 'pp',           title: 'Pride and Prejudice',      author: 'Jane Austen',
    cover: { bg: '#9e8a6c', ink: '#fbf8f1' }, progress: 0.78, recent: '3 天前', cached: 38                },
  { id: 'sun',          title: 'The Sun Also Rises',       author: 'Ernest Hemingway',
    cover: { bg: '#384a5c', ink: '#f5f1e8' }, progress: 0,    recent: '本周',   cached: 0, fresh: true   },
  { id: 'moby',         title: 'Moby-Dick',                author: 'Herman Melville',
    cover: { bg: '#5c4b3a', ink: '#ebe3d0' }, progress: 0.12, recent: '2 周前',  cached: 14                },
  { id: 'frank',        title: 'Frankenstein',             author: 'Mary Shelley',
    cover: { bg: '#a89478', ink: '#1f1b15' }, progress: 1.0,  recent: '上月',   cached: 24,  done: true   },
  { id: 'dorian',       title: 'The Picture of Dorian Gray', author: 'Oscar Wilde',
    cover: { bg: '#b89878', ink: '#1f1b15' }, progress: 0.52, recent: '上月',   cached: 19                },
  { id: 'jane-eyre',    title: 'Jane Eyre',                author: 'Charlotte Brontë',
    cover: { bg: '#3d4434', ink: '#ebe3d0' }, progress: 0.04, recent: '2 月前',  cached: 2                 },
  { id: 'sherlock',     title: 'A Study in Scarlet',       author: 'Arthur Conan Doyle',
    cover: { bg: '#7a3a2a', ink: '#f5f1e8' }, progress: 0.91, recent: '3 月前',  cached: 12                },
];

// ───────────────────── book cover ─────────────────────

function BookCover({ book, t, size = 'lg' }) {
  // size: lg (140×210) or sm (84×126) — kept off skeuomorphism deliberately,
  // just flat typography on a paper-toned rectangle. The horizontal hair-rule
  // and the small LEXI publisher mark are the only ornaments.
  const W = size === 'lg' ? 140 : 84;
  const H = size === 'lg' ? 210 : 126;
  const titleSize = size === 'lg' ? 15 : 10;
  const authorSize = size === 'lg' ? 9.5 : 7.5;
  const pad = size === 'lg' ? 14 : 9;
  return (
    <div style={{
      width: W, height: H, background: book.cover.bg, color: book.cover.ink,
      position:'relative', overflow:'hidden',
      borderRadius: 2,
      boxShadow: t.name && t.name.includes('Light')
        ? '0 1px 2px rgba(40,28,14,.18), 0 6px 14px rgba(40,28,14,.08)'
        : '0 1px 2px rgba(0,0,0,.4), 0 6px 14px rgba(0,0,0,.25)',
      display:'flex', flexDirection:'column', justifyContent:'space-between',
      padding: pad, boxSizing:'border-box',
      fontFamily: SERIF,
    }}>
      <div style={{
        height: 1, width: '40%', background: book.cover.ink, opacity: .45,
      }} />
      <div style={{textAlign:'left', textWrap:'pretty'}}>
        <div style={{
          fontSize: titleSize, lineHeight: 1.15, letterSpacing:'-.012em',
          fontWeight: 500, marginBottom: size === 'lg' ? 6 : 4,
        }}>{book.title}</div>
        <div style={{
          fontSize: authorSize, lineHeight: 1.3, fontStyle:'italic',
          opacity: .82, letterSpacing:'.01em',
        }}>{book.author}</div>
      </div>
      <div style={{
        fontFamily: MONO, fontSize: 7, letterSpacing:'.18em',
        opacity: .5, textTransform:'uppercase',
      }}>LEXI</div>
    </div>
  );
}

// ───────────────────── book card (cover + meta + progress) ─────────────────────

function BookCard({ book, t, hovered, onHover, onClick }) {
  return (
    <div
      onMouseEnter={() => onHover && onHover(book.id)}
      onMouseLeave={() => onHover && onHover(null)}
      onClick={() => onClick && onClick(book)}
      style={{
        width: 160, display:'flex', flexDirection:'column', gap: 10,
        cursor: 'pointer', position:'relative',
        transform: hovered ? 'translateY(-2px)' : 'none',
        transition: 'transform .15s',
      }}
    >
      <div style={{margin:'0 auto'}}>
        <BookCover book={book} t={t} />
      </div>
      <div style={{padding:'0 4px'}}>
        <div style={{
          fontFamily: SANS, fontSize: 12.5, color: t.ink, lineHeight: 1.3,
          fontWeight: 500, letterSpacing:'-.005em',
          textOverflow:'ellipsis', whiteSpace:'nowrap', overflow:'hidden',
        }}>{book.title}</div>
        <div style={{
          fontFamily: SANS, fontSize: 11, color: t.ink3, lineHeight: 1.3,
          marginTop: 2,
          textOverflow:'ellipsis', whiteSpace:'nowrap', overflow:'hidden',
        }}>{book.author}</div>
        <div style={{height: 8}} />
        {/* hairline progress + meta */}
        <div style={{position:'relative', height: 1, background: t.rule, marginBottom: 6}}>
          <div style={{
            position:'absolute', left: 0, top: 0, height: '100%',
            width: `${(book.progress || 0) * 100}%`,
            background: book.done ? t.ink3 : t.accent,
            opacity: book.done ? 1 : .8,
          }} />
        </div>
        <div style={{
          fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em',
          display:'flex', justifyContent:'space-between',
        }}>
          <span>{book.fresh ? 'NEW' : book.done ? '已读完' : `${Math.round(book.progress * 100)}%`}</span>
          <span>{book.recent}</span>
        </div>
      </div>
    </div>
  );
}

// ───────────────────── top toolbar ─────────────────────

function ShelfTopbar({ t, theme, state }) {
  return (
    <div style={{
      height: 44, flex:'0 0 auto', position:'relative',
      background: t.chrome, borderBottom: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', padding:'0 14px',
    }}>
      <TrafficLights />

      <div style={{marginLeft: 28, display:'flex', alignItems:'center', gap: 10, flex: 1}}>
        {/* search field */}
        <div style={{
          flex:'0 0 240px', height: 24, borderRadius: 5,
          background: t.bgInset, border: `1px solid ${t.rule}`,
          display:'flex', alignItems:'center', padding:'0 8px', gap: 6,
        }}>
          <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke={t.ink3} strokeWidth="1.5">
            <circle cx="7" cy="7" r="4" /><line x1="10.5" y1="10.5" x2="13.5" y2="13.5" strokeLinecap="round" />
          </svg>
          <span style={{
            fontFamily: SANS, fontSize: 12,
            color: state === 'search' ? t.ink : t.ink3, flex: 1,
          }}>{state === 'search' ? 'Gatsby' : '搜索书名 / 作者'}</span>
          <span style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em'}}>⌘F</span>
        </div>

        {/* sort */}
        <div style={{
          height: 24, padding:'0 10px', borderRadius: 5,
          background: 'transparent', border: `1px solid ${t.rule2}`,
          display:'inline-flex', alignItems:'center', gap: 5,
          fontFamily: SANS, fontSize: 12, color: t.ink2,
        }}>
          排序 · 最近
          <span style={{color: t.ink3, fontSize: 9, marginTop: 1}}>▾</span>
        </div>
      </div>

      <div style={{display:'flex', alignItems:'center', gap: 6}}>
        <button style={{
          height: 24, padding:'0 12px', borderRadius: 5,
          background: t.accentSoft, color: t.accent, border:'none', cursor:'pointer',
          fontFamily: SANS, fontSize: 12, fontWeight: 500,
          display:'inline-flex', alignItems:'center', gap: 5,
        }}>
          <Icon name="plus" size={11} color={t.accent} /> 添加 EPUB
        </button>
      </div>
    </div>
  );
}

// ───────────────────── full window ─────────────────────

function BookshelfWindow({ theme = 'dark', state = 'default' }) {
  const t = TOKENS[theme];
  const W = 1100, H = 760;
  const dark = theme === 'dark';
  return (
    <div style={{
      width: W, height: H, background: t.bg, color: t.ink,
      borderRadius: 10, overflow:'hidden',
      boxShadow: dark
        ? '0 30px 80px rgba(0,0,0,.45), 0 0 0 1px rgba(0,0,0,.6)'
        : '0 30px 80px rgba(60,40,20,.18), 0 0 0 1px rgba(0,0,0,.08)',
      display:'flex', flexDirection:'column', position:'relative',
      fontFeatureSettings:'"kern","liga","calt"',
    }}>
      <ShelfTopbar t={t} theme={theme} state={state} />

      <div style={{flex: 1, overflow:'auto', padding: '40px 56px 64px', position:'relative'}}>
        {state === 'empty' ? (
          <EmptyState t={t} />
        ) : state === 'drag' ? (
          <>
            <BookGrid t={t} books={BOOKS_DATA} dimmed />
            <DragOverlay t={t} />
          </>
        ) : (
          <>
            {state === 'search' && <SearchInfo t={t} />}
            <BookGrid t={t} books={state === 'search'
              ? BOOKS_DATA.filter(b => b.title.toLowerCase().includes('gatsby'))
              : BOOKS_DATA} />
          </>
        )}
      </div>

      {/* status bar */}
      <div style={{
        flex:'0 0 auto', height: 28, display:'flex', alignItems:'center',
        padding:'0 16px', justifyContent:'space-between',
        fontFamily: SANS, fontSize: 11, color: t.ink3,
        borderTop: `1px solid ${t.rule}`, background: t.chrome,
      }}>
        <span>{state === 'empty' ? '本地无书籍' : `${BOOKS_DATA.length} 本书 · 翻译缓存 124 MB`}</span>
        <span style={{fontFamily: MONO, letterSpacing:'.04em'}}>v1.0 · ⌘⇧L 已激活</span>
      </div>
    </div>
  );
}

// ───────────────────── sub-pieces ─────────────────────

function BookGrid({ t, books, dimmed }) {
  return (
    <div style={{
      display:'grid',
      gridTemplateColumns:'repeat(auto-fill, minmax(160px, 1fr))',
      gap: '36px 28px', opacity: dimmed ? .35 : 1,
      transition:'opacity .2s',
    }}>
      <SectionHeader t={t} label="继续阅读" />
      <BookCard book={books[0]} t={t} />
      {books.slice(1, 3).map((b) => <BookCard key={b.id} book={b} t={t} />)}
      {books.length > 3 && (
        <>
          <SectionHeader t={t} label="书架" />
          {books.slice(3).map((b) => <BookCard key={b.id} book={b} t={t} />)}
        </>
      )}
    </div>
  );
}

function SectionHeader({ t, label }) {
  return (
    <div style={{gridColumn: '1 / -1', marginTop: 8, marginBottom: -16}}>
      <div style={{
        fontFamily: SANS, fontSize: 10.5, color: t.ink3,
        textTransform:'uppercase', letterSpacing:'.14em', fontWeight: 600,
      }}>{label}</div>
    </div>
  );
}

function EmptyState({ t }) {
  return (
    <div style={{
      width:'100%', height:'100%', minHeight: 500,
      display:'flex', alignItems:'center', justifyContent:'center',
    }}>
      <div style={{
        width: 480, padding:'60px 40px',
        border: `1.5px dashed ${t.rule2}`, borderRadius: 8,
        textAlign:'center', display:'flex', flexDirection:'column', gap: 16,
        alignItems:'center',
      }}>
        <svg width="48" height="48" viewBox="0 0 48 48" fill="none" stroke={t.ink3} strokeWidth="1.2">
          <path d="M12 8h18l8 8v24a2 2 0 0 1-2 2H12a2 2 0 0 1-2-2V10a2 2 0 0 1 2-2Z" />
          <path d="M30 8v8h8" />
          <line x1="17" y1="26" x2="31" y2="26" />
          <line x1="17" y1="32" x2="27" y2="32" />
        </svg>
        <div style={{fontFamily: SERIF, fontSize: 19, color: t.ink, letterSpacing:'-.01em'}}>
          书架是空的
        </div>
        <div style={{fontFamily: SANS, fontSize: 13, color: t.ink2, lineHeight: 1.55, maxWidth: 320}}>
          把 EPUB 文件拖到这里，或者
          <span style={{color: t.accent, fontWeight: 500, marginLeft: 4, cursor:'pointer'}}>点击选择文件</span>。
        </div>
        <div style={{
          fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.06em',
          marginTop: 8, textTransform:'uppercase',
        }}>支持 .epub · .epub3</div>
      </div>
    </div>
  );
}

function DragOverlay({ t }) {
  return (
    <div style={{
      position:'absolute', inset: 18, pointerEvents:'none',
      background: t.accentSoft, border: `2px dashed ${t.accent}`,
      borderRadius: 10,
      display:'flex', alignItems:'center', justifyContent:'center',
    }}>
      <div style={{
        background: t.bg, color: t.ink,
        padding:'18px 26px', borderRadius: 10,
        boxShadow:'0 18px 40px rgba(0,0,0,.20), 0 0 0 1px rgba(0,0,0,.08)',
        display:'flex', flexDirection:'column', alignItems:'center', gap: 8,
      }}>
        <div style={{fontFamily: SERIF, fontSize: 17, color: t.ink, letterSpacing:'-.005em'}}>
          松开以加入书架
        </div>
        <div style={{fontFamily: SANS, fontSize: 12, color: t.ink3}}>
          1981·days·in·the·life-of-ivan.epub
        </div>
      </div>
    </div>
  );
}

function SearchInfo({ t }) {
  return (
    <div style={{
      marginBottom: 24, padding:'0 4px',
      fontFamily: SANS, fontSize: 11.5, color: t.ink3,
      display:'flex', alignItems:'center', gap: 6,
    }}>
      <span>搜索结果："Gatsby" · 1 项</span>
      <span style={{color: t.ink4}}>·</span>
      <span style={{color: t.accent, cursor:'pointer'}}>清除</span>
    </div>
  );
}

// ───────────────────── book context menu (right-click) ─────────────────────

function BookContextMenu({ t, theme }) {
  return (
    <div style={{
      width: 200, background: t.bgRaised, color: t.ink,
      borderRadius: 8, overflow:'hidden', padding: 4,
      boxShadow: theme === 'dark'
        ? '0 14px 36px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5)'
        : '0 14px 36px rgba(60,40,20,.18), 0 0 0 1px rgba(0,0,0,.08)',
      fontFamily: SANS, fontSize: 12.5,
    }}>
      {[
        { label: '打开', shortcut:'⌘O' },
        { label: '继续阅读', shortcut:'↵', hot: true },
        { divider: true },
        { label: '在 Finder 中显示', shortcut:'⌥⌘R' },
        { label: '复制书籍信息' },
        { divider: true },
        { label: '清除翻译缓存 (8.4 MB)' },
        { label: '导出生词本…' },
        { divider: true },
        { label: '从书架移除', danger: true },
      ].map((it, i) => it.divider ? (
        <div key={i} style={{height: 1, background: t.rule, margin:'4px 6px'}} />
      ) : (
        <div key={i} style={{
          display:'flex', justifyContent:'space-between', padding:'6px 10px',
          borderRadius: 5,
          background: it.hot ? t.accentSoft : 'transparent',
          color: it.danger ? t.danger : (it.hot ? t.accent : t.ink),
          fontWeight: it.hot ? 500 : 400,
        }}>
          <span>{it.label}</span>
          {it.shortcut && <span style={{fontFamily: MONO, fontSize: 10.5, color: t.ink3}}>{it.shortcut}</span>}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { BookshelfWindow, BookCard, BookCover, BOOKS_DATA, BookContextMenu });
