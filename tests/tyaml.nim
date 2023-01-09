import
  yaml/serialization,
  streams

type 
  MountKind* = enum
    mkTmpfs
    mkS3fs
  Mount* = object
    mountPoint: string
    case kind: MountKind
    of mkTmpfs:
      discard
    of mkS3fs:
      key: string
      secret: string
      bucket: string
  Con* = object of RootObj
    name*: string
    mounts*: seq[Mount]

let noMounts = Con(name:"example", mounts: @[])

let m = Mount(mountPoint: "/etc/tmpfs", kind: mkTmpfs)

var c2 = Con(name: "c2", mounts: @[m])

var s = newFileStream("out.yaml", fmWrite)
dump(noMounts, s)
s.close()

s = newFileStream("out2.yaml", fmWrite)
dump(c2,s)
s.close()

import std/typeinfo

var x: Any

x = c2.toAny

# echo x.kind
# for (name,i) in x.fields:
#   echo name

import macros

macro dumpTypeImpl(x: typed): untyped =
  newLit(x.getTypeImpl.repr)

# echo c2.dumpTypeImpl()

import std/tables

let sampleNodeStr = """
{ "i": 1, "f": 0.1, "s": "hello"}
"""

import yaml/dom
import sequtils

var node: YamlNode

load(sampleNodeStr,node)

# echo node.kind

# TODO: yMapping.fields: TableRef[YamlNode,YamlNode] => TableRef[string,YamlNode] conversion function
# Wait... can't because of what YamlNode actually holds

type
  MyNodeKind = enum
    mnString, mnList, mnMap
  MyNode {.implicit.} = object
    case kind: MyNodeKind
    of mnString:
      strVal: string
    of mnList:
      listVal: seq[MyNode]
    of mnMap:
      mapVal: TableRef[string, MyNode]

proc get(o: TableRef[YamlNode, YamlNode], n: string): YamlNode =
  let x = YamlNode(
    kind: yScalar, 
    content: n, 
    tag: yTagExclamationMark)
  if not o.hasKey(x):
    raise newException(ValueError, "Could not find")
  return o[x]

proc simplifyName(k: YamlNode): string =
  case k.kind
  of yScalar:
    return k.content
  else:
    raise newException(ValueError, "Cannot simplify the name of a non-scalar")

proc translate(n: YamlNode): MyNode =
  case n.kind
  of yMapping:
    let t = newTable[string,MyNode](n.fields.len)
    for k,v in n.fields.pairs:
      let name = simplifyName(k)
      t[name] = translate(v)
    result = MyNode(kind: mnMap, mapVal: t)
  of ySequence:
    let elems = n.elems.mapIt(translate(it))
    result = MyNode(kind: mnList, listVal: elems)
  else:
    result = MyNode(kind: mnString, strVal: n.content)

# echo len(node.fields)
# echo node.fields.get("i")

# import json

# var jnode: JsonNode

# load(sampleNodeStr, jnode)

# echo jnode

# Needs tags
var mynode: MyNode

mynode = node.translate()

echo mynode