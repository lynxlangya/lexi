// prototype-settings.jsx — Interactive settings sheet for the Lexi prototype.
// Modal centered card (720 × 580) backed by useTweaks state — toggles take effect live.

// ── shared bits (forks of settings.jsx, parameterized to live state) ──

function ISetRow({ t, label, hint, control, last }) {
  return (
    <div style={{
      display:'flex', alignItems:'center', gap: 16,
      padding:'10px 16px', borderBottom: last ? 'none' : `1px solid ${t.rule}`,
      minHeight: 40,
    }}>
      <div style={{flex:'1 1 0%', minWidth: 120}}>
        <div style={{fontFamily: SANS, fontSize: 12.5, color: t.ink}}>{label}</div>
        {hint && <div style={{fontFamily: SANS, fontSize: 11, color: t.ink3, marginTop: 2, lineHeight: 1.45}}>{hint}</div>}
      </div>
      <div style={{flex:'0 0 auto', display:'flex', alignItems:'center', justifyContent:'flex-end', minWidth: 0}}>{control}</div>
    </div>
  );
}

function ISetCard({ t, title, children }) {
  return (
    <div style={{marginBottom: 18}}>
      {title && (
        <div style={{
          fontFamily: SANS, fontSize: 10.5, color: t.ink3, fontWeight: 600,
          textTransform:'uppercase', letterSpacing:'.10em', margin:'0 16px 8px',
        }}>{title}</div>
      )}
      <div style={{
        background: t.bgRaised, border: `1px solid ${t.rule}`,
        borderRadius: 8, overflow:'hidden',
      }}>{children}</div>
    </div>
  );
}

function ITog({ t, value, onChange }) {
  return (
    <div onClick={() => onChange(!value)} style={{
      width: 32, height: 18, borderRadius: 999, cursor:'pointer',
      background: value ? t.accent : t.ink4, position:'relative',
      boxShadow: 'inset 0 0 0 .5px rgba(0,0,0,.15)',
    }}>
      <div style={{
        width: 14, height: 14, borderRadius:'50%', background:'#fff',
        position:'absolute', top: 2, left: value ? 16 : 2,
        boxShadow:'0 1px 2px rgba(0,0,0,.22)',
        transition: 'left .12s',
      }} />
    </div>
  );
}

function ISelect({ t, value, options, onChange }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} style={{
      padding:'4px 24px 4px 10px', borderRadius: 5,
      background: t.bgInset, color: t.ink,
      border: `1px solid ${t.rule2}`, fontFamily: SANS, fontSize: 12,
      cursor:'pointer', appearance:'none',
      backgroundImage: `linear-gradient(45deg, transparent 50%, ${t.ink3} 50%),
                        linear-gradient(135deg, ${t.ink3} 50%, transparent 50%)`,
      backgroundPosition: 'calc(100% - 13px) center, calc(100% - 8px) center',
      backgroundSize: '5px 5px',
      backgroundRepeat: 'no-repeat',
    }}>
      {options.map((o) => {
        const v = typeof o === 'string' ? o : o.value;
        const l = typeof o === 'string' ? o : o.label;
        return <option key={v} value={v}>{l}</option>;
      })}
    </select>
  );
}

function ISegmented({ t, value, options, onChange }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center',
      background: t.bgInset, padding: 2, borderRadius: 6,
      border: `1px solid ${t.rule}`, fontFamily: SANS, fontSize: 12,
    }}>
      {options.map((o) => {
        const v = typeof o === 'string' ? o : o.value;
        const l = typeof o === 'string' ? o : o.label;
        const active = v === value;
        return (
          <span key={v} onClick={() => onChange(v)} style={{
            padding:'3px 10px', borderRadius: 4, cursor:'pointer',
            background: active ? t.bgRaised : 'transparent',
            color: active ? t.ink : t.ink2,
            boxShadow: active ? '0 0 0 1px rgba(0,0,0,.05), 0 1px 2px rgba(0,0,0,.04)' : 'none',
          }}>{l}</span>
        );
      })}
    </div>
  );
}

