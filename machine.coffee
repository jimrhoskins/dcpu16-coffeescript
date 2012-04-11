hex = (n) -> 
  s = "000" + n.toString(16)
  s[(s.length-4)...]

bin = (n) -> 
  s = "000000000000000" + n.toString(2)
  s[(s.length-16)...]

_bin = (str) -> parseInt(str, 2)

class Machine
  OPCODES: [
    "$OP", "SET", "ADD", "SUB",
    "MUL", "DIV", "MOD", "SHL",
    "SHR", "AND", "BOR", "XOR",
    "IFE", "IFN", "IFG", "IFB"
  ]

  NON_BASIC_OPCODES: [null, "JSR"]

  constructor: (program)->
    @memory = (data for data in program)
    print(@memory)

    @register =
      A: 0
      B: 0
      C: 0
      X: 0
      Y: 0
      Z: 0
      I: 0
      J: 0
      PC: 0
      SP: 0
      O: 0


  nextWord: ->
    @register.PC += 1
    @memory[@register.PC - 1]

  step: ->
    instruction = @nextWord()

    op = @getOp(instruction & 0x0f)

    if op is "$OP"
      op = @NON_BASIC_OPCODES[(instruction >> 4) & 0x3f]
      a = @getValue (instruction >> 10) & 0x3f
      b = undefined
    else
      a = @getValue (instruction >> 4)  & 0x3f
      b = @getValue (instruction >> 10) & 0x3f

    @exec op, a, b




  exec: (op, args...) ->
    if @skipNext
      @skipNext = false
      return
    if op? 
      console.log op, (a.repr for a in args when a?).join(', ')
      @[op].call(this,args...)
    else
      console.log '~SKIP~', op, (a.repr for a in args when a?).join(', ')


  pop: ->
    val = @peek()
    @register.SP = (@register.SP + 1) & 0xffff
    val

  peek: ->
    @memory[@register.SP]

  push: (val) ->
    @register.SP = (@register.SP - 1) & 0xffff
    @memory[@register.SP] = val & 0xffff
    console.log '+++++ PUSH', @memory[@register.SP], @register.SP

  getOp: (number) ->
    @OPCODES[number]

  getValue: (raw) ->
    get = set = null
    switch true
      # register
      when raw in [0x00..0x07]
        key = "ABCXYZIJ".charAt(raw)
        get = => @register[key]
        set = (val) => @register[key] = val
        repr = key

      # [register]
      when raw in [0x08..0x0f]
        key = "ABCXYZIJ".charAt(raw - 0x08)
        get = => @memory[@register[key]] or 0
        set = (val) => @memory[@register[key]] = val
        repr = "[#{key}]"

      # [next word + register]
      when raw in [0x10..0x17]
        value = @nextWord()
        key = "ABCXYZIJ".charAt(raw - 0x10)
        get = => @memory[value + @register[key]] or 0
        set = (val) => @memory[value + @register[key]] = val
        repr = "[0x#{value.toString(16)}+#{key}]"

      # POP
      when raw is 0x18
        value = @pop()
        get = => value
        set = => #crash
        repr = "POP"

      # PEEK
      when raw is 0x19
        value = @peek()
        get = => value
        set = => #crash
        repr = "PEEK"

      # PUSH
      when raw is 0x1a
        get = => #unknown
        set = (val) => @push(val)
        repr = "PUSH"

      # SP
      when raw is 0x1b
        get = => @register.SP
        set = (val) => @register.SP = val
        repr = "SP"

      # PC
      when raw is 0x1c
        get = => @register.PC
        set = (val) => @register.PC = val
        repr = "PC"

      # O
      when raw is 0x1d
        get = => @register.O
        set = (val) => @register.O = val
        repr = "O"

      # [next word]
      when raw is 0x1e
        value = @nextWord()
        get = => @memory[value] or 0
        set = (val) => @memory[value] = val
        repr = "[0x#{value.toString(16)}]"

      # next word (literal)
      when raw is 0x1f
        value = @nextWord()
        get = => value
        set = => #nope
        repr = "0x#{value.toString(16)}"

      when raw in [0x20..0x3f]
        value = raw - 0x20
        get = => value
        set = => #nope
        repr = "0x#{value.toString(16)}"



    unless get and set
      throw "Uh oh #{raw}"

    return {
      raw
      get
      set
      repr
    }


  JSR: (a) ->
    @push(@register.PC )
    @register.PC = a.get()
    # JSR

  SET: (a, b) ->
    a.set(b.get())

  ADD: (a, b) ->
    sum = a.get() + b.get()
    if sum > 0xffff
      @register.O = 0x0001
    else
      @register.O = 0x0
    a.set(sum & 0xffff)


  SUB: (a, b) ->
    result = a.get() - b.get()
    if result < 0
      @register.O = 0xffff
    else
      @register.O = 0x0
    a.set(result & 0xffff)

  MUL: (a, b) ->
    result = a.get() * b.get()
    @register.O = (result >> 16) & 0xffff
    a.set(result & 0xffff)

  DIV: (a, b) ->
    if b.get() is 0
      a.set(0x0)
      @register.O = 0x0
    else
      result = a / b
      @register.O = ((a.get() << 16)/b.get()) & 0xffff
      a.set(result & 0xffff)
    # SUB

  MOD: (a, b) ->
    if b.get() is 0
      a.set(0)
    else
      a.set((a%b) & 0xffff)

  SHL: (a, b) ->
    @register.O = ((a.get() << b.get()) >> 16) & 0xffff
    a.set((a.get() << b.get()) & 0xffff)

  SHR: (a, b) ->
    # SUB
    @register.O = ((a.get() << 16) >> b.get()) & 0xffff
    a.set((a.get() >> b.get()) & 0xffff)

  AND: (a, b) ->
    a.set(a.get() & b.get())

  BOR: (a, b) ->
    a.set(a.get() | b.get())

  XOR: (a, b) ->
    a.set(a.get() ^ b.get())

  IFE: (a, b) ->
    unless a.get() is b.get()
      @skipNext = true

  IFN: (a, b) ->
    unless a.get() isnt b.get()
      @skipNext = true

  IFG: (a, b) ->
    unless a.get() > b.get()
      @skipNext = true

  IFG: (a, b) ->
    unless (a.get() & b.get()) isnt 0
      @skipNext = true

