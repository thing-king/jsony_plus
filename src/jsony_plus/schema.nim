# std
import macros
import strutils, options, sets, os

import utils

import json, jsony, tables
export json, jsony, tables

type
  SchemaRefKind* = enum
    LOCAL,    # References within same file (#/definitions/...)
    EXTERNAL  # References to other files (other.json#/...)
    
  SchemaRef* = object
    path*: seq[string]  # ['definitions', 'status'] etc
    case kind*: SchemaRefKind
    of LOCAL:
      discard
    of EXTERNAL:
      file*: string

  PropertyKind* = enum
    STRING = "string",
    ARRAY = "array", 
    OBJECT = "object",
    ENUM = "enum",
    INTEGER = "integer",
    NUMBER = "number",
    BOOLEAN = "boolean",
    ONE_OF = "oneOf",    # Union type
    ANY_OF = "anyOf",    # Union type with different semantics
    ALL_OF = "allOf",    # Intersection type
    REF = "$ref"         # Reference to another schema

  AdditionalPropertiesKind* = enum
    NONE,       # additionalProperties: false
    ANY,        # additionalProperties: true
    SCHEMA      # additionalProperties: { ... schema ... }

  Property* = ref object
    name*: string
    description*: string    
    title*: string         
    default*: JsonNode     
    
    case kind*: PropertyKind
    # -------------------- NUMBER & INTEGER --------------------
    of NUMBER, INTEGER:
      minimum*: Option[float]  
      maximum*: Option[float]  
      exclusiveMinimum*: Option[float]  # strict lower bound
      exclusiveMaximum*: Option[float]  # strict upper bound
      multipleOf*: Option[float]  # Value must be a multiple of this number

    # -------------------- STRING --------------------
    of STRING:
      pattern*: Option[string]  # Regular expression constraint
      minLength*: Option[int]   # Minimum length of string
      maxLength*: Option[int]   # Maximum length of string
      format*: Option[string]   # Enforces format ("date-time", "email", etc.)

    # -------------------- ENUM --------------------
    of ENUM:
      enumValues*: seq[string]  # Allowed values
      constant*: Option[string]    # Single fixed value (alternative to enum)

    # -------------------- ARRAY --------------------
    of ARRAY:
      items*: Property
      # UNSUPPORTED: contains*: Option[Property]   # At least one item must match this
      minItems*: Option[int]    
      maxItems*: Option[int]    
      uniqueItems*: bool

    # -------------------- OBJECT --------------------
    of OBJECT:
      properties*: seq[Property]
      required*: seq[string]

      # UNSUPPORTED: patternProperties*: Table[string, Property] # Regex-based property keys
      # UNSUPPORTED: dependencies*: Table[string, seq[string]]  # Property dependencies


      case additionalPropertiesKind*: AdditionalPropertiesKind
      of NONE: discard
      of ANY: discard
      of SCHEMA: additionalPropertiesSchema*: Property

      definitions*: Table[string, Property]
    
    # -------------------- BOOLEAN --------------------
    of BOOLEAN:
      discard

    # -------------------- COMPOSITE TYPES --------------------
    of ONE_OF, ANY_OF, ALL_OF:
      variants*: seq[Property]
      # UNSUPPORTED: discriminator*: Option[string]  # JSON Schema allows a discriminator for these
    
    # -------------------- REFERENCE --------------------
    of REF:
      reference*: SchemaRef

  NamedProperty* = object
    name*: string
    property*: Property


proc parseSchemaRef(refStr: string): SchemaRef =
  if refStr.startsWith("#/"):
    # Local reference
    result = SchemaRef(kind: LOCAL, path: refStr[2..^1].split("/"))
  else:
    # External reference
    let parts = refStr.split("#/")
    result = SchemaRef(
      kind: EXTERNAL,
      file: parts[0],
      path: parts[1].split("/")
    )

