fs = require 'fs'
cpu = {Machine} = require './machine'
class Emulator
  loadSource: (source) ->
    @loadProgram cpu.assemble(source)

  loadProgram: (program) ->
    @machine = new Machine(program)

  run: (@progressive) ->
    screen = new Screen(@machine)
    #@machine.verbose = true
    while @machine.exited is false
      @machine.step()
      if @machine.videoDirty
        screen.display()
        @machine.videoDirty=false
        unless @progressive
          process.stdout.write((new Array(19)).join '\x1b[1A')
        else
          cpu.print(@machine.memory)
    screen.display() unless @progressive

  dump: ->
    cpu.print(@machine.memory)
    cpu.dump(@machine)

class Screen
  BORDER: '\x1b[46;34m#\x1b[49;39m'
  constructor: (@machine) ->
    @ram = @machine.memory
    #@ram = []
    #for x in [(0x8000)...(0x8000 + 32 * 16)]
      #word = (x ) % (0xff)
      #word = word << 8
      #word = word | ("x".charCodeAt() & 0xff)
      #@ram[x] = word
      ##
    #@ram[0x8001] = (0b00010111 << 8) | "x".charCodeAt()
    #@ram = machine.ram 
    #
  write: (args...) ->
    process.stdout.write(args.join(''))

  colors:
    0b000 : 0 #black
    0b001 : 4 #blue
    0b010 : 2 #green
    0b011 : 6 #cyan
    0b100 : 1 #red
    0b101 : 5 #magenta
    0b110 : 3 #yellow
    0b111 : 7 #white

  display: ->
    @write (new Array(35)).join(@BORDER), '\x1b[39;49m\n'
    for row in [0...16]
      @write @BORDER 
      for col in [0...32]
        # Read Word out of ram
        word = (@ram[0x8000 + (row * 32) + col] or 0) & 0xffff

        # Get character (fall back to space if unprintable)
        char = String.fromCharCode(word & 0x7f)
        char = ' ' if (word & 0x7f) < 0x20

        blink = if word & 0x80
          ";5"
        else
          ''

        bg = (word >> 8) & 0xf
        bg = @colors[bg & 0x7] + 40

        fg = (word >> 12) & 0xf
        fg = @colors[fg & 0x7] + 30
        @write "\x1b[#{fg};#{bg}#{blink}m#{char}\x1b[39;49;0m"
      @write @BORDER, '\n'
    @write (new Array(35)).join(@BORDER), '\x1b[39;49m\n'



if require.main is module
  e = new Emulator
  e.loadSource(fs.readFileSync("#{__dirname}/../code/matrix.dasm").toString())
  e.run(!true)
  e.dump()

