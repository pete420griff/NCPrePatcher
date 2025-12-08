require_relative 'nitro/nitro.rb'
require_relative 'unarm/unarm.rb'
require_relative 'ncpp/interpreter.rb'

require 'json'
require 'optparse'
require 'fileutils'
require 'pathname'

module NCPP

  # TODO: MUST move away from globals
  $clean_rom = nil
  $target_rom = nil

  alias $rom $clean_rom # In most cases the clean rom will be desired

  $config = nil

  NCP_CONFIG_FILE_PATH   = 'ncpatcher.json'
  CONFIG_FILE_PATH       = 'ncpp_config.json'
  NCPP_DEFS_FILENAME     = 'ncpp_defs'
  NCPP_GLB_DEFS_FILENAME = 'ncpp_global'

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
      ncp_cfg['pre-build']&.delete('ncpp.bat')
    else
      ncp_cfg['pre-build'] |= [(/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil ? 'ncpp.bat' : 'ncpp']
    end

    gen_path = ($config || CONFIG_TEMPLATE)[:gen_path]
    prefix   = "#{gen_path}/"

    [arm9_cfg, arm7_cfg].compact.each do |cfg|

      [['source', File.join(gen_path, 'source')], ['source7', File.join(gen_path, 'source7')]].each do |name, path|
        entry = cfg['includes'].find { it[0] == (revert ? path : name) }
        entry[0] = (revert ? name : path) if entry
      end

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
    plural = missing.length > 1
    puts "Please fill #{plural ? 'out' : 'in'} the following field#{plural ? 's' : ''} in #{cfg_path.bold_red}:"
    missing.each {|field| puts "  * ".purple + field.to_s}
    exit
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
      puts "Created #{cfg_path} in current directory.".cyan if verbose

      missing = get_missing_config_reqs(cfg)
      list_missing_config_fields(missing, cfg_path) unless missing.empty?

    else
      cfg = JSON.load_file(cfg_path)
      missing = get_missing_config_reqs(cfg)
      list_missing_config_fields(missing, cfg_path) unless missing.empty?
    end

    $config = cfg
    $clean_rom = Nitro::Rom.new(cfg['clean_rom'].gsub(/\$\{env:([^}]+)\}/) { ENV[$1] })
    $target_rom = Nitro::Rom.new(cfg['target_rom'].gsub(/\$\{env:([^}]+)\}/) { ENV[$1]}) unless cfg['target_rom'].empty?

    Unarm.load_symbols9(cfg['symbols9'].gsub(/\$\{env:([^}]+)\}/) { ENV[$1] }) unless cfg['symbols9'].empty?
    Unarm.load_symbols7(cfg['symbols7'].gsub(/\$\{env:([^}]+)\}/) { ENV[$1] }) unless cfg['symbols7'].empty?
  end

  def self.uninstall(cfg_path = CONFIG_FILE_PATH)
    ncp_cfg = JSON.load_file(NCP_CONFIG_FILE_PATH)

    arm9_cfg = ncp_cfg['arm9'].empty? ? nil : JSON.load_file(ncp_cfg['arm9']['target'])
    arm7_cfg = ncp_cfg['arm7'].empty? ? nil : JSON.load_file(ncp_cfg['arm7']['target'])

    update_ncp_configs(ncp_cfg, arm9_cfg, arm7_cfg, revert: true)

    return if !File.exist?(cfg_path)

    cfg = JSON.load_file(cfg_path)
    FileUtils.rm_rf(cfg['gen_path']) unless cfg['gen_path'].empty?
    File.delete(cfg_path)
  end

  def self.show_rom_info(rom)
    puts "Game title: #{rom.header.game_title}\n"              \
         "Game code: #{rom.header.game_code}\n"                \
         "Maker code: #{rom.header.maker_code}\n"              \
         "Size: #{(rom.size / 1024.0 / 1024.0).round(2)} MB\n" \
         "Overlay count: #{rom.overlay_count}"
    puts "Arm9 symbol count: #{Unarm.symbols9.count}" unless Unarm.symbols9.nil?
    puts "Arm7 symbol count: #{Unarm.symbols7.count}" unless Unarm.symbols7.nil?
    puts
  end

  # update timestamp cache entry and returns whether it has been modified
  def self.update_ts_cache_entry(ts_cache, entry_file)
    last_modified = File.mtime(entry_file).to_s
    modified = !ts_cache[entry_file].eql?(last_modified)
    ts_cache[entry_file] = last_modified
    modified
  end

  # evaluates the given rb file as a module and returns: { commands: COMMANDS, variables: VARIABLES }
  def self.eval_rb_defs(file_path)
    mod = Module.new
    mod.module_eval(File.read(file_path), file_path)
    {
      commands:  mod.const_defined?(:COMMANDS) ? mod.const_get(:COMMANDS) : {},
      variables: mod.const_defined?(:VARIABLES) ? mod.const_get(:VARIABLES) : {}
    }
  end

  # evaluates the given ncpp file and returns: { commands: COMMANDS, variables: VARIABLES }
  def self.eval_ncpp_defs(file_path, extra_cmds, extra_vars, safe)
    interpreter = NCPPFileInterpreter.new($config['command_prefix'], extra_cmds, extra_vars, safe: safe)
    interpreter.run(file_path)
    { commands: interpreter.get_new_commands, variables: interpreter.get_new_variables }
  end

  def self.run(args)
    ncpp_filename   = nil
    config_filename = nil
    interactive     = false
    ncpp_script     = false
    quiet           = false
    debug           = false
    show_rom_info   = false
    safe_mode       = false
    puritan_mode    = false
    no_cache        = false
    no_cache_pass   = false
    clear_gen       = false

    OptionParser.new do |opts|
      opts.on('--run FILE', 'Specify an NCPP script file to run') do |f|
        ncpp_filename = f
        ncpp_script = true
      end

      opts.on('--config FILE', 'Specify a config file (defaults to ncpp_config.json)') do |f|
        config_filename = f
      end

      opts.on('--interactive', '--repl', 'Run the Read-Eval-Print Loop interpreter') do
        interactive = true
      end

      opts.on('-q', '--quiet', '--sybau', 'Don\'t print parsing info') do
        quiet = true
      end

      opts.on('-d', '--debug', 'Enable debug info printing') do
        debug = true
      end

      opts.on('--safe', 'Run interpreter in safe mode to disable the execution of inline Ruby code') do
        safe_mode = true
      end

      opts.on('--puritanism', 'Run interpreter in puritan mode to disable the execution of impure expressions') do
        puritan_mode = true
      end

      opts.on('--no-cache', 'Disable interpreter runtime command caching') do
        no_cache = true
        no_cache_pass = true
      end

      opts.on('--no-cache-pass', 'Disable the passing of command cache between preprocessor interpreter instances') do
        no_cache_pass = true
      end

      opts.on('--clear-gen', 'Force all preprocessed files in gen folder to be regenerated') do
        clear_gen = true
      end

      opts.on('--show-rom-info', 'Show ROM info on startup') do
        show_rom_info = true
      end

      opts.on('--remove', 'Removes NCPrePatcher from your project') do
        uninstall
        exit
      end

      opts.on('-v', '--version', 'Show NCPrePatcher version') do
        puts VERSION
        exit
      end

      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit
      end
    end.parse!(args)

    ncp_project = File.exist? NCP_CONFIG_FILE_PATH

    if !ncp_project && !interactive && !ncpp_script
      puts "In preprocessor mode, NCPrePatcher must be run in a directory with an #{NCP_CONFIG_FILE_PATH.bold_red} "\
           "file."
      exit(1)
    end

    if config_filename
      init(config_filename)
    elsif ncp_project
      init
    end

    show_rom_info($rom) if show_rom_info && !$rom.nil?

    if ncpp_script
      interpreter = NCPPFileInterpreter.new($config.nil? ? COMMAND_PREFIX : $config['command_prefix'], safe: safe_mode, 
                                            no_cache: no_cache)
      exit_code = interpreter.run(ncpp_filename, debug: debug)
      exit(exit_code)
    end

    if interactive
      REPL.new(safe: safe_mode, puritan: puritan_mode, no_cache: no_cache).run(debug: debug)
      exit
    end

    ncp_cfg = JSON.load_file(NCP_CONFIG_FILE_PATH)
    root_dir = Pathname.new(File.dirname(NCP_CONFIG_FILE_PATH))
    code_root_dir = Pathname.new(File.dirname(ncp_cfg['arm9']['target']))

    Dir.chdir(code_root_dir.relative_path_from(root_dir))

    timestamp_cache_path = File.join($config['gen_path'], 'timestamp_cache.json')
    cache_exists = File.exist?(timestamp_cache_path)

    if clear_gen && cache_exists
      File.delete(timestamp_cache_path)
      cache_exists = false
    end

    timestamp_cache = cache_exists ? JSON.load_file(timestamp_cache_path) : {}

    if timestamp_cache['NCPP_VERSION'] != VERSION
      timestamp_cache = {}
    else
      timestamp_cache.delete('NCPP_VERSION')
    end

    exts = $config['source_file_types'].join(',')
  
    success           = true
    parsed_file_count = 0
    lines_parsed      = 0
    start_time        = Time.now

    $config['sources'].each do |src|
      extra_commands  = {}
      extra_variables = {}
      command_cache = {}

      defs_modified = false

      unless puritan_mode # read ncpp_global/defs files

        rb_def_files = [
          File.join(src.sub(/^\/|\/$/, '').split('/').first, NCPP_GLB_DEFS_FILENAME+'.rb'),
          File.join(src.sub('*', ''), NCPP_DEFS_FILENAME+'.rb'),
        ]

        if !safe_mode
          rb_def_files.each do |file|
            next unless File.exist?(file)
            defs_modified = update_ts_cache_entry(timestamp_cache, file)
            defs = eval_rb_defs(file)
            extra_commands.merge!(defs[:commands])
            extra_variables.merge!(defs[:variables])
          end
        else
          rb_def_files.each do |file|
            next unless File.exist?(file)
            Utils.print_warning "'#{file}' is ignored in safe mode"
          end
        end

        ncpp_def_files = rb_def_files.map { "#{it[..-4]}.ncpp" }
        ncpp_def_files.each do |file|
          next unless File.exist?(file)
          defs_modified = update_ts_cache_entry(timestamp_cache, file)
          defs = eval_ncpp_defs(file, extra_commands, extra_variables, safe_mode)
          extra_commands.merge!(defs[:commands])
          extra_variables.merge!(defs[:variables])
        end

      end

      if File.file?(src)
        files = [src]
      else
        if src.end_with?('/*')
          base = src[0...-2] # drop trailing "/*"
          pattern = File.join(base, '**', "*.{#{exts}}") # recursive directory search
        else
          base = src
          pattern = File.join(base, "*.{#{exts}}")
        end
        files = Dir.glob(pattern)
      end

      timestamp_cache.delete_if do |file, _mtime|
        if !File.exist?(file)
          File.delete(File.join($config['gen_path'], file))
          true
        else
          false
        end
      end

      files.delete_if do |file|
        last_modified = File.mtime(file).to_s
        modified = !timestamp_cache[file]&.eql?(last_modified)
        timestamp_cache[file] = last_modified
        if file.end_with?('.s')
          if modified || modified.nil?
            dest = File.join($config['gen_path'], file)
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp(file, dest)
          end
          true
        elsif !modified && !defs_modified
          true
        else
          false
        end
      end

      parsed_file_count += files.count

      files.each do |file|
        interpreter = CFileInterpreter.new(
          file, $config['gen_path'], $config['command_prefix'], extra_commands, extra_variables,
          safe: safe_mode, puritan: puritan_mode, no_cache: no_cache, cmd_cache: no_cache_pass ? {} : command_cache
        )
        interpreter.run(verbose: !quiet, debug: debug)
        lines_parsed += interpreter.lines_parsed

        command_cache.merge!(interpreter.get_cacheable_cache) unless no_cache_pass

        unless interpreter.incomplete_files.empty?
          timestamp_cache.delete(file)
          success = false
        end
      end

      # interpreter = CFileInterpreter.new(
      #   files, $config['gen_path'], $config['command_prefix'], extra_commands, extra_variables,
      #   safe: safe_mode, puritan: puritan_mode
      # )
      # interpreter.run(verbose: !quiet)
      # lines_parsed += interpreter.lines_parsed

      # unless interpreter.incomplete_files.empty?
      #   interpreter.incomplete_files.each do |file|
      #     timestamp_cache.delete(file)
      #     success = false
      #   end
      # end

    end

    timestamp_cache['NCPP_VERSION'] = VERSION

    FileUtils.mkdir_p(File.dirname(timestamp_cache_path))
    File.write(timestamp_cache_path, JSON.generate(timestamp_cache))

    # FileUtils.mkdir_p(File.dirname(cmd_cache_path))
    # File.write(cmd_cache_path, JSON.generate(command_cache))

    unless quiet
      if lines_parsed > 0
        msg = "\nParsed #{lines_parsed} line#{'s' if lines_parsed != 1} across " \
              "#{parsed_file_count} file#{'s' if parsed_file_count != 1}."
        puts (success ? msg.green : msg.yellow)
        if success
          puts "Took ".green + String(Time.now - start_time).underline_green + " seconds.".green
        else
          puts "Took ".yellow + String(Time.now - start_time).underline_yellow + " seconds.".yellow
        end
      else
        puts "Nothing to parse.".green
      end
    end

    puts
    ARGV.clear

    unless success
      puts 'NCPrePatcher execution was not successful.'.bold_red
      exit(1)
    end

  end

end
