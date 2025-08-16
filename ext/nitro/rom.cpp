#include "rom.hpp"

#include <fstream>
#include <sstream>

namespace fs = std::filesystem;

namespace nitro {

NitroRom::LoadResult NitroRom::load(const fs::path& path) {

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

    m_loaded = true;

    return LoadResult::Success;
}

const HeaderBin& NitroRom::getHeader() const {
	return reinterpret_cast<const HeaderBin&>(*m_bytes.data());
}

const NitroRom::Banner& NitroRom::getBanner() const {
	return reinterpret_cast<const NitroRom::Banner&>(m_bytes.data()[getHeader().bannerOffset]);
}

const NitroRom::FAT& NitroRom::getFAT() const {
	return reinterpret_cast<const NitroRom::FAT&>(m_bytes.data()[getHeader().fat.romOffset]);
}

// const NitroRom::FNTEntry*& NitroRom::getFNT() const {
// 	return reinterpret_cast<const NitroRom::FNTEntry*&>(m_bytes.data()[getHeader().fnt.romOffset]);
// }

} // nitro
