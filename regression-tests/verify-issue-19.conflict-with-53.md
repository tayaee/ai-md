# verify-issue-19 vs issue-53

`verify-issue-19.sh` check #2 asserted `list_specs` filters names via
`.endswith(".ai.md")`. issue-53 (nested `.ai.md` directory support) rewrote
`list_specs` to recurse with `src_dir.rglob("*.ai.md")` instead of a flat
`iterdir()` + `endswith()` scan, so it can find specs under subdirectories
(e.g. `src/app/tetris.ai.md`) and return them as POSIX-relative paths
(`"app/tetris.ai.md"`). The glob pattern itself now does the `.ai.md`
filtering, so the literal `endswith(".ai.md")` string is gone from the
source.

`verify-issue-19.sh` was updated to accept either form
(`endswith\(".ai.md"\)|rglob\("\*.ai.md"\)`) so both the original
(issue-19) and current (issue-53) implementations satisfy the check. No
functional regression: `test_list_specs` still asserts a sorted, filtered
list of `*.ai.md` names, extended to include nested-directory ones (see
`engine/tests/test_artifacts.py`).
