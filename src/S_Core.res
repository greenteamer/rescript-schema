@@uncurried

type never

external castAnyToUnknown: 'any => unknown = "%identity"
external castUnknownToAny: unknown => 'any = "%identity"

module Obj = {
  external magic: 'a => 'b = "%identity"
}

module Stdlib = {
  module Type = {
    type t = [#undefined | #object | #boolean | #number | #bigint | #string | #symbol | #function]

    external typeof: 'a => t = "#typeof"
  }

  module Promise = {
    type t<+'a> = promise<'a>

    @send
    external thenResolveWithCatch: (t<'a>, 'a => 'b, Js.Exn.t => 'b) => t<'b> = "then"

    @send
    external thenResolve: (t<'a>, 'a => 'b) => t<'b> = "then"

    @val @scope("Promise")
    external resolve: 'a => t<'a> = "resolve"
  }

  module Re = {
    @send
    external toString: Js.Re.t => string = "toString"
  }

  module Object = {
    @val
    external overrideWith: ('object, 'object) => unit = "Object.assign"

    @val external internalClass: Js.Types.obj_val => string = "Object.prototype.toString.call"
  }

  module Set = {
    type t<'value>

    @new
    external empty: unit => t<'value> = "Set"

    @send
    external has: (t<'value>, 'value) => bool = "has"

    @send
    external add: (t<'value>, 'value) => t<'value> = "add"

    @new
    external fromArray: array<'value> => t<'value> = "Set"

    @val("Array.from")
    external toArray: t<'value> => array<'value> = "from"
  }

  module Array = {
    @inline
    let unique = array => array->Set.fromArray->Set.toArray

    @send
    external append: (array<'a>, 'a) => array<'a> = "concat"

    @inline
    let has = (array, idx) => {
      array->Js.Array2.unsafe_get(idx)->(Obj.magic: 'a => bool)
    }

    let isArray = Js.Array2.isArray
  }

  module Exn = {
    type error

    @new
    external makeError: string => error = "Error"

    let raiseAny = (any: 'any): 'a => any->Obj.magic->raise

    let raiseError: error => 'a = raiseAny
  }

  module Int = {
    @inline
    let plus = (int1: int, int2: int): int => {
      (int1->Js.Int.toFloat +. int2->Js.Int.toFloat)->(Obj.magic: float => int)
    }

    external unsafeToString: int => string = "%identity"
  }

