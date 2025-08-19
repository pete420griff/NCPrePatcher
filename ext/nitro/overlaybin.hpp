#pragma once

#include <vector>
#include <filesystem>

#include "icodebin.hpp"

#define OVERLAY_FLAG_COMP 1
#define OVERLAY_FLAG_AUTH 2

namespace nitro {

struct OvtEntry {
	u32 overlayID;
	u32 ramAddress;
	u32 ramSize;
	u32 bssSize;
	u32 sinitStart;
	u32 sinitEnd;
	u32 fileID;
	u32 compressed : 24; // size of compressed "ramSize"
	u32 flag : 8;
};

class OverlayBin : public ICodeBin {
public:
	OverlayBin() = default;

	bool load(const std::filesystem::path& path, u32 ramAddress, bool compressed, s32 id);
	bool load(const u8* ovPtr, const OvtEntry& ovte);

	bool readBytes(u32 address, void* out, u32 size) const override;
	bool writeBytes(u32 address, const void* data, u32 size) override;

	u32 getSize() const override { return static_cast<u32>(m_bytes.size()); }
	u32 getStartAddress() const override { return m_ramAddress; }

	[[nodiscard]] constexpr std::vector<u8>& data()						{ return m_bytes; };
	[[nodiscard]] constexpr const std::vector<u8>& data() const			{ return m_bytes; };
	[[nodiscard]] constexpr std::vector<u8>& backupData()				{ return m_backupData; };
	[[nodiscard]] constexpr const std::vector<u8>& backupData() const	{ return m_backupData; };

	[[nodiscard]] constexpr bool getDirty() const { return m_isDirty; }
	constexpr void setDirty(bool isDirty) { m_isDirty = isDirty; }

	s32 getID() const { return m_id; }

private:
	std::vector<u8> m_bytes;
	u32 m_ramAddress;
	s32 m_id;
	bool m_isDirty;
	std::vector<u8> m_backupData;
};

} // nitro
