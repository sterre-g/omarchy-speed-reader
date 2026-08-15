var SENTENCE_END = /[.!?]["'\)\]]*$/
var CLAUSE_END = /[,;:]["'\)\]]*$/

function clampWpm(value, fallback) {
  var n = Number(value)
  if (!isFinite(n)) n = fallback
  n = Math.round(n)
  if (n < 60) return 60
  if (n > 1500) return 1500
  return n
}

function tokenize(text) {
  var raw = String(text || "").replace(/\s+/g, " ").trim()
  if (raw === "") return []
  return raw.split(" ")
}

// Index of the letter to pin the eye on, roughly a third into the word. The
// offset walks past leading punctuation so an opening quote does not shift the
// whole word sideways.
function orpIndex(word) {
  var text = String(word || "")
  if (text === "") return 0

  var lead = 0
  while (lead < text.length && !/[0-9A-Za-z]/.test(text.charAt(lead))) lead++
  if (lead >= text.length) return Math.floor(text.length / 2)

  var core = text.slice(lead).replace(/[^0-9A-Za-z].*$/, "")
  var n = core.length
  var offset = n <= 1 ? 0 : (n <= 5 ? 1 : (n <= 9 ? 2 : 3))
  return Math.min(text.length - 1, lead + offset)
}

function dwellFactor(word) {
  var text = String(word || "")
  var core = text.replace(/[^0-9A-Za-z]/g, "")
  var factor = 1

  if (core.length >= 12) factor += 0.5
  else if (core.length >= 8) factor += 0.3
  else if (core.length >= 6) factor += 0.15

  if (SENTENCE_END.test(text)) factor += 0.9
  else if (CLAUSE_END.test(text)) factor += 0.4

  return factor
}

function wordDelayMs(word, wpm) {
  var base = 60000 / clampWpm(wpm, 400)
  return Math.max(20, Math.round(base * dwellFactor(word)))
}

function totalSeconds(words, wpm) {
  var total = 0
  for (var i = 0; i < words.length; i++) total += wordDelayMs(words[i], wpm)
  return Math.round(total / 1000)
}

function sentenceStarts(words) {
  var starts = [0]
  for (var i = 0; i < words.length - 1; i++) {
    if (SENTENCE_END.test(words[i])) starts.push(i + 1)
  }
  return starts
}

// Back one sentence means the start of the current sentence unless we are
// already sitting on it, which is what makes repeated presses walk backwards.
function previousSentence(words, index) {
  var starts = sentenceStarts(words)
  var current = 0
  for (var i = 0; i < starts.length; i++) {
    if (starts[i] <= index) current = i
  }
  if (starts[current] < index) return starts[current]
  return current > 0 ? starts[current - 1] : 0
}

function nextSentence(words, index) {
  var starts = sentenceStarts(words)
  for (var i = 0; i < starts.length; i++) {
    if (starts[i] > index) return starts[i]
  }
  return Math.max(0, words.length - 1)
}

function progress(index, total) {
  if (total <= 0) return 0
  return Math.max(0, Math.min(1, index / total))
}

function formatDuration(seconds) {
  var total = Math.max(0, Math.round(seconds))
  var minutes = Math.floor(total / 60)
  var rest = total % 60
  return minutes + ":" + (rest < 10 ? "0" + rest : String(rest))
}

function positionText(index, words) {
  if (words.length === 0) return "nothing loaded"
  return (Math.min(index + 1, words.length)) + " / " + words.length + " words"
}

function remainingText(index, words, wpm) {
  if (words.length === 0) return ""
  return formatDuration(totalSeconds(words.slice(index), wpm)) + " left"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    clampWpm: clampWpm,
    tokenize: tokenize,
    orpIndex: orpIndex,
    dwellFactor: dwellFactor,
    wordDelayMs: wordDelayMs,
    totalSeconds: totalSeconds,
    sentenceStarts: sentenceStarts,
    previousSentence: previousSentence,
    nextSentence: nextSentence,
    progress: progress,
    formatDuration: formatDuration,
    positionText: positionText,
    remainingText: remainingText
  }
}