  module Dict = {
    @val
    external copy: (@as(json`{}`) _, Js.Dict.t<'a>) => Js.Dict.t<'a> = "Object.assign"

    @inline
    let has = (dict, key) => {
      dict->Js.Dict.unsafeGet(key)->(Obj.magic: 'a => bool)
    }

    @inline
    let deleteInPlace = (dict, key) => {
      Js.Dict.unsafeDeleteKey(dict->(Obj.magic: Js.Dict.t<'a> => Js.Dict.t<string>), key)
    }

    let mapValues: (Js.Dict.t<'a>, 'a => 'b) => Js.Dict.t<'b> = %raw(`(dict, fn)=>{
      var key,newDict = {};
      for (key in dict) {
        newDict[key] = fn(dict[key])
      }
      return newDict
    }`)

    let every: (Js.Dict.t<'a>, 'a => bool) => bool = %raw(`(dict, fn)=>{
      for (var key in dict) {
        if (!fn(dict[key])) {
          return false
        }
      }
      return true
    }`)
  }

  module Float = {
    external unsafeToString: float => string = "%identity"
  }

  module Bool = {
    external unsafeToString: bool => string = "%identity"
  }

  module BigInt = {
    type t = Js.Types.bigint_val

    let unsafeToString = bigInt => {
      bigInt->(Obj.magic: t => string) ++ "n"
    }
  }

  module Function = {
    @variadic @new
    external _make: array<string> => 'function = "Function"

    @inline
    let make2 = (~ctxVarName1, ~ctxVarValue1, ~ctxVarName2, ~ctxVarValue2, ~inlinedFunction) => {
      _make([ctxVarName1, ctxVarName2, `return ${inlinedFunction}`])(ctxVarValue1, ctxVarValue2)
    }
  }

  module Symbol = {
    type t = Js.Types.symbol

    @val external make: string => t = "Symbol"

    @send external toString: t => string = "toString"
  }

  module Inlined = {
    module Value = {
      @inline
      let stringify = any => {
        if any === %raw("void 0") {
          "undefined"
        } else {
          any->Js.Json.stringifyAny->Obj.magic
        }
      }

      @inline
      let fromString = (string: string): string => string->Js.Json.stringifyAny->Obj.magic
    }

    module Float = {
      @inline
      let toRescript = float => float->Js.Float.toString ++ (mod_float(float, 1.) === 0. ? "." : "")
    }
  }
}

module Literal = {
  open Stdlib

  type rec t =
    | String(string)
    | Number(float)
    | Boolean(bool)
    | BigInt(Js.Types.bigint_val)
    | Symbol(Js.Types.symbol)
    | Array(array<t>)
    | Dict(Js.Dict.t<t>)
    | Function(Js.Types.function_val)
    | Object(Js.Types.obj_val)
    | Null
    | Undefined
    | NaN

  let rec classify = (value): t => {
    let typeOfValue = value->Type.typeof
    switch typeOfValue {
    | #undefined => Undefined
    | #object if value === %raw(`null`) => Null
    | #object if value->Stdlib.Array.isArray =>
      Array(value->(Obj.magic: 'a => array<'b>)->Js.Array2.map(i => i->classify))
    | #object
      if (value->(Obj.magic: 'a => {"constructor": unknown}))["constructor"] === %raw("Object") =>
      Dict(value->(Obj.magic: 'a => Js.Dict.t<'b>)->Dict.mapValues(classify))
    | #object => Object(value->(Obj.magic: 'a => Js.Types.obj_val))
    | #function => Function(value->(Obj.magic: 'a => Js.Types.function_val))
    | #string => String(value->(Obj.magic: 'a => string))
    | #number if value->(Obj.magic: 'a => float)->Js.Float.isNaN => NaN
    | #number => Number(value->(Obj.magic: 'a => float))
    | #boolean => Boolean(value->(Obj.magic: 'a => bool))
    | #symbol => Symbol(value->(Obj.magic: 'a => Js.Types.symbol))
    | #bigint => BigInt(value->(Obj.magic: 'a => Js.Types.bigint_val))
    }
  }

  let rec value = literal => {
    switch literal {
    | NaN => %raw(`NaN`)
    | Undefined => %raw(`undefined`)
    | Null => %raw(`null`)
    | Number(v) => v->castAnyToUnknown
    | Boolean(v) => v->castAnyToUnknown
    | BigInt(v) => v->castAnyToUnknown
    | String(v) => v->castAnyToUnknown
    | Object(v) => v->castAnyToUnknown
    | Function(v) => v->castAnyToUnknown
    | Symbol(v) => v->castAnyToUnknown
    | Array(v) => v->Js.Array2.map(value)->castAnyToUnknown
    | Dict(v) => v->Dict.mapValues(value)->castAnyToUnknown
    }
  }

  let rec isJsonable = literal => {
    switch literal {
    | Null
    | Number(_)
    | Boolean(_)
    | String(_) => true
    | NaN
    | Undefined
    | BigInt(_)
    | Object(_)
    | Function(_)
    | Symbol(_) => false
    | Array(v) => v->Js.Array2.every(isJsonable)
    | Dict(v) => v->Dict.every(isJsonable)
    }
  }

  let rec toText = literal => {
    switch literal {
    | NaN => `NaN`
    | Undefined => `undefined`
    | Null => `null`
    | Number(v) => v->Float.unsafeToString
    | Boolean(v) => v->Bool.unsafeToString
    | BigInt(v) => v->BigInt.unsafeToString
    | String(v) => v->Inlined.Value.fromString
    | Object(v) => v->Object.internalClass
    | Function(_) => "[object Function]"
    | Symbol(v) => v->Symbol.toString
    | Array(v) => `[${v->Js.Array2.map(toText)->Js.Array2.joinWith(", ")}]`
    | Dict(v) =>
      `{${v
        ->Js.Dict.keys
        ->Js.Array2.map(key =>
          `${key->Inlined.Value.fromString}: ${toText(v->Js.Dict.unsafeGet(key))}`
        )
        ->Js.Array2.joinWith(", ")}}`
    }
  }
}

module Path = {
  type t = string

  external toString: t => string = "%identity"

  @inline
  let empty = ""

  @inline
  let dynamic = "[]"

  let toArray = path => {
    switch path {
    | "" => []
    | _ =>
      path
      ->Js.String2.split(`"]["`)
      ->Js.Array2.joinWith(`","`)
      ->Js.Json.parseExn
      ->(Obj.magic: Js.Json.t => array<string>)
    }
  }

  @inline
  let fromInlinedLocation = inlinedLocation => `[${inlinedLocation}]`

  @inline
  let fromLocation = location => `[${location->Stdlib.Inlined.Value.fromString}]`

  let fromArray = array => {
    switch array {
    | [] => ""
    | [location] => fromLocation(location)
    | _ =>
      "[" ++ array->Js.Array2.map(Stdlib.Inlined.Value.fromString)->Js.Array2.joinWith("][") ++ "]"
    }
  }

  let concat = (path, concatedPath) => path ++ concatedPath
}

let symbol = Stdlib.Symbol.make("rescript-struct")

@unboxed
type isAsyncParse = | @as(0) Unknown | Value(bool)
type unknownKeys = Strip | Strict

type rec t<'value> = {
  @as("t")
  tagged: tagged,
  @as("n")
  name: unit => string,
  @as("p")
  mutable parseOperationBuilder: builder,
  @as("s")
  mutable serializeOperationBuilder: builder,
  @as("f")
  maybeTypeFilter: option<(~inputVar: string) => string>,
  @as("i")
  mutable isAsyncParse: isAsyncParse,
  @as("m")
  metadataMap: Js.Dict.t<unknown>,
}
and tagged =
  | Never
  | Unknown
  | String
  | Int
  | Float
  | Bool
  | Literal(Literal.t)
  | Option(t<unknown>)
  | Null(t<unknown>)
  | Array(t<unknown>)
  | Object({fields: Js.Dict.t<t<unknown>>, fieldNames: array<string>, unknownKeys: unknownKeys})
  | Tuple(array<t<unknown>>)
  | Union(array<t<unknown>>)
  | Dict(t<unknown>)
  | JSON
and builder
and builderCtx = {
  @as("a")
  mutable isAsyncBranch: bool,
  @as("c")
  mutable code: string,
  @as("o")
  operation: operation,
  @as("v")
  mutable _varCounter: int,
  @as("s")
  mutable _vars: Stdlib.Set.t<string>,
  @as("l")
  mutable _varsAllocation: string,
  @as("i")
  mutable _input: string,
  @as("e")
  _embeded: array<unknown>,
}
and operation =
  | Parsing
  | Serializing
and struct<'a> = t<'a>
type rec error = private {operation: operation, code: errorCode, path: Path.t}
and errorCode =
  | OperationFailed(string)
  | InvalidOperation({description: string})
  | InvalidType({expected: struct<unknown>, received: unknown})
  | InvalidLiteral({expected: Literal.t, received: unknown})
  | InvalidTupleSize({expected: int, received: int})
  | ExcessField(string)
  | InvalidUnion(array<error>)
  | UnexpectedAsync
  | InvalidJsonStruct(struct<unknown>)
type exn += private Raised(error)

external castUnknownStructToAnyStruct: t<unknown> => t<'any> = "%identity"
external toUnknown: t<'any> => t<unknown> = "%identity"

type payloadedVariant<'payload> = private {_0: 'payload}
type payloadedError<'payload> = private {_1: 'payload}
let unsafeGetVariantPayload = variant => (variant->Obj.magic)._0
let unsafeGetErrorPayload = variant => (variant->Obj.magic)._1

module InternalError = {
  %%raw(`
    class RescriptStructError extends Error {
      constructor(code, operation, path) {
        super();
        this.operation = operation;
        this.code = code;
        this.path = path;
        this.s = symbol;
        this.RE_EXN_ID = Raised;
        this._1 = this;
        this.Error = this;
        this.name = "RescriptStructError";
      }
      get message() {
        return message(this);
      }
      get reason() {
        return reason(this);
      }
    }
  `)

  @new
  external make: (~code: errorCode, ~operation: operation, ~path: Path.t) => error =
    "RescriptStructError"

  let getOrRethrow = (exn: exn) => {
    if %raw("exn&&exn.s===symbol") {
      exn->(Obj.magic: exn => error)
    } else {
      raise(%raw("exn&&exn.RE_EXN_ID==='JsError'") ? exn->unsafeGetErrorPayload : exn)
    }
  }

  @inline
  let raise = (~code, ~operation, ~path) => {
    Stdlib.Exn.raiseAny(make(~code, ~operation, ~path))
  }

  let prependLocationOrRethrow = (exn, location) => {
    let error = exn->getOrRethrow
    raise(
      ~path=Path.concat(location->Path.fromLocation, error.path),
      ~code=error.code,
      ~operation=error.operation,
    )
  }

  @inline
  let panic = message => Stdlib.Exn.raiseError(Stdlib.Exn.makeError(`[rescript-struct] ${message}`))
}

type effectCtx<'value> = {
  struct: t<'value>,
  fail: 'a. (string, ~path: Path.t=?) => 'a,
  failWithError: 'a. error => 'a,
}

module EffectCtx = {
  let make = (~selfStruct, ~path, ~operation) => {
    struct: selfStruct->castUnknownStructToAnyStruct,
    failWithError: (error: error) => {
      InternalError.raise(~path=path->Path.concat(error.path), ~code=error.code, ~operation)
    },
    fail: (message, ~path as customPath=Path.empty) => {
      InternalError.raise(
        ~path=path->Path.concat(customPath),
        ~code=OperationFailed(message),
        ~operation,
      )
    },
  }
}

@inline
let classify = struct => struct.tagged

module Builder = {
  type t = builder
  type ctx = builderCtx
  type implementation = (ctx, ~selfStruct: struct<unknown>, ~path: Path.t) => string

  let make = (Obj.magic: implementation => t)

  module Ctx = {
    type t = ctx

    @inline
    let embed = (b: t, value) => {
      `e[${(b._embeded->Js.Array2.push(value->castAnyToUnknown)->(Obj.magic: int => float) -. 1.)
          ->(Obj.magic: float => string)}]`
    }

    let scope = (b: t, fn) => {
      let prevVarsAllocation = b._varsAllocation
      let prevCode = b.code
      b._varsAllocation = ""
      b.code = ""
      let resultCode = fn(b)
      let varsAllocation = b._varsAllocation
      let code = varsAllocation === "" ? b.code : `let ${varsAllocation};${b.code}`
      b._varsAllocation = prevVarsAllocation
      b.code = prevCode
      code ++ resultCode
    }

    let varWithoutAllocation = (b: t) => {
      let newCounter = b._varCounter->Stdlib.Int.plus(1)
      b._varCounter = newCounter
      let v = `v${newCounter->Stdlib.Int.unsafeToString}`
      b._vars->Stdlib.Set.add(v)->ignore
      v
    }

    let var = (b: t) => {
      let v = b->varWithoutAllocation
      b._varsAllocation = b._varsAllocation === "" ? v : b._varsAllocation ++ "," ++ v
      v
    }

    @inline
    let useInput = b => {
      b._input
    }

    let toVar = (b, val) =>
      if b._vars->Stdlib.Set.has(val) {
        val
      } else {
        let var = b->var
        b.code = b.code ++ `${var}=${val};`
        var
      }

    @inline
    let useInputVar = b => {
      b->toVar(b->useInput)
    }

    @inline
    let isInternalError = (_b: t, var) => {
      `${var}&&${var}.s===s`
    }

    let transform = (b: t, ~input, ~isAsync, operation) => {
      if b.isAsyncBranch === true {
        let prevCode = b.code
        b.code = ""
        let inputVar = b->varWithoutAllocation
        let operationOutputVar = operation(b, ~input=inputVar)
        let outputVar = b->var
        b.code =
          prevCode ++
          `${outputVar}=()=>${input}().then(${inputVar}=>{${b.code}return ${operationOutputVar}${isAsync
              ? "()"
              : ""}});`
        outputVar
      } else if isAsync {
        b.isAsyncBranch = true
        // TODO: Would be nice to remove. Needed to enforce that async ops are always vars
        let outputVar = b->var
        b.code = b.code ++ `${outputVar}=${operation(b, ~input)};`
        outputVar
      } else {
        operation(b, ~input)
      }
    }

    let embedSyncOperation = (b: t, ~input, ~fn: 'input => 'output) => {
      b->transform(~input, ~isAsync=false, (b, ~input) => {
        `${b->embed(fn)}(${input})`
      })
    }

    let embedAsyncOperation = (b: t, ~input, ~fn: 'input => unit => promise<'output>) => {
      b->transform(~input, ~isAsync=true, (b, ~input) => {
        `${b->embed(fn)}(${input})`
      })
    }

    let raiseWithArg = (b: t, ~path, fn: 'arg => errorCode, arg) => {
      `${b->embed(arg => {
          InternalError.raise(~path, ~code=fn(arg), ~operation=b.operation)
        })}(${arg})`
    }

    let fail = (b: t, ~message, ~path) => {
      `${b->embed(() => {
          InternalError.raise(~path, ~code=OperationFailed(message), ~operation=b.operation)
        })}()`
    }

    let invalidOperation = (b: t, ~path, ~description) => {
      InternalError.raise(
        ~path,
        ~code=InvalidOperation({description: description}),
        ~operation=b.operation,
      )
    }

    let withCatch = (b: t, ~catch, fn) => {
      let prevCode = b.code

      b.code = ""
      let errorVar = b->varWithoutAllocation
      let maybeResolveVar = catch(b, ~errorVar)
      let catchCode = `if(${b->isInternalError(errorVar)}){${b.code}`

      b.code = ""
      let fnOutput = fn(b)
      let isAsync = b.isAsyncBranch
      let isInlined = !(b._vars->Stdlib.Set.has(fnOutput))

      let outputVar = isAsync || isInlined ? b->var : fnOutput

      let catchCode = switch maybeResolveVar {
      | None => _ => `${catchCode}}throw ${errorVar}`
      | Some(resolveVar) =>
        catchLocation =>
          catchCode ++
          switch catchLocation {
          | #0 if isAsync => `${outputVar}=()=>Promise.resolve(${resolveVar})`
          | #0 => `${outputVar}=${resolveVar}`
          | #1 => `return Promise.resolve(${resolveVar})`
          | #2 => `return ${resolveVar}`
          } ++
          `}else{throw ${errorVar}}`
      }

      b.code =
        prevCode ++
        `try{${b.code}${{
            switch (isAsync, isInlined) {
            | (true, _) =>
              `${outputVar}=()=>{try{return ${fnOutput}().catch(${errorVar}=>{${catchCode(
                  #2,
                )}})}catch(${errorVar}){${catchCode(#1)}}};`
            | (_, true) => `${outputVar}=${fnOutput}`
            | _ => ""
            }
          }}}catch(${errorVar}){${catchCode(#0)}}`

      outputVar
    }

    let withPathPrepend = (b: t, ~path, ~dynamicLocationVar as maybeDynamicLocationVar=?, fn) => {
      if path === Path.empty && maybeDynamicLocationVar === None {
        fn(b, ~path)
      } else {
        try b->withCatch(
          ~catch=(b, ~errorVar) => {
            b.code = `${errorVar}.path=${path->Stdlib.Inlined.Value.fromString}+${switch maybeDynamicLocationVar {
              | Some(var) => `'["'+${var}+'"]'+`
              | _ => ""
              }}${errorVar}.path`
            None
          },
          b => fn(b, ~path=Path.empty),
        ) catch {
        | Raised(error) =>
          InternalError.raise(
            ~path=path->Path.concat(Path.dynamic)->Path.concat(error.path),
            ~code=error.code,
            ~operation=error.operation,
          )
        }
      }
    }

    let typeFilterCode = (b: t, ~typeFilter, ~struct, ~inputVar, ~path) => {
      `if(${typeFilter(~inputVar)}){${b->raiseWithArg(
          ~path,
          input => InvalidType({
            expected: struct,
            received: input,
          }),
          inputVar,
        )}}`
    }

    let use = (b: t, ~struct, ~input, ~path) => {
      let isParentAsync = b.isAsyncBranch
      let isParsing = b.operation === Parsing
      b._input = input
      b.isAsyncBranch = false
      let output = (
        (isParsing ? struct.parseOperationBuilder : struct.serializeOperationBuilder)->(
          Obj.magic: builder => implementation
        )
      )(b, ~selfStruct=struct, ~path)
      if isParsing {
        struct.isAsyncParse = Value(b.isAsyncBranch)
        b.isAsyncBranch = isParentAsync || b.isAsyncBranch
      }
      output
    }

    let useWithTypeFilter = (b: t, ~struct, ~input, ~path) => {
      let input = switch struct.maybeTypeFilter {
      | Some(typeFilter) => {
          let inputVar = b->toVar(input)
          b.code = b.code ++ b->typeFilterCode(~struct, ~typeFilter, ~inputVar, ~path)
          inputVar
        }
      | None => input
      }
      b->use(~struct, ~input, ~path)
    }
  }

  let noop = make((b, ~selfStruct as _, ~path as _) => {
    b->Ctx.useInput
  })

  let noopOperation = i => i->Obj.magic

  @inline
  let intitialInputVar = "i"

  let build = (builder, ~struct, ~operation) => {
    let b = {
      _embeded: [],
      _varCounter: -1,
      _varsAllocation: "",
      _vars: Stdlib.Set.fromArray([intitialInputVar]),
      _input: intitialInputVar,
      code: "",
      isAsyncBranch: false,
      operation,
    }

    let output = (builder->(Obj.magic: builder => implementation))(
      b,
      ~selfStruct=struct,
      ~path=Path.empty,
    )

    if operation === Parsing {
      switch struct.maybeTypeFilter {
      | Some(typeFilter) =>
        b.code =
          b->Ctx.typeFilterCode(
            ~struct,
            ~typeFilter,
            ~inputVar=intitialInputVar,
            ~path=Path.empty,
          ) ++ b.code
      | None => ()
      }
      struct.isAsyncParse = Value(b.isAsyncBranch)
    }

    if b.code === "" && output === intitialInputVar {
      noopOperation
    } else {
      let inlinedFunction = `${intitialInputVar}=>{${b._varsAllocation === ""
          ? ""
          : `let ${b._varsAllocation};`}${b.code}return ${output}}`

      // Js.log(inlinedFunction)

      Stdlib.Function.make2(
        ~ctxVarName1="e",
        ~ctxVarValue1=b._embeded,
        ~ctxVarName2="s",
        ~ctxVarValue2=symbol,
        ~inlinedFunction,
      )
    }
  }
}
// TODO: Split validation code and transformation code
module B = Builder.Ctx

let toLiteral = {
  let rec loop = struct => {
    switch struct->classify {
    | Literal(literal) => literal
    | Union(unionStructs) => unionStructs->Js.Array2.unsafe_get(0)->loop
    | Tuple(tupleStructs) => Array(tupleStructs->Js.Array2.map(a => a->loop))
    | Object({fields}) => Dict(fields->Stdlib.Dict.mapValues(loop))
    | String
    | Int
    | Float
    | Bool
    | Option(_)
    | Null(_)
    | Never
    | Unknown
    | JSON
    | Array(_)
    | Dict(_) =>
      Stdlib.Exn.raiseAny(symbol)
    }
  }
  struct => {
    try {
      Some(loop(struct))
    } catch {
    | Js.Exn.Error(jsExn) =>
      jsExn->(Obj.magic: Js.Exn.t => Stdlib.Symbol.t) === symbol ? None : Stdlib.Exn.raiseAny(jsExn)
    }
  }
}

let isAsyncParse = struct => {
  let struct = struct->toUnknown
  switch struct.isAsyncParse {
  | Unknown =>
    try {
      let _ = struct.parseOperationBuilder->Builder.build(~struct, ~operation=Parsing)
      struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
    } catch {
    | exn => {
        let _ = exn->InternalError.getOrRethrow
        false
      }
    }
  | Value(v) => v
  }
}

let rec validateJsonableStruct = (struct, ~rootStruct, ~isRoot=false, ()) => {
  if isRoot || rootStruct !== struct {
    switch struct->classify {
    | String
    | Int
    | Float
    | Bool
    | Never
    | JSON => ()
    | Dict(struct)
    | Null(struct)
    | Array(struct) =>
      struct->validateJsonableStruct(~rootStruct, ())
    | Object({fieldNames, fields}) =>
      for idx in 0 to fieldNames->Js.Array2.length - 1 {
        let fieldName = fieldNames->Js.Array2.unsafe_get(idx)
        let fieldStruct = fields->Js.Dict.unsafeGet(fieldName)
        try {
          switch fieldStruct->classify {
          // Allow optional fields
          | Option(s) => s
          | _ => fieldStruct
          }->validateJsonableStruct(~rootStruct, ())
        } catch {
        | exn => exn->InternalError.prependLocationOrRethrow(fieldName)
        }
      }

    | Tuple(childrenStructs) =>
      childrenStructs->Js.Array2.forEachi((struct, i) => {
        try {
          struct->validateJsonableStruct(~rootStruct, ())
        } catch {
        // TODO: Should throw with the nested struct instead of prepending path?
        | exn => exn->InternalError.prependLocationOrRethrow(i->Js.Int.toString)
        }
      })
    | Union(childrenStructs) =>
      childrenStructs->Js.Array2.forEach(struct => struct->validateJsonableStruct(~rootStruct, ()))
    | Literal(l) if l->Literal.isJsonable => ()
    | Option(_)
    | Unknown
    | Literal(_) =>
      InternalError.raise(~path=Path.empty, ~code=InvalidJsonStruct(struct), ~operation=Serializing)
    }
  }
}

@inline
let make = (
  ~name,
  ~tagged,
  ~metadataMap,
  ~parseOperationBuilder,
  ~serializeOperationBuilder,
  ~maybeTypeFilter,
) => {
  tagged,
  parseOperationBuilder,
  serializeOperationBuilder,
  isAsyncParse: Unknown,
  maybeTypeFilter,
  name,
  metadataMap,
}

@inline
let makeWithNoopSerializer = (
  ~name,
  ~tagged,
  ~metadataMap,
  ~parseOperationBuilder,
  ~maybeTypeFilter,
) => {
  name,
  tagged,
  parseOperationBuilder,
  serializeOperationBuilder: Builder.noop,
  isAsyncParse: Unknown,
  maybeTypeFilter,
  metadataMap,
}

module Operation = {
  let unexpectedAsync = _ =>
    InternalError.raise(~path=Path.empty, ~code=UnexpectedAsync, ~operation=Parsing)

  type label =
    | @as("op") Parser | @as("opa") ParserAsync | @as("os") Serializer | @as("osj") SerializerToJson

  @inline
  let make = (~label: label, ~init: t<unknown> => 'input => 'output) => {
    (
      (i, s) => {
        try {
          (s->Obj.magic->Js.Dict.unsafeGet((label :> string)))(i)
        } catch {
        | _ =>
          if s->Obj.magic->Js.Dict.unsafeGet((label :> string))->Obj.magic {
            %raw(`exn`)->Stdlib.Exn.raiseAny
          } else {
            let o = init(s->Obj.magic)
            s->Obj.magic->Js.Dict.set((label :> string), o)
            o(i)
          }
        }
      }
    )->Obj.magic
  }
}

let parseAnyOrRaiseWith = Operation.make(~label=Parser, ~init=struct => {
  let operation = struct.parseOperationBuilder->Builder.build(~struct, ~operation=Parsing)
  let isAsync = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
  isAsync ? Operation.unexpectedAsync : operation
})

let parseAnyWith = (any, struct) => {
  try {
    parseAnyOrRaiseWith(any->castAnyToUnknown, struct)->castUnknownToAny->Ok
  } catch {
  | exn => exn->InternalError.getOrRethrow->Error
  }
}

let parseWith: (Js.Json.t, t<'value>) => result<'value, error> = parseAnyWith

let parseOrRaiseWith: (Js.Json.t, t<'value>) => 'value = parseAnyOrRaiseWith

let asyncPrepareOk = value => Ok(value->castUnknownToAny)

let asyncPrepareError = jsExn => {
  jsExn->(Obj.magic: Js.Exn.t => exn)->InternalError.getOrRethrow->Error
}

let internalParseAsyncWith = Operation.make(~label=ParserAsync, ~init=struct => {
  let operation = struct.parseOperationBuilder->Builder.build(~struct, ~operation=Parsing)
  let isAsync = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
  isAsync
    ? operation->(Obj.magic: (unknown => unknown) => unknown => unit => promise<unknown>)
    : input => {
        let syncValue = operation(input)
        () => syncValue->Stdlib.Promise.resolve
      }
})

let parseAnyAsyncWith = (any, struct) => {
  try {
    internalParseAsyncWith(any->castAnyToUnknown, struct)()->Stdlib.Promise.thenResolveWithCatch(
      asyncPrepareOk,
      asyncPrepareError,
    )
  } catch {
  | exn => exn->InternalError.getOrRethrow->Error->Stdlib.Promise.resolve
  }
}

let parseAsyncWith = parseAnyAsyncWith

let parseAnyAsyncInStepsWith = (any, struct) => {
  try {
    let asyncFn = internalParseAsyncWith(any->castAnyToUnknown, struct)
    (() => asyncFn()->Stdlib.Promise.thenResolveWithCatch(asyncPrepareOk, asyncPrepareError))->Ok
  } catch {
  | exn => exn->InternalError.getOrRethrow->Error
  }
}

let parseAsyncInStepsWith = parseAnyAsyncInStepsWith

let serializeOrRaiseWith = Operation.make(~label=SerializerToJson, ~init=struct => {
  try {
    struct->validateJsonableStruct(~rootStruct=struct, ~isRoot=true, ())
    // TODO: Move outside of the try/catch
    struct.serializeOperationBuilder->Builder.build(~struct, ~operation=Serializing)
  } catch {
  | exn => {
      let error = exn->InternalError.getOrRethrow
      _ => Stdlib.Exn.raiseAny(error)
    }
  }
})

let serializeWith = (value, struct) => {
  try {
    serializeOrRaiseWith(value, struct)->Ok
  } catch {
  | exn => exn->InternalError.getOrRethrow->Error
  }
}

let serializeToUnknownOrRaiseWith = Operation.make(~label=Serializer, ~init=struct => {
  struct.serializeOperationBuilder->Builder.build(~struct, ~operation=Serializing)
})

let serializeToUnknownWith = (value, struct) => {
  try {
    serializeToUnknownOrRaiseWith(value, struct)->Ok
  } catch {
  | exn => exn->InternalError.getOrRethrow->Error
  }
}

let serializeToJsonStringWith = (value: 'value, struct: t<'value>, ~space=0): result<
  string,
  error,
> => {
  switch value->serializeWith(struct) {
  | Ok(json) => Ok(json->Js.Json.stringifyWithSpace(space))
  | Error(_) as e => e
  }
}

let parseJsonStringWith = (json: string, struct: t<'value>): result<'value, error> => {
  switch try {
    json->Js.Json.parseExn->Ok
  } catch {
  | Js.Exn.Error(error) =>
    Error(
      InternalError.make(
        ~code=OperationFailed(error->Js.Exn.message->(Obj.magic: option<string> => string)),
        ~operation=Parsing,
        ~path=Path.empty,
      ),
    )
  } {
  | Ok(json) => json->parseWith(struct)
  | Error(_) as e => e
  }
}

module Metadata = {
  module Id: {
    type t<'metadata>
    let make: (~namespace: string, ~name: string) => t<'metadata>
    external toKey: t<'metadata> => string = "%identity"
  } = {
    type t<'metadata> = string

    let make = (~namespace, ~name) => {
      `${namespace}:${name}`
    }

    external toKey: t<'metadata> => string = "%identity"
  }

  module Map = {
    let empty = Js.Dict.empty()

    let set = (map, ~id: Id.t<'metadata>, metadata: 'metadata) => {
      map === empty
        ? %raw(`{[id]:metadata}`)
        : {
            let copy = map->Stdlib.Dict.copy
            copy->Js.Dict.set(id->Id.toKey, metadata->castAnyToUnknown)
            copy
          }
    }
  }

  let get = (struct, ~id: Id.t<'metadata>) => {
    struct.metadataMap->Js.Dict.unsafeGet(id->Id.toKey)->(Obj.magic: unknown => option<'metadata>)
  }

  let set = (struct, ~id: Id.t<'metadata>, metadata: 'metadata) => {
    let metadataMap = struct.metadataMap->Map.set(~id, metadata)
    make(
      ~name=struct.name,
      ~parseOperationBuilder=struct.parseOperationBuilder,
      ~serializeOperationBuilder=struct.serializeOperationBuilder,
      ~tagged=struct.tagged,
      ~maybeTypeFilter=struct.maybeTypeFilter,
      ~metadataMap,
    )
  }
}

let recursive = fn => {
  let placeholder: t<'value> = {"m": Metadata.Map.empty}->Obj.magic
  let struct = fn(placeholder)
  placeholder->Stdlib.Object.overrideWith(struct)

  {
    let builder = placeholder.parseOperationBuilder
    placeholder.parseOperationBuilder = Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      let isAsync = {
        selfStruct.parseOperationBuilder = Builder.noop
        let ctx = {
          _embeded: [],
          _varsAllocation: "",
          code: "",
          _input: Builder.intitialInputVar,
          _varCounter: -1,
          _vars: Stdlib.Set.fromArray([Builder.intitialInputVar]),
          isAsyncBranch: false,
          operation: Parsing,
        }
        let _ = (builder->(Obj.magic: builder => Builder.implementation))(ctx, ~selfStruct, ~path)
        ctx.isAsyncBranch
      }

      selfStruct.parseOperationBuilder = Builder.make((b, ~selfStruct, ~path as _) => {
        let input = b->B.useInput
        if isAsync {
          b->B.embedAsyncOperation(~input, ~fn=input => input->internalParseAsyncWith(selfStruct))
        } else {
          b->B.embedSyncOperation(~input, ~fn=input => input->parseAnyOrRaiseWith(selfStruct))
        }
      })

      let operation = builder->Builder.build(~struct=selfStruct, ~operation=Parsing)
      if isAsync {
        selfStruct->Obj.magic->Js.Dict.set((Operation.ParserAsync :> string), operation)
      } else {
        // TODO: Use init function
        selfStruct->Obj.magic->Js.Dict.set((Operation.Parser :> string), operation)
      }

      selfStruct.parseOperationBuilder = builder
      b->B.withPathPrepend(~path, (b, ~path as _) =>
        if isAsync {
          b->B.embedAsyncOperation(~input, ~fn=operation)
        } else {
          b->B.embedSyncOperation(~input, ~fn=operation)
        }
      )
    })
  }

  {
    let builder = placeholder.serializeOperationBuilder
    placeholder.serializeOperationBuilder = Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      selfStruct.serializeOperationBuilder = Builder.make((b, ~selfStruct, ~path as _) => {
        let input = b->B.useInput
        b->B.embedSyncOperation(
          ~input,
          ~fn=input => input->serializeToUnknownOrRaiseWith(selfStruct),
        )
      })

      let operation = builder->Builder.build(~struct=selfStruct, ~operation=Serializing)

      // TODO: Use init function
      // TODO: What about json validation ?? Check whether it works correctly
      selfStruct->Obj.magic->Js.Dict.set((Operation.Serializer :> string), operation)

      selfStruct.serializeOperationBuilder = builder
      b->B.withPathPrepend(~path, (b, ~path as _) => b->B.embedSyncOperation(~input, ~fn=operation))
    })
  }

  placeholder
}

let setName = (struct, name) => {
  make(
    ~name=() => name,
    ~parseOperationBuilder=struct.parseOperationBuilder,
    ~serializeOperationBuilder=struct.serializeOperationBuilder,
    ~tagged=struct.tagged,
    ~maybeTypeFilter=struct.maybeTypeFilter,
    ~metadataMap=struct.metadataMap,
  )
}

let primitiveName = () => {
  (%raw(`this`): t<'a>).tagged->(Obj.magic: tagged => string)
}

let containerName = () => {
  let tagged = (%raw(`this`): t<'a>).tagged->Obj.magic
  `${tagged["TAG"]}(${(tagged->unsafeGetVariantPayload).name()})`
}

let internalRefine = (struct, refiner) => {
  let struct = struct->toUnknown
  make(
    ~name=struct.name,
    ~tagged=struct.tagged,
    ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      b->B.transform(~input=b->B.use(~struct, ~input, ~path), ~isAsync=false, (b, ~input) => {
        let inputVar = b->B.toVar(input)
        b.code = b.code ++ refiner(b, ~inputVar, ~selfStruct, ~path)
        inputVar
      })
    }),
    ~serializeOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      b->B.use(
        ~struct,
        ~input=b->B.transform(~input, ~isAsync=false, (b, ~input) => {
          let inputVar = b->B.toVar(input)
          b.code = b.code ++ refiner(b, ~inputVar, ~selfStruct, ~path)
          inputVar
        }),
        ~path,
      )
    }),
    ~maybeTypeFilter=struct.maybeTypeFilter,
    ~metadataMap=struct.metadataMap,
  )
}

let refine: (t<'value>, effectCtx<'value> => 'value => unit) => t<'value> = (struct, refiner) => {
  struct->internalRefine((b, ~inputVar, ~selfStruct, ~path) => {
    `${b->B.embed(
        refiner(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)),
      )}(${inputVar});`
  })
}

let addRefinement = (struct, ~metadataId, ~refinement, ~refiner) => {
  struct
  ->Metadata.set(
    ~id=metadataId,
    switch struct->Metadata.get(~id=metadataId) {
    | Some(refinements) => refinements->Stdlib.Array.append(refinement)
    | None => [refinement]
    },
  )
  ->internalRefine(refiner)
}

type transformDefinition<'input, 'output> = {
  @as("p")
  parser?: 'input => 'output,
  @as("a")
  asyncParser?: 'input => unit => promise<'output>,
  @as("s")
  serializer?: 'output => 'input,
}
let transform: (
  t<'input>,
  effectCtx<'output> => transformDefinition<'input, 'output>,
) => t<'output> = (struct, transformer) => {
  let struct = struct->toUnknown
  make(
    ~name=struct.name,
    ~tagged=struct.tagged,
    ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      let input = b->B.use(~struct, ~input, ~path)
      switch transformer(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)) {
      | {parser, asyncParser: ?None} => b->B.embedSyncOperation(~input, ~fn=parser)
      | {parser: ?None, asyncParser} => b->B.embedAsyncOperation(~input, ~fn=asyncParser)
      | {parser: ?None, asyncParser: ?None, serializer: ?None} => input
      | {parser: ?None, asyncParser: ?None, serializer: _} =>
        b->B.invalidOperation(~path, ~description=`The S.transform parser is missing`)
      | {parser: _, asyncParser: _} =>
        b->B.invalidOperation(
          ~path,
          ~description=`The S.transform doesn't allow parser and asyncParser at the same time. Remove parser in favor of asyncParser.`,
        )
      }
    }),
    ~serializeOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      switch transformer(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)) {
      | {serializer} =>
        b->B.use(~struct, ~input=b->B.embedSyncOperation(~input, ~fn=serializer), ~path)
      | {parser: ?None, asyncParser: ?None, serializer: ?None} => b->B.use(~struct, ~input, ~path)
      | {serializer: ?None, asyncParser: ?Some(_)}
      | {serializer: ?None, parser: ?Some(_)} =>
        b->B.invalidOperation(~path, ~description=`The S.transform serializer is missing`)
      }
    }),
    ~maybeTypeFilter=struct.maybeTypeFilter,
    ~metadataMap=struct.metadataMap,
  )
}

type preprocessDefinition<'input, 'output> = {
  @as("p")
  parser?: unknown => 'output,
  @as("a")
  asyncParser?: unknown => unit => promise<'output>,
  @as("s")
  serializer?: unknown => 'input,
}
let rec preprocess = (struct, transformer) => {
  let struct = struct->toUnknown
  switch struct->classify {
  | Union(unionStructs) =>
    make(
      ~name=struct.name,
      ~tagged=Union(
        unionStructs->Js.Array2.map(unionStruct =>
          unionStruct->castUnknownStructToAnyStruct->preprocess(transformer)->toUnknown
        ),
      ),
      ~parseOperationBuilder=struct.parseOperationBuilder,
      ~serializeOperationBuilder=struct.serializeOperationBuilder,
      ~maybeTypeFilter=struct.maybeTypeFilter,
      ~metadataMap=struct.metadataMap,
    )
  | _ =>
    make(
      ~name=struct.name,
      ~tagged=struct.tagged,
      ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
        let input = b->B.useInput
        switch transformer(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)) {
        | {parser, asyncParser: ?None} =>
          let operationResultVar = b->B.var
          b.code = b.code ++ `${operationResultVar}=${b->B.embedSyncOperation(~input, ~fn=parser)};`
          b->B.useWithTypeFilter(~struct, ~input=operationResultVar, ~path)
        | {parser: ?None, asyncParser} => {
            let parseResultVar = b->B.embedAsyncOperation(~input, ~fn=asyncParser)
            let outputVar = b->B.var
            let asyncResultVar = b->B.varWithoutAllocation

            // TODO: Optimize async transformation to chain .then
            b.code =
              b.code ++
              `${outputVar}=()=>${parseResultVar}().then(${asyncResultVar}=>{${b->B.scope(b => {
                  let structOutputVar =
                    b->B.useWithTypeFilter(~struct, ~input=asyncResultVar, ~path)
                  let isAsync = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
                  `return ${isAsync ? `${structOutputVar}()` : structOutputVar}`
                })}});`
            outputVar
          }
        | {parser: ?None, asyncParser: ?None} => b->B.useWithTypeFilter(~struct, ~input, ~path)
        | {parser: _, asyncParser: _} =>
          b->B.invalidOperation(
            ~path,
            ~description=`The S.preprocess doesn't allow parser and asyncParser at the same time. Remove parser in favor of asyncParser.`,
          )
        }
      }),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
        let input = b->B.useInput
        let input = b->B.use(~struct, ~input, ~path)
        switch transformer(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)) {
        | {serializer} => b->B.embedSyncOperation(~input, ~fn=serializer)
        // TODO: Test that it doesn't return InvalidOperation when parser is passed but not serializer
        | {serializer: ?None} => input
        }
      }),
      ~maybeTypeFilter=None,
      ~metadataMap=struct.metadataMap,
    )
  }
}