function ISlider({ t, value, min, max, step = 1, unit = '', onChange, width = 200 }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{display:'flex', alignItems:'center', gap: 10}}>
      <span style={{fontFamily: MONO, fontSize: 11, color: t.ink3, minWidth: 28, textAlign:'right'}}>{value}{unit}</span>
      <div style={{position:'relative', width, height: 16, display:'flex', alignItems:'center'}}>
        <div style={{position:'absolute', left: 0, right: 0, height: 3, background: t.rule, borderRadius: 2}} />
        <div style={{position:'absolute', left: 0, height: 3, background: t.accent, width: `${pct}%`, borderRadius: 2}} />
        <input type="range" value={value} min={min} max={max} step={step}
          onChange={(e) => onChange(Number(e.target.value))}
          style={{position:'absolute', inset: 0, opacity: 0, cursor:'pointer', width:'100%'}} />
        <div style={{
          position:'absolute', left: `calc(${pct}% - 8px)`,
          width: 16, height: 16, borderRadius:'50%', background:'#fff',
          boxShadow:'0 1px 3px rgba(0,0,0,.3), 0 0 0 .5px rgba(0,0,0,.1)',
          pointerEvents:'none',
        }} />
      </div>
    </div>
  );
}

function IShortcut({ t, keys }) {
  return (
    <div style={{
      padding:'3px 10px', borderRadius: 5, background: t.bgInset,
      border: `1px solid ${t.rule2}`,
      fontFamily: MONO, fontSize: 12, color: t.ink, letterSpacing:'.04em',
      minWidth: 80, textAlign:'center',
    }}>{keys}</div>
  );
}

function IButton({ t, label, primary, danger, onClick }) {
  return (
    <button onClick={onClick} style={{
      padding:'4px 12px', borderRadius: 5, cursor:'pointer',
      background: primary ? t.accent : 'transparent',
      color: primary ? '#fff' : (danger ? t.danger : t.ink),
      border: primary ? 'none' : `1px solid ${danger ? t.danger : t.rule2}`,
      fontFamily: SANS, fontSize: 12, fontWeight: 500,
    }}>{label}</button>
  );
}

const I_TABS = [
  { id:'general',  label:'通用',   iconPath:'M3 8h10M3 4h10M3 12h10' },
  { id:'engine',   label:'引擎',   iconPath:'M8 2.5v3M8 10.5v3M2.5 8h3M10.5 8h3M4.4 4.4l2 2M9.6 9.6l2 2M4.4 11.6l2-2M9.6 6.4l2-2' },
  { id:'shortcut', label:'快捷键', iconPath:'M2.5 4.5h11v7h-11zM4 7h.1M6 7h.1M8 7h.1M10 7h.1M12 7h.1M4.5 9.5h7' },
  { id:'reader',   label:'阅读器', iconPath:'M3 3.5h6v9H3zM9 3.5h4v9H9z' },
];

// ── tabs ──────────────────────────────────────────────────────────────────

function ITabGeneral({ t, tw, setTw, flash }) {
  return (
    <div>
      <ISetCard t={t} title="启动 / 退出">
        <ISetRow t={t} label="启动 Lexi 时"
          control={<ISelect t={t} value={tw.onLaunch || 'last'} onChange={(v) => setTw('onLaunch', v)}
            options={[
              { label:'打开上次的书', value:'last' },
              { label:'打开书架',     value:'shelf' },
              { label:'什么也不做',    value:'nothing' },
            ]} />} />
        <ISetRow t={t} label="关闭主窗口" hint="保留 menu-bar 浮窗与全局划词翻译"
          control={<ISelect t={t} value={tw.onClose || 'menubar'} onChange={(v) => setTw('onClose', v)}
            options={[
              { label:'保留在 menu bar', value:'menubar' },
              { label:'完全退出',       value:'quit' },
            ]} />} last />
      </ISetCard>

      <ISetCard t={t} title="数据">
        <ISetRow t={t} label="书籍与翻译缓存位置"
          control={<div style={{display:'flex', gap: 8, alignItems:'center'}}>
            <span style={{fontFamily: MONO, fontSize: 11, color: t.ink3}}>~/Library/Lexi</span>
            <IButton t={t} label="更改…" onClick={() => flash && flash('Demo: 文件选择器')} />
          </div>} />
        <ISetRow t={t} label="iCloud 同步阅读进度 + 生词本"
          control={<ITog t={t} value={tw.icloud ?? true} onChange={(v) => setTw('icloud', v)} />} last />
      </ISetCard>

      <ISetCard t={t} title="关于">
        <ISetRow t={t} label="自动检查更新"
          control={<ITog t={t} value={tw.autoUpdate ?? true} onChange={(v) => setTw('autoUpdate', v)} />} />
        <ISetRow t={t} label="发送匿名崩溃日志"
          control={<ITog t={t} value={tw.crashLogs ?? true} onChange={(v) => setTw('crashLogs', v)} />} last />
      </ISetCard>
    </div>
  );
}

