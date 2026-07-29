#pragma once

#include <cstdint>

namespace duckdb {

enum class FTSUnicodeScript : uint8_t { OTHER, HAN, HIRAGANA, KATAKANA };

struct FTSUnicodeProperties {
  FTSUnicodeScript script;
  bool alphabetic;
  bool decimal_number;
  bool whitespace;
  bool punctuation;
  bool combining_mark;
  bool emoji;
};

class FTSUnicodeClassifier {
public:
  static FTSUnicodeProperties Classify(int32_t codepoint);
};

} // namespace duckdb