proc parseProperty(node: JsonNode, name: string = ""): Property =
  # Common fields
  var prop = Property(
    name: name,
    description: if node.hasKey("description"): node["description"].getStr() else: "",
    title: if node.hasKey("title"): node["title"].getStr() else: "",
    default: if node.hasKey("default"): node["default"] else: newJNull()
  )

  # Handle $ref first as it takes precedence
  if node.hasKey("$ref"):
    result = Property(
      name: prop.name,
      description: prop.description,
      title: prop.title,
      default: prop.default,
      kind: REF,
      reference: parseSchemaRef(node["$ref"].getStr())
    )
    return

  # Handle empty object case
  if node.kind == JObject and node.len == 0:
    result = Property(
      name: prop.name,
      description: prop.description,
      title: prop.title,
      default: prop.default,
      kind: OBJECT,
      properties: @[],
      required: @[],
      additionalPropertiesKind: ANY,
      definitions: initTable[string, Property]()
    )
    return

  # Handle composite types
  if node.hasKey("oneOf"):
    var variants: seq[Property] = @[]
    for subSchema in node["oneOf"]:
      variants.add(parseProperty(subSchema))
    result = Property(
      name: prop.name,
      description: prop.description,
      title: prop.title,
      default: prop.default,
      kind: ONE_OF,
      variants: variants
    )
    return

  if node.hasKey("anyOf"):
    var variants: seq[Property] = @[]
    for subSchema in node["anyOf"]:
      variants.add(parseProperty(subSchema))
    result = Property(
      name: prop.name,
      description: prop.description,
      title: prop.title,
      default: prop.default,
      kind: ANY_OF,
      variants: variants
    )
    return

  if node.hasKey("allOf"):
    var variants: seq[Property] = @[]
    for subSchema in node["allOf"]:
      variants.add(parseProperty(subSchema))
    result = Property(
      name: prop.name,
      description: prop.description,
      title: prop.title,
      default: prop.default,
      kind: ALL_OF,
      variants: variants
    )
    return

  # Handle enum type
  if node.hasKey("enum"):
    var enumVals: seq[string] = @[]
    for val in node["enum"]:
      enumVals.add(val.getStr())
    
    result = Property(
      name: prop.name,
      description: prop.description,
      title: prop.title,
      default: prop.default,
      kind: ENUM,
      enumValues: enumVals
    )

  # Handle type-specific parsing
  elif node.hasKey("type"):
    let typ = node["type"].getStr()
    case typ
    of "boolean":
      result = Property(
        name: prop.name,
        description: prop.description,
        title: prop.title,
        default: prop.default,
        kind: BOOLEAN
      )

    of "string":
      result = Property(
        name: prop.name,
        description: prop.description,
        title: prop.title,
        default: prop.default,
        kind: STRING,
        pattern: if node.hasKey("pattern"): some(node["pattern"].getStr()) else: none(string),
        minLength: if node.hasKey("minLength"): some(node["minLength"].getInt()) else: none(int),
        maxLength: if node.hasKey("maxLength"): some(node["maxLength"].getInt()) else: none(int),
        format: if node.hasKey("format"): some(node["format"].getStr()) else: none(string)
      )

    of "array":
      result = Property(
        name: prop.name,
        description: prop.description,
        title: prop.title,
        default: prop.default,
        kind: ARRAY,
        items: if node.hasKey("items"): parseProperty(node["items"]) else: nil,
        minItems: if node.hasKey("minItems"): some(node["minItems"].getInt()) else: none(int),
        maxItems: if node.hasKey("maxItems"): some(node["maxItems"].getInt()) else: none(int),
        uniqueItems: if node.hasKey("uniqueItems"): node["uniqueItems"].getBool() else: false
      )

    of "integer":
      result = Property(
        name: prop.name,
        description: prop.description,
        title: prop.title,
        default: prop.default,
        kind: INTEGER,
        minimum: if node.hasKey("minimum"): some(float(node["minimum"].getInt())) else: none(float),
        maximum: if node.hasKey("maximum"): some(float(node["maximum"].getInt())) else: none(float),
        exclusiveMinimum: if node.hasKey("exclusiveMinimum"): some(float(node["exclusiveMinimum"].getInt())) else: none(float),
        exclusiveMaximum: if node.hasKey("exclusiveMaximum"): some(float(node["exclusiveMaximum"].getInt())) else: none(float),
        multipleOf: if node.hasKey("multipleOf"): some(float(node["multipleOf"].getInt())) else: none(float)
      )
    
    of "number":
      result = Property(
        name: prop.name,
        description: prop.description,
        title: prop.title,
        default: prop.default,
        kind: NUMBER,
        minimum: if node.hasKey("minimum"): some(node["minimum"].getFloat()) else: none(float),
        maximum: if node.hasKey("maximum"): some(node["maximum"].getFloat()) else: none(float),
        exclusiveMinimum: if node.hasKey("exclusiveMinimum"): some(node["exclusiveMinimum"].getFloat()) else: none(float),
        exclusiveMaximum: if node.hasKey("exclusiveMaximum"): some(node["exclusiveMaximum"].getFloat()) else: none(float),
        multipleOf: if node.hasKey("multipleOf"): some(node["multipleOf"].getFloat()) else: none(float)
      )

    of "object":
      var objProps: seq[Property] = @[]
      var defs = initTable[string, Property]()
      var additionalPropsKind = ANY  # default to true
      var additionalPropsSchema: Property

      # Parse definitions if they exist
      if node.hasKey("definitions"):
        for defName, defNode in node["definitions"]:
          defs[defName] = parseProperty(defNode, defName)

      # Parse properties
      if node.hasKey("properties"):
        for propName, propNode in node["properties"]:
          objProps.add(parseProperty(propNode, propName))

      # Handle additionalProperties
      if node.hasKey("additionalProperties"):
        let addProps = node["additionalProperties"]
        case addProps.kind
        of JBool:
          additionalPropsKind = if addProps.getBool(): ANY else: NONE
        of JObject:
          additionalPropsKind = SCHEMA
          additionalPropsSchema = parseProperty(addProps)
        else:
          raise newException(ValueError, "Invalid additionalProperties value")

      # Construct the result based on additionalProperties kind
      case additionalPropsKind
      of NONE, ANY:
        result = Property(
          name: prop.name,
          description: prop.description,
          title: prop.title,
          default: prop.default,
          kind: OBJECT,
          properties: objProps,
          required: if node.hasKey("required"): 
                     node["required"].to(seq[string]) 
                   else: @[],
          additionalPropertiesKind: additionalPropsKind,
          definitions: defs
        )
      of SCHEMA:
        result = Property(
          name: prop.name,
          description: prop.description,
          title: prop.title,
          default: prop.default,
          kind: OBJECT,
          properties: objProps,
          required: if node.hasKey("required"): 
                     node["required"].to(seq[string]) 
                   else: @[],
          additionalPropertiesKind: SCHEMA,
          additionalPropertiesSchema: additionalPropsSchema,
          definitions: defs
        )
    
    else:
      raise newException(ValueError, "Unsupported type: " & typ)
  
  else:
    # Handle case where neither type nor enum is present but object is not empty
    if node.kind == JObject:
      result = Property(
        name: prop.name,
        description: prop.description,
        title: prop.title,
        default: prop.default,
        kind: OBJECT,
        properties: @[],
        required: @[],
        additionalPropertiesKind: ANY,
        definitions: initTable[string, Property]()
      )
    else:
      raise newException(ValueError, "Schema must have either 'type', 'enum', '$ref', 'oneOf', 'anyOf', or 'allOf' field")

