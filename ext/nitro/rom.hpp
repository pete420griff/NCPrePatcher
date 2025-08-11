#pragma once

#include "headerbin.hpp"
#include "armbin.hpp"
#include "overlaybin.hpp"

namespace nitro {

class NitroROM {
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

    struct FAT {
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
        char* name;
    };

    struct FNTDirEntry : public FNTEntry {
        union {
            u16 dirID;
            struct { u8 dirIDLo; u8 dirIDHi; };
        };
    };

    NitroROM() = default;

    LoadResult load(const std::filesystem::path& path);

    bool loaded() const { return m_loaded; }

    [[nodiscard]] constexpr size_t size() const { return m_bytes.size(); };
    [[nodiscard]] constexpr const std::vector<u8>& data() const { return m_bytes; };
    [[nodiscard]] const HeaderBin& getHeader() const { return reinterpret_cast<const HeaderBin&>(*m_bytes.data()); }
    [[nodiscard]] const Banner& getBanner() const { return reinterpret_cast<const Banner&>(m_bytes.data()[getHeader().bannerOffset]); }

private:
    std::vector<u8> m_bytes;
    bool m_loaded = false;
};

} // nitro
