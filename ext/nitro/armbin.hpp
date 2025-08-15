#pragma once

#include <sstream>
#include <filesystem>
#include <vector>
#include <exception>

#include "icodebin.hpp"
#include "types.hpp"

namespace nitro {

struct ARMBinaryInfo {
	u32 romOffset;
	u32 entryAddress;
	u32 ramAddress;
	u32 size;
};

class ArmBin : public ICodeBin {
public:
	struct ModuleParams {
		u32 autoloadListStart;
		u32 autoloadListEnd;
		u32 autoloadStart;
		u32 staticBssStart;
		u32 staticBssEnd;
		u32 compStaticEnd; //compressedStaticEnd
		u32 sdkVersionID;
		u32 nitroCodeBE;
		u32 nitroCodeLE;
	};

	struct AutoLoadEntry {
		u32 address;
		u32 size;
		u32 bssSize;
		u32 dataOffset;
	};

	ArmBin() = default;

	bool load(const std::filesystem::path& path, u32 entryAddr, u32 ramAddr, u32 autoLoadHookOffset, bool isArm9);
	bool load(const u8* romPtr, const ARMBinaryInfo& info, u32 autoLoadHookOffset, bool isArm9);

	bool readBytes(u32 address, void* out, u32 size) const override;
	bool writeBytes(u32 address, const void* data, u32 size) override;

	void refreshAutoloadData();

	[[nodiscard]] ModuleParams* getModuleParams();
	[[nodiscard]] const ModuleParams* getModuleParams() const;

	[[nodiscard]] constexpr bool sanityCheckAddress(u32 addr) const;

	[[nodiscard]] constexpr u32 getRamAddress() const { return m_ramAddr; }

	[[nodiscard]] constexpr std::vector<u8>& data() { return m_bytes; }
	[[nodiscard]] constexpr const std::vector<u8>& data() const { return m_bytes; }

	[[nodiscard]] constexpr std::vector<AutoLoadEntry>& getAutoloadList() { return m_autoloadList; }
	[[nodiscard]] constexpr const std::vector<AutoLoadEntry>& getAutoloadList() const { return m_autoloadList; }

private:
	u32 m_ramAddr; //The offset of this binary in memory
	u32 m_entryAddr; //The address of the entry point
	u32 m_autoLoadHookOffset;
	u32 m_moduleParamsOffset;
	u32 m_isArm9;

	std::vector<u8> m_bytes;
	std::vector<AutoLoadEntry> m_autoloadList;

};

} // nitro
