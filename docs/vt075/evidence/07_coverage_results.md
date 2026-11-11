suite: [SUMMARY] VT-075 TESTS: 24 PASSED | 0 FAILED (exit=0)
filter: all tests
line coverage: 158/164 = 96.3%
arm (branch) coverage: 58/64 = 90.6%
approx arms (false-arm of an if whose body does not end in return/continue/break): 2
UNCOVERED line 47: return true
UNCOVERED line 169: return _result(ERR_PERSIST_FAILED)
UNCOVERED line 183: return _result(ERR_INVALID_INPUT)
UNCOVERED line 186: return _result(ERR_NOT_FOUND)
UNCOVERED line 190: return _result(ERR_PERSIST_FAILED)
UNCOVERED line 209: return _result(ERR_PERSIST_FAILED)
UNCOVERED arm true of line 46: if not persist_hook.is_valid():
UNCOVERED arm true of line 168: if not _persist():
UNCOVERED arm true of line 182: if not _valid_id(record_id):
UNCOVERED arm true of line 185: if rec.is_empty():
UNCOVERED arm true of line 189: if not _persist():
UNCOVERED arm true of line 208: if not _persist():
