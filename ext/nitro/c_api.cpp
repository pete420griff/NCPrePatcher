#include "rom.hpp"
#include "armbin.hpp"
#include "overlaybin.hpp"
#include "headerbin.hpp"

#if defined(_MSC_VER) || defined(__MINGW32__)
	#define NITRO_API __declspec(dllexport)
#else
	#define NITRO_API
#endif

namespace fs = std::filesystem;

using namespace nitro;

extern "C" {

	NITRO_API NitroRom* nitroRom_alloc() {
		return new(std::nothrow) NitroRom;
	}

	NITRO_API void nitroRom_release(NitroRom* rom) {
		delete rom;
	}

	NITRO_API bool nitroRom_load(NitroRom* rom, const char* filePath) {
		
		if (rom->loaded())
			return false;

		return rom->load(fs::path(filePath)) == NitroRom::LoadResult::Success;
	}

	NITRO_API size_t nitroRom_getSize(const NitroRom* rom) {
		return rom->size();
	}

	NITRO_API const HeaderBin* nitroRom_getHeader(const NitroRom* rom) {
		return &rom->getHeader();
	}

	NITRO_API const void* nitroRom_getFile(const NitroRom* rom, u32 id) {
		return rom->getFile(id);
	}

	NITRO_API u32 nitroRom_getFileSize(const NitroRom* rom, u32 id) {
		return rom->getFileSize(id);
	}

	NITRO_API ArmBin* nitroRom_loadArm9(NitroRom* rom) {
		ArmBin* arm = new(std::nothrow) ArmBin;
		if (!arm) return arm;
		arm->load(rom->data().data(), rom->getHeader().arm9, rom->getHeader().arm9AutoLoadListHookOffset, true);
		return arm;
	}

	NITRO_API ArmBin* nitroRom_loadArm7(NitroRom* rom) {
		ArmBin* arm = new(std::nothrow) ArmBin;
		arm->load(rom->data().data(), rom->getHeader().arm7, rom->getHeader().arm7AutoLoadListHookOffset, false);
		return arm;
	}

	NITRO_API OverlayBin* nitroRom_loadOverlay(NitroRom* rom, u32 id) {
		OverlayBin* ov = new(std::nothrow) OverlayBin;
		if (!ov) return ov;
		const OvtEntry& ovte = rom->getOvtEntry(id);
		if (!ov->load(static_cast<const u8*>(rom->getFile(ovte.fileID)), ovte))
			return nullptr;
		return ov;
	}

	NITRO_API const OvtEntry* nitroRom_getArm9OvT(const NitroRom* rom) {
		return reinterpret_cast<const OvtEntry*>(&rom->data()[rom->getHeader().arm9OvT.romOffset]);
	}

	NITRO_API u32 nitroRom_getOverlayCount(const NitroRom* rom) {
		return rom->getOverlayCount();
	}


	NITRO_API HeaderBin* headerBin_alloc() {
		return new(std::nothrow) HeaderBin;
	}

	NITRO_API void headerBin_release(HeaderBin* header) {
		delete header;
	}

	NITRO_API bool headerBin_load(HeaderBin* header, const char* filePath) {
		return header->load(fs::path(filePath));
	}

	NITRO_API const char* headerBin_getGameTitle(const HeaderBin* header) {
		static char gameTitle[13];

		for (u32 i = 0; i < 12; i++)
			gameTitle[i] = header->gameTitle[i];

		gameTitle[12] = '\0';
		return gameTitle;
	}

	NITRO_API const char* headerBin_getGameCode(const HeaderBin* header) {
		static char gameCode[5];

		for (u32 i = 0; i < 4; i++)
			gameCode[i] = header->gameCode[i];

		gameCode[4] = '\0';
		return gameCode;
	}

	NITRO_API const char* headerBin_getMakerCode(const HeaderBin* header) {
		static char makerCode[3];
		makerCode[0] = header->makerCode[0];
		makerCode[1] = header->makerCode[1];
		makerCode[2] = '\0';
		return makerCode;
	}

	NITRO_API u32 headerBin_getArm9AutoLoadHookOffset(const HeaderBin* header) {
		return header->arm9AutoLoadListHookOffset;
	}

	NITRO_API u32 headerBin_getArm7AutoLoadHookOffset(const HeaderBin* header) {
		return header->arm7AutoLoadListHookOffset;
	}

	NITRO_API u32 headerBin_getArm9EntryAddress(const HeaderBin* header) {
		return header->arm9.entryAddress;
	}

	NITRO_API u32 headerBin_getArm7EntryAddress(const HeaderBin* header) {
		return header->arm7.entryAddress;
	}

	NITRO_API u32 headerBin_getArm9RamAddress(const HeaderBin* header) {
		return header->arm9.ramAddress;
	}

	NITRO_API u32 headerBin_getArm7RamAddress(const HeaderBin* header) {
		return header->arm7.ramAddress;
	}

	NITRO_API u32 headerBin_getArm9OvTSize(const HeaderBin* header) {
		return header->arm9OvT.size;
	}


	NITRO_API u64 codeBin_read64(const ICodeBin* bin, u32 address) {
		return bin->read<u64>(address);
	}

	NITRO_API u32 codeBin_read32(const ICodeBin* bin, u32 address) {
		return bin->read<u32>(address);
	}

	NITRO_API u16 codeBin_read16(const ICodeBin* bin, u32 address) {
		return bin->read<u16>(address);
	}

	NITRO_API u8 codeBin_read8(const ICodeBin* bin, u32 address) {
		return bin->read<u8>(address);
	}

	NITRO_API const char* codeBin_readCString(const ICodeBin* bin, u32 address) {
		return static_cast<const char*>(bin->getPtrToData(address));
	}

	NITRO_API u32 codeBin_getStartAddress(const ICodeBin* bin) {
		return bin->getStartAddress();
	}

	NITRO_API u32 codeBin_getSize(const ICodeBin* bin) {
		return bin->getSize();
	}

	NITRO_API const void* codeBin_getSectPtr(const ICodeBin* bin, u32 address, size_t sect_size) {
		return (bin->getStartAddress() + bin->getSize() < address + sect_size) ? nullptr : bin->getPtrToData(address);
	}


	NITRO_API ArmBin* armBin_alloc() {
		return new(std::nothrow) ArmBin;
	}

	NITRO_API void armBin_release(ArmBin* arm) {
		delete arm;
	}

	NITRO_API bool armBin_load(ArmBin* arm, const char* filePath, u32 entryAddr, u32 ramAddr, u32 autoLoadHookOffset, bool arm9 = true) {
		return arm->load(fs::path(filePath), entryAddr, ramAddr, autoLoadHookOffset, arm9);
	}

	NITRO_API u32 armBin_getEntryPointAddress(const ArmBin* arm) {
		return arm->getEntryPointAddress();
	}

	NITRO_API const ArmBin::ModuleParams* armBin_getModuleParams(const ArmBin* arm) {
		return arm->getModuleParams();
	}

	NITRO_API const ArmBin::AutoLoadEntry* armBin_getAutoloadEntry(const ArmBin* arm, u32 entryID) {
		return &arm->getAutoloadList()[entryID];
	}

	NITRO_API size_t armBin_getAutoloadEntryCount(const ArmBin* arm) {
		return arm->getAutoloadList().size();
	}

	NITRO_API bool armBin_sanityCheckAddress(const ArmBin* arm, u32 addr) {
		return arm->sanityCheckAddress(addr);
	}


	NITRO_API OverlayBin* overlayBin_alloc() {
		return new(std::nothrow) OverlayBin;
	}

	NITRO_API void overlayBin_release(OverlayBin* ov) {
		delete ov;
	}

	NITRO_API bool overlayBin_load(OverlayBin* ov, const char* filePath, u32 ramAddress, bool compressed, s32 id) {
		return ov->load(filePath, ramAddress, compressed, id);
	}

}
