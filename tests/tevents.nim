import
  asyncdispatch,
  strformat,
  sugar,
  unittest,
  tiny_container_manager/async_utils,
  tiny_container_manager/events,
  nim_utils/logline

var x = 0

var em = newManager()

proc handleCheck(e: Event) {.async.} =
  assertEvent e, evRunCheck
  logInfo "running a check"
  x += 1

em.registerHandler(evRunCheck, handleCheck)

asyncCheck em.triggerEvent(Event(kind: evRunCheck))
pollAll()
check x == 1

em = newManager()

var y = 0
var callOrder: seq[int] = @[]

for i in countdown(10, 0):
  capture i:
    proc f(e: Event) {.async.} =
      assertEvent e, evRunCheck
      let time = i * 10
      logInfo fmt"Waiting for {time} ms"
      await sleepAsync(time)
      logInfo fmt"Thread {i} waking up"
      y += 1
      {.gcsafe.}:
        # This should be safe because processing in async
        # event loop, which is not parallel
        callOrder.add(i)
    em.registerHandler(evRunCheck, f)

block checkOtherEventKind:
  asyncCheck em.triggerEvent(Event(kind: evTest))
  pollAll()
  # Nothing should have ran
  check y == 0

asyncCheck em.triggerEvent(Event(kind: evRunCheck))
pollAll()
check y == 11

let pos0 = callOrder.find(0)
let pos10 = callOrder.find(10)

check pos0 != -1
check pos10 != -1

# function `0` should have woken up before function `10`
logDebug fmt"{pos0=} {pos10=}"
check pos0 < pos10
