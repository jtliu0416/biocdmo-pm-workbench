// Behavioral contract test for the client plugin without touching project files.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, 'client.js'), 'utf8');
const registrations = new Map();
const attrs = (values) => ({ getAttribute: (key) => values[key] });
const events = [];
const row = (kind, filePath) => ({
  kind,
  filePath,
  children: [],
  getAttribute: (key) => ({ 'data-files-entry': kind, 'data-files-path': filePath })[key],
  querySelector: () => null,
  appendChild(button) { this.children.push(button); },
});
const rootPath = '\\\\C-FILESERVER\\06-项目管理部\\01-Project-Ongoing\\IP266';
const folder = row('directory', rootPath + '/03-项目启动');
const file = row('file', rootPath + '/05-项目进展汇报/00-SUM/IP266项目进展汇报-2023.8.1.pptx');
const outside = row('file', '\\\\C-FILESERVER\\06-项目管理部\\01-Project-Ongoing\\IP999/private.docx');
const tree = {
  ...attrs({ 'data-files-root': rootPath }),
  querySelectorAll: () => [folder, file, outside],
};
class Observer {
  constructor(callback) { this.callback = callback; }
  observe() {}
  disconnect() {}
}
const document = {
  body: {},
  querySelectorAll: (selector) => selector === '[data-files-root]' ? [tree] : [],
  createElement: () => ({
    classList: { contains: () => false },
    setAttribute(name, value) { this[name] = value; },
    addEventListener(name, fn) { this[name] = fn; },
    remove() {},
  }),
};
const React = {
  createElement: (type, props, ...children) => ({ type, props: props || {}, children }),
  Fragment: Symbol('fragment'),
  Component: class Component { },
  useEffect(callback) { callback(); },
  useState(init) { return [init, () => { }]; },
  useSyncExternalStore(_subscribe, snapshot) { return snapshot(); },
};
let draftRev = 1;
const inputActions = {
  captureInsertion: () => ({ draftRev }),
  insertText(text, span) {
    if (span.draftRev !== draftRev) return false;
    events.push(text);
    return true;
  },
};
// 同步 thenable：模拟宿主 /pm-minutes/config（客户端不再硬编码项目根）
function syncThenable(value) {
  return {
    then(fn) { let out; try { out = fn(value); } catch (e) { return syncThenable(undefined); } return (out && typeof out.then === 'function') ? out : syncThenable(out); },
    catch() { return this; },
  };
}
const hostConfig = { projects: ['IP266'], roots: { IP266: rootPath }, parent: path.dirname(rootPath) };   // 兼容旧桩，不再被客户端使用
const fetchStub = (url) => syncThenable({
  ok: true,
  status: 200,
  json: () => syncThenable(url.indexOf('/pm-minutes/config') >= 0 ? hostConfig : {}),
  text: () => syncThenable('{}'),
});
let plugin;
vm.runInNewContext(source, {
  window: { __ModuleLoader__: { load({ factory }) { plugin = factory((key) => {
    assert.equal(key, 'react');
    return React;
  }); } } },
  document,
  MutationObserver: Observer,
  queueMicrotask,
  console,
  fetch: fetchStub,
});
plugin.apply({
  slots: {
    inject(_name, callback) { return callback(); },
    register(definition, component) { registrations.set(definition.name, component); return () => {}; },
  },
  remote: { workspaceFiles: { stat: async () => ({ ok: true, value: { version: 'test-version' } }) } },
});
// 功能开关默认关闭：自研引用按钮不再注入（better-sidebar / 原生 @ 已覆盖）
const refDisabled = /ENABLE_FILE_REFERENCE = false/.test(source);
if (refDisabled) {
  const toolbar = registrations.get('sidebar.right.tab.files.actions');
  const element = toolbar ? toolbar({ absolutePath: rootPath, inputActions, sessionId: 'session-IP266' }) : null;
  assert.ok(!element, 'file reference toolbar must be disabled when ENABLE_FILE_REFERENCE = false');
  console.log('file reference feature correctly DISABLED (by design)');
} else {
  const toolbar = registrations.get('sidebar.right.tab.files.actions');
  assert.equal(typeof toolbar, 'function');
  const element = toolbar({ absolutePath: rootPath, inputActions, sessionId: 'session-IP266' });
  assert.ok(element, 'toolbar anchor is active for this Workspace');
}
if (refDisabled) {
  console.log('reference-behavior tests skipped (file reference disabled by design; dock kept for panel buttons)');
  const dock = registrations.get('conversation.input.dock');
  assert.equal(typeof dock, 'function', 'dock registration still present');
  console.log('PM client behavior PASSED (file reference disabled by flag; dock intact)');
} else {
const bridge = element.children.find((child) => child && child.props && child.props.treeRoot);
assert.ok(bridge, 'row actions bridge rendered');
bridge.type(bridge.props);
assert.equal(folder.children.length, 1, 'folder receives a reference button');
assert.equal(file.children.length, 1, 'file receives a reference button');
assert.equal(outside.children.length, 0, 'other projects cannot be referenced');
const event = { preventDefault() {}, stopPropagation() {} };
(async () => {
  await folder.children[0].click(event);
  assert.match(events[0], /^@\/\/C-FILESERVER\/06-项目管理部\/01-Project-Ongoing\/IP266\/03-项目启动\/\n$/);
  file.children[0].click(event);
  await new Promise((resolve) => setImmediate(resolve));
  assert.match(events[1], /^@\/\//);
  assert.match(events[1], /\.pptx（版本 test-version）\n$/);
  const chip = registrations.get('conversation.input.dock')({ sessionId: 'session-IP266' });
  const rendered = chip.children.find((child) => child && typeof child.type === 'function');
  assert.equal(rendered.type(rendered.props).props.title, file.filePath.replace(/\//g, '\\'), 'chip tracks exact file');
  const other = registrations.get('conversation.input.dock')({ sessionId: 'session-other' });
  const otherRendered = other.children.find((child) => child && typeof child.type === 'function');
  assert.equal(otherRendered.type(otherRendered.props), null, 'no cross-session chip');
  draftRev++;
  const before = events.length;
  folder.children[0].click(event);
  assert.equal(events.length, before + 1, 'new draft accepts a fresh click');
  inputActions.insertText = () => false;
  file.children[0].click(event);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(events.length, before + 1, 'rejected insert does not modify the draft');
  console.log('PM row reference behavior PASSED (folder, file, boundary, version, session chip, failed insertion)');
})().catch((error) => { console.error(error); process.exitCode = 1; });
}
