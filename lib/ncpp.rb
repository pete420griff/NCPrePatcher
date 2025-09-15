require_relative 'nitro/nitro.rb'
require_relative 'unarm/unarm.rb'
require_relative 'ncpp/interpreter.rb'

require 'json'
require 'optparse'
require 'fileutils'

module NCPP

  $clean_rom = nil
  $target_rom = nil

  alias $rom $clean_rom # In most cases the clean rom will be desired
  alias $virgin_rom $clean_rom # for good measure
  alias $unmolested_rom $clean_rom

  $config = nil

  CONFIG_FILE_PATH     = 'ncpp_config.json'
  NCP_CONFIG_FILE_PATH = 'ncpatcher.json'

  CONFIG_TEMPLATE = {
    clean_rom: '', target_rom: '',
    sources: [], source_file_types: %w[cpp hpp inl c h s],
    symbols9: '', symbols7: '',
    gen_path: 'ncpp-gen',
    command_prefix: 'ncpp_'
  }

  REQUIRED_CONFIG_FIELDS = [:clean_rom, :sources].freeze


  def self.glean_from_arm_config(cfg, arm_cfg, cpu: 9)
    cfg[('symbols'+cpu.to_s).to_sym] = arm_cfg['symbols']
    arm_cfg['regions'].each do |region|
      if region['sources'][0].is_a? Array
        cfg[:sources].concat(region['sources'].map {|src,glb| "#{src}#{glb ? '/*' : ''}" })
      else
        cfg[:sources].concat(region['sources'])
      end
    end
    cfg
  end

  def self.update_ncp_configs(ncp_cfg, arm9_cfg, arm7_cfg = nil, revert: false)
    if revert
      ncp_cfg['pre-build']&.delete('ncpp')
    else
      ncp_cfg['pre-build'] |= ['ncpp']
    end

    gen_path = ($config || CONFIG_TEMPLATE)[:gen_path]
    prefix   = "#{gen_path}/"

    [arm9_cfg, arm7_cfg].compact.each do |cfg|
      cfg['regions'].each do |region|
        region['sources'].map! do |src|
          if src.is_a?(Array)
            src[0] =
              if revert
                src[0].sub(/^#{Regexp.escape(prefix)}/, '')
              else
                File.join(gen_path, src[0].to_s)
              end
            src
          else
            if revert
              src.sub(/^#{Regexp.escape(prefix)}/, '')
            else
              File.join(gen_path, src.to_s)
            end
          end
        end
      end
    end

    File.write(NCP_CONFIG_FILE_PATH, JSON.pretty_generate(ncp_cfg))
    File.write(ncp_cfg['arm9']['target'], JSON.pretty_generate(arm9_cfg))
    File.write(ncp_cfg['arm7']['target'], JSON.pretty_generate(arm7_cfg)) if arm7_cfg
  end

  def self.get_missing_config_reqs(cfg)
    missing_fields = []

    cfg.each do |field, value|
      next unless REQUIRED_CONFIG_FIELDS.include? field.to_sym
      missing_fields << field if value.empty? || value.nil?
    end

    missing_fields
  end

  def self.list_missing_config_fields(missing, cfg_path)
    puts "Please fill out the following field#{missing.length > 1 ? 's' : ''} in #{cfg_path}:"
    missing.each {|field| puts "* #{field.to_s}"}
    puts; exit
  end

  def self.init(cfg_path = CONFIG_FILE_PATH, verbose: true)

    if !File.exist?(cfg_path)
      ncp_cfg = JSON.load_file(NCP_CONFIG_FILE_PATH)
      arm9_cfg = arm7_cfg = nil

      arm9_cfg = JSON.load_file(ncp_cfg['arm9']['target'])
      cfg = glean_from_arm_config(CONFIG_TEMPLATE, arm9_cfg, cpu: 9)

      if !ncp_cfg['arm7'].empty?
        arm7_cfg = JSON.load_file(ncp_cfg['arm7']['target'])
        cfg = glean_from_arm_config(cfg, arm7_cfg, cpu: 7)
      end

      update_ncp_configs(ncp_cfg,arm9_cfg,arm7_cfg)

      File.write(cfg_path, JSON.pretty_generate(cfg))
      puts "Created #{cfg_path} in current directory." if verbose

      missing = get_missing_config_reqs(cfg)
      list_missing_config_fields(missing, cfg_path) unless missing.empty?

    else
      cfg = JSON.load_file(cfg_path)
      missing = get_missing_config_reqs(cfg)
      list_missing_config_fields(missing, cfg_path) unless missing.empty?
    end

    $config = cfg
    $clean_rom = Nitro::Rom.new(cfg['clean_rom'])
    $target_rom = Nitro::Rom.new(cfg['target_rom']) unless cfg['target_rom'].empty?

    Unarm.load_symbols9(cfg['symbols9']) unless cfg['symbols9'].empty?
    Unarm.load_symbols7(cfg['symbols7']) unless cfg['symbols7'].empty?
  end

  def self.clean(cfg_path = CONFIG_FILE_PATH)
    if !File.exist?(cfg_path)
      puts 'Nothing to clean'
      return
    end
    cfg = JSON.load_file(cfg_path)
    FileUtils.rm_rf(cfg['gen_path']) unless cfg['gen_path'].empty?
    File.delete(cfg_path)

    ncp_cfg = JSON.load_file(NCP_CONFIG_FILE_PATH)

    arm9_cfg = ncp_cfg['arm9'].empty? ? nil : JSON.load_file(ncp_cfg['arm9']['target'])
    arm7_cfg = ncp_cfg['arm7'].empty? ? nil : JSON.load_file(ncp_cfg['arm7']['target'])

    update_ncp_configs(ncp_cfg, arm9_cfg, arm7_cfg, revert: true)
  end

  def self.show_rom_info(rom)
    puts "Game title: #{rom.header.game_title}"
    puts "Game code: #{rom.header.game_code}"
    puts "Maker code: #{rom.header.maker_code}"
    puts "Size: #{(rom.size / 1024.0 / 1024.0).round(2)} MB"
    puts "Overlay count: #{rom.overlay_count}"
    puts "Arm9 symbol count: #{Unarm.symbols9.count}" unless Unarm.symbols9.nil?
    puts "Arm7 symbol count: #{Unarm.symbols7.count}" unless Unarm.symbols7.nil?
    puts
  end

  def self.run(args)
    config_file = nil
    use_config  = true
    interactive = false
    quiet       = false

    OptionParser.new do |opts|
      opts.on('--config FILE', 'Specify a config file') do |f|
        config_file = f
      end

      opts.on('--no-config', 'Don\'t use a config file') do
        use_config = false
      end

      opts.on('--interactive', '--repl', 'Run in REPL mode') do
        interactive = true
      end

      opts.on('-q', '--quiet', '--sybau', 'Don\'t print info') do
        quiet = true
      end

      opts.on('--remove', '--clean', '--kys', 'Removes any trace of my existence from your project') do
        clean
        exit
      end

      opts.on('-v', '--version', 'Print NCPrePatcher version') do
        puts VERSION
        exit
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!(args)

    if config_file
      init(config_file)
    elsif use_config
      init
    end

    if interactive
      REPL.new.run
      exit
    end

    show_rom_info($rom) unless quiet || $rom.nil?

    timestamp_cache_path = File.join($config['gen_path'], 'timestamp_cache.json')
    if File.exist?(timestamp_cache_path)
      timestamp_cache = JSON.load_file(timestamp_cache_path)
    else
      timestamp_cache = {}
      # FileUtils.mkdir_p(File.dirname(timestamp_cache_path))
    end

    exts = $config['source_file_types'].join(',')

    $config['sources'].each do |src|
      if File.file?(src)
        files = [src]
      else
        if src.end_with?('/*')
          base = src[0...-2] # drop trailing "/*"
          pattern = File.join(base, '**', "*.{#{exts}}") # recursive
        else
          base = src
          pattern = File.join(base, "*.{#{exts}}")
        end
        files = Dir.glob(pattern)
      end

      files.delete_if do |file|
        last_modified = File.mtime(file).to_s
        not_modified = timestamp_cache[file]&.eql?(last_modified)
        timestamp_cache[file] = last_modified
        if file.end_with?('.s')
          if !not_modified && !not_modified.nil?
            dest = File.join($config['gen_path'], file)
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp(file, dest)
          end
          true
        elsif not_modified
          true
        else
          false
        end
      end

      CFileInterpreter.new(files, $config['gen_path']).run
    end

    FileUtils.mkdir_p(File.dirname(timestamp_cache_path))
    File.write(timestamp_cache_path, JSON.generate(timestamp_cache))
  
    puts
    ARGV.clear
  end

end
