import macros

proc getSubType(T: NimNode): NimNode =
  # Get the subtype T of an input

  let baseTy = getTypeInst(T)
  if eqIdent(baseTy[0], "seq") or eqIdent(baseTy, "openarray"):
    result = baseTy[1]
  elif eqIdent(baseTy[0], "array"):
    result = baseTy[2]
  else:
    error "Unsupported container type: " & $baseTy[0]

proc injectParam(param: NimNode): NimNode =
  nnkPragmaExpr.newTree(
      newIdentNode($param),
      nnkPragma.newTree(ident("inject"))
    )

macro getOutputSubtype(values: untyped, containers: varargs[typed], loopBody: untyped): untyped =
  # Get the type of an expression on items of sevaral containers

  # This is the macro equivalent to the following template.
  # There is no simpler way as `type` cannot return void: https://github.com/nim-lang/Nim/issues/7397
  #
  # template test(a, b, ...: seq[int], loopBody: untyped): typedesc =
  #
  #   template test_type(): untyped =
  #     type((
  #       block:
  #         var
  #           x{.inject.}: type(items(a))
  #           y{.inject.}: type(items(b));
  #           ...
  #         loopBody
  #       ))
  #
  #   when compiles(test_type()):
  #     test_type()
  #   else:
  #     void


  let N = values.len
  assert containers.len == N

  var inject_params = nnkVarSection.newTree()

  for i in 0 ..< N:
    inject_params.add nnkIdentDefs.newTree(
      injectParam(values[i]),
      getSubType(containers[i]),
      newEmptyNode()
    )

  let loopBodyType = nnkTypeOfExpr.newTree(
      nnkBlockStmt.newTree(
        newEmptyNode(),
        nnkStmtList.newTree(
          inject_params,
          loopBody
        )
      )
  )

  result = quote do:
    when compiles(`loopBodyType`):
      # If it's void it fails to compile
      # Not sure what happens if it fails due to user error.
      `loopBodyType`
    else:
      void

proc pop(tree: var NimNode): NimNode =
  result = tree[tree.len-1]
  tree.del(tree.len-1)

macro generateZip(
                  zipName: NimNode,
                  index: untyped,
                  enumerate: static[bool],
                  containers: varargs[typed],
                  mutables: static[seq[int]] # Those are a seq[bool]: https://github.com/nim-lang/Nim/issues/7375
                  ): typed =

  let N = containers.len
  assert mutables.len == N
  assert N > 1, "Error: only 0 or 1 argument passed." &
    "\nThe zip macros should be called directly " &
    "with all input sequences like so: zip(s1, s2, s3)."

  # 1. Initialization
  result = newStmtList()

  # Now we create a `zipImpl` iterator with N arguments

  # 2. Create the parameters: Return type + N arguments
  var zipParams = newSeq[NimNode](N+1)

  # 2.1 Return type
  zipParams[0] = newPar()
  if enumerate:
    zipParams[0].add getType(int)
  for i in 0 ..< N:
    let subt = getSubType(containers[i])
    if mutables[i] == 1:
      zipParams[0].add nnkVarTy.newtree(subt)
    else:
      zipParams[0].add subt

  # 2.2 Parameters
  for i in 0 ..< N:
    let s = newIdentDefs(ident("loopfusion_container" & $i), containers[i].getTypeInst)
    zipParams[i+1] = s

  # 3. Body
  # defined below, see Note
  # var zipBody = newStmtList()

  # 3.1 Check that the length of the seqs are the same
  let container0 = containers[0]
  let size0 = newIdentNode("loopfusion_size0")
  # NOTE: using quote do will fail with an `illegal capture` error,
  # hence build AST manually
  #zipBody.add quote do:
  #  let `size0` = `container0`.len
  var zipBody =  nnkStmtList.newTree(
    nnkLetSection.newTree(
      nnkIdentDefs.newTree(
        newIdentNode($size0),
        newEmptyNode(),
        nnkDotExpr.newTree(
          newIdentNode($container0),
          newIdentNode("len")
        )
      )
    )
  )

  block:
    var i = 1 # we don't check the size0 of the first container
    while i < containers.len:
      let t = containers[i]
      let check = quote do:
        assert(`size0` == `t`.len, "forZip macro: parameter " &
          `t`.astTostr &
          " in position #" & $(`i`) &
          " has a different length.")
      zipBody.add check
      inc i

  # 3.2 We setup the loop index
  let iter = if enumerate:
                newIdentNode($index)
              else:
                newIdentNode("loopfusion_index_")
  let iter_inject = if enumerate: injectParam(iter)
                    else: iter

  # 3.2 We create the innermost (s0[i], s1[i], s2[i], ..., s100[i])
  var inner = newPar()
  if enumerate:
    inner.add newIdentNode($index)
  for arg in containers:
    inner.add nnkBracketExpr.newTree(arg, iter)

  # 3.3 We create the for loop
  var forLoop = nnkForStmt.newTree()
  # for i in 0 ..< size0:
  #   yield (s0[i], s1[i], s2[i], ..., s100[i])
  #   OR
  #   yield (i, s0[i], s1[i], s2[i], ..., s100[i])

  forLoop.add iter_inject

  forLoop.add nnkInfix.newTree(
      ident("..<"),
      newIntLitNode(0),
      size0
    )

  forLoop.add nnkYieldStmt.newTree(
      inner
    )

  zipBody.add forLoop

  # 3.4 Construct the iterator
  var zipImpl = newProc(
    name = zipName,
    params = zipParams,
    body = zipBody,
    procType = nnkIteratorDef
  )

  # 4. Make it visible
  result.add zipImpl