type customDefinition<'input, 'output> = {
  @as("p")
  parser?: unknown => 'output,
  @as("a")
  asyncParser?: unknown => unit => promise<'output>,
  @as("s")
  serializer?: 'output => 'input,
}
let custom = (name, definer) => {
  make(
    ~name=() => name,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=Unknown,
    ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      switch definer(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)) {
      | {parser, asyncParser: ?None} => b->B.embedSyncOperation(~input, ~fn=parser)
      | {parser: ?None, asyncParser} => b->B.embedAsyncOperation(~input, ~fn=asyncParser)
      | {parser: ?None, asyncParser: ?None, serializer: ?None} => input
      | {parser: ?None, asyncParser: ?None, serializer: _} =>
        b->B.invalidOperation(~path, ~description=`The S.custom parser is missing`)
      | {parser: _, asyncParser: _} =>
        b->B.invalidOperation(
          ~path,
          ~description=`The S.custom doesn't allow parser and asyncParser at the same time. Remove parser in favor of asyncParser.`,
        )
      }
    }),
    ~serializeOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let input = b->B.useInput
      switch definer(EffectCtx.make(~selfStruct, ~path, ~operation=b.operation)) {
      | {serializer} => b->B.embedSyncOperation(~input, ~fn=serializer)
      | {parser: ?None, asyncParser: ?None, serializer: ?None} => input
      | {serializer: ?None, asyncParser: ?Some(_)}
      | {serializer: ?None, parser: ?Some(_)} =>
        b->B.invalidOperation(~path, ~description=`The S.custom serializer is missing`)
      }
    }),
    ~maybeTypeFilter=None,
  )
}

