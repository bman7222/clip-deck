"""Builds the tiny Yomitan test dictionaries in scripts/fixtures/dictionaries/*.zip (checked in).
Run: python -I scripts/make-dictionary-fixtures.py. The data is written for Clip Deck's tests; no Yomitan data or code."""
import json
import pathlib
import zipfile

OUT = pathlib.Path(__file__).resolve().parent / "fixtures" / "dictionaries"


def build(name, files, raw=()):
    with zipfile.ZipFile(OUT / f"{name}.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for path, data in list(files.items()) + list(raw):
            info = zipfile.ZipInfo(path, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            text = data if isinstance(data, str) else json.dumps(data, ensure_ascii=False)
            z.writestr(info, text.encode("utf-8"))


def index(title, revision="1", fmt=3, **extra):
    return {"title": title, "revision": revision, "format": fmt, **extra}


def sc(*lines):  # structured content: a list of senses
    return {"type": "structured-content", "content": [{"tag": "ul", "content": [{"tag": "li", "content": s} for s in lines]}]}


NOTE = "Test data written for Clip Deck"
words_bank_1 = [
    ["こんにちは", "こんにちは", "", "", 10, [sc("hello", "good day")], 1, "P"],
    ["元気", "げんき", "adj-na", "", 8, ["healthy", "energetic"], 2, ""],
    ["です", "です", "", "", 5, ["is", "be"], 3, ""],
    ["また", "また", "", "", 4, ["again", "also"], 4, ""],
]
words_bank_2 = [
    ["食べる", "たべる", "v1", "v1", 9, [sc("to eat")], 5, "P"],
    ["行く", "いく", "v5", "v5", 9, [sc("to go")], 6, "P"],
    ["行く", "ゆく", "v5", "v5", 3, ["to go (literary)"], 7, ""],
    ["高い", "たかい", "adj-i", "adj-i", 7, [sc("high", "expensive")], 8, "P"],
    ["する", "する", "vs", "vs", 6, [sc("to do")], 9, ""],
]
tags = [["v1", "partOfSpeech", -1, "Ichidan verb", 0], ["adj-i", "partOfSpeech", -1, "I-adjective", 0],
        ["P", "popular", -10, "Popular", 5]]

OUT.mkdir(parents=True, exist_ok=True)
build("words-v3", {
    "index.json": index("Clip Test Words", "2026.1", attribution=NOTE, author="Clip Deck", url="https://example.com/test"),
    "term_bank_1.json": words_bank_1, "term_bank_2.json": words_bank_2, "tag_bank_1.json": tags,
    "kanji_bank_1.json": [["日", "ニチ", "", "", ["sun"], {}]],
})
build("words-second", {
    "index.json": index("Second Test Words", "1"),
    "term_bank_1.json": [["食べる", "たべる", "v1", "v1", 1, ["to eat (second dictionary)"], 1, ""],
                         ["猫", "ねこ", "n", "", 1, ["cat"], 2, ""]],
})
build("frequency", {
    "index.json": index("Test Frequency", "1", frequencyMode="rank-based"),
    "term_meta_bank_1.json": [
        ["食べる", "freq", 120], ["行く", "freq", {"value": 340, "displayValue": "340"}],
        ["高い", "freq", {"reading": "たかい", "frequency": 55}], ["する", "freq", "12"],
        ["食べる", "pitch", {"reading": "たべる", "pitches": [{"position": 2}]}],
    ],
})
build("popup-frequency", {  # 元気 has no frequency in "frequency"; the popup tests (-uiTestingLookup) need a badge for it
    "index.json": index("Popup Frequency", "1", frequencyMode="rank-based"),
    "term_meta_bank_1.json": [["元気", "freq", {"value": 1234, "displayValue": "1,234"}]],
})
build("legacy-v1", {
    "index.json": index("Legacy Words", "1", fmt=1),
    "term_bank_1.json": [["犬", "いぬ", "n", "", 0, "dog", "hound"], ["猫", "ねこ", "n", "", 0, "cat"]],
})
build("lookup-words", {
    "index.json": index("Lookup Words", "1"),
    "term_bank_1.json": [["元", "もと", "n", "", 1, ["origin"], 1, ""], ["足", "あし", "n", "", 5, ["foot"], 2, ""],
                         ["脚", "あし", "n", "", 5, ["leg"], 3, ""]],
})
build("frequency-rank", {
    "index.json": index("Rank Frequency", "1", frequencyMode="rank-based"),
    "term_meta_bank_1.json": [["足", "freq", 10], ["脚", "freq", {"value": 20, "displayValue": "20 (rare)"}]],
})
build("frequency-occurrence", {
    "index.json": index("Occurrence Frequency", "1", frequencyMode="occurrence-based"),
    "term_meta_bank_1.json": [["足", "freq", 5], ["脚", "freq", 50]],
})
build("no-index", {"term_bank_1.json": words_bank_1})
build("format-9", {"index.json": index("Future Words", "1", fmt=9), "term_bank_1.json": words_bank_1})
build("bad-bank", {"index.json": index("Bad Bank", "1"), "term_bank_1.json": words_bank_1},
      raw=[("term_bank_2.json", "[[\"x\", ")])
good = (OUT / "words-v3.zip").read_bytes()
(OUT / "corrupt.zip").write_bytes(good[: len(good) // 2])  # the central directory is at the end, so this can't open
