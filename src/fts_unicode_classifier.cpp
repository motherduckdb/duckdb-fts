#include "fts_unicode_classifier.hpp"

#include "duckdb/common/common.hpp"
#include "fts_unicode_data.hpp"

namespace duckdb {

static_assert(static_cast<uint8_t>(FTSUnicodeScript::HAN) ==
                  FTS_UNICODE_SCRIPT_HAN,
              "Unexpected Han script value");
static_assert(static_cast<uint8_t>(FTSUnicodeScript::HIRAGANA) ==
                  FTS_UNICODE_SCRIPT_HIRAGANA,
              "Unexpected Hiragana script value");
static_assert(static_cast<uint8_t>(FTSUnicodeScript::KATAKANA) ==
                  FTS_UNICODE_SCRIPT_KATAKANA,
              "Unexpected Katakana script value");

template <idx_t SIZE>
static uint8_t LookupProperties(int32_t codepoint,
                                const FTSUnicodeRange (&ranges)[SIZE]) {
  if (codepoint < 0) {
    return 0;
  }
  if (codepoint < static_cast<int32_t>(sizeof(FTS_UNICODE_ASCII_PROPERTIES))) {
    return FTS_UNICODE_ASCII_PROPERTIES[codepoint];
  }

  idx_t lower = 0;
  idx_t upper = SIZE;
  while (lower < upper) {
    auto middle = lower + (upper - lower) / 2;
    if (codepoint < ranges[middle].first) {
      upper = middle;
    } else if (codepoint > ranges[middle].last) {
      lower = middle + 1;
    } else {
      return ranges[middle].properties;
    }
  }
  return 0;
}

FTSUnicodeProperties FTSUnicodeClassifier::Classify(int32_t codepoint) {
  auto properties = LookupProperties(codepoint, FTS_UNICODE_RANGES);
  return {static_cast<FTSUnicodeScript>(properties & FTS_UNICODE_SCRIPT_MASK),
          (properties & FTS_UNICODE_ALPHABETIC) != 0,
          (properties & FTS_UNICODE_DECIMAL_NUMBER) != 0,
          (properties & FTS_UNICODE_WHITESPACE) != 0,
          (properties & FTS_UNICODE_PUNCTUATION) != 0,
          (properties & FTS_UNICODE_COMBINING_MARK) != 0,
          (properties & FTS_UNICODE_EMOJI) != 0};
}

} // namespace duckdb
