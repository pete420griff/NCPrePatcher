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

	const char* nitroRom_getGameTitle(const NitroRom* rom) {
		return rom->getHeader().gameTitle;
	}

	const char* nitroRom_getGameCode(const NitroRom* rom) {
		return rom->getHeader().gameCode;
	}


	ArmBin* armBin_alloc() {
		return new ArmBin;
	}

	void armBin_release(ArmBin* arm) {
		delete arm;
	}

	bool armBin_load(ArmBin* arm, const char* filePath, bool arm9 = true) {
		// arm->load(filePath,)
		return false;
	}

	bool armBin_loadFromRom(ArmBin* arm, const NitroRom* rom, bool arm9 = true) {
		return false;
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

	bool overlayBin_loadFromRom(OverlayBin* ov, const NitroRom* rom, const char* filePath) {
		return false;
	}

}
