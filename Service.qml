import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var widgets: []

  function registerWidget(widget) {
    if (!widget || root.widgets.indexOf(widget) !== -1) return
    root.widgets = root.widgets.concat([widget])
  }

  function unregisterWidget(widget) {
    root.widgets = root.widgets.filter(function (w) { return w !== widget })
  }

  function focusedWidget() {
    for (var i = 0; i < root.widgets.length; i++) {
      if (root.widgets[i] && root.widgets[i].onFocusedScreen === true) return root.widgets[i]
    }
    return root.widgets.length > 0 ? root.widgets[0] : null
  }

  // The reader opens on the monitor you are looking at, so every call goes to
  // the widget there.
  function withFocused(action) {
    var widget = root.focusedWidget()
    return widget ? action(widget) : "no speed reader on the bar"
  }

  IpcHandler {
    target: "sterre.speed-reader"

    function open(): void { root.withFocused(function (w) { w.open() }) }
    function close(): void { root.widgets.forEach(function (w) { if (w) w.close() }) }
    function toggle(): void { root.withFocused(function (w) { w.toggle() }) }
    function read(): string {
      return root.withFocused(function (w) {
        w.readClipboard(false)
        return "reading clipboard"
      })
    }
    // One keybinding, from nothing to reading: open, take whatever is on the
    // clipboard, and start.
    function readnow(): string {
      return root.withFocused(function (w) {
        w.readClipboard(true)
        return "reading clipboard now"
      })
    }
    function play(): string {
      return root.withFocused(function (w) {
        w.play()
        return "playing"
      })
    }
    function pause(): string {
      return root.withFocused(function (w) {
        w.pause()
        return "paused"
      })
    }
    function speed(value: string): string {
      return root.withFocused(function (w) {
        w.setWpm(Number(value))
        return String(w.wpm) + " wpm"
      })
    }
    function status(): string {
      return root.withFocused(function (w) {
        return Model.positionText(w.index, w.words) + ", " + w.wpm + " wpm"
      })
    }
  }
}
