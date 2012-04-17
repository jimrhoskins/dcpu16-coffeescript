{assemble} = require '../lib/machine'
require 'should'

describe 'Assebler', ->
  describe 'SET', ->
    it 'should assign literals into registers', ->
      code1= assemble  "SET A, 0x30"
      code2= assemble  ";\nset a,0x30 ;comment"
      code2.should.eql code1
      code1.should.eql [0x7c01, 0x0030]

    it 'should assign literals into literal pointer', ->
      code1 = assemble "SET [0x1000] 0x20"
      code2 = assemble "set [ 0x1000 ], 0x20;comment"
      code2.should.eql code1
      code1.should.eql [0x7de1, 0x1000, 0x0020]

    it 'should assign register offset literals into literal pointer', ->
      code1 = assemble "SET [0x2000+I] [A]"
      code2 = assemble "\t\tSET [ 0x2000\t   +   i ] [   a ];[whatever]"
      code2.should.eql code1
      code1.should.eql [0x2161, 0x2000]

    it 'should assign pop into register', ->
      code1 = assemble "SET PC POP"
      code2 = assemble "set pc, pop"
      code2.should.eql code1
      code1.should.eql [0x61c1]

  describe 'SUB', ->
    it 'should subtract a pointer from a register', ->
      code1 = assemble "SUB A, [0x1000]"
      code2 = assemble "\t sub\ta,[  0x1000] ;;;;"
      code2.should.eql code1
      code1.should.eql [0x7803, 0x1000]

    it 'should subtract a literal from a register', ->
      code1 = assemble "SUB I, 1"
      code2 = assemble "\t sub\ti,1 ;;;;"
      code2.should.eql code1
      code1.should.eql [0x8463]

  describe 'IFN', ->

    it 'should compare a register to a small literal', ->
      code1 = assemble 'IFN A, 0x10'
      code2 = assemble '\tifn a\t0x10;'
      code2.should.eql code1
      code2.should.eql [0xc00d]

  describe 'JSR', ->

    it 'should compare a register to a small literal', ->
      code1 = assemble 'JSR 0x1234'
      code2 = assemble 'jsr 0x1234;woo'
      code2.should.eql code1
      code2.should.eql [0x7c10, 0x1234]
