import 
  ./shell_utils,
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

proc allHosts(target: Container): seq[string] =
  return @[target.host, fmt"www.{target.host}"]

proc createContainer(target: Container) =
  # TODO: check if running
  let pullCmd = fmt"docker pull {target.image}"
  echo pullCmd
  echo pullCmd.simpleExec()
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo cmd.simpleExec()

proc localPort(target: Container): int =
  let containers = "docker container ls".simpleExec
  proc findline(): string =
    for line in containers.split("\n")[1..^1]:
      if line.contains(target.name):
        return line
  let targetLine = findline()
  for word in targetLine.split(" "):
    if word.contains("0.0.0.0"):
      return word.split("->")[0].split("0.0.0.0:")[1].parseInt()

proc isRunning*(target: Container): bool =
  let containers = "docker container ls".simpleExec
  for line in containers.split("\n")[1..^1]:
    if line.contains(target.name):
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


proc ensureContainer*(target: Container) =
  if not target.isRunning:
    target.createContainer
  target.createNginxConfig()
  target.runCertbot()