// menubar.jsx — Lexi menu-bar popup (划词翻译浮窗)
// 4 states × 2 themes:
//   word     — IPA + POS + senses + TTS + add-to-vocab (placeholder)
//   sentence — clean translation, source/target swap, engine, copy
//   loading  — skeleton, faint shimmer, "正在翻译…"
//   error    — friendly error + retry + "去设置"
//
// Width 380, content height fluid. Renders as a floating card with a soft
// shadow + 1px ring; macOS vibrancy is mimicked with the warm chrome color.

function PopBtn({ children, t, primary, dim }) {
  return (
    <button style={{
      background: primary ? t.accent : 'transparent',
      color: primary ? '#fff' : (dim ? t.ink3 : t.ink2),
      border: primary ? 'none' : `1px solid ${t.rule2}`,
      borderRadius: 5, padding:'3px 10px', fontSize: 11.5, fontFamily: SANS,
      cursor:'pointer', display:'inline-flex', alignItems:'center', gap: 5,
      letterSpacing:'.01em',
    }}>{children}</button>
  );
}

function EnginePill({ t, active, label }) {
  return (
    <span style={{
      padding:'2px 8px', borderRadius: 4,
      background: active ? t.accentSoft : 'transparent',
      color: active ? t.accent : t.ink3,
      fontFamily: SANS, fontSize: 10.5, fontWeight: active ? 600 : 500,
      letterSpacing:'.02em',
      cursor:'pointer',
    }}>{label}</span>
  );
}

function PopShell({ t, theme, children, width = 380 }) {
  return (
    <div style={{
      width, background: t.bgRaised, color: t.ink,
      borderRadius: 12, overflow:'hidden',
      boxShadow: theme === 'dark'
        ? '0 24px 60px rgba(0,0,0,.55), 0 0 0 1px rgba(0,0,0,.5), inset 0 .5px 0 rgba(255,255,255,.05)'
        : '0 22px 50px rgba(60,40,20,.20), 0 0 0 1px rgba(0,0,0,.08), inset 0 .5px 0 rgba(255,255,255,.6)',
      fontFeatureSettings:'"kern","liga","calt"',
      // backdrop hint
      backdropFilter:'blur(20px)',
    }}>
      {children}
    </div>
  );
}

function PopHeader({ t, label, right }) {
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

function PopFooter({ t, children }) {
  return (
    <div style={{
      padding:'8px 12px',
      borderTop: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', justifyContent:'space-between',
      background: t.bg,
    }}>{children}</div>
  );
}

// ───────────── state: WORD ─────────────

function WordPop({ theme }) {
  const t = TOKENS[theme];
  return (
    <PopShell t={t} theme={theme}>
      <PopHeader t={t} label="Lexi · 单词" right={
        <span style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em'}}>⌘⇧L</span>
      } />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{display:'flex', alignItems:'baseline', gap: 10, flexWrap:'wrap'}}>
          <span style={{fontFamily: SERIF, fontSize: 26, color: t.ink, letterSpacing:'-.01em', fontWeight: 500}}>vulnerable</span>
          <span style={{fontFamily: MONO, fontSize: 12.5, color: t.ink3, letterSpacing:'.02em'}}>/ˈvʌlnərəbl/</span>
          <button style={{
            border:'none', background:'transparent', color: t.ink3, padding: 2,
            cursor:'pointer', display:'flex', alignItems:'center',
          }}><Icon name="speaker" size={14} /></button>
        </div>

        <div style={{height: 12}} />

        <div style={{display:'flex', flexDirection:'column', gap: 10}}>
          {[
            { pos: 'adj.', en: 'exposed to harm; emotionally open and unguarded', zh: '易受伤害的；脆弱的、情感上不设防的' },
            { pos: 'adj.', en: '(of a position) susceptible to attack',           zh: '（指位置、立场）易受攻击的' },
          ].map((s, i) => (
            <div key={i} style={{display:'flex', gap: 10, alignItems:'flex-start'}}>
              <span style={{
                flex:'0 0 32px', fontFamily: SERIF, fontStyle:'italic',
                fontSize: 12, color: t.accent, lineHeight: 1.5, paddingTop: 1,
              }}>{s.pos}</span>
              <div style={{flex: 1, minWidth: 0}}>
                <div style={{fontFamily: SERIF, fontSize: 13.5, color: t.ink, lineHeight: 1.5}}>{s.en}</div>
                <div style={{fontFamily: ZH, fontSize: 12.5, color: t.ink2, lineHeight: 1.6, marginTop: 2}}>{s.zh}</div>
              </div>
            </div>
          ))}
        </div>

        <div style={{height: 14}} />

        <div style={{
          padding:'10px 12px', borderRadius: 6,
          background: t.bgInset, border: `1px solid ${t.rule}`,
        }}>
          <div style={{fontFamily: MONO, fontSize: 9.5, color: t.ink3, letterSpacing:'.08em', textTransform:'uppercase', marginBottom: 5}}>原文 · in context</div>
          <div style={{fontFamily: SERIF, fontSize: 12.5, color: t.ink2, fontStyle:'italic', lineHeight: 1.55}}>
            "In my younger and more <span style={{background: t.sel, color: t.ink, padding:'0 1px', borderRadius: 2, fontStyle:'normal'}}>vulnerable</span> years…"
          </div>
        </div>
      </div>

      <PopFooter t={t}>
        <div style={{display:'flex', gap: 2, alignItems:'center'}}>
          <EnginePill t={t} active={true}  label="Dict" />
          <EnginePill t={t} active={false} label="DeepL" />
          <EnginePill t={t} active={false} label="GPT" />
        </div>
        <div style={{display:'flex', gap: 6}}>
          <PopBtn t={t}><Icon name="copy" size={11} /> 复制</PopBtn>
          <PopBtn t={t} primary><Icon name="plus" size={11} /> 生词本</PopBtn>
        </div>
      </PopFooter>
    </PopShell>
  );
}

