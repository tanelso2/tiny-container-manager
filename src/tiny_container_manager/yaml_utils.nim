import
    yaml,
    yaml/dom,
    sequtils,
    streams,
    strformat,
    strutils,
    sugar,
    tables,
    nim_utils/logline

type
  YNodeKind* = enum
    ynString, ynList, ynMap
  YNode* = object
    case kind*: YNodeKind
    of ynString:
      strVal*: string
    of ynList:
      listVal*: seq[YNode]
    of ynMap:
      mapVal*: TableRef[string, YNode]

proc newYList*(elems: seq[YNode]): YNode =
    YNode(kind:ynList, listVal: elems)

proc newYMap*(t: TableRef[string,YNode]): YNode =
    YNode(kind: ynMap, mapVal: t)

proc newYMap*(a: openArray[(string,YNode)]): YNode =
    a.newTable().newYMap()

proc newYString*(s: string): YNode =
    YNode(kind: ynString, strVal: s)

proc newYList*(elems: seq[string]): YNode =
    YNode(kind:ynList, listVal: elems.map(newYString))

template expectYString*(body: untyped) =
    case n.kind
    of ynString:
        body
    else:
        raise newException(ValueError, "expected string YNode")

template expectYList*(body: untyped) =
    case n.kind
    of ynList:
        body
    else:
        raise newException(ValueError, "expected list YNode")

template expectYMap*(body: untyped) =
    case n.kind
    of ynMap:
        body
    else:
        raise newException(ValueError, "expected map YNode")

proc get*(n: YNode, k: string): YNode =
    expectYMap:
        result = n.mapVal[k]

proc elems*(n: YNode): seq[YNode] =
    expectYList:
        result = n.listVal

proc str*(n: YNode): string =
    expectYString:
        result = n.strVal

proc getStr*(n: YNode, k: string): string =
    expectYMap:
        n.get(k).str()

proc toInt*(n: YNode): int =
    expectYString:
        result = parseInt(n.strVal)

proc toFloat*(n: YNode): float =
    expectYString:
        result = parseFloat(n.strVal)

proc simplifyName(k: YamlNode): string =
  case k.kind
  of yScalar:
    return k.content
  else:
    raise newException(ValueError, "Cannot simplify the name of a non-scalar")

proc translate(n: YamlNode): YNode =
  case n.kind
  of yMapping:
    let t = newTable[string,YNode](n.fields.len)
    for k,v in n.fields.pairs:
      let name = simplifyName(k)
      t[name] = translate(v)
    result = newYMap(t)
  of ySequence:
    let elems = n.elems.mapIt(translate(it))
    result = newYList(elems)
  else:
    result = newYString(n.content)

proc loadNode*(s: string | Stream): YNode =
    var node: YamlNode
    load(s,node)
    return translate(node)

proc newline(i: int): string =
    "\n" & repeat(' ', i)

proc toString*(n: YNode, indentLevel=0): string =

    proc newline(): string =
        newline(indentLevel)

    case n.kind
    of ynString:
        let s = n.strVal
        if len(s) > 0:
            return s
        else:
            return "\"\""
    of ynMap:
        let fields = n.mapVal
        let s = collect:
            for k,v in fields.pairs:
                case v.kind
                of ynString:
                    let indentPlus = len(k) + 2
                    let newIndent = indentLevel + indentPlus
                    let vstr = v.toString(indentLevel=newIndent)
                    fmt"{k}: {vstr}"
                else:
                    let newIndent = indentLevel+2
                    var vstr = v.toString(indentLevel=newIndent)
                    vstr = fmt"{newline(newIndent)}{vstr}"
                    fmt"{k}:{vstr}"
        case len(s)
        of 0:
            return "{}"
        else:
            return s.join(newline())
    of ynList:
        let elems = n.listVal
        case len(elems)
        of 0: return "[]"
        else:
            return elems
                .mapIt(toString(it,indentLevel=indentLevel+2))
                .mapIt("- $1" % it)
                .join(newline())

proc toYaml*(x: string): YNode =
    newYString(x)

proc toYaml*(i: int): YNode =
    newYString($i)

proc toYaml*(f: float): YNode =
    newYString($f)

proc toYaml*(b: bool): YNode =
    newYString($b)

proc toYaml*[T](l: seq[T]): YNode =
    let elems = collect:
        for x in l:
            toYaml(x)
    return elems.newYList()

proc ofYaml*[T](n: YNode, t: typedesc[T]): T =
    discard

proc ofYaml*[T](n: YNode, t: typedesc[seq[T]]): seq[T] =
    expectYList:
        result = collect:
            for x in n.elems():
                ofYaml(x, T)