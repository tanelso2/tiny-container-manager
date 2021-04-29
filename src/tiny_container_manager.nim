import yaml.serialization, streams
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
  return containers.contains(target.name)

when isMainModule:
  echo "hey hey hey"

