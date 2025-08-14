#include "headerbin.hpp"

#include <iostream>
#include <fstream>
#include <cstring>

namespace fs = std::filesystem;

namespace nitro {

HeaderBin::HeaderBin() = default;

bool HeaderBin::load(const fs::path& path) {

	if (!fs::exists(path)) {
		// LOG_ERROR("Could not find file.");
		return false;
	}

	std::ifstream headerFile(path, std::ios::binary);
	if (!headerFile.is_open()) {
		// LOG_ERROR("Could not read file.");
		return false;
	}

	uintmax_t headerSize = fs::file_size(path);
	if (headerSize < 512) {

		headerFile.close();

		// LOG_ERROR("Invalid ROM header file: {}", path.string());
		// LOG_ERROR("Expected a minimum of 512 bytes, got {} bytes.", headerSize);
		return false;
	}

	// TODO: More safety on HeaderBin loading
	headerFile.read(reinterpret_cast<char*>(this), sizeof(HeaderBin));
	headerFile.close();

	return true;
}

} // nitro
