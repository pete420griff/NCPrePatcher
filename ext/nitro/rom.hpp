#pragma once

#include "headerbin.hpp"
#include "armbin.hpp"
#include "overlaybin.hpp"

namespace nitro {

class NitroRom {
public:
    enum class LoadResult : u8 {
        Success,
        InvalidPath,
        SizeExceed,
        Failure
    };

    struct Banner {
        u8 version;
        u8 reserved1;
        u16 crc16V1;
        u8 reserved2[28];
        u8 iconChr[0x200];
        u8 iconPltt[0x20];
    };

    struct FATEntry {
        u32 start;  // top address of file
        u32 end;    // bottom address
    };

    struct FNTDir {
        u32 entryStart;
        u16 entryFileID;    // top entry file ID
        u16 parentID;       // parent directory ID
    };

    struct FNTEntry {
        u8 entryType        : 1;
        u8 entryNameLength  : 7;
        u32 name; // cast to char*
    };

    struct FNTDirEntry : public FNTEntry {
        union {
            u16 dirID;
            struct { u8 dirIDLo; u8 dirIDHi; };
        };
    };

    NitroRom() noexcept = default;

    LoadResult load(const std::filesystem::path& path);

    bool loaded() const { return m_loaded; }

    [[nodiscard]] constexpr size_t size() const { return m_bytes.size(); };
    [[nodiscard]] constexpr const std::vector<u8>& data() const { return m_bytes; };

    [[nodiscard]] const HeaderBin& getHeader() const;
    [[nodiscard]] const Banner& getBanner() const;
    [[nodiscard]] const FATEntry& getFATEntry(u32 index) const;
    [[nodiscard]] const void* getFile(u32 id) const;
    [[nodiscard]] const OvtEntry& getOvtEntry(u32 index) const;

    u32 getFileSize(u32 id) const;
    u32 getOverlayCount() const;

private:
    std::vector<u8> m_bytes;
    bool m_loaded = false;
};

} // nitro
