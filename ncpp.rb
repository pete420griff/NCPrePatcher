require_relative 'lib/nitro.rb'
require_relative 'lib/unarm.rb'
require_relative 'lib/utils.rb'

$rom = Nitro::Rom.new('NSMB.nds')

# $ins = Unarm::ArmIns.disasm($rom.arm9.read32(0x02080104))


if $PROGRAM_NAME == __FILE__
  rom = Nitro::Rom.new(ARGV.length == 0 ? "NSMB.nds" : ARGV[0])
  puts "Game title: #{rom.header.game_title}"
  puts "Game code: #{rom.header.game_code}"
  puts "Maker code: #{rom.header.maker_code}"
  puts "Size: #{(rom.size / 1024.0 / 1024.0).round(2)} MB"
  puts "Overlay count: #{rom.overlay_count}"
  puts

  Unarm.load_symbols9('symbols9.x')
  Unarm.load_symbols7('symbols7.x')

  # ov24_syms = Unarm::Symbols.new(syms: Unarm.symbols, locs: ['ov24'])

  # puts Unarm::ArmIns.disasm(rom.ov10.read32(rom.ov10.start_addr),rom.ov10.start_addr, 'ov10').str

  # rom.ov10.read(..rom.ov10.start_addr+0x30).each do |word, addr|
  #   puts Unarm::ArmIns.disasm(word, addr, 'ov10').str
  # end

  start_time = Time.now

  f = File.new('nsmb-disasm.txt', 'w')

  # Unarm.use_arm7

  # puts "Disassembling arm7..."
  # f.puts '-- ARM7 --'
  # rom.arm9.read.each do |word, addr|
  #   sym = Unarm.sym_map.key(addr)
  #   f.puts sym if sym
  #   f.puts "#{addr.to_hex}: #{Unarm::ArmIns.disasm(word, addr, 'arm7').str}"
  # end

  Unarm.use_arm9

  puts "Disassembling arm9..."
  f.puts '-- ARM9 --'
  rom.arm9.read.each do |word, addr|
    sym = Unarm.sym_map.key(addr)
    f.puts sym if sym
    f.puts "#{addr.to_hex}: #{Unarm::ArmIns.disasm(word, addr, 'arm9').str}"
  end

  # rom.overlay_count.times do |i|
  #   puts "Disassembling ov#{i}..."
  #   f.puts "-- OVERLAY #{i} --"
  #   syms = Unarm.symbols.locs["ov#{i}"] ? Unarm::Symbols.new(syms: Unarm.symbols, locs: ["ov#{i}"]) : nil
  #   rom.get_overlay(i).read.each do |word, addr|
  #     sym = syms ? syms.map.key(addr) : nil
  #     f.puts sym if sym
  #     f.puts "#{addr.to_hex}: #{Unarm::ArmIns.disasm(word, addr, "ov#{i}").str}"
  #   end
  # end

  # f.close

  puts "Done! Took #{(Time.now - start_time).round(3)} seconds."

end
