#include "rom.hpp"
#include "armbin.hpp"
#include "overlaybin.hpp"
#include "headerbin.hpp"

#if defined(_MSC_VER) || defined(__MINGW32__)
	#define DLL_EXPORT __declspec(dllexport)
#else
	#define DLL_EXPORT
#endif

namespace fs = std::filesystem;

using namespace nitro;

extern "C" {

	DLL_EXPORT NitroRom* nitroRom_alloc() {
		return new NitroRom;
	}

	DLL_EXPORT void nitroRom_release(NitroRom* rom) {
		delete rom;
	}

	DLL_EXPORT bool nitroRom_load(NitroRom* rom, const char* filePath) {
		
		if (rom->loaded())
			return false;

		return rom->load(fs::path(filePath)) == NitroRom::LoadResult::Success;
	}

	DLL_EXPORT size_t nitroRom_getSize(const NitroRom* rom) {
		return rom->size();
	}

	DLL_EXPORT const HeaderBin* nitroRom_getHeader(const NitroRom* rom) {
		return &rom->getHeader();
	}

	DLL_EXPORT const void* nitroRom_getFile(const NitroRom* rom, u32 id) {
		return rom->getFile(id);
	}

	DLL_EXPORT u32 nitroRom_getFileSize(const NitroRom* rom, u32 id) {
		return rom->getFileSize(id);
	}

	DLL_EXPORT ArmBin* nitroRom_loadArm9(NitroRom* rom) {
		ArmBin* arm = new ArmBin;
		arm->load(rom->data().data(), rom->getHeader().arm9, rom->getHeader().arm9AutoLoadListHookOffset, true);
		return arm;
	}

	DLL_EXPORT ArmBin* nitroRom_loadArm7(NitroRom* rom) {
		ArmBin* arm = new ArmBin;
		arm->load(rom->data().data(), rom->getHeader().arm7, rom->getHeader().arm7AutoLoadListHookOffset, false);
		return arm;
	}

	DLL_EXPORT OverlayBin* nitroRom_loadOverlay(NitroRom* rom, u32 id) {
		OverlayBin* ov = new OverlayBin;
		const OvtEntry& ovte = rom->getOvtEntry(id);
		if (!ov->load(static_cast<const u8*>(rom->getFile(ovte.fileID)), ovte))
			return nullptr;
		return ov;
	}

	DLL_EXPORT const OvtEntry* nitroRom_getArm9OvT(const NitroRom* rom) {
		return reinterpret_cast<const OvtEntry*>(&rom->data()[rom->getHeader().arm9OvT.romOffset]);
	}

	DLL_EXPORT u32 nitroRom_getOverlayCount(const NitroRom* rom) {
		return rom->getOverlayCount();
	}


	DLL_EXPORT HeaderBin* headerBin_alloc() {
		return new HeaderBin;
	}

	DLL_EXPORT void headerBin_release(HeaderBin* header) {
		delete header;
	}

	DLL_EXPORT bool headerBin_load(HeaderBin* header, const char* filePath) {
		return header->load(fs::path(filePath));
	}

	DLL_EXPORT const char* headerBin_getGameTitle(const HeaderBin* header) {
		static char gameTitle[13];

		for (u32 i = 0; i < 12; i++)
			gameTitle[i] = header->gameTitle[i];

		gameTitle[12] = '\0';
		return gameTitle;
	}

	DLL_EXPORT const char* headerBin_getGameCode(const HeaderBin* header) {
		static char gameCode[5];

		for (u32 i = 0; i < 4; i++)
			gameCode[i] = header->gameCode[i];

		gameCode[4] = '\0';
		return gameCode;
	}

	DLL_EXPORT const char* headerBin_getMakerCode(const HeaderBin* header) {
		static char makerCode[3];
		makerCode[0] = header->makerCode[0];
		makerCode[1] = header->makerCode[1];
		makerCode[2] = '\0';
		return makerCode;
	}

	DLL_EXPORT u32 headerBin_getArm9AutoLoadHookOffset(const HeaderBin* header) {
		return header->arm9AutoLoadListHookOffset;
	}

	DLL_EXPORT u32 headerBin_getArm7AutoLoadHookOffset(const HeaderBin* header) {
		return header->arm7AutoLoadListHookOffset;
	}

	DLL_EXPORT u32 headerBin_getArm9EntryAddress(const HeaderBin* header) {
		return header->arm9.entryAddress;
	}

	DLL_EXPORT u32 headerBin_getArm7EntryAddress(const HeaderBin* header) {
		return header->arm7.entryAddress;
	}

	DLL_EXPORT u32 headerBin_getArm9RamAddress(const HeaderBin* header) {
		return header->arm9.ramAddress;
	}

	DLL_EXPORT u32 headerBin_getArm7RamAddress(const HeaderBin* header) {
		return header->arm7.ramAddress;
	}

	DLL_EXPORT u32 headerBin_getArm9OvTSize(const HeaderBin* header) {
		return header->arm9OvT.size;
	}


	DLL_EXPORT u64 codeBin_read64(const ICodeBin* bin, u32 address) {
		return bin->read<u64>(address);
	}

	DLL_EXPORT u32 codeBin_read32(const ICodeBin* bin, u32 address) {
		return bin->read<u32>(address);
	}

	DLL_EXPORT u16 codeBin_read16(const ICodeBin* bin, u32 address) {
		return bin->read<u16>(address);
	}

	DLL_EXPORT u8 codeBin_read8(const ICodeBin* bin, u32 address) {
		return bin->read<u8>(address);
	}

	DLL_EXPORT u32 codeBin_getStartAddress(const ICodeBin* bin) {
		return bin->getStartAddress();
	}

	DLL_EXPORT u32 codeBin_getSize(const ICodeBin* bin) {
		return bin->getSize();
	}


	DLL_EXPORT ArmBin* armBin_alloc() {
		return new ArmBin;
	}

	DLL_EXPORT void armBin_release(ArmBin* arm) {
		delete arm;
	}

	DLL_EXPORT bool armBin_load(ArmBin* arm, const char* filePath, u32 entryAddr, u32 ramAddr, u32 autoLoadHookOffset, bool arm9 = true) {
		return arm->load(fs::path(filePath), entryAddr, ramAddr, autoLoadHookOffset, arm9);
	}

	DLL_EXPORT u32 armBin_getEntryPointAddress(const ArmBin* arm) {
		return arm->getEntryPointAddress();
	}


	DLL_EXPORT OverlayBin* overlayBin_alloc() {
		return new OverlayBin;
	}

	DLL_EXPORT void overlayBin_release(OverlayBin* ov) {
		delete ov;
	}

	DLL_EXPORT bool overlayBin_load(OverlayBin* ov, const char* filePath, u32 ramAddress, bool compressed, s32 id) {
		return ov->load(filePath, ramAddress, compressed, id);
	}

}