proc generateRootName*(prop: Property, name: string = ""): string =
  result = name 
  if name.len == 0:
    if prop.title.len > 0:
      result = prop.title.replace(" ", "")
    else:
      result = "GeneratedSchema"

proc getFullName(parentFullName: string, currentName: string): string =
  return parentFullName & currentName.capitalizeAscii

proc addAll[T](to: var seq[T], frm: seq[T]) =
  for item in frm:
    to.add(item)

proc findPropertiesOfKind*(p: Property, parentName: string, searchKinds: set[PropertyKind]): seq[NamedProperty] =
  ## Recursively searches the property tree for properties whose kind is in searchKinds.
  ## As it traverses the tree it builds a fully qualified name using getFullName.
  var results: seq[NamedProperty] = @[]
  
  var currentName: string
  if parentName.len > 0:
    # Compare names case-insensitively to avoid duplicating a name that’s already "baked in"
    if p.name.len > 0 and parentName.toLowerAscii.endsWith(p.name.toLowerAscii):
      currentName = parentName
      # echo "[DEBUG] Skipping duplicate name for property '", p.name, "': using ", currentName
    else:
      currentName = getFullName(parentName, p.name)
  else:
    currentName = p.name
  
  # echo "[DEBUG] Processing property '", p.name, "' (kind: ", $p.kind, ") under '", parentName, "' => '", currentName, "'"
  
  if p.kind in searchKinds:
    results.add(NamedProperty(name: currentName, property: p))
  
  case p.kind
  of ARRAY:
    # Traverse the items schema with a suffix "Item"
    results.addAll(findPropertiesOfKind(p.items, getFullName(currentName, "Item"), searchKinds))
    
  of OBJECT:
    # Traverse declared properties
    for field in p.properties:
      results.addAll(findPropertiesOfKind(field, currentName, searchKinds))
    
    # Handle additionalProperties: if there are no declared properties, use "Value"; otherwise "Additional"
    if p.additionalPropertiesKind == AdditionalPropertiesKind.SCHEMA:
      let suffix = if p.properties.len == 0: "Value" else: "Additional"
      results.addAll(findPropertiesOfKind(p.additionalPropertiesSchema, getFullName(currentName, suffix), searchKinds))
    
    # Traverse definitions
    for key, defProp in p.definitions.pairs:
      results.addAll(findPropertiesOfKind(defProp, getFullName(currentName & "Definitions", key), searchKinds))
      
  of ONE_OF, ANY_OF, ALL_OF:
    # For union types, traverse each variant using a "Variant" suffix
    for idx, variant in p.variants:
      results.addAll(findPropertiesOfKind(variant, getFullName(currentName, "Variant" & $idx), searchKinds))
      
  else:
    # Primitive types, REF, etc. have no nested properties
    discard
  
  return results



