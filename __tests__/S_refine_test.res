open Ava

test("Successfully refines on parsing", t => {
  let struct = S.int->S.refine(value =>
    if value < 0 {
      S.fail("Should be positive")
    }
  )

  t->Assert.deepEqual(%raw(`12`)->S.parseAnyWith(struct), Ok(12), ())
  t->Assert.deepEqual(
    %raw(`-12`)->S.parseAnyWith(struct),
    Error({
      code: OperationFailed("Should be positive"),
      operation: Parsing,
      path: S.Path.empty,
    }),
    (),
  )
})

test("Fails with custom path", t => {
  let struct = S.int->S.refine(value =>
    if value < 0 {
      S.fail(~path=S.Path.fromArray(["data", "myInt"]), "Should be positive")
    }
  )

  t->Assert.deepEqual(
    %raw(`-12`)->S.parseAnyWith(struct),
    Error({
      code: OperationFailed("Should be positive"),
      operation: Parsing,
      path: S.Path.fromArray(["data", "myInt"]),
    }),
    (),
  )
})

test("Successfully refines on serializing", t => {
  let struct = S.int->S.refine(value =>
    if value < 0 {
      S.fail("Should be positive")
    }
  )

  t->Assert.deepEqual(12->S.serializeToUnknownWith(struct), Ok(%raw("12")), ())
  t->Assert.deepEqual(
    -12->S.serializeToUnknownWith(struct),
    Error({
      code: OperationFailed("Should be positive"),
      operation: Serializing,
      path: S.Path.empty,
    }),
    (),
  )
})

asyncTest("Successfully refines on async parsing", async t => {
  let struct = S.int->S.asyncParserRefine(value =>
    Promise.resolve()->Promise.thenResolve(
      () => {
        if value < 0 {
          S.fail("Should be positive")
        }
      },
    )
  )

  t->Assert.deepEqual(await %raw(`12`)->S.parseAnyAsyncWith(struct), Ok(12), ())
  t->Assert.deepEqual(
    await %raw(`-12`)->S.parseAnyAsyncWith(struct),
    Error({
      code: OperationFailed("Should be positive"),
      operation: Parsing,
      path: S.Path.empty,
    }),
    (),
  )
})

test("Fails to parse async refinement using parseAnyWith", t => {
  let struct = S.string->S.asyncParserRefine(_ => Promise.resolve())

  t->Assert.deepEqual(
    %raw(`"Hello world!"`)->S.parseAnyWith(struct),
    Error({
      code: UnexpectedAsync,
      operation: Parsing,
      path: S.Path.empty,
    }),
    (),
  )
})

asyncTest("Successfully parses async refinement using parseAsyncWith", t => {
  let struct = S.string->S.asyncParserRefine(_ => Promise.resolve())

  %raw(`"Hello world!"`)
  ->S.parseAsyncWith(struct)
  ->Promise.thenResolve(result => {
    t->Assert.deepEqual(result, Ok("Hello world!"), ())
  })
})

asyncTest("Fails to parse async refinement with user error", t => {
  let struct =
    S.string->S.asyncParserRefine(_ => Promise.resolve()->Promise.then(() => S.fail("User error")))

  %raw(`"Hello world!"`)
  ->S.parseAsyncWith(struct)
  ->Promise.thenResolve(result => {
    t->Assert.deepEqual(
      result,
      Error({
        S.code: OperationFailed("User error"),
        path: S.Path.empty,
        operation: Parsing,
      }),
      (),
    )
  })
})

asyncTest("Can apply other actions after async refinement", t => {
  let struct =
    S.string
    ->S.asyncParserRefine(_ => Promise.resolve())
    ->S.String.trim()
    ->S.asyncParserRefine(_ => Promise.resolve())

  %raw(`"    Hello world!"`)
  ->S.parseAsyncWith(struct)
  ->Promise.thenResolve(result => {
    t->Assert.deepEqual(result, Ok("Hello world!"), ())
  })
})
