import
    asyncdispatch,
    os,
    std/re,
    std/times,
    strutils,
    strformat,
    sequtils,
    times,
    ./cache,
    ./metrics,
    ./shell_utils,
    nim_utils/logline

proc makeLabeledLineRegex(label: string): string =
    return r"\s*" & label & r":\s+(.*)\s*$"

let labels = @[
    "Certificate Name",
    "Serial Number",
    "Key Type",
    "Domains",
    "Expiry Date",
    "Certificate Path",
    "Private Key Path"
]

proc getFullRegexStr(): string =
    var x = ""
    for l in labels:
        x = x & makeLabeledLineRegex(l)
    return x

proc getRegex(): Regex =
    return rex(getFullRegexStr(), flags = {reStudy, reMultiLine})

let certbotCertRegex* = getRegex()

type
  Cert* = ref object of RootObj
    name*: string
    serial*: string
    keyType*: string
    domains*: seq[string]
    exp*: Expiration
    certPath*: string
    privKeyPath*: string
  Expiration* = ref object of RootObj
    timestamp*: string
    valid*: bool


proc `$`[Cert](x: Cert): string =
  fmt"name:{x.name} serial: {x.serial}"


proc parseExp(s: string): Expiration =
  let x = s.split(" ")
  var valid: bool
  if x[2].contains("INVALID"):
    valid = false
  else:
    valid = true
  return Expiration(timestamp: x[0..1].join(" "), valid: valid)

proc parseDomains(s: string): seq[string] =
  return s.split(" ")

proc parseCert(s: string): Cert =
  var x: array[7, string]
  if match(s, certbotCertRegex, x):
    return Cert(name: x[0],
                serial: x[1],
                keyType: x[2],
                domains: parseDomains(x[3]),
                exp: parseExp(x[4]),
                certPath: x[5],
                privKeyPath: x[6])
  else:
    raise newException(AssertionDefect, "Shit")

proc parseCerts*(s: string): seq[Cert] =
  let certs = s.findAll(certbotCertRegex)
  return certs.mapIt(parseCert(it))

var previousCertbotCertsOutput: seq[Cert] = @[]

proc getAllCertbotCerts*(): Future[seq[Cert]] {.async.} =
  try:
    # TODO?: Maybe read these certs ourselves instead of shelling out to certbot
    logInfo "Running 'certbot certificates'"
    let output = await "certbot certificates".asyncExec()
    result = output.parseCerts()
    previousCertbotCertsOutput = result
    return result
  except IoError:
    let msg = getCurrentExceptionMsg()
    if msg.contains("Another instance of Certbot is already running."):
      logError "Couldn't get certs due to other instance of certbot"
      return previousCertbotCertsOutput
    else:
      raise getCurrentException()

let getAllCertbotCertsCached* = mkTimedCache(getAllCertbotCerts, initDuration(seconds = 5))

proc cleanUpLetsEncryptBackups*() =
  let dir = "/var/lib/letsencrypt/backups"
  let anHourAgo = getTime() - initDuration(hours = 1)
  var filesDeleted = 0
  for (fileType, path) in walkDir(dir):
    # a < b if a happened before b
    if path.getCreationTime() < anHourAgo:
      if fileType == pcFile:
        path.removeFile()
      if fileType == pcDir:
        path.removeDir()
      filesDeleted += 1

  logDebug(fmt"Deleted {filesDeleted} backup files")
  metrics.letsEncryptBackupsDeleted.inc(filesDeleted)
