// menubar-popup-v2.jsx — Standalone-mode popup, two design directions.
//
// A · MINIMAL  — Apple Books-lookup feel. 320 wide. Just the answer.
// B · POWER    — Linear / Raycast feel. 420 wide. History + pin + actions.

const SERIF_ENT = '"New York", "Charter", "Iowan Old Style", Georgia, serif';
const SANS_ENT  = '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif';
const ZH_ENT    = '"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", system-ui, sans-serif';
const MONO_ENT  = '"SF Mono", ui-monospace, Menlo, monospace';

function popTokens(dark, accent) {
  return {
    bg:        dark ? '#23201a' : '#fbf8f1',
    bgInset:   dark ? '#1c1914' : '#f1ede0',
    chrome:    dark ? '#1f1c17' : '#f3efe4',
    ink:       dark ? '#ebe3d0' : '#1f1b15',
    ink2:      dark ? '#8e8472' : '#7a7163',
    ink3:      dark ? '#6a6353' : '#a59c89',
    ink4:      dark ? '#3f3a30' : '#c8bfac',
    rule:      dark ? '#2b271f' : '#e3dccb',
    rule2:     dark ? '#3a342a' : '#cfc6b1',
    accent,
    accentSoft: hex2rgba(accent, dark ? .14 : .10),
    sel:        hex2rgba(accent, dark ? .22 : .18),
    shimmer1:  dark ? 'rgba(255,240,210,0.04)' : 'rgba(167,158,140,0.10)',
    shimmer2:  dark ? 'rgba(255,240,210,0.10)' : 'rgba(167,158,140,0.22)',
    warn:      dark ? '#d68a5a' : '#a85a2a',
    danger:    dark ? '#c87060' : '#9c4a39',
  };
}
function hex2rgba(hex, a) {
  const h = hex.replace('#','');
  const r = parseInt(h.slice(0,2),16), g = parseInt(h.slice(2,4),16), b = parseInt(h.slice(4,6),16);
  return `rgba(${r},${g},${b},${a})`;
}

// ── shared chrome ─────────────────────────────────────────────────────────

function PopFrame({ dark, x, y, w, popRef, pinned, children, anim = true }) {
  const W = w, margin = 16;
  const vw = window.innerWidth, vh = window.innerHeight;
  let left = x - W / 2;
  if (left < margin) left = margin;
  if (left + W > vw - margin) left = vw - W - margin;
  let top = y;
  if (top + 460 > vh - margin) top = Math.max(margin, y - 460 - 16);
  return (
    <div ref={popRef} style={{
      position:'fixed', left, top, width: W, zIndex: 200,
      background: dark ? '#23201a' : '#fbf8f1',
      color: dark ? '#ebe3d0' : '#1f1b15',
      borderRadius: 12, overflow:'hidden',
      boxShadow: dark
        ? '0 30px 70px rgba(0,0,0,.65), 0 0 0 1px rgba(0,0,0,.6), inset 0 .5px 0 rgba(255,255,255,.05)'
        : '0 24px 60px rgba(40,28,14,.30), 0 0 0 1px rgba(0,0,0,.10), inset 0 .5px 0 rgba(255,255,255,.7)',
      fontFeatureSettings:'"kern","liga","calt"',
      animation: anim ? 'lexiPopIn .14s ease-out' : 'none',
    }}>
      {pinned && (
        <div style={{
          position:'absolute', top: 8, right: 8, width: 6, height: 6, borderRadius:'50%',
          background: dark ? '#d68a5a' : '#b35c2c',
          boxShadow:'0 0 0 2px ' + (dark ? '#23201a' : '#fbf8f1'),
        }} />
      )}
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
      fontFamily: SANS_ENT, fontSize: 11, color: t.ink3,
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
      padding:'8px 12px', borderTop: `1px solid ${t.rule}`,
      display:'flex', alignItems:'center', justifyContent:'space-between',
      background: t.chrome, gap: 8,
    }}>{children}</div>
  );
}

function Btn({ children, t, primary, dim, onClick, title }) {
  return (
    <button onClick={onClick} title={title} style={{
      background: primary ? t.accent : 'transparent',
      color: primary ? '#fff' : (dim ? t.ink3 : t.ink2),
      border: primary ? 'none' : `1px solid ${t.rule2}`,
      borderRadius: 5, padding:'3px 10px', fontSize: 11.5, fontFamily: SANS_ENT,
      cursor:'pointer', display:'inline-flex', alignItems:'center', gap: 5,
      letterSpacing:'.01em', height: 22, fontWeight: 500,
    }}>{children}</button>
  );
}

