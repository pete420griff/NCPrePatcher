require 'ncpp'

start_time = Time.now

puts 'Loading rom...'
rom = Nitro::Rom.new('NSMB_Test.nds')

puts 'Loading symbols...'
Unarm.load_symbols9('symbols9-nsmb.x')

f = File.open('nsmb-disasm.txt', 'w')

puts 'Disassembling arm9...'
rom.arm9.each_ins {|ins| f.puts "#{ins.addr.to_hex}: #{ins.str}" }

f.puts

rom.each_overlay do |ov, id|
  puts "Disassembling overlay#{id}"
  ov.each_ins {|ins| f.puts "#{ins.addr.to_hex}: #{ins.str}" }
end

f.close

puts "Done! Took #{Time.now - start_time} seconds."
