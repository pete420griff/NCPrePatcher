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


	DLL_EXPORT ArmBin* armBin_alloc() {
		return new ArmBin;
	}

	DLL_EXPORT void armBin_release(ArmBin* arm) {
		delete arm;
	}

	DLL_EXPORT bool armBin_load(ArmBin* arm, const char* filePath, u32 entryAddr, u32 ramAddr, u32 autoLoadHookOffset, bool arm9 = true) {
		return arm->load(fs::path(filePath), entryAddr, ramAddr, autoLoadHookOffset, arm9);
	}


	DLL_EXPORT OverlayBin* overlayBin_alloc() {
		return new OverlayBin;
	}

	DLL_EXPORT void overlayBin_release(OverlayBin* ov) {
		delete ov;
	}

	DLL_EXPORT bool overlayBin_load(OverlayBin* ov, const char* filePath) {
		return false;
	}

}
