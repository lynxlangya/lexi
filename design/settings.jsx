// settings.jsx — Lexi settings panel · 4 tabs
// Window: 720 × 580 · macOS native settings feel (Notes/Mail/System Settings style)
//
// Tabs: 通用 · 引擎 · 快捷键 · 阅读器

// ───────────────────── primitives ─────────────────────

function SetRow({ t, label, hint, control, last }) {
  return (
    <div style={{
      display:'grid', gridTemplateColumns:'minmax(140px, 1fr) auto',
      gap: 16, alignItems:'center',
      padding:'10px 16px', borderBottom: last ? 'none' : `1px solid ${t.rule}`,
      minHeight: 40,
    }}>
      <div>
        <div style={{fontFamily: SANS, fontSize: 12.5, color: t.ink, fontWeight: 400}}>{label}</div>
        {hint && <div style={{fontFamily: SANS, fontSize: 11, color: t.ink3, marginTop: 2, lineHeight: 1.45, fontWeight: 400}}>{hint}</div>}
      </div>
      <div style={{display:'flex', alignItems:'center', justifyContent:'flex-end'}}>
        {control}
      </div>
    </div>
  );
}

function SetCard({ t, title, children }) {
  return (
    <div style={{marginBottom: 20}}>
      {title && (
        <div style={{
          fontFamily: SANS, fontSize: 11, color: t.ink3, fontWeight: 600,
          textTransform:'uppercase', letterSpacing:'.10em',
          margin:'0 16px 8px',
        }}>{title}</div>
      )}
      <div style={{
        background: t.bgRaised, border: `1px solid ${t.rule}`,
        borderRadius: 8, overflow:'hidden',
      }}>{children}</div>
    </div>
  );
}

// macOS switch toggle
function SwTog({ t, on, label }) {
  return (
    <div style={{display:'inline-flex', alignItems:'center', gap: 8}}>
      {label && <span style={{fontFamily: SANS, fontSize: 12.5, color: t.ink2}}>{label}</span>}
      <div style={{
        width: 32, height: 18, borderRadius: 999,
        background: on ? t.accent : t.ink4,
        position:'relative', flex:'0 0 auto',
        boxShadow: 'inset 0 0 0 .5px rgba(0,0,0,.15)',
      }}>
        <div style={{
          width: 14, height: 14, borderRadius:'50%', background:'#fff',
          position:'absolute', top: 2, left: on ? 16 : 2,
          boxShadow:'0 1px 2px rgba(0,0,0,.22)',
        }} />
      </div>
    </div>
  );
}

function SwSelect({ t, value, hint }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap: 8,
      padding:'4px 10px', borderRadius: 5,
      background: t.bgInset, border: `1px solid ${t.rule2}`,
      fontFamily: SANS, fontSize: 12, color: t.ink,
      minHeight: 24,
    }}>
      <span>{value}</span>
      {hint && <span style={{color: t.ink3}}>{hint}</span>}
      <span style={{color: t.ink3, fontSize: 9}}>▾</span>
    </div>
  );
}

function SwSegmented({ t, value, options }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center',
      background: t.bgInset, padding: 2, borderRadius: 6,
      border: `1px solid ${t.rule}`,
      fontFamily: SANS, fontSize: 12,
    }}>
      {options.map((o, i) => (
        <span key={i} style={{
          padding:'3px 10px', borderRadius: 4,
          background: o === value ? t.bgRaised : 'transparent',
          color: o === value ? t.ink : t.ink2,
          boxShadow: o === value ? '0 0 0 1px rgba(0,0,0,.05), 0 1px 2px rgba(0,0,0,.04)' : 'none',
        }}>{o}</span>
      ))}
    </div>
  );
}

function SwInput({ t, value, password, wide = 200 }) {
  return (
    <div style={{
      width: wide, minHeight: 24, padding:'4px 10px',
      borderRadius: 5, background: t.bgInset, border: `1px solid ${t.rule2}`,
      fontFamily: password ? MONO : SANS, fontSize: 12, color: t.ink,
      letterSpacing: password ? '.04em' : 'normal',
    }}>{value}</div>
  );
}

