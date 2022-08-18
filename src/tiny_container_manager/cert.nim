import
    std/re,
    strutils,
    strformat,
    sequtils,
    ./shell_utils

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

proc getAllCertbotCerts*(): seq[Cert] =
  let output = "sudo certbot certificates".simpleExec()
  return output.parseCerts()
