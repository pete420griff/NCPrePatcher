require_relative 'nitro.rb'
require_relative 'unarm.rb'
require_relative 'utils.rb'

require 'json'

module NCPP

  $CONFIG_FILE_PATH = 'ncpp_config.json'
  $clean_rom = nil
  $target_rom = nil

  @@config_template = {
    clean_rom: '', target_rom: '',
    symbols9: '', symbols7: ''
  }

  @@required_config_fields = [:clean_rom]

  def self.init
    cfg_path = $CONFIG_FILE_PATH

    if !File.exist?(cfg_path)
      puts "Config file not found.\n\n"
      File.write(cfg_path, JSON.pretty_generate(@@config_template))
      puts "Created #{cfg_path} in current directory."
      puts "Please fill out the following fields:"
      @@required_config_fields.each { |field| puts "- #{field.to_s}"}
      puts; exit
    end

    cfg = JSON.load_file(cfg_path)

    missing_fields = []
    req_fields = @@required_config_fields.map(&:to_s)
    cfg.each do |field, value|
      next unless req_fields.include? field
      if value.respond_to? :empty?
        missing_fields << field if value.empty?
      elsif value == nil
        missing_fields << field
      end
    end

    if !missing_fields.empty?
      puts "Please fill out the following required fields in #{cfg_path}:"
      missing_fields.each { |field| puts "- #{field.to_s}"}
      puts; exit
    end

    $clean_rom = Nitro::Rom.new(cfg['clean_rom'])

    Unarm.load_symbols9(cfg['symbols9']) unless cfg['symbols9'].empty?
    Unarm.load_symbols7(cfg['symbols7']) unless cfg['symbols7'].empty?

  end

  def self.main
    puts 'Main func!'
  end

	def self.run(args)

    init

    puts "Game title: #{$clean_rom.header.game_title}"
    puts "Game code: #{$clean_rom.header.game_code}"
    puts "Maker code: #{$clean_rom.header.maker_code}"
    puts "Size: #{($clean_rom.size / 1024.0 / 1024.0).round(2)} MB"
    puts "Overlay count: #{$clean_rom.overlay_count}\n"

    main
	end

end
