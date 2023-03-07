import
  asyncdispatch,
  strformat,
  sugar,
  nim_utils/logline

proc pollAll*() =
  while true:
    try:
      poll()
    except ValueError:
      break

type
  AsyncCallback* = (() {.async.} -> Future[void])

proc asyncLoop*(cb: AsyncCallback, sleepSeconds: Natural) {.async.} =
  while true:
    try:
      await cb()
    except:
      let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
      logError fmt"Got exception {repr(e)} with message {msg}"
    await sleepAsync(sleepSeconds * 1000)