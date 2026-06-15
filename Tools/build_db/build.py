#!/usr/bin/env python3
"""Build bible.sqlite (개역개정 / NKRV) from source/nkrv.json.

Output schema:
  books(id INTEGER PK, abbr TEXT, name TEXT, testament TEXT, aliases TEXT, sort INTEGER)
  verses(id INTEGER PK, book_id INTEGER, chapter INTEGER, verse INTEGER, text TEXT)

The FTS5 full-text index is NOT built here. It is created at first run by the
app (in the writable copy) so the tokenizer always matches the runtime SQLite.
"""
import json
import os
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "source", "nkrv.json")
OUT = os.path.join(HERE, "..", "..", "Sources", "biblego", "Resources", "bible.sqlite")

# id, abbr (matches the abbreviation used in nkrv.json), full name, testament, aliases
BOOKS = [
    (1,  "창",   "창세기",       "OT", "창세 Gen Genesis"),
    (2,  "출",   "출애굽기",     "OT", "출애 출애굽 Exo Exodus"),
    (3,  "레",   "레위기",       "OT", "레위 Lev Leviticus"),
    (4,  "민",   "민수기",       "OT", "민수 Num Numbers"),
    (5,  "신",   "신명기",       "OT", "신명 Deu Deuteronomy"),
    (6,  "수",   "여호수아",     "OT", "여호수아 수아 Jos Joshua"),
    (7,  "삿",   "사사기",       "OT", "사사 Jdg Judges"),
    (8,  "룻",   "룻기",         "OT", "룻 Rut Ruth"),
    (9,  "삼상", "사무엘상",     "OT", "사무엘상 삼상 1Sam 1Samuel"),
    (10, "삼하", "사무엘하",     "OT", "사무엘하 삼하 2Sam 2Samuel"),
    (11, "왕상", "열왕기상",     "OT", "열왕기상 왕상 1Kgs 1Kings"),
    (12, "왕하", "열왕기하",     "OT", "열왕기하 왕하 2Kgs 2Kings"),
    (13, "대상", "역대상",       "OT", "역대상 대상 1Chr 1Chronicles"),
    (14, "대하", "역대하",       "OT", "역대하 대하 2Chr 2Chronicles"),
    (15, "스",   "에스라",       "OT", "에스라 Ezr Ezra"),
    (16, "느",   "느헤미야",     "OT", "느헤미야 Neh Nehemiah"),
    (17, "에",   "에스더",       "OT", "에스더 Est Esther"),
    (18, "욥",   "욥기",         "OT", "욥 Job"),
    (19, "시",   "시편",         "OT", "시편 Psa Psalm Psalms"),
    (20, "잠",   "잠언",         "OT", "잠언 Pro Proverbs"),
    (21, "전",   "전도서",       "OT", "전도 Ecc Ecclesiastes"),
    (22, "아",   "아가",         "OT", "아가 Sng Song"),
    (23, "사",   "이사야",       "OT", "이사야 Isa Isaiah"),
    (24, "렘",   "예레미야",     "OT", "예레미야 Jer Jeremiah"),
    (25, "애",   "예레미야애가", "OT", "애가 예레미야애가 Lam Lamentations"),
    (26, "겔",   "에스겔",       "OT", "에스겔 Ezk Ezekiel"),
    (27, "단",   "다니엘",       "OT", "다니엘 Dan Daniel"),
    (28, "호",   "호세아",       "OT", "호세아 Hos Hosea"),
    (29, "욜",   "요엘",         "OT", "요엘 Jol Joel"),
    (30, "암",   "아모스",       "OT", "아모스 Amo Amos"),
    (31, "옵",   "오바댜",       "OT", "오바댜 Oba Obadiah"),
    (32, "욘",   "요나",         "OT", "요나 Jon Jonah"),
    (33, "미",   "미가",         "OT", "미가 Mic Micah"),
    (34, "나",   "나훔",         "OT", "나훔 Nam Nahum"),
    (35, "합",   "하박국",       "OT", "하박국 Hab Habakkuk"),
    (36, "습",   "스바냐",       "OT", "스바냐 Zep Zephaniah"),
    (37, "학",   "학개",         "OT", "학개 Hag Haggai"),
    (38, "슥",   "스가랴",       "OT", "스가랴 Zec Zechariah"),
    (39, "말",   "말라기",       "OT", "말라기 Mal Malachi"),
    (40, "마",   "마태복음",     "NT", "마태 마태복음 Mat Matthew"),
    (41, "막",   "마가복음",     "NT", "마가 마가복음 Mrk Mark"),
    (42, "눅",   "누가복음",     "NT", "누가 누가복음 Luk Luke"),
    (43, "요",   "요한복음",     "NT", "요한 요한복음 Jhn John"),
    (44, "행",   "사도행전",     "NT", "사도 사도행전 행전 Act Acts"),
    (45, "롬",   "로마서",       "NT", "로마 로마서 Rom Romans"),
    (46, "고전", "고린도전서",   "NT", "고린도전서 고전 1Cor 1Corinthians"),
    (47, "고후", "고린도후서",   "NT", "고린도후서 고후 2Cor 2Corinthians"),
    (48, "갈",   "갈라디아서",   "NT", "갈라디아 갈라디아서 Gal Galatians"),
    (49, "엡",   "에베소서",     "NT", "에베소 에베소서 Eph Ephesians"),
    (50, "빌",   "빌립보서",     "NT", "빌립보 빌립보서 Php Philippians"),
    (51, "골",   "골로새서",     "NT", "골로새 골로새서 Col Colossians"),
    (52, "살전", "데살로니가전서","NT", "데살로니가전서 살전 1Th 1Thessalonians"),
    (53, "살후", "데살로니가후서","NT", "데살로니가후서 살후 2Th 2Thessalonians"),
    (54, "딤전", "디모데전서",   "NT", "디모데전서 딤전 1Tim 1Timothy"),
    (55, "딤후", "디모데후서",   "NT", "디모데후서 딤후 2Tim 2Timothy"),
    (56, "딛",   "디도서",       "NT", "디도 디도서 Tit Titus"),
    (57, "몬",   "빌레몬서",     "NT", "빌레몬 빌레몬서 Phm Philemon"),
    (58, "히",   "히브리서",     "NT", "히브리 히브리서 Heb Hebrews"),
    (59, "약",   "야고보서",     "NT", "야고보 야고보서 Jas James"),
    (60, "벧전", "베드로전서",   "NT", "베드로전서 벧전 1Pet 1Peter"),
    (61, "벧후", "베드로후서",   "NT", "베드로후서 벧후 2Pet 2Peter"),
    (62, "요일", "요한일서",     "NT", "요한일서 요일 1Jn 1John"),
    (63, "요이", "요한이서",     "NT", "요한이서 요이 2Jn 2John"),
    (64, "요삼", "요한삼서",     "NT", "요한삼서 요삼 3Jn 3John"),
    (65, "유",   "유다서",       "NT", "유다 유다서 Jud Jude"),
    (66, "계",   "요한계시록",   "NT", "요한계시록 계시록 요계 Rev Revelation"),
]