function SwButton({ t, label, primary, danger }) {
  return (
    <button style={{
      padding:'4px 12px', borderRadius: 5, cursor:'pointer',
      background: primary ? t.accent : 'transparent',
      color: primary ? '#fff' : (danger ? t.danger : t.ink),
      border: primary ? 'none' : `1px solid ${danger ? t.danger : t.rule2}`,
      fontFamily: SANS, fontSize: 12, fontWeight: 500,
    }}>{label}</button>
  );
}

function SwShortcut({ t, keys, recording }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center',
      padding:'3px 10px', borderRadius: 5,
      background: recording ? t.accentSoft : t.bgInset,
      border: `1px solid ${recording ? t.accent : t.rule2}`,
      fontFamily: MONO, fontSize: 12, color: recording ? t.accent : t.ink,
      letterSpacing:'.04em', minWidth: 80, justifyContent:'center',
    }}>{recording ? '…按下快捷键' : keys}</div>
  );
}

function SwBar({ t, pct, label, color }) {
  return (
    <div style={{width: 200}}>
      <div style={{height: 4, background: t.rule, borderRadius: 2, overflow:'hidden'}}>
        <div style={{height:'100%', width:`${pct}%`, background: color || t.accent}} />
      </div>
      {label && <div style={{
        fontFamily: MONO, fontSize: 10, color: t.ink3, marginTop: 4, textAlign:'right', letterSpacing:'.04em',
      }}>{label}</div>}
    </div>
  );
}

// ───────────────────── sidebar / window chrome ─────────────────────

const TABS = [
  { id: 'general',   label: '通用',  iconPath: 'M3 8h10M3 4h10M3 12h10' },
  { id: 'engine',    label: '引擎',  iconPath: 'M8 2.5v3M8 10.5v3M2.5 8h3M10.5 8h3M4.4 4.4l2 2M9.6 9.6l2 2M4.4 11.6l2-2M9.6 6.4l2-2' },
  { id: 'shortcut',  label: '快捷键', iconPath: 'M2.5 4.5h11v7h-11zM4 7h.1M6 7h.1M8 7h.1M10 7h.1M12 7h.1M4.5 9.5h7' },
  { id: 'reader',    label: '阅读器', iconPath: 'M3 3.5h6v9H3zM9 3.5h4v9H9z' },
];

function SetSidebar({ t, tab }) {
  return (
    <aside style={{
      width: 180, flex:'0 0 180px', height:'100%',
      background: t.bgRaised, borderRight: `1px solid ${t.rule}`,
      padding: '40px 8px 16px', display:'flex', flexDirection:'column', gap: 2,
    }}>
      {TABS.map((it) => {
        const active = it.id === tab;
        return (
          <div key={it.id} style={{
            padding:'6px 12px', borderRadius: 5,
            display:'flex', alignItems:'center', gap: 9,
            background: active ? t.accentSoft : 'transparent',
            color: active ? t.accent : t.ink,
            fontFamily: SANS, fontSize: 13,
            cursor:'pointer',
            fontWeight: active ? 500 : 400,
          }}>
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke={active ? t.accent : t.ink2}
              strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
              <path d={it.iconPath} />
            </svg>
            <span>{it.label}</span>
          </div>
        );
      })}

      <div style={{flex: 1}} />

      <div style={{padding:'8px 12px', borderTop: `1px solid ${t.rule}`, marginTop: 12,
        fontFamily: SANS, fontSize: 10.5, color: t.ink3, lineHeight: 1.5}}>
        <div>Lexi 1.0 (build 412)</div>
        <div style={{color: t.accent, marginTop: 2, cursor:'pointer'}}>检查更新…</div>
      </div>
    </aside>
  );
}

function SetTopbar({ t }) {
  return (
    <div style={{
      height: 38, flex:'0 0 auto', position:'relative',
      background: t.chrome, borderBottom: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', padding:'0 12px',
    }}>
      <TrafficLights />
      <div style={{
        position:'absolute', left:'50%', top:'50%', transform:'translate(-50%, -50%)',
        fontFamily: SANS, fontSize: 12, color: t.ink2, fontWeight: 500,
      }}>设置</div>
    </div>
  );
}

// ───────────────────── tab: 通用 ─────────────────────