function EnginePill({ t, active, label, onClick }) {
  return (
    <span onClick={onClick} style={{
      padding:'2px 8px', borderRadius: 4,
      background: active ? t.accentSoft : 'transparent',
      color: active ? t.accent : t.ink3,
      fontFamily: SANS_ENT, fontSize: 10.5, fontWeight: active ? 600 : 500,
      letterSpacing:'.02em', cursor:'pointer',
    }}>{label}</span>
  );
}

function MiniIcon({ name, size = 13, color = 'currentColor' }) {
  const s = { width: size, height: size, fill:'none', stroke: color, strokeWidth: 1.4, strokeLinecap:'round', strokeLinejoin:'round' };
  switch (name) {
    case 'speaker':
      return <svg {...s} viewBox="0 0 16 16"><path d="M3 6h2l3-2.5v9L5 10H3z"/><path d="M10.5 6c.8.5 1.2 1.2 1.2 2s-.4 1.5-1.2 2"/></svg>;
    case 'copy':
      return <svg {...s} viewBox="0 0 16 16"><rect x="5" y="5" width="8" height="8" rx="1.5"/><path d="M3 11V4a1 1 0 0 1 1-1h7"/></svg>;
    case 'plus':
      return <svg {...s} viewBox="0 0 16 16"><line x1="8" y1="3.5" x2="8" y2="12.5"/><line x1="3.5" y1="8" x2="12.5" y2="8"/></svg>;
    case 'pin':
      return <svg {...s} viewBox="0 0 16 16"><path d="M9.5 2.5 13.5 6.5l-2 2-1 1.4-2.6-2.6-3 3-1 .3.3-1 3-3L4.6 3.9l1.4-1L7.5 2.5z"/></svg>;
    case 'send':
      return <svg {...s} viewBox="0 0 16 16"><path d="M13.5 8H4.5M9 4.5 13.5 8 9 11.5"/></svg>;
    case 'warn':
      return <svg {...s} viewBox="0 0 16 16"><path d="M8 2 14 13H2Z"/><line x1="8" y1="6.5" x2="8" y2="9.5"/><circle cx="8" cy="11.2" r=".4" fill={color} stroke="none"/></svg>;
    case 'spinner':
      return <svg {...s} viewBox="0 0 16 16"><circle cx="8" cy="8" r="5.5" strokeOpacity=".25"/><path d="M13.5 8a5.5 5.5 0 0 0-5.5-5.5"/></svg>;
    case 'x':
      return <svg {...s} viewBox="0 0 16 16"><line x1="4" y1="4" x2="12" y2="12"/><line x1="12" y1="4" x2="4" y2="12"/></svg>;
    default: return null;
  }
}

// ── A · MINIMAL — word card ───────────────────────────────────────────────

