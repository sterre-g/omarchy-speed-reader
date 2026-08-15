const assert = require("node:assert/strict")
const M = require("../Model.js")

function run(name, fn) {
  fn()
  process.stdout.write("ok - " + name + "\n")
}

run("tokenize collapses whitespace and drops empties", () => {
  assert.deepEqual(M.tokenize("one  two\n\tthree "), ["one", "two", "three"])
  assert.deepEqual(M.tokenize("   "), [])
  assert.deepEqual(M.tokenize(""), [])
  assert.deepEqual(M.tokenize(null), [])
})

run("wpm is clamped to a sane range", () => {
  assert.equal(M.clampWpm(400, 300), 400)
  assert.equal(M.clampWpm(10, 300), 60)
  assert.equal(M.clampWpm(99999, 300), 1500)
  assert.equal(M.clampWpm("junk", 300), 300)
  assert.equal(M.clampWpm(420.6, 300), 421)
})

run("the focus letter sits about a third into the word", () => {
  assert.equal(M.orpIndex("a"), 0)
  assert.equal(M.orpIndex("cat"), 1)
  assert.equal(M.orpIndex("readers"), 2)
  assert.equal(M.orpIndex("extraordinary"), 3)
})

run("leading punctuation shifts the focus letter with the word", () => {
  assert.equal(M.orpIndex("\"quoted"), 3)
  assert.equal(M.orpIndex("(aside)"), 2)
  assert.equal(M.orpIndex("..."), 1)
  assert.equal(M.orpIndex(""), 0)
})

run("the focus letter is always inside the word", () => {
  const words = ["a", "at", "\"a\"", "(x)", "hello,", "end.", "supercalifragilistic"]
  for (const word of words) {
    const index = M.orpIndex(word)
    assert.ok(index >= 0 && index < Math.max(1, word.length), word + " -> " + index)
  }
})

run("long words and sentence ends get more time", () => {
  assert.equal(M.dwellFactor("the"), 1)
  assert.ok(M.dwellFactor("ordinary") > M.dwellFactor("plain"))
  assert.ok(M.dwellFactor("end.") > M.dwellFactor("end"))
  assert.ok(M.dwellFactor("clause,") > M.dwellFactor("clause"))
  assert.ok(M.dwellFactor("end.") > M.dwellFactor("clause,"))
})

run("word delay follows wpm", () => {
  assert.equal(M.wordDelayMs("the", 600), 100)
  assert.equal(M.wordDelayMs("the", 300), 200)
  assert.ok(M.wordDelayMs("the.", 600) > M.wordDelayMs("the", 600))
  assert.ok(M.wordDelayMs("the", 1500) >= 20)
})

run("total time counts every word", () => {
  const words = M.tokenize("one two three four five six")
  assert.equal(M.totalSeconds(words, 600), 1)
  assert.equal(M.totalSeconds([], 600), 0)
  assert.ok(M.totalSeconds(words, 100) > M.totalSeconds(words, 600))
})

run("sentence starts follow terminal punctuation", () => {
  const words = M.tokenize("One two. Three four! Five?")
  assert.deepEqual(M.sentenceStarts(words), [0, 2, 4])
  assert.deepEqual(M.sentenceStarts(M.tokenize("no terminator here")), [0])
  assert.deepEqual(M.sentenceStarts([]), [0])
})

run("quoted sentence ends still count", () => {
  const words = M.tokenize("He said \"go.\" She left.")
  assert.deepEqual(M.sentenceStarts(words), [0, 3])
})

run("back one sentence restarts the current sentence first", () => {
  const words = M.tokenize("One two. Three four! Five six.")
  assert.equal(M.previousSentence(words, 3), 2)
  assert.equal(M.previousSentence(words, 2), 0)
  assert.equal(M.previousSentence(words, 0), 0)
  assert.equal(M.previousSentence(words, 5), 4)
})

run("forward one sentence lands on the next start", () => {
  const words = M.tokenize("One two. Three four! Five six.")
  assert.equal(M.nextSentence(words, 0), 2)
  assert.equal(M.nextSentence(words, 2), 4)
  assert.equal(M.nextSentence(words, 5), words.length - 1)
})

run("progress stays between zero and one", () => {
  assert.equal(M.progress(0, 10), 0)
  assert.equal(M.progress(5, 10), 0.5)
  assert.equal(M.progress(20, 10), 1)
  assert.equal(M.progress(0, 0), 0)
  assert.equal(M.progress(-5, 10), 0)
})

run("readouts describe position and time left", () => {
  const words = M.tokenize("one two three")
  assert.equal(M.positionText(0, words), "1 / 3 words")
  assert.equal(M.positionText(2, words), "3 / 3 words")
  assert.equal(M.positionText(9, words), "3 / 3 words")
  assert.equal(M.positionText(0, []), "nothing loaded")
  assert.equal(M.formatDuration(65), "1:05")
  assert.equal(M.formatDuration(0), "0:00")
  assert.match(M.remainingText(0, words, 600), /left$/)
  assert.equal(M.remainingText(0, [], 600), "")
})

process.stdout.write("\nall Model.js tests passed\n")