// ───────────── state: SENTENCE ─────────────

function SentencePop({ theme }) {
  const t = TOKENS[theme];
  return (
    <PopShell t={t} theme={theme}>
      <PopHeader t={t} label="Lexi · 整句" right={
        <span style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.04em'}}>EN → ZH</span>
      } />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{fontFamily: SERIF, fontSize: 14, color: t.ink2, lineHeight: 1.6, fontStyle:'italic'}}>
          "Whenever you feel like criticizing any one, just remember that all the people in this world haven't had the advantages that you've had."
        </div>
        <div style={{
          height: 1, background: t.rule, margin: '14px 0',
        }} />
        <div style={{fontFamily: ZH, fontSize: 14.5, color: t.ink, lineHeight: 1.78, letterSpacing:'.01em'}}>
          每当你想批评别人的时候，记住，这世上并不是所有人，都拥有过你所拥有的那些条件。
        </div>
      </div>
      <PopFooter t={t}>
        <div style={{display:'flex', gap: 2, alignItems:'center'}}>
          <EnginePill t={t} active={false} label="DeepL" />
          <EnginePill t={t} active={true}  label="GPT-4" />
          <EnginePill t={t} active={false} label="Google" />
        </div>
        <div style={{display:'flex', gap: 6}}>
          <PopBtn t={t}><Icon name="speaker" size={11} /></PopBtn>
          <PopBtn t={t}><Icon name="copy" size={11} /> 复制</PopBtn>
        </div>
      </PopFooter>
    </PopShell>
  );
}

// ───────────── state: LOADING ─────────────

function LoadingPop({ theme }) {
  const t = TOKENS[theme];
  return (
    <PopShell t={t} theme={theme}>
      <PopHeader t={t} label="Lexi · 翻译中" right={
        <span style={{display:'inline-flex', alignItems:'center', gap: 5, color: t.accent, fontFamily: SANS, fontSize: 10.5, letterSpacing:'.04em', textTransform:'none'}}>
          <span style={{display:'inline-block', width: 10, height: 10, animation:'lexiSpin 1.2s linear infinite'}}>
            <Icon name="spinner" size={10} color={t.accent} />
          </span>
          GPT-4
        </span>
      } />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{fontFamily: SERIF, fontSize: 14, color: t.ink2, lineHeight: 1.6, fontStyle:'italic'}}>
          "He didn't say any more, but we've always been unusually communicative in a reserved way…"
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
      <PopFooter t={t}>
        <span style={{fontFamily: SANS, fontSize: 11, color: t.ink3}}>预计 0.8 秒</span>
        <PopBtn t={t} dim>取消</PopBtn>
      </PopFooter>
    </PopShell>
  );
}

// ───────────── state: ERROR ─────────────

