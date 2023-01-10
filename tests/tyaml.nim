import 
  std/tables

import 
  tiny_container_manager/yaml_utils {.all.}

proc roundTrip(n: YNode): YNode =
  n.toString().loadNode()

proc checkRoundtrip(n: YNode) =
  assert n.toString() == n.toString().loadNode().toString()

proc checkRoundtrip(s: string) =
  checkRoundtrip s.loadNode()

const divider = "\n~~~~~~~~~~~~\n"
template echod(s) =
  echo s
  echo divider

let sampleNodeStr = """
{ "i": 1, "f": 0.1, "s": "hello"}
"""
checkRoundtrip sampleNodeStr

var mynode: YNode 
mynode = loadNode(sampleNodeStr)
checkRoundtrip mynode

var sampleStr = """
a:
- 1
- 2
- 3
b: false
"""
checkRoundtrip sampleStr

mynode = loadNode(sampleStr)
checkRoundtrip mynode

let intList: YNode = newYList(@[
    newYString("1"), 
    newYString("2"), 
    newYString("3")
])

checkRoundtrip intList

let heteroList: YNode = newYList(@[
  newYString("1"), 
  newYString("2"), 
  newYList(@[newYString("3"), newYString("4")]),
  newYString("5")
])
checkRoundtrip heteroList


let smallList: YNode = newYList(@["a", "b", "c", "d"])
checkRoundtrip smallList

let t = {
  "x": smallList, 
  "y": newYString("yay"),
  "z": heteroList,
  "z2": heteroList,
}.newTable()

let mapExample: YNode = newYMap(t)
checkRoundtrip mapExample

let t2 = {
  "apple": newYString("red"),
  "orange": heteroList,
  "banana": mapExample
}.newTable()

let map2: YNode = newYMap(t2)
checkRoundtrip map2


# Check Maps under lists
let map3 = newYMap({
  "example1": newYList(@[newYString("0.12"), map2]),
  "example2": mapExample
})

checkRoundtrip map3

var s = """
a: 1
b: 2
c: 
  d: 4
  e: 5
  f: 
   - 6
   - 7
   - 8
"""
checkRoundtrip s

# Empty list
let emptyNodes: seq[YNode] = @[]
let emptyList = newYList(emptyNodes)
checkRoundtrip emptyList
let emptyList2 = emptyList.toString().loadNode()
assert emptyList2.kind == ynList
assert emptyList2.listVal.len() == 0

# empty map
let emptyMap = newYMap(newTable[string,YNode]())
checkRoundtrip emptyMap
let emptyMap2 = emptyMap.toString().loadNode()
checkRoundtrip emptyMap2
assert emptyMap2.kind == ynMap
assert emptyMap2.mapVal.len() == 0

# empty string
let emptyString = newYString("")
checkRoundtrip emptyString
let emptyStringList = newYList(@[emptyString, emptyString])
checkRoundtrip emptyStringList
let emptyStringMap = newYMap({"a": emptyString, "b": newYString("1")})
checkRoundtrip emptyStringMap