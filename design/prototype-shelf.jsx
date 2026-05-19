// prototype-shelf.jsx — Interactive bookshelf view
// Drops over the reader with the same chrome. Click a book → onOpen(book).

const SHELF_BOOKS = [
  { id: 'gatsby',    title: 'The Great Gatsby',          author: 'F. Scott Fitzgerald', cover: { bg: '#d8c4a0', ink: '#1f1b15' }, progress: 0.34, recent: '昨天',  cached: 8,  open: true },
  { id: 'pp',        title: 'Pride and Prejudice',       author: 'Jane Austen',          cover: { bg: '#9e8a6c', ink: '#fbf8f1' }, progress: 0.78, recent: '3 天前', cached: 38 },
  { id: 'sun',       title: 'The Sun Also Rises',        author: 'Ernest Hemingway',     cover: { bg: '#384a5c', ink: '#f5f1e8' }, progress: 0,    recent: '本周',   cached: 0, fresh: true },
  { id: 'moby',      title: 'Moby-Dick',                 author: 'Herman Melville',      cover: { bg: '#5c4b3a', ink: '#ebe3d0' }, progress: 0.12, recent: '2 周前', cached: 14 },
  { id: 'frank',     title: 'Frankenstein',              author: 'Mary Shelley',         cover: { bg: '#a89478', ink: '#1f1b15' }, progress: 1.0,  recent: '上月',   cached: 24, done: true },
  { id: 'dorian',    title: 'The Picture of Dorian Gray',author: 'Oscar Wilde',          cover: { bg: '#b89878', ink: '#1f1b15' }, progress: 0.52, recent: '上月',   cached: 19 },
  { id: 'jane-eyre', title: 'Jane Eyre',                 author: 'Charlotte Brontë',     cover: { bg: '#3d4434', ink: '#ebe3d0' }, progress: 0.04, recent: '2 月前', cached: 2 },
  { id: 'sherlock',  title: 'A Study in Scarlet',        author: 'Arthur Conan Doyle',   cover: { bg: '#7a3a2a', ink: '#f5f1e8' }, progress: 0.91, recent: '3 月前', cached: 12 },
];

// ── small bits ─────────────────────────────────────────────────────────────

function IShelfCover({ book, dark }) {
  return (
    <div style={{
      width: 144, height: 216,
      background: book.cover.bg, color: book.cover.ink,
      position:'relative', overflow:'hidden', borderRadius: 2,
      boxShadow: dark
        ? '0 1px 2px rgba(0,0,0,.4), 0 6px 14px rgba(0,0,0,.25)'
        : '0 1px 2px rgba(40,28,14,.18), 0 6px 14px rgba(40,28,14,.08)',
      display:'flex', flexDirection:'column', justifyContent:'space-between',
      padding: 14, boxSizing:'border-box', fontFamily: SERIF,
    }}>
      <div style={{height: 1, width:'40%', background: book.cover.ink, opacity:.45}} />
      <div>
        <div style={{
          fontSize: 15, lineHeight: 1.15, letterSpacing:'-.012em',
          fontWeight: 500, marginBottom: 6, textWrap:'pretty',
        }}>{book.title}</div>
        <div style={{fontSize: 9.5, lineHeight: 1.3, fontStyle:'italic', opacity:.82, letterSpacing:'.01em'}}>{book.author}</div>
      </div>
      <div style={{fontFamily: MONO, fontSize: 7, letterSpacing:'.18em', opacity:.5, textTransform:'uppercase'}}>LEXI</div>
    </div>
  );
}

