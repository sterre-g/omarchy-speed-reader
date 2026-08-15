import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "sterre.speed-reader"
  manageIpc: false

  property var words: []
  property int index: 0
  property bool playing: false
  property int wpm: Model.clampWpm(root.setting("wpm", 400), 400)
  property string sourceNote: "nothing loaded"

  readonly property string currentWord: root.index >= 0 && root.index < root.words.length
    ? root.words[root.index]
    : ""
  readonly property int currentDelay: root.currentWord !== ""
    ? Model.wordDelayMs(root.currentWord, root.wpm)
    : 250
  readonly property bool atEnd: root.words.length > 0 && root.index >= root.words.length - 1

  // Only the widget on the focused monitor answers IPC, so the reader opens
  // where you are looking. The bar keeps one panel open shell wide anyway.
  readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen
    ? root.QsWindow.window.screen.name
    : ""
  readonly property bool onFocusedScreen: Hyprland.focusedMonitor && root.screenName !== ""
    ? Hyprland.focusedMonitor.name === root.screenName
    : false

  // The reader owns the middle of the screen now, so the word is sized for
  // reading across the room rather than for a bar popup.
  readonly property int wordSize: Math.round(Style.font.displayLarge * 2.4)
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function loadText(raw) {
    var next = Model.tokenize(raw)
    root.words = next
    root.index = 0
    root.playing = false
    root.sourceNote = next.length > 0
      ? "clipboard, " + Model.formatDuration(Model.totalSeconds(next, root.wpm)) + " at " + root.wpm + " wpm"
      : "clipboard was empty"
  }

  function loadClipboard() {
    if (!clipboard.running) clipboard.running = true
  }

  function play() {
    if (root.words.length === 0) return
    if (root.atEnd) root.index = 0
    root.playing = true
  }

  function pause() {
    root.playing = false
  }

  function togglePlay() {
    if (root.playing) root.pause()
    else root.play()
  }

  function advance() {
    if (root.index + 1 >= root.words.length) {
      root.index = Math.max(0, root.words.length - 1)
      root.playing = false
      return
    }
    root.index = root.index + 1
  }

  function back() {
    root.index = Model.previousSentence(root.words, root.index)
  }

  function forward() {
    root.index = Model.nextSentence(root.words, root.index)
  }

  function setWpm(next) {
    root.wpm = Model.clampWpm(next, 400)
  }

  onOpenedChanged: if (opened) {
    if (root.words.length === 0 && root.setting("autoLoad", true)) root.loadClipboard()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  } else {
    root.pause()
  }

  Timer {
    id: tick
    interval: root.currentDelay
    running: root.playing && root.words.length > 0
    repeat: true
    onTriggered: root.advance()
  }

  Process {
    id: clipboard
    command: ["wl-paste", "-n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadText(text)
    }
  }

  IpcHandler {
    target: "sterre.speed-reader"
    enabled: root.onFocusedScreen

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function read(): string {
      root.open()
      root.loadClipboard()
      return "reading clipboard"
    }
    function play(): string {
      root.play()
      return "playing"
    }
    function pause(): string {
      root.pause()
      return "paused"
    }
    function speed(value: string): string {
      root.setWpm(Number(value))
      return String(root.wpm) + " wpm"
    }
    function status(): string {
      return Model.positionText(root.index, root.words) + ", " + root.wpm + " wpm"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf02d"
    active: root.playing
    tooltipText: root.words.length > 0
      ? Model.positionText(root.index, root.words) + ", " + Model.remainingText(root.index, root.words, root.wpm)
      : "Speed reader"
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) root.loadClipboard()
      else root.toggle()
    }
  }

  // Reading happens in the middle of the screen rather than in a popup pinned
  // to the bar: the whole point of RSVP is that your eyes do not travel, so the
  // word has to sit where you are already looking.
  PanelWindow {
    id: readerWindow
    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    visible: root.opened
    color: "transparent"
    WlrLayershell.namespace: "sterre-speed-reader"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: root.opened
      onMoveRequested: function (dx, dy) {
        if (dy < 0) root.setWpm(root.wpm + 25)
        else if (dy > 0) root.setWpm(root.wpm - 25)
        else if (dx < 0) root.back()
        else if (dx > 0) root.forward()
      }
      onActivateRequested: root.togglePlay()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        if (t === "r" || t === "R") root.loadClipboard()
        else if (t === "0") root.index = 0
      }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(760), readerWindow.width - Style.space(80))
        implicitHeight: column.implicitHeight + Style.spacing.panelPadding * 2
        radius: Style.cornerRadius
        color: Color.menu.background
        border.width: Math.max(1, Style.space(2))
        border.color: Color.menu.border

      Column {
        id: column
        anchors.centerIn: parent
        width: card.width - Style.spacing.panelPadding * 2
        spacing: Style.space(10)

        PanelSectionHeader {
          width: parent.width
          text: "Speed reader"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Item {
          id: display
          width: parent.width
          height: Math.round(root.wordSize * 2.2)

          readonly property string word: root.currentWord
          readonly property int orp: Model.orpIndex(display.word)
          readonly property string pre: display.word.substring(0, display.orp)
          readonly property string mid: display.word.substring(display.orp, display.orp + 1)
          readonly property string post: display.word.substring(display.orp + 1)
          readonly property real pivot: Math.round(display.width * 0.42)

          Rectangle {
            x: display.pivot
            width: 1
            height: Math.round(root.wordSize * 0.35)
            color: root.dim
            anchors.top: parent.top
          }

          Rectangle {
            x: display.pivot
            width: 1
            height: Math.round(root.wordSize * 0.35)
            color: root.dim
            anchors.bottom: parent.bottom
          }

          Text {
            id: midText
            x: display.pivot - width / 2
            anchors.verticalCenter: parent.verticalCenter
            text: display.mid
            font.family: root.fontFamily
            font.pixelSize: root.wordSize
            color: Color.accent
          }

          Text {
            anchors.right: midText.left
            anchors.baseline: midText.baseline
            text: display.pre
            font.family: root.fontFamily
            font.pixelSize: root.wordSize
            color: root.foreground
          }

          Text {
            anchors.left: midText.right
            anchors.baseline: midText.baseline
            text: display.post
            font.family: root.fontFamily
            font.pixelSize: root.wordSize
            color: root.foreground
          }
        }

        Rectangle {
          width: parent.width
          height: Math.max(2, Style.space(3))
          radius: height / 2
          color: Qt.darker(root.foreground, 2.6)

          Rectangle {
            width: parent.width * Model.progress(root.index, Math.max(1, root.words.length - 1))
            height: parent.height
            radius: parent.radius
            color: root.foreground
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(positionText.implicitHeight, remainingText.implicitHeight)

          Text {
            id: positionText
            anchors.left: parent.left
            text: Model.positionText(root.index, root.words)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: root.dim
          }

          Text {
            id: remainingText
            anchors.right: parent.right
            text: Model.remainingText(root.index, root.words, root.wpm)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: root.dim
          }
        }

        Item {
          width: parent.width
          implicitHeight: controls.implicitHeight

          Row {
            id: controls
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.spacing.controlGap

            PanelActionButton {
              iconText: "\uf021"
              tooltipText: "Load clipboard"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.loadClipboard()
            }

            PanelActionButton {
              iconText: "\uf04a"
              tooltipText: "Back one sentence"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.back()
            }

            PanelActionButton {
              iconText: root.playing ? "\uf04c" : "\uf04b"
              tooltipText: root.playing ? "Pause" : "Play"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.togglePlay()
            }

            PanelActionButton {
              iconText: "\uf04e"
              tooltipText: "Forward one sentence"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.forward()
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: speedRow.implicitHeight

          Row {
            id: speedRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.spacing.controlGap

            PanelActionButton {
              iconText: "\uf068"
              tooltipText: "Slower"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.setWpm(root.wpm - 25)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.wpm + " wpm"
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              color: root.foreground
            }

            PanelActionButton {
              iconText: "\uf067"
              tooltipText: "Faster"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.setWpm(root.wpm + 25)
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Text {
          width: parent.width
          text: root.sourceNote + "\nspace play, h l sentence, k j speed, r reload, 0 restart"
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.dim
          wrapMode: Text.WordWrap
        }
      }
      }
    }
  }
}