let rec literalCheckBuilder = (b, ~value, ~inputVar) => {
  if value->castUnknownToAny->Js.Float.isNaN {
    `Number.isNaN(${inputVar})`
  } else if value === %raw(`null`) {
    `${inputVar}===null`
  } else if value === %raw(`void 0`) {
    `${inputVar}===void 0`
  } else {
    let check = `${inputVar}===${b->B.embed(value)}`
    if value->Stdlib.Array.isArray {
      let value = value->(Obj.magic: unknown => array<unknown>)
      `(${check}||Array.isArray(${inputVar})&&${inputVar}.length===${value
        ->Js.Array2.length
        ->Stdlib.Int.unsafeToString}` ++
      (value->Js.Array2.length > 0
        ? "&&" ++
          value
          ->Js.Array2.mapi((item, idx) =>
            b->literalCheckBuilder(
              ~value=item,
              ~inputVar=`${inputVar}[${idx->Stdlib.Int.unsafeToString}]`,
            )
          )
          ->Js.Array2.joinWith("&&")
        : "") ++ ")"
    } else if %raw(`value&&value.constructor===Object`) {
      let value = value->(Obj.magic: unknown => Js.Dict.t<unknown>)
      let keys = value->Js.Dict.keys
      let numberOfKeys = keys->Js.Array2.length
      `(${check}||${inputVar}&&${inputVar}.constructor===Object&&Object.keys(${inputVar}).length===${numberOfKeys->Stdlib.Int.unsafeToString}` ++
      (numberOfKeys > 0
        ? "&&" ++
          keys
          ->Js.Array2.map(key => {
            b->literalCheckBuilder(
              ~value=value->Js.Dict.unsafeGet(key),
              ~inputVar=`${inputVar}[${key->Stdlib.Inlined.Value.fromString}]`,
            )
          })
          ->Js.Array2.joinWith("&&")
        : "") ++ ")"
    } else {
      check
    }
  }
}

let literal = value => {
  let value = value->castAnyToUnknown
  let literal = value->Literal.classify
  let operationBuilder = Builder.make((b, ~selfStruct as _, ~path) => {
    let inputVar = b->B.useInputVar
    b.code =
      b.code ++
      `${b->literalCheckBuilder(~value, ~inputVar)}||${b->B.raiseWithArg(
          ~path,
          input => InvalidLiteral({
            expected: literal,
            received: input,
          }),
          inputVar,
        )};`
    inputVar
  })
  make(
    ~name=() => `Literal(${literal->Literal.toText})`,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=Literal(literal),
    ~parseOperationBuilder=operationBuilder,
    ~serializeOperationBuilder=operationBuilder,
    ~maybeTypeFilter=None,
  )
}
let unit = literal(%raw("void 0"))

module Definition = {
  type t<'embeded>
  type node<'embeded> = Js.Dict.t<t<'embeded>>
  type kind = | @as(0) Node | @as(1) Constant | @as(2) Embeded

  let toKindWithSet = (definition: t<'embeded>, ~embededSet: Stdlib.Set.t<'embeded>) => {
    if embededSet->Stdlib.Set.has(definition->(Obj.magic: t<'embeded> => 'embeded)) {
      Embeded
    } else if definition->Stdlib.Type.typeof === #object && definition !== %raw(`null`) {
      Node
    } else {
      Constant
    }
  }

  @inline
  let toKindWithValue = (definition: t<'embeded>, ~embeded: 'embeded) => {
    if embeded === definition->(Obj.magic: t<'embeded> => 'embeded) {
      Embeded
    } else if definition->Stdlib.Type.typeof === #object && definition !== %raw(`null`) {
      Node
    } else {
      Constant
    }
  }

  let toConstant = (Obj.magic: t<'embeded> => unknown)
  let toEmbeded = (Obj.magic: t<'embeded> => 'embeded)
  let toNode = (Obj.magic: t<'embeded> => node<'embeded>)
}

module Variant = {
  @unboxed
  type serializeOutput = Registered(string) | @as(0) Unregistered | @as(1) RegisteredMultipleTimes

  let factory = {
    (struct: t<'value>, definer: 'value => 'variant): t<'variant> => {
      let struct = struct->toUnknown
      make(
        ~name=struct.name,
        ~tagged=struct.tagged,
        ~parseOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
          let input = b->B.useInput
          b->B.embedSyncOperation(~input=b->B.use(~struct, ~input, ~path), ~fn=definer)
        }),
        ~serializeOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
          let inputVar = b->B.useInputVar

          let definition =
            definer(symbol->(Obj.magic: Stdlib.Symbol.t => 'value))->(
              Obj.magic: 'variant => Definition.t<Stdlib.Symbol.t>
            )

          let output = {
            // TODO: Check that it might be not an object in union
            let rec definitionToOutput = (
              definition: Definition.t<Stdlib.Symbol.t>,
              ~outputPath,
            ) => {
              let kind = definition->Definition.toKindWithValue(~embeded=symbol)
              switch kind {
              | Embeded => Registered(`${inputVar}${outputPath}`)
              | Constant => {
                  let constant = definition->Definition.toConstant
                  let constantVar = b->B.var
                  b.code =
                    b.code ++
                    `${constantVar}=${inputVar}${outputPath};if(${constantVar}!==${b->B.embed(
                        constant,
                      )}){${b->B.raiseWithArg(
                        ~path=path->Path.concat(outputPath),
                        input => InvalidLiteral({
                          expected: constant->Literal.classify,
                          received: input,
                        }),
                        constantVar,
                      )}}`
                  Unregistered
                }
              | Node => {
                  let node = definition->Definition.toNode
                  let keys = node->Js.Dict.keys
                  let maybeOutputRef = ref(Unregistered)
                  for idx in 0 to keys->Js.Array2.length - 1 {
                    let key = keys->Js.Array2.unsafe_get(idx)
                    let definition = node->Js.Dict.unsafeGet(key)
                    let maybeOutput = definitionToOutput(
                      definition,
                      ~outputPath=Path.concat(outputPath, Path.fromLocation(key)),
                    )
                    switch (maybeOutputRef.contents, maybeOutput) {
                    | (Registered(_), Registered(_))
                    | (Registered(_), RegisteredMultipleTimes) =>
                      maybeOutputRef.contents = RegisteredMultipleTimes
                    | (RegisteredMultipleTimes, _)
                    | (Registered(_), Unregistered) => ()
                    | (Unregistered, _) => maybeOutputRef.contents = maybeOutput
                    }
                  }
                  maybeOutputRef.contents
                }
              }
            }
            definitionToOutput(definition, ~outputPath=Path.empty)
          }

          switch output {
          | RegisteredMultipleTimes =>
            b->B.invalidOperation(
              ~path,
              ~description=`Can't create serializer. The S.variant's value is registered multiple times. Use S.transform instead`,
            )
          | Registered(var) => b->B.use(~struct, ~input=var, ~path)
          | Unregistered =>
            switch selfStruct->toLiteral {
            | Some(literal) => b->B.use(~struct, ~input=b->B.embed(literal->Literal.value), ~path)
            | None =>
              b->B.invalidOperation(
                ~path,
                ~description=`Can't create serializer. The S.variant's value is not registered and not a literal. Use S.transform instead`,
              )
            }
          }
        }),
        ~maybeTypeFilter=struct.maybeTypeFilter,
        ~metadataMap=struct.metadataMap,
      )
    }
  }
}

module Option = {
  type default = Value(unknown) | Callback(unit => unknown)

  let defaultMetadataId: Metadata.Id.t<default> = Metadata.Id.make(
    ~namespace="rescript-struct",
    ~name="Option.default",
  )

  let default = struct => struct->Metadata.get(~id=defaultMetadataId)

  let parseOperationBuilder = Builder.make((b, ~selfStruct, ~path) => {
    let inputVar = b->B.useInputVar
    let outputVar = b->B.var

    let isNull = %raw(`selfStruct.t.TAG === "Null"`)
    let childStruct = selfStruct.tagged->unsafeGetVariantPayload

    let ifCode = b->B.scope(b => {
      `${outputVar}=${b->B.use(~struct=childStruct, ~input=inputVar, ~path)}`
    })
    let isAsync = childStruct.isAsyncParse->(Obj.magic: isAsyncParse => bool)

    b.code =
      b.code ++
      `if(${inputVar}!==${isNull
          ? "null"
          : "void 0"}){${ifCode}}else{${outputVar}=${switch isAsync {
        | false => `void 0`
        | true => `()=>Promise.resolve(void 0)`
        }}}`

    outputVar
  })

  let serializeOperationBuilder = Builder.make((b, ~selfStruct, ~path) => {
    let inputVar = b->B.useInputVar
    let outputVar = b->B.var

    let isNull = %raw(`selfStruct.t.TAG === "Null"`)
    let childStruct = selfStruct.tagged->unsafeGetVariantPayload

    b.code =
      b.code ++
      `if(${inputVar}!==void 0){${b->B.scope(b => {
          `${outputVar}=${b->B.use(
              ~struct=childStruct,
              ~input=`${b->B.embed(%raw("Caml_option.valFromOption"))}(${inputVar})`,
              ~path,
            )}`
        })}}else{${outputVar}=${isNull ? `null` : `void 0`}}`
    outputVar
  })

  let maybeTypeFilter = (~struct, ~inlinedNoneValue) => {
    switch struct.maybeTypeFilter {
    | Some(typeFilter) =>
      Some(
        (~inputVar) => {
          `${inputVar}!==${inlinedNoneValue}&&(${typeFilter(~inputVar)})`
        },
      )
    | None => None
    }
  }

  let factory = struct => {
    let struct = struct->toUnknown
    make(
      ~name=containerName,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=Option(struct),
      ~parseOperationBuilder,
      ~serializeOperationBuilder,
      ~maybeTypeFilter=maybeTypeFilter(~struct, ~inlinedNoneValue="void 0"),
    )
  }