function GeneralTab({ t }) {
  return (
    <div>
      <SetCard t={t} title="启动 / 退出">
        <SetRow t={t} label="启动 Lexi 时" control={<SwSelect t={t} value="打开上次的书" />} />
        <SetRow t={t} label="关闭主窗口" hint="保留 menu-bar 浮窗与全局划词翻译"
          control={<SwSelect t={t} value="保留在 menu bar" />} last />
      </SetCard>

      <SetCard t={t} title="数据">
        <SetRow t={t} label="书籍与翻译缓存位置"
          control={<div style={{display:'flex', gap: 8, alignItems:'center'}}>
            <span style={{fontFamily: MONO, fontSize: 11, color: t.ink3, letterSpacing:'.01em'}}>~/Library/Lexi</span>
            <SwButton t={t} label="更改…" />
          </div>} />
        <SetRow t={t} label="iCloud 同步阅读进度 + 生词本" hint="同步发生在退出阅读会话或关闭 app 时"
          control={<SwTog t={t} on={true} />} />
        <SetRow t={t} label="开发模式" hint="启用 dev tools 与详细日志" control={<SwTog t={t} on={false} />} last />
      </SetCard>

      <SetCard t={t} title="关于">
        <SetRow t={t} label="自动检查更新" control={<SwTog t={t} on={true} />} />
        <SetRow t={t} label="发送匿名崩溃日志" control={<SwTog t={t} on={true} />} last />
      </SetCard>
    </div>
  );
}

// ───────────────────── tab: 引擎 ─────────────────────

function EngineTab({ t }) {
  return (
    <div>
      <SetCard t={t} title="默认引擎">
        <SetRow t={t} label="段落翻译" hint="阅读章节时整页 / 整段翻译"
          control={<SwSelect t={t} value="GPT-4" hint="(Turbo)" />} />
        <SetRow t={t} label="划词翻译" hint="选中文字 / ⌘⇧L 浮窗弹出"
          control={<SwSelect t={t} value="本地词典 + DeepL" />} last />
      </SetCard>

      <SetCard t={t} title="API Keys">
        <SetRow t={t} label="OpenAI"   control={<div style={{display:'flex', gap: 8}}><SwInput t={t} value="sk-•••••••••••••••••••••N7B2" password /><SwButton t={t} label="测试" /></div>} />
        <SetRow t={t} label="Anthropic" control={<div style={{display:'flex', gap: 8}}><SwInput t={t} value="sk-ant-•••••••••••••••••••••" password /><SwButton t={t} label="测试" /></div>} />
        <SetRow t={t} label="DeepL"    control={<div style={{display:'flex', gap: 8}}><SwInput t={t} value="●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● (Free)" password wide={260} /><SwButton t={t} label="测试" /></div>} last />
      </SetCard>

      <SetCard t={t} title="后备策略">
        <SetRow t={t} label="主引擎失败时" hint="超时或配额耗尽 8 秒后自动切换"
          control={<SwSelect t={t} value="按顺序: DeepL → 本地词典" />} last />
      </SetCard>

      <SetCard t={t} title="翻译缓存">
        <SetRow t={t} label="总占用"
          control={<div style={{display:'flex', alignItems:'center', gap: 12}}>
            <SwBar t={t} pct={42} label="124 / 300 MB" />
          </div>} />
        <SetRow t={t} label="" control={<div style={{display:'flex', gap: 8}}>
          <SwButton t={t} label="按书清除…" />
          <SwButton t={t} label="全部清除" danger />
        </div>} last />
      </SetCard>
    </div>
  );
}

// ───────────────────── tab: 快捷键 ─────────────────────

const SHORTCUTS = [
  { label: '划词翻译',          keys: '⌘⇧L', hint: '全局生效，App 不在前台也响应' },
  { label: '即时翻译选中文字',   keys: '⌘⇧T', hint: '不弹浮窗，结果替换选区周围' },
  { label: '显示 / 隐藏阅读器',   keys: '⌘⇧K', hint: '全局' },
  { label: '加入生词本',         keys: '⌘D' },
  { label: '朗读选中内容',       keys: '⌘.' },
  { label: '切换 仅原文/译文/双语', keys: '⌘B' },
  { label: '下一章 / 上一章',     keys: '⌘] / ⌘[' },
  { label: '切换侧栏目录',       keys: '⌘0' },
  { label: '字号大 / 小',         keys: '⌘+ / ⌘-' },
];