function ITabEngine({ t, tw, setTw, chapterEngine, setChapterEngine, flash }) {
  const keyRows = [
    { id:'openai',    label:'OpenAI',    hint:'GPT-4 / GPT-3.5',                     masked:'sk-•••••••••••••••••••N7B2',  status:'ok' },
    { id:'anthropic', label:'Anthropic', hint:'Claude 3.5 Sonnet',                   masked:'sk-ant-•••••••••••••••••• ', status:'ok' },
    { id:'deepl',     label:'DeepL',     hint:'Free · 还剩 423K / 500K 字符 (本月)',  masked:'',                            status:'unset' },
  ];
  const customEngines = [
    { id:'ollama',   name:'本地 Llama 3',     type:'ollama',             url:'http://localhost:11434', enabled: true,  status:'ok'    },
    { id:'deepseek', name:'DeepSeek Chat',    type:'openai-compatible',  url:'api.deepseek.com',        enabled: true,  status:'ok'    },
    { id:'kimi',     name:'Kimi (Moonshot)',  type:'openai-compatible',  url:'api.moonshot.cn',         enabled: false, status:'idle'  },
  ];
  return (
    <div>
      <ISetCard t={t} title="默认引擎">
        <ISetRow t={t} label="段落翻译" hint="阅读章节时整页 / 整段翻译"
          control={<ISelect t={t} value={chapterEngine} onChange={setChapterEngine}
            options={[
              { label:'GPT-4 (Turbo)',    value:'GPT-4' },
              { label:'Claude 3.5',       value:'Claude' },
              { label:'DeepL',            value:'DeepL' },
              { label:'Google',           value:'Google' },
              { label:'— 自定义 —',       value:'__sep__' },
              { label:'本地 Llama 3',     value:'Llama 3' },
              { label:'DeepSeek Chat',    value:'DeepSeek' },
            ]} />} />
        <ISetRow t={t} label="划词翻译" hint="选中文字 / ⌘⇧L 浮窗弹出"
          control={<ISelect t={t} value={tw.popupEngine || 'Dict'} onChange={(v) => setTw('popupEngine', v)}
            options={['Dict', 'DeepL', 'GPT', 'Claude', 'Llama 3']} />} last />
      </ISetCard>

      <ISetCard t={t} title="API Keys">
        {keyRows.map((r, i) => (
          <ISetRow key={r.id} t={t} label={r.label} hint={r.hint}
            control={<APIKeyField t={t} masked={r.masked} status={r.status}
              onTest={() => flash && flash(`${r.label} · 连接成功 (${380 + i*30}ms)`)}
              onSet={() => flash && flash(`Demo: 输入 ${r.label} API key`)} />}
            last={i === keyRows.length - 1} />
        ))}
      </ISetCard>

      <ISetCard t={t} title="自定义引擎">
        {customEngines.map((e, i) => (
          <CustomEngineRow key={e.id} t={t} engine={e}
            onToggle={(v) => flash && flash(`${e.name} · ${v ? '已启用' : '已停用'}`)}
            onTest={() => flash && flash(`${e.name} · 连接成功`)}
            onEdit={() => flash && flash(`Demo: 编辑 ${e.name}`)}
            last={i === customEngines.length - 1 && false /* keep border for "+" row */} />
        ))}
        <div style={{padding:'8px 16px', display:'flex'}}>
          <button onClick={() => flash && flash('Demo: 添加自定义引擎面板')} style={{
            display:'inline-flex', alignItems:'center', gap: 6,
            background:'transparent', border:'none', cursor:'pointer',
            color: t.accent, fontFamily: SANS, fontSize: 12, padding: 0,
          }}>
            <Icon name="plus" size={11} color={t.accent} /> 添加自定义引擎
          </button>
          <span style={{marginLeft: 14, fontFamily: SANS, fontSize: 11, color: t.ink3, fontStyle:'italic'}}>
            支持 OpenAI-compatible · Ollama · 任意 POST endpoint
          </span>
        </div>
      </ISetCard>

      <ISetCard t={t} title="翻译缓存">
        <ISetRow t={t} label="总占用"
          control={<div style={{width: 200}}>
            <div style={{height: 4, background: t.rule, borderRadius: 2, overflow:'hidden'}}>
              <div style={{height:'100%', width:'42%', background: t.accent}} />
            </div>
            <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, marginTop: 4, textAlign:'right'}}>124 / 300 MB</div>
          </div>} />
        <ISetRow t={t} label=""
          control={<div style={{display:'flex', gap: 8}}>
            <IButton t={t} label="按书清除…" onClick={() => flash && flash('Demo: 按书清除面板')} />
            <IButton t={t} label="全部清除" danger onClick={() => flash && flash('已清除全部翻译缓存')} />
          </div>} last />
      </ISetCard>
    </div>
  );
}

