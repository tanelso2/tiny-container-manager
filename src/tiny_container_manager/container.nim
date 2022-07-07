import
  ./cert,
  ./shell_utils,
  ./docker,
  ./metrics,
  ./log,
  asyncdispatch,
  httpclient,
  os,
  prometheus as prom,
  sequtils,
  std/options,
  streams,
  strformat,
  strutils,
  sugar,
  yaml/serialization

# TODO: Figure out difference between object and ref object.
# I have read the docs before and I still don't get it
type
  ContainerSpec* = ref object of RootObj
    name*: string
    image*: string
    containerPort*: int
    host*: string
  Container* = ref object of ContainerSpec
    nginxBase*: string

const defaultNginxBase = "/etc/nginx"

proc newContainer*(spec: ContainerSpec, nginxBase: string = defaultNginxBase): Container =
  return Container(name: spec.name,
                   image: spec.image,
                   containerPort: spec.containerPort,
                   host: spec.host,
                   nginxBase: nginxBase)

proc nginxBaseOrDefault*(target: Container): string =
  if target.nginxBase == "":
    raise newException(IOError, "Blank nginx base not allowed")
  else:
    target.nginxBase

const email = "tanelso2@gmail.com"

proc matches(target: Container, d: DContainer): bool =
  # Names are prefaced by a slash due to docker internals
  # https://github.com/moby/moby/issues/6705
  let nameMatch = d.Names.contains(fmt"/{target.name}")
  let imageMatch = d.Image == target.image

  return nameMatch and imageMatch

proc allHosts(target: Container): seq[string] =
  return @[target.host, fmt"www.{target.host}"]

proc tryStopContainer*(target: Container) {.async.} =
  try:
    let stopCmd = fmt"docker stop {target.name}"
    discard await stopCmd.asyncExec()
  except:
    discard # TODO: Only discard if failed because container didn't exist

proc tryRemoveContainer*(target: Container) {.async.} =
  try:
    let rmCmd = fmt"docker rm {target.name}"
    discard await rmCmd.asyncExec()
  except:
    discard


proc createContainer*(target: Container) {.async.} =
  await target.tryStopContainer()
  await target.tryRemoveContainer()
  let pullCmd = fmt"docker pull {target.image}"
  echo pullCmd
  echo await pullCmd.asyncExec()
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo await cmd.asyncExec()
  {.gcsafe.}: metrics.containerStarts.labels(target.name).inc()

proc certMatches(target: Container, cert: Cert): bool =
  let domains = cert.domains
  let host = target.host
  return domains.anyIt(it == host)

proc getInstalledCert(target: Container): Option[Cert] =
  let certs = getAllCertbotCerts()
  let matches = certs.filterIt(certMatches(target, it))
  if len(matches) < 1:
    return none(Cert)
  else:
    return some(matches[0])

proc getRunningContainer(target: Container): DContainer =
  let containers = getContainers()
  return containers.filterIt(target.matches(it))[0]

proc localPort*(target: Container): int =
  let c = target.getRunningContainer()
  return c.Ports[0].PublicPort

proc isHealthy*(target: Container): bool =
  let containers = getContainers()
  var found = false
  for c in containers:
    if target.matches(c):
      found = true
  result = found
  {.gcsafe.}:
    metrics
      .healthCheckStatus
      .labels(target.host, "docker", if result: "success" else: "failure")
      .inc()

# let client = newHttpClient(maxRedirects=0)
#

proc isWebsiteRunning*(target: Container): bool =
  try:
    let client = newHttpClient(maxRedirects=0)
    logInfo(fmt"Checking {target.host}")
    let website = target.host
    let httpUrl = fmt"http://{website}"
    let httpsUrl = fmt"https://{website}"
    let httpRet = client.request(httpUrl, httpMethod="GET")
    # This check seems to throw exceptions every once in a while because of cert errors...
    # So while httpclient library says it doesn't check validity, it seems to be attempting to...
    let httpsRet = client.request(httpsUrl, httpMethod="GET")
    let httpWorks = "301" in httpRet.status
    let httpsWorks = "200" in httpsRet.status
    result = httpWorks and httpsWorks
  except:
    logError(getCurrentExceptionMsg())
    result = false
  finally:
    {.gcsafe.}:
      metrics
        .healthCheckStatus
        .labels(target.host, "http", if result: "success" else: "failure")
        .inc()

proc simpleNginxConfig*(target: Container): string =
  let port = 80
  let hosts = target.allHosts.join(" ")
  let containerPort = target.localPort
  let x = fmt("""
  server {
    listen <port>;
    listen [::]:<port>;

    server_name <hosts>;

    location / {
      proxy_pass http://127.0.0.1:<containerPort>;
      proxy_set_header Host $host;
    }
  }
  """, '<', '>')
  return x

proc makeHttpRedirectBlock(host: string): string =
  let x = fmt("""
    if ($host = <host>) {
      return 301 https://$host$request_uri;
    }
  """, '<', '>')
  return x.strip()

