# NCPrePatcher

A preprocessor for [NCPatcher](https://github.com/TheGameratorT/NCPatcher) with access to your NDS ROM and a disassembler.

## Installation

#### Requirements

- [Ruby (≥ 3.4 required)](https://www.ruby-lang.org/en/downloads/)

Go to Releases, download the .gem file for your platform, then open up the command line where it was downloaded to and enter:
```console
gem install NCPrePatcher-[version]-[platform].gem
```

The `ncpp` command should now be available at your command line (a system reboot may be required).

## Usage

NCPrePatcher can be used as a Ruby library or, as it was built for, as a preprocessor alongside NCPatcher.

For the former, simply `require` it as you would with any gem:
```ruby
require ncpp
```

For the latter, navigate to an existing project using NCPatcher (where an `ncpatcher.json` file is present), and run:
```console
ncpp
```
Follow the directions given, and it will be installed into your project. Subsequently, running `ncpp` manually will no longer be required; being added as a pre-build command in `ncpatcher.json`, it will run when NCPatcher does.

For examples of usage as a preprocessor, see [ncpp-demos](https://github.com/pete420griff/ncpp-demos).

To view what else NCPrePatcher can do, run:
```console
ncpp --help
```

## Building

> [!NOTE]
> This is an alternative to installing NCPrePatcher via the methods described in [the installation guide](#installation)

#### Requirements

- Ruby
- CMake and a modern C++ compiler
- Rust and Cargo

To build the required native libraries, go to /ext/ and run:
```console
ruby build.rb
```

Then go back to the base directory and run:
```console
gem build ncpp.gemspec
```

## Credits

- Code from NCPatcher used by the **nitro** library
- [unarm](https://github.com/AetiasHax/unarm) used for disassembling
- [Ruby-FFI](https://github.com/ffi/ffi) used for binding the above libraries to Ruby
- [Parslet](https://github.com/kschiess/parslet) used for parsing the DSL