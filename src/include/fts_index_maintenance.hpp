#pragma once

#include "fts_index_common.hpp"

#include "duckdb/common/common.hpp"
#include "duckdb/parser/qualified_name.hpp"

namespace duckdb {

struct FTSIndexMaintenanceConfig {
  FTSAnalyzerConfig analyzer;
  bool cluster_terms = false;
  bool layered_search = false;
};

class FTSIndexMaintenance {
public:
  static string DropTriggers(const QualifiedName &qname);
  static string Create(const QualifiedName &qname, const string &input_id,
                       const vector<string> &input_values,
                       const FTSIndexMaintenanceConfig &config);
};

} // namespace duckdb
