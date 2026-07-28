extends RefCounted

# ============================================================
# ULTRANOKIA Cutscene Data
# All story text — intro, level outros, ending, credits
# ============================================================

# Game intro — plays before Level 1
const GAME_INTRO: PackedStringArray = [
	"In the depths of the Techno-Hell, where flesh meets steel and souls are rendered into data...",
	"one demon awakens.",
	"ULTRANOKIA.",
	"Forged in the Hell Forge, betrayed by the Archdemon Council.",
	"Now, there is only one directive:",
	"ASCEND.",
	"Through blood. Through fire. Through the throne itself.",
]

# Level names for display
const LEVEL_NAMES: Array[String] = [
	"TECHNO HELL",
	"CYBER CATACOMBS",
	"HELL FORGE",
	"TOWER OF SINS",
	"SHATTERED CITY",
	"THRONE ROOM",
	"FINAL BATTLE",
]

# Level intro texts — shown when entering each level
const LEVEL_INTROS: Array[String] = [
	"LEVEL 1: TECHNO HELL — The outermost ring. Where the damned are processed and repurposed. The gate stands before you.",
	"LEVEL 2: CYBER CATACOMBS — Beneath the surface, the forgotten screams of a million lost souls still echo in the dark.",
	"LEVEL 3: HELL FORGE — Where your own kind were once created. The fires that birthed you now await your return.",
	"LEVEL 4: TOWER OF SINS — Each floor a testament to demonkind's cruelty. Pride. Greed. Wrath. Ascend through them all.",
	"LEVEL 5: SHATTERED CITY — Once the capital of the Techno-Hell Empire. Now a graveyard of steel and silence.",
	"LEVEL 6: THRONE ROOM — The seat of the False King. Empty thrones and broken oaths. He awaits his judgment.",
	"LEVEL 7: FINAL BATTLE — Behind the throne, the Final Gate opens. The Architect of Hell itself. The source of all betrayal.",
]

# Level outro texts — shown after completing each level
const LEVEL_OUTROS: Array[String] = [
	"The Techno-Hell gate crumbles behind you. The Cyber Catacombs await — where the forgotten screams of a million lost souls still echo.",
	"You've torn through the catacombs. But the Hell Forge burns ahead — where your own kind were once created. The fires remember you.",
	"The Forge is silent. Its flames extinguished by your passage. The Tower of Sins rises above — each floor a testament to demonkind's cruelty.",
	"The Tower crumbles beneath you. The Shattered City lies ahead — once the capital of the Techno-Hell Empire, now a monument to its fall.",
	"The Archdemon falls. The city's last defender is ash. Only the Throne Room remains. The False King awaits his judgment.",
	"The throne is empty. The False King is no more. But the Final Gate opens — and behind it, the Architect of Hell itself. The source of all.",
]

# Ending sequence — plays after Final Boss is defeated
const ENDING_SEQUENCE: PackedStringArray = [
	"The Architect falls.",
	"ULTRANOKIA stands alone in the ruins of the Throne Room.",
	"The Techno-Hell trembles.",
	"For the first time in eternity...",
	"there is silence.",
	"And in that silence, a new order begins.",
]

# Credits — scrolling text shown after ending
const CREDITS: PackedStringArray = [
	"",
	"ULTRANOKIA",
	"",
	"A fast-paced 3D FPS built in Godot Engine",
	"inspired by Ultrakill and Doom Eternal.",
	"",
	"---",
	"",
	"TEAM ULTRANOKIA",
	"",
	"Game Design: The ULTRANOKIA Team",
	"Programming: The ULTRANOKIA Team",
	"Level Design: The ULTRANOKIA Team",
	"Art Direction: The ULTRANOKIA Team",
	"Sound Design: The ULTRANOKIA Team",
	"",
	"---",
	"",
	"Built with Godot Engine 4",
	"",
	"Special thanks to:",
	"The Godot community",
	"The Ultrakill and Doom communities",
	"Everyone who believed in this project",
	"",
	"---",
	"",
	"\"Through blood. Through fire. Through the throne itself.\"",
	"",
	"",
	"Thank you for playing.",
	"",
]