// Custom engine row — name + type tag + url + enabled toggle + test + ⋯
function CustomEngineRow({ t, engine, onToggle, onTest, onEdit, last }) {
  const [on, setOn] = useState(engine.enabled);
  const ok = engine.status === 'ok' && on;
  return (
    <div style={{
      display:'flex', alignItems:'center', gap: 12,
      padding:'10px 16px', borderBottom: last ? 'none' : `1px solid ${t.rule}`,
      minHeight: 44, opacity: on ? 1 : .55,
    }}>
      <span style={{
        width: 6, height: 6, borderRadius:'50%',
        background: ok ? '#5a8a52' : t.ink4, flex:'0 0 auto',
        boxShadow: ok ? `0 0 0 2px ${t.bgRaised}` : 'none',
      }} />
      <div style={{flex: 1, minWidth: 0}}>
        <div style={{
          display:'flex', alignItems:'center', gap: 8,
          fontFamily: SANS, fontSize: 12.5, color: t.ink,
        }}>
          <span>{engine.name}</span>
          <span style={{
            padding:'1px 6px', borderRadius: 3,
            background: t.bgInset, border: `1px solid ${t.rule}`,
            fontFamily: MONO, fontSize: 9.5, color: t.ink3, letterSpacing:'.04em',
            textTransform:'uppercase', fontWeight: 500,
          }}>{engine.type}</span>
        </div>
        <div style={{
          fontFamily: MONO, fontSize: 11, color: t.ink3, marginTop: 2, letterSpacing:'.01em',
          overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap',
        }}>{engine.url}</div>
      </div>
      <ITog t={t} value={on} onChange={(v) => { setOn(v); onToggle(v); }} />
      <button onClick={onTest} style={{
        padding:'0 9px', height: 24, borderRadius: 5,
        background:'transparent', color: t.ink2,
        border: `1px solid ${t.rule2}`, cursor:'pointer',
        fontFamily: SANS, fontSize: 11.5, fontWeight: 500,
      }}>测试</button>
      <button onClick={onEdit} title="编辑" style={{
        width: 22, height: 24, padding: 0, borderRadius: 5,
        background:'transparent', color: t.ink3,
        border: `1px solid ${t.rule2}`, cursor:'pointer',
        fontFamily: SANS, fontSize: 13, lineHeight: '20px',
        display:'inline-flex', alignItems:'center', justifyContent:'center',
      }}>⋯</button>
    </div>
  );
}