  let getWithDefault = (struct, default) => {
    let struct = struct->(Obj.magic: t<option<'value>> => t<unknown>)
    make(
      ~name=struct.name,
      ~metadataMap=struct.metadataMap->Metadata.Map.set(~id=defaultMetadataId, default),
      ~tagged=struct.tagged,
      ~parseOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let input = b->B.useInput
        b->B.transform(~input=b->B.use(~struct, ~input, ~path), ~isAsync=false, (b, ~input) => {
          // TODO: Reassign input if it's not a var
          `${input}===void 0?${switch default {
            | Value(v) => b->B.embed(v)
            | Callback(cb) => `${b->B.embed(cb)}()`
            }}:${input}`
        })
      }),
      ~serializeOperationBuilder=struct.serializeOperationBuilder,
      ~maybeTypeFilter=struct.maybeTypeFilter,
    )
  }

  let getOr = (struct, defalutValue) =>
    struct->getWithDefault(Value(defalutValue->castAnyToUnknown))
  let getOrWith = (struct, defalutCb) =>
    struct->getWithDefault(Callback(defalutCb->(Obj.magic: (unit => 'a) => unit => unknown)))
}

module Null = {
  let factory = struct => {
    let struct = struct->toUnknown
    make(
      ~name=containerName,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=Null(struct),
      ~parseOperationBuilder=Option.parseOperationBuilder,
      ~serializeOperationBuilder=Option.serializeOperationBuilder,
      ~maybeTypeFilter=Option.maybeTypeFilter(~struct, ~inlinedNoneValue="null"),
    )
  }
}

module Object = {
  type ctx = {
    @as("f") field: 'value. (string, t<'value>) => 'value,
    @as("o") fieldOr: 'value. (string, t<'value>, 'value) => 'value,
    @as("t") tag: 'value. (string, 'value) => unit,
  }
  type itemDefinition = {
    @as("s")
    struct: struct<unknown>,
    @as("l")
    inlinedInputLocation: string,
    @as("p")
    inputPath: Path.t,
  }

  let typeFilter = (~inputVar) => `!${inputVar}||${inputVar}.constructor!==Object`

  let noopRefinement = (_b, ~selfStruct as _, ~inputVar as _, ~path as _) => ()

  let makeParseOperationBuilder = (
    ~itemDefinitions,
    ~itemDefinitionsSet,
    ~definition,
    ~inputRefinement,
    ~unknownKeysRefinement,
  ) => {
    Builder.make((b, ~selfStruct, ~path) => {
      let inputVar = b->B.useInputVar

      let registeredDefinitions = Stdlib.Set.empty()
      let asyncOutputVars = []

      inputRefinement(b, ~selfStruct, ~inputVar, ~path)

      let prevCode = b.code
      b.code = ""
      unknownKeysRefinement(b, ~selfStruct, ~inputVar, ~path)
      let unknownKeysRefinementCode = b.code
      b.code = ""

      let syncOutput = {
        let rec definitionToOutput = (definition: Definition.t<itemDefinition>, ~outputPath) => {
          let kind = definition->Definition.toKindWithSet(~embededSet=itemDefinitionsSet)
          switch kind {
          | Embeded => {
              let itemDefinition = definition->Definition.toEmbeded
              registeredDefinitions->Stdlib.Set.add(itemDefinition)->ignore
              let {struct, inputPath} = itemDefinition
              let fieldOuputVar =
                b->B.useWithTypeFilter(
                  ~struct,
                  ~input=`${inputVar}${inputPath}`,
                  ~path=path->Path.concat(inputPath),
                )
              let isAsyncField = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
              if isAsyncField {
                // TODO: Ensure that it's not a var, but inlined
                asyncOutputVars->Js.Array2.push(fieldOuputVar)->ignore
              }

              fieldOuputVar
            }
          | Constant => {
              let constant = definition->Definition.toConstant
              b->B.embed(constant)
            }
          | Node => {
              let node = definition->Definition.toNode
              let isArray = Stdlib.Array.isArray(node)
              let keys = node->Js.Dict.keys
              let codeRef = ref(isArray ? "[" : "{")
              for idx in 0 to keys->Js.Array2.length - 1 {
                let key = keys->Js.Array2.unsafe_get(idx)
                let definition = node->Js.Dict.unsafeGet(key)
                let output =
                  definition->definitionToOutput(
                    ~outputPath=Path.concat(outputPath, Path.fromLocation(key)),
                  )
                codeRef.contents =
                  codeRef.contents ++
                  (isArray ? output : `${key->Stdlib.Inlined.Value.fromString}:${output}`) ++ ","
              }
              codeRef.contents ++ (isArray ? "]" : "}")
            }
          }
        }
        definition->definitionToOutput(~outputPath=Path.empty)
      }
      let registeredFieldsCode = b.code
      b.code = ""

      for idx in 0 to itemDefinitions->Js.Array2.length - 1 {
        let itemDefinition = itemDefinitions->Js.Array2.unsafe_get(idx)
        if registeredDefinitions->Stdlib.Set.has(itemDefinition)->not {
          let {struct, inputPath} = itemDefinition
          let fieldOuputVar =
            b->B.useWithTypeFilter(
              ~struct,
              ~input=`${inputVar}${inputPath}`,
              ~path=path->Path.concat(inputPath),
            )
          let isAsyncField = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
          if isAsyncField {
            // TODO: Ensure that it's not a var, but inlined
            asyncOutputVars->Js.Array2.push(fieldOuputVar)->ignore
          }
        }
      }
      let unregisteredFieldsCode = b.code

      b.code =
        prevCode ++ unregisteredFieldsCode ++ registeredFieldsCode ++ unknownKeysRefinementCode

      if asyncOutputVars->Js.Array2.length === 0 {
        syncOutput
      } else {
        let outputVar = b->B.var
        b.code =
          b.code ++
          `${outputVar}=()=>Promise.all([${asyncOutputVars
            ->Js.Array2.map(asyncOutputVar => `${asyncOutputVar}()`)
            ->Js.Array2.joinWith(
              ",",
            )}]).then(([${asyncOutputVars->Js.Array2.toString}])=>(${syncOutput}));`
        outputVar
      }
    })
  }

  module Ctx = {
    type t = {
      @as("n")
      fieldNames: array<string>,
      @as("h")
      fields: Js.Dict.t<struct<unknown>>,
      @as("d")
      itemDefinitionsSet: Stdlib.Set.t<itemDefinition>,
      // Public API for JS/TS users.
      // It shouldn't be used from ReScript and
      // needed only because we use @as to reduce bundle-size
      // of ReScript compiled code
      @as("field") _jsField: 'value. (string, t<'value>) => 'value,
      @as("fieldOr") _jsFieldOr: 'value. (string, t<'value>, 'value) => 'value,
      @as("tag") _jsTag: 'value. (string, 'value) => unit,
      // Public API for ReScript users
      ...ctx,
    }

    @inline
    let make = () => {
      let fields = Js.Dict.empty()
      let fieldNames = []
      let itemDefinitionsSet = Stdlib.Set.empty()

      let field:
        type value. (string, struct<value>) => value =
        (fieldName, struct) => {
          let struct = struct->toUnknown
          let inlinedInputLocation = fieldName->Stdlib.Inlined.Value.fromString
          if fields->Stdlib.Dict.has(fieldName) {
            InternalError.panic(
              `The field ${inlinedInputLocation} is defined multiple times. If you want to duplicate the field, use S.transform instead.`,
            )
          } else {
            let itemDefinition: itemDefinition = {
              struct,
              inlinedInputLocation,
              inputPath: inlinedInputLocation->Path.fromInlinedLocation,
            }
            fields->Js.Dict.set(fieldName, struct)
            fieldNames->Js.Array2.push(fieldName)->ignore
            itemDefinitionsSet->Stdlib.Set.add(itemDefinition)->ignore
            itemDefinition->(Obj.magic: itemDefinition => value)
          }
        }

      let tag = (tag, asValue) => {
        let _ = field(tag, literal(asValue))
      }

      let fieldOr = (fieldName, struct, or) => {
        field(fieldName, Option.factory(struct)->Option.getOr(or))
      }

      {
        fieldNames,
        fields,
        itemDefinitionsSet,
        // js/ts methods
        _jsField: field,
        _jsFieldOr: fieldOr,
        _jsTag: tag,
        // methods
        field,
        fieldOr,
        tag,
      }
    }
  }

  let factory = definer => {
    let ctx = Ctx.make()
    let definition = definer((ctx :> ctx))->(Obj.magic: 'any => Definition.t<itemDefinition>)
    let {itemDefinitionsSet, fields, fieldNames} = ctx
    let itemDefinitions = itemDefinitionsSet->Stdlib.Set.toArray

    make(
      ~name=() =>
        `Object({${fieldNames
          ->Js.Array2.map(fieldName => {
            let fieldStruct = fields->Js.Dict.unsafeGet(fieldName)
            `${fieldName->Stdlib.Inlined.Value.fromString}: ${fieldStruct.name()}`
          })
          ->Js.Array2.joinWith(", ")}})`,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=Object({
        fields,
        fieldNames,
        unknownKeys: Strip,
      }),
      ~parseOperationBuilder=makeParseOperationBuilder(
        ~itemDefinitions,
        ~itemDefinitionsSet,
        ~definition,
        ~inputRefinement=noopRefinement,
        ~unknownKeysRefinement=(b, ~selfStruct, ~inputVar, ~path) => {
          let withUnknownKeysRefinement =
            (selfStruct->classify->Obj.magic)["unknownKeys"] === Strict
          switch (withUnknownKeysRefinement, itemDefinitions) {
          | (true, []) => {
              let keyVar = b->B.var
              b.code =
                b.code ++
                `for(${keyVar} in ${inputVar}){${b->B.raiseWithArg(
                    ~path,
                    exccessFieldName => ExcessField(exccessFieldName),
                    keyVar,
                  )}}`
            }
          | (true, _) => {
              let keyVar = b->B.var
              b.code = b.code ++ `for(${keyVar} in ${inputVar}){if(`
              for idx in 0 to itemDefinitions->Js.Array2.length - 1 {
                let itemDefinition = itemDefinitions->Js.Array2.unsafe_get(idx)
                if idx !== 0 {
                  b.code = b.code ++ "&&"
                }
                b.code = b.code ++ `${keyVar}!==${itemDefinition.inlinedInputLocation}`
              }
              b.code =
                b.code ++
                `){${b->B.raiseWithArg(
                    ~path,
                    exccessFieldName => ExcessField(exccessFieldName),
                    keyVar,
                  )}}}`
            }
          | _ => ()
          }
        },
      ),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let inputVar = b->B.useInputVar
        let fieldsCodeRef = ref("")

        let registeredDefinitions = Stdlib.Set.empty()

        {
          let prevCode = b.code
          b.code = ""
          let rec definitionToOutput = (definition: Definition.t<itemDefinition>, ~outputPath) => {
            let kind = definition->Definition.toKindWithSet(~embededSet=itemDefinitionsSet)
            switch kind {
            | Embeded =>
              let itemDefinition = definition->Definition.toEmbeded
              if registeredDefinitions->Stdlib.Set.has(itemDefinition) {
                b->B.invalidOperation(
                  ~path,
                  ~description=`The field ${itemDefinition.inlinedInputLocation} is registered multiple times. If you want to duplicate the field, use S.transform instead`,
                )
              } else {
                registeredDefinitions->Stdlib.Set.add(itemDefinition)->ignore
                let {inlinedInputLocation, struct} = itemDefinition
                fieldsCodeRef.contents =
                  fieldsCodeRef.contents ++
                  `${inlinedInputLocation}:${b->B.use(
                      ~struct,
                      ~input=`${inputVar}${outputPath}`,
                      ~path=path->Path.concat(outputPath),
                    )},`
              }
            | Constant => {
                let value = definition->Definition.toConstant
                b.code =
                  `if(${inputVar}${outputPath}!==${b->B.embed(value)}){${b->B.raiseWithArg(
                      ~path=path->Path.concat(outputPath),
                      input => InvalidLiteral({
                        expected: value->Literal.classify,
                        received: input,
                      }),
                      `${inputVar}${outputPath}`,
                    )}}` ++
                  b.code
              }
            | Node => {
                let node = definition->Definition.toNode
                let keys = node->Js.Dict.keys
                for idx in 0 to keys->Js.Array2.length - 1 {
                  let key = keys->Js.Array2.unsafe_get(idx)
                  let definition = node->Js.Dict.unsafeGet(key)
                  definitionToOutput(
                    definition,
                    ~outputPath=Path.concat(outputPath, Path.fromLocation(key)),
                  )
                }
              }
            }
          }
          definitionToOutput(definition, ~outputPath=Path.empty)
          b.code = prevCode ++ b.code
        }

        for idx in 0 to itemDefinitions->Js.Array2.length - 1 {
          let itemDefinition = itemDefinitions->Js.Array2.unsafe_get(idx)
          if registeredDefinitions->Stdlib.Set.has(itemDefinition)->not {
            let {struct, inlinedInputLocation} = itemDefinition
            switch struct->toLiteral {
            | Some(literal) =>
              fieldsCodeRef.contents =
                fieldsCodeRef.contents ++
                `${inlinedInputLocation}:${b->B.embed(literal->Literal.value)},`
            | None =>
              b->B.invalidOperation(
                ~path,
                ~description=`Can't create serializer. The ${inlinedInputLocation} field is not registered and not a literal. Use S.transform instead`,
              )
            }
          }
        }

        `{${fieldsCodeRef.contents}}`
      }),
      ~maybeTypeFilter=Some(typeFilter),
    )
  }

  let strip = struct => {
    switch struct->classify {
    | Object({unknownKeys: Strict, fieldNames, fields}) =>
      make(
        ~name=struct.name,
        ~tagged=Object({unknownKeys: Strip, fieldNames, fields}),
        ~parseOperationBuilder=struct.parseOperationBuilder,
        ~serializeOperationBuilder=struct.serializeOperationBuilder,
        ~maybeTypeFilter=struct.maybeTypeFilter,
        ~metadataMap=struct.metadataMap,
      )
    | _ => struct
    }
  }

  let strict = struct => {
    switch struct->classify {
    | Object({unknownKeys: Strip, fieldNames, fields}) =>
      make(
        ~name=struct.name,
        ~tagged=Object({unknownKeys: Strict, fieldNames, fields}),
        ~parseOperationBuilder=struct.parseOperationBuilder,
        ~serializeOperationBuilder=struct.serializeOperationBuilder,
        ~maybeTypeFilter=struct.maybeTypeFilter,
        ~metadataMap=struct.metadataMap,
      )
    // TODO: Should it throw for non Object structs?
    | _ => struct
    }
  }
}

module Never = {
  let builder = Builder.make((b, ~selfStruct, ~path) => {
    let input = b->B.useInput
    b.code =
      b.code ++
      b->B.raiseWithArg(
        ~path,
        input => InvalidType({
          expected: selfStruct,
          received: input,
        }),
        input,
      ) ++ ";"
    input
  })

  let struct = make(
    ~name=primitiveName,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=Never,
    ~parseOperationBuilder=builder,
    ~serializeOperationBuilder=builder,
    ~maybeTypeFilter=None,
  )
}

module Unknown = {
  let struct = {
    name: primitiveName,
    tagged: Unknown,
    parseOperationBuilder: Builder.noop,
    serializeOperationBuilder: Builder.noop,
    isAsyncParse: Value(false),
    metadataMap: Metadata.Map.empty,
    maybeTypeFilter: None,
  }
}

module String = {
  module Refinement = {
    type kind =
      | Min({length: int})
      | Max({length: int})
      | Length({length: int})
      | Email
      | Uuid
      | Cuid
      | Url
      | Pattern({re: Js.Re.t})
      | Datetime
    type t = {
      kind: kind,
      message: string,
    }

    let metadataId: Metadata.Id.t<array<t>> = Metadata.Id.make(
      ~namespace="rescript-struct",
      ~name="String.refinements",
    )
  }

  let refinements = struct => {
    switch struct->Metadata.get(~id=Refinement.metadataId) {
    | Some(m) => m
    | None => []
    }
  }

  let cuidRegex = %re(`/^c[^\s-]{8,}$/i`)
  let uuidRegex = %re(`/^([a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[a-f0-9]{4}-[a-f0-9]{12}|00000000-0000-0000-0000-000000000000)$/i`)
  // Adapted from https://stackoverflow.com/a/46181/1550155
  let emailRegex = %re(`/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2}))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2}))\])|(\[IPv6:(([a-f0-9]{1,4}:){7}|::([a-f0-9]{1,4}:){0,6}|([a-f0-9]{1,4}:){1}:([a-f0-9]{1,4}:){0,5}|([a-f0-9]{1,4}:){2}:([a-f0-9]{1,4}:){0,4}|([a-f0-9]{1,4}:){3}:([a-f0-9]{1,4}:){0,3}|([a-f0-9]{1,4}:){4}:([a-f0-9]{1,4}:){0,2}|([a-f0-9]{1,4}:){5}:([a-f0-9]{1,4}:){0,1})([a-f0-9]{1,4}|(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2}))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2})))\])|([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])*(\.[A-Za-z]{2,})+))$/`)
  // Adapted from https://stackoverflow.com/a/3143231
  let datetimeRe = %re(`/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/`)

  let typeFilter = (~inputVar) => `typeof ${inputVar}!=="string"`

  let struct = makeWithNoopSerializer(
    ~name=primitiveName,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=String,
    ~parseOperationBuilder=Builder.noop,
    ~maybeTypeFilter=Some(typeFilter),
  )