proc nginxConfigWithCert(target: Container, cert: Cert): string =
  let allHosts = target.allHosts
  let httpRedirectBlocks = allHosts.mapIt(makeHttpRedirectBlock(it)).join("\n\n")
  let hosts = allHosts.join(" ")
  let containerPort = target.localPort
  let certPath = cert.certPath
  let privKeyPath = cert.privKeyPath
  let x = fmt("""
  server {
    listen 80;
    listen [::]:80;

    <httpRedirectBlocks>

    server_name <hosts>;
    return 404;
  }
  server {
    server_name <hosts>;
    location / {
      proxy_pass http://127.0.0.1:<containerPort>;
      proxy_set_header Host $host;
    }

    listen 443 ssl;
    ssl_certificate <certPath>;
    ssl_certificate_key <privKeyPath>;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
  }
  """, '<', '>')
  return x

proc nginxConfigFile(target: Container): string =
  let base = target.nginxBaseOrDefault()
  fmt"{base}/sites-available/{target.name}"

proc nginxEnabledFile(target: Container): string =
  let base = target.nginxBaseOrDefault()
  fmt"{base}/sites-enabled/{target.name}"

proc enableInNginx(target: Container) =
  assert target.nginxConfigFile.fileExists
  if not target.nginxEnabledFile.symLinkExists:
    createSymlink(target.nginxConfigFile, target.nginxEnabledFile)

proc disableInNginx(target: Container) =
  target.nginxEnabledFile.removeFile()

proc isEnabledInNginx(target: Container): bool =
  target.nginxConfigFile.fileExists and target.nginxEnabledFile.symLinkExists


proc createNginxConfig*(target: Container) {.async.} =
  let x = target.simpleNginxConfig()
  let filename = target.nginxConfigFile()
  filename.createFile
  writeFile(filename, x)
  let enabledFile = target.nginxEnabledFile()
  if not enabledFile.symlinkExists:
    createSymlink(filename, enabledFile)
  {.gcsafe.}: metrics.nginxConfigsWritten.labels(target.name).inc()

proc createSimpleNginxConfig(target: Container) {.async.} =
  let x = target.simpleNginxConfig()
  let filename = target.nginxConfigFile
  if filename.fileExists:
    filename.removeFile()
  filename.createFile
  filename.writeFile(x)
  target.enableInNginx()

proc createHttpsNginxConfig(target: Container) {.async.} =
  if target.isEnabledInNginx:
    target.disableInNginx()
  let maybeCert = target.getInstalledCert()
  assert maybeCert.isSome
  let cert = maybeCert.get()
  let x = target.nginxConfigWithCert(cert)
  let filename = target.nginxConfigFile
  if filename.fileExists:
    filename.removeFile()
  filename.createFile
  filename.writeFile(x)
  target.enableInNginx()

proc parseContainer*(filename: string): Container =
  {.gcsafe.}:
    var spec: ContainerSpec
    var s = newFileStream(filename)
    load(s, spec)
    s.close()
    return newContainer(spec)

proc runCertbot(target: Container) {.async.} =
  let allHosts = target.allHosts()
  let hostCmdLine = allHosts.map((x) => fmt"-d {x}").join(" ")
  let certbotCmd = fmt"certbot certonly --nginx -n --keep {hostCmdLine} --email {email} --agree-tos"
  echo certbotCmd
  echo await certbotCmd.asyncExec()
  {.gcsafe.}: metrics.letsEncryptRuns.labels(target.name).inc()
  # metrics.incLetsEncryptRuns(@[target.name])
  #
proc isCertValid*(target: Container): bool =
  let x = target.getInstalledCert()
  return x.isSome and x.get().exp.valid

proc isNginxConfigCorrect*(target: Container): bool =
  var expectedContents: string
  if target.isCertValid():
    expectedContents = nginxConfigWithCert(target, target.getInstalledCert.get())
  else:
    expectedContents = target.simpleNginxConfig()
  let actualContents = readFile(target.nginxConfigFile())
  return expectedContents == actualContents

proc isNginxConfigHttps*(target: Container): bool =
  let expectedContents = nginxConfigWithCert(target, target.getInstalledCert.get())
  let actualContents = readFile(target.nginxConfigFile())
  return expectedContents == actualContents

proc lookupDns(host: string): string =
  fmt"dig {host} +short".simpleExec()

proc lookupDns(target: Container): string =
  target.host.lookupDns()


# Set to false, trying to figure out what
# causes isWebsiteRunning() to randomly fail
let ffHttpRequests = false

proc ensureContainer*(target: Container) {.async.} =
  discard target.isWebsiteRunning()
  if not target.isHealthy:
    logInfo(fmt"{target.name} is not healthy, recreating")
    await target.createContainer()
  if not target.isCertValid():
    logInfo(fmt"{target.name} does not have a valid cert, trying to fetch")
    await target.createSimpleNginxConfig()
    await target.runCertbot()
  else:
    if not target.isNginxConfigHttps():
      logInfo(fmt"{target.name} creating nginx config")
      await target.createHttpsNginxConfig()
      if checkNginxService():
        await reloadNginx()
      else:
        await restartNginx()
    else:
      logInfo(fmt"{target.name} seemed like it was fine, doing nothing")
  # if ffHttpRequests:
  #   if not target.isWebsiteRunning:
  #     await target.createNginxConfig()
  #     await target.runCertbot()
  # else:
  #   if not target.isCertValid():
  #     await target.createNginxConfig()
  #     await target.runCertbot()
  #     await reloadNginx()