// API key row — status dot · masked key (or "未设置") · 测试 · 更换
function APIKeyField({ t, masked, status, onTest, onSet }) {
  const ok = status === 'ok';
  const dotColor = ok ? '#5a8a52' : t.ink4;
  return (
    <div style={{display:'inline-flex', alignItems:'stretch', gap: 6, height: 24}}>
      <div style={{
        display:'inline-flex', alignItems:'center', gap: 7,
        padding:'0 9px', borderRadius: 5,
        background: t.bgInset, border: `1px solid ${t.rule2}`,
        width: 184,
      }}>
        <span style={{
          width: 6, height: 6, borderRadius:'50%',
          background: dotColor, flex:'0 0 auto',
          boxShadow: ok ? `0 0 0 2px ${t.bgInset}` : 'none',
        }} />
        <span style={{
          flex: 1, minWidth: 0, fontFamily: MONO, fontSize: 11,
          color: ok ? t.ink : t.ink3, letterSpacing:'.02em',
          fontStyle: ok ? 'normal' : 'italic',
          overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap',
        }}>{ok ? masked : '未设置'}</span>
      </div>
      {ok ? (
        <>
          <button onClick={onTest} style={{
            padding:'0 9px', borderRadius: 5,
            background:'transparent', color: t.ink2,
            border: `1px solid ${t.rule2}`, cursor:'pointer',
            fontFamily: SANS, fontSize: 11.5, fontWeight: 500,
          }}>测试</button>
          <button onClick={onSet} title="更换 Key" style={{
            width: 22, padding: 0, borderRadius: 5,
            background:'transparent', color: t.ink3,
            border: `1px solid ${t.rule2}`, cursor:'pointer',
            fontFamily: SANS, fontSize: 13, lineHeight: '20px',
            display:'inline-flex', alignItems:'center', justifyContent:'center',
          }}>⋯</button>
        </>
      ) : (
        <button onClick={onSet} style={{
          padding:'0 10px', borderRadius: 5,
          background: t.accent, color:'#fff',
          border:'none', cursor:'pointer',
          fontFamily: SANS, fontSize: 11.5, fontWeight: 500,
        }}>设置…</button>
      )}
    </div>
  );
}

const I_SHORTCUTS = [
  { label:'划词翻译',            keys:'⌘⇧L', hint:'全局生效' },
  { label:'即时翻译选中文字',     keys:'⌘⇧T', hint:'不弹浮窗，替换选区' },
  { label:'显示 / 隐藏阅读器',     keys:'⌘⇧K', hint:'全局' },
  { label:'加入生词本',           keys:'⌘D' },
  { label:'朗读选中内容',         keys:'⌘.' },
  { label:'切换 仅原文/译文/双语', keys:'⌘B' },
  { label:'下一章 / 上一章',       keys:'⌘] / ⌘[' },
  { label:'切换侧栏目录',         keys:'⌘0' },
  { label:'字号大 / 小',           keys:'⌘+ / ⌘-' },
];

function ITabShortcut({ t, tw, setTw }) {
  return (
    <div>
      <ISetCard t={t} title="阅读器">
        {I_SHORTCUTS.slice(0, 6).map((s, i) => (
          <ISetRow key={i} t={t} label={s.label} hint={s.hint}
            control={<IShortcut t={t} keys={s.keys} />}
            last={i === 5} />
        ))}
      </ISetCard>
      <ISetCard t={t} title="导航">
        {I_SHORTCUTS.slice(6).map((s, i) => (
          <ISetRow key={i} t={t} label={s.label} hint={s.hint}
            control={<IShortcut t={t} keys={s.keys} />}
            last={i === I_SHORTCUTS.length - 6 - 1} />
        ))}
      </ISetCard>
      <ISetCard t={t} title="">
        <ISetRow t={t} label="冲突检测" hint="当 Lexi 快捷键与系统或其他 app 冲突时提示"
          control={<ITog t={t} value={tw.conflictDetect ?? true} onChange={(v) => setTw('conflictDetect', v)} />} last />
      </ISetCard>
    </div>
  );
}