# Assume that Property, SchemaRef, PropertyKind, AdditionalPropertiesKind,
# and the utility procs (toEnumValue, generateRootName, getFullName) are defined.
proc log(msg: string) =
  discard
  # let v = 2
  # echo "[DEBUG] ", msg


# Define a CacheKind to indicate what we stored.
type
  CacheKind* = enum
    ckJSON,     # raw JSON stored
    ckPROPERTY  # parsed Property stored

# Cache holds either a JSON node or a parsed Property.
type
  Cache* = object
    kind*: CacheKind
    json*: JsonNode      # valid if kind==ckJSON
    prop*: Property      # valid if kind==ckPROPERTY

# Global cache mapping external file paths to Cache values.
var externalFileCache {.compileTime}: Table[string, Cache] = initTable[string, Cache]()
var globalDefinedTypeNames {.compileTime}: HashSet[string] = initHashSet[string]()
var alreadyImportedExternalNames {.compileTime}: seq[string] = @[]

proc deduplicateDefs*(defs: seq[NimNode]): seq[NimNode] =
  ## Scan through defs, keeping only one definition per type name.
  var uniqueDefs: seq[NimNode] = @[]
  for d in defs:
    ## Assume that a type definition node has its type name as the first child.
    ## You might need to adjust this if your AST structure differs.
    let typeName = $d[0]  # Convert the first child (identifier) to string.
    if typeName notin globalDefinedTypeNames:
      globalDefinedTypeNames.incl(typeName)
      uniqueDefs.add(d)
    else:
      log "Removing duplicate type definition for: " & typeName
  return uniqueDefs

proc generateHooks(prop: Property, typeName: string): NimNode =
  var generatedNames = newSeq[string]()
  

  proc genVariantHooks(prop: Property, name: string): NimNode =
    # echo "CHECKING: " & currentTypeName
    if generatedNames.contains(name):
      return result
    generatedNames.add(name)

    result = newStmtList()
    
    
    let nameIdent = ident(name)

    # Generate parseHook
    let parseCases = newStmtList()
    let hookVIdent = ident("v")
    let hookSIdent = ident("s")
    let dumpVIdent = ident("v")
    let dumpSIdent = ident("s")
    let jsonStrIdent = ident("jsonStr")
    

    let dumpBody = nnkCaseStmt.newTree(
      newDotExpr(
        dumpVIdent,
        ident("kind")
      )
    )

    # echo "VARIANT: " & name

    for i, variant in prop.variants:
      let kindIdent = nnkDotExpr.newTree(
        ident(nameIdent.strVal & "Kind"),
        ident("Variant" & $i)
      )
      let valueTypeStr = name & "Variant" & $i
      let valueTypeIdent = ident(valueTypeStr)
      let valueStr = "value" & $i
      let valueIdent = ident(valueStr)

      # echo "Kind: " & kindIdent[0].strVal & "." & kindIdent[1].strVal

      parseCases.add quote do:
        try:
          var tempValue: `valueTypeIdent`
          # echo "Trying to parse " & `hookSIdent` & " as " & `valueTypeStr`

          tempValue = fromJson(`jsonStrIdent`, `valueTypeIdent`)
          `hookVIdent` = `nameIdent`(kind: `kindIdent`, `valueIdent`: tempValue)
          return
        except:
          # echo "Error: " & getCurrentExceptionMsg()
          discard
      
      dumpBody.add nnkOfBranch.newTree(
        kindIdent,
        quote do:
          `dumpSIdent` = toJson(`dumpVIdent`.`valueIdent`)
      )
      
      

    result.add quote do:
      proc parseHook*(`hookSIdent`: string, i: var int, `hookVIdent`: var `nameIdent`) =
        var `jsonStrIdent`: string
        var jsn: RawJson
        
        parseHook(`hookSIdent`, i, jsn)
        jsonStr = jsn.toJson()

        `parseCases`

        raise newException(ValueError, "Could not parse any variant for " & `name`)


      proc dumpHook*(`dumpSIdent`: var string, `dumpVIdent`: `nameIdent`) =
        `dumpBody`
 
  # TODO: make enum hook work backwards, implement dumpHook for the reverse operation
  proc genEnumHook(prop: Property, name: string): NimNode =
    let nameIdent = ident(name)

    let tableIdent = ident(name & "Table")
    let table = nnkStmtList.newTree(
      nnkVarSection.newTree(
        nnkIdentDefs.newTree(
          tableIdent,
          nnkBracketExpr.newTree(
            ident("Table"),
            ident("string"),
            nameIdent
          ),
          nnkCall.newTree(
            nnkBracketExpr.newTree(
              ident("initTable"),
              ident("string"),
              nameIdent
            )
          )
        )
      )
    )

    for enumValue in prop.enumValues:
      let enumValueIdent = newStrLitNode(enumValue)

      # if name ends with "Variant" + number, remove it
      
      let newEnumValueName = toEnumValue(name, enumValue)
      let newEnumValueIdent = ident(newEnumValueName)

      # echo " mapping " & enumValue & " -> " & newEnumValueName    

      table.add(
        nnkAsgn.newTree(
          nnkBracketExpr.newTree(
            tableIdent,
            enumValueIdent
          ),
          nnkDotExpr.newTree(
            nameIdent,
            newEnumValueIdent
          )
        )
      )

    result = quote do:
      proc enumHook*(s: string, v: var `nameIdent`) =
        `table`
        v = `tableIdent`[s]


  result = newStmtList()

  let enums = findPropertiesOfKind(prop, typeName, {ENUM})
  for enumm in enums:
    result.add genEnumHook(enumm.property, enumm.name)

  let variants = findPropertiesOfKind(prop, typeName, {ONE_OF, ANY_OF})
  for variant in variants:
    result.add genVariantHooks(variant.property, variant.name)


