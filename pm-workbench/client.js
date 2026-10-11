window.__ModuleLoader__.load({
  id: '@local/dsh-biocdmo-pm-workbench',
  factory(require) {
    const React = require('react');
    const h = React.createElement;
    // 【功能开关】自研"引用到对话"按钮：better-sidebar / 原生 @ 已覆盖该需求，默认关闭。
    // 恢复方法：改为 true，并同步更新 verify-client.cjs 的对应断言。
    const ENABLE_FILE_REFERENCE = false;
    // 可引用范围 = 当前会话工作区根（来自原生文件树 data-files-root）。
    // 不依赖宿主路由、不硬编码服务器名或用户路径，可移植。
    const roots = [];
    let selected = null;
    let statFile = null;
    let latestInputActions = null;
    let sidebarServices = { better: null, right: null, tabs: null };
    const listeners = new Set();
    function subscribe(listener) { listeners.add(listener); return () => listeners.delete(listener); }
    function select(payload) {
      selected = payload;
      for (const listener of listeners) { try { listener(payload); } catch (e) { } }
    }
    function useSelectedFile() {
      const [file, setFile] = React.useState(selected);
      React.useEffect(() => subscribe(setFile), []);
      return file;
    }
    function projectOf(path) { const match = String(path).match(/(IP\d{3,})/i); return match ? match[1].toUpperCase() : null; }
    function referenceText(file) {
      const abs = String(file.absolutePath || '');
      const isDir = file.kind === 'directory';
      const hasSpaces = /\s/.test(abs);
      const normalized = abs.replace(/\\/g, '/');
      const slash = isDir && !normalized.endsWith('/') ? '/' : '';
      const versioned = file.version ? `（版本 ${file.version}）` : '';
      return (hasSpaces ? `@"${normalized}${slash}"${versioned}` : `@${normalized}${slash}${versioned}`) + '\n';
    }
    function addReference(absolutePath, inputActions, sessionId, kind, version) {
      const file = { absolutePath, kind: kind || 'file', version };
      const text = referenceText(file);
      if (inputActions.insertText(text, inputActions.captureInsertion ? inputActions.captureInsertion() : undefined)) {
        select(Object.assign({}, file, { sessionId, inserted: true }));
      }
    }
    function AddFileReference({ absolutePath, inputActions, sessionId }) {
      if (!allowed(absolutePath)) return null;
      return h('button', { className: 'pmfr-add', type: 'button', title: '将此精确文件路径加入当前对话', onClick: () => addReference(absolutePath, inputActions, sessionId) }, '引用到对话');
    }
    function FileChip({ inputActions, sessionId }) {
      const file = useSelectedFile();
      if (!file || !file.inserted || file.sessionId !== sessionId) return null;
      return h('div', { className: 'pmfr-chip', title: file.absolutePath },
        h('span', { className: 'pmfr-icon', 'aria-hidden': true }, '▣'),
        h('span', { className: 'pmfr-label' }, file.name),
        h('span', { className: 'pmfr-note' }, file.kind === 'directory' ? '文件夹范围 · 已加入输入框' : '文件 · 已加入输入框'),
        h('button', { type: 'button', title: '关闭提示（不删除输入框中的引用文字）', onClick: () => select(null) }, '×'));
    }
    function FileTreeRowActions({ sessionId, treeRoot, inputActions }) {
      React.useEffect(() => {
        if (!allowed(treeRoot)) return;
        const owned = new Set();
        let observer;
        let queued = false;
        let disposed = false;
        function install() {
          if (disposed) return;
          for (const tree of document.querySelectorAll('[data-files-root]')) {
            const rootAttr = tree.getAttribute('data-files-root');
            if (!rootAttr || !allowed(rootAttr)) continue;
            for (const row of tree.querySelectorAll('[data-files-entry]')) {
              if (row.querySelector(':scope > .pmfr-row-action')) continue;
              const kind = row.getAttribute('data-files-entry');
              const raw = row.getAttribute('data-files-path');
              if (!raw || !(/^[A-Za-z]:[\\/]|^\\\\/.test(raw))) continue;
              const p = raw.replace(/\//g, '\\');
              if (!allowed(p) || !normalized(p).startsWith(normalized(treeRoot) + '/') || p.split('\\').includes('..')) continue;
              const button = document.createElement('button');
              button.type = 'button';
              button.className = 'pmfr-row-action';
              button.textContent = '🔗';
              button.title = '引用' + (kind === 'directory' ? '文件夹' : '文件') + '到对话：' + basename(p);
              button.setAttribute('aria-label', button.title);
              button.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                if (kind === 'file' && typeof statFile === 'function') {
                  // 文件：先查版本再引用（版本化引用），失败降级为普通引用
                  statFile(sessionId, p).then((res) => {
                    const version = res && res.ok && res.value ? res.value.version : undefined;
                    addReference(p, inputActions, sessionId, kind, version);
                  }).catch(() => addReference(p, inputActions, sessionId, kind));
                } else {
                  addReference(p, inputActions, sessionId, kind);
                }
              });
              row.appendChild(button);
              owned.add(button);
            }
          }
        }
        function schedule() {
          if (queued || disposed) return;
          queued = true;
          requestAnimationFrame(() => { queued = false; install(); });
        }
        observer = new MutationObserver(schedule);
        // 观察 each [data-files-root] 元素（观察字符串路径会抛错）
        for (const tree of document.querySelectorAll('[data-files-root]')) {
          const rootAttr = tree.getAttribute('data-files-root');
          if (!rootAttr || !allowed(rootAttr)) continue;
          observer.observe(tree, { childList: true, subtree: true });
        }
        install();
        return () => {
          disposed = true;
          if (observer) observer.disconnect();
          for (const el of owned) el.remove();
          owned.clear();
        };
      }, [treeRoot, inputActions, sessionId]);
      return null;
    }
    function FilesToolbarAction({ absolutePath, inputActions, sessionId }) {
      if (!allowed(absolutePath)) return null;
      return h(React.Fragment, null, h('style', null, css),
        h(FileTreeRowActions, { sessionId, treeRoot: absolutePath, inputActions }));
    }
    function SkillStrip({ sessionId, inputActions }) {
      const file = useSelectedFile();
      if (!file || !file.inserted || file.sessionId !== sessionId || file.kind !== 'file' || !allowed(file.absolutePath)) return null;
      const project = projectOf(file.absolutePath);
      if (!project) return null;
      if (inputActions) latestInputActions = inputActions;
      const request = `请加密文件 @${file.absolutePath.replace(/\\/g, '/')} ，项目 ${project}。\n执行方式（不要在工作目录或网盘中搜索脚本与密码文件）：\npwsh -File "<preset根目录>\\pm-workbench\\encrypt-office.ps1" -Path "<上面的文件路径>" -Project "${project}"\n<preset根目录> 按 preset 部署约定解析（默认 %USERPROFILE%\\AI\\preset\\PM，部署位置不同以实际为准）。\n密码由脚本内部处理：优先项目目录 .pm-password，其次本机 DPAPI；若提示项目尚未设置密码，请在对话中提醒 PM 输入一次项目密码，由 Agent 写入项目目录隐藏文件 .pm-password 后重试。不要回显密码。完成后只回复生成的 -加密 副本路径。`;
      const go = () => {
        if (!inputActions || typeof inputActions.insertText !== 'function' || typeof inputActions.captureInsertion !== 'function') return;
        if (!inputActions.insertText(request, inputActions.captureInsertion())) return;
        if (typeof inputActions.submit === 'function') inputActions.submit();
      };
      return h('div', { className: 'pmfr-skills' },
        h('button', { type: 'button', className: 'pmfr-skill', title: '用项目固定密码加密此文件（首次会提醒输入密码，之后不再询问）', onClick: go }, '🔒 加密此文件'));
    }
    const css = `.pmfr-row-action{position:absolute;right:7px;top:2px;z-index:1;border:1px solid transparent;border-radius:5px;padding:0 5px;background:transparent;color:var(--dsw-alias-brand-primary,#3174d6);font:12px/1.6 system-ui,sans-serif;cursor:pointer;opacity:.55}.pmfr-row-action:hover{opacity:1;background:var(--dsw-alias-bg-layer-2,#f3f5f8);border-color:var(--dsw-alias-border-l2,#ddd)}[data-files-entry="file"],[data-files-entry="directory"]{position:relative}.pmfr-chip{display:inline-flex;align-items:center;gap:6px;max-width:100%;margin:2px 0;padding:4px 7px;border:1px solid var(--dsw-alias-border-l1);border-radius:7px;background:var(--dsw-alias-bg-layer-1);font:12px/1.25 system-ui,sans-serif;color:var(--dsw-alias-label-primary)}.pmfr-icon{color:var(--dsw-alias-brand-primary)}.pmfr-label{max-width:min(500px,55vw);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.pmfr-note{color:var(--dsw-alias-label-secondary);font-size:10px}.pmfr-chip button{border:0;background:transparent;color:var(--dsw-alias-label-secondary);font-size:16px;line-height:1;cursor:pointer;padding:0 1px}.pmfr-skills{display:flex;gap:6px;margin:2px 0}.pmfr-skill{border:1px solid var(--dsw-alias-border-l2,#ddd);border-radius:7px;padding:3px 9px;background:var(--dsw-alias-bg-layer-1);color:var(--dsw-alias-label-primary);font:12px/1.4 system-ui,sans-serif;cursor:pointer}.pmfr-skill:hover{border-color:var(--dsw-alias-brand-primary);color:var(--dsw-alias-brand-primary)}.pmfr-dock{padding:0 12px 0 8px}.pmfr-minutes-panel{display:flex;flex-direction:column;gap:8px;padding:12px;overflow-y:auto;height:100%;box-sizing:border-box}.pmfr-minutes-head{display:flex;align-items:center;justify-content:space-between}.pmfr-minutes-head .pmfr-minutes-title{font:600 14px/1.4 system-ui,sans-serif;color:var(--dsw-alias-label-primary)}.pmfr-m-refresh{border:1px solid var(--dsw-alias-border-l2,#ddd);border-radius:5px;background:transparent;color:var(--dsw-alias-brand-primary,#3174d6);font:13px/1.4 system-ui,sans-serif;cursor:pointer;padding:2px 8px}.pmfr-m-refresh:hover{background:var(--dsw-alias-bg-layer-2,#f3f5f8)}.pmfr-m-search{width:100%;box-sizing:border-box;margin:6px 0;padding:5px 8px;border:1px solid var(--dsw-alias-border-l2,#ddd);border-radius:6px;font:12px/1.4 system-ui,sans-serif}.pmfr-m-topbar{display:flex;align-items:center;justify-content:space-between;gap:8px}.pmfr-m-brand{font:600 14px/1.4 system-ui,sans-serif;color:var(--dsw-alias-label-primary)}.pmfr-m-topbtns{display:flex;gap:6px}.pmfr-m-cachebar{font:11px/1.5 system-ui,sans-serif;color:var(--dsw-alias-label-secondary);padding:4px 8px;border-radius:6px;background:var(--dsw-alias-bg-layer-2,#f6f8fa)}.pmfr-m-group{display:flex;flex-direction:column;gap:6px}.pmfr-m-groupname{font:600 11px/1.4 system-ui,sans-serif;color:var(--dsw-alias-label-tertiary,#8a8f98);margin:6px 0 2px;letter-spacing:.03em}.pmfr-m-titlerow{display:flex;align-items:flex-start;justify-content:space-between;gap:6px}.pmfr-m-titletags{display:flex;align-items:center;gap:4px;flex:0 0 auto}.pmfr-m-tag{font:10px/1.6 system-ui,sans-serif;padding:0 6px;border-radius:8px;background:var(--dsw-alias-bg-layer-2,#eef2f6);color:var(--dsw-alias-label-secondary);white-space:nowrap}.pmfr-m-tag.ok{background:#e6f7ea;color:#1d7a3a;border:1px solid #b7e2c2}.pmfr-m-tag.other{background:#fff6e5;color:#96601a;border:1px solid #f0d8a8}.pmfr-m-chev{border:0;background:transparent;color:var(--dsw-alias-label-secondary);font:12px/1 system-ui,sans-serif;cursor:pointer;padding:2px 4px}.pmfr-m-menu{display:flex;flex-direction:column;gap:4px;margin-top:6px;padding:6px 8px;border:1px dashed var(--dsw-alias-border-l2,#ddd);border-radius:6px;background:var(--dsw-alias-bg-layer-2,#fafbfc)}.pmfr-m-file{text-align:left;font:12px/1.6 system-ui,sans-serif;padding:3px 6px;border-radius:5px}.pmfr-m-file:hover{background:var(--dsw-alias-bg-layer-3,#eef2f6)}.pmfr-browser{display:flex;flex-direction:column;gap:6px;padding:8px;height:100%;overflow:auto}.pmfr-browser-head{display:flex;align-items:center;gap:6px}.pmfr-browser-path{font:12px/1.5 system-ui,sans-serif;color:var(--dsw-alias-label-secondary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.pmfr-browser-list{display:flex;flex-direction:column;gap:2px}.pmfr-browser-row{display:flex;align-items:center;gap:4px}.pmfr-browser-name{flex:1;text-align:left;border:0;background:transparent;font:13px/1.9 system-ui,sans-serif;padding:2px 6px;border-radius:5px;cursor:pointer;color:var(--dsw-alias-label-primary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.pmfr-browser-name:hover{background:var(--dsw-alias-bg-layer-2,#eef2f6)}.pmfr-browser-row.dir .pmfr-browser-name{font-weight:600}.pmfr-browser-go{border:0;background:transparent;color:var(--dsw-alias-label-secondary);cursor:pointer;font:13px/1 system-ui,sans-serif}.pmfr-m-metarow{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:2px}.pmfr-m-metarow .pmfr-mi-btn{padding:1px 6px;font-size:11px;line-height:1.5;opacity:.92}.pmfr-m-metarow .pmfr-mi-btn:hover{opacity:1}.pmfr-m-iconrow{display:flex;gap:4px;margin-top:6px;flex-wrap:wrap}.pmfr-mi-btn{border:1px solid var(--dsw-alias-border-l2,#ddd);border-radius:6px;background:var(--dsw-alias-bg-layer-1);font:13px/1 system-ui,sans-serif;padding:4px 7px;cursor:pointer}.pmfr-mi-btn:hover{border-color:var(--dsw-alias-brand-primary,#3174d6);background:var(--dsw-alias-bg-layer-2,#f3f5f8)}.pmfr-m-list{display:flex;flex-direction:column;gap:6px}.pmfr-m-item{border:1px solid var(--dsw-alias-border-l2,#ddd);border-radius:8px;padding:8px;background:var(--dsw-alias-bg-layer-1)}.pmfr-m-item.open{border-color:var(--dsw-alias-brand-primary,#3174d6)}.pmfr-m-row{cursor:pointer}.pmfr-m-title{font:600 12px/1.4 system-ui,sans-serif;color:var(--dsw-alias-label-primary)}.pmfr-m-meta{font:11px/1.4 system-ui,sans-serif;color:var(--dsw-alias-label-secondary);margin-top:2px}.pmfr-m-actions{display:flex;gap:6px;margin-top:6px}.pmfr-m-dlmsg{font:11px/1.5 system-ui,sans-serif;color:var(--dsw-alias-label-secondary);margin-top:6px;word-break:break-all}.pmfr-m-dlmsg.ok{color:#1a7f37}.pmfr-m-detail{margin-top:8px;padding-top:8px;border-top:1px dashed var(--dsw-alias-border-l2,#ddd)}.pmfr-m-sec{margin-bottom:8px}.pmfr-m-sech{font:600 11px/1.4 system-ui,sans-serif;color:var(--dsw-alias-brand-primary,#3174d6);margin-bottom:3px}.pmfr-m-pre{white-space:pre-wrap;font:12px/1.6 system-ui,sans-serif;color:var(--dsw-alias-label-primary)}.pmfr-m-ul{margin:0;padding-left:16px;font:12px/1.6 system-ui,sans-serif}.pmfr-m-note{font:11px/1.5 system-ui,sans-serif;color:var(--dsw-alias-label-secondary)}.pmfr-m-tr{font:12px/1.6 system-ui,sans-serif;color:var(--dsw-alias-label-primary);margin-bottom:4px}.pmfr-m-err{font:12px/1.5 system-ui,sans-serif;color:#b3261e}.pmfr-m-ping{font:11px/1.5 system-ui,sans-serif;padding:4px 8px;border-radius:6px;margin-bottom:6px}.pmfr-m-ping.ok{background:#e8f5ec;color:#1a7f37}.pmfr-m-ping.bad{background:#fdecec;color:#b3261e}.pmfr-tab-btn{border:1px solid var(--dsw-alias-border-l2,#ddd);border-radius:7px;padding:7px 10px;background:var(--dsw-alias-bg-layer-1);color:var(--dsw-alias-label-primary);font:12px/1.4 system-ui,sans-serif;text-align:left;cursor:pointer}.pmfr-tab-btn:hover{border-color:var(--dsw-alias-brand-primary);color:var(--dsw-alias-brand-primary)}`;
    function StyledChip(props) {
      // 始终捕获输入通道，供会议纪要面板的「归档/交给 Agent」按钮使用
      if (props.inputActions) latestInputActions = props.inputActions;
      React.useEffect(() => {
        function align() {
          if (typeof document === 'undefined' || !document.querySelector) return;
          const dock = document.querySelector('.pmfr-dock');
          if (!dock) return;
          const box = document.querySelector('form textarea, textarea, [contenteditable="true"]');
          if (!box) return;
          const left = box.getBoundingClientRect().left;
          if (left > 0) {
            dock.style.maxWidth = 'none';
            dock.style.paddingLeft = Math.round(left) + 'px';
          }
        }
        align();
        if (typeof window !== 'undefined' && typeof window.addEventListener === 'function') {
          window.addEventListener('resize', align);
          var alignTimer = window.setInterval(align, 2000);
        }
        return () => {
          if (typeof window !== 'undefined' && typeof window.removeEventListener === 'function') window.removeEventListener('resize', align);
          if (typeof window !== 'undefined' && typeof window.clearInterval === 'function' && typeof alignTimer !== 'undefined') window.clearInterval(alignTimer);
        };
      }, []);
      return h('div', { className: 'pmfr-dock' }, h('style', null, css), h(FileChip, props), h(SkillStrip, props));
    }
    function projectOfPath(path) { return projectOf(path); }
    function basename(p) { const i = Math.max(p.lastIndexOf('\\'), p.lastIndexOf('/')); return i >= 0 ? p.slice(i + 1) : p; }
    function normalized(p) { return String(p || '').replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase(); }
    // 当前文件树根（同步读取原生树的 data-files-root）；没有树时退回已记录的根
    function currentTreeRoot() {
      try {
        if (typeof document !== 'undefined') {
          let el = null;
          if (typeof document.querySelector === 'function') el = document.querySelector('[data-files-root]');
          else if (typeof document.querySelectorAll === 'function') el = document.querySelectorAll('[data-files-root]')[0];
          const r = el && el.getAttribute ? el.getAttribute('data-files-root') : '';
          if (r) return r;
        }
      } catch (e) { }
      return roots[0] || '';
    }
    // 允许引用的范围 = 当前打开的工作区（其内文件都可引用），不依赖任何预置配置
    function allowed(absolutePath) {
      const root = currentTreeRoot();
      if (!root) return false;
      const p = normalized(absolutePath);
      const r = normalized(root);
      return p === r || p.startsWith(r + '/');
    }
    // ============ 会议纪要面板（better-sidebar tab；数据读取用户目录 ~/.pm-workbench/cache） ============
    const MINUTES_URL = 'https://shanji.dingtalk.com/app/transcribes';
    class MinutesBoundary extends React.Component {
      constructor(p) { super(p); this.state = { err: null }; }
      static getDerivedStateFromError(err) { return { err: String(err && err.message || err) }; }
      componentDidCatch(err) { if (typeof console !== 'undefined' && console.error) console.error('[pm-workbench] minutes panel error', err); }
      render() {
        if (this.state.err) return h('div', { className: 'pmfr-m-err', style: { padding: '10px' } }, '面板渲染出错: ' + this.state.err);
        return this.props.children;
      }
    }
    function fmtDate(ms) { try { const d = new Date(ms); return d ? `${d.getMonth() + 1}-${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}` : ''; } catch (e) { return ''; } }
    function fmtDur(ms) { if (!ms && ms !== 0) return ''; const s = Math.round(ms / 1000); return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; }
    function MinutesPanelBody(props) {
      const visible = props.visible !== false;
      const sid = (props.scope && props.scope.sessionId) || props.sessionId || '';
      const fileUrl = (p) => '/sidebar/file?sessionId=' + encodeURIComponent(sid) + '&path=' + encodeURIComponent(p);
      // 项目号由当前工作区（会话 cwd）决定，无需人工选择
      const WS_CWD = (props.scope && props.scope.cwd) || '';
      const wsProject = (() => { const mm = /IP\s?(\d{3})/i.exec(WS_CWD); return mm ? 'IP' + mm[1] : ''; })();
      // 取数：优先宿主路由（若已加载）；不可用时自动回退到缓存文件（better-sidebar 文件接口）
      const fetchJson = (routeUrl, cachePath) => {
        return fetch(routeUrl).then((r) => (r.ok ? r.text() : Promise.reject(new Error('HTTP ' + r.status))))
          .then((txt) => JSON.parse(txt))
          .catch(() => fetch(fileUrl(cachePath)).then((r) => {
            if (!r.ok) throw new Error('HTTP ' + r.status + '（宿主路由与缓存均不可用）');
            return r.text();
          }).then((txt) => JSON.parse(txt)));
      };
      // 缓存目录：用户家目录（~ 由 better-sidebar 宿主展开为 %USERPROFILE%），跟人走、与项目解耦、多 PM 零冲突
      const CACHE_BASE = '~/.pm-workbench/cache';
      const loadArchiveIndex = () => {
        fetchJson(null, CACHE_BASE + '/archive-index.json').then((idx) => {
          if (!idx) return;
          try {
            // uuid → 归档条目数组（同一听记可归档到多个项目）
            const map = {};
            for (const e of (idx.entries || [])) {
              if (!e || !e.uuid) continue;
              if (!map[e.uuid]) map[e.uuid] = [];
              map[e.uuid].push(e);
            }
            setArchived(map);
          } catch (e) { }
        }).catch(() => { });
      };
      const [items, setItems] = React.useState(null);
      const [listErr, setListErr] = React.useState('');
      const [cacheAt, setCacheAt] = React.useState('');
      const [q, setQ] = React.useState('');
      const [openUuid, setOpenUuid] = React.useState(null);
      const [details, setDetails] = React.useState({});
      const [downloads, setDownloads] = React.useState({});
      const [archived, setArchived] = React.useState({});
      const load = React.useCallback(() => {
        setListErr('');
        fetchJson(null, CACHE_BASE + '/minutes-list.json').then((d) => {
          setCacheAt((d.generatedAt || '').replace('T', ' ').slice(0, 16));
          setItems(d.minutes || []);
        }).catch((e) => {
          setItems([]);
          setListErr('首次使用：点右上角「🔄 同步」生成缓存（约 1-2 分钟）。' + (e && e.message ? ' ' + e.message : ''));
        });
      }, [sid]);
      React.useEffect(() => { load(); }, [load]);
      // 读取归档索引（uuid → 条目数组）；同一听记可能已归档到多个项目
      React.useEffect(() => { loadArchiveIndex(); }, [sid]);
      // 同步：点一下 → Agent 跑 dws 更新用户缓存 → 面板轮询自动刷新（首次=生成缓存，之后=同步最新）
      const syncNow = () => {
        const text = `请同步会议纪要面板缓存：1) 运行 dws minutes +list-all --format json；2) 对每条听记运行 dws minutes +detail --id <taskUuid>（若 %USERPROFILE%\\.pm-workbench\\cache\\minutes-detail\\<uuid>.json 已存在可跳过）；3) 把列表写入 "%USERPROFILE%\\.pm-workbench\\cache\\minutes-list.json"（结构 {generatedAt, minutes}，%USERPROFILE% 展开为本机用户目录），每条详情写入 "%USERPROFILE%\\.pm-workbench\\cache\\minutes-detail\\<taskUuid>.json"；4) 完成后告诉我共几条。`
        const how = sendPrompt(text);
        setCacheAt(how === 'sent' ? '同步中…（Agent 正在运行 dws，完成后自动刷新）' : '同步指令已复制到剪贴板，请粘贴发送');
        if (how !== 'sent') return;
        let tries = 0;
        const timer = setInterval(() => {
          tries++;
          fetchJson(null, CACHE_BASE + '/minutes-list.json').then((d) => {
            const at = (d.generatedAt || '').replace('T', ' ').slice(0, 16);
            if (at && at !== cacheAt) {
              clearInterval(timer);
              setCacheAt(at + '（已同步）');
              load(); loadArchiveIndex();
            } else if (tries > 100) {
              clearInterval(timer);
              setCacheAt('同步超时，请稍后重试');
            }
          }).catch(() => { });
        }, 3000);
      };
      const toggleDetail = (m) => {
        const uuid = m.taskUuid;
        if (openUuid === uuid) { setOpenUuid(null); return; }
        setOpenUuid(uuid);
        if (!details[uuid]) {
          setDetails((s) => Object.assign({}, s, { [uuid]: { loading: true } }));
          fetchJson(null, CACHE_BASE + '/minutes-detail/' + uuid + '.json')
            .then((d) => setDetails((s) => Object.assign({}, s, { [uuid]: d })))
            .catch((e) => setDetails((s) => Object.assign({}, s, { [uuid]: { error: '详情读取失败: ' + String(e && e.message || e) } })));
        }
      };
      // 统一的“交给 Agent”通道：写入输入框并提交；无通道时降级为复制指令
      const sendPrompt = (text) => {
        const ia = latestInputActions;
        if (ia && typeof ia.insertText === 'function') {
          ia.insertText(text, typeof ia.captureInsertion === 'function' ? ia.captureInsertion() : undefined);
          if (typeof ia.submit === 'function') ia.submit();
          return 'sent';
        }
        try { if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text); } catch (e) { }
        return 'copied';
      };
      // 在内置侧栏打开该纪要：优先 DSH 原生浏览器标签（Electron webview，带登录态），
      // 其次 better-sidebar 已注册的浏览器类标签，最后外部浏览器兜底
      const openInSidebar = (m) => {
        const url = m.url;
        if (!url) return 'no-url';
        const tried = [];
        const bs = sidebarServices.better || (props.ctx && props.ctx.betterSidebar) || null;
        const sr = sidebarServices.right || (props.ctx && props.ctx.sidebarRight) || null;
        const srt = sidebarServices.tabs || (props.ctx && props.ctx.sidebarRightTabs) || null;
        try {
          // DSH 官方写法（源码 openExternalLink）：kind='browser'，URL 放在 params.url
          const hasBrowser = srt && typeof srt.get === 'function' ? srt.get('browser') !== undefined : true;
          if (sr && typeof sr.openTabIn === 'function' && sid) {
            if (!hasBrowser) { tried.push('browser-kind-missing'); }
            else { sr.openTabIn(sid, 'browser', { params: { url } }); return 'native-browser+url'; }
          } else { tried.push('no-sidebarRight'); }
        } catch (e) { tried.push('native:' + String(e && e.message || e)); }
        try {
          if (bs && typeof bs.getTabs === 'function' && typeof bs.openTab === 'function') {
            const list = bs.getTabs() || [];
            const cand = list.find((t) => /browser|浏览器|网页|web/i.test(String(t.id) + ' ' + (typeof t.title === 'function' ? t.title() : (t.title || ''))));
            if (cand) { bs.openTab({ type: cand.id, url, title: '听记 · ' + (m.title || '') }, { sessionId: sid }); return 'bs:' + cand.id; }
            tried.push('bs-kinds=' + list.map((t) => String(t.id)).join('|'));
          } else { tried.push('no-betterSidebar'); }
        } catch (e) { tried.push('bs:' + String(e && e.message || e)); }
        try { window.open(url, '_blank'); tried.push('external'); } catch (e) { tried.push('ext-fail'); }
        return 'fallback(' + tried.join(',') + ')';
      };
      // 在侧栏打开归档产物：
      //  - 文件 → 原生资源地址（DSH 自带 Office 预览）→ 退 better-sidebar 编辑器
      //  - 目录 → 枚举在册标签类型，用「目录内的文件」在原生文件树里定位（传目录本身会报 is a directory）
      const openPathInSidebar = (absPath, title, isDir, revealPath) => {
        const bs = sidebarServices.better || (props.ctx && props.ctx.betterSidebar) || null;
        const sr = sidebarServices.right || (props.ctx && props.ctx.sidebarRight) || null;
        const tabs = sidebarServices.tabs || (props.ctx && props.ctx.sidebarRightTabs) || null;
        const scope = { sessionId: sid };
        const tried = [];
        let kinds = [];
        try {
          if (tabs && typeof tabs.entries === 'function') {
            kinds = (tabs.entries() || []).map((t) => ({ kind: String(t.kind || ''), id: String(t.id || ''), band: String(t.band || '') }));
          } else if (tabs && typeof tabs.getSnapshot === 'function') {
            kinds = (tabs.getSnapshot() || []).map((t) => ({ kind: String(t.kind || ''), id: String(t.id || ''), band: String(t.band || '') }));
          }
        } catch (e) { tried.push('entries:' + String(e && e.message || e)); }
        const kindsLabel = 'kinds=' + kinds.map((k) => k.kind + (k.band ? '(' + k.band + ')' : '')).join('|');

        if (isDir) {
          const pick = kinds.find((k) => /file|文件|workspace|资源|目录|tree|explorer/i.test(k.kind + ' ' + k.id)) || null;
          if (pick && sr && typeof sr.openTabIn === 'function') {
            // 传目录本身：原生文件树会定位到该目录（不再把目录交给编辑器）
            try { sr.openTabIn(sid, pick.kind, { params: { path: absPath } }); return 'tree@dir:' + pick.kind; } catch (e) { tried.push('tree@dir:' + String(e && e.message || e)); }
            try { sr.openTabIn(sid, pick.kind); return 'tree:' + pick.kind; } catch (e) { tried.push('tree:' + String(e && e.message || e)); }
          } else if (!pick) { tried.push('no-tree-kind'); }
        } else {
          try {
            if (sr && typeof sr.openResource === 'function') {
              const cwdNorm = String(WS_CWD || '').replace(/\\/g, '/').replace(/\/+$/, '');
              const pth = absPath.replace(/\\/g, '/');
              const rel = (cwdNorm && pth.toLowerCase().startsWith(cwdNorm.toLowerCase() + '/')) ? pth.slice(cwdNorm.length + 1) : pth;
              sr.openResource('dsh-resource://file/session/' + sid + '/' + rel);
              return 'resource';
            }
          } catch (e) { tried.push('resource:' + String(e && e.message || e)); }
          try {
            if (bs && typeof bs.openFile === 'function') { bs.openFile(scope, absPath, title); return 'openFile'; }
          } catch (e) { tried.push('openFile:' + String(e && e.message || e)); }
        }
        try { if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(absPath); } catch (e) { }
        return 'FAILED(' + tried.join(',') + ';' + kindsLabel + ')';
      };
      // 归档：一键把指令发给 Agent，由它执行本地脚本完成确定性归档（面板不再自带任何宿主路由）
      const archive = (m, force) => {
        const uuid = m.taskUuid;
        const title = m.title || '未命名会议';
        const setMsg = (msg) => setDownloads((s) => Object.assign({}, s, { [uuid]: { msg } }));
        const text = `请归档这条听记：标题「${title}」，taskUuid: ${uuid}。执行：pwsh -File "<preset根目录>\\pm-workbench\\archive-minutes.ps1" -Uuid ${uuid}${wsProject ? ' -Project ' + wsProject : ''}${force ? ' -Force' : ''} ；脚本会一次性归档 01 纪要Word / 02 录音 / 03 AI摘要 / 04 行动项 / 05 逐字稿 / 06 关键词 到项目盘 06-项目会会议纪要 的独立文件夹，并更新个人归档索引。完成后把归档文件夹路径与文件清单发我。`;
        const how = sendPrompt(text);
        setMsg(how === 'sent' ? '已发送归档指令，脚本执行完我会告诉你路径' : '已复制归档指令到剪贴板，请粘贴发送');
      };
      const filtered = (items || []).filter((m) => !q || (m.title || '').toLowerCase().includes(q.toLowerCase()));
      const detailOf = (uuid) => details[uuid] || {};
      // 按时间分组：今天 / 本周 / 更早
      const bucketOf = (ms) => {
        try {
          const d = new Date(ms); const now = new Date();
          const day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
          if (d.getTime() >= day0) return '今天';
          if (d.getTime() >= day0 - 6 * 86400000) return '本周';
          return '更早';
        } catch (e) { return '更早'; }
      };
      const groups = [];
      for (const m of filtered) {
        const b = bucketOf(m.startTime);
        let g = groups.find((x) => x.name === b);
        if (!g) { g = { name: b, items: [] }; groups.push(g); }
        g.items.push(m);
      }
      const renderDetail = (uuid) => {
        const d = detailOf(uuid);
        if (d.loading) return h('div', { className: 'pmfr-m-detail' }, '加载详情…');
        if (d.error) return h('div', { className: 'pmfr-m-detail' }, '详情读取失败——请点 ⟳ 重试。');
        const basic = d.basic || d.basicInfo || {};
        const summary = (d.summary && (d.summary.fullSummary || d.summary.summary)) || '';
        const todos = (d.todos && (d.todos.items || d.todos.todos)) || [];
        const kws = (d.keywords && (d.keywords.keywords || d.keywords.items)) || [];
        const paras = (d.transcript && (d.transcript.paragraphs || d.transcript.items)) || [];
        const metaBits = [];
        if (basic.startTime) metaBits.push('开始 ' + String(basic.startTime));
        if (basic.durationMillis || basic.duration) metaBits.push('时长 ' + (basic.duration || fmtDur(basic.durationMillis)));
        return h('div', { className: 'pmfr-m-detail' },
          metaBits.length ? h('div', { className: 'pmfr-m-note' }, metaBits.join(' · ')) : null,
          summary ? h('div', { className: 'pmfr-m-sec' }, h('div', { className: 'pmfr-m-sech' }, '摘要'), h('div', { className: 'pmfr-m-pre' }, String(summary))) : null,
          todos.length ? h('div', { className: 'pmfr-m-sec' }, h('div', { className: 'pmfr-m-sech' }, '行动项 (' + todos.length + ')'), h('ul', { className: 'pmfr-m-ul' }, todos.map((t, i) => h('li', { key: i }, [t.content || t.text, t.assignee ? '（' + t.assignee : null, t.dueDate ? ' 截止:' + t.dueDate + '）' : (t.assignee ? '）' : '')])))) : null,
          kws.length ? h('div', { className: 'pmfr-m-sec' }, h('div', { className: 'pmfr-m-sech' }, '关键词'), h('div', { className: 'pmfr-m-note' }, kws.map((k) => k.keyword || k.word || k).join(' · '))) : null,
          paras.length ? h('div', { className: 'pmfr-m-sec' }, h('div', { className: 'pmfr-m-sech' }, '转写（前 20 段，全文见网页）'), paras.slice(0, 20).map((p, i) => h('div', { key: i, className: 'pmfr-m-tr' }, h('b', null, (p.speakerName || p.speaker || '发言人') + '：'), p.text || p.content || ''))) : null
        );
      };
      const iconBtn = (icon, title, onClick) => h('button', { className: 'pmfr-mi-btn', type: 'button', title, onClick: (e) => { e.stopPropagation(); onClick(); } }, icon);
      const renderItem = (m) => {
        const isOpen = openUuid === m.taskUuid;
        const dl = downloads[m.taskUuid] || {};
        const arcList = archived[m.taskUuid] || [];
        const arc = arcList.find((e) => String(e.project || '').toUpperCase() === wsProject) || null;   // 本项目归档
        const arcOther = arcList.filter((e) => e !== arc);                                            // 其他项目的归档记录
        const kids = [
          // 点整行 = 直接在内置侧栏打开查看（无需单独的查看按钮）
          h('div', { key: 'row', className: 'pmfr-m-row', onClick: () => { const how = openInSidebar(m); setDownloads((s) => Object.assign({}, s, { [m.taskUuid]: { msg: '打开方式: ' + how } })); } },
            h('div', { className: 'pmfr-m-titlerow' },
              h('div', { className: 'pmfr-m-title' }, m.title || '(未命名)'),
              h('div', { className: 'pmfr-m-titletags' },
                arc
                  ? h('span', { className: 'pmfr-m-tag ok', title: '本项目(' + wsProject + ')归档于 ' + String(arc.archivedAt || '').replace('T', ' ').slice(0, 16) + ' · ' + arc.folder }, '✅ 已归档')
                  : (arcOther.length
                    ? h('span', { className: 'pmfr-m-tag other', title: arcOther.map((o) => o.project + '：' + o.folder).join('\n') }, '📦 已归档于 ' + arcOther.map((o) => o.project).join('/'))
                    : null),
                h('button', { className: 'pmfr-m-chev', type: 'button', title: isOpen ? '收起摘要' : '展开摘要', onClick: (e) => { e.stopPropagation(); toggleDetail(m); } }, isOpen ? '▾' : '▸'))),
            // 日期时间与操作按钮同一行：左侧时间，右侧按钮（不再单独占一行）
            h('div', { className: 'pmfr-m-metarow' },
              h('div', { className: 'pmfr-m-meta' }, fmtDate(m.startTime) + (m.durationMillis ? ' · ' + fmtDur(m.durationMillis) : '')),
              (arc
                ? iconBtn('📂 打开', '已归档：打开归档位置（原生文件树 + 资源管理器中定位）', () => {
                  const folder = arc.folder || '';
                  if (!folder) return;
                  try {
                    const tabsReg = sidebarServices.tabs;
                    const sr = sidebarServices.right;
                    if (sr && typeof sr.openTabIn === 'function' && (!tabsReg || typeof tabsReg.get !== 'function' || tabsReg.get('files'))) {
                      sr.openTabIn(sid, 'files', { revealIfOpened: true });
                    }
                  } catch (e) { }
                  try {
                    const c = props.ctx || {};
                    const remoteSession = (c.remote && c.remote.session) || (typeof c.get === 'function' ? c.get('remote.session') : null);
                    if (remoteSession && typeof remoteSession.openWorkspacePath === 'function') {
                      Promise.resolve(remoteSession.openWorkspacePath({ path: folder, action: 'reveal' })).catch(() => { });
                    }
                  } catch (e) { }
                })
                : iconBtn('📥 归档', '归档到当前项目 ' + (wsProject || '（工作区未识别项目）') + '：录音+纪要+摘要+行动项+逐字稿+关键词（编号 01~06）', () => archive(m))))),
        ];
        if (dl.msg) kids.push(h('div', { key: 'msg', className: 'pmfr-m-dlmsg' }, dl.msg));
        if (isOpen) kids.push(renderDetail(m.taskUuid));
        return h('div', { key: m.taskUuid, className: 'pmfr-m-item' + (isOpen ? ' open' : '') + (arc ? ' archived' : '') }, kids);
      };
      const renderGroup = (g) => h('div', { key: g.name, className: 'pmfr-m-group' },
        h('div', { className: 'pmfr-m-groupname' }, g.name),
        g.items.map(renderItem));
      const kids = [];
      kids.push(h('div', { key: 'top', className: 'pmfr-m-topbar' },
        h('div', { className: 'pmfr-m-brand' }, '📅 会议纪要'),
        h('div', { className: 'pmfr-m-topbtns' },
          h('button', { className: 'pmfr-m-refresh', type: 'button', title: '重新读取缓存文件（纯本地，不拉新数据）', onClick: load }, '⟳'),
          h('button', { className: 'pmfr-m-refresh', type: 'button', title: '同步钉钉最新：首次自动生成缓存；之后拉取最新听记（Agent 执行，完成后自动刷新）', onClick: syncNow }, '🔄 同步'))));
      kids.push(h('div', { key: 'cache', className: 'pmfr-m-cachebar' }, (cacheAt ? ('读取于 ' + cacheAt) : '尚未读取') + (wsProject ? '　·　归档目标 ' + wsProject : '　·　工作区未识别项目号')));
      kids.push(h('input', { key: 'q', className: 'pmfr-m-search', type: 'text', placeholder: '搜索标题…', value: q, onInput: (e) => setQ(e.target.value) }));
      if (listErr) kids.push(h('div', { key: 'err', className: 'pmfr-m-err' }, listErr, ' ', h('button', { className: 'pmfr-tab-btn', onClick: load }, '重试')));
      if (items === null && !listErr) kids.push(h('div', { key: 'loading', className: 'pmfr-m-note' }, '加载中…'));
      if (items !== null && !filtered.length && !listErr) kids.push(h('div', { key: 'empty', className: 'pmfr-m-note' }, q ? '没有匹配的纪要' : '暂无纪要'));
      kids.push(h('div', { key: 'list', className: 'pmfr-m-list' }, groups.map(renderGroup)));
      kids.push(h('div', { key: 'note', className: 'pmfr-minutes-note' }, '数据来自本机 dws（钉钉组织权限），经宿主路由实时读取。🔄 同步钉钉最新（首次=生成缓存） · 点标题侧栏查看 · ▸ 展开摘要 · 右下按钮归档 / 打开。'));
      return h(MinutesBoundary, null, h('div', { className: 'pmfr-minutes-panel', 'data-pm-minutes-tab': '1' }, kids));
    }
    return {
      inject: ['slots', 'remote.workspaceFiles'],
      apply(ctx) {
        statFile = (sessionId, absolutePath) => ctx.remote.workspaceFiles.stat(sessionId, absolutePath);
        try { sidebarServices.right = (typeof ctx.get === 'function' ? ctx.get('sidebarRight') : ctx.sidebarRight) || null; sidebarServices.tabs = (typeof ctx.get === 'function' ? ctx.get('sidebarRightTabs') : ctx.sidebarRightTabs) || null; } catch (e) { }
        // 工作区根由原生文件树的 data-files-root 注入（见 setWorkspaceRoot 调用点），无宿主依赖
        const disposers = [];
        // 自研文件引用按钮：默认关闭（ENABLE_FILE_REFERENCE = false）
        if (ENABLE_FILE_REFERENCE) {
        disposers.push(ctx.slots.inject('sidebar.right.tab.document.actions', () => ctx.slots.register({ name: 'sidebar.right.tab.document.actions', id: 'pm-file-reference', order: 20, label: '引用到对话' }, AddFileReference)));
        disposers.push(ctx.slots.inject('sidebar.right.tab.files.actions', () => ctx.slots.register({ name: 'sidebar.right.tab.files.actions', id: 'pm-file-reference-selected', order: 20, label: '引用已选文件' }, FilesToolbarAction)));
        }   // end ENABLE_FILE_REFERENCE
        // dock 通道始终注册：会议纪要面板的「归档」按钮靠它发送指令
        disposers.push(ctx.slots.inject('conversation.input.dock', () => ctx.slots.register({ name: 'conversation.input.dock', id: 'pm-file-reference-chip', order: 5, label: '项目文件引用' }, StyledChip)));
        // 会议纪要：better-sidebar 原生 tab（探测 + internal/service 事件补注册，标准范式）
        try {
          let registered = false;
          const tryRegister = () => {
            if (registered) return;
            const bs = typeof ctx.get === 'function' ? ctx.get('betterSidebar') : (ctx.betterSidebar || null);
            if (!bs || typeof bs.registerTab !== 'function') return;
            registered = true;
            const disposer = bs.registerTab({
              id: 'pm-workbench:minutes',
              title: () => '会议纪要',
              description: () => '浏览钉钉 AI 听记纪要：查看 / 归档到项目盘',
              icon: (size) => h('span', { style: { fontSize: (size || 16) + 'px' }, ariaHidden: 'true' }, '📅'),
              order: 65,
              single: true,
              component: (props) => h(MinutesBoundary, null, h(MinutesPanelBody, props)),
            });
            if (typeof disposer === 'function') disposers.push(disposer);

          };
          ctx.effect(() => {
            const off = typeof ctx.on === 'function' ? ctx.on('internal/service', () => tryRegister()) : undefined;
            tryRegister();
            return () => { if (typeof off === 'function') off(); };
          }, 'pm-workbench: minutes tab watch');
        } catch (e) {
          if (typeof console !== 'undefined' && console.warn) console.warn('[pm-workbench] minutes tab setup failed', e);
        }
        return () => { selected = null; disposers.reverse().forEach((dispose) => { if (typeof dispose === 'function') dispose(); }); };
      },
    };
  },
});