function ITabReader({ t, tw, setTw, accentSwatches }) {
  return (
    <div>
      <ISetCard t={t} title="排版">
        <ISetRow t={t} label="正文字号"
          hint="也可在阅读时用 ⌘+ / ⌘- 临时调整"
          control={<ISlider t={t} value={tw.fontSize} min={14} max={22} unit="pt"
            onChange={(v) => setTw('fontSize', v)} />} />
        <ISetRow t={t} label="衬线字体"
          control={<ISelect t={t} value={tw.serif}
            options={Object.keys(SERIF_CHOICES)}
            onChange={(v) => setTw('serif', v)} />} />
        <ISetRow t={t} label="行距" hint="影响 EN 正文，ZH 自动 +6%"
          control={<ISegmented t={t} value={tw.lineH || 'normal'}
            options={[
              { label:'紧凑', value:'tight' },
              { label:'标准', value:'normal' },
              { label:'宽松', value:'loose' },
            ]}
            onChange={(v) => setTw('lineH', v)} />} last />
      </ISetCard>

      <ISetCard t={t} title="译文显示">
        <ISetRow t={t} label="默认显示模式"
          control={<ISegmented t={t} value={tw.transMode}
            options={[
              { label:'原文+译文', value:'both' },
              { label:'仅原文',    value:'en' },
              { label:'仅译文',    value:'zh' },
            ]}
            onChange={(v) => setTw('transMode', v)} />} />
        <ISetRow t={t} label="译文视觉强度" hint="A 纯字号降级 · B 左侧竖线 · C 淡背景块"
          control={<ISegmented t={t} value={tw.paraStyle}
            options={[
              { label:'A 字号', value:'demote' },
              { label:'B 竖线', value:'rule' },
              { label:'C 底色', value:'tint' },
            ]}
            onChange={(v) => setTw('paraStyle', v)} />} />
        <ISetRow t={t} label="章节预取" hint="后台预先翻译相邻章节"
          control={<ISegmented t={t} value={tw.prefetch || '1'}
            options={[
              { label:'0',    value:'0' },
              { label:'1 章', value:'1' },
              { label:'2 章', value:'2' },
            ]}
            onChange={(v) => setTw('prefetch', v)} />} last />
      </ISetCard>

      <ISetCard t={t} title="主题">
        <ISetRow t={t} label="模式"
          control={<ISegmented t={t} value={tw.theme}
            options={[
              { label:'亮 Paper',     value:'light' },
              { label:'暗 Candlelit', value:'dark' },
            ]}
            onChange={(v) => setTw('theme', v)} />} />
        <ISetRow t={t} label="重音色"
          control={<div style={{display:'flex', gap: 8}}>
            {accentSwatches.map((c, i) => (
              <button key={i} onClick={() => setTw('accentIdx', i)} style={{
                width: 22, height: 22, padding: 0, borderRadius:'50%',
                background: c, cursor:'pointer',
                border: i === tw.accentIdx ? `2px solid ${t.ink}` : '2px solid transparent',
                boxShadow:'inset 0 0 0 1px rgba(0,0,0,.10)',
              }} />
            ))}
          </div>} last />
      </ISetCard>
    </div>
  );
}

// ── settings modal sheet ─────────────────────────────────────────────────