class Assembler
  OPS:
    SET: 0x01
    ADD: 0x02
    SUB: 0x03
    MUL: 0x04
    DIV: 0x05
    MOD: 0x06
    SHL: 0x07
    SHR: 0x08
    AND: 0x09
    BOR: 0x0a
    XOR: 0x0b
    IFE: 0x0c
    IFN: 0x0d
    IFG: 0x0e
    IFB: 0x0f
    JSR: 0x10

  REGISTERS:
    A: 0x00
    B: 0x01
    C: 0x02
    X: 0x03
    Y: 0x04
    Z: 0x05
    I: 0x06
    J: 0x07
    POP:  0x18
    PEEK: 0x19
    PUSH: 0x1a
    SP:   0x1b
    PC:   0x1c
    O:    0x1d


  constructor: (@code) ->
    @instructions = []
    @labels = {}
    @read()
    console.lg
    @compile()
    #console.log @

  # Reads code and populates instructions array
  # instruction = [OP, ARGS...]
  read: ->
    # split code into multiple lines
    lines = @code.split(/\n+/)

    for line in lines
      line = @cleanLine line
      continue unless line.length
      tokens = @split line

      op = null
      args = []

      for token in tokens
        if @isLabel(token)
          # Store label with instruction number
          label = token[1...]
          if label of @labels
            @crash "Duplicate label #{label}"
          else
            @labels[token[1...]] = @instructions.length
        else if @isOp(token) and not op
          op = token
        else if op
          args.push token
        else
          @crash("Don't know what to do with #{token} in #{line}")

      if op
        @instructions.push [op, args...]

  # Convert instruction list to binary program
  compile: ->
    instructionMap = {}
    labelFixes = []
    @program = []
    for [op, args...],i in @instructions
      instructionMap[i] = @program.length
      word = 0
      word |= @OPS[op]
      next = []

      shift = -2
      # if lower 4 bits are 0, arg a is op, and only arg b exists
      if (word & 0xf) is 0
        shift = 4
      for arg in args
        shift += 6
        [pointer, arg] = @checkForPointer(arg)
        label=false

        # [next word + register]
        if arg.indexOf('+') isnt -1
          # split next word and register around + (and strip spaces)
          [literal, register] = arg.replace(/\s+/g, '').split('+')

          # Convert literal string to number for next word
          literal = parseInt(literal)
          if isNaN(literal)
            @crash 'Bad iteral in ' + op + args

          # Value code is 0x10 - 0x17, based on register
          code = (@REGISTERS[register] + 0x10)

          # Apply value to word
          word |= (code << shift)

          # push value to next word
          next.push literal
          continue

        # POP PEEK PUSH SP PC 0
        if arg of @REGISTERS and @REGISTERS[arg] > 0x07
          code = @REGISTERS[arg]
          word |= (code << shift)
          continue

        #  register and [register]
        if arg of @REGISTERS  and @REGISTERS[arg] <= 0x07
          # Grab value of named register
          code = @REGISTERS[arg]

          # If this is a pointer, increase value by 0x08
          code += 0x08 if pointer

          # Apply value to word
          word |= (code << shift )
          continue


        # next word and [next word] and literal value
        literal = null
        if @labels[arg]?
          label = true
          literal = @labels[arg]
          labelFixes.push @program.length + next.length + 1
        else
          literal = parseInt(arg)

        if literal? and not isNaN(literal)
          if literal > 0x1f or label # next word or [next word]
            code = 0x1e
            code += 1 unless pointer
            next.push literal
          else # literal
            code = literal + 0x20

          word |= (code << shift)
          continue




      # Push the instruction word into memory
      @program.push word
      # Push next word or words into memory, if any
      @program.push next...


    # Currently labels hold instruction number, not instruction address
    # Loop through incorrect addresses, and fix
    for address in labelFixes 
      @program[address] = instructionMap[@program[address]]



  # Determines if argument is a pointer [somevalue]
  # returns [isPointer?, someValue]
  checkForPointer: (arg) ->
    match = arg.match(/^\[\s*(.+)\s*\]$/)
    if match
      [true, match[1]]
    else
      [false, arg]


  # Cleans line of ASM
  cleanLine: (line) ->
    line
      .replace(/;.*$/,'')            #remove comments
      .replace(/(^\s+)|(\s+$)/g, '') #trim whitespace
      .replace(/[,\s]+/g, ' ')       #collapse adjacent whitespace

  # Split line into tokens (line must be clean)
  split: (line) ->
    line.split(' ')

  # token is a label (form of :loop-1label )
  isLabel: (token) -> 
    token.match(/^:[-_a-z0-9]+$/i)

  # Is an OP
  isOp: (token) -> 
    token of @OPS


  crash: (message = 'Unknown Error') -> throw message