### generateSchemaTypes
proc generateSchemaTypes(prop: Property, typeName: string): NimNode =
  ## Recursively generate top-level type definitions from a JSON Schema Property tree.
  ## Returns a StmtList node containing all type definitions.
  
  let globalRootName = generateRootName(prop, typeName)
  log "Starting generation with root name: " & globalRootName
  
  ## Helper procs for building AST nodes manually:
  proc mkIdent(s: string): NimNode =
    # echo "[DEBUG] mkIdent: " & s
    return ident(s)
  
  proc mkEmpty(): NimNode =
    let node = newNimNode(nnkEmpty)
    return node
  
  proc mkTypeDef(name: string, typeBody: NimNode): NimNode =
    # echo "[DEBUG] mkTypeDef: " & name
    # return newTree(nnkTypeDef, postfix(ident(name), "*"), mkEmpty(), typeBody)
    return newTree(nnkTypeDef, postfix(ident(name), "*"), mkEmpty(), typeBody)


  proc mkEnumType(name: string, variants: seq[string]): NimNode =
    # echo "[DEBUG] mkEnumType: " & name & " with variants: " & $variants
    var enumTy = newNimNode(nnkEnumTy)
    enumTy.add(mkEmpty())
    for v in variants:
      enumTy.add(mkIdent(v))
    return mkTypeDef(name, enumTy)
  
  proc mkArrayType(name: string, itemType: string): NimNode =
    # echo "[DEBUG] mkArrayType: " & name & " alias for seq of " & itemType
    var bracketExpr = newNimNode(nnkBracketExpr)
    bracketExpr.add(mkIdent("seq"))
    bracketExpr.add(mkIdent(itemType))
    return mkTypeDef(name, bracketExpr)
  
  proc mkTableType(name: string, itemType: string): NimNode =
    # echo "[DEBUG] mkTableType: " & name & " alias for Table[string, " & itemType & "]"
    var tableExpr = newNimNode(nnkBracketExpr)
    tableExpr.add(mkIdent("Table"))
    tableExpr.add(mkIdent("string"))
    tableExpr.add(mkIdent(itemType))
    return mkTypeDef(name, tableExpr)
  
  proc mkField(fieldName: string, typeNode: NimNode, defaultVal: NimNode): NimNode =
    # echo "[DEBUG] mkField: " & fieldName
    return newTree(nnkIdentDefs, postfix(mkIdent(fieldName), "*"), typeNode, defaultVal)
  
  proc mkObjectType(name: string, fields: seq[NimNode]): NimNode =
    # echo "[DEBUG] mkObjectType: " & name & " with " & $fields.len & " field(s)"
    var recList = newNimNode(nnkRecList)
    for f in fields:
      recList.add(f)
    var objectTy = newNimNode(nnkObjectTy)
    objectTy.add(mkEmpty())
    objectTy.add(mkEmpty())
    objectTy.add(recList)
    return mkTypeDef(name, objectTy)
  
  proc mkDiscriminantEnum(enumName: string, variantNames: seq[string]): NimNode =
    # echo "[DEBUG] mkDiscriminantEnum: " & enumName & " with variants: " & $variantNames
    var enumTy = newNimNode(nnkEnumTy)
    enumTy.add(mkEmpty())
    for v in variantNames:
      enumTy.add(mkIdent(v))
    return mkTypeDef(enumName, enumTy)
  
  proc mkUnionType(unionName: string, unionEnumName: string,
                   branches: seq[(string, seq[NimNode])]): NimNode =
    # echo "[DEBUG] mkUnionType: " & unionName & " with discriminant " & unionEnumName
    var recCase = newNimNode(nnkRecCase)
    recCase.add(newTree(nnkIdentDefs, postfix(mkIdent("kind"), "*"), mkIdent(unionEnumName), mkEmpty()))
    for branch in branches:
      let (branchName, branchFields) = branch
      # echo "[DEBUG]   mkUnionType branch: " & branchName
      var ofBranch = newNimNode(nnkOfBranch)
      ofBranch.add(mkIdent(branchName))
      var branchRecList = newNimNode(nnkRecList)
      for f in branchFields:
        branchRecList.add(f)
      ofBranch.add(branchRecList)
      recCase.add(ofBranch)
    var recList = newNimNode(nnkRecList)
    recList.add(recCase)
    var objectTy = newNimNode(nnkObjectTy)
    objectTy.add(mkEmpty())
    objectTy.add(mkEmpty())
    objectTy.add(recList)
    return mkTypeDef(unionName, objectTy)
  
  ## Nested definitions
  var collectedDefs: seq[NimNode] = @[]
  var hooks: seq[NimNode] = @[]

  ## Main recursive helper.
  proc gen(p: Property, currName: string): (string, seq[NimNode]) =
    log "gen: processing property '" & currName & "' of kind: " & $p.kind
    var localDefs: seq[NimNode] = @[]
    var outType: string = ""
    case p.kind
    of STRING:
      outType = "string"
      log "   Primitive type STRING"
    of INTEGER:
      outType = "int"
      log "   Primitive type INTEGER"
    of NUMBER:
      outType = "float"
      log "   Primitive type NUMBER"
    of BOOLEAN:
      outType = "bool"
      log "   Primitive type BOOLEAN"
    of ENUM:
      outType = currName
      var variants: seq[string] = @[]
      for v in p.enumValues:
        let enumVal = toEnumValue(currName, v)
        # echo "[DEBUG]   ENUM variant: " & enumVal
        variants.add(enumVal)
      localDefs.add(mkEnumType(currName, variants))
    of ARRAY:
      log "   ARRAY type processing"
      let (itemType, itemDefs) = gen(p.items, currName & "Item")
      addAll(localDefs, itemDefs)
      outType = currName
      localDefs.add(mkArrayType(currName, itemType))
    of OBJECT:
      log "   OBJECT type processing"
      for defKey, defProp in p.definitions.pairs:
        let fullDefName = getFullName(currName & "Definitions", defKey)
        log "     processing nested definition: " & defKey & " -> " & fullDefName
        let (_, defDefs) = gen(defProp, fullDefName)
        addAll(localDefs, defDefs)

      if p.properties.len == 0 and p.additionalPropertiesKind == AdditionalPropertiesKind.SCHEMA:
        log "   Object with additionalProperties only; converting to table alias with '__Value'"
        let (valueType, valueDefs) = gen(p.additionalPropertiesSchema, currName & "Value")
        addAll(localDefs, valueDefs)
        outType = currName
        localDefs.add(mkTableType(currName, valueType))
      else:
        outType = currName
        var fieldNodes: seq[NimNode] = @[]
        for field in p.properties:
          let fullFieldName = getFullName(currName, field.name)
          log "     processing object field: " & field.name & " -> " & fullFieldName
          let (fieldType, fieldDefs) = gen(field, fullFieldName)
          addAll(localDefs, fieldDefs)
          fieldNodes.add(mkField(field.name, mkIdent(fieldType), mkEmpty()))
        if p.additionalPropertiesKind == AdditionalPropertiesKind.SCHEMA:
          log "     processing additionalProperties as schema"
          let fullAPName = getFullName(currName, "Additional")
          let (apType, apDefs) = gen(p.additionalPropertiesSchema, fullAPName)
          addAll(localDefs, apDefs)
          var tableType = newNimNode(nnkBracketExpr)
          tableType.add(mkIdent("Table"))
          tableType.add(mkIdent("string"))
          tableType.add(mkIdent(apType))
          fieldNodes.add(mkField("additionalProperties", tableType, mkEmpty()))
        var nestedDefs: seq[NimNode] = @[]
        for defKey, defProp in p.definitions.pairs:
          let fullDefName = getFullName(currName, defKey)
          log "     processing nested definition: " & defKey & " -> " & fullDefName
          let (outKind, defDefs) = gen(defProp, fullDefName)
          if defDefs.len == 0:
            log "     No AST nodes were generated for " & fullDefName & "; creating a type alias to " & outKind
            nestedDefs.add(mkTypeDef(fullDefName, mkIdent(outKind)))
          else:
            addAll(nestedDefs, defDefs)
        localDefs = nestedDefs & localDefs
        localDefs.add(mkObjectType(currName, fieldNodes))
    of ONE_OF, ANY_OF, ALL_OF:
      log "   Union type processing (oneOf/anyOf/allOf)"
      outType = currName
      var branches: seq[(string, seq[NimNode])] = @[]
      var variantNames: seq[string] = @[]
      for idx, variant in p.variants:
        let variantName = "Variant" & $idx
        log "     union branch: " & variantName
        variantNames.add(variantName)
        # Set the branch alias to be <currName><variantName>
        let branchAlias = currName & variantName
        # Generate the branch type with branchAlias as the desired name.
        var (vType, vDefs) = gen(variant, branchAlias)
        addAll(localDefs, vDefs)
        # If the generated type is not already the branch alias, then create an alias.
        if vType != branchAlias:
          log " Creating alias for union branch: " & branchAlias & " = " & vType
          localDefs.add(mkTypeDef(branchAlias, mkIdent(vType)))
          vType = branchAlias
        var branchFields: seq[NimNode] = @[]
        branchFields.add(mkField("value" & $idx, mkIdent(vType), mkEmpty()))
        branches.add((variantName, branchFields))
      let unionEnumName = currName & "Kind"
      localDefs.add(mkDiscriminantEnum(unionEnumName, variantNames))
      localDefs.add(mkUnionType(currName, unionEnumName, branches))
    of REF:
      log "   $ref encountered"
      if p.reference.kind == SchemaRefKind.LOCAL:
        var refName = globalRootName
        for part in p.reference.path:
          refName = getFullName(refName, part)
        # if refName == "definitions":
          # refName = globalRootName & "__definitions"
        # elif refName.startsWith("definitions_"):
          # refName = globalRootName & "__" & refName.substr(len("definitions_"))
        outType = refName
        log "   Resolved local $ref to: " & refName
      else:
        ## External reference: look up the external file in our global cache.
        if not externalFileCache.contains(p.reference.file):
          raise newException(Exception, "External file not loaded: " & p.reference.file)
        let cacheVal = externalFileCache[p.reference.file]
        if cacheVal.kind == ckPROPERTY:
          var targetProp = cacheVal.prop
          for part in p.reference.path:
            if targetProp.definitions.contains(part):
              targetProp = targetProp.definitions[part]
            else:
              var found = false
              for sub in targetProp.properties:
                if sub.name == part:
                  targetProp = sub
                  found = true
                  break
              if not found:
                raise newException(Exception, "External $ref path not found: " & part)
          var newTypeName = p.reference.file.split(".")[0]
          for part in p.reference.path:
            newTypeName = getFullName(newTypeName, part)
          let (refType, defs) = gen(targetProp, newTypeName)
          addAll(localDefs, defs)
          outType = refType
        else: # ckJSON: we stored raw JSON in the cache
          var targetJson = cacheVal.json
          for part in p.reference.path:
            if targetJson.hasKey(part):
              targetJson = targetJson[part]
            else:
              raise newException(Exception, "External $ref JSON path not found: " & part)
          var targetProp = parseProperty(targetJson)
          var newTypeName = p.reference.file.split(".")[0]
          for part in p.reference.path:
            newTypeName = getFullName(newTypeName, part)
          
          let (refType, defs) = gen(targetProp, newTypeName)
          
          if not alreadyImportedExternalNames.contains(newTypeName):
            addAll(localDefs, defs)
            hooks.add(generateHooks(targetProp, newTypeName))
            alreadyImportedExternalNames.add(newTypeName)
          else:
            log "   Skipping hooks and type generation for already imported external type: " & newTypeName
          outType = refType

          
          

        log "   Resolved external $ref to: " & outType
    else:
      outType = "unknown"
      log "   Unknown property kind encountered!"
    return (outType, localDefs)
  

  var allDefs: seq[NimNode] = @[]

  ## Process root-level definitions first:
  if prop.definitions.len > 0:
    for defKey, defProp in prop.definitions.pairs:
      let fullDefName = getFullName(globalRootName & "Definitions", defKey)
      log " Processing root definition: " & defKey & " -> " & fullDefName
      let (outType, defNodes) = gen(defProp, fullDefName)
      if defNodes.len == 0:
        log " No AST nodes were generated for " & fullDefName & "; creating a type alias to " & outType
        allDefs.add(mkTypeDef(fullDefName, mkIdent(outType)))
      else:
        addAll(allDefs, defNodes)


  let (_, mainDefs) = gen(prop, globalRootName)
  allDefs.addAll(collectedDefs)
  allDefs.addAll(mainDefs)


  allDefs = deduplicateDefs(allDefs)
  # allDefs.addAll(hooks)

  var rootStmt = newNimNode(nnkStmtList)
  for d in allDefs:
    if d.kind == nnkTypeDef:
      rootStmt.add(newTree(nnkTypeSection, d))
    else:
      rootStmt.add(d)
  
  for hook in hooks:
    rootStmt.add(hook)

  log " Generation complete. Final AST:"
  log rootStmt.repr
  return rootStmt