def main():
    if not os.path.exists(SRC):
        sys.exit(f"source not found: {SRC}\nDownload bible_structured.json -> {SRC}")
    data = json.load(open(SRC, encoding="utf-8"))

    abbr_to_id = {b[1]: b[0] for b in BOOKS}

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.executescript(
        """
        PRAGMA journal_mode = DELETE;
        CREATE TABLE books (
            id INTEGER PRIMARY KEY,
            abbr TEXT NOT NULL,
            name TEXT NOT NULL,
            testament TEXT NOT NULL,
            aliases TEXT NOT NULL,
            sort INTEGER NOT NULL
        );
        CREATE TABLE verses (
            id INTEGER PRIMARY KEY,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL
        );
        """
    )
    db.executemany(
        "INSERT INTO books (id, abbr, name, testament, aliases, sort) VALUES (?,?,?,?,?,?)",
        [(b[0], b[1], b[2], b[3], b[4], b[0]) for b in BOOKS],
    )

    rows = []
    vid = 0
    missing = set()
    for r in data:
        bid = abbr_to_id.get(r["book"])
        if bid is None:
            missing.add(r["book"])
            continue
        vid += 1
        rows.append((vid, bid, int(r["chapter"]), int(r["verse"]), r["content"].strip()))
    if missing:
        sys.exit(f"unknown book abbreviations in source: {sorted(missing)}")

    db.executemany(
        "INSERT INTO verses (id, book_id, chapter, verse, text) VALUES (?,?,?,?,?)", rows
    )
    db.execute("CREATE INDEX idx_verses_ref ON verses(book_id, chapter, verse)")
    db.commit()

    n = db.execute("SELECT COUNT(*) FROM verses").fetchone()[0]
    nb = db.execute("SELECT COUNT(*) FROM books").fetchone()[0]
    sample = db.execute(
        "SELECT b.name, v.chapter, v.verse, v.text FROM verses v "
        "JOIN books b ON b.id=v.book_id WHERE b.abbr='요' AND v.chapter=3 AND v.verse=16"
    ).fetchone()
    db.close()
    print(f"wrote {OUT}")
    print(f"books={nb} verses={n}")
    print(f"sample 요 3:16 -> {sample}")


if __name__ == "__main__":
    main()
