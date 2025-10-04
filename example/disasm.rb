require 'ncpp'

start_time = Time.now

puts 'Loading rom...'
rom = Nitro::Rom.new('Ratatouille.nds')

NCPP.show_rom_info(rom)

puts "Ov0 sinit start: " + rom.ovt.get_entry(0)[:sinit_start].to_hex
puts "Ov1 sinit start: " + rom.ovt.get_entry(1)[:sinit_start].to_hex
puts "Ov2 sinit start: " + rom.ovt.get_entry(2)[:sinit_start].to_hex

# puts 'Loading symbols...'
# Unarm.load_symbols9('symbols9.x')

f = File.open('rat-disasm.txt', 'w')

puts 'Disassembling arm9...'

# Here we treat every word in the binary as if it's an arm instruction; this is of course not reality
rom.arm9.each_ins {|ins| f.puts "#{ins.addr.to_hex}: #{ins.str}" }

f.puts

rom.each_overlay do |ov, id|
  puts "Disassembling overlay#{id}"
  ov.each_ins {|ins| f.puts "#{ins.addr.to_hex}: #{ins.str}" }
  f.puts
end

f.close

puts "Done! Took #{Time.now - start_time} seconds."
