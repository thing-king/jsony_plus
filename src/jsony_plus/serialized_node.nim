import macros
import strutils, options

import pkg/jsony_plus

type
  LineInfo* = object
    filename*: string
    line*: int
    column*: int

type
  SerializedNode* = object
    kind*: string
    repr*: string    # Regular repr (source code)
    info*: LineInfo        # Location info
    strVal*: string      
    intVal*: BiggestInt  
    floatVal*: float
    symKind*: string
    typeKind*: string
    children*: seq[SerializedNode]

allowSerialization LineInfo
allowSerialization SerializedNode


proc toSerializedNode*(node: NimNode): SerializedNode =
  result = SerializedNode(
    kind: $node.kind,
    repr: node.repr,  # Regular source code repr
    info: LineInfo(
      filename: node.lineInfoObj.filename,
      line: node.lineInfoObj.line,
      column: node.lineInfoObj.column
    ),
    children: @[]
  )

  # Handle different node types
  case node.kind:
  of nnkStrLit..nnkTripleStrLit:
    result.strVal = node.strVal
  of nnkCharLit..nnkUInt64Lit:
    result.intVal = node.intVal
  of nnkFloatLit..nnkFloat128Lit:
    result.floatVal = node.floatVal
  of nnkIdent, nnkSym:
    result.strVal = node.strVal
  else:
    # Recursively process child nodes
    for i in 0..<node.len:
      result.children.add(toSerializedNode(node[i]))

proc toNimNode*(node: SerializedNode): NimNode =
  # Helper to convert string kind back to NimNodeKind
  let kind = parseEnum[NimNodeKind](node.kind)
  
  # Create the base node based on kind
  result = case kind
  of nnkStrLit..nnkTripleStrLit:
    newStrLitNode(node.strVal)
  of nnkCharLit..nnkUInt64Lit:
    newIntLitNode(node.intVal)
  of nnkFloatLit..nnkFloat128Lit:
    newFloatLitNode(node.floatVal)
  of nnkIdent, nnkSym:
    ident(node.strVal)
  else:
    newNimNode(kind)
    
  # Set the line info if available
  if node.info.line != 0:  # Only set if we have valid line info
    # Create a temporary node with the desired line info
    let infoNode = newNimNode(kind)
    infoNode.setLineInfo(node.info.filename, node.info.line.int, node.info.column.int)
    # Copy the line info to our result node
    result.copyLineInfo(infoNode)
    
  # Process children recursively
  for child in node.children:
    result.add(toNimNode(child))



proc treeRepr*(node: SerializedNode, level: int = 0): string =
  let indent = "  ".repeat(level)
  result = indent & node.kind
  
  case node.kind
  of "nnkStrLit", "nnkRStrLit", "nnkTripleStrLit", "nnkIdent":
    result &= " " & node.strVal.escape
  of "nnkCharLit", "nnkIntLit", "nnkInt8Lit", "nnkInt16Lit", 
     "nnkInt32Lit", "nnkInt64Lit", "nnkUIntLit", "nnkUInt8Lit", 
     "nnkUInt16Lit", "nnkUInt32Lit", "nnkUInt64Lit":
    result &= " " & $node.intVal
  of "nnkFloatLit", "nnkFloat32Lit", "nnkFloat64Lit", "nnkFloat128Lit":
    result &= " " & $node.floatVal
  else: discard

  result &= "\n"
  
  # Add children recursively
  for child in node.children:
    result &= treeRepr(child, level + 1)

proc `==`*(a, b: SerializedNode): bool =
  if a.kind != b.kind: return false
  if a.strVal != b.strVal: return false
  if a.intVal != b.intVal: return false
  if a.floatVal != b.floatVal: return false
  if a.children.len != b.children.len: return false
  for i in 0..<a.children.len:
    if a.children[i] != b.children[i]: return false
  return true
proc `==`*(a, b: Option[SerializedNode]): bool =
  if a.isNone and b.isNone: return true
  if a.isSome and b.isSome: return a.get == b.get
  return false