function ErrorPop({ theme }) {
  const t = TOKENS[theme];
  return (
    <PopShell t={t} theme={theme}>
      <PopHeader t={t} label="Lexi" right={
        <span style={{display:'inline-flex', alignItems:'center', gap: 5, color: t.warn, fontFamily: SANS, fontSize: 10.5, textTransform:'none', letterSpacing:'.02em'}}>
          <Icon name="warn" size={11} color={t.warn} /> 翻译失败
        </span>
      } />
      <div style={{padding:'18px 16px 8px'}}>
        <div style={{fontFamily: SANS, fontSize: 13.5, color: t.ink, lineHeight: 1.55, fontWeight: 500}}>
          连接 OpenAI 超时
        </div>
        <div style={{height: 4}} />
        <div style={{fontFamily: ZH, fontSize: 12.5, color: t.ink2, lineHeight: 1.65}}>
          请求 8 秒未响应。检查网络，或在设置中切换到 DeepL / 本地词典作为后备。
        </div>

        <div style={{
          marginTop: 12, padding:'8px 10px', borderRadius: 5,
          background: t.bgInset, border: `1px solid ${t.rule}`,
          fontFamily: MONO, fontSize: 10.5, color: t.ink3, letterSpacing:'.02em',
        }}>
          ETIMEDOUT · api.openai.com:443
        </div>
      </div>
      <PopFooter t={t}>
        <button style={{
          background:'transparent', border:'none', color: t.ink3,
          fontFamily: SANS, fontSize: 11.5, cursor:'pointer', padding: 0,
        }}>去设置 →</button>
        <div style={{display:'flex', gap: 6}}>
          <PopBtn t={t}>关闭</PopBtn>
          <PopBtn t={t} primary>重试</PopBtn>
        </div>
      </PopFooter>
    </PopShell>
  );
}

// ───────────────────── comparison: paragraph translation styles ─────────────────────

function ParaStyle({ t, style, label, desc }) {
  // style: 'demote' | 'rule' | 'tint'
  const wrap = {
    margin: 0,
    paddingLeft: style === 'rule'  ? 12 : 0,
    borderLeft: style === 'rule'   ? `1.5px solid ${t.rule2}` : 'none',
    background:  style === 'tint'  ? t.bgInset : 'transparent',
    borderRadius: style === 'tint' ? 4 : 0,
    padding:      style === 'tint' ? '8px 12px' : (style === 'rule' ? '0 0 0 12px' : 0),
  };
  return (
    <div style={{flex: 1, minWidth: 0}}>
      <div style={{fontFamily: MONO, fontSize: 10, color: t.ink3, letterSpacing:'.08em', textTransform:'uppercase', marginBottom: 4, fontWeight: 600}}>{label}</div>
      <div style={{fontFamily: SANS, fontSize: 11.5, color: t.ink3, marginBottom: 16, lineHeight: 1.5}}>{desc}</div>

      <div style={{marginBottom: 24}}>
        <p style={{margin: 0, fontFamily: SERIF, fontSize: 16, lineHeight: 1.72, color: t.ink, letterSpacing:'-.003em'}}>
          He didn't say any more, but we've always been unusually communicative in a reserved way.
        </p>
        <div style={{height: 6}} />
        <div style={wrap}>
          <p style={{margin: 0, fontFamily: ZH, fontSize: 13, lineHeight: 1.78, color: t.ink2, letterSpacing:'.01em'}}>
            他没再多说什么，但我们父子之间向来不必多言便能心领神会。
          </p>
        </div>
      </div>

      <div>
        <p style={{margin: 0, fontFamily: SERIF, fontSize: 16, lineHeight: 1.72, color: t.ink, letterSpacing:'-.003em'}}>
          In consequence, I'm inclined to reserve all judgments.
        </p>
        <div style={{height: 6}} />
        <div style={wrap}>
          <p style={{margin: 0, fontFamily: ZH, fontSize: 13, lineHeight: 1.78, color: t.ink2, letterSpacing:'.01em'}}>
            因此，我习惯了对一切都不轻易下判断。
          </p>
        </div>
      </div>
    </div>
  );
}

function ParaStyleCompare({ theme }) {
  const t = TOKENS[theme];
  return (
    <div style={{
      background: t.bg, color: t.ink, padding:'36px 40px',
      border: `1px solid ${t.rule}`, borderRadius: 8,
      width: '100%', height: '100%', boxSizing:'border-box',
      display:'flex', gap: 40,
    }}>
      <ParaStyle t={t} style="demote" label="A · TYPOGRAPHY"  desc="只靠字号 + 色阶降级。最克制，最不打扰阅读。" />
      <div style={{width: 1, background: t.rule}} />
      <ParaStyle t={t} style="rule"   label="B · HAIR-LINE"   desc="左侧 1.5px 浅色竖线作为锚点。译文像注释边栏。" />
      <div style={{width: 1, background: t.rule}} />
      <ParaStyle t={t} style="tint"   label="C · SUBTLE TINT" desc="极淡背景块。最易扫描，但视觉密度最高。" />
    </div>
  );
}

Object.assign(window, { WordPop, SentencePop, LoadingPop, ErrorPop, ParaStyleCompare });
