#include "overlaybin.hpp"

#include "core/log.hpp"

#include <iostream>
#include <fstream>
#include <cstring>
#include <sstream>

#include "blz.hpp"

namespace fs = std::filesystem;

namespace nitro {

OverlayBin::OverlayBin() = default;

bool OverlayBin::load(const fs::path& path, u32 ramAddress, bool compressed, int id) {

	m_ramAddress = ramAddress;
	m_id = id;
	m_isDirty = false;

	if (!fs::exists(path)) {
		LOG_ERROR("Could not find file.");
		return false;
	}

	uintmax_t fileSize = fs::file_size(path);

	std::ifstream file(path, std::ios::binary);
	if (!file.is_open()) {
		LOG_ERROR("File already open");
		return false;
	}

	if (fileSize == 0)
		return false;

	m_bytes.resize(fileSize);
	file.read(reinterpret_cast<char*>(m_bytes.data()), std::streamsize(fileSize));
	file.close();

	if (compressed)
		blz::uncompressInplace(m_bytes);

	return true;
}

bool OverlayBin::readBytes(u32 address, void* out, u32 size) const {

	u32 binAddress = address - m_ramAddress;
	if (binAddress + size > m_bytes.size()) {
		std::ostringstream oss;
		oss << "Failed to read from overlay " << m_id << ", reading " << size << " byte(s) from address 0x" <<
			std::uppercase << std::hex << address << std::nouppercase << " exceeds range.";
		return false;
	}
	std::memcpy(out, &m_bytes[binAddress], size);
	return true;
}

bool OverlayBin::writeBytes(u32 address, const void* data, u32 size) {

	u32 binAddress = address - m_ramAddress;
	if (binAddress + size > m_bytes.size())
	{
		std::ostringstream oss;
		oss << "Failed to write to overlay " << m_id << ", writing " << size << " byte(s) to address 0x" <<
			std::uppercase << std::hex << address << std::nouppercase << " exceeds range.";
		return false;
	}
	std::memcpy(&m_bytes[binAddress], data, size);
	m_isDirty = true;
	return true;
}

} // nitro
