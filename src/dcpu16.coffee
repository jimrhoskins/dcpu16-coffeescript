#!/usr/bin/env coffee

fs = require 'fs'
cpu = require './machine'

command = process.argv[2]


loadHex = (code) ->
	program = []
	for word, index in code by 4
		program.push parseInt(code.substr(index, 4), 16)
	program

# compile file.asm
if command is 'compile' or command is 'c'
	infile  = process.argv[3]
	outfile = infile.replace(/\.asm$/i, '') + ".hex"

	source = fs.readFileSync(infile).toString()
	prog = cpu.assemble(source)
	hex = (cpu.hex(word) for word in prog).join('')

	fs.writeFileSync(outfile, hex)

	console.log "Compiled #{infile} to #{outfile}"

# decompile file.hex
if command is 'decompile' or command is 'd'
	infile  = process.argv[3]
	outfile = infile + ".d.asm"

	source = fs.readFileSync(infile).toString()
	unless source.match /^[a-f0-9]+$/i
		console.log "#{infile} doesn't seem to be a valid hex file"
	else
		prog = loadHex(source)
		machine = new cpu.Machine(prog)
		code = machine.decompile()
		console.log code


# run file.asm
if command is 'run' or command is 'r'
	infile = process.argv[3]
	source = fs.readFileSync(infile).toString()
	prog = cpu.assemble(source)
	machine = new cpu.Machine(prog, true)

	rl = require('readline').createInterface(process.stdin, process.stdout)
	rl.on 'line', ->
		machine.step()
		cpu.print(machine.memory)
		cpu.dump(machine)
		console.log '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'

if command is 'dump'
  infile = process.argv[3]
  source = fs.readFileSync(infile).toString()
  prog = cpu.assemble(source)
  cpu.print(prog)
