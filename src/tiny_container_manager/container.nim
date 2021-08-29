import
  ./shell_utils,
  ./docker,
  os,
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

let email = "tanelso2@gmail.com"

proc matches(target: Container, d: DContainer): bool =
  # Names are prefaced by a slash due to docker internals
  # https://github.com/moby/moby/issues/6705
  let nameMatch = d.Names.contains(fmt"/{target.name}")
  let imageMatch = d.Image == target.image

  return nameMatch and imageMatch

proc allHosts(target: Container): seq[string] =
  return @[target.host, fmt"www.{target.host}"]

proc createContainer*(target: Container) =
  # TODO: check if running
  discard simpleExec(fmt"docker rm {target.name}")
  let pullCmd = fmt"docker pull {target.image}"
  echo pullCmd
  echo pullCmd.simpleExec()
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo cmd.simpleExec()

proc getRunningContainer(target: Container): DContainer =
  let containers = getContainers()
  return containers.filterIt(target.matches(it))[0]

proc localPort*(target: Container): int =
  let c = target.getRunningContainer()
  return c.Ports[0].PublicPort

proc isHealthy*(target: Container): bool =
  let containers = getContainers()
  for c in containers:
    if target.matches(c):
      return true
  return false

proc createNginxConfig(target: Container) =
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
  restartNginx()

proc parseContainer*(filename: string): Container =
  var ret: Container
  var s = newFileStream(filename)
  load(s, ret)
  s.close()
  return ret

proc runCertbot(target: Container) =
  let allHosts = target.allHosts()
  let hostCmdLine = allHosts.map((x) => fmt"-d {x}").join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {hostCmdLine} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()

proc isNginxConfigCorrect(target: Container) =
  echo "TODO IMPL ME"
  return true

proc ensureContainer*(target: Container) =
  if not target.isHealthy:
    echo fmt"{target.name} is not healthy, recreating"
    target.createContainer()
    target.createNginxConfig()
    target.runCertbot()