function IShelfCard({ book, t, theme, current, onOpen, onCtx }) {
  const [hover, setHover] = useState(false);
  return (
    <div
      onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      onClick={() => onOpen(book)}
      onContextMenu={(e) => { e.preventDefault(); onCtx(book, { x: e.clientX, y: e.clientY }); }}
      style={{
        width: 168, display:'flex', flexDirection:'column', gap: 10,
        cursor:'pointer', position:'relative',
        transform: hover ? 'translateY(-3px)' : 'none',
        transition: 'transform .18s',
      }}
    >
      <div style={{margin:'0 auto', position:'relative'}}>
        <IShelfCover book={book} dark={theme === 'dark'} />
        {current === book.id && (
          <div style={{
            position:'absolute', top: -6, right: -6,
            width: 18, height: 18, borderRadius: '50%',
            background: t.accent, color:'#fff', display:'flex',
            alignItems:'center', justifyContent:'center',
            fontFamily: SANS, fontSize: 9, fontWeight: 700,
            boxShadow:'0 2px 6px rgba(0,0,0,.25)',
          }}>●</div>
        )}
      </div>
      <div style={{padding:'0 4px'}}>
        <div style={{
          fontFamily: SANS, fontSize: 12.5, color: t.ink, lineHeight: 1.3,
          fontWeight: 500, letterSpacing:'-.005em',
          textOverflow:'ellipsis', whiteSpace:'nowrap', overflow:'hidden',
        }}>{book.title}</div>
        <div style={{
          fontFamily: SANS, fontSize: 11, color: t.ink3, lineHeight: 1.3, marginTop: 2,
          textOverflow:'ellipsis', whiteSpace:'nowrap', overflow:'hidden',
        }}>{book.author}</div>
        <div style={{height: 8}} />
        <div style={{position:'relative', height: 1, background: t.rule, marginBottom: 6}}>
          <div style={{
            position:'absolute', left: 0, top: 0, height:'100%',
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

// ── interactive bookshelf view (full window content) ──────────────────────

function ShelfView({ t, theme, currentBookId, onOpenBook, flash }) {
  const [query, setQuery] = useState('');
  const [sort, setSort] = useState('最近');
  const [dragOver, setDragOver] = useState(false);
  const [ctx, setCtx] = useState(null);   // { book, x, y }
  const [hideOpened, setHideOpened] = useState(false);   // visual gimmick for "已开"

  const filtered = useMemo(() => {
    let list = SHELF_BOOKS;
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter(b => b.title.toLowerCase().includes(q) || b.author.toLowerCase().includes(q));
    }
    if (sort === '书名')  list = [...list].sort((a, b) => a.title.localeCompare(b.title));
    if (sort === '进度')  list = [...list].sort((a, b) => b.progress - a.progress);
    return list;
  }, [query, sort]);

  // close ctx menu on outside click
  useEffect(() => {
    if (!ctx) return;
    const onDown = (e) => {
      if (e.target.closest('[data-shelf-ctx]')) return;
      setCtx(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [ctx]);

  // simulated drop handler
  const onDrop = (e) => {
    e.preventDefault(); setDragOver(false);
    flash && flash('已加入书架 · the-stranger.epub');
  };

  return (
    <div
      onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
      onDragLeave={() => setDragOver(false)}
      onDrop={onDrop}
      style={{flex: 1, display:'flex', flexDirection:'column', minHeight: 0, position:'relative'}}>

      {/* shelf toolbar */}
      <div style={{
        flex:'0 0 auto', padding:'12px 56px 0',
        display:'flex', alignItems:'center', gap: 12,
      }}>
        <div style={{
          flex:'0 0 280px', height: 28, borderRadius: 5,
          background: t.bgInset, border: `1px solid ${t.rule}`,
          display:'flex', alignItems:'center', padding:'0 10px', gap: 8,
        }}>
          <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke={t.ink3} strokeWidth="1.5">
            <circle cx="7" cy="7" r="4" /><line x1="10.5" y1="10.5" x2="13.5" y2="13.5" strokeLinecap="round" />
          </svg>
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="搜索书名 / 作者"
            style={{flex: 1, background:'transparent', border:'none', outline:'none',
              color: t.ink, fontFamily: SANS, fontSize: 12.5}} />
          {!query && <span style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em'}}>⌘F</span>}
          {query && (
            <button onClick={() => setQuery('')} style={{background:'transparent', border:'none', color: t.ink3, cursor:'pointer', padding: 0, fontSize: 14, lineHeight: 1}}>×</button>
          )}
        </div>

        <div style={{display:'inline-flex', alignItems:'center', gap: 0,
          background: t.bgInset, padding: 2, borderRadius: 6, border: `1px solid ${t.rule}`,
          fontFamily: SANS, fontSize: 11.5}}>
          {['最近','书名','进度'].map((s) => (
            <span key={s} onClick={() => setSort(s)} style={{
              padding:'3px 10px', borderRadius: 4, cursor:'pointer',
              background: sort === s ? t.bgRaised : 'transparent',
              color: sort === s ? t.ink : t.ink2,
              boxShadow: sort === s ? '0 0 0 1px rgba(0,0,0,.05)' : 'none',
            }}>{s}</span>
          ))}
        </div>

        <div style={{flex: 1}} />
        <button onClick={() => flash && flash('Demo: 拖拽 EPUB 文件到此处')} style={{
          height: 28, padding:'0 14px', borderRadius: 5,
          background: t.accentSoft, color: t.accent, border:'none', cursor:'pointer',
          fontFamily: SANS, fontSize: 12, fontWeight: 500,
          display:'inline-flex', alignItems:'center', gap: 6,
        }}><Icon name="plus" size={12} color={t.accent} /> 添加 EPUB</button>
      </div>

      <div style={{flex: 1, overflow:'auto', padding:'32px 56px 64px', position:'relative'}}>
        {filtered.length === 0 ? (
          <div style={{
            padding:'80px 0', textAlign:'center', fontFamily: SANS,
            color: t.ink3, fontSize: 13,
          }}>
            <div style={{fontFamily: SERIF, fontSize: 19, color: t.ink2, marginBottom: 8, fontStyle:'italic'}}>
              "{query}" — 书架里没有这本
            </div>
            <span style={{color: t.accent, cursor:'pointer'}} onClick={() => setQuery('')}>清除搜索</span>
          </div>
        ) : (
          <>
            {!query && sort === '最近' && (
              <SectionHead t={t} label="继续阅读" />
            )}
            <div style={{
              display:'grid',
              gridTemplateColumns:'repeat(auto-fill, minmax(168px, 1fr))',
              gap: '36px 28px',
            }}>
              {filtered.slice(0, !query && sort === '最近' ? 3 : filtered.length).map((b) => (
                <IShelfCard key={b.id} book={b} t={t} theme={theme}
                  current={currentBookId} onOpen={onOpenBook}
                  onCtx={(book, pt) => setCtx({ book, ...pt })} />
              ))}
            </div>

            {!query && sort === '最近' && filtered.length > 3 && (
              <>
                <div style={{height: 36}} />
                <SectionHead t={t} label="书架" />
                <div style={{
                  display:'grid',
                  gridTemplateColumns:'repeat(auto-fill, minmax(168px, 1fr))',
                  gap: '36px 28px',
                }}>
                  {filtered.slice(3).map((b) => (
                    <IShelfCard key={b.id} book={b} t={t} theme={theme}
                      current={currentBookId} onOpen={onOpenBook}
                      onCtx={(book, pt) => setCtx({ book, ...pt })} />
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </div>

      {/* drag overlay */}
      {dragOver && (
        <div style={{
          position:'absolute', inset: 16, pointerEvents:'none',
          background: t.accentSoft, border: `2px dashed ${t.accent}`,
          borderRadius: 10, zIndex: 10,
          display:'flex', alignItems:'center', justifyContent:'center',
        }}>
          <div style={{
            background: t.bg, padding:'18px 26px', borderRadius: 10,
            boxShadow:'0 18px 40px rgba(0,0,0,.25)',
            fontFamily: SERIF, fontSize: 17, color: t.ink, letterSpacing:'-.005em',
          }}>松开以加入书架</div>
        </div>
      )}

      {/* context menu */}
      {ctx && (
        <div data-shelf-ctx style={{
          position:'fixed', left: ctx.x, top: ctx.y, zIndex: 60,
          width: 220, background: t.bgRaised, color: t.ink,
          borderRadius: 8, overflow:'hidden', padding: 4,
          boxShadow: theme === 'dark'
            ? '0 14px 36px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5)'
            : '0 14px 36px rgba(60,40,20,.18), 0 0 0 1px rgba(0,0,0,.08)',
          fontFamily: SANS, fontSize: 12.5,
          animation:'lexiPopIn .12s ease-out',
        }}>
          {[
            { label:'打开', shortcut:'⌘O', onClick:() => { onOpenBook(ctx.book); setCtx(null); } },
            { label:'继续阅读', shortcut:'↵', hot: true,
              onClick:() => { onOpenBook(ctx.book); setCtx(null); } },
            { divider: true },
            { label:'在 Finder 中显示', shortcut:'⌥⌘R',
              onClick:() => { flash && flash('Demo: Finder reveal'); setCtx(null); } },
            { divider: true },
            { label:`清除翻译缓存 (${(ctx.book.cached * 1.05).toFixed(1)} MB)`,
              onClick:() => { flash && flash(`已清除 · ${ctx.book.title}`); setCtx(null); } },
            { divider: true },
            { label:'从书架移除', danger: true,
              onClick:() => { flash && flash('Demo: 仅做演示，不会真的移除'); setCtx(null); } },
          ].map((it, i) => it.divider ? (
            <div key={i} style={{height: 1, background: t.rule, margin:'4px 6px'}} />
          ) : (
            <button key={i} onClick={it.onClick} style={{
              display:'flex', width:'100%', justifyContent:'space-between',
              padding:'6px 10px', borderRadius: 5, border:'none', cursor:'pointer',
              background: it.hot ? t.accentSoft : 'transparent',
              color: it.danger ? t.danger : (it.hot ? t.accent : t.ink),
              fontFamily: SANS, fontSize: 12.5, fontWeight: it.hot ? 500 : 400,
              textAlign:'left',
            }}
              onMouseEnter={(e) => { if (!it.hot) e.currentTarget.style.background = t.accentFaint; }}
              onMouseLeave={(e) => { if (!it.hot) e.currentTarget.style.background = 'transparent'; }}
            >
              <span>{it.label}</span>
              {it.shortcut && <span style={{fontFamily: MONO, fontSize: 10.5, color: t.ink3}}>{it.shortcut}</span>}
            </button>
          ))}
        </div>
      )}

      {/* hint that other books reuse demo content */}
      {currentBookId !== 'gatsby' && (
        <div style={{
          position:'absolute', left: 56, bottom: 16,
          fontFamily: SANS, fontSize: 11, color: t.ink3, fontStyle:'italic',
        }}>
          演示数据：非 Gatsby 的书共用同一份章节作为占位
        </div>
      )}
    </div>
  );
}

function SectionHead({ t, label }) {
  return (
    <div style={{marginBottom: 14}}>
      <div style={{
        fontFamily: SANS, fontSize: 10.5, color: t.ink3,
        textTransform:'uppercase', letterSpacing:'.14em', fontWeight: 600,
      }}>{label}</div>
    </div>
  );
}

// Shelf-mode title bar — replaces the reader's title bar when on shelf
function ShelfTitleBar({ t, onBack, bookCount }) {
  return (
    <div style={{
      height: 44, flex:'0 0 auto', position:'relative',
      background: t.chrome, borderBottom: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', padding:'0 12px',
    }}>
      <TrafficLights />
      <div style={{
        position:'absolute', left:'50%', top:'50%', transform:'translate(-50%, -50%)',
        fontFamily: SANS, fontSize: 13, color: t.ink, fontWeight: 500, letterSpacing:'-.005em',
      }}>书架</div>
      <div style={{marginLeft:'auto', display:'flex', gap: 8, alignItems:'center',
        fontFamily: SANS, fontSize: 11.5, color: t.ink3}}>
        <span>{bookCount} 本书</span>
        {onBack && (
          <button onClick={onBack} style={{
            background:'transparent', border: `1px solid ${t.rule2}`, color: t.ink2,
            padding:'3px 10px', borderRadius: 5, cursor:'pointer',
            fontFamily: SANS, fontSize: 11.5, marginLeft: 8,
          }}>返回阅读</button>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { ShelfView, ShelfTitleBar, SHELF_BOOKS });