  let min = (struct, length, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `String must be ${length->Stdlib.Int.unsafeToString} or more characters long`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}.length<${b->B.embed(length)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Min({length: length}),
        message,
      },
    )
  }

  let max = (struct, length, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `String must be ${length->Stdlib.Int.unsafeToString} or fewer characters long`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}.length>${b->B.embed(length)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Max({length: length}),
        message,
      },
    )
  }

  let length = (struct, length, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `String must be exactly ${length->Stdlib.Int.unsafeToString} characters long`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}.length!==${b->B.embed(length)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Length({length: length}),
        message,
      },
    )
  }

  let email = (struct, ~message=`Invalid email address`) => {
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(!${b->B.embed(emailRegex)}.test(${inputVar})){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Email,
        message,
      },
    )
  }

  let uuid = (struct, ~message=`Invalid UUID`) => {
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(!${b->B.embed(uuidRegex)}.test(${inputVar})){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Uuid,
        message,
      },
    )
  }

  let cuid = (struct, ~message=`Invalid CUID`) => {
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(!${b->B.embed(cuidRegex)}.test(${inputVar})){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Cuid,
        message,
      },
    )
  }

  let url = (struct, ~message=`Invalid url`) => {
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `try{new URL(${inputVar})}catch(_){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Url,
        message,
      },
    )
  }

  let pattern = (struct, re, ~message=`Invalid`) => {
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        let reVar = b->B.var
        `${reVar}=${b->B.embed(
            re,
          )};${reVar}.lastIndex=0;if(!${reVar}.test(${inputVar})){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Pattern({re: re}),
        message,
      },
    )
  }

  let datetime = (struct, ~message=`Invalid datetime string! Must be UTC`) => {
    let refinement = {
      Refinement.kind: Datetime,
      message,
    }
    struct
    ->Metadata.set(
      ~id=Refinement.metadataId,
      {
        switch struct->Metadata.get(~id=Refinement.metadataId) {
        | Some(refinements) => refinements->Stdlib.Array.append(refinement)
        | None => [refinement]
        }
      },
    )
    ->transform(s => {
      parser: string => {
        if datetimeRe->Js.Re.test_(string)->not {
          s.fail(message)
        }
        Js.Date.fromString(string)
      },
      serializer: date => date->Js.Date.toISOString,
    })
  }

  let trim = struct => {
    let transformer = string => string->Js.String2.trim
    struct->transform(_ => {parser: transformer, serializer: transformer})
  }
}

module JsonString = {
  let factory = struct => {
    let struct = struct->toUnknown
    try {
      struct->validateJsonableStruct(~rootStruct=struct, ~isRoot=true, ())
    } catch {
    | exn => {
        let _ = exn->InternalError.getOrRethrow
        InternalError.panic(
          `The struct ${struct.name()} passed to S.jsonString is not compatible with JSON`,
        )
      }
    }
    make(
      ~name=primitiveName,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=String,
      ~parseOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let input = b->B.useInput
        let jsonVar = b->B.var
        b.code =
          b.code ++
          `try{${jsonVar}=JSON.parse(${input})}catch(t){${b->B.raiseWithArg(
              ~path,
              message => OperationFailed(message),
              "t.message",
            )}}`

        b->B.useWithTypeFilter(~struct, ~input=jsonVar, ~path)
      }),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let input = b->B.useInput
        `JSON.stringify(${b->B.use(~struct, ~input, ~path)})`
      }),
      ~maybeTypeFilter=Some(String.typeFilter),
    )
  }
}

module Bool = {
  let typeFilter = (~inputVar) => `typeof ${inputVar}!=="boolean"`

  let struct = makeWithNoopSerializer(
    ~name=primitiveName,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=Bool,
    ~parseOperationBuilder=Builder.noop,
    ~maybeTypeFilter=Some(typeFilter),
  )
}

module Int = {
  module Refinement = {
    type kind =
      | Min({value: int})
      | Max({value: int})
      | Port
    type t = {
      kind: kind,
      message: string,
    }

    let metadataId: Metadata.Id.t<array<t>> = Metadata.Id.make(
      ~namespace="rescript-struct",
      ~name="Int.refinements",
    )
  }

  let refinements = struct => {
    switch struct->Metadata.get(~id=Refinement.metadataId) {
    | Some(m) => m
    | None => []
    }
  }

  let typeFilter = (~inputVar) =>
    `typeof ${inputVar}!=="number"||${inputVar}>2147483647||${inputVar}<-2147483648||${inputVar}%1!==0`

  let struct = makeWithNoopSerializer(
    ~name=primitiveName,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=Int,
    ~parseOperationBuilder=Builder.noop,
    ~maybeTypeFilter=Some(typeFilter),
  )

  let min = (struct, minValue, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Number must be greater than or equal to ${minValue->Stdlib.Int.unsafeToString}`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}<${b->B.embed(minValue)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Min({value: minValue}),
        message,
      },
    )
  }

  let max = (struct, maxValue, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Number must be lower than or equal to ${maxValue->Stdlib.Int.unsafeToString}`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}>${b->B.embed(maxValue)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Max({value: maxValue}),
        message,
      },
    )
  }

  let port = (struct, ~message="Invalid port") => {
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}<1||${inputVar}>65535){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Port,
        message,
      },
    )
  }
}

module Float = {
  module Refinement = {
    type kind =
      | Min({value: float})
      | Max({value: float})
    type t = {
      kind: kind,
      message: string,
    }

    let metadataId: Metadata.Id.t<array<t>> = Metadata.Id.make(
      ~namespace="rescript-struct",
      ~name="Float.refinements",
    )
  }

  let refinements = struct => {
    switch struct->Metadata.get(~id=Refinement.metadataId) {
    | Some(m) => m
    | None => []
    }
  }

  let typeFilter = (~inputVar) => `typeof ${inputVar}!=="number"||Number.isNaN(${inputVar})`

  let struct = makeWithNoopSerializer(
    ~name=primitiveName,
    ~metadataMap=Metadata.Map.empty,
    ~tagged=Float,
    ~parseOperationBuilder=Builder.noop,
    ~maybeTypeFilter=Some(typeFilter),
  )

  let min = (struct, minValue, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Number must be greater than or equal to ${minValue->Stdlib.Float.unsafeToString}`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}<${b->B.embed(minValue)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Min({value: minValue}),
        message,
      },
    )
  }

  let max = (struct, maxValue, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Number must be lower than or equal to ${maxValue->Stdlib.Float.unsafeToString}`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}>${b->B.embed(maxValue)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Max({value: maxValue}),
        message,
      },
    )
  }
}

module Array = {
  module Refinement = {
    type kind =
      | Min({length: int})
      | Max({length: int})
      | Length({length: int})
    type t = {
      kind: kind,
      message: string,
    }

    let metadataId: Metadata.Id.t<array<t>> = Metadata.Id.make(
      ~namespace="rescript-struct",
      ~name="Array.refinements",
    )
  }

  let refinements = struct => {
    switch struct->Metadata.get(~id=Refinement.metadataId) {
    | Some(m) => m
    | None => []
    }
  }

  let typeFilter = (~inputVar) => `!Array.isArray(${inputVar})`

  let factory = struct => {
    let struct = struct->toUnknown
    make(
      ~name=containerName,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=Array(struct),
      ~parseOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let inputVar = b->B.useInputVar
        let iteratorVar = b->B.varWithoutAllocation
        let outputVar = b->B.var

        b.code =
          b.code ++
          `${outputVar}=[];for(let ${iteratorVar}=0;${iteratorVar}<${inputVar}.length;++${iteratorVar}){${b->B.scope(
              b => {
                let itemOutputVar =
                  b->B.withPathPrepend(
                    ~path,
                    ~dynamicLocationVar=iteratorVar,
                    (b, ~path) =>
                      b->B.useWithTypeFilter(~struct, ~input=`${inputVar}[${iteratorVar}]`, ~path),
                  )
                `${outputVar}.push(${itemOutputVar})`
              },
            )}}`

        let isAsync = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
        if isAsync {
          let asyncOutputVar = b->B.var
          b.code = b.code ++ `${asyncOutputVar}=()=>Promise.all(${outputVar}.map(t=>t()));`
          asyncOutputVar
        } else {
          outputVar
        }
      }),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        if struct.serializeOperationBuilder === Builder.noop {
          b->B.useInput
        } else {
          let inputVar = b->B.useInputVar
          let iteratorVar = b->B.varWithoutAllocation
          let outputVar = b->B.var

          b.code =
            b.code ++
            `${outputVar}=[];for(let ${iteratorVar}=0;${iteratorVar}<${inputVar}.length;++${iteratorVar}){${b->B.scope(
                b => {
                  let itemOutputVar =
                    b->B.withPathPrepend(
                      ~path,
                      ~dynamicLocationVar=iteratorVar,
                      (b, ~path) => b->B.use(~struct, ~input=`${inputVar}[${iteratorVar}]`, ~path),
                    )
                  `${outputVar}.push(${itemOutputVar})`
                },
              )}}`

          outputVar
        }
      }),
      ~maybeTypeFilter=Some(typeFilter),
    )
  }

  let min = (struct, length, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Array must be ${length->Stdlib.Int.unsafeToString} or more items long`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}.length<${b->B.embed(length)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Min({length: length}),
        message,
      },
    )
  }

  let max = (struct, length, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Array must be ${length->Stdlib.Int.unsafeToString} or fewer items long`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}.length>${b->B.embed(length)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Max({length: length}),
        message,
      },
    )
  }

  let length = (struct, length, ~message as maybeMessage=?) => {
    let message = switch maybeMessage {
    | Some(m) => m
    | None => `Array must be exactly ${length->Stdlib.Int.unsafeToString} items long`
    }
    struct->addRefinement(
      ~metadataId=Refinement.metadataId,
      ~refiner=(b, ~inputVar, ~selfStruct as _, ~path) => {
        `if(${inputVar}.length!==${b->B.embed(length)}){${b->B.fail(~message, ~path)}}`
      },
      ~refinement={
        kind: Length({length: length}),
        message,
      },
    )
  }
}

module Dict = {
  let factory = struct => {
    let struct = struct->toUnknown
    make(
      ~name=containerName,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=Dict(struct),
      ~parseOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let inputVar = b->B.useInputVar
        let keyVar = b->B.varWithoutAllocation
        let outputVar = b->B.var

        b.code =
          b.code ++
          `${outputVar}={};for(let ${keyVar} in ${inputVar}){${b->B.scope(b => {
              let itemOutputVar =
                b->B.withPathPrepend(
                  ~path,
                  ~dynamicLocationVar=keyVar,
                  (b, ~path) =>
                    b->B.useWithTypeFilter(~struct, ~input=`${inputVar}[${keyVar}]`, ~path),
                )
              `${outputVar}[${keyVar}]=${itemOutputVar}`
            })}}`

        let isAsync = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
        if isAsync {
          let resolveVar = b->B.varWithoutAllocation
          let rejectVar = b->B.varWithoutAllocation
          let asyncParseResultVar = b->B.varWithoutAllocation
          let counterVar = b->B.varWithoutAllocation
          let asyncOutputVar = b->B.var
          b.code =
            b.code ++
            `${asyncOutputVar}=()=>new Promise((${resolveVar},${rejectVar})=>{let ${counterVar}=Object.keys(${outputVar}).length;for(let ${keyVar} in ${outputVar}){${outputVar}[${keyVar}]().then(${asyncParseResultVar}=>{${outputVar}[${keyVar}]=${asyncParseResultVar};if(${counterVar}--===1){${resolveVar}(${outputVar})}},${rejectVar})}});`
          asyncOutputVar
        } else {
          outputVar
        }
      }),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        if struct.serializeOperationBuilder === Builder.noop {
          b->B.useInput
        } else {
          let inputVar = b->B.useInputVar
          let keyVar = b->B.varWithoutAllocation
          let outputVar = b->B.var

          b.code =
            b.code ++
            `${outputVar}={};for(let ${keyVar} in ${inputVar}){${b->B.scope(b => {
                let itemOutputVar =
                  b->B.withPathPrepend(
                    ~path,
                    ~dynamicLocationVar=keyVar,
                    (b, ~path) => b->B.use(~struct, ~input=`${inputVar}[${keyVar}]`, ~path),
                  )

                `${outputVar}[${keyVar}]=${itemOutputVar}`
              })}}`

          outputVar
        }
      }),
      ~maybeTypeFilter=Some(Object.typeFilter),
    )
  }
}

