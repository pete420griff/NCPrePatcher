require_relative 'nitro.rb'
require_relative 'unarm.rb'
require_relative 'utils.rb'

require 'json'

module NCPP

  $CONFIG_FILE_PATH = 'ncpp_config.json'
  $clean_rom = nil
  $target_rom = nil

  alias $rom $clean_rom # I think in most cases the clean rom will be needed
  alias $virgin_rom $clean_rom # for good measure
  alias $unmolested_rom $clean_rom

  @@config_template = {
    clean_rom: '', target_rom: '',
    sources: [], # each entry: [string path, bool search_recursive]
    source_file_types: ['cpp','hpp','c','h'],
    symbols9: '', symbols7: '',
    output_path: 'ncpp_gen' # gets auto-created
  }

  @@required_config_fields = [:clean_rom, :sources]

  def self.glean_from_ncp_config(cfg)
    return cfg if !File.exist?('ncpatcher.json')
    ncp_cfg = JSON.load_file('ncpatcher.json')

    %w[9 7].each do |cpu|
      if !ncp_cfg['arm'+cpu].empty?
        arm_cfg = JSON.load_file(ncp_cfg['arm'+cpu]['target'])

        cfg[('symbols'+cpu).to_sym] = arm_cfg['symbols']

        arm_cfg['regions'].each do |region|
          cfg[:sources].concat(region['sources'])
        end
      end
    end

    cfg
  end

  def self.get_missing_config_reqs(cfg)
    missing_fields = []
    req_fields = @@required_config_fields#.map(&:to_s)

    cfg.each do |field, value|
      next unless req_fields.include? field
      if value.respond_to? :empty?
        missing_fields << field if value.empty?
      elsif !value
        missing_fields << field
      end
    end

    missing_fields
  end

  def self.init
    cfg_path = $CONFIG_FILE_PATH

    if !File.exist?(cfg_path)
      puts "Config file not found.\n\n"
      cfg = glean_from_ncp_config(@@config_template)
      File.write(cfg_path, JSON.pretty_generate(cfg))
      puts "Created #{cfg_path} in current directory."
      missing = get_missing_config_reqs(cfg)
      if !missing.empty?
        puts "Please fill out the following fields:"
        missing.each { |field| puts "- #{field.to_s}"}
        puts; exit
      end

    else
      cfg = JSON.load_file(cfg_path)
      missing = get_missing_config_reqs(cfg)

      if !missing.empty?
        puts "Please fill out the following required fields in #{cfg_path}:"
        missing.each { |field| puts "- #{field.to_s}"}
        puts; exit
      end
    end

    $config = cfg
    $clean_rom = Nitro::Rom.new(cfg['clean_rom'])
    $target_rom = Nitro::Rom.new(cfg['target_rom']) unless cfg['target_rom'].empty?

    Unarm.load_symbols9(cfg['symbols9']) unless cfg['symbols9'].empty?
    Unarm.load_symbols7(cfg['symbols7']) unless cfg['symbols7'].empty?

  end


  def self.run(args)

    init

    puts "Game title: #{$clean_rom.header.game_title}"
    puts "Game code: #{$clean_rom.header.game_code}"
    puts "Maker code: #{$clean_rom.header.maker_code}"
    puts "Size: #{($clean_rom.size / 1024.0 / 1024.0).round(2)} MB"
    puts "Overlay count: #{$clean_rom.overlay_count}\n\n"

    $config['sources'].each do |src, recursive|
      files = Dir["#{src}/*#{recursive ? '*/*' : ''}.{#{$config['source_file_types'].join(',')}}"]
      puts files
    end

  end

end