proc cleanGenSym*(s: string): string =
  var i = 0
  result = ""
  while i < s.len:
    if i + 6 < s.len and s[i] == '`' and s[i+1] == 'g' and s[i+2] == 'e' and 
       s[i+3] == 'n' and s[i+4] == 's' and s[i+5] == 'y' and s[i+6] == 'm':
      # Skip past gensym and digits
      i += 7  # skip `gensym
      while i < s.len and s[i] in {'0'..'9'}: i.inc
    else:
      result.add s[i]
      i.inc


### fromSchema Macro
macro fromSchema*(schemaPath: static[string], typeName: static[string]): untyped =
  # if not existsEnv("THING_PROJECT"):
  #   error "THING_PROJECT environment variable not set"
  # let projectPath = getEnv("THING_PROJECT")
  # let newPath = projectPath / schemaPath
  let fileName = schemaPath.split("/")[^1]
  
  ## Reads the schema file at compile time, parses it, and stores its result
  ## in the global externalFileCache. If the resulting Property is “empty” (has no
  ## properties, definitions, etc.), then we store the raw JSON instead.
  let content = staticRead(schemaPath)
  let jsn = parseJson(content)
  let prop = parseProperty(jsn)
  var cacheVal: Cache
  ## (You may want to refine the "empty" test; here we simply say that if the parsed
  ## property has no "type" (i.e. its kind is OBJECT but with empty definitions/properties),
  ## we store the raw JSON.)
  
  # echo "HERE!"
  # echo prop[]
  if (prop.kind == OBJECT) and (prop.properties.len == 0) and (prop.definitions.len == 0) and (prop.additionalPropertiesKind == ANY or prop.additionalPropertiesKind == NONE):
    # echo "Storing raw JSON for " & fileName
    cacheVal = Cache(kind: ckJSON, json: jsn, prop: nil)
  else:
    cacheVal = Cache(kind: ckPROPERTY, json: newJNull(), prop: prop)
    result = newStmtList(
      generateSchemaTypes(prop, typeName),
      generateHooks(prop, typeName)
    )
    # echo result.repr
  
  externalFileCache[fileName] = cacheVal