module Tuple = {
  type ctx = {
    @as("i") item: 'value. (int, t<'value>) => 'value,
    @as("t") tag: 'value. (int, 'value) => unit,
  }

  module Ctx = {
    type t = {
      @as("s")
      structs: array<struct<unknown>>,
      @as("d")
      itemDefinitionsSet: Stdlib.Set.t<Object.itemDefinition>,
      @as("item") _jsItem: 'value. (int, t<'value>) => 'value,
      @as("tag") _jsTag: 'value. (int, 'value) => unit,
      ...ctx,
    }

    @inline
    let make = () => {
      let structs = []
      let itemDefinitionsSet = Stdlib.Set.empty()

      let item:
        type value. (int, struct<value>) => value =
        (idx, struct) => {
          let struct = struct->toUnknown
          let inlinedInputLocation = `"${idx->Stdlib.Int.unsafeToString}"`
          if structs->Stdlib.Array.has(idx) {
            InternalError.panic(
              `The item ${inlinedInputLocation} is defined multiple times. If you want to duplicate the item, use S.transform instead.`,
            )
          } else {
            let itemDefinition: Object.itemDefinition = {
              struct,
              inlinedInputLocation,
              inputPath: inlinedInputLocation->Path.fromInlinedLocation,
            }
            structs->Js.Array2.unsafe_set(idx, struct)
            itemDefinitionsSet->Stdlib.Set.add(itemDefinition)->ignore
            itemDefinition->(Obj.magic: Object.itemDefinition => value)
          }
        }

      let tag = (idx, asValue) => {
        let _ = item(idx, literal(asValue))
      }

      {
        structs,
        itemDefinitionsSet,
        // js/ts methods
        _jsItem: item,
        _jsTag: tag,
        // methods
        item,
        tag,
      }
    }
  }

  let factory = definer => {
    let ctx = Ctx.make()
    let definition = definer((ctx :> ctx))->(Obj.magic: 'any => Definition.t<Object.itemDefinition>)
    let {itemDefinitionsSet, structs} = ctx
    let length = structs->Js.Array2.length
    for idx in 0 to length - 1 {
      if structs->Js.Array2.unsafe_get(idx)->Obj.magic->not {
        let struct = unit->toUnknown
        let inlinedInputLocation = `"${idx->Stdlib.Int.unsafeToString}"`
        let itemDefinition: Object.itemDefinition = {
          struct,
          inlinedInputLocation,
          inputPath: inlinedInputLocation->Path.fromInlinedLocation,
        }
        structs->Js.Array2.unsafe_set(idx, struct)
        itemDefinitionsSet->Stdlib.Set.add(itemDefinition)->ignore
      }
    }
    let itemDefinitions = itemDefinitionsSet->Stdlib.Set.toArray

    make(
      ~name=() => `Tuple(${structs->Js.Array2.map(s => s.name())->Js.Array2.joinWith(", ")})`,
      ~tagged=Tuple(structs),
      ~parseOperationBuilder=Object.makeParseOperationBuilder(
        ~itemDefinitions,
        ~itemDefinitionsSet,
        ~definition,
        ~inputRefinement=(b, ~selfStruct as _, ~inputVar, ~path) => {
          b.code =
            b.code ++
            `if(${inputVar}.length!==${length->Stdlib.Int.unsafeToString}){${b->B.raiseWithArg(
                ~path,
                numberOfInputItems => InvalidTupleSize({
                  expected: length,
                  received: numberOfInputItems,
                }),
                `${inputVar}.length`,
              )}}`
        },
        ~unknownKeysRefinement=Object.noopRefinement,
      ),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct as _, ~path) => {
        let inputVar = b->B.useInputVar
        let outputVar = b->B.var
        let registeredDefinitions = Stdlib.Set.empty()
        b.code = b.code ++ `${outputVar}=[];`

        {
          let prevCode = b.code
          b.code = ""
          let rec definitionToOutput = (
            definition: Definition.t<Object.itemDefinition>,
            ~outputPath,
          ) => {
            let kind = definition->Definition.toKindWithSet(~embededSet=itemDefinitionsSet)
            switch kind {
            | Embeded =>
              let itemDefinition = definition->Definition.toEmbeded
              if registeredDefinitions->Stdlib.Set.has(itemDefinition) {
                b->B.invalidOperation(
                  ~path,
                  ~description=`The item ${itemDefinition.inlinedInputLocation} is registered multiple times. If you want to duplicate the item, use S.transform instead`,
                )
              } else {
                registeredDefinitions->Stdlib.Set.add(itemDefinition)->ignore
                let {struct, inputPath} = itemDefinition
                let fieldOuputVar =
                  b->B.use(
                    ~struct,
                    ~input=`${inputVar}${outputPath}`,
                    ~path=path->Path.concat(outputPath),
                  )
                b.code = b.code ++ `${outputVar}${inputPath}=${fieldOuputVar};`
              }
            | Constant => {
                let value = definition->Definition.toConstant
                b.code =
                  `if(${inputVar}${outputPath}!==${b->B.embed(value)}){${b->B.raiseWithArg(
                      ~path=path->Path.concat(outputPath),
                      input => InvalidLiteral({
                        expected: value->Literal.classify,
                        received: input,
                      }),
                      `${inputVar}${outputPath}`,
                    )}}` ++
                  b.code
              }
            | Node => {
                let node = definition->Definition.toNode
                let keys = node->Js.Dict.keys
                for idx in 0 to keys->Js.Array2.length - 1 {
                  let key = keys->Js.Array2.unsafe_get(idx)
                  let definition = node->Js.Dict.unsafeGet(key)
                  definitionToOutput(
                    definition,
                    ~outputPath=Path.concat(outputPath, Path.fromLocation(key)),
                  )
                }
              }
            }
          }
          definitionToOutput(definition, ~outputPath=Path.empty)
          b.code = prevCode ++ b.code
        }

        for idx in 0 to itemDefinitions->Js.Array2.length - 1 {
          let itemDefinition = itemDefinitions->Js.Array2.unsafe_get(idx)
          if registeredDefinitions->Stdlib.Set.has(itemDefinition)->not {
            let {struct, inlinedInputLocation, inputPath} = itemDefinition
            switch struct->toLiteral {
            | Some(literal) =>
              b.code = b.code ++ `${outputVar}${inputPath}=${b->B.embed(literal->Literal.value)};`
            | None =>
              b->B.invalidOperation(
                ~path,
                ~description=`Can't create serializer. The ${inlinedInputLocation} item is not registered and not a literal. Use S.transform instead`,
              )
            }
          }
        }

        outputVar
      }),
      ~maybeTypeFilter=Some(Array.typeFilter),
      ~metadataMap=Metadata.Map.empty,
    )
  }
}

module Union = {
  let factory = structs => {
    let structs: array<t<unknown>> = structs->Obj.magic

    if structs->Js.Array2.length < 2 {
      InternalError.panic("A Union struct factory require at least two structs.")
    }

    make(
      ~name=() => `Union(${structs->Js.Array2.map(s => s.name())->Js.Array2.joinWith(", ")})`,
      ~metadataMap=Metadata.Map.empty,
      ~tagged=Union(structs),
      ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
        let inputVar = b->B.useInputVar
        let structs = selfStruct->classify->unsafeGetVariantPayload

        let isAsyncRef = ref(false)
        let itemsCode = []
        let itemsOutputVar = []

        let prevCode = b.code
        for idx in 0 to structs->Js.Array2.length - 1 {
          let struct = structs->Js.Array2.unsafe_get(idx)
          b.code = ""
          let itemOutputVar = b->B.useWithTypeFilter(~struct, ~input=inputVar, ~path=Path.empty)
          let isAsyncItem = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)
          if isAsyncItem {
            isAsyncRef.contents = true
          }
          itemsOutputVar->Js.Array2.push(itemOutputVar)->ignore
          itemsCode->Js.Array2.push(b.code)->ignore
        }
        b.code = prevCode
        let isAsync = isAsyncRef.contents

        let outputVar = b->B.var

        let codeEndRef = ref("")
        let errorCodeRef = ref("")

        // TODO: Use B.withCatch ???
        for idx in 0 to structs->Js.Array2.length - 1 {
          let struct = structs->Js.Array2.unsafe_get(idx)
          let code = itemsCode->Js.Array2.unsafe_get(idx)
          let itemOutputVar = itemsOutputVar->Js.Array2.unsafe_get(idx)
          let isAsyncItem = struct.isAsyncParse->(Obj.magic: isAsyncParse => bool)

          let errorVar = b->B.varWithoutAllocation

          let errorCode = if isAsync {
            (isAsyncItem ? `${errorVar}===${itemOutputVar}?${errorVar}():` : "") ++
            `Promise.reject(${errorVar})`
          } else {
            errorVar
          }
          if idx === 0 {
            errorCodeRef.contents = errorCode
          } else {
            errorCodeRef.contents = errorCodeRef.contents ++ "," ++ errorCode
          }

          b.code =
            b.code ++
            `try{${code}${switch (isAsyncItem, isAsync) {
              | (true, _) => `throw ${itemOutputVar}`
              | (false, false) => `${outputVar}=${itemOutputVar}`
              | (false, true) => `${outputVar}=()=>Promise.resolve(${itemOutputVar})`
              }}}catch(${errorVar}){if(${b->B.isInternalError(errorVar)}${isAsyncItem
                ? `||${errorVar}===${itemOutputVar}`
                : ""}){`
          codeEndRef.contents = `}else{throw ${errorVar}}}` ++ codeEndRef.contents
        }

        if isAsync {
          b.code =
            b.code ++
            `${outputVar}=()=>Promise.any([${errorCodeRef.contents}]).catch(t=>{${b->B.raiseWithArg(
                ~path,
                internalErrors => {
                  InvalidUnion(internalErrors)
                },
                `t.errors`,
              )}})` ++
            codeEndRef.contents
          outputVar
        } else {
          b.code =
            b.code ++
            b->B.raiseWithArg(
              ~path,
              internalErrors => InvalidUnion(internalErrors),
              `[${errorCodeRef.contents}]`,
            ) ++
            codeEndRef.contents
          outputVar
        }
      }),
      ~serializeOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
        let inputVar = b->B.useInputVar
        let structs = selfStruct->classify->unsafeGetVariantPayload

        let outputVar = b->B.var

        let codeEndRef = ref("")
        let errorVarsRef = ref("")

        for idx in 0 to structs->Js.Array2.length - 1 {
          let itemStruct = structs->Js.Array2.unsafe_get(idx)
          let errorVar = b->B.varWithoutAllocation
          errorVarsRef.contents = errorVarsRef.contents ++ errorVar ++ `,`

          b.code =
            b.code ++
            `try{${b->B.scope(
                b => {
                  let itemOutput = b->B.use(~struct=itemStruct, ~input=inputVar, ~path=Path.empty)
                  let itemOutput = switch itemStruct.maybeTypeFilter {
                  | Some(typeFilter) =>
                    let itemOutputVar = b->B.toVar(itemOutput)
                    b.code =
                      b.code ++
                      b->B.typeFilterCode(
                        ~struct=itemStruct,
                        ~typeFilter,
                        ~inputVar=itemOutputVar,
                        ~path=Path.empty,
                      )
                    itemOutputVar
                  | None => itemOutput
                  }
                  `${outputVar}=${itemOutput}`
                },
              )}}catch(${errorVar}){if(${b->B.isInternalError(errorVar)}){`

          codeEndRef.contents = `}else{throw ${errorVar}}}` ++ codeEndRef.contents
        }

        b.code =
          b.code ++
          b->B.raiseWithArg(
            ~path,
            internalErrors => InvalidUnion(internalErrors),
            `[${errorVarsRef.contents}]`,
          ) ++
          codeEndRef.contents

        outputVar
      }),
      ~maybeTypeFilter=None,
    )
  }
}

let list = struct => {
  struct
  ->Array.factory
  ->transform(_ => {
    parser: array => array->Belt.List.fromArray,
    serializer: list => list->Belt.List.toArray,
  })
}

let json = makeWithNoopSerializer(
  ~name=primitiveName,
  ~tagged=JSON,
  ~metadataMap=Metadata.Map.empty,
  ~maybeTypeFilter=None,
  ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
    let rec parse = (input, ~path=path) => {
      switch input->Stdlib.Type.typeof {
      | #number if Js.Float.isNaN(input->(Obj.magic: unknown => float))->not =>
        input->(Obj.magic: unknown => Js.Json.t)
      | #object =>
        if input === %raw(`null`) {
          input->(Obj.magic: unknown => Js.Json.t)
        } else if input->Stdlib.Array.isArray {
          let input = input->(Obj.magic: unknown => array<unknown>)
          let output = []
          for idx in 0 to input->Js.Array2.length - 1 {
            let inputItem = input->Js.Array2.unsafe_get(idx)
            output
            ->Js.Array2.push(
              inputItem->parse(~path=path->Path.concat(Path.fromLocation(idx->Js.Int.toString))),
            )
            ->ignore
          }
          output->Js.Json.array
        } else {
          let input = input->(Obj.magic: unknown => Js.Dict.t<unknown>)
          let keys = input->Js.Dict.keys
          let output = Js.Dict.empty()
          for idx in 0 to keys->Js.Array2.length - 1 {
            let key = keys->Js.Array2.unsafe_get(idx)
            let field = input->Js.Dict.unsafeGet(key)
            output->Js.Dict.set(key, field->parse(~path=path->Path.concat(Path.fromLocation(key))))
          }
          output->Js.Json.object_
        }

      | #string
      | #boolean =>
        input->(Obj.magic: unknown => Js.Json.t)

      | _ =>
        InternalError.raise(
          ~path,
          ~code=InvalidType({
            expected: selfStruct,
            received: input,
          }),
          ~operation=Parsing,
        )
      }
    }
    let input = b->B.useInput

    `${b->B.embed(parse)}(${input})`
  }),
)

type catchCtx<'value> = {
  @as("e") error: error,
  @as("i") input: unknown,
  @as("s") struct: t<'value>,
  @as("f") fail: 'a. (string, ~path: Path.t=?) => 'a,
  @as("w") failWithError: 'a. error => 'a,
}
let catch = (struct, getFallbackValue) => {
  let struct = struct->toUnknown
  make(
    ~name=struct.name,
    ~parseOperationBuilder=Builder.make((b, ~selfStruct, ~path) => {
      let inputVar = b->B.useInputVar
      b->B.withCatch(
        ~catch=(b, ~errorVar) => Some(
          `${b->B.embed((input, internalError) =>
              getFallbackValue({
                input,
                error: internalError,
                struct: selfStruct->castUnknownStructToAnyStruct,
                failWithError: (error: error) => {
                  InternalError.raise(
                    ~path=path->Path.concat(error.path),
                    ~code=error.code,
                    ~operation=b.operation,
                  )
                },
                fail: (message, ~path as customPath=Path.empty) => {
                  InternalError.raise(
                    ~path=path->Path.concat(customPath),
                    ~code=OperationFailed(message),
                    ~operation=b.operation,
                  )
                },
              })
            )}(${inputVar},${errorVar})`,
        ),
        b => {
          b->B.useWithTypeFilter(~struct, ~input=inputVar, ~path)
        },
      )
    }),
    ~serializeOperationBuilder=struct.serializeOperationBuilder,
    ~tagged=struct.tagged,
    ~maybeTypeFilter=None,
    ~metadataMap=struct.metadataMap,
  )
}

let deprecationMetadataId: Metadata.Id.t<string> = Metadata.Id.make(
  ~namespace="rescript-struct",
  ~name="deprecation",
)

let deprecate = (struct, message) => {
  struct->Metadata.set(~id=deprecationMetadataId, message)
}

let deprecation = struct => struct->Metadata.get(~id=deprecationMetadataId)

let descriptionMetadataId: Metadata.Id.t<string> = Metadata.Id.make(
  ~namespace="rescript-struct",
  ~name="description",
)

let describe = (struct, description) => {
  struct->Metadata.set(~id=descriptionMetadataId, description)
}

let description = struct => struct->Metadata.get(~id=descriptionMetadataId)

module Error = {
  type class
  let class: class = %raw("RescriptStructError")

  let make = InternalError.make

  let raise = (error: error) => error->Stdlib.Exn.raiseAny