macro forZipImpl[N: static[int]](
  index: untyped,
  enumerate: static[bool],
  values: untyped,
  containers: varargs[typed],
  mutables: static[array[N, int]], # Those are a seq[bool]: https://github.com/nim-lang/Nim/issues/7375
  loopBody: untyped
  ): untyped =

  assert values.len == N
  assert containers.len == N

  # 1. Initialization
  result = newStmtList()

  # 2. Create the idents injected
  var idents_inject = newPar()
  for ident in values:
    idents_inject.add injectParam(ident)

  # 3. Create the index injected if applicable
  let idx_inject = injectParam(index)

  # 4. Checking the result type and creating put it in temp space if it's
  #    not void
  let outType = getAST(getOutputSubtype(values,containers, loopBody))
  let loopResult = genSym(nskVar, "loopfusion_result_")

  result.add quote do:
    when not (`outType` is void):
      var `loopResult`: seq[`outType`] = @[]

  # 5. Generate the matching zip iterator
  let zipName = if enumerate:
                  genSym(nskIterator,"loopfusion_enumerateZipImpl_" & $N & "_")
                else:
                  genSym(nskIterator,"loopfusion_zipImpl_" & $N & "_")

  result.add getAST(generateZip(zipName, index, enumerate, containers, mutables))

  # 6. Creating the call
  var zipCall = newCall(zipName)
  containers.copyChildrenTo zipCall

  # 7. For statement/expression
  var forLoop = nnkForStmt.newTree()
  if enumerate:
    forLoop.add idx_inject
  idents_inject.copyChildrenTo forLoop
  forLoop.add zipCall

  forLoop.add quote do:
    when `outType` is void:
      `loopbody`
    else:
      `loopResult`.add `loopBody`

  # 8. Finalize
  result.add forLoop
  result.add quote do:
    when not (`outType` is void):
      `loopResult`


macro forZip*(args: varargs[untyped]): untyped =
  ## Iterates over a variadic number of sequences or arrays

  ## Example:
  ##
  ## let a = [1, 2, 3]
  ## let b = @[11, 12, 13]
  ## let c = @[10, 10, 10]
  ##
  ## forZip [x, y, z], [a, b, c]:
  ##   echo (x + y) * z

  # In an untyped context, we can't deal with types at all so we reformat the args
  # and then pass the new argument to a typed macro

  var params = args
  var loopBody = params.pop

  var index = getType(int)              # to be replaced with the index variable if applicable
  var values = nnkBracket.newTree()
  var containers = nnkArgList.newTree()
  var mutables: seq[bool] = @[]
  var N = 0
  var enumerate = false

  for arg in params:
    case arg.kind:
    of nnkIdent:
      if N == 0:
        index = arg
        enumerate = true
      else:
        error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    of nnkInfix:
      if eqIdent(arg[0], "in"):
        values.add arg[1]
        if arg[2].kind == nnkVarTy:
          containers.add arg[2][0]
          mutables.add true
        else:
          containers.add arg[2] # TODO: use an intermediate assignation if it's a result of a proc to avoid calling it multiple time
          mutables.add false
      else:
        error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    of nnkStmtList:
      # for the case where an arg is
      # `contains(x, idx)`
      let call = arg[0]
      expectKind(call, nnkCall)
      if eqIdent(call[0], "contains"):
        values.add call[2]
        if call[1].kind == nnkVarTy:
          containers.add call[1][0]
          mutables.add true
        else:
          containers.add call[1] # TODO: use an intermediate assignation if it's a result of a proc to avoid calling it multiple time
          mutables.add false
      else:
        error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    else:
      error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    inc N

  if enumerate:
    result = quote do:
      forZipImpl(`index`, true, `values`, `containers`, `mutables`,`loopBody`)
  else:
    result = quote do:
      forZipImpl(`index`, false, `values`, `containers`, `mutables`, `loopBody`)


template forEach*(args: varargs[untyped]): untyped {.deprecated: "forEach has been renamed forZip".}=
  forZip(args)
