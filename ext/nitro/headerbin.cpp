#include "headerbin.hpp"

#include <iostream>
#include <fstream>
#include <cstring>

namespace fs = std::filesystem;

namespace nitro {

bool HeaderBin::load(const fs::path& path) {

	if (!fs::exists(path))
		return false;

	std::ifstream headerFile(path, std::ios::binary);
	if (!headerFile.is_open())
		return false;

	uintmax_t headerSize = fs::file_size(path);
	if (headerSize < 512) {
		headerFile.close();
		return false;
	}

	// TODO: More safety on HeaderBin loading
	headerFile.read(reinterpret_cast<char*>(this), sizeof(HeaderBin));
	headerFile.close();

	return true;
}

} // nitro
