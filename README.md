# NCPrePatcher

A preprocessor for [NCPatcher](https://github.com/TheGameratorT/NCPatcher) with access to your NDS ROM and a disassembler.

## Installation

#### Requirements

- [Ruby (≥ 3.4 recommended)](https://www.ruby-lang.org/en/news/2024/12/25/ruby-3-4-0-released/)

Go to Releases, download the .gem file for your platform, then open up the command line where it was downloaded to and enter:
```console
gem install NCPrePatcher-[version]-[platform].gem
```

The `ncpp` command should now be available at your command line (a system reboot may be required).

## Usage

NCPrePatcher can be used as a Ruby library or as a preprocessor alongside NCPatcher.

For the former, simply `require` it as you would with any gem:
```ruby
require ncpp
```

For the latter, navigate to an existing project using NCPatcher (where an `ncpatcher.json` file is present), and run:
```console
ncpp
```

To view what else it can do, run:
```console
ncpp --help
```

## Credits

- Code from NCPatcher used by the **nitro** library
- [unarm](https://github.com/AetiasHax/unarm) used for disassembling
- [Ruby-FFI](https://github.com/ffi/ffi) used for binding the libraries above to Ruby
- [Parslet](https://github.com/kschiess/parslet) used for parsing the DSL