# - TODO CLEAN THIS UP
cleanLine = -> [0, 0, 0, 0, 0, 0, 0, 0 ]

print = (memory) ->
  console.log "\n--------------- Memory Dump -----------------"
  lines = []
  for word, address in memory
    continue unless word
    line = Math.floor(address/8)
    col = address % 8
    lines[line] ?= cleanLine()
    lines[line][col] =word

  for line, lineno in lines
    continue unless line
    console.log hex(lineno*8) + ": " + (hex word for word in line).join(" ")
  console.log "---------------------------------------------"





CODE =
  """

  ;basic stuff
                SET A, 0x30              ; 7c01 0030
                SET [0x1000], 0x20       ; 7de1 1000 0020
                SUB A, [0x1000]          ; 7803 1000
                IFN A, 0x10              ; c00d 
                   SET PC, crash         ; 7dc1 001a [*]

  ; Do a loopy thing
                SET I, 10                ; a861
                SET A, 0x2000            ; 7c01 2000
  :loop         SET [0x2000+I], [A]      ; 2161 2000
                SUB I, 1                 ; 8463
                IFN I, 0                 ; 806d
                   SET PC, loop          ; 7dc1 000d [*]

  ; Call a subroutine
                SET X, 0x4               ; 9031
                JSR testsub              ; 7c10 0018 [*]
                SET PC, crash            ; 7dc1 001a [*]

  :testsub      SHL X, 4                 ; 9037
                SET PC, POP              ; 61c1
                  
  ; Hang forever. X should now be 0x40 if everything went right.
  :crash        SET PC, crash            ; 7dc1 001a [*]

  ; [*]: Note that these can be one word shorter and one cycle faster by using the short form (0x00-0x1f) of literals,
  ;      but my assembler doesn't support short form labels yet.
  """

dump = (machine) ->
  console.log (" #{x}  " for x in "ABCXYZIJ".split('')).join('|') + "| PC | SP | O"
  console.log (hex(machine.register[x]) for x in "A B C X Y Z I J PC SP O".split(' ')).join('|')
assemble = (code) ->
  (new Assembler code).program

if require.main is module
  #new Assembler CODE
  rl = require('readline').createInterface process.stdin, process.stdout

  machine = new Machine(assemble(CODE))
  rl.on 'line', ->
    machine.step()
    print(machine.memory)
    dump(machine)
    console.log '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'