macro fromSchema*(schemaPath: static[string], typeName: static[string], appendToPath: static[string]): untyped =
  # if not existsEnv("THING_PROJECT"):
  #   error "THING_PROJECT environment variable not set"
  # let projectPath = getEnv("THING_PROJECT")
  # let newPath = projectPath / schemaPath
  # let newAppendToPath = projectPath / appendToPath
  let fileName = schemaPath.split("/")[^1]
  
  ## Reads the schema file at compile time, parses it, and stores its result
  ## in the global externalFileCache. If the resulting Property is “empty” (has no
  ## properties, definitions, etc.), then we store the raw JSON instead.
  let content = staticRead(schemaPath)
  let jsn = parseJson(content)
  let prop = parseProperty(jsn)
  var cacheVal: Cache
  ## (You may want to refine the "empty" test; here we simply say that if the parsed
  ## property has no "type" (i.e. its kind is OBJECT but with empty definitions/properties),
  ## we store the raw JSON.)
  if (prop.kind == OBJECT) and (prop.properties.len == 0) and (prop.definitions.len == 0) and (prop.additionalPropertiesKind == ANY or prop.additionalPropertiesKind == NONE):
    # echo "Storing raw JSON for " & fileName
    cacheVal = Cache(kind: ckJSON, json: jsn, prop: nil)
  else:
    cacheVal = Cache(kind: ckPROPERTY, json: newJNull(), prop: prop)
    result = newStmtList(
      generateSchemaTypes(prop, typeName),
      generateHooks(prop, typeName)
    )

    when not defined(js):
      # if appendToPath file does not exist, create it
      if not fileExists(appendToPath):
        writeFile(appendToPath, "import tables, options, jsony\n")
      
      # append to appendToPath, result.repr
      let currentContent = readFile(appendToPath)
      writeFile(appendToPath, currentContent & "\n\n## " & typeName & "\n" & result.repr.cleanGenSym)
    else:
      error "Cannot use `fromSchema` with `appendToPath` when `js` defined."
    # echo result.repr
  
  externalFileCache[fileName] = cacheVal
