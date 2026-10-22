#!/usr/bin/env osascript -l JavaScript
// Run by neru after it right-clicks a Slack message (see config.toml):
// the right-click focuses the message row and mounts its hover toolbar, so
// the row's "Reply in thread" button is found via accessibility and AXPressed
// (Chromium dispatches a real click for AXPress, no mouse needed).
// JXA + ObjC bridge because AppleScript tree walks are far too slow on
// Slack's Electron accessibility tree.
ObjC.import('Cocoa');
ObjC.bindFunction('AXUIElementCreateApplication', ['id', ['unsigned int']]);
ObjC.bindFunction('AXUIElementCopyAttributeValue', ['int', ['id', 'id', 'id *']]);
ObjC.bindFunction('AXUIElementSetAttributeValue', ['int', ['id', 'id', 'id']]);
ObjC.bindFunction('AXUIElementPerformAction', ['int', ['id', 'id']]);

function run() {
  const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier('com.tinyspeck.slackmacgap');
  if (apps.count === 0) return;
  const ax = $.AXUIElementCreateApplication(apps.objectAtIndex(0).processIdentifier);
  $.AXUIElementSetAttributeValue(ax, $('AXManualAccessibility'), $.NSNumber.numberWithBool(true));

  const attr = (el, name) => {
    const ref = Ref();
    return $.AXUIElementCopyAttributeValue(el, $(name), ref) === 0 ? ref[0] : null;
  };
  const str = (x) => (x === null ? '' : ObjC.unwrap(x) || '');

  function search(el, pred, depth = 0) {
    if (depth > 45) return null;
    if (pred(el)) return el;
    const kids = attr(el, 'AXChildren');
    if (!kids) return null;
    for (let i = 0; i < kids.count; i++) {
      const hit = search(kids.objectAtIndex(i), pred, depth + 1);
      if (hit) return hit;
    }
    return null;
  }

  // the toolbar button: "Reply in thread" / "Reply to thread" per workspace
  const isReply = (el) =>
    str(attr(el, 'AXRole')) === 'AXButton' &&
    str(attr(el, 'AXDescription')).indexOf('Reply') === 0;
  const isMenu = (el) => str(attr(el, 'AXRole')) === 'AXMenu';

  function findInWindows(pred) {
    const wins = attr(ax, 'AXWindows');
    for (let i = 0; wins && i < wins.count; i++) {
      const hit = search(wins.objectAtIndex(i), pred);
      if (hit) return hit;
    }
    return null;
  }

  delay(0.3);
  for (let i = 0; i < 10; i++) {
    // right-clicking a word can open a context menu (native Look Up/Search
    // menu, or a mention/link menu) on top of the message — dismiss it; the
    // click focused the message row underneath either way
    if (findInWindows(isMenu)) {
      Application('System Events').keyCode(53);
      delay(0.25);
      continue;
    }
    const f = attr(ax, 'AXFocusedUIElement');
    if (f) {
      const hit = search(f, isReply);
      if (hit) {
        $.AXUIElementPerformAction(hit, $('AXPress'));
        tickAlsoSend();
        return;
      }
    }
    delay(0.15);
  }
  const me = Application.currentApplication();
  me.includeStandardAdditions = true;
  me.beep();

  // pre-tick "Also send to #channel" / "Also send as direct message" in the
  // thread pane that just opened, so a plain Enter already lands in the main
  // chat; then put focus back in the composer (the tick can steal it)
  function tickAlsoSend() {
    const isAlsoSend = (el) =>
      str(attr(el, 'AXRole')) === 'AXCheckBox' &&
      str(attr(el, 'AXTitle')).indexOf('Also send') === 0;
    const isThreadComposer = (el) =>
      str(attr(el, 'AXRole')) === 'AXTextArea' &&
      str(attr(el, 'AXDescription')).indexOf('Reply') === 0;

    let cb = null;
    for (let i = 0; i < 20 && !cb; i++) {
      delay(0.15);
      cb = findInWindows(isAlsoSend);
    }
    if (!cb) return; // pane never opened; Primary+Shift+Enter ticks it anyway
    if (Number(ObjC.unwrap(attr(cb, 'AXValue'))) === 0) {
      $.AXUIElementPerformAction(cb, $('AXPress'));
    }
    for (let i = 0; i < 10; i++) {
      delay(0.1);
      const comp = findInWindows(isThreadComposer);
      if (comp) {
        $.AXUIElementSetAttributeValue(comp, $('AXFocused'), $.NSNumber.numberWithBool(true));
        return;
      }
    }
  }
}
