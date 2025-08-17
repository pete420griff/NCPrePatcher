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
	return reinterpret_cast<const Banner&>(m_bytes.data()[getHeader().bannerOffset]);
}

const NitroRom::FATEntry& NitroRom::getFATEntry(u32 index) const {
	return reinterpret_cast<const FATEntry*>(&m_bytes.data()[getHeader().fat.romOffset])[index];
}

const void* NitroRom::getFile(u32 id) const {
	return static_cast<const void*>(&m_bytes.data()[getFATEntry(id).start]);
}

u32 NitroRom::getFileSize(u32 id) const {
	return getFATEntry(id).end - getFATEntry(id).start;
}

const OvtEntry& NitroRom::getArm9OvtEntry(u32 index) const {
	return reinterpret_cast<const OvtEntry*>(&m_bytes.data()[getHeader().arm9OvT.romOffset])[index];
}

const OvtEntry& NitroRom::getArm7OvtEntry(u32 index) const {
	return reinterpret_cast<const OvtEntry*>(&m_bytes.data()[getHeader().arm7OvT.romOffset])[index];
}

u32 NitroRom::getArm9OverlayCount() const {
	return getHeader().arm9OvT.size / sizeof(OvtEntry);
}

u32 NitroRom::getArm7OverlayCount() const {
	return getHeader().arm7OvT.size / sizeof(OvtEntry);
}

} // nitro
