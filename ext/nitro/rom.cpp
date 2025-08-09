#include "rom.hpp"

#include <fstream>
#include <sstream>

namespace fs = std::filesystem;

namespace nitro {

LoadResult NitroROM::load(const fs::path& path) {

    if (!fs::exists(path) || !fs::is_regular_file(path))
		return LoadResult::InvalidPath;

	std::ifstream romFile(path, std::ios::binary);
	if (!romFile.is_open())
		return LoadResult::Failure;

	uintmax_t romSize = fs::file_size(path);

	if (romSize >= (1 << 30)) // 1 GiB = 2^30 bytes
		return LoadResult::SizeExceed;

	// TODO: More safety to ensure this is a valid nds rom?
	m_bytes.resize(romSize);
	romFile.read(reinterpret_cast<char*>(m_bytes.data()), romSize);

	const auto& header = getHeader();

    // TODO: get this outta here
	// char targetGameCode[4] = {'A','2','D','E'};
	// if (!std::ranges::equal(header.gameCode, targetGameCode)) {
    //     LOG_ERROR("Not a valid NSMB DS USA ROM!");
    //     return false;
    // }

    m_loaded = true;

    return LoadResult::Success;
}

} // nitro