function WordA({ ctx, word, entry, engine, onEngine, onAdd, onClose, popRef, pinned, onPin }) {
  const t = ctx.t;
  return (
    <PopFrame dark={ctx.dark} x={ctx.x} y={ctx.y} w={320} popRef={popRef} pinned={pinned}>
      <PopHeader t={t} label="Lexi · 单词"
        right={<HeaderActions t={t} onPin={onPin} pinned={pinned} onClose={onClose} />} />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{display:'flex', alignItems:'baseline', gap: 10, flexWrap:'wrap'}}>
          <span style={{fontFamily: SERIF_ENT, fontSize: 24, color: t.ink, letterSpacing:'-.01em', fontWeight: 500}}>{word}</span>
          <span style={{fontFamily: MONO_ENT, fontSize: 12, color: t.ink3, letterSpacing:'.02em'}}>{entry.ipa}</span>
          <button style={{border:'none', background:'transparent', color: t.ink3, padding: 2, cursor:'pointer', display:'flex'}}>
            <MiniIcon name="speaker" size={13} />
          </button>
        </div>
        <div style={{height: 10}} />
        <div style={{display:'flex', flexDirection:'column', gap: 8}}>
          {entry.senses.slice(0, 2).map((s, i) => (
            <div key={i}>
              <div style={{display:'flex', gap: 8, alignItems:'baseline'}}>
                <span style={{
                  fontFamily: SERIF_ENT, fontStyle:'italic',
                  fontSize: 11.5, color: t.accent, lineHeight: 1.5, minWidth: 28,
                }}>{s.pos}</span>
                <div style={{flex: 1, minWidth: 0}}>
                  <div style={{fontFamily: SERIF_ENT, fontSize: 13, color: t.ink, lineHeight: 1.5}}>{s.en}</div>
                  <div style={{fontFamily: ZH_ENT, fontSize: 12, color: t.ink2, lineHeight: 1.6, marginTop: 1}}>{s.zh}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
        <div style={{height: 12}} />
      </div>
      <PopFooter t={t}>
        <div style={{display:'flex', gap: 2}}>
          {['Dict','DeepL','GPT'].map((e) => (
            <EnginePill key={e} t={t} active={engine === e} label={e} onClick={() => onEngine(e)} />
          ))}
        </div>
        <Btn t={t} primary onClick={onAdd}><MiniIcon name="plus" size={11} /> 生词本</Btn>
      </PopFooter>
    </PopFrame>
  );
}

// ── A · MINIMAL — sentence card ───────────────────────────────────────────

function SentenceA({ ctx, text, zh, engine, onEngine, onClose, popRef, pinned, onPin }) {
  const t = ctx.t;
  return (
    <PopFrame dark={ctx.dark} x={ctx.x} y={ctx.y} w={340} popRef={popRef} pinned={pinned}>
      <PopHeader t={t} label="Lexi · 整句"
        right={<HeaderActions t={t} onPin={onPin} pinned={pinned} onClose={onClose} />} />
      <div style={{padding:'14px 16px 4px'}}>
        <div style={{fontFamily: SERIF_ENT, fontSize: 13.5, color: t.ink2, lineHeight: 1.55, fontStyle:'italic'}}>
          "{text}"
        </div>
        <div style={{height: 1, background: t.rule, margin: '14px 0'}} />
        <div style={{fontFamily: ZH_ENT, fontSize: 14, color: t.ink, lineHeight: 1.75, letterSpacing:'.01em'}}>
          {zh}
        </div>
      </div>
      <PopFooter t={t}>
        <div style={{display:'flex', gap: 2}}>
          {['DeepL','GPT-4','Google'].map((e) => (
            <EnginePill key={e} t={t} active={engine === e} label={e} onClick={() => onEngine(e)} />
          ))}
        </div>
        <Btn t={t}><MiniIcon name="copy" size={11} /> 复制</Btn>
      </PopFooter>
    </PopFrame>
  );
}

// ── B · POWER — word card ─────────────────────────────────────────────────

function WordB({ ctx, word, entry, history, engine, onEngine, onAdd, onSend, onClose, onHistoryPick, popRef, pinned, onPin }) {
  const t = ctx.t;
  const w = (window.innerWidth < 800) ? 380 : 420;
  return (
    <PopFrame dark={ctx.dark} x={ctx.x} y={ctx.y} w={w} popRef={popRef} pinned={pinned}>
      {history && history.length > 0 && (
        <div style={{
          padding:'8px 12px 8px', display:'flex', gap: 6, alignItems:'center',
          borderBottom: `1px solid ${t.rule}`,
          background: t.chrome,
          fontFamily: SANS_ENT, fontSize: 11, color: t.ink3,
        }}>
          <span style={{
            fontSize: 9.5, letterSpacing:'.10em', textTransform:'uppercase', fontWeight: 600,
            color: t.ink3, marginRight: 2,
          }}>近期</span>
          {history.slice(0, 5).map((h, i) => (
            <span key={i} onClick={() => onHistoryPick(h)} style={{
              padding:'2px 8px', borderRadius: 999,
              background: t.bgInset, border: `1px solid ${t.rule}`,
              color: t.ink2, cursor:'pointer', fontSize: 11,
              transition:'background .12s',
            }}
              onMouseEnter={(e) => { e.currentTarget.style.background = t.accentSoft; e.currentTarget.style.color = t.accent; }}
              onMouseLeave={(e) => { e.currentTarget.style.background = t.bgInset; e.currentTarget.style.color = t.ink2; }}
            >{h}</span>
          ))}
        </div>
      )}

      <PopHeader t={t} label="Lexi · 单词卡"
        right={<HeaderActions t={t} onPin={onPin} pinned={pinned} onClose={onClose} />} />

      <div style={{padding:'16px 18px 2px'}}>
        <div style={{display:'flex', alignItems:'baseline', gap: 10, flexWrap:'wrap'}}>
          <span style={{fontFamily: SERIF_ENT, fontSize: 30, color: t.ink, letterSpacing:'-.012em', fontWeight: 500}}>{word}</span>
          <div style={{display:'inline-flex', alignItems:'baseline', gap: 4}}>
            <span style={{fontFamily: MONO_ENT, fontSize: 11.5, color: t.ink3, letterSpacing:'.02em'}}>UK</span>
            <span style={{fontFamily: MONO_ENT, fontSize: 12.5, color: t.ink2, letterSpacing:'.02em'}}>{entry.ipa}</span>
            <button style={{border:'none', background:'transparent', color: t.ink3, padding: 2, cursor:'pointer', display:'inline-flex'}}>
              <MiniIcon name="speaker" size={13} />
            </button>
          </div>
          <div style={{display:'inline-flex', alignItems:'baseline', gap: 4}}>
            <span style={{fontFamily: MONO_ENT, fontSize: 11.5, color: t.ink3, letterSpacing:'.02em'}}>US</span>
            <span style={{fontFamily: MONO_ENT, fontSize: 12.5, color: t.ink2, letterSpacing:'.02em'}}>{entry.ipa.replace('ɒ','ɑː').replace('ə','ər')}</span>
            <button style={{border:'none', background:'transparent', color: t.ink3, padding: 2, cursor:'pointer', display:'inline-flex'}}>
              <MiniIcon name="speaker" size={13} />
            </button>
          </div>
        </div>

        <div style={{height: 14}} />

        <div style={{display:'flex', flexDirection:'column', gap: 12}}>
          {entry.senses.map((s, i) => (
            <div key={i} style={{display:'flex', gap: 12, alignItems:'flex-start'}}>
              <span style={{
                flex:'0 0 36px', fontFamily: SERIF_ENT, fontStyle:'italic',
                fontSize: 12.5, color: t.accent, lineHeight: 1.5, paddingTop: 1,
              }}>{s.pos}</span>
              <div style={{flex: 1, minWidth: 0}}>
                <div style={{fontFamily: SERIF_ENT, fontSize: 14, color: t.ink, lineHeight: 1.5}}>{s.en}</div>
                <div style={{fontFamily: ZH_ENT, fontSize: 13, color: t.ink2, lineHeight: 1.6, marginTop: 2}}>{s.zh}</div>
                {i === 0 && entry.example && (
                  <div style={{
                    marginTop: 6, padding:'6px 10px', borderRadius: 5,
                    background: t.bgInset, border: `1px solid ${t.rule}`,
                    fontFamily: SERIF_ENT, fontStyle:'italic', fontSize: 12,
                    color: t.ink2, lineHeight: 1.55,
                  }}>
                    "{entry.example.en}"
                    <div style={{
                      fontFamily: ZH_ENT, fontStyle:'normal', fontSize: 11.5,
                      color: t.ink3, marginTop: 4,
                    }}>{entry.example.zh}</div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>

        {entry.related && (
          <div style={{marginTop: 14, display:'flex', alignItems:'baseline', gap: 8, flexWrap:'wrap'}}>
            <span style={{
              fontFamily: SANS_ENT, fontSize: 10, color: t.ink3,
              textTransform:'uppercase', letterSpacing:'.10em', fontWeight: 600,
            }}>相关</span>
            {entry.related.map((r, i) => (
              <span key={i} style={{
                fontFamily: SERIF_ENT, fontSize: 12, fontStyle:'italic',
                color: t.ink2, cursor:'pointer',
                borderBottom: `1px dotted ${t.rule2}`, paddingBottom: 1,
              }}>{r}</span>
            ))}
          </div>
        )}

        <div style={{height: 14}} />
      </div>

      <PopFooter t={t}>
        <div style={{display:'flex', gap: 2}}>
          {['Dict','DeepL','GPT','Claude'].map((e) => (
            <EnginePill key={e} t={t} active={engine === e} label={e} onClick={() => onEngine(e)} />
          ))}
        </div>
        <div style={{display:'flex', gap: 6}}>
          <Btn t={t} onClick={onSend} title="发送到 Lexi 阅读器"><MiniIcon name="send" size={11} /></Btn>
          <Btn t={t} primary onClick={onAdd}><MiniIcon name="plus" size={11} /> 生词本</Btn>
        </div>
      </PopFooter>
    </PopFrame>
  );
}

// ── B · POWER — sentence card ─────────────────────────────────────────────

function SentenceB({ ctx, text, zh, alt, engine, onEngine, onSend, onClose, popRef, pinned, onPin }) {
  const t = ctx.t;
  const w = (window.innerWidth < 800) ? 380 : 420;
  return (
    <PopFrame dark={ctx.dark} x={ctx.x} y={ctx.y} w={w} popRef={popRef} pinned={pinned}>
      <PopHeader t={t} label="Lexi · 整句"
        right={<HeaderActions t={t} onPin={onPin} pinned={pinned} onClose={onClose} />} />
      <div style={{padding:'16px 18px 4px'}}>
        <div style={{fontFamily: SERIF_ENT, fontSize: 14, color: t.ink2, lineHeight: 1.6, fontStyle:'italic'}}>
          "{text}"
        </div>
        <div style={{height: 1, background: t.rule, margin: '14px 0'}} />
        <div style={{fontFamily: ZH_ENT, fontSize: 14.5, color: t.ink, lineHeight: 1.78, letterSpacing:'.01em'}}>
          {zh}
        </div>
        {alt && (
          <div style={{
            marginTop: 14, padding:'10px 12px', borderRadius: 6,
            background: t.bgInset, border: `1px solid ${t.rule}`,
          }}>
            <div style={{fontFamily: SANS_ENT, fontSize: 10, color: t.ink3, letterSpacing:'.08em', textTransform:'uppercase', marginBottom: 4, fontWeight: 600}}>
              备选 · DeepL
            </div>
            <div style={{fontFamily: ZH_ENT, fontSize: 13, color: t.ink2, lineHeight: 1.65}}>{alt}</div>
          </div>
        )}
        <div style={{height: 12}} />
      </div>
      <PopFooter t={t}>
        <div style={{display:'flex', gap: 2}}>
          {['DeepL','GPT-4','Claude','Google'].map((e) => (
            <EnginePill key={e} t={t} active={engine === e} label={e} onClick={() => onEngine(e)} />
          ))}
        </div>
        <div style={{display:'flex', gap: 6}}>
          <Btn t={t}><MiniIcon name="speaker" size={11} /></Btn>
          <Btn t={t} onClick={onSend}><MiniIcon name="send" size={11} /> 发送</Btn>
        </div>
      </PopFooter>
    </PopFrame>
  );
}

// ── Loading / Error (shared between directions) ───────────────────────────

function LoadingPopV2({ ctx, text, engine, popRef, pinned }) {
  const t = ctx.t;
  return (
    <PopFrame dark={ctx.dark} x={ctx.x} y={ctx.y} w={340} popRef={popRef} pinned={pinned}>
      <PopHeader t={t} label="Lexi · 翻译中" right={
        <span style={{display:'inline-flex', alignItems:'center', gap: 5, color: t.accent, fontSize: 10.5, textTransform:'none'}}>
          <span style={{display:'inline-block', width: 10, height: 10, animation:'lexiSpin 1.2s linear infinite'}}>
            <MiniIcon name="spinner" size={10} color={t.accent} />
          </span>
          {engine}
        </span>
      } />
      <div style={{padding:'14px 16px 8px'}}>
        <div style={{fontFamily: SERIF_ENT, fontSize: 13.5, color: t.ink2, lineHeight: 1.55, fontStyle:'italic',
          maxHeight: 60, overflow:'hidden'}}>
          "{text}"
        </div>
        <div style={{height: 1, background: t.rule, margin: '14px 0'}} />
        <div style={{display:'flex', flexDirection:'column', gap: 8}}>
          {[100, 90, 60].map((w, i) => (
            <div key={i} style={{
              height: 11, width: `${w}%`, borderRadius: 3,
              background: `linear-gradient(90deg, ${t.shimmer1}, ${t.shimmer2}, ${t.shimmer1})`,
              backgroundSize: '200% 100%',
              animation: `lexiShimmer 1.6s linear infinite`,
              animationDelay: `${i * 0.12}s`,
            }} />
          ))}
        </div>
        <div style={{height: 6}} />
      </div>
    </PopFrame>
  );
}

function ErrorPopV2({ ctx, popRef, onRetry, onClose, onSettings }) {
  const t = ctx.t;
  return (
    <PopFrame dark={ctx.dark} x={ctx.x} y={ctx.y} w={360} popRef={popRef}>
      <PopHeader t={t} label="Lexi" right={
        <span style={{display:'inline-flex', alignItems:'center', gap: 5, color: t.warn, fontSize: 10.5, textTransform:'none'}}>
          <MiniIcon name="warn" size={11} color={t.warn} /> 翻译失败
        </span>
      } />
      <div style={{padding:'18px 16px 8px'}}>
        <div style={{fontFamily: SANS_ENT, fontSize: 13.5, color: t.ink, fontWeight: 500}}>连接 OpenAI 超时</div>
        <div style={{height: 4}} />
        <div style={{fontFamily: ZH_ENT, fontSize: 12.5, color: t.ink2, lineHeight: 1.65}}>
          请求 8 秒未响应。检查网络，或切换到 DeepL / 本地词典 / Llama 3 作为后备。
        </div>
        <div style={{marginTop: 12, padding:'8px 10px', borderRadius: 5,
          background: t.bgInset, border: `1px solid ${t.rule}`,
          fontFamily: MONO_ENT, fontSize: 10.5, color: t.ink3, letterSpacing:'.02em'}}>
          ETIMEDOUT · api.openai.com:443
        </div>
      </div>
      <PopFooter t={t}>
        <button onClick={onSettings} style={{background:'transparent', border:'none', color: t.ink3,
          fontFamily: SANS_ENT, fontSize: 11.5, cursor:'pointer', padding: 0}}>去设置 →</button>
        <div style={{display:'flex', gap: 6}}>
          <Btn t={t} onClick={onClose}>关闭</Btn>
          <Btn t={t} primary onClick={onRetry}>重试</Btn>
        </div>
      </PopFooter>
    </PopFrame>
  );
}

// header actions (pin + close)
function HeaderActions({ t, onPin, pinned, onClose }) {
  return (
    <span style={{display:'inline-flex', alignItems:'center', gap: 2}}>
      <button onClick={onPin} title={pinned ? '取消固定' : '固定'} style={{
        width: 18, height: 18, padding: 0, borderRadius: 3, border:'none', cursor:'pointer',
        background: pinned ? t.accentSoft : 'transparent', color: pinned ? t.accent : t.ink3,
        display:'inline-flex', alignItems:'center', justifyContent:'center',
      }}><MiniIcon name="pin" size={10} /></button>
      <button onClick={onClose} title="关闭 (Esc)" style={{
        width: 18, height: 18, padding: 0, borderRadius: 3, border:'none', cursor:'pointer',
        background:'transparent', color: t.ink3,
        display:'inline-flex', alignItems:'center', justifyContent:'center',
      }}><MiniIcon name="x" size={10} /></button>
    </span>
  );
}

// ── Trigger chip (PopClip-style) ──────────────────────────────────────────

function TriggerChip({ x, y, dark, accent, onClick }) {
  return (
    <div onClick={onClick} style={{
      position:'fixed', left: x - 16, top: y - 30, zIndex: 150,
      width: 32, height: 22, borderRadius: 6,
      background: dark ? '#23201a' : '#fbf8f1',
      color: accent,
      border: `1px solid ${dark ? 'rgba(0,0,0,.6)' : 'rgba(0,0,0,.10)'}`,
      boxShadow: dark
        ? '0 8px 24px rgba(0,0,0,.55), inset 0 .5px 0 rgba(255,255,255,.05)'
        : '0 8px 24px rgba(40,28,14,.20), inset 0 .5px 0 rgba(255,255,255,.7)',
      cursor:'pointer',
      display:'inline-flex', alignItems:'center', justifyContent:'center', gap: 2,
      fontFamily: SANS_ENT, fontSize: 11, fontWeight: 600,
      animation:'lexiPopIn .12s ease-out', userSelect:'none',
    }}>
      {/* LexiGlyph but smaller */}
      <svg width="12" height="12" viewBox="0 0 16 16">
        <rect x="2" y="5"  width="10" height="2" rx="1" fill={accent} />
        <rect x="2" y="9"  width="7"  height="2" rx="1" fill={accent} opacity=".55" />
        <circle cx="13" cy="6" r="1" fill={accent} />
      </svg>
      <span style={{fontSize: 10, letterSpacing:'.02em'}}>译</span>
    </div>
  );
}

Object.assign(window, {
  WordA, SentenceA, WordB, SentenceB,
  LoadingPopV2, ErrorPopV2, TriggerChip,
  popTokens,
});
