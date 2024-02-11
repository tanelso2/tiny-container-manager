import 
  tiny_container_manager/[
    cache
  ],
  std/times,
  unittest

var a = 0
proc test(): int =
  a = a + 1
  return 50

let cachedFunc = mkTimedCache(test, initDuration(days = 1))

check cachedFunc() == 50
check cachedFunc() == 50
check a == 1
