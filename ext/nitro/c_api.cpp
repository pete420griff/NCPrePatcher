#include "rom.hpp"
#include "armbin.hpp"
#include "overlaybin.hpp"
#include "headerbin.hpp"

namespace fs = std::filesystem;

using namespace nitro;

extern "C" {

	NitroRom* nitroRom_alloc() {
		return new NitroRom;
	}

	void nitroRom_release(NitroRom* rom) {
		delete rom;
	}

	bool nitroRom_load(NitroRom* rom, const char* filePath) {
		
		if (rom->loaded())
			return false;

		return rom->load(fs::path(filePath)) == NitroRom::LoadResult::Success;
	}

	size_t nitroRom_getSize(const NitroRom* rom) {
		return rom->size();
	}

	const HeaderBin* nitroRom_getHeader(const NitroRom* rom) {
		return &rom->getHeader();
	}

	ArmBin* nitroRom_loadArm9(NitroRom* rom) {
		ArmBin* arm = new ArmBin;
		arm->load(rom->data().data(), rom->getHeader().arm9, rom->getHeader().arm9AutoLoadListHookOffset, true);
		return arm;
	}

	ArmBin* nitroRom_loadArm7(NitroRom* rom) {
		ArmBin* arm = new ArmBin;
		arm->load(rom->data().data(), rom->getHeader().arm7, rom->getHeader().arm7AutoLoadListHookOffset, false);
		return arm;
	}


	HeaderBin* headerBin_alloc() {
		return new HeaderBin;
	}

	void headerBin_release(HeaderBin* header) {
		delete header;
	}

	bool headerBin_load(HeaderBin* header, const char* filePath) {
		return header->load(fs::path(filePath));
	}

	const char* headerBin_getGameTitle(const HeaderBin* header) {
		return header->gameTitle;
	}

	const char* headerBin_getGameCode(const HeaderBin* header) {
		static char gameCode[5];
		
		for (u32 i = 0; i < 4; i++)
			gameCode[i] = header->gameCode[i];
		
		gameCode[4] = '\0';
		return gameCode;
	}

	const char* headerBin_getMakerCode(const HeaderBin* header) {
		static char makerCode[3];
		makerCode[0] = header->makerCode[0];
		makerCode[1] = header->makerCode[1];
		makerCode[2] = '\0';
		return makerCode;
	}


	ArmBin* armBin_alloc() {
		return new ArmBin;
	}

	void armBin_release(ArmBin* arm) {
		delete arm;
	}

	bool armBin_load(ArmBin* arm, const char* filePath, u32 entryAddr, u32 ramAddr, u32 autoLoadHookOffset, bool arm9 = true) {
		return arm->load(fs::path(filePath), entryAddr, ramAddr, autoLoadHookOffset, arm9);
	}


	OverlayBin* overlayBin_alloc() {
		return new OverlayBin;
	}

	void overlayBin_release(OverlayBin* ov) {
		delete ov;
	}

	bool overlayBin_load(OverlayBin* ov, const char* filePath) {
		return false;
	}

}