  let rec reason = (error, ~nestedLevel=0) => {
    switch error.code {
    | OperationFailed(reason) => reason
    | InvalidOperation({description}) => description
    | UnexpectedAsync => "Encountered unexpected asynchronous transform or refine. Use S.parseAsyncWith instead of S.parseWith"
    | ExcessField(fieldName) =>
      `Encountered disallowed excess key ${fieldName->Stdlib.Inlined.Value.fromString} on an object. Use Deprecated to ignore a specific field, or S.Object.strip to ignore excess keys completely`
    | InvalidType({expected, received}) =>
      `Expected ${expected.name()}, received ${received->Literal.classify->Literal.toText}`
    | InvalidLiteral({expected, received}) =>
      `Expected ${expected->Literal.toText}, received ${received->Literal.classify->Literal.toText}`
    | InvalidJsonStruct(struct) => `The struct ${struct.name()} is not compatible with JSON`
    | InvalidTupleSize({expected, received}) =>
      `Expected Tuple with ${expected->Stdlib.Int.unsafeToString} items, received ${received->Stdlib.Int.unsafeToString}`
    | InvalidUnion(errors) => {
        let lineBreak = `\n${" "->Js.String2.repeat(nestedLevel * 2)}`
        let reasons =
          errors
          ->Js.Array2.map(error => {
            let reason = error->reason(~nestedLevel=nestedLevel->Stdlib.Int.plus(1))
            let location = switch error.path {
            | "" => ""
            | nonEmptyPath => `Failed at ${nonEmptyPath}. `
            }
            `- ${location}${reason}`
          })
          ->Stdlib.Array.unique
        `Invalid union with following errors${lineBreak}${reasons->Js.Array2.joinWith(lineBreak)}`
      }
    }
  }

  let reason = reason->(Obj.magic: ((error, ~nestedLevel: int=?) => string) => error => string)

  let message = error => {
    let operation = switch error.operation {
    | Serializing => "serializing"
    | Parsing => "parsing"
    }
    let pathText = switch error.path {
    | "" => "root"
    | nonEmptyPath => nonEmptyPath
    }
    `Failed ${operation} at ${pathText}. Reason: ${error->reason}`
  }
}

let inline = {
  let rec internalInline = (struct, ~variant as maybeVariant=?, ()) => {
    let metadataMap = struct.metadataMap->Stdlib.Dict.copy

    let inlinedStruct = switch struct->classify {
    | Literal(literal) => `S.literal(%raw(\`${literal->Literal.toText}\`))`
    | Union(unionStructs) => {
        let variantNamesCounter = Js.Dict.empty()
        `S.union([${unionStructs
          ->Js.Array2.map(s => {
            let variantName = s.name()
            let numberOfVariantNames = switch variantNamesCounter->Js.Dict.get(variantName) {
            | Some(n) => n
            | None => 0
            }
            variantNamesCounter->Js.Dict.set(variantName, numberOfVariantNames->Stdlib.Int.plus(1))
            let variantName = switch numberOfVariantNames {
            | 0 => variantName
            | _ =>
              variantName ++ numberOfVariantNames->Stdlib.Int.plus(1)->Stdlib.Int.unsafeToString
            }
            let inlinedVariant = `#${variantName->Stdlib.Inlined.Value.fromString}`
            s->internalInline(~variant=inlinedVariant, ())
          })
          ->Js.Array2.joinWith(", ")}])`
      }
    | JSON => `S.json`
    | Tuple([s1]) => `S.tuple1(${s1->internalInline()})`
    | Tuple([s1, s2]) => `S.tuple2(${s1->internalInline()}, ${s2->internalInline()})`
    | Tuple([s1, s2, s3]) =>
      `S.tuple3(${s1->internalInline()}, ${s2->internalInline()}, ${s3->internalInline()})`
    | Tuple(tupleStructs) =>
      `S.tuple(s => (${tupleStructs
        ->Js.Array2.mapi((s, idx) =>
          `s.item(${idx->Stdlib.Int.unsafeToString}, ${s->internalInline()})`
        )
        ->Js.Array2.joinWith(", ")}))`
    | Object({fieldNames: []}) => `S.object(_ => ())`
    | Object({fieldNames, fields}) =>
      `S.object(s =>
  {
    ${fieldNames
        ->Js.Array2.map(fieldName => {
          `${fieldName->Stdlib.Inlined.Value.fromString}: s.field(${fieldName->Stdlib.Inlined.Value.fromString}, ${fields
            ->Js.Dict.unsafeGet(fieldName)
            ->internalInline()})`
        })
        ->Js.Array2.joinWith(",\n    ")},
  }
)`
    | String => `S.string`
    | Int => `S.int`
    | Float => `S.float`
    | Bool => `S.bool`
    | Option(struct) => `S.option(${struct->internalInline()})`
    | Null(struct) => `S.null(${struct->internalInline()})`
    | Never => `S.never`
    | Unknown => `S.unknown`
    | Array(struct) => `S.array(${struct->internalInline()})`
    | Dict(struct) => `S.dict(${struct->internalInline()})`
    }

    let inlinedStruct = switch struct->Option.default {
    | Some(default) => {
        metadataMap->Stdlib.Dict.deleteInPlace(Option.defaultMetadataId->Metadata.Id.toKey)
        switch default {
        | Value(defaultValue) =>
          inlinedStruct ++
          `->S.Option.getOr(%raw(\`${defaultValue->Stdlib.Inlined.Value.stringify}\`))`
        | Callback(defaultCb) =>
          inlinedStruct ++
          `->S.Option.getOrWith(() => %raw(\`${defaultCb()->Stdlib.Inlined.Value.stringify}\`))`
        }
      }

    | None => inlinedStruct
    }

    let inlinedStruct = switch struct->deprecation {
    | Some(message) => {
        metadataMap->Stdlib.Dict.deleteInPlace(deprecationMetadataId->Metadata.Id.toKey)
        inlinedStruct ++ `->S.deprecate(${message->Stdlib.Inlined.Value.fromString})`
      }

    | None => inlinedStruct
    }

    let inlinedStruct = switch struct->description {
    | Some(message) => {
        metadataMap->Stdlib.Dict.deleteInPlace(descriptionMetadataId->Metadata.Id.toKey)
        inlinedStruct ++ `->S.describe(${message->Stdlib.Inlined.Value.stringify})`
      }

    | None => inlinedStruct
    }

    let inlinedStruct = switch struct->classify {
    | Object({unknownKeys: Strict}) => inlinedStruct ++ `->S.Object.strict`
    | _ => inlinedStruct
    }

    let inlinedStruct = switch struct->classify {
    | String
    | Literal(String(_)) =>
      switch struct->String.refinements {
      | [] => inlinedStruct
      | refinements =>
        metadataMap->Stdlib.Dict.deleteInPlace(String.Refinement.metadataId->Metadata.Id.toKey)
        inlinedStruct ++
        refinements
        ->Js.Array2.map(refinement => {
          switch refinement {
          | {kind: Email, message} =>
            `->S.String.email(~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Url, message} =>
            `->S.String.url(~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Uuid, message} =>
            `->S.String.uuid(~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Cuid, message} =>
            `->S.String.cuid(~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Min({length}), message} =>
            `->S.String.min(${length->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Max({length}), message} =>
            `->S.String.max(${length->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Length({length}), message} =>
            `->S.String.length(${length->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Pattern({re}), message} =>
            `->S.String.pattern(%re(${re
              ->Stdlib.Re.toString
              ->Stdlib.Inlined.Value.fromString}), ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Datetime, message} =>
            `->S.String.datetime(~message=${message->Stdlib.Inlined.Value.fromString})`
          }
        })
        ->Js.Array2.joinWith("")
      }
    | Int =>
      // | Literal(Int(_)) ???
      switch struct->Int.refinements {
      | [] => inlinedStruct
      | refinements =>
        metadataMap->Stdlib.Dict.deleteInPlace(Int.Refinement.metadataId->Metadata.Id.toKey)
        inlinedStruct ++
        refinements
        ->Js.Array2.map(refinement => {
          switch refinement {
          | {kind: Max({value}), message} =>
            `->S.Int.max(${value->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Min({value}), message} =>
            `->S.Int.min(${value->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Port, message} =>
            `->S.Int.port(~message=${message->Stdlib.Inlined.Value.fromString})`
          }
        })
        ->Js.Array2.joinWith("")
      }
    | Float =>
      // | Literal(Float(_)) ???
      switch struct->Float.refinements {
      | [] => inlinedStruct
      | refinements =>
        metadataMap->Stdlib.Dict.deleteInPlace(Float.Refinement.metadataId->Metadata.Id.toKey)
        inlinedStruct ++
        refinements
        ->Js.Array2.map(refinement => {
          switch refinement {
          | {kind: Max({value}), message} =>
            `->S.Float.max(${value->Stdlib.Inlined.Float.toRescript}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Min({value}), message} =>
            `->S.Float.min(${value->Stdlib.Inlined.Float.toRescript}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          }
        })
        ->Js.Array2.joinWith("")
      }

    | Array(_) =>
      switch struct->Array.refinements {
      | [] => inlinedStruct
      | refinements =>
        metadataMap->Stdlib.Dict.deleteInPlace(Array.Refinement.metadataId->Metadata.Id.toKey)
        inlinedStruct ++
        refinements
        ->Js.Array2.map(refinement => {
          switch refinement {
          | {kind: Max({length}), message} =>
            `->S.Array.max(${length->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Min({length}), message} =>
            `->S.Array.min(${length->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          | {kind: Length({length}), message} =>
            `->S.Array.length(${length->Stdlib.Int.unsafeToString}, ~message=${message->Stdlib.Inlined.Value.fromString})`
          }
        })
        ->Js.Array2.joinWith("")
      }

    | _ => inlinedStruct
    }

    let inlinedStruct = if metadataMap->Js.Dict.keys->Js.Array2.length !== 0 {
      `{
  let s = ${inlinedStruct}
  let _ = %raw(\`s.m = ${metadataMap->Js.Json.stringifyAny->Belt.Option.getUnsafe}\`)
  s
}`
    } else {
      inlinedStruct
    }

    let inlinedStruct = switch maybeVariant {
    | Some(variant) => inlinedStruct ++ `->S.variant(v => ${variant}(v))`
    | None => inlinedStruct
    }

    inlinedStruct
  }

  struct => {
    // Have it only for the sake of importing Caml_option in a less painfull way
    // Not related to the function at all
    if %raw(`false`) {
      switch %raw(`void 0`) {
      | Some(v) => v
      | None => ()
      }
    }

    struct->toUnknown->internalInline()
  }
}

let object = Object.factory
let never = Never.struct
let unknown = Unknown.struct
let string = String.struct
let bool = Bool.struct
let int = Int.struct
let float = Float.struct
let null = Null.factory
let option = Option.factory
let array = Array.factory
let dict = Dict.factory
let variant = Variant.factory
let tuple = Tuple.factory
let tuple1 = v0 => tuple(s => s.item(0, v0))
let tuple2 = (v0, v1) => tuple(s => (s.item(0, v0), s.item(1, v1)))
let tuple3 = (v0, v1, v2) => tuple(s => (s.item(0, v0), s.item(1, v1), s.item(2, v2)))
let union = Union.factory
let jsonString = JsonString.factory

@send
external name: t<'a> => string = "n"

// =============
// JS/TS API
// =============

@tag("success")
type jsResult<'value> = | @as(true) Success({value: 'value}) | @as(false) Failure({error: error})

let toJsResult = (result: result<'value, error>): jsResult<'value> => {
  switch result {
  | Ok(value) => Success({value: value})
  | Error(error) => Failure({error: error})
  }
}

let js_parse = (struct, data) => {
  try {
    Success({
      value: parseAnyOrRaiseWith(data, struct),
    })
  } catch {
  | exn => Failure({error: exn->InternalError.getOrRethrow})
  }
}

let js_parseOrThrow = (struct, data) => {
  data->parseAnyOrRaiseWith(struct)
}

let js_parseAsync = (struct, data) => {
  data->parseAnyAsyncWith(struct)->Stdlib.Promise.thenResolve(toJsResult)
}

let js_serialize = (struct, value) => {
  try {
    Success({
      value: serializeToUnknownOrRaiseWith(value, struct),
    })
  } catch {
  | exn => Failure({error: exn->InternalError.getOrRethrow})
  }
}

let js_serializeOrThrow = (struct, value) => {
  value->serializeToUnknownOrRaiseWith(struct)
}

let js_transform = (struct, ~parser as maybeParser=?, ~serializer as maybeSerializer=?) => {
  struct->transform(s => {
    {
      parser: ?switch maybeParser {
      | Some(parser) => Some(v => parser(v, s))
      | None => None
      },
      serializer: ?switch maybeSerializer {
      | Some(serializer) => Some(v => serializer(v, s))
      | None => None
      },
    }
  })
}

let js_refine = (struct, refiner) => {
  struct->refine(s => {
    v => refiner(v, s)
  })
}

let noop = a => a
let js_asyncParserRefine = (struct, refine) => {
  struct->transform(s => {
    {
      asyncParser: v => () => refine(v, s)->Stdlib.Promise.thenResolve(() => v),
      serializer: noop,
    }
  })
}

let js_optional = (struct, maybeOr) => {
  let struct = option(struct)
  switch maybeOr {
  | Some(or) if Js.typeof(or) === "function" => struct->Option.getOrWith(or->Obj.magic)->Obj.magic
  | Some(or) => struct->Option.getOr(or->Obj.magic)->Obj.magic
  | None => struct
  }
}

let js_tuple = definer => {
  if Js.typeof(definer) === "function" {
    let definer = definer->(Obj.magic: unknown => Tuple.ctx => 'a)
    tuple(definer)
  } else {
    let structs = definer->(Obj.magic: unknown => array<t<unknown>>)
    tuple(s => {
      structs->Js.Array2.mapi((struct, idx) => {
        s.item(idx, struct)
      })
    })
  }
}

let js_custom = (~name, ~parser as maybeParser=?, ~serializer as maybeSerializer=?, ()) => {
  custom(name, s => {
    {
      parser: ?switch maybeParser {
      | Some(parser) => Some(v => parser(v, s))
      | None => None
      },
      serializer: ?switch maybeSerializer {
      | Some(serializer) => Some(v => serializer(v, s))
      | None => None
      },
    }
  })
}

let js_object = definer => {
  if Js.typeof(definer) === "function" {
    let definer = definer->(Obj.magic: unknown => Object.ctx => 'a)
    object(definer)
  } else {
    let definer = definer->(Obj.magic: unknown => Js.Dict.t<t<unknown>>)
    object(s => {
      let definition = Js.Dict.empty()
      let fieldNames = definer->Js.Dict.keys
      for idx in 0 to fieldNames->Js.Array2.length - 1 {
        let fieldName = fieldNames->Js.Array2.unsafe_get(idx)
        let struct = definer->Js.Dict.unsafeGet(fieldName)
        definition->Js.Dict.set(fieldName, s.field(fieldName, struct))
      }
      definition
    })
  }
}