function ShortcutTab({ t }) {
  return (
    <div>
      <SetCard t={t} title="阅读器">
        {SHORTCUTS.slice(0, 6).map((s, i) => (
          <SetRow key={i} t={t} label={s.label} hint={s.hint}
            control={<SwShortcut t={t} keys={s.keys} recording={i === 3} />}
            last={i === 5} />
        ))}
      </SetCard>

      <SetCard t={t} title="导航">
        {SHORTCUTS.slice(6).map((s, i) => (
          <SetRow key={i} t={t} label={s.label} hint={s.hint}
            control={<SwShortcut t={t} keys={s.keys} />}
            last={i === SHORTCUTS.length - 6 - 1} />
        ))}
      </SetCard>

      <SetCard t={t} title="">
        <SetRow t={t} label="冲突检测"
          hint="当 Lexi 快捷键与系统或其他 app 冲突时提示"
          control={<SwTog t={t} on={true} />} last />
      </SetCard>
    </div>
  );
}

// ───────────────────── tab: 阅读器 ─────────────────────

function ReaderTab({ t }) {
  return (
    <div>
      <SetCard t={t} title="排版">
        <SetRow t={t} label="正文字号" hint="也可在阅读时用 ⌘+ / ⌘- 临时调整"
          control={<div style={{display:'flex', alignItems:'center', gap: 10}}>
            <span style={{fontFamily: MONO, fontSize: 11, color: t.ink3}}>17pt</span>
            <SwBar t={t} pct={(17 - 14) / 8 * 100} />
          </div>} />
        <SetRow t={t} label="衬线字体" control={<SwSelect t={t} value="New York" />} />
        <SetRow t={t} label="中文译文字体" control={<SwSelect t={t} value="PingFang SC" />} />
        <SetRow t={t} label="行距" hint="影响 EN 正文，ZH 自动 +6%"
          control={<SwSegmented t={t} value="1.72" options={['1.55','1.72','1.85']} />} last />
      </SetCard>

      <SetCard t={t} title="译文显示">
        <SetRow t={t} label="默认显示模式"
          control={<SwSegmented t={t} value="原文+译文" options={['原文+译文','仅原文','仅译文']} />} />
        <SetRow t={t} label="译文视觉强度" hint="A 纯字号降级 · B 左侧竖线 · C 淡背景块"
          control={<SwSegmented t={t} value="A" options={['A','B','C']} />} />
        <SetRow t={t} label="章节预取" hint="后台预先翻译相邻章节"
          control={<SwSegmented t={t} value="1 章" options={['0','1 章','2 章']} />} last />
      </SetCard>

      <SetCard t={t} title="暗色阅读">
        <SetRow t={t} label="暗色模式"
          control={<SwSegmented t={t} value="跟随系统" options={['跟随系统','总是亮','总是暗']} />} />
        <SetRow t={t} label="暗色色温" hint="越偏右越暖，长时段阅读建议偏暖"
          control={<div style={{display:'flex', alignItems:'center', gap: 8, width: 220}}>
            <span style={{fontFamily: MONO, fontSize: 9.5, color: t.ink3}}>冷</span>
            <SwBar t={t} pct={72} color={t.accent} />
            <span style={{fontFamily: MONO, fontSize: 9.5, color: t.ink3}}>暖</span>
          </div>} />
        <SetRow t={t} label="重音色"
          control={<div style={{display:'flex', gap: 6}}>
            {['#b35c2c','#a85a2a','#7d6644','#9c4a39'].map((c, i) => (
              <div key={i} style={{
                width: 18, height: 18, borderRadius:'50%', background: c,
                border: i === 0 ? `1.5px solid ${t.ink}` : '1.5px solid transparent',
                boxShadow:'inset 0 0 0 1px rgba(0,0,0,.10)',
              }} />
            ))}
          </div>} last />
      </SetCard>
    </div>
  );
}

// ───────────────────── full window ─────────────────────

function SettingsWindow({ theme = 'dark', tab = 'general' }) {
  const t = TOKENS[theme];
  const W = 720, H = 580;
  const dark = theme === 'dark';
  const TabComp = { general: GeneralTab, engine: EngineTab, shortcut: ShortcutTab, reader: ReaderTab }[tab] || GeneralTab;
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
      <SetTopbar t={t} />
      <div style={{flex: 1, display:'flex', minHeight: 0}}>
        <SetSidebar t={t} tab={tab} />
        <div style={{flex: 1, overflow:'auto', padding:'28px 20px 36px'}}>
          <TabComp t={t} />
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { SettingsWindow });
