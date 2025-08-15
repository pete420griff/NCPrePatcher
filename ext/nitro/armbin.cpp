#include "armbin.hpp"

#include <iostream>
#include <fstream>
#include <string>
#include <algorithm>
#include <sstream>
#include <cstring>

#include "blz.hpp"

namespace fs = std::filesystem;

namespace nitro {

bool ArmBin::load(const fs::path& path, u32 entryAddr, u32 ramAddr, u32 autoLoadHookOffset, bool isArm9) {

	m_ramAddr = ramAddr;
	m_entryAddr = entryAddr;
	m_autoLoadHookOffset = autoLoadHookOffset;
	m_isArm9 = isArm9;

	// READ FILE ================================

	if (!fs::exists(path)) {
		// LOG_ERROR("Could not find file.");
		return false;
	}

	uintmax_t fileSize = fs::file_size(path);
	if (fileSize < 4) {
		// LOG_ERROR("Invalid ARM binary.");
		return false;
	}

	std::ifstream file(path, std::ios::binary);
	if (!file.is_open()) {
		// LOG_ERROR("Could not read file.");
		return false;
	}

	m_bytes.resize(fileSize);
	file.read(reinterpret_cast<char*>(m_bytes.data()), std::streamsize(fileSize));
	file.close();

	u8* bytesData = m_bytes.data();

	// FIND MODULE PARAMS ================================

	m_moduleParamsOffset = *reinterpret_cast<u32*>(&bytesData[autoLoadHookOffset - m_ramAddr - 4]) - m_ramAddr;

	std::cout << "Found ModuleParams at: 0x" << std::uppercase << std::hex << m_moduleParamsOffset << std::endl;

	ModuleParams* moduleParams = getModuleParams();

	// DECOMPRESS ================================

	if (moduleParams->compStaticEnd) {
		std::cout << "Decompressing..." << std::endl;

		u32 decompSize = static_cast<u32>(fileSize) + *reinterpret_cast<u32*>(&bytesData[moduleParams->compStaticEnd - m_ramAddr - 4]);

		m_bytes.resize(decompSize);
		bytesData = m_bytes.data();
		moduleParams = getModuleParams();

		try {
			blz::uncompressInplace(&bytesData[moduleParams->compStaticEnd - m_ramAddr]);
		}
		catch (const std::exception& e) {
			std::ostringstream oss;
			oss << "Failed to decompress the binary: " << e.what();
			return false;
		}

		std::cout << "  Old size: 0x" << fileSize << std::endl;
		std::cout << "  New size: 0x" << decompSize << std::endl;

		moduleParams->compStaticEnd = 0;
	}

	refreshAutoloadData();

	return true;
}

bool ArmBin::load(const u8* romPtr, const ARMBinaryInfo& info, u32 autoLoadHookOffset, bool isArm9) {

	if (romPtr == nullptr || info.size < 4)
		return false;

	m_ramAddr = info.ramAddress;
	m_entryAddr = info.entryAddress;
	m_autoLoadHookOffset = autoLoadHookOffset;
	m_isArm9 = isArm9;

	romPtr += info.romOffset;

	m_bytes.assign(romPtr, romPtr + info.size);

	u8* bytesData = m_bytes.data();

	m_moduleParamsOffset = *reinterpret_cast<u32*>(&bytesData[autoLoadHookOffset - m_ramAddr - 4]) - m_ramAddr;

	ModuleParams* moduleParams = getModuleParams();

	if (moduleParams->compStaticEnd) {
		std::cout << "Decompressing..." << std::endl;

		u32 decompSize = static_cast<u32>(info.size) + *reinterpret_cast<u32*>(&bytesData[moduleParams->compStaticEnd - m_ramAddr - 4]);

		m_bytes.resize(decompSize);
		bytesData = m_bytes.data();
		moduleParams = getModuleParams();

		try {
			blz::uncompressInplace(&bytesData[moduleParams->compStaticEnd - m_ramAddr]);
		}
		catch (const std::exception& e) {
			std::ostringstream oss;
			oss << "Failed to decompress the binary: " << e.what();
			return false;
		}

		std::cout << "  Old size: 0x" << info.size << std::endl;
		std::cout << "  New size: 0x" << decompSize << std::endl;

		moduleParams->compStaticEnd = 0;
	}

	refreshAutoloadData();

	return true;
}

bool ArmBin::readBytes(u32 address, void* out, u32 size) const {

	auto failDueToSizeExceed = [&]() {
		std::ostringstream oss;
		oss << "Failed to read from arm, reading " << size << " byte(s) from address 0x" <<
			std::uppercase << std::hex << address << std::nouppercase << " exceeds range.";
		return false;
	};

	u32 autoloadStart = getModuleParams()->autoloadStart;
	if (address >= m_ramAddr && address < autoloadStart) {
		if (address + size > autoloadStart)
			failDueToSizeExceed();
		std::memcpy(out, &m_bytes[address - m_ramAddr], size);
		return true;
	}

	for (const AutoLoadEntry& autoload : m_autoloadList) {
		u32 autoloadEnd = autoload.address + autoload.size;
		if (address >= autoload.address && address < autoloadEnd) {
			if (address + size > autoloadEnd)
				failDueToSizeExceed();
			std::memcpy(out, &m_bytes[autoload.dataOffset + (address - autoload.address)], size);
			return true;
		}
	}

	std::ostringstream oss;
	oss << "Address 0x" << std::uppercase << std::hex << address << std::nouppercase << " out of range.";
	return false;
}

bool ArmBin::writeBytes(u32 address, const void* data, u32 size) {

	auto failDueToSizeExceed = [&]() {
		std::ostringstream oss;
		oss << "Failed to write to arm, writing " << size << " byte(s) to address 0x" <<
			std::uppercase << std::hex << address << std::nouppercase << " exceeds range.";
		return false;
	};

	u32 autoloadStart = getModuleParams()->autoloadStart;
	if (address >= m_ramAddr && address < autoloadStart) {
		if (address + size > autoloadStart)
			failDueToSizeExceed();
		std::memcpy(&m_bytes[address - m_ramAddr], data, size);
		return true;
	}

	for (AutoLoadEntry& autoload : m_autoloadList) {
		u32 autoloadEnd = autoload.address + autoload.size;
		if (address >= autoload.address && address < autoloadEnd) {
			if (address + size > autoloadEnd)
				failDueToSizeExceed();
			std::memcpy(&m_bytes[autoload.dataOffset + (address - autoload.address)], data, size);
			return true;
		}
	}

	std::ostringstream oss;
	oss << "Address 0x" << std::uppercase << std::hex << address << std::nouppercase << " out of range.";
	return false;
}

void ArmBin::refreshAutoloadData() {

	u8* bytesData = m_bytes.data();
	ModuleParams* moduleParams = getModuleParams();

	m_autoloadList.clear();

	u32* alIter = reinterpret_cast<u32*>(&bytesData[moduleParams->autoloadListStart - m_ramAddr]);
	u32* alEnd = reinterpret_cast<u32*>(&bytesData[moduleParams->autoloadListEnd - m_ramAddr]);
	u32 alDataIter = moduleParams->autoloadStart - m_ramAddr;

	while (alIter < alEnd) {
		u32 entryInfo[3];
		std::memcpy(&entryInfo, alIter, 12);

		AutoLoadEntry entry;
		entry.address = entryInfo[0];
		entry.size = entryInfo[1];
		entry.bssSize = entryInfo[2];
		entry.dataOffset = alDataIter;

		m_autoloadList.push_back(entry);

		alIter += 3;
		alDataIter += entry.size;
	}
}


ArmBin::ModuleParams* ArmBin::getModuleParams() {
	return reinterpret_cast<ModuleParams*>(&((m_bytes.data())[m_moduleParamsOffset]));
}

const ArmBin::ModuleParams* ArmBin::getModuleParams() const {
	return reinterpret_cast<const ModuleParams*>(&((m_bytes.data())[m_moduleParamsOffset]));
}

constexpr bool ArmBin::sanityCheckAddress(u32 addr) const {
	return addr >= m_ramAddr && addr < (m_ramAddr + 0x00400000);
}

} // nitro