function SettingsSheet({ t, theme, tw, setTw, chapterEngine, setChapterEngine, accentSwatches, flash, onClose }) {
  const [tab, setTab] = useState('reader');

  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div onClick={onClose} style={{
      position:'fixed', inset: 0, zIndex: 80,
      background: theme === 'dark' ? 'rgba(0,0,0,.55)' : 'rgba(60,40,20,.30)',
      display:'flex', alignItems:'center', justifyContent:'center',
      animation:'lexiPopIn .14s ease-out',
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        width: 720, height: 580,
        background: t.bg, color: t.ink,
        borderRadius: 10, overflow:'hidden',
        boxShadow: theme === 'dark'
          ? '0 40px 100px rgba(0,0,0,.65), 0 0 0 1px rgba(0,0,0,.6)'
          : '0 40px 100px rgba(60,40,20,.30), 0 0 0 1px rgba(0,0,0,.12)',
        display:'flex', flexDirection:'column',
        fontFeatureSettings:'"kern","liga","calt"',
      }}>
        {/* title bar */}
        <div style={{
          height: 38, flex:'0 0 auto', position:'relative',
          background: t.chrome, borderBottom: `1px solid ${t.rule}`,
          display:'flex', alignItems:'center', padding:'0 12px',
        }}>
          <div style={{display:'flex', gap: 8, alignItems:'center'}}>
            <button onClick={onClose} aria-label="close" style={{
              width: 12, height: 12, borderRadius:'50%', background:'#ff5f57',
              border:'none', padding: 0, cursor:'pointer',
              boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)',
            }} />
            <span style={{width: 12, height: 12, borderRadius:'50%', background:'#febc2e',
              boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
            <span style={{width: 12, height: 12, borderRadius:'50%', background:'#28c840',
              boxShadow:'inset 0 0 0 .5px rgba(0,0,0,.18)'}} />
          </div>
          <div style={{
            position:'absolute', left:'50%', top:'50%', transform:'translate(-50%, -50%)',
            fontFamily: SANS, fontSize: 12, color: t.ink2, fontWeight: 500,
          }}>设置</div>
        </div>

        <div style={{flex: 1, display:'flex', minHeight: 0}}>
          {/* sidebar */}
          <aside style={{
            width: 180, flex:'0 0 180px',
            background: t.bgRaised, borderRight: `1px solid ${t.rule}`,
            padding: '20px 8px 16px', display:'flex', flexDirection:'column', gap: 2,
          }}>
            {I_TABS.map((it) => {
              const active = it.id === tab;
              return (
                <button key={it.id} onClick={() => setTab(it.id)} style={{
                  padding:'6px 12px', borderRadius: 5,
                  display:'flex', alignItems:'center', gap: 9,
                  background: active ? t.accentSoft : 'transparent',
                  color: active ? t.accent : t.ink,
                  fontFamily: SANS, fontSize: 13, fontWeight: active ? 500 : 400,
                  border:'none', cursor:'pointer', textAlign:'left',
                }}
                  onMouseEnter={(e) => { if (!active) e.currentTarget.style.background = t.accentFaint; }}
                  onMouseLeave={(e) => { if (!active) e.currentTarget.style.background = 'transparent'; }}
                >
                  <svg width="14" height="14" viewBox="0 0 16 16" fill="none"
                    stroke={active ? t.accent : t.ink2} strokeWidth="1.4"
                    strokeLinecap="round" strokeLinejoin="round">
                    <path d={it.iconPath} />
                  </svg>
                  {it.label}
                </button>
              );
            })}
            <div style={{flex: 1}} />
            <div style={{padding:'8px 12px', borderTop: `1px solid ${t.rule}`, marginTop: 12,
              fontFamily: SANS, fontSize: 10.5, color: t.ink3, lineHeight: 1.5}}>
              <div>Lexi 1.0 (build 412)</div>
              <div style={{color: t.accent, marginTop: 2, cursor:'pointer'}}>检查更新…</div>
            </div>
          </aside>

          {/* content */}
          <div style={{flex: 1, overflow:'auto', padding:'20px 16px 28px'}}>
            {tab === 'general'  && <ITabGeneral  t={t} tw={tw} setTw={setTw} flash={flash} />}
            {tab === 'engine'   && <ITabEngine   t={t} tw={tw} setTw={setTw} chapterEngine={chapterEngine} setChapterEngine={setChapterEngine} flash={flash} />}
            {tab === 'shortcut' && <ITabShortcut t={t} tw={tw} setTw={setTw} />}
            {tab === 'reader'   && <ITabReader   t={t} tw={tw} setTw={setTw} accentSwatches={accentSwatches} />}
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { SettingsSheet });
