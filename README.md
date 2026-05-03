# DebuffedPlus
Debuffed plus Charmed addon with universal debuff tracker on Charmed players emphasizing when DoTs are present

# Debuffed (Merged with Charmed)

A lightweight, packet-parsing debuff tracker for Final Fantasy XI (Windower 4). Originally created by Xathe (Debuffed) and wes/icy (Charmed), this merged and enhanced version provides comprehensive target debuff tracking.

## Core Features
Tracks enfeebles on enemies and displays the enfeebles active on the current target. Now includes defense-down from abilities/weapon skills and modifier functionality for additional duration (see below). 
Tracks Charmed status effect on allies, giving a universal dialog box for Charmed players showing the active effects on them for easier crowd-control. Will highlight if Charmed players have DoTs on them so you can take actions other than trying to spam Sleep on them. 

Automatically tracks specific defense-down abilities as well. Currently, Tachi: Ageha, Armor Break, and Angon.

Charmed Alliance UI: Automatically detects when an alliance member is Charmed. 
	Displays a heart icon (`17.png`) next to their party frame.
    Opens a global warning text box listing their name and any active debuffs.
			CC-Breaker Warning: Automatically highlights Damage-over-Time effects (Poison, Dia, Bio, Requiem, Helix, etc.) in bright red so you know immediately if Sleep/Lullaby will be broken.
		Enfeebling Duration Modifiers:  Dynamically adjusts debuff timers based on your enfeebling duration gear/traits using a simple math modifier command.

## Installation
1. Download the repository and extract the folder.
2. Ensure the folder is named `Debuffed`.
3. Place the `Debuffed` folder into your `Windower4/addons/` directory.
4. Important: Ensure the `data/icons/17.png` file exists within the addon folder for the Charmed UI to work.
5. Load in-game using `//lua l debuffed`.
	Note: if you have a previous version, you will need to delete your settings.xml file in order to get the updated functionality. You can make a copy/backup of it and paste in anything that you want to keep after the addon generates a settings file for you.

## Commands

You can use `//debuffed` or `//dbf` for all commands.

### General Tracking Commands
//dbf mode (or `m`) - Toggles between whitelist and blacklist mode for the target display.
//dbf timers (or `t`) - Toggles the display of countdown timers next to the debuff names.
//dbf hide (or `h`) - Toggles whether timers that reach 0 are hidden or remain on the screen.
//dbf interval <value> (or `i`) - Changes the UI refresh interval (default is 0.1).
//dbf <whitelist|blacklist> <add|remove> <spell name> - Modifies your spell filter lists. (e.g., `//dbf blacklist add Dia II`)

### Charmed UI Commands
//dbf charmed debug - Toggles test display ON/OFF. Shows all icons and the text box so you can drag them to your desired screen locations. Run the command again to save their positions.
//dbf charmed align - Aligns all Charmed heart icons into a perfect vertical column based on the X-coordinate of your `<p0>` (Player) icon.
//dbf charmed reset - Resets all Charmed UI elements (icons and text box) back to their default screen coordinates.

### Enfeebling Duration Commands
Adjusts the math applied to standard debuff durations based on your gear. The formula used is: `(Base_Duration + Added_Seconds) * Multiplier`

//dbf enfdur +<value> - Sets just the flat added seconds. (e.g., `//dbf enfdur +15` for Saboteur/traits).
//dbf enfdur +<value> x<value> - Sets both variables at once. (e.g., `//dbf enfdur +15 x1.5`).
//dbf enfdur reset - Resets the math back to default `(Base + 0) * 1.0`.

## Credits
* **Debuffed:** Originally created by Xathe (Asura).
* **Charmed / TParty:** Originally created by wes, modified by icy.
* **Merger & Enhancements:** Persona (github.com/izaniki)
