#!/usr/bin/env osascript -l JavaScript
// Bound to a neru hotkey in Slack (see config.toml). With a reply typed in
// the thread composer: tick "Also send to #channel", press "Send now", then
// press the pane's Close button — the reply lands in the main chat and the
// thread sidebar closes. (Close button instead of Escape: Escape only works
// from some focus states, the button always does.)
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
  const press = (el) => $.AXUIElementPerformAction(el, $('AXPress'));
  const bail = () => {
    const me = Application.currentApplication();
    me.includeStandardAdditions = true;
    me.beep();
  };

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

  // "Also send to #channel" in channels, "Also send as direct message" in DMs
  const isAlsoSend = (el) =>
    str(attr(el, 'AXRole')) === 'AXCheckBox' &&
    str(attr(el, 'AXTitle')).indexOf('Also send') === 0;
  const isSendNow = (el) =>
    str(attr(el, 'AXRole')) === 'AXButton' &&
    str(attr(el, 'AXDescription')).indexOf('Send now') === 0;
  const isClose = (el) =>
    str(attr(el, 'AXRole')) === 'AXButton' &&
    str(attr(el, 'AXDescription')) === 'Close';

  function findCheckbox() {
    const fw = attr(ax, 'AXFocusedWindow');
    let cb = fw ? search(fw, isAlsoSend) : null;
    if (cb) return cb;
    const wins = attr(ax, 'AXWindows');
    for (let i = 0; wins && i < wins.count && !cb; i++) {
      cb = search(wins.objectAtIndex(i), isAlsoSend);
    }
    return cb;
  }
  // the pane's own controls live in the checkbox's ancestor chain; walking up
  // and searching down stays inside the thread pane, so the main composer's
  // Send button can never be picked up
  function inPane(cb, pred, maxUp) {
    let node = cb;
    for (let up = 0; up < maxUp; up++) {
      node = attr(node, 'AXParent');
      if (!node) return null;
      const hit = search(node, pred);
      if (hit) return hit;
    }
    return null;
  }

  const cb = findCheckbox();
  if (!cb) return bail(); // no thread pane open

  const send = inPane(cb, isSendNow, 5);
  if (!send || !ObjC.unwrap(attr(send, 'AXEnabled'))) return bail(); // nothing typed

  if (Number(ObjC.unwrap(attr(cb, 'AXValue'))) === 0) {
    press(cb);
    // confirm the tick before sending — never send a thread-only reply
    let ticked = false;
    for (let i = 0; i < 10 && !ticked; i++) {
      delay(0.1);
      ticked = Number(ObjC.unwrap(attr(cb, 'AXValue'))) === 1;
    }
    if (!ticked) return bail();
  }

  press(send);
  delay(0.5);

  // re-find from scratch: the send re-renders the pane and can stale old refs
  const cb2 = findCheckbox();
  if (!cb2) return; // pane already gone
  const close = inPane(cb2, isClose, 10);
  if (close) press(close);
}
