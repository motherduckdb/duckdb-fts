#!/usr/bin/env python3

import argparse
from pathlib import Path

DEFAULT_UNICODE_VERSION = "17.0.0"

SCRIPT_MASK = 0x03
SCRIPT_HAN = 0x01
SCRIPT_HIRAGANA = 0x02
SCRIPT_KATAKANA = 0x03
ALPHABETIC = 0x04
DECIMAL_NUMBER = 0x08
WHITESPACE = 0x10
PUNCTUATION = 0x20
COMBINING_MARK = 0x40
EMOJI = 0x80


def validate_unicode_version(path, version):
    short_version = ".".join(version.split(".")[:2])
    header = "\n".join(path.read_text(encoding="utf-8").splitlines()[:10])
    if short_version not in header:
        raise ValueError(f"{path} does not contain Unicode {version} data")


def parse_properties(path):
    properties = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        codepoints, property_name = [part.strip() for part in line.split(";", 1)]
        if ".." in codepoints:
            first, last = codepoints.split("..", 1)
        else:
            first = last = codepoints
        properties.setdefault(property_name, []).append((int(first, 16), int(last, 16)))
    return properties


def merge_ranges(ranges):
    result = []
    for first, last in sorted(ranges):
        if result and first <= result[-1][1] + 1:
            result[-1] = (result[-1][0], max(result[-1][1], last))
        else:
            result.append((first, last))
    return result


def combine(properties, names):
    return merge_ranges([item for name in names for item in properties[name]])


def append_range(ranges, first, last, property_mask):
    if ranges and first == ranges[-1][1] + 1 and property_mask == ranges[-1][2]:
        ranges[-1] = (ranges[-1][0], last, property_mask)
    else:
        ranges.append((first, last, property_mask))


def combine_properties(property_ranges):
    events = {}
    for property_mask, ranges in property_ranges:
        for first, last in merge_ranges(ranges):
            events.setdefault(first, []).append(property_mask)
            if last < 0x10FFFF:
                events.setdefault(last + 1, []).append(property_mask)

    ranges = []
    current_mask = 0
    previous = 0
    for codepoint in sorted(events):
        if previous < codepoint and current_mask:
            append_range(ranges, previous, codepoint - 1, current_mask)
        for property_mask in events[codepoint]:
            current_mask ^= property_mask
        previous = codepoint
    if current_mask:
        append_range(ranges, previous, 0x10FFFF, current_mask)
    return ranges


def split_ascii(ranges):
    ascii_properties = [0] * 128
    non_ascii_ranges = []
    for first, last, property_mask in ranges:
        for codepoint in range(first, min(last, 127) + 1):
            ascii_properties[codepoint] = property_mask
        if last >= 128:
            append_range(non_ascii_ranges, max(first, 128), last, property_mask)
    return ascii_properties, non_ascii_ranges


def render_ascii_table(properties):
    lines = ["static constexpr uint8_t FTS_UNICODE_ASCII_PROPERTIES[] = {"]
    for offset in range(0, len(properties), 16):
        values = ", ".join(
            f"0x{value:02X}" for value in properties[offset : offset + 16]
        )
        lines.append(f"    {values},")
    lines.append("};")
    return "\n".join(lines)


def render_range_table(ranges):
    lines = ["static constexpr FTSUnicodeRange FTS_UNICODE_RANGES[] = {"]
    lines.extend(
        f"    {{0x{first:06X}, 0x{last:06X}, 0x{property_mask:02X}}},"
        for first, last, property_mask in ranges
    )
    lines.append("};")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate FTS Unicode property tables")
    parser.add_argument(
        "--unicode-version",
        default=DEFAULT_UNICODE_VERSION,
        help="Unicode version recorded in the generated header",
    )
    parser.add_argument("ucd_dir", type=Path, help="Unicode Character Database root")
    parser.add_argument("output", type=Path, help="Generated C++ header")
    args = parser.parse_args()

    scripts_path = args.ucd_dir / "Scripts.txt"
    derived_core_path = args.ucd_dir / "DerivedCoreProperties.txt"
    property_list_path = args.ucd_dir / "PropList.txt"
    emoji_path = args.ucd_dir / "emoji" / "emoji-data.txt"
    categories_path = args.ucd_dir / "extracted" / "DerivedGeneralCategory.txt"
    for path in [
        scripts_path,
        derived_core_path,
        property_list_path,
        emoji_path,
        categories_path,
    ]:
        validate_unicode_version(path, args.unicode_version)

    scripts = parse_properties(scripts_path)
    derived_core = parse_properties(derived_core_path)
    property_list = parse_properties(property_list_path)
    emoji = parse_properties(emoji_path)
    categories = parse_properties(categories_path)

    ranges = combine_properties(
        [
            (SCRIPT_HAN, scripts["Han"]),
            (SCRIPT_HIRAGANA, scripts["Hiragana"]),
            (SCRIPT_KATAKANA, scripts["Katakana"]),
            (ALPHABETIC, derived_core["Alphabetic"]),
            (DECIMAL_NUMBER, categories["Nd"]),
            (WHITESPACE, property_list["White_Space"]),
            (
                PUNCTUATION,
                combine(categories, ["Pc", "Pd", "Pe", "Pf", "Pi", "Po", "Ps"]),
            ),
            (COMBINING_MARK, combine(categories, ["Mc", "Me", "Mn"])),
            (EMOJI, combine(emoji, ["Emoji_Presentation", "Extended_Pictographic"])),
        ]
    )
    ascii_properties, non_ascii_ranges = split_ascii(ranges)

    content = "\n".join(
        [
            f"// Generated by scripts/generate_unicode_tables.py from Unicode {args.unicode_version}.",
            "// See https://www.unicode.org/terms_of_use.html.",
            "#pragma once",
            "",
            "#include <cstdint>",
            "",
            "// clang-format off",
            "",
            "namespace duckdb {",
            "",
            "struct FTSUnicodeRange {",
            "  int32_t first;",
            "  int32_t last;",
            "  uint8_t properties;",
            "};",
            "",
            f"static constexpr uint8_t FTS_UNICODE_SCRIPT_MASK = 0x{SCRIPT_MASK:02X};",
            f"static constexpr uint8_t FTS_UNICODE_SCRIPT_HAN = 0x{SCRIPT_HAN:02X};",
            f"static constexpr uint8_t FTS_UNICODE_SCRIPT_HIRAGANA = 0x{SCRIPT_HIRAGANA:02X};",
            f"static constexpr uint8_t FTS_UNICODE_SCRIPT_KATAKANA = 0x{SCRIPT_KATAKANA:02X};",
            f"static constexpr uint8_t FTS_UNICODE_ALPHABETIC = 0x{ALPHABETIC:02X};",
            f"static constexpr uint8_t FTS_UNICODE_DECIMAL_NUMBER = 0x{DECIMAL_NUMBER:02X};",
            f"static constexpr uint8_t FTS_UNICODE_WHITESPACE = 0x{WHITESPACE:02X};",
            f"static constexpr uint8_t FTS_UNICODE_PUNCTUATION = 0x{PUNCTUATION:02X};",
            f"static constexpr uint8_t FTS_UNICODE_COMBINING_MARK = 0x{COMBINING_MARK:02X};",
            f"static constexpr uint8_t FTS_UNICODE_EMOJI = 0x{EMOJI:02X};",
            "",
            render_ascii_table(ascii_properties),
            "",
            render_range_table(non_ascii_ranges),
            "",
            "} // namespace duckdb",
            "",
            "// clang-format on",
            "",
        ]
    )
    args.output.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
