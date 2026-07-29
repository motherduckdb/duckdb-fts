#include "fts_unicode_classifier.hpp"

#include "duckdb/common/common.hpp"
#include "fts_unicode_data.hpp"

namespace duckdb {

template <idx_t SIZE>
static bool InRanges(int32_t codepoint, const FTSUnicodeRange (&ranges)[SIZE]) {
  idx_t lower = 0;
  idx_t upper = SIZE;
  while (lower < upper) {
    auto middle = lower + (upper - lower) / 2;
    if (codepoint < ranges[middle].first) {
      upper = middle;
    } else if (codepoint > ranges[middle].last) {
      lower = middle + 1;
    } else {
      return true;
    }
  }
  return false;
}

static FTSUnicodeScript ClassifyScript(int32_t codepoint) {
  if (InRanges(codepoint, FTS_UNICODE_HAN_RANGES)) {
    return FTSUnicodeScript::HAN;
  }
  if (InRanges(codepoint, FTS_UNICODE_HIRAGANA_RANGES)) {
    return FTSUnicodeScript::HIRAGANA;
  }
  if (InRanges(codepoint, FTS_UNICODE_KATAKANA_RANGES)) {
    return FTSUnicodeScript::KATAKANA;
  }
  return FTSUnicodeScript::OTHER;
}

FTSUnicodeProperties FTSUnicodeClassifier::Classify(int32_t codepoint) {
  return {ClassifyScript(codepoint),
          InRanges(codepoint, FTS_UNICODE_ALPHABETIC_RANGES),
          InRanges(codepoint, FTS_UNICODE_DECIMAL_NUMBER_RANGES),
          InRanges(codepoint, FTS_UNICODE_WHITESPACE_RANGES),
          InRanges(codepoint, FTS_UNICODE_PUNCTUATION_RANGES),
          InRanges(codepoint, FTS_UNICODE_COMBINING_MARK_RANGES),
          InRanges(codepoint, FTS_UNICODE_EMOJI_RANGES)};
}

} // namespace duckdb
