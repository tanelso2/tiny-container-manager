import
  ./shell_utils,
  ./docker,
  ./metrics as metrics,
  asyncdispatch,
  httpclient,
  os,
  prometheus as prom,
  sequtils,
  streams,
  strformat,
  strutils,
  sugar,
  yaml/serialization

type
  Container* = object of RootObj
    name*: string
    image*: string
    containerPort*: int
    host*: string

const email = "tanelso2@gmail.com"

proc matches(target: Container, d: DContainer): bool =
  # Names are prefaced by a slash due to docker internals
  # https://github.com/moby/moby/issues/6705
  let nameMatch = d.Names.contains(fmt"/{target.name}")
  let imageMatch = d.Image == target.image

  return nameMatch and imageMatch

proc allHosts(target: Container): seq[string] =
  return @[target.host, fmt"www.{target.host}"]

proc createContainer*(target: Container) {.async.} =
  # TODO: check if running
  let stopCmd = fmt"docker stop {target.name}"
  discard await stopCmd.asyncExec()
  let rmCmd = fmt"docker rm {target.name}"
  discard await rmCmd.asyncExec()
  let pullCmd = fmt"docker pull {target.image}"
  echo pullCmd
  echo await pullCmd.asyncExec()
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo await cmd.asyncExec()
  {.gcsafe.}: metrics.containerStarts.labels(target.name).inc()

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

proc isWebsiteRunning*(target: Container): bool =
  let client = newHttpClient(maxRedirects=0)
  echo fmt"Checking {target.host}"
  let website = target.host
  let httpUrl = fmt"http://{website}"
  let httpsUrl = fmt"https://{website}"
  let httpRet = client.request(httpUrl, httpMethod="GET")
  let httpsRet = client.request(httpsUrl, httpMethod="GET")
  let httpWorks = "301" in httpRet.status
  # httpclient library doesn't check validity of certs right now...
  # I probably need to implement that
  let httpsWorks = "200" in httpsRet.status
  result = httpWorks and httpsWorks
  {.gcsafe.}:
    metrics
      .healthCheckStatus
      .labels(target.host, "http", if result: "success" else: "failure")
      .inc()

proc createNginxConfig(target: Container) {.async.} =
  let port = 80
  let hosts = target.allHosts.join(" ")
  let containerPort = target.localPort
  let x = fmt("""
  server {
    listen 0.0.0.0:80;
    listen [::]:80;

    server_name <hosts>;

    location / {
      proxy_pass http://127.0.0.1:<containerPort>;
    }
  }
  """, '<', '>')
  let filename = fmt"/etc/nginx/sites-available/{target.name}"
  filename.createFile
  writeFile(filename, x)
  let enabledFile = fmt"/etc/nginx/sites-enabled/{target.name}"
  if not enabledFile.symlinkExists:
    createSymlink(filename, enabledFile)
  {.gcsafe.}: metrics.nginxConfigsWritten.labels(target.name).inc()
  await restartNginx()

proc parseContainer*(filename: string): Container =
  {.gcsafe.}:
    var ret: Container
    var s = newFileStream(filename)
    load(s, ret)
    s.close()
    return ret

proc runCertbot(target: Container) {.async.} =
  let allHosts = target.allHosts()
  let hostCmdLine = allHosts.map((x) => fmt"-d {x}").join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {hostCmdLine} --email {email} --agree-tos"
  echo certbotCmd
  echo await certbotCmd.asyncExec()
  {.gcsafe.}: metrics.letsEncryptRuns.labels(target.name).inc()
  # metrics.incLetsEncryptRuns(@[target.name])

proc isNginxConfigCorrect(target: Container): bool =
  echo "TODO IMPL ME"
  return true

let ffHttpRequests = false

proc ensureContainer*(target: Container) {.async.} =
  if not target.isHealthy:
    echo fmt"{target.name} is not healthy, recreating"
    await target.createContainer()
  if ffHttpRequests:
    if not target.isWebsiteRunning:
      await target.createNginxConfig()
      await target.runCertbot()
  else:
    await target.createNginxConfig()
    await target.runCertbot()

