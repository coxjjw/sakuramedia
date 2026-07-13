#!/usr/bin/env bash
# 全量测试入口。
#
# 不要用裸 `flutter test`：它会把 test/ 下 196 个文件逐个编译并序列化一次完整
# dill（约 0.47s/文件的串行开销，加并发也压不下去），全量要 140s。这里先把这些
# 文件聚合成 12 个 bundle 入口再跑，同样的 1617 个用例约 40s。
#
#   ./scripts/test.sh                  # 全量
#   ./scripts/test.sh --name 'xxx'     # 额外参数透传给 flutter test
#
# 只改一个模块时不必走这里，直接跑那个文件更快：
#   flutter test test/features/movies/presentation/pages/desktop/movie_detail_page_test.dart

set -euo pipefail

cd "$(dirname "$0")/.."

# 每次重新生成（不到 1s）。bundle 不入库，所以不存在「加了 test 文件却忘了重新
# 生成、新测试被静默跳过」这种事。
dart run tool/gen_test_bundles.dart --quiet

# 每个 bundle 一个 worker。
concurrency="$(find test_bundles -name '*_test.dart' | wc -l | tr -d ' ')"

exec flutter test test_bundles -j "$concurrency" "$@"
