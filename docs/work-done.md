# Work done

## 2026-08-15 - first release

- `main`: RSVP clipboard reader. Tokenizing, optimal recognition point, per
  word dwell multipliers and sentence jumping live in `Model.js` with 14 node
  assertions; `Panel.qml` is the bar widget and panel.
- Only the widget on the focused monitor registers the IPC handler, which is
  how the reader opens on the screen you are looking at without needing a
  singleton service.
