# jsony_plus
An extension of [jsony](https://github.com/treeform/jsony) providing quality of life features.


## Features

### Rename keys with an easy pragma
JSON property names can be renamed to *not* directly match to type property names. *This works both ways to/from*
```nim
type AnObject = object
  Name  {.json: "name"      }: string
  Value {.json: "some_value"}: string

# required to generate `dumpHook()` and `parseHook()`s
allowSerialization AnObject

echo AnObject(Name: "hello", Value: "world!").toJson()
# { "name": "hello", "some_value": "world!" }
```

### JSON Schema-based type generation
Types can be auto-generated given a JSON Schema.

###### Usage:
```nim
# fromSchema <path> <baseName>
fromSchema "web/css/schemas/atRules.schema.json", "AtRule"
```

<details>
    <summary>Example JSON Schema</summary>

  #### Given the following schema:
  ```json
  {
    "definitions": {
      "stringOrPropertyList": {
        "oneOf": [
          {
            "type": "string"
          },
          {
            "type": "array",
            "minItems": 1,
            "uniqueItems": true,
            "items": {
              "type": "string",
              "property-reference": {
                "comment": "property-reference is an extension to the JSON schema validator. Here it jumps 3 levels up in the hierarchy and tests if a value is an existing key in descriptors. See test/validate-schema.js for implementation details.",
                "$data": "3"
              }
            }
          }
        ]
      }
    },
    "type": "object",
    "additionalProperties": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "syntax": {
          "type": "string"
        },
        "interfaces": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "groups": {
          "type": "array",
          "minitems": 1,
          "uniqueItems": true,
          "items": {
            "$ref": "definitions.json#/groupList"
          }
        },
        "descriptors": {
          "type": "object",
          "additionalProperties": {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "syntax": {
                "type": "string"
              },
              "media": {
                "oneOf": [
                  {
                    "type": "string",
                    "enum": [
                      "all",
                      "continuous",
                      "paged",
                      "visual"
                    ]
                  },
                  {
                    "type": "array",
                    "minItems": 2,
                    "uniqueItems": true,
                    "items": {
                      "type": "string",
                      "enum": [
                        "continuous",
                        "paged",
                        "visual"
                      ]
                    }
                  }
                ]
              },
              "initial": {
                "$ref": "#/definitions/stringOrPropertyList"
              },
              "percentages": {
                "$ref": "#/definitions/stringOrPropertyList"
              },
              "computed": {
                "$ref": "#/definitions/stringOrPropertyList"
              },
              "order": {
                "enum": [
                  "orderOfAppearance",
                  "uniqueOrder"
                ]
              },
              "status": {
                "enum": [
                  "standard",
                  "nonstandard",
                  "experimental",
                  "obsolete"
                ]
              },
              "mdn_url": {
                "type": "string",
                "pattern": "^https://developer.mozilla.org/docs/Web/CSS/"
              }
            },
            "required": [
              "syntax",
              "initial",
              "percentages",
              "computed",
              "order",
              "status"
            ]
          }
        },
        "status": {
          "enum": [
            "standard",
            "nonstandard",
            "experimental",
            "obsolete"
          ]
        },
        "mdn_url": {
          "type": "string",
          "pattern": "^https://developer.mozilla.org/docs/Web/CSS/"
        }
      },
      "required": [
        "syntax",
        "groups",
        "status"
      ]
    }
  }
  ```
</details>

<details>
    <summary>Example Generated Types and Hooks</summary>

  #### Generates the following nim types:
  ```nim
  type
    AtRuleDefinitionsStringOrPropertyListVariant0* = string
  type
    AtRuleDefinitionsStringOrPropertyListVariant1* = seq[string]
  type
    AtRuleDefinitionsStringOrPropertyListKind* = enum
      Variant0, Variant1
  type
    AtRuleDefinitionsStringOrPropertyList* = object
      case kind*: AtRuleDefinitionsStringOrPropertyListKind
      of Variant0:
          value0*: AtRuleDefinitionsStringOrPropertyListVariant0

      of Variant1:
          value1*: AtRuleDefinitionsStringOrPropertyListVariant1

    
  type
    AtRuleValueInterfaces* = seq[string]
  type
    definitionsGroupList* = enum
      dglBASIC_SELECTORS, dglCOMBINATORS, dglCOMPOSITING_AND_BLENDING,
      dglCSS_ANGLES, dglCSS_ANIMATIONS, dglCSS_BACKGROUNDS_AND_BORDERS,
      dglCSS_BASIC_USER_INTERFACE, dglCSS_BOX_ALIGNMENT, dglCSS_BOX_MODEL,
      dglCSS_BOX_SIZING, dglCSS_CASCADING_AND_INHERITANCE, dglCSS_COLOR,
      dglCSS_CONDITIONAL_RULES, dglCSS_CONTAINMENT, dglCSS_COUNTER_STYLES,
      dglCSS_CUSTOM_PROPERTIES_FOR_CASCADING_VARIABLES, dglCSS_DEVICE_ADAPTATION,
      dglCSS_DISPLAY, dglCSS_FLEXIBLE_BOX_LAYOUT, dglCSS_FONTS,
      dglCSS_FRAGMENTATION, dglCSS_FREQUENCIES, dglCSS_GENERATED_CONTENT,
      dglCSS_GRID_LAYOUT, dglCSS_HOUDINI, dglCSS_IMAGES, dglCSS_INLINE,
      dglCSS_LENGTHS, dglCSS_LISTS_AND_COUNTERS, dglCSS_LOGICAL_PROPERTIES,
      dglCSS_MASKING, dglCSS_MOTION_PATH, dglCSS_MULTI_COLUMN_LAYOUT,
      dglCSS_NAMESPACES, dglCSS_OVERFLOW, dglCSS_OVERSCROLL_BEHAVIOR,
      dglCSS_PAGED_MEDIA, dglCSS_POSITIONING, dglCSS_RESOLUTIONS, dglCSS_RUBY,
      dglCSS_SCROLL_ANCHORING, dglCSS_SCROLLBARS, dglCSS_SCROLL_SNAP,
      dglCSS_SHADOW_PARTS, dglCSS_SHAPES, dglCSS_SPEECH, dglCSS_SYNTAX,
      dglCSS_TABLE, dglCSS_TEXT, dglCSS_TEXT_DECORATION, dglCSS_TIMES,
      dglCSS_TRANSFORMS, dglCSS_TRANSITIONS, dglCSS_TYPES, dglCSS_UNITS,
      dglCSS_VIEW_TRANSITIONS, dglCSS_WILL_CHANGE, dglCSS_WRITING_MODES,
      dglCSSOM_VIEW, dglFILTER_EFFECTS, dglGROUPING_SELECTORS, dglMATH_ML,
      dglMEDIA_QUERIES, dglMICROSOFT_EXTENSIONS, dglMOZILLA_EXTENSIONS,
      dglPOINTER_EVENTS, dglPSEUDO, dglPSEUDO_CLASSES, dglPSEUDO_ELEMENTS,
      dglSELECTORS, dglSCALABLE_VECTOR_GRAPHICS, dglWEB_KIT_EXTENSIONS
  type
    AtRuleValueGroups* = seq[definitionsGroupList]
  type
    AtRuleValueDescriptorsValueMediaVariant0* = enum
      arvdvmvALL, arvdvmvCONTINUOUS, arvdvmvPAGED, arvdvmvVISUAL
  type
    AtRuleValueDescriptorsValueMediaVariant1Item* = enum
      arvdvmviCONTINUOUS, arvdvmviPAGED, arvdvmviVISUAL
  type
    AtRuleValueDescriptorsValueMediaVariant1* = seq[
        AtRuleValueDescriptorsValueMediaVariant1Item]
  type
    AtRuleValueDescriptorsValueMediaKind* = enum
      Variant0, Variant1
  type
    AtRuleValueDescriptorsValueMedia* = object
      case kind*: AtRuleValueDescriptorsValueMediaKind
      of Variant0:
          value0*: AtRuleValueDescriptorsValueMediaVariant0

      of Variant1:
          value1*: AtRuleValueDescriptorsValueMediaVariant1

    
  type
    AtRuleValueDescriptorsValueOrder* = enum
      arvdvoORDER_OF_APPEARANCE, arvdvoUNIQUE_ORDER
  type
    AtRuleValueDescriptorsValueStatus* = enum
      arvdvsSTANDARD, arvdvsNONSTANDARD, arvdvsEXPERIMENTAL, arvdvsOBSOLETE
  type
    AtRuleValueDescriptorsValue* = object
      syntax*: string
      media*: AtRuleValueDescriptorsValueMedia
      initial*: AtRuleDefinitionsStringOrPropertyList
      percentages*: AtRuleDefinitionsStringOrPropertyList
      computed*: AtRuleDefinitionsStringOrPropertyList
      order*: AtRuleValueDescriptorsValueOrder
      status*: AtRuleValueDescriptorsValueStatus
      mdn_url*: string

  type
    AtRuleValueDescriptors* = Table[string, AtRuleValueDescriptorsValue]
  type
    AtRuleValueStatus* = enum
      arvsSTANDARD, arvsNONSTANDARD, arvsEXPERIMENTAL, arvsOBSOLETE
  type
    AtRuleValue* = object
      syntax*: string
      interfaces*: AtRuleValueInterfaces
      groups*: AtRuleValueGroups
      descriptors*: AtRuleValueDescriptors
      status*: AtRuleValueStatus
      mdn_url*: string

  type
    AtRule* = Table[string, AtRuleValue]
  ```

  #### Also generates these hooks:
  ```nim
  proc enumHook*(s: string; v: var definitionsGroupList) =
    var definitionsGroupListTable: Table[string, definitionsGroupList] = initTable[
        string, definitionsGroupList]()
    definitionsGroupListTable["Basic Selectors"] = definitionsGroupList.dglBASIC_SELECTORS
    definitionsGroupListTable["Combinators"] = definitionsGroupList.dglCOMBINATORS
    definitionsGroupListTable["Compositing and Blending"] = definitionsGroupList.dglCOMPOSITING_AND_BLENDING
    definitionsGroupListTable["CSS Angles"] = definitionsGroupList.dglCSS_ANGLES
    definitionsGroupListTable["CSS Animations"] = definitionsGroupList.dglCSS_ANIMATIONS
    definitionsGroupListTable["CSS Backgrounds and Borders"] = definitionsGroupList.dglCSS_BACKGROUNDS_AND_BORDERS
    definitionsGroupListTable["CSS Basic User Interface"] = definitionsGroupList.dglCSS_BASIC_USER_INTERFACE
    definitionsGroupListTable["CSS Box Alignment"] = definitionsGroupList.dglCSS_BOX_ALIGNMENT
    definitionsGroupListTable["CSS Box Model"] = definitionsGroupList.dglCSS_BOX_MODEL
    definitionsGroupListTable["CSS Box Sizing"] = definitionsGroupList.dglCSS_BOX_SIZING
    definitionsGroupListTable["CSS Cascading and Inheritance"] = definitionsGroupList.dglCSS_CASCADING_AND_INHERITANCE
    definitionsGroupListTable["CSS Color"] = definitionsGroupList.dglCSS_COLOR
    definitionsGroupListTable["CSS Conditional Rules"] = definitionsGroupList.dglCSS_CONDITIONAL_RULES
    definitionsGroupListTable["CSS Containment"] = definitionsGroupList.dglCSS_CONTAINMENT
    definitionsGroupListTable["CSS Counter Styles"] = definitionsGroupList.dglCSS_COUNTER_STYLES
    definitionsGroupListTable["CSS Custom Properties for Cascading Variables"] = definitionsGroupList.dglCSS_CUSTOM_PROPERTIES_FOR_CASCADING_VARIABLES
    definitionsGroupListTable["CSS Device Adaptation"] = definitionsGroupList.dglCSS_DEVICE_ADAPTATION
    definitionsGroupListTable["CSS Display"] = definitionsGroupList.dglCSS_DISPLAY
    definitionsGroupListTable["CSS Flexible Box Layout"] = definitionsGroupList.dglCSS_FLEXIBLE_BOX_LAYOUT
    definitionsGroupListTable["CSS Fonts"] = definitionsGroupList.dglCSS_FONTS
    definitionsGroupListTable["CSS Fragmentation"] = definitionsGroupList.dglCSS_FRAGMENTATION
    definitionsGroupListTable["CSS Frequencies"] = definitionsGroupList.dglCSS_FREQUENCIES
    definitionsGroupListTable["CSS Generated Content"] = definitionsGroupList.dglCSS_GENERATED_CONTENT
    definitionsGroupListTable["CSS Grid Layout"] = definitionsGroupList.dglCSS_GRID_LAYOUT
    definitionsGroupListTable["CSS Houdini"] = definitionsGroupList.dglCSS_HOUDINI
    definitionsGroupListTable["CSS Images"] = definitionsGroupList.dglCSS_IMAGES
    definitionsGroupListTable["CSS Inline"] = definitionsGroupList.dglCSS_INLINE
    definitionsGroupListTable["CSS Lengths"] = definitionsGroupList.dglCSS_LENGTHS
    definitionsGroupListTable["CSS Lists and Counters"] = definitionsGroupList.dglCSS_LISTS_AND_COUNTERS
    definitionsGroupListTable["CSS Logical Properties"] = definitionsGroupList.dglCSS_LOGICAL_PROPERTIES
    definitionsGroupListTable["CSS Masking"] = definitionsGroupList.dglCSS_MASKING
    definitionsGroupListTable["CSS Motion Path"] = definitionsGroupList.dglCSS_MOTION_PATH
    definitionsGroupListTable["CSS Multi-column Layout"] = definitionsGroupList.dglCSS_MULTI_COLUMN_LAYOUT
    definitionsGroupListTable["CSS Namespaces"] = definitionsGroupList.dglCSS_NAMESPACES
    definitionsGroupListTable["CSS Overflow"] = definitionsGroupList.dglCSS_OVERFLOW
    definitionsGroupListTable["CSS Overscroll Behavior"] = definitionsGroupList.dglCSS_OVERSCROLL_BEHAVIOR
    definitionsGroupListTable["CSS Paged Media"] = definitionsGroupList.dglCSS_PAGED_MEDIA
    definitionsGroupListTable["CSS Positioning"] = definitionsGroupList.dglCSS_POSITIONING
    definitionsGroupListTable["CSS Resolutions"] = definitionsGroupList.dglCSS_RESOLUTIONS
    definitionsGroupListTable["CSS Ruby"] = definitionsGroupList.dglCSS_RUBY
    definitionsGroupListTable["CSS Scroll Anchoring"] = definitionsGroupList.dglCSS_SCROLL_ANCHORING
    definitionsGroupListTable["CSS Scrollbars"] = definitionsGroupList.dglCSS_SCROLLBARS
    definitionsGroupListTable["CSS Scroll Snap"] = definitionsGroupList.dglCSS_SCROLL_SNAP
    definitionsGroupListTable["CSS Shadow Parts"] = definitionsGroupList.dglCSS_SHADOW_PARTS
    definitionsGroupListTable["CSS Shapes"] = definitionsGroupList.dglCSS_SHAPES
    definitionsGroupListTable["CSS Speech"] = definitionsGroupList.dglCSS_SPEECH
    definitionsGroupListTable["CSS Syntax"] = definitionsGroupList.dglCSS_SYNTAX
    definitionsGroupListTable["CSS Table"] = definitionsGroupList.dglCSS_TABLE
    definitionsGroupListTable["CSS Text"] = definitionsGroupList.dglCSS_TEXT
    definitionsGroupListTable["CSS Text Decoration"] = definitionsGroupList.dglCSS_TEXT_DECORATION
    definitionsGroupListTable["CSS Times"] = definitionsGroupList.dglCSS_TIMES
    definitionsGroupListTable["CSS Transforms"] = definitionsGroupList.dglCSS_TRANSFORMS
    definitionsGroupListTable["CSS Transitions"] = definitionsGroupList.dglCSS_TRANSITIONS
    definitionsGroupListTable["CSS Types"] = definitionsGroupList.dglCSS_TYPES
    definitionsGroupListTable["CSS Units"] = definitionsGroupList.dglCSS_UNITS
    definitionsGroupListTable["CSS View Transitions"] = definitionsGroupList.dglCSS_VIEW_TRANSITIONS
    definitionsGroupListTable["CSS Will Change"] = definitionsGroupList.dglCSS_WILL_CHANGE
    definitionsGroupListTable["CSS Writing Modes"] = definitionsGroupList.dglCSS_WRITING_MODES
    definitionsGroupListTable["CSSOM View"] = definitionsGroupList.dglCSSOM_VIEW
    definitionsGroupListTable["Filter Effects"] = definitionsGroupList.dglFILTER_EFFECTS
    definitionsGroupListTable["Grouping Selectors"] = definitionsGroupList.dglGROUPING_SELECTORS
    definitionsGroupListTable["MathML"] = definitionsGroupList.dglMATH_ML
    definitionsGroupListTable["Media Queries"] = definitionsGroupList.dglMEDIA_QUERIES
    definitionsGroupListTable["Microsoft Extensions"] = definitionsGroupList.dglMICROSOFT_EXTENSIONS
    definitionsGroupListTable["Mozilla Extensions"] = definitionsGroupList.dglMOZILLA_EXTENSIONS
    definitionsGroupListTable["Pointer Events"] = definitionsGroupList.dglPOINTER_EVENTS
    definitionsGroupListTable["Pseudo"] = definitionsGroupList.dglPSEUDO
    definitionsGroupListTable["Pseudo-classes"] = definitionsGroupList.dglPSEUDO_CLASSES
    definitionsGroupListTable["Pseudo-elements"] = definitionsGroupList.dglPSEUDO_ELEMENTS
    definitionsGroupListTable["Selectors"] = definitionsGroupList.dglSELECTORS
    definitionsGroupListTable["Scalable Vector Graphics"] = definitionsGroupList.dglSCALABLE_VECTOR_GRAPHICS
    definitionsGroupListTable["WebKit Extensions"] = definitionsGroupList.dglWEB_KIT_EXTENSIONS
    v = definitionsGroupListTable[s]

  proc enumHook*(s: string;
                v: var AtRuleValueDescriptorsValueMediaVariant0) =
    var AtRuleValueDescriptorsValueMediaVariant0Table: Table[string,
        AtRuleValueDescriptorsValueMediaVariant0] = initTable[string,
        AtRuleValueDescriptorsValueMediaVariant0]()
    AtRuleValueDescriptorsValueMediaVariant0Table["all"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvALL
    AtRuleValueDescriptorsValueMediaVariant0Table["continuous"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvCONTINUOUS
    AtRuleValueDescriptorsValueMediaVariant0Table["paged"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvPAGED
    AtRuleValueDescriptorsValueMediaVariant0Table["visual"] = AtRuleValueDescriptorsValueMediaVariant0.arvdvmvVISUAL
    v = AtRuleValueDescriptorsValueMediaVariant0Table[s]

  proc enumHook*(s: string;
                v: var AtRuleValueDescriptorsValueMediaVariant1Item) =
    var AtRuleValueDescriptorsValueMediaVariant1ItemTable: Table[string,
        AtRuleValueDescriptorsValueMediaVariant1Item] = initTable[string,
        AtRuleValueDescriptorsValueMediaVariant1Item]()
    AtRuleValueDescriptorsValueMediaVariant1ItemTable["continuous"] = AtRuleValueDescriptorsValueMediaVariant1Item.arvdvmviCONTINUOUS
    AtRuleValueDescriptorsValueMediaVariant1ItemTable["paged"] = AtRuleValueDescriptorsValueMediaVariant1Item.arvdvmviPAGED
    AtRuleValueDescriptorsValueMediaVariant1ItemTable["visual"] = AtRuleValueDescriptorsValueMediaVariant1Item.arvdvmviVISUAL
    v = AtRuleValueDescriptorsValueMediaVariant1ItemTable[s]

  proc enumHook*(s: string;
                v: var AtRuleValueDescriptorsValueOrder) =
    var AtRuleValueDescriptorsValueOrderTable: Table[string,
        AtRuleValueDescriptorsValueOrder] = initTable[string,
        AtRuleValueDescriptorsValueOrder]()
    AtRuleValueDescriptorsValueOrderTable["orderOfAppearance"] = AtRuleValueDescriptorsValueOrder.arvdvoORDER_OF_APPEARANCE
    AtRuleValueDescriptorsValueOrderTable["uniqueOrder"] = AtRuleValueDescriptorsValueOrder.arvdvoUNIQUE_ORDER
    v = AtRuleValueDescriptorsValueOrderTable[s]

  proc enumHook*(s: string;
                v: var AtRuleValueDescriptorsValueStatus) =
    var AtRuleValueDescriptorsValueStatusTable: Table[string,
        AtRuleValueDescriptorsValueStatus] = initTable[string,
        AtRuleValueDescriptorsValueStatus]()
    AtRuleValueDescriptorsValueStatusTable["standard"] = AtRuleValueDescriptorsValueStatus.arvdvsSTANDARD
    AtRuleValueDescriptorsValueStatusTable["nonstandard"] = AtRuleValueDescriptorsValueStatus.arvdvsNONSTANDARD
    AtRuleValueDescriptorsValueStatusTable["experimental"] = AtRuleValueDescriptorsValueStatus.arvdvsEXPERIMENTAL
    AtRuleValueDescriptorsValueStatusTable["obsolete"] = AtRuleValueDescriptorsValueStatus.arvdvsOBSOLETE
    v = AtRuleValueDescriptorsValueStatusTable[s]

  proc enumHook*(s: string; v: var AtRuleValueStatus) =
    var AtRuleValueStatusTable: Table[string, AtRuleValueStatus] = initTable[
        string, AtRuleValueStatus]()
    AtRuleValueStatusTable["standard"] = AtRuleValueStatus.arvsSTANDARD
    AtRuleValueStatusTable["nonstandard"] = AtRuleValueStatus.arvsNONSTANDARD
    AtRuleValueStatusTable["experimental"] = AtRuleValueStatus.arvsEXPERIMENTAL
    AtRuleValueStatusTable["obsolete"] = AtRuleValueStatus.arvsOBSOLETE
    v = AtRuleValueStatusTable[s]

  proc parseHook*(s: string; i: var int;
                  v: var AtRuleValueDescriptorsValueMedia) =
    var jsonStr: string
    var jsn: RawJson
    parseHook(s, i, jsn)
    jsonStr = jsn.toJson()
    try:
      var tempValue: AtRuleValueDescriptorsValueMediaVariant0
      tempValue = fromJson(jsonStr,
                                  AtRuleValueDescriptorsValueMediaVariant0)
      v = AtRuleValueDescriptorsValueMedia(
          kind: AtRuleValueDescriptorsValueMediaKind.Variant0,
          value0: tempValue)
      return
    except:
      discard
    try:
      var tempValue: AtRuleValueDescriptorsValueMediaVariant1
      tempValue = fromJson(jsonStr,
                                  AtRuleValueDescriptorsValueMediaVariant1)
      v = AtRuleValueDescriptorsValueMedia(
          kind: AtRuleValueDescriptorsValueMediaKind.Variant1,
          value1: tempValue)
      return
    except:
      discard
    raise newException(ValueError, "Could not parse any variant for " &
        "AtRuleValueDescriptorsValueMedia")

  proc dumpHook*(s: var string; v: AtRuleValueDescriptorsValueMedia) =
    case v.kind
    of AtRuleValueDescriptorsValueMediaKind.Variant0:
      s = toJson(v.value0)
    of AtRuleValueDescriptorsValueMediaKind.Variant1:
      s = toJson(v.value1)
    
  proc parseHook*(s: string; i: var int;
                  v: var AtRuleDefinitionsStringOrPropertyList) =
    var jsonStr: string
    var jsn: RawJson
    parseHook(s, i, jsn)
    jsonStr = jsn.toJson()
    try:
      var tempValue: AtRuleDefinitionsStringOrPropertyListVariant0
      tempValue = fromJson(jsonStr,
                                    AtRuleDefinitionsStringOrPropertyListVariant0)
      v = AtRuleDefinitionsStringOrPropertyList(
          kind: AtRuleDefinitionsStringOrPropertyListKind.Variant0,
          value0: tempValue)
      return
    except:
      discard
    try:
      var tempValue: AtRuleDefinitionsStringOrPropertyListVariant1
      tempValue = fromJson(jsonStr,
                                    AtRuleDefinitionsStringOrPropertyListVariant1)
      v = AtRuleDefinitionsStringOrPropertyList(
          kind: AtRuleDefinitionsStringOrPropertyListKind.Variant1,
          value1: tempValue)
      return
    except:
      discard
    raise newException(ValueError, "Could not parse any variant for " &
        "AtRuleDefinitionsStringOrPropertyList")

  proc dumpHook*(s: var string; v: AtRuleDefinitionsStringOrPropertyList) =
    case v.kind
    of AtRuleDefinitionsStringOrPropertyListKind.Variant0:
      s = toJson(v.value0)
    of AtRuleDefinitionsStringOrPropertyListKind.Variant1:
      s = toJson(v.value1)
  ```
</details>


#### Unions
Nim enforces a single-type constraint on all values, JSON schema allows unions. To make this possible we make use of "Variants", this looks as follows:
```nim
# Variant Values
type
  PropertiesValueMediaVariant0* = enum
    pvmvALL, pvmvAURAL, pvmvCONTINUOUS, pvmvINTERACTIVE, pvmvNONE,
    pvmvNO_PRACTICAL_MEDIA, pvmvPAGED, pvmvVISUAL,
    pvmvVISUAL_IN_CONTINUOUS_MEDIA_NO_EFFECT_IN_OVERFLOW_COLUMNS
type
  PropertiesValueMediaVariant1Item* = enum
    pvmviINTERACTIVE, pvmviPAGED, pvmviVISUAL
type
  PropertiesValueMediaVariant1* = seq[PropertiesValueMediaVariant1Item]
# Variant Kinds
type
  PropertiesValueMediaKind* = enum
    Variant0, Variant1
# Main Object
type
  PropertiesValueMedia* = object
    case kind*: PropertiesValueMediaKind
    of Variant0:
        value0*: PropertiesValueMediaVariant0

    of Variant1:
        value1*: PropertiesValueMediaVariant1
```
This serialization works both ways, *to and from* by generating associated `dumpHook()` and `parseHook()`s alongisde generated types.

#### Multi-file Reference Supported
Simply ensure a file referenced is loaded using `fromSchema`


### Small QOL Procedures

`parse[T](str: string)` / `to[T](str: string)` / `to[T](str: string, T: typedesc)`
```nim
let anObject = parse[AnObject]("""{ "name": "hello", "some_value": "world!" }""")
let anObject2 = to[AnObject]("""{ "name": "hello", "some_value": "world!" }""")
let anObject3 = """{ "name": "hello", "some_value": "world!" }""".to(AnObject)
```

`isEmpty[T](x: T)`
Creates a default T and compares to x, if matching- x is blank/empty/default
```nim
echo AnObject().isEmpty() # returns 'true'
```

`isOf[T](str: string)`
Parses str as T, and checks if empty.
*jsony is "loose", anything not AnObject will parse- but be empty*
If two objects share a field name, this will not work- making this very silly
```nim
type NotAnObject =
  something: int

echo """{"name": "hello"}""".isOf(NotAnObject) # false
echo """{"name": "hello"}""".isOf(AnObject)    # true
```

`tryParse[T](str: string)`
Parses, then checks if not empty

`pretty(str: string)`
Pretties an inline JSON string, akin to json.pretty

#### TODO
* Expand `fromSchema` to support the entire spec
* Expand `fromSchema` to allow an optional body, DSL guides type naming
* Extend hooks to be easier to use
* Replace `isOf` entirely
