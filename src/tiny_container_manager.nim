#import yaml.serialization, streams
import 
  strformat,
  os,
  osproc,
  strutils
# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.
type
  Container = object of RootObj
    name*: string
    image: string
    containerPort: int
    host: string

proc runInShell(x: openArray[string]): string =
  let process = x[0]
  let args = x[1..^1]
  return execProcess(process, args=args, options={poUsePath}).strip

proc simpleExec(command: string): string = command.split.runInShell

proc isRunning(target: Container): bool =
  let containers = "docker container ls".simpleExec
  for line in containers.split("\n")[1..^1]:
    if line.contains(target.name):
      return true
  return false

proc createContainer(target: Container) =
  # TODO: check if running
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo cmd.simpleExec()


when isMainModule:
  echo "hey hey hey"
  let name = "k8s_rules-configmap-reloader_prometheus-prometheus-operator-prometheus-0"
  let image = "nginx:latest"
  let containerPort = 8080
  let host = "thomasnelson.me"
  let c = Container(name: name, image: image, containerPort: containerPort, host: host)
  echo fmt"{c.name} is running? {c.isRunning}"
  let c2 = Container(name: "tnelson-personal-website", image: image, containerPort: containerPort, host: host)
  echo fmt"{c2.name} is running? {c2.isRunning}"
  if not c2.isRunning:
    c2.createContainer

