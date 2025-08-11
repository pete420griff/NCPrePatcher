#include "rom.hpp"
#include "armbin.hpp"
#include "overlaybin.hpp"
#include "headerbin.hpp"

namespace fs = std::filesystem;

using namespace nitro;

extern "C" {

	static NitroROM romInstance = {};

	bool nitro_loadROM(const char* romPath) {
		
		if (romInstance.loaded())
			return false;

		return romInstance.load(fs::path(romPath)) == NitroROM::LoadResult::Success;
	}

	size_t nitro_getROMSize() {
		return romInstance.size();
	}

}
