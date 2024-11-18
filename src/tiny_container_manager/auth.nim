import
  jester,
  options,
  os,
  strformat,
  strutils,
  ./config,
  nim_utils/logline

proc getKeys*(dir: string = config.keysDir()): seq[string] =
  result = newSeq[string]()
  for (_, path) in walkDir(dir):
    let user = path.extractFilename()
    let secret = path.readFile().strip()
    let key = fmt"{user}:{secret}"
    result.add(key)

proc authHeader*(r: jester.request.Request): Option[string] =
  let h = "Authorization"
  if r.headers.hasKey(h):
    let val = r.headers[h,0]
    return some(val)
  else:
    return none(string)

proc isAuthHeaderValid*(r: jester.request.Request): bool =
  let maybeAuthHeader = r.authHeader()
  if maybeAuthHeader.isNone():
    return false
  let authHeader = maybeAuthHeader.get()
  for k in getKeys():
    if authHeader == fmt"Basic {k}":
      logDebug "login success"
      return true
  return false

template authRequired*(body: untyped) =
  if not request.isAuthHeaderValid():
    resp Http401, "Unauthorized", contentType = "text/plain"
  body
