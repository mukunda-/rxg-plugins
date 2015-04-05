#pragma semicolon 1
//#tf2items_randomizer#

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#tryinclude <tf2items_giveweapon>
#tryinclude <visweps>
#define REQUIRE_PLUGIN

//#define TF2ITEMSOLD

#define PLUGIN_NAME		"[TF2Items] Randomizer"
#define PLUGIN_AUTHOR		"FlaminSarge"
#define PLUGIN_VERSION		"1.591" //As of Aug11, 2013
#define PLUGIN_CONTACT		"https://forums.alliedmods.net/showthread.php?t=139069"
#define PLUGIN_DESCRIPTION	"[TF2] Randomizer rebuilt around the TF2Items extension"

#define EF_BONEMERGE			(1 << 0)
#define EF_BONEMERGE_FASTCULL	(1 << 7)

public Plugin:myinfo = {
	name			= PLUGIN_NAME,
	author			= PLUGIN_AUTHOR,
	description	= PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url				= PLUGIN_CONTACT
};

new TFClassType:iRndClass[MAXPLAYERS + 1];
new iRndWeapon[MAXPLAYERS + 1][3];
new iRndCloak[MAXPLAYERS + 1];
new TFClassType:iDefClass[MAXPLAYERS + 1];
//new bool:RoundStarted;
//new pOldAmmo[MAXPLAYERS + 1][2];
//new bool:g_bMapLoaded = false;
new bool:bUbered[MAXPLAYERS + 1] = { false, ... };
//new playerWeapon[MAXPLAYERS + 1][6][2] = -1;
#if defined _visweps_included
new bool:bVisWeps = false;
#endif
new bool:tf2items_giveweapon = false;
#if defined _steamtools_included
new bool:steamtools = false;
#endif
new Handle:hSDKEquipWearable;
new bool:bSDKStarted;
new bool:bJarated[MAXPLAYERS + 1];
new bool:bDoubleJumped[MAXPLAYERS + 1];
new iLastButtons[MAXPLAYERS + 1];
new bool:bDontRespawn[MAXPLAYERS + 1];
//new Float:flBabyFaceSpeed[MAXPLAYERS + 1] = { -1.0, ... };
//new bTeleOnSpawn[MAXPLAYERS + 1];
//new Float:vecTeleOnSpawnOrigin[MAXPLAYERS + 1][3];
//new Float:vecTeleOnSpawnAngles[MAXPLAYERS + 1][3];

// cvars
new bool:bCvarEnabled;
new bool:bCvarAnnounce;
new iCvarPartial;
new bool:bCvarDestroy;
//new cvar_fixammo;
//new cvar_fixpyro;
new bool:bCvarFixSpy;
new iCvarFixUber;
#define FIXUBER_HEALBEAMS	(1 << 0)
#define FIXUBER_UBERS		(1 << 1)

new bool:bCvarBetaWeapons;
new bool:bCvarCustomWeapons;
//new bool:cvar_fixreload;
new bool:bCvarGoldenWrench;
new bool:bCvarFixFood;
#if defined _steamtools_included
new bool:bCvarGameDesc;
#endif
new bool:bCvarSpyCloak;

new bool:bCvarDebug;

// fixes
//new ammo_count[MAXPLAYERS + 1][2];
//new spy_status[MAXPLAYERS + 1];
new iHealBeamParticles[MAXPLAYERS + 1][3];
new iHealTarget[MAXPLAYERS + 1] = { -1, ... };
new iEyeParticle[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

//weapons
static const iWeaponPrimary[] =
{
	-1,
	13,
	14,
	15,
	17,
	18,
	19,
	21,
	24,
	36,
	40,
	41,
	45,
	56,
	61,
	127,
	141,
	161,
	2041,
	2141,
	215,
	228,
	220,
	224,
	237,
	230,
	2228,
	9,
	298,
	305,
	308,
	312,
	412,
	402,
	405,
	414,
	424,
	448,
	460,
	441,
	513,
	525,
	526,
	527,
	588,
	594,
	608,
	730,
	741,
	752,
	772,
	811,
	996,
	997
};
static const String:strWeaponPrimary[][] =
{
	"Normal",					//0
	"Scattergun",				//1
	"Sniper Rifle",				//2
	"Minigun",					//3
	"Syringe Gun",				//4
	"Rocket Launcher",			//5
	"Grenade Launcher",			//6
	"Flamethrower",				//7
	"Revolver",					//8
	"Blutsauger",
	"Backburner",
	"Natascha",
	"Force-a-Nature",
	"Hunstman",
	"Ambassador",
	"Direct Hit",
	"Frontier Justice",
	"Big Kill",
	"Ludmila",					//18
	"Texas Ten-Shot",			//19
	"Degreaser",
	"Black Box",
	"Shortstop",
	"L'Etranger",
	"Rocket Jumper",
	"Sydney Sleeper",
	"The Army of One",			//26
	"Shotgun",
	"Iron Curtain",
	"Crusader's Crossbow",
	"Loch-n-Load",
	"Brass Beast",
	"Overdose",
	"Bazaar Bargain",
	"Ali Baba's Wee Booties",
	"Liberty Launcher",
	"Tomislav",
	"Soda Popper",
	"Enforcer",
	"Cow Mangler 5000",
	"The Original",
	"Diamondback",
	"Machina",
	"Widowmaker",
	"Pomson 6000",
	"Phlogistinator",
	"Bootlegger",
	"Beggar's Bazooka",
	"Rainblower",
	"Hitman's Heatmaker",
	"Baby Face's Blaster",
	"Huo-Long Heater",
	"Loose Cannon",
	"Rescue Ranger"
};
static const iWeaponSecondary[] =
{
	-1,
	16,
	20,
	29,
	35,
	39,
	42,
	46,
	58,
	130,
	140,
	159,
	163,
	222,
	226,
	129,
	265,
	311,
	22,
	294,
	231,
	57,
	131,
	133,
	2058,
	354,
	351,
	411,
	433,
	406,
	415,
	425,
	444,
	449,
	442,
	528,
	595,
	642,
	740,
	751,
	773,
	812,
	735,
	810,
	998,
	933
};
static const String:strWeaponSecondary[][] =
{
	"Normal",
	"SMG",
	"Sticky Launcher",
	"Medigun",
	"Kritzkrieg",
	"Flare Gun",
	"Sandvich",
	"Bonk! Atomic Punch",
	"Jarate",
	"Scottish Resistance",
	"Wrangler",
	"Dalokohs Bar",
	"Crit-a-Cola",
	"Mad Milk",
	"Battalion's Backup",
	"Buff Banner",
	"Sticky Jumper",
	"Buffalo Steak Sandvich",
	"Pistol",
	"Lugermorph",
	"Darwin's Danger Shield",
	"Razorback",
	"Chargin' Targe",
	"Gunboats",
	"Ant'eh'gen",				//24
	"The Concheror",
	"Detonator",
	"Quick-Fix",
	"Fishcake",
	"Splendid Screen",
	"Reserve Shooter",
	"Family Business",
	"Mantreads",
	"Winger",
	"Righteous Bison",
	"Short Circuit",
	"Manmelter",
	"Cozy Camper",
	"Scorch Shot",
	"Cleaner's Carbine",
	"Pretty Boy's Pocket Pistol",
	"Flying Guillotine",
	"Sapper",
	"Red-Tape Recorder",
	"Vaccinator",
	"Ap-Sap"
};
static const iWeaponMelee[] =
{
	-1,
	0,
	2,
	3,
	4,
	195,
	7,
	8,
	37,
	38,
	43,
	44,
	132,
	142,
	153,
	155,
	171,
	172,
	239,
	214,
	221,
	225,
	232,
	173,
	169,
	266,
	2193,
	2171,
	304,
	307,
	310,
	317,
	325,
	326,
	327,
	329,
	331,
	2197,
	1,
	6,
	128,
	154,
	264,
	348,
	349,
	355,
	356,
	357,
	452,
	466,
	423,
	401,
	404,
	413,
	416,
	426,
	447,
	450,
	461,
	457,
	482,
	474,
	572,
	574,
	587,
	589,
	593,
	609,
	638,
	648,
	649,
	656,
	727,
	739,
	775,
	813,
	939,
	954,
	1013
};
static const String:strWeaponMelee[][] =
{
	"Normal",
	"Bat",
	"Fire Axe",
	"Kukri",
	"Knife",
	"Fists",
	"Wrench",
	"Bonesaw",
	"Ubersaw",
	"Axetinguisher",
	"Killing Gloves of Boxing",
	"Sandman",
	"Eyelander",
	"Gunslinger",
	"Homewrecker",
	"Southern Hospitality",
	"Tribalman's Shiv",
	"Scotsman's Skullcutter",
	"Gloves of Running Urgently",
	"Powerjack",
	"Holy Mackerel",
	"Your Eternal Reward",
	"Bushwacka",
	"Vita-Saw",
	"Golden Wrench",
	"Horseless Headless Horsemann's Headtaker",
	"Fighter's Falcata",						//26
	"Khopesh Climber",							//27
	"Amputator",
	"Ullapool Caber",
	"Warrior's Spirit",
	"Candy Cane",
	"Boston Basher",
	"Backscratcher",
	"Claidheamh Mor",
	"Jag",
	"Fists of Steel",
	"Rebel's Curse",							//37
	"Bottle",
	"Shovel",
	"Equalizer",
	"Pain Train",
	"Frying Pan",
	"Sharpened Volcano Fragment",
	"Sun-on-a-Stick",
	"The Fan O'War",
	"Conniver's Kunai",
	"The Half-Zatoichi",
	"Three Rune Blade",
	"The Maul",
	"The Saxxy",
	"Shahanshah",
	"Persian Persuader",
	"Solemn Vow",
	"Market Gardener",
	"Eviction Notice",
	"Disciplinary Action",
	"Atomizer",
	"Big Earner",
	"Postal Pummeler",
	"Nessie's Nine Iron",
	"Conscientious Objector",
	"Unarmed Combat",
	"Wanga Prick",
	"Apoco-Fists",
	"Eureka Effect",
	"Third Degree",
	"Scottish Handshake",
	"Sharp Dresser",
	"Wrap Assassin",
	"Spy-cicle",
	"Holiday Punch",
	"Black Rose",
	"Lollichop",
	"Escape Plan",
	"Neon Annihilator",
	"Bat Outta Hell",
	"Memory Maker",
	"Ham Shank"
};
static const iWeaponCloakary[] =	//so clever at naming these things b/c why not
{
	-1,
	30,
	59,
	60,
	297,
	947
};
static const String:strWeaponCloakary[][] =
{
	"Normal",
	"Invisibility Watch",
	"Dead Ringer",
	"Cloak and Dagger",
	"Enthusiast's Timepiece",
	"Quackenbirdt"
};
enum
{
	Handle:BonkTimer = 0,
	Handle:BallTimer,
	Handle:JarTimer,
	Handle:EatTimer,
	Handle:ChargeTimer,
	Handle:DalokohsTimer,
	Handle:IgniteArrowTimer,
	Handle:MaxTimers
};
enum
{
	BonkCooldown = 0,
	BallCooldown,
	JarCooldown,
	EatCooldown,
	LongEatCooldown,
	ReloadCooldown,
	MaxCooldowns
};
enum
{
	Handle:PrimaryHud,
	Handle:SecondaryHud,
	Handle:MeleeHud,
	Handle:DisguiseHud
};
new Handle:hWeaponsHud;
enum
{
	Float:PrimarySavedInfo,
	Float:SecondarySavedInfo,
	Float:MeleeSavedInfo,
	Float:DisguiseSavedInfo
};
new Handle:hHuds[4];
new Float:flSavedInfo[MAXPLAYERS + 1][4];
new Handle:hTimers[MAXPLAYERS + 1][MaxTimers];
new Handle:hTimerAnnounce[MAXPLAYERS + 1];
new bool:bHasAnnounce[MAXPLAYERS + 1];
/*new Handle:BonkCooldownTimer[MAXPLAYERS + 1];
new Handle:BallCooldownTimer[MAXPLAYERS + 1];
new Handle:JarCooldownTimer[MAXPLAYERS + 1];
new Handle:EatCooldownTimer[MAXPLAYERS + 1];
new Handle:DalokohsBuffTimer[MAXPLAYERS + 1];
new Handle:pChargeTiming[MAXPLAYERS + 1];
new Handle:pIgniteArrowTimer[MAXPLAYERS + 1];*/
new bool:bCooldowns[MAXPLAYERS + 1][MaxCooldowns];
/*new bool:pReloadCooldown[MAXPLAYERS + 1];
new bool:pEatCooldown[MAXPLAYERS + 1];
new bool:pBonkCooldown[MAXPLAYERS + 1];
new bool:pJarCooldown[MAXPLAYERS + 1];
new bool:pBallCooldown[MAXPLAYERS + 1];
new bool:pLongEatCooldown[MAXPLAYERS + 1];*/
new bool:bDalokohsBuff[MAXPLAYERS + 1];

new Handle:hItemInfoTrie = INVALID_HANDLE;
//new Handle:hMaxHealth;
//new Handle:hHeal_Radius;

#if defined _steamtools_included
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("Steam_SetGameDescription");
	return APLRes_Success;
}
#endif

//new Handle:max_ammo;
public OnPluginStart()
{
	decl String:strModName[32]; GetGameFolderName(strModName, sizeof(strModName));
	if (strncmp(strModName, "tf", 2, false) != 0)
	{
		SetFailState("[TF2Items] Randomizer is for TF2 only. It may or may not work with TF2 Beta.");
		return;
	}
	//Friggin SDKCalls...
	if (!TF2_SdkStartup()) return;

	/***********
	 * ConVars *
	 ***********/
	new Handle:cv_version = CreateConVar("tf2items_rnd_version", PLUGIN_VERSION, "[TF2Items]Randomizer Version", FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_SPONLY);
	new Handle:cv_enabled = CreateConVar("tf2items_rnd_enabled", "0", "Enables/disables forcing random class and giving random weapons.", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_announce = CreateConVar("tf2items_rnd_announce", "1", "Enables/disables the Randomizer announcement in chat on join/enable.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_partial = CreateConVar("tf2items_rnd_normals", "0", "If >0, increases chance of each weapon roll being set to normal, -1 is no normals", FCVAR_NOTIFY | FCVAR_PLUGIN, true, -1.0, true, 100.0);
	new Handle:cv_destroy = CreateConVar("tf2items_rnd_destroy_buildings", "1", "Destroys Engineer buildings when a player respawns as a different class.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
//	new Handle:cv_fixammo = CreateConVar("tf2items_rnd_fix_ammo", "1", "Emulates proper ammo handling.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
//	new Handle:cv_fixpyro = CreateConVar("tf2items_rnd_fix_pyro", "1", "Properly limits the Pyro's speed when scoped or spun down.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_fixspy  = CreateConVar("tf2items_rnd_fix_spy", "1", "0 = don't check, 1 = force undisguise on all attacks", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_fixuber = CreateConVar("tf2items_rnd_fix_uber", "3", "1-Emulates healbeams for non-Medics, 2-Emulates Ubercharges for non-Medics, 3-both", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_customweapons = CreateConVar("tf2items_rnd_customweapons", "1", "Includes Custom Weapons in the Randomizer.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_betaweapons = CreateConVar("tf2items_rnd_betaweapons", "1", "Includes Ludmila in the Randomizer.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
//	new Handle:cv_fixreload = CreateConVar("tf2items_rnd_fix_reload", "1", "Stops Revolver reload exploit for non-spies.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_goldenwrench = CreateConVar("tf2items_rnd_godweapons", "1", "Allows Randomizer to give the Golden Wrench, Headtaker, Saxxy.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_fixfood = CreateConVar("tf2items_rnd_fix_food", "1", "Emulates Food items for non-Heavies and non-Scouts", FCVAR_PLUGIN, true, 0.0, true, 1.0);
#if defined _steamtools_included
	new Handle:cv_gamedesc = CreateConVar("tf2items_rnd_gamedesc", "1", "1 - [TF2Items]Randomizer vVERSION when Randomizer is enabled. Requires Steamtools.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
#endif
//	new Handle:cv_gdmanifix = CreateConVar("tf2items_rnd_manifix_gd", "0", "If gamedesc is on, enable if 3rd party plugins have trouble detecting gametype", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	new Handle:cv_spycloak = CreateConVar("tf2items_rnd_cloaks", "1", "If enabled, randomize a Spy's cloak", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	new Handle:cv_debug = CreateConVar("tf2items_rnd_debug", "0", "Set 1 to enable debug messages", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	HookConVarChange(cv_enabled, cvhook_enabled);
	HookConVarChange(cv_announce, cvhook_announce);
	HookConVarChange(cv_partial, cvhook_partial);
	HookConVarChange(cv_destroy, cvhook_destroy);
//	HookConVarChange(cv_fixammo, cvhook_fixammo);
//	HookConVarChange(cv_fixpyro, cvhook_fixpyro);
	HookConVarChange(cv_fixspy,  cvhook_fixspy);
	HookConVarChange(cv_fixuber, cvhook_fixuber);
	HookConVarChange(cv_betaweapons, cvhook_betaweapons);
	HookConVarChange(cv_customweapons, cvhook_customweapons);
//	HookConVarChange(cv_fixreload, cvhook_fixreload);
	HookConVarChange(cv_goldenwrench, cvhook_goldenwrench);
	HookConVarChange(cv_fixfood, cvhook_fixfood);
#if defined _steamtools_included
	HookConVarChange(cv_gamedesc, cvhook_gamedesc);
#endif
//	HookConVarChange(cv_gdmanifix, cvhook_manifix);
	HookConVarChange(cv_spycloak, cvhook_spycloak);

	HookConVarChange(cv_debug, cvhook_debug);

//	HookConVarChange(FindConVar("sv_tags"), cvhook_tags);

	SetConVarString(cv_version, PLUGIN_VERSION);
	bCvarEnabled = GetConVarBool(cv_enabled);
	bCvarAnnounce = GetConVarBool(cv_announce);
	iCvarPartial = GetConVarInt(cv_partial);
	bCvarDestroy = GetConVarBool(cv_destroy);
//	cvar_fixammo = GetConVarBool(cv_fixammo);
//	cvar_fixpyro = GetConVarBool(cv_fixpyro);
	bCvarFixSpy = GetConVarBool(cv_fixspy);
	iCvarFixUber = GetConVarInt(cv_fixuber);
	bCvarBetaWeapons = GetConVarBool(cv_betaweapons);
	bCvarCustomWeapons = GetConVarBool(cv_customweapons);
//	cvar_fixreload = GetConVarBool(cv_fixreload);
	bCvarGoldenWrench = GetConVarBool(cv_goldenwrench);
	bCvarFixFood = GetConVarBool(cv_fixfood);
#if defined _steamtools_included
	bCvarGameDesc = GetConVarBool(cv_gamedesc);
#endif
//	cvar_manifix = GetConVarBool(cv_gdmanifix);
	bCvarSpyCloak = GetConVarBool(cv_spycloak);

	bCvarDebug = GetConVarBool(cv_debug);

	/***********
	 * Commands *
	 ***********/
	RegAdminCmd("tf2items_rnd_enable", Command_EnableRnd, ADMFLAG_CONVARS, "Changes the tf2items_rnd_enabled cvar to 1");
	RegAdminCmd("tf2items_rnd_disable", Command_DisableRnd, ADMFLAG_CONVARS, "Changes the tf2items_rnd_enabled cvar to 0");
	RegAdminCmd("tf2items_rnd_reroll", Command_Reroll, ADMFLAG_CHEATS, "Rerolls a player: tf2items_rnd_reroll <target>");
	RegAdminCmd("sm_reroll", Command_Reroll, ADMFLAG_CHEATS, "Rerolls a player: sm_reroll <target>");
	RegAdminCmd("tf2items_rnd_loadout", Command_MyLoadout, 0, "Re-displays loadout to client");
	RegAdminCmd("sm_myloadout", Command_MyLoadout, 0, "Re-displays loadout to client");
	RegAdminCmd("sm_myweps", Command_MyLoadout, 0, "Re-displays loadout to client");
	RegAdminCmd("sm_cantsee", Command_CantSee, 0, "Sets client's active weapon to be half-invisible");
	RegAdminCmd("tf2items_rnd_set", Command_SetLoadout, ADMFLAG_CHEATS, "Set a client's loadout- cmd target class wep1 wep2 wep3 cloak");
	RegAdminCmd("rnd_set", Command_SetLoadout, ADMFLAG_CHEATS, "Set a client's loadout- cmd target class wep1 wep2 wep3 cloak");
//	RegAdminCmd("sm_healring", Cmd_Healring, 0, "sm_healring <0/1>");
//	RegConsoleCmd("sm_rollme", Command_RollMe,

	AddCommandListener(Cmd_destroy, "destroy");	//I figure I'll have it Cmd_commandstring, except for taunts.
//	AddCommandListener(Cmd_build, "build");
	AddCommandListener(Cmd_taunt, "+taunt");
	AddCommandListener(Cmd_taunt, "taunt");
	AddCommandListener(Cmd_taunt, "+use_action_slot_item_server");
	AddCommandListener(Cmd_taunt, "use_action_slot_item_server");

	//Translations file...
	LoadTranslations("common.phrases");
	/************************
	 * Event & Entity Hooks *
	 ************************/
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_win", Event_RoundWin, EventHookMode_PostNoCopy);
	HookEvent("post_inventory_application", Event_PostInventoryApplication, EventHookMode_Post);
//	HookEvent("teamplay_round_start", Roundstart, EventHookMode_PostNoCopy);
//	HookEvent("teamplay_round_active", Roundactive, EventHookMode_PostNoCopy);
	HookUserMessage(GetUserMessageId("PlayerJarated"), Event_PlayerJarated);
	HookUserMessage(GetUserMessageId("PlayerJaratedFade"), Event_PlayerJaratedFade);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_carryobject", Event_PlayerCarryObject);
	HookEntityOutput("trigger_ignite_arrows", "OnStartTouch", Output_IgniteArrowsStart);
	HookEntityOutput("trigger_ignite_arrows", "OnEndTouch", Output_IgniteArrowsEnd);

//	MarkNativeAsOptional("VisWep_GiveWeapon");
	//Item Trie
	CreateItemInfoTrie();
	for (new i = 0; i < sizeof(hHuds); i++)
	{
		hHuds[i] = CreateHudSynchronizer();
	}
	hWeaponsHud = CreateHudSynchronizer();

#if defined _visweps_included
	bVisWeps = LibraryExists("visweps");
#endif
	tf2items_giveweapon = LibraryExists("tf2items_giveweapon");
#if defined _steamtools_included
	steamtools = LibraryExists("SteamTools");
#endif

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client)) continue;
		OnClientPutInServer(client);
		if (!IsPlayerAlive(client)) continue;
		iDefClass[client] = TF2_GetPlayerClass(client);
	}
}
/*stock TagsCheck(const String:tag[], bool:remove = false)	//DarthNinja
{
	new Handle:hTags = FindConVar("sv_tags");
	decl String:tags[255];
	GetConVarString(hTags, tags, sizeof(tags));

	if (StrContains(tags, tag, false) == -1 && !remove)
	{
		decl String:newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		ReplaceString(newTags, sizeof(newTags), ",,", ", ", false);
		SetConVarString(hTags, newTags);
		GetConVarString(hTags, tags, sizeof(tags));
	}
	else if (StrContains(tags, tag, false) > -1 && remove)
	{
		ReplaceString(tags, sizeof(tags), tag, "", false);
		ReplaceString(tags, sizeof(tags), ",,", ", ", false);
		SetConVarString(hTags, tags);
	}
//	CloseHandle(hTags);
}
public cvhook_tags(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!bEnabled) TagsCheck("nocrits");
	else if (GetConVarBool(FindConVar("tf_weapon_criticals"))) TagsCheck("nocrits", true);
}*/
public Action:Cmd_destroy(client, String:cmd[], args)
{
	if (args < 1) return Plugin_Continue;
	if (!IsValidClient(client)) return Plugin_Continue;
	if (TF2_GetPlayerClass(client) == TFClass_Engineer) return Plugin_Continue;
	decl String:arg1[32];
	decl String:arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new building = StringToInt(arg1);
	if (building == 0 && !StrEqual(arg1, "0")) return Plugin_Continue;
	if (building == 3) return Plugin_Continue;
	new TFObjectMode:mode = TFObjectMode_None;
	if (building == _:TFObject_Teleporter && args >= 2)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
		mode = TFObjectMode:StringToInt(arg2);
		if (mode > TFObjectMode_Exit) mode = TFObjectMode_None;
	}
	DestroyClientBuilding(client, TFObjectType:building, mode);
	return Plugin_Continue;
}
//Useless now that m_aBuildableObjectTypes exists
/*public Action:Cmd_build(client, String:cmd[], args)
{
	if (args < 1) return Plugin_Continue;
	if (!IsValidClient(client)) return Plugin_Continue;
	if (TF2_GetPlayerClass(client) == TFClass_Engineer) return Plugin_Continue;
	if (GetIndexOfWeaponSlot(client, 5) != 28) return Plugin_Continue;
	decl String:arg1[32];
	decl String:arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new building = StringToInt(arg1);
	if (building == 3) return Plugin_Handled;
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting)) return Plugin_Continue;
	if (building == 0 && !StrEqual(arg1, "0")) return Plugin_Continue;
	new TFObjectMode:mode = TFObjectMode_None;
	if (building == _:TFObject_Teleporter && args >= 2)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
		mode = TFObjectMode:StringToInt(arg2);
		if (mode > TFObjectMode_Exit) mode = TFObjectMode_None;
	}
	new builder = GetPlayerWeaponSlot(client, 5);
	if (builder > MaxClients && IsValidEntity(builder))
	{
		SetEntProp(builder, Prop_Data, "m_iSubType", building);
		SetEntProp(builder, Prop_Send, "m_iObjectMode", mode);
//		decl String:classname[64];
//		for (new i = 0; i < 48; i++)
//		{
//			new ent = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
//			if (ent > MaxClients && IsValidEntity(ent) && GetEntityClassname(ent, classname, sizeof(classname)) && StrEqual(classname, "tf_weapon_builder", false))
//			{
//
//			}
//		}
	}
//	new TFClassType:class = TF2_GetPlayerClass(client);
//	TF2_SetPlayerClass(client, TFClass_Engineer, _, false);
//	FakeClientCommand(client, "build %d %d", building, _:mode);
//	TF2_SetPlayerClass(client, class, _, false);
	return Plugin_Continue;
}*/
public Action:Cmd_taunt(client, String:cmd[], args)
{
	if (tf2items_giveweapon) return Plugin_Continue;
	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsPlayerAlive(client)) return Plugin_Continue;
	decl String:arg1[32];
	if (args > 0)
	{
		GetCmdArg(1, arg1, sizeof(arg1));
		if (StrEqual(arg1, "AmputatorFix")) return Plugin_Continue;
	}
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class != TFClass_Spy && (TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Disguising))) return Plugin_Handled;
	if (StrContains(cmd, "taunt", false) != -1
		&& (GetEntityFlags(client) & FL_ONGROUND)
		&& !TF2_IsPlayerInCondition(client, TFCond_Taunting)
		&& !TF2_IsPlayerInCondition(client, TFCond_Cloaked)
		&& !TF2_IsPlayerInCondition(client, TFCond_Disguised)
		&& !TF2_IsPlayerInCondition(client, TFCond_Disguising)
		&& class != TFClass_Medic
		&& GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 304
		&& GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))
	{
//		new Handle:pack;
//		CreateDataTimer(0.0, Timer_SetAmpTauntBack, pack, TIMER_FLAG_NO_MAPCHANGE);
//		WritePackCell(pack, GetClientUserId(client));
//		WritePackCell(pack, _:TF2_GetPlayerClass(client));
		TF2_SetPlayerClass(client, TFClass_Medic, _, false);
		FakeClientCommand(client, "taunt AmputatorFix");
		TF2_SetPlayerClass(client, class, _, false);
		if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
		{
			//new bool:healing = TF2_IsPlayerInCondition(client, TFCond_Healing);
			TF2_AddCondition(client, TFCond:55, 4.2);
			CreateTimer(0.05, Timer_RemoveHealing, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/*public Action:Timer_SetAmpTauntBack(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = GetClientOfUserId(ReadPackCell(pack));
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
	new TFClassType:class = TFClassType:ReadPackCell(pack);
	TF2_SetPlayerClass(client, class, _, false);
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		//new bool:healing = TF2_IsPlayerInCondition(client, TFCond_Healing);
		TF2_AddCondition(client, TFCond:55, 4.2);
		CreateTimer(0.05, Timer_RemoveHealing, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Stop;
}*/

public Action:Timer_RemoveHealing(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
	if (!TF2_IsPlayerInCondition(client, TFCond:55) || !TF2_IsPlayerInCondition(client, TFCond_Taunting)) return Plugin_Stop;
	if (GetEntProp(client, Prop_Send, "m_nNumHealers") <= 1) TF2_RemoveCondition(client, TFCond_Healing);
	return Plugin_Continue;
}

stock DestroyClientBuilding(client, TFObjectType:building, TFObjectMode:mode = TFObjectMode_None)
{
	new String:classname[] = "obj_dispenser";
	switch (building)
	{
		case TFObject_Dispenser: classname = "obj_dispenser";
		case TFObject_Teleporter: classname = "obj_teleporter";
		case TFObject_Sentry: classname = "obj_sentrygun";
	}
	new i = -1;
	while ((i = FindEntityByClassname(i, classname)) != -1)
	{
		if (GetEntPropEnt(i, Prop_Send, "m_hBuilder") != client) continue;
		if (building == TFObject_Teleporter && mode != TF2_GetObjectMode(i)) continue;
		if (GetEntProp(i, Prop_Send, "m_bHasSapper")) continue;
		SetVariantInt(GetEntProp(i, Prop_Send, "m_iHealth") + 100);
		AcceptEntityInput(i, "RemoveHealth");
	}
}

public OnPluginEnd()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		ClearHealBeams(client);
		ClearEyeParticle(client);
		if (IsClientInGame(client))
		{
			TF2Attrib_RemoveByName(client, "maxammo metal increased");
			TF2Attrib_RemoveByName(client, "major move speed bonus");
		}
	}
}
public OnLibraryRemoved(const String:name[])
{
#if defined _visweps_included
	if (StrEqual(name, "visweps"))
	{
		bVisWeps = false;
	}
#endif
	if (StrEqual(name, "tf2items_giveweapon"))
	{
		tf2items_giveweapon = false;
	}
#if defined _steamtools_included
	if (StrEqual(name, "SteamTools"))
	{
		steamtools = false;
	}
#endif
	if (bCvarDebug) LogMessage("Library %s removed from Randomizer", name);
}

public OnLibraryAdded(const String:name[])
{
#if defined _visweps_included
	if (StrEqual(name, "visweps"))
	{
		bVisWeps = true;
	}
#endif
	if (StrEqual(name, "tf2items_giveweapon"))
	{
		tf2items_giveweapon = true;
	}
#if defined _steamtools_included
	if (StrEqual(name, "SteamTools"))
	{
		steamtools = true;
	}
#endif
	if (bCvarDebug) LogMessage("Library %s added for Randomizer", name);
}
public OnClientPutInServer(client)
{
	SetRandomization(client);
	for (new i = 0; i < MaxCooldowns; i++)
	{
		bCooldowns[client][i] = false;
	}
/*	pReloadCooldown[client] = false;
	pBonkCooldown[client] = false;
	pEatCooldown[client] = false;
	pLongEatCooldown[client] = false;
	pJarCooldown[client] = false;
	pBallCooldown[client] = false;*/
	bDalokohsBuff[client] = false;
	bJarated[client] = false;
	bDoubleJumped[client] = false;
	bUbered[client] = false;
	bDontRespawn[client] = false;
//	bTeleOnSpawn[client] = 0;
	bHasAnnounce[client] = false;
	ClearHealBeams(client);
	ClearEyeParticle(client);
/*	BonkCooldownTimer[client] = INVALID_HANDLE;
	EatCooldownTimer[client] = INVALID_HANDLE;
	DalokohsBuffTimer[client] = INVALID_HANDLE;
	JarCooldownTimer[client] = INVALID_HANDLE;
	BallCooldownTimer[client] = INVALID_HANDLE;*/
}

public OnClientDisconnect_Post(client)
{
	for (new i = 0; i < MaxCooldowns; i++)
	{
		bCooldowns[client][i] = false;
	}
/*	pReloadCooldown[client] = false;
	pBonkCooldown[client] = false;
	pEatCooldown[client] = false;
	pLongEatCooldown[client] = false;
	pJarCooldown[client] = false;
	pBallCooldown[client] = false;*/
	bDalokohsBuff[client] = false;
	bJarated[client] = false;
	bUbered[client] = false;
	bDontRespawn[client] = false;
//	bTeleOnSpawn[client] = 0;
	bHasAnnounce[client] = false;
	iDefClass[client] = TFClass_Unknown;
	for (new i = 0; i < MaxTimers; i++)
	{
		hTimers[client][i] = INVALID_HANDLE;
	}
	hTimerAnnounce[client] = INVALID_HANDLE;
/*	BonkCooldownTimer[client] = INVALID_HANDLE;
	EatCooldownTimer[client] = INVALID_HANDLE;
	DalokohsBuffTimer[client] = INVALID_HANDLE;
	JarCooldownTimer[client] = INVALID_HANDLE;
	BallCooldownTimer[client] = INVALID_HANDLE;
	pChargeTiming[client] = INVALID_HANDLE;*/
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (tf2items_giveweapon) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) return;
	new weapon = GetEventInt(event, "weaponid");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage = GetEventInt(event, "damageamount");
	new custom = GetEventInt(event, "custom");
	if (weapon == TF_WEAPON_SNIPERRIFLE && TF2_IsPlayerInCondition(client, TFCond_Jarated))
	{
		bJarated[client] = true;
	}
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (attacker == client)
	{
		if (!IsPlayerAlive(client)) return;
		if (class == TFClass_Soldier || class == TFClass_DemoMan) return;
		new jumpstate = 1;
		new bool:playsound = false;
		if (weapon == TF_WEAPON_ROCKETLAUNCHER && GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary) == 237)
		{
			playsound = true;
		}
		if (weapon == TF_WEAPON_PIPEBOMBLAUNCHER)
		{
			jumpstate = 2;
		}
		if (custom == TF_CUSTOM_PRACTICE_STICKY)
		{
			jumpstate = 2;
			playsound = true;
		}
		SetBlastJumpState(client, jumpstate, playsound);
		return;
	}
	new buffclient = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);
/*	if (IsValidClient(attacker) && IsPlayerAlive(client) && class != TFClass_Soldier && (buffclient == 226 || buffclient == 354) && !GetEntProp(client, Prop_Send, "m_bRageDraining"))
	{
		new Float:rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
		if (buffclient == 354) rage += (damage / 3.33);
		else rage += (damage / 3.50);
		if (rage > 100.0) rage = 100.0;
		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", rage);
	}*/
//	if (IsValidClient(attacker) && IsPlayerAlive(client) && class != TFClass_Soldier && buffclient == 226 && !GetEntProp(client, Prop_Send, "m_bRageDraining"))
//	{
//		new Float:rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
//		rage += (damage / 3.50);
//		if (rage > 100.0) rage = 100.0;
//		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", rage);
//	}
	if (!IsValidClient(attacker)) return;
	if (!IsPlayerAlive(attacker)) return;
	if (weapon == TF_WEAPON_MINIGUN && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary) == 15 && GetEntProp(GetPlayerWeaponSlot(attacker, TFWeaponSlot_Primary), Prop_Send, "m_iEntityLevel") == (-128+5) && (GetClientButtons(attacker) & (IN_ATTACK|IN_ATTACK2)) == IN_ATTACK2)
	{
		new health = GetClientHealth(attacker);
		if (health < TF2_GetMaxHealth(attacker))
		{
			health += 3;
			TF2_SetHealth(attacker, health);
		}
		new Handle:healevent = CreateEvent("player_healonhit", true);
		SetEventInt(healevent, "entindex", attacker);
		SetEventInt(healevent, "amount", 3);
		FireEvent(healevent);
	}
	new TFClassType:attackerclass = TF2_GetPlayerClass(attacker);
	if (weapon == TF_WEAPON_BONESAW && attackerclass != TFClass_Medic && !TF2_IsPlayerInCondition(client, TFCond_Disguised) && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee) == 37)
	{
		decl String:secondary[64];
		new sec = GetPlayerWeaponSlot(attacker, TFWeaponSlot_Secondary);
		if (sec > MaxClients && IsValidEntity(sec) && GetEntityClassname(sec, secondary, sizeof(secondary)) && StrEqual(secondary, "tf_weapon_medigun", false))
		{
			new Float:charge = GetEntPropFloat(sec, Prop_Send, "m_flChargeLevel");
			charge += 0.25;
			if (charge > 1.0) charge = 1.0;
			SetEntPropFloat(sec, Prop_Send, "m_flChargeLevel", charge);
		}
	}
	if (GetEntProp(attacker, Prop_Send, "m_bRageDraining")) return;
	if ((custom == TF_CUSTOM_BURNING || custom == TF_CUSTOM_BURNING_FLARE) && attackerclass != TFClass_Pyro && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary) == 594 && GetEntPropFloat(attacker, Prop_Send, "m_flNextRageEarnTime") <= GetGameTime())
	{
		new Float:rage = GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
		rage += (damage / 2.25);
		if (rage > 100.0) rage = 100.0;
		SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", rage);
	}
	buffclient = GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Secondary);
	if (attackerclass != TFClass_Soldier && (buffclient == 129 || buffclient == 226 || buffclient == 354))
	{
		if (custom == TF_CUSTOM_BURNING && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary) == 594) return;
		new Float:rage = GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
		if (buffclient == 354) rage += (damage / 4.80);
		else rage += (damage / 6.0);
		if (rage > 100.0) rage = 100.0;
		SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", rage);
	}
}

stock SetBlastJumpState(client, jumpstate, bool:playsound)
{
	new offs = FindSendPropInfo("CTFPlayer", "m_iSpawnCounter") + 12;
	if (offs == 11 || offs == 12) return;
	SetEntData(client, offs, GetEntData(client, offs) | jumpstate);
	if (jumpstate == 1 || jumpstate == 2)
	{
		new Handle:event = CreateEvent(jumpstate == 2 ? "sticky_jump" : "rocket_jump", true);
		SetEventInt(event, "userid", GetClientUserId(client));
		SetEventBool(event, "playsound", playsound);
		FireEvent(event);
	}
}

public Action:Event_PlayerJaratedFade(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	if (tf2items_giveweapon) return;
	BfReadByte(bf); //client
	new victim = BfReadByte(bf);
	bJarated[victim] = false;
}
public Action:Event_PlayerJarated(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	if (tf2items_giveweapon) return;
	new client = BfReadByte(bf);
	new victim = BfReadByte(bf);
	new jar = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	new Address:attrib = Address_Null;
	if (jar != -1 && GetEntProp(jar, Prop_Send, "m_iItemDefinitionIndex") == 58 && (attrib = TF2Attrib_GetByName(jar, "bleeding duration")) != Address_Null)
	{
		if (TF2Attrib_GetByName(jar, "jarate description") == Address_Null && !bJarated[victim])
			CreateTimer(0.0, Timer_NoPiss, GetClientUserId(victim));	//TF2_RemoveCondition(victim, TFCond_Jarated);
		TF2_MakeBleed(victim, client, TF2Attrib_GetValue(attrib));
	}
	else bJarated[victim] = true;
	return;
}
public Action:Timer_NoPiss(Handle:timer, any:userid)
{
	new victim = GetClientOfUserId(userid);
	if (IsValidClient(victim)) TF2_RemoveCondition(victim, TFCond_Jarated);
}
//public Roundstart(Handle:event, const String:name[], bool:dontBroadcast)
//{
//	RoundStarted = true;
//}
//public Roundactive(Handle:event, const String:name[], bool:dontBroadcast)
//{
//	RoundStarted = false;
//}

public cvhook_enabled(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	bCvarEnabled = GetConVarBool(cvar);
	if (bCvarEnabled)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			SetRandomization(i);
			if (IsClientInGame(i) && IsPlayerAlive(i)) TF2_RespawnPlayer(i);
		}
		PrintToChatAll("[TF2Items]Randomizer Enabled!");
#if defined _steamtools_included
		if (steamtools && bCvarGameDesc)
		{
			decl String:gameDesc[64];
			Format(gameDesc, sizeof(gameDesc), "[TF2Items]Randomizer v%s", PLUGIN_VERSION);
			Steam_SetGameDescription(gameDesc);
		}
#endif
	}
	else
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				TF2Attrib_RemoveByName(i, "maxammo metal increased");
				TF2Attrib_RemoveByName(i, "major move speed bonus");
				if (IsPlayerAlive(i)) TF2_RespawnPlayer(i);
			}
		}
		PrintToChatAll("[TF2Items]Randomizer Disabled!");
#if defined _steamtools_included
		if (steamtools && bCvarGameDesc)
		{
			Steam_SetGameDescription("Team Fortress");
		}
#endif
	}
}

public cvhook_announce(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarAnnounce = GetConVarBool(cvar); }
public cvhook_partial(Handle:cvar, const String:oldVal[], const String:newVal[]) { iCvarPartial	=	GetConVarInt(cvar); }
public cvhook_destroy(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarDestroy	=	GetConVarBool(cvar); }
//public cvhook_fixammo(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_fixammo = GetConVarBool(cvar); }
//public cvhook_fixpyro(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_fixpyro = GetConVarBool(cvar); }
public cvhook_fixspy (Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarFixSpy	=	GetConVarBool(cvar); }
public cvhook_fixuber(Handle:cvar, const String:oldVal[], const String:newVal[]) { iCvarFixUber	=	GetConVarInt(cvar); }
public cvhook_betaweapons(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarBetaWeapons = GetConVarBool(cvar); }
public cvhook_customweapons(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarCustomWeapons = GetConVarBool(cvar); }
//public cvhook_fixreload(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_fixreload = GetConVarBool(cvar); }
public cvhook_goldenwrench(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarGoldenWrench = GetConVarBool(cvar); }
public cvhook_fixfood(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarFixFood = GetConVarBool(cvar); }
#if defined _steamtools_included
public cvhook_gamedesc(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarGameDesc = GetConVarBool(cvar); }
#endif
//public cvhook_manifix(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_manifix = GetConVarBool(cvar); }
public cvhook_spycloak(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarSpyCloak = GetConVarBool(cvar); }

public cvhook_debug(Handle:cvar, const String:oldVal[], const String:newVal[]) { bCvarDebug = GetConVarBool(cvar); }

SetRandomization(client)
{
	iRndClass[client] = TFClassType:mt_rand(1, 9); //GetRandomInt(1, 9);
	if (bCvarEnabled && IsValidClient(client)) SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", iRndClass[client]);	//This may or may not be good.
	iRndWeapon[client][0] = -2;
}

public OnClientDisconnect(client)
{
	ClearHealBeams(client);
	ClearEyeParticle(client);

	for (new i = 0; i < MaxTimers; i++)
	{
		ClearTimer(hTimers[client][i]);
	}
	ClearTimer(hTimerAnnounce[client]);
/*	if (BonkCooldownTimer[client] != INVALID_HANDLE)
	{
		KillTimer(BonkCooldownTimer[client]);
		BonkCooldownTimer[client] = INVALID_HANDLE;
	}
	if (EatCooldownTimer[client] != INVALID_HANDLE)
	{
		KillTimer(EatCooldownTimer[client]);
		EatCooldownTimer[client] = INVALID_HANDLE;
	}
	if (DalokohsBuffTimer[client] != INVALID_HANDLE)
	{
		KillTimer(DalokohsBuffTimer[client]);
		DalokohsBuffTimer[client] = INVALID_HANDLE;
	}
	if (JarCooldownTimer[client] != INVALID_HANDLE)
	{
		KillTimer(JarCooldownTimer[client]);
		JarCooldownTimer[client] = INVALID_HANDLE;
	}
	if (BallCooldownTimer[client] != INVALID_HANDLE)
	{
		KillTimer(BallCooldownTimer[client]);
		BallCooldownTimer[client] = INVALID_HANDLE;
	}
	if (pChargeTiming[client] != INVALID_HANDLE)
	{
		KillTimer(pChargeTiming[client]);
		pChargeTiming[client] = INVALID_HANDLE;
	}*/
}

public OnMapStart()
{
//	g_bMapLoaded = true;
	for (new i = 1; i <= MaxClients; i++) if (IsClientInGame(i)) OnClientPutInServer(i);
//	CreateTimer(0.1, timer_checkammos, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	PrecacheSound("player/invulnerable_off.wav", true);
	PrecacheSound("player/invulnerable_on.wav", true);
	PrecacheSound("weapons/weapon_crit_charged_on.wav", true);
	PrecacheSound("weapons/weapon_crit_charged_off.wav", true);
	PrecacheSound("vo/SandwichEat09.wav", true);
	PrecacheSound("player/recharged.wav", true);
	PrecacheSound("player/pl_scout_dodge_can_drink.wav", true);
	PrecacheSound("vo/pyro_laughhappy01.wav", true);
	PrecacheSound("vo/pyro_paincrticialdeath01.wav", true);
	PrecacheSound("vo/pyro_paincrticialdeath03.wav", true);
	PrecacheSound("weapons/drg_wrench_teleport.wav", true);
	PrecacheSound("weapons/teleporter_send.wav", true);
	if (FileExists("models/buildables/toolbox_placement_sentry1.mdl", true)) PrecacheModel("models/buildables/toolbox_placement_sentry1.mdl", true);
	if (FileExists("models/buildables/toolbox_placement.mdl", true)) PrecacheModel("models/buildables/toolbox_placement.mdl", true);
	if (FileExists("models/buildables/toolbox_placed.mdl", true)) PrecacheModel("models/buildables/toolbox_placed.mdl", true);
	PrepareAllModels();
//	new String:mapname[64];
//	GetCurrentMap(mapname, sizeof(mapname));
	bCvarEnabled = GetConVarBool(FindConVar("tf2items_rnd_enabled"));
//	if (strncmp(mapname, "zf_", 3, false) == 0) ServerCommand("tf2items_rnd_enabled 0");
	IsMedieval(true);
}

/*public OnMapEnd()
{
//	g_bMapLoaded = false;
}*/

stock IsMedieval(bool:bForceRecalc = false)
{
	static found = false;
	static bIsMedieval = false;
	if (bForceRecalc)
	{
		found = false;
		bIsMedieval = false;
	}
	if (!found)
	{
		found = true;
		if (FindEntityByClassname(-1, "tf_logic_medieval") != -1) bIsMedieval = true;
	}
	return bIsMedieval;
}
public Action:Command_EnableRnd(client, args)
{
	new String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
//	if (strncmp(mapname, "zf_", 3, false) == 0) ReplyToCommand(client, "[TF2Items] Randomizer is disabled on Zombie Fortress, though it should now work. Wait for an update.");
//	else
	if (bCvarEnabled) ReplyToCommand(client, "[TF2Items]Randomizer is already enabled!");
	else if (!bCvarEnabled)
	{
		ServerCommand("tf2items_rnd_enabled 1");
		ReplyToCommand(client, "[TF2Items] Enabled Randomizer");
	}
	return Plugin_Handled;
}
public Action:Command_DisableRnd(client, args)
{
	if (!bCvarEnabled) ReplyToCommand(client, "[TF2Items]Randomizer is already disabled!");
	else if (bCvarEnabled)
	{
		ServerCommand("tf2items_rnd_enabled 0");
		ReplyToCommand(client, "[TF2Items] Disabled Randomizer");
	}
	return Plugin_Handled;
}
public Action:Timer_Announce(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (bCvarEnabled && bCvarAnnounce && IsValidClient(client) && !bHasAnnounce[client])
	{
		PrintToChat(client, "\x01\x0700FF59[TF2Items]Randomizer\x01 v%s by FlaminSarge", PLUGIN_VERSION);
		PrintToChat(client, "--Random class, random weapons. You only reroll if killed by an enemy.");
		PrintToChat(client, "\x01--Type \x0700FF59/myweps\x01 in chat to list your weapons and see the details of any custom weapons.");
		bHasAnnounce[client] = true;
	}
	hTimerAnnounce[client] = INVALID_HANDLE;
	return Plugin_Stop;
}
public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Error-checking
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) return;
	if (!IsPlayerAlive(client)) return;

//	flBabyFaceSpeed[client] = -1.0;
	for (new i = 0; i < MaxCooldowns; i++)
	{
		if (i == ReloadCooldown) continue;
		bCooldowns[client][i] = false;
	}
/*	pBonkCooldown[client] = false;
	pEatCooldown[client] = false;
	pLongEatCooldown[client] = false;
	pJarCooldown[client] = false;
	pBallCooldown[client] = false;*/
	bDalokohsBuff[client] = false;
	bJarated[client] = false;
	bUbered[client] = false;
	ClearEyeParticle(client);

	if (bCvarEnabled && !bHasAnnounce[client] && !IsFakeClient(client))
	{
		hTimerAnnounce[client] = CreateTimer(4.0, Timer_Announce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	new TFClassType:cur = TF2_GetPlayerClass(client);
	if (cur == TFClass_Unknown) return;
	// Randomize if necessary.
	if (!bCvarEnabled)
	{
//		iRndClass[client] = cur;
		iRndWeapon[client] = { 0, 0, 0 };
	}
	else if (iRndWeapon[client][0] == -2)
	{
		if (iCvarPartial > 0 && mt_rand(1, 100) <= iCvarPartial) iRndWeapon[client][0] = 0;	//GetRandomInt now mt_rand
		else iRndWeapon[client][0] = mt_rand(iCvarPartial == -1 ? 1 : 0, sizeof(iWeaponPrimary) - 1);

		if (iCvarPartial > 0 && mt_rand(1, 100) <= iCvarPartial) iRndWeapon[client][1] = 0;
		else iRndWeapon[client][1] = mt_rand(iCvarPartial == -1 ? 1 : 0, sizeof(iWeaponSecondary) - 1);

		if (iCvarPartial > 0 && mt_rand(1, 100) <= iCvarPartial) iRndWeapon[client][2] = 0;
		else iRndWeapon[client][2] = mt_rand(iCvarPartial == -1 ? 1 : 0, sizeof(iWeaponMelee) - 1);

		if (bCvarSpyCloak && iRndClass[client] == TFClass_Spy)
		{
			if (iCvarPartial > 0 && mt_rand(1, 100) <= iCvarPartial) iRndCloak[client] = 0;
			else
			{
				iRndCloak[client] = mt_rand(iCvarPartial == -1 ? 1 : 0, sizeof(iWeaponCloakary) - 3);
				if (iRndCloak[client] == 1)
				{
					new invis = mt_rand(0, 2);
					if (invis > 0) iRndCloak[client] = invis + 3;
				}
			}
		} else iRndCloak[client] = -1;

		if (!bCvarBetaWeapons)
		{
			if (iRndWeapon[client][0] == 18) iRndWeapon[client][0] = 11;
//			if (iRndWeapon[client][0] == 32) iRndWeapon[client][0] = 4;
//			if (iRndWeapon[client][1] == 26) iRndWeapon[client][1] = 5;
//			if (iRndWeapon[client][1] == 27) iRndWeapon[client][1] = 3;
		}
		if (!bCvarCustomWeapons)
		{
			if (iRndWeapon[client][0] == 19) iRndWeapon[client][0] = 16;
			if (iRndWeapon[client][0] == 26) iRndWeapon[client][0] = 21;
			if (iRndWeapon[client][2] == 26) iRndWeapon[client][2] = 3;
			if (iRndWeapon[client][2] == 27) iRndWeapon[client][2] = 16;
			if (iRndWeapon[client][2] == 37) iRndWeapon[client][2] = 6;
			if (iRndWeapon[client][1] == 24) iRndWeapon[client][1] = 8;
		}
		if (!bCvarGoldenWrench)
		{
			if (iRndWeapon[client][2] == 24) iRndWeapon[client][2] = 6;
			if (iRndWeapon[client][2] == 25) iRndWeapon[client][2] = 12;
//			if (iRndWeapon[client][2] == 37) iRndWeapon[client][2] = 6;
			if (iRndWeapon[client][2] == 50) iRndWeapon[client][2] = 0;
		}
		if (IsMedieval())
		{
			if (iRndWeapon[client][0] != 0 && iRndWeapon[client][0] != 13 && iRndWeapon[client][0] != 29) iRndWeapon[client][0] = 0;
			switch (iRndWeapon[client][1])
			{
				case 0, 6, 7, 11, 12, 13, 14, 15, 17, 20, 21, 22, 23, 24, 28, 29, 32: {}
				default: iRndWeapon[client][1] = 0;
			}
		}
		if (IsFakeClient(client))
		{
			if (iRndWeapon[client][0] == 26) iRndWeapon[client][0] = 0;
			switch (iRndWeapon[client][1])
			{
				case 0, 6, 7, 11, 12, 17, 28: iRndWeapon[client][1] = 0;
				case 42, 43:
				{
					//if (TF2_GetPlayerClass(client) == TFClass_Engineer)
					iRndWeapon[client][1] = 0;	//bots crash sappers
				}
			}
		}
		if (iRndWeapon[client][0] == 24 && iRndWeapon[client][1] == 16) iRndWeapon[client][0] = 5;
//		if (cur != TFClass_Heavy && iRndWeapon[client][1] == 17) iRndWeapon[client][1] = 6;
	}
	// Check class and weapons.
	if (bCvarEnabled && cur != iRndClass[client])
	{
		if (bCvarDestroy && cur == TFClass_Engineer)
		{
			decl String:classname[32];
			static MaxEntities = 0;
			if (!MaxEntities) MaxEntities = GetMaxEntities();
			for (new i = MaxClients + 1; i <= MaxEntities; i++)
			{
				if (IsValidEdict(i))
				{
					GetEdictClassname(i, classname, sizeof(classname));
					if (StrEqual(classname, "obj_dispenser")
					|| StrEqual(classname, "obj_sentrygun")
					|| StrEqual(classname, "obj_teleporter"))
//					|| StrEqual(classname, "obj_teleporter_exit"))
					{
						if (GetEntPropEnt(i, Prop_Send, "m_hBuilder") == client)
						{
							SetVariantInt(9001);
							AcceptEntityInput(i, "RemoveHealth");
						}
					}
				}
			}
		}
/*		if (bTeleOnSpawn[client])	//Are we respawning a client who is the wrong class? If so, use their saved position.
		{
			if (bTeleOnSpawn[client] == 2) bTeleOnSpawn[client] = 0;
			else bTeleOnSpawn[client]++;
			TeleportEntity(client, vecTeleOnSpawnOrigin[client], vecTeleOnSpawnAngles[client], NULL_VECTOR);
			vecTeleOnSpawnOrigin[client] = NULL_VECTOR;
			vecTeleOnSpawnAngles[client] = NULL_VECTOR;
		}*/
//		TF2_SetPlayerClass(client, iRndClass[client], false, true);
		if (!bDontRespawn[client])
		{
			bDontRespawn[client] = true;

/*			bTeleOnSpawn[client] = 1;
			GetClientAbsOrigin(client, vecTeleOnSpawnOrigin[client]);
			GetClientAbsAngles(client, vecTeleOnSpawnAngles[client]);*/

			TF2_SetPlayerClass(client, iRndClass[client], false, true);
			if (IsPlayerAlive(client)) CreateTimer(0.0, Timer_Respawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE); //TF2_RespawnPlayer(client);
			CreateTimer(0.3, Timer_DontRespawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
//		CreateTimer(0.0, Timer_RegeneratePlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	iDefClass[client] = TF2_GetPlayerClass(client);
/*	if (!tf2items_giveweapon && iDefClass[client] != TFClass_Soldier && iDefClass[client] != TFClass_Pyro)
	{
		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 0.0);
		SetEntProp(client, Prop_Send, "m_bRageDraining", 0);
	}*/
//	else
//	{
//		spy_status[client] = (cur == TFClass_Spy);
//		GiveRndWeapons(client);	//already in the locker weapon reset
//		ammo_count[client][0] = 1000;
//		ammo_count[client][1] = 1000;
//	}
}
public Action:Timer_Respawn(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		TF2_RespawnPlayer(client);
/*		if (bTeleOnSpawn[client])	//Are we respawning a client who is the wrong class? If so, use their saved position.
		{
			if (bTeleOnSpawn[client] == 2) bTeleOnSpawn[client] = 0;
			else bTeleOnSpawn[client]++;
			TeleportEntity(client, vecTeleOnSpawnOrigin[client], vecTeleOnSpawnAngles[client], NULL_VECTOR);
			vecTeleOnSpawnOrigin[client] = NULL_VECTOR;
			vecTeleOnSpawnAngles[client] = NULL_VECTOR;
		}*/
	}
}
public Action:Timer_RegeneratePlayer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client))
		TF2_RegeneratePlayer(client);
}
public Action:Timer_DontRespawn(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client >= 0 && client <= MaxClients)
	{
		bDontRespawn[client] = false;
	}
}
public Event_PostInventoryApplication(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client) && TF2_GetPlayerClass(client) != TFClass_Sniper)
	{
		if (TF2_IsPlayerInCondition(client, TFCond_Zoomed)) TF2_RemoveCondition(client, TFCond_Zoomed);
//		if (TF2_IsPlayerInCondition(client, TFCond_Slowed)) TF2_RemoveCondition(client, TFCond_Slowed);
	}
/*	if (IsValidClient(client))
	{
		for (new i = 0; i <= MeleeHud; i++)
		{
			ClearSyncHud(client, hHuds[i]);
			flSavedInfo[client][i] = -1.0;
		}
	}*/
	CreateTimer(0.05, Timer_LockerWeaponReset, any:GetEventInt(event, "userid"));
	for (new i = 0; i < MaxTimers; i++)
	{
		if (i == DalokohsTimer) continue;
		if (hTimers[client][i] != INVALID_HANDLE) TriggerTimer(hTimers[client][i]);
		ClearTimer(hTimers[client][i]);
	}
/*	if (BonkCooldownTimer[client] != INVALID_HANDLE)
	{
		TriggerTimer(BonkCooldownTimer[client]);
		BonkCooldownTimer[client] = INVALID_HANDLE;
	}
	if (EatCooldownTimer[client] != INVALID_HANDLE)
	{
		TriggerTimer(EatCooldownTimer[client]);
		EatCooldownTimer[client] = INVALID_HANDLE;
	}
	if (JarCooldownTimer[client] != INVALID_HANDLE)
	{
		TriggerTimer(JarCooldownTimer[client]);
		JarCooldownTimer[client] = INVALID_HANDLE;
	}
	if (BallCooldownTimer[client] != INVALID_HANDLE)
	{
		TriggerTimer(BallCooldownTimer[client]);
		BallCooldownTimer[client] = INVALID_HANDLE;
	}
	if (pChargeTiming[client] != INVALID_HANDLE)
	{
		KillTimer(pChargeTiming[client]);
		pChargeTiming[client] = INVALID_HANDLE;
	}*/
}

public Action:Timer_LockerWeaponReset(Handle:timer, any:userid)
{
	if (bCvarEnabled)
	{
		new client = GetClientOfUserId(userid);
		if (IsValidClient(client))
		{
			GiveRndWeapons(client);
			CreateTimer(0.1, Timer_CheckHealth, any:userid);
			/*if (IsFakeClient(client))
			{
				if (pLockerTouchCount[client] < 4) pLockerTouchCount[client]++;
				else
				{
					ServerCommand("sm_reroll #%d", GetClientUserId(client));
					pLockerTouchCount[client] = 0;
				}
			}*/
		}
	}
}

/*public Action:timer_checkammos(Handle:timer)
{
	if (bCvarEnabled && cvar_fixreload)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				new weapon = GetPlayerWeaponSlot(i, 0);
				if (IsValidEntity(weapon))
				{
					new newammo;
					new idx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
					new TFClassType:class = TF2_GetPlayerClass(i);
					if ((newammo = GetSpeshulAmmo(i, 0)) < pOldAmmo[i] && (((idx == 36 || idx == 412) && class != TFClass_Medic) || (class != TFClass_Spy && (idx == 224 || idx == 61 || idx == 161 || idx == 460 || idx == 525)) || (class != TFClass_Scout && (idx == 45 || idx == 220 || idx == 448))))
					{
						pOldAmmo[i] = newammo;
//						pReloadCooldown[i] = true;
						SetNextAttack(weapon, ((idx == 448) ? 0.7 : 1.0));
//						CreateTimer(((idx == 448) ? 0.7 : 1.0), Reload_Cooldown, i);
					}
					else pOldAmmo[i] = GetSpeshulAmmo(i, 0);
				}
			}
		}
	}
}*/
stock SetNextAttack(weapon, Float:duration = 0.0)
{
	if (!IsValidEntity(weapon)) return;
	new Float:next = GetGameTime() + duration;
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", next);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", next);
}
public Action:Timer_CheckHealth(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client))
	{
		new max = TF2_GetMaxHealth(client);
		if (iRndWeapon[client][0] == 24 || iRndWeapon[client][1] == 16) TF2_SetHealth(client, RoundToFloor(max * 1.5 < 350 ? 350.0 : max * 1.5));
		else
		{
			if (GetClientHealth(client) > RoundToFloor(1.5 * max)) TF2_SetHealth(client, RoundToFloor(1.5 * max));
			else if (GetClientHealth(client) < max) TF2_SetHealth(client, max);
		}
	//	TF2_SetMaxHealth(client, max);
	}
}
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new deathflags = GetEventInt(event, "death_flags");
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new assister = GetClientOfUserId(GetEventInt(event, "assister"));
	new custom = GetEventInt(event, "customkill");
	new weaponid = GetEventInt(event, "weaponid");
	new inflictor = GetEventInt(event, "inflictor_entindex");
	decl String:weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	if (!tf2items_giveweapon)
	{
		if (weaponid == TF_WEAPON_WRENCH && IsValidClient(inflictor))
		{
			new weaponent = GetEntPropEnt(inflictor, Prop_Send, "m_hActiveWeapon");
			if (weaponent > -1 && GetEntProp(weaponent, Prop_Send, "m_iItemDefinitionIndex") == 197 && GetEntProp(weaponent, Prop_Send, "m_iEntityLevel") == (-128+13)) //Checking if it's a Rebel's Curse
			{
				CreateTimer(0.1, Timer_DissolveRagdoll, userid);
	/*			PrintToChatAll("weaponid is 197 with -115, active");
				new ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
				PrintToChatAll("trying to dissolve %d", ragdoll);
				if (ragdoll != -1)
				{
					DissolveRagdoll(ragdoll);
					PrintToChatAll("dissolving");
				}*/
			}
		}

		if (custom == TF_CUSTOM_DECAPITATION && weaponid == TF_WEAPON_SWORD && IsValidClient(attacker) && IsPlayerAlive(attacker) && TF2_GetPlayerClass(attacker) != TFClass_DemoMan && !StrEqual(weapon, "demokatana"))
		{
			new mel = GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee);
			new Address:attrib = TF2Attrib_GetByName(mel, "decapitate type");
			if (attrib != Address_Null && TF2Attrib_GetValue(attrib) == 1.0) AddDecapitation(attacker, client);
//			if (StrEqual(weapon, "sword", false) || StrEqual(weapon, "nessieclub", false) || StrEqual(weapon, "headtaker", false)) AddDecapitation(attacker, client);
		}
		if (!(deathflags & TF_DEATHFLAG_DEADRINGER) && weaponid == TF_WEAPON_KNIFE && custom == TF_CUSTOM_BACKSTAB && IsValidClient(attacker) && IsPlayerAlive(attacker) && TF2_GetPlayerClass(attacker) != TFClass_Spy)
		{
			new mel = GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee);
			new Address:attrib = TF2Attrib_GetByName(mel, "disguise on backstab");
			if (attrib != Address_Null && TF2Attrib_GetValue(attrib) == 1.0) InstantDisguise(attacker, client);
//			if (StrEqual(weapon, "eternal_reward", false) || StrEqual(weapon, "voodoo_pin", false)) InstantDisguise(attacker, client);
		}
		if (IsValidClient(assister) && IsPlayerAlive(assister) && GetIndexOfWeaponSlot(assister, TFWeaponSlot_Primary) == 752 && TF2_GetPlayerClass(assister) != TFClass_Sniper)
		{
			new Float:rage = GetEntPropFloat(assister, Prop_Send, "m_flRageMeter");
			rage += 15.0;
			if (rage > 100.0) rage = 100.0;
			SetEntPropFloat(assister, Prop_Send, "m_flRageMeter", rage);
		}
		if (IsValidClient(attacker) && IsPlayerAlive(attacker) && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary) == 752 && TF2_GetPlayerClass(attacker) != TFClass_Sniper)
		{
			new Float:rage = GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
			rage += 35.0;
			if (rage > 100.0) rage = 100.0;
			SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", rage);
		}
	}
	if (!(deathflags & TF_DEATHFLAG_DEADRINGER))
	{
		decl String:weaponlog[64];
		GetEventString(event, "weapon_logclassname", weaponlog, sizeof(weaponlog));
		if (((attacker && attacker != client) || custom == TF_CUSTOM_DECAPITATION_BOSS || (custom >= 58 && custom <= 60) || (strcmp(weaponlog, "eyeball_rocket", false) == 0)) && bCvarEnabled) SetRandomization(client);
		for (new i = 0; i < MaxTimers; i++)
		{
			ClearTimer(hTimers[client][i]);
		}
		ClearHealBeams(client);
		ClearEyeParticle(client);
	}
	return Plugin_Continue;
}

public Action:Timer_DissolveRagdoll(Handle:timer, any:userid)
{
	new victim = GetClientOfUserId(userid);
	new ragdoll = (IsValidClient(victim) ? GetEntPropEnt(victim, Prop_Send, "m_hRagdoll") : -1);
	if (IsValidEntity(ragdoll))
	{
		DissolveRagdoll(ragdoll);
	}
}

stock DissolveRagdoll(ragdoll)
{
	new dissolver = CreateEntityByName("env_entity_dissolver");

	if (!IsValidEntity(dissolver))
	{
		return;
	}

	DispatchKeyValue(dissolver, "dissolvetype", "0");
	DispatchKeyValue(dissolver, "magnitude", "200");
	DispatchKeyValue(dissolver, "target", "!activator");

	AcceptEntityInput(dissolver, "Dissolve", ragdoll);
	AcceptEntityInput(dissolver, "Kill");
//	PrintToChatAll("dissolving2");

	return;
}

stock AddDecapitation(client, victim)
{
	new heads = GetEntProp(client, Prop_Send, "m_iDecapitations") + 1;
	if (IsValidClient(victim)) heads += GetEntProp(victim, Prop_Send, "m_iDecapitations");
	SetEntProp(client, Prop_Send, "m_iDecapitations", heads);
	if (!TF2_IsPlayerInCondition(client, TFCond_DemoBuff))
	{
		TF2_AddCondition(client, TFCond_DemoBuff, -1.0);
	}
	ChangeEyeParticle(client);
}

stock InstantDisguise(client, victim)
{
	new TFClassType:class = TF2_GetPlayerClass(client);
	TF2_SetPlayerClass(client, TFClass_Spy, _, false);
	new TFTeam:team = TFTeam:GetClientTeam(victim);
	if (team != TFTeam_Red && team != TFTeam_Blue) team = ((GetClientTeam(client) == _:TFTeam_Red) ? (TFTeam_Blue) : (TFTeam_Red));
	TF2_DisguisePlayer(client, team, TF2_GetPlayerClass(victim), victim);
	TF2_SetPlayerClass(client, class, _, false);
/*	TF2_AddCondition(client, TFCond_Disguised, -1.0);
	SetEntProp(client, Prop_Send, "m_nDisguiseTeam", GetClientTeam(victim));
	SetEntProp(client, Prop_Send, "m_nDisguiseClass", _:TF2_GetPlayerClass(victim));
	SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", victim);
	SetEntProp(client, Prop_Send, "m_iDisguiseHealth", TF2_GetMaxHealth(victim));*/
//	SetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon", CreateDisguiseWeapon(victim));
//	SetEntProp(client, Prop_Send, "m_iDisguiseBody", GetEntProp(victim, Prop_Send, "m_nBody"));
}

stock CreateDisguiseWeapon(client)
{
	decl String:formatBuffer[32], String:weaponClassname[64];
	new pri = iRndWeapon[client][0];
	if (pri < 0) pri = 0;
	new idx = iWeaponPrimary[pri];
	Format(formatBuffer, sizeof(formatBuffer), "%d_%s", idx, "classname");
	if (!GetTrieString(hItemInfoTrie, formatBuffer, weaponClassname, sizeof(weaponClassname)) || strncmp(weaponClassname, "tf_wearable", 11, false) == 0)
	{
		idx = GetDefaultWeaponIndex(TF2_GetPlayerClass(client), TFWeaponSlot_Primary);
		Format(formatBuffer, sizeof(formatBuffer), "%d_%s", idx, "classname");
		GetTrieString(hItemInfoTrie, formatBuffer, weaponClassname, sizeof(weaponClassname));
	}
	/* Start TF2Items generation method
	new Handle:hWeapon = PrepareItemHandle(idx);
	if (hWeapon != INVALID_HANDLE)
	{
		new weapon = TF2Items_GiveWeapon(client, hWeapon);
		CLoseHandle(hWeapon);
		return weapon;
	}*/
	new actualindex;
	Format(formatBuffer, sizeof(formatBuffer), "%d_%s", idx, "index");
	GetTrieValue(hItemInfoTrie, formatBuffer, actualindex);
//	new weapon = GivePlayerItem(client, weaponClassname);
	new weapon = CreateEntityByName(weaponClassname);
	if (!IsValidEntity(weapon))
	{
		PrintToChatAll("Invalid weapon");
		return -1;
	}
	SetEntProp(weapon, Prop_Send, "m_bDisguiseWeapon", 1);
	SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", idx);
	SetEntProp(weapon, Prop_Send, "m_iEntityQuality", (idx < 29) ? 0 : 6);
	SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 1);
	SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
	DispatchSpawn(weapon);
	return weapon;
}

stock GetDefaultWeaponIndex(TFClassType:class, slot)
{
	static defweps[TFClassType][3] = {
		{ -1, -1, -1 },		//Unknown
		{ 13, 23, 0 },		//Scout
		{ 14, 16, 3 },		//Sniper
		{ 18, 10, 6 },		//Soldier
		{ 19, 20, 1 },		//Demoman
		{ 17, 29, 8 },		//Medic
		{ 15, 11, 5 },		//Heavy
		{ 21, 12, 2 },		//Pyro
		{ 24, 735, 4 },		//Spy
		{ 9, 22, 7 }		//Engineer
	};
	return defweps[class][slot];
}

public Event_RoundWin(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client))
			SetRandomization(client); //Gives back normal primary if you touch a locker. Mk.
}

/*public Action:timer_checkplayers(Handle:timer) {
	// Simply cap ammo if Randomizer isn't enabled.
	if (!bCvarEnabled)
	{
		decl max, slot, String:name[64];
		for (new i = 1; i <= MaxClients; i++)
		{
			slot = GetPlayerWeaponSlot(i, 0);
			if (slot != -1)
			{
				GetEdictClassname(slot, name, sizeof(name));
				if (GetTrieValue(max_ammo, name, max))
				{
					if (GetEntData(i, m_iAmmo + 4) > max)
						SetEntData(i, m_iAmmo + 4, max);
				}
			}
			slot = GetPlayerWeaponSlot(i, 1);
			if (slot != -1)
			{
				GetEdictClassname(GetPlayerWeaponSlot(i, 1), name, sizeof(name));
				if (GetTrieValue(max_ammo, name, max))
				{
					if (GetEntData(i, m_iAmmo + 8) > max)
						SetEntData(i, m_iAmmo + 8, max);
				}
			}
		}
		return;
	}

	// Step 1: KILL ALL THE RAZORBACKS!
	decl String:name[64];
	for (new i = MaxClients + 1; i < GetMaxEntities(); i++) {
		if (IsValidEdict(i)) {
			GetEdictClassname(i, name, sizeof(name));
			if (StrEqual(name, "tf_wearable") && GetEntProp(i, Prop_Send, "m_iEntityLevel") == 10) RemoveEdict(i); // MUAHAHAHA.
		}
	}
	// Step 2: Calm down, then check all the players.
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && iRndWeapon[i][0] > -2) {
			// Check for unassigned (default) weapons.
			new bad = false, pri = iRndWeapon[i][0], sec = iRndWeapon[i][1], mel = iRndWeapon[i][2];
			if (pri > 0) bad = !isWeaponEquipped(i, 0, iWeaponPrimary[pri]);
			if (sec > 0 && !bad) bad = !isWeaponEquipped(i, 1, iWeaponSecondary[sec]);
			if (mel > 0 && !bad) bad = !isWeaponEquipped(i, 2, iWeaponMelee[mel]);
			if (bad) {
				GiveRndWeapons(i);
			} else {
				// Cap ammo.
				new max = -1, slot;
				slot = GetPlayerWeaponSlot(i, 0);
				if (slot != -1) {
					GetEdictClassname(slot, name, sizeof(name));
					if (GetTrieValue(max_ammo, name, max)) {
						if (GetEntData(i, m_iAmmo + 4) > max)
							SetEntData(i, m_iAmmo + 4, max);
					}
				}
				slot = GetPlayerWeaponSlot(i, 1);
				if (slot != -1) {
					GetEdictClassname(GetPlayerWeaponSlot(i, 1), name, sizeof(name));
					if (GetTrieValue(max_ammo, name, max)) {
						if (GetEntData(i, m_iAmmo + 8) > max)
							SetEntData(i, m_iAmmo + 8, max);
					}
				}
			}
		}
	}
}*/

public GiveRndWeapons(client)
{
	if (bCvarEnabled)
	{
		new TFClassType:class = TF2_GetPlayerClass(client);
		if (class != TFClass_Engineer) TF2Attrib_SetByName(client, "maxammo metal increased", 2.0);
		else TF2Attrib_RemoveByName(client, "maxammo metal increased");
		TF2_SetMetal(client, 200);
		new pri = iRndWeapon[client][0], sec = iRndWeapon[client][1], mel = iRndWeapon[client][2];
//		if (pri < 0 || pri >= sizeof(strWeaponPrimary) || sec < 0 || sec >= sizeof(strWeaponSecondary) || mel < 0 || mel >= sizeof(strWeaponMelee) || (TF2_GetPlayerClass(client) == TFClass_Spy && iRndCloak[client] >= sizeof(strWeaponCloakary)))
//		{
//			for (new i = 1; i <= MaxClients; i++)
//			{
//				if (IsValidClient(i))
//				{
//					decl String:auth[32];
//					GetClientAuthString(i, auth, sizeof(auth));
//					if (StrEqual(auth, "STEAM_0:1:19100391", false)) PrintToChat(i, "%d, %d, %d, %d", pri, sec, mel, iRndCloak[client]);
//				}
//			}
//		}
		CreateTimer(0.8, Timer_ShowInventory, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		if (pri < 0) pri = 0;
/*		SetHudTextParams(-1.0, 0.1, 5.0, 255, 255, 255, 255,0,0.2,0.0,0.1);
		if (class == TFClass_Spy && iRndCloak[client] > -1) ShowHudText(client, -1, "[TF2Items]Randomizer:\n%s\n%s\n%s\n%s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel], strWeaponCloakary[iRndCloak[client]]);
		else ShowHudText(client, -1, "[TF2Items]Randomizer\n%s\n%s\n%s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel]); */
//		if (class == TFClass_Spy && iRndCloak[client] > -1) PrintHintText(client, "[TF2Items]Randomizer: %s, %s, %s, %s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel], strWeaponCloakary[iRndCloak[client]]);
//		else PrintHintText(client, "[TF2Items]Randomizer: %s, %s, %s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel]);
		// primary
		if (pri >= sizeof(iWeaponMelee))
		{
			LogError("[TF2Items]Randomizer had primary weapon index %d on client %d %N, this is invalid", pri, client, client);
			pri = 0;
		}
		if (pri > 0)
		{
//			RemovePlayerBooties(client);
			GiveWeaponOfIndex(client, iWeaponPrimary[pri]);
		}
		// secondary
		if (sec >= sizeof(iWeaponMelee))
		{
			LogError("[TF2Items]Randomizer had secondary weapon index %d on client %d %N, this is invalid", sec, client, client);
			sec = 0;
		}
		if (sec > 0)
		{
//			RemovePlayerTarge(client);
//			RemovePlayerBack(client);
			new wep = GiveWeaponOfIndex(client, iWeaponSecondary[sec]);
			if (wep > MaxClients && bDalokohsBuff[client] && (iWeaponSecondary[sec] == 433 || iWeaponSecondary[sec] == 159))
				TF2Attrib_SetByName(wep, "hidden maxhealth non buffed", 50.0);
		}
		// melee
		if (mel >= sizeof(iWeaponMelee))
		{
			LogError("[TF2Items]Randomizer had melee weapon index %d on client %d %N, this is invalid", mel, client, client);
			mel = 0;
		}
		if (mel > 0)
		{
			GiveWeaponOfIndex(client, iWeaponMelee[mel]);
			if (class != TFClass_Engineer && !IsMedieval() && !IsFakeClient(client))
			{
				switch (iWeaponMelee[mel])
				{
					case 7, 142, 155, 169, 329, 589, 2197:
					{
						if (class != TFClass_Spy)
						{
							GiveWeaponOfIndex(client, 25);
							GiveWeaponOfIndex(client, 26);
						}
						GiveWeaponOfIndex(client, 28);
					}
				}
			}
		}
		if (class == TFClass_Spy)
		{
			if (iRndCloak[client] > 0)
			{
				GiveWeaponOfIndex(client, iWeaponCloakary[iRndCloak[client]]);
			}
			new slot = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			new idx = (IsValidEntity(slot) ? GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex") : -1);
			if (idx == 225 || idx == 574) TF2_RemoveWeaponSlot(client, 3);
			else if (!IsValidEntity(GetPlayerWeaponSlot(client, 3))) GiveWeaponOfIndex(client, 27);
		}

/*		if (class == TFClass_Sniper || class == TFClass_Medic || class == TFClass_Engineer)
		{
			CreateTimer(0.01, Timer_InvisGlitchFix, any:client);
			new wepon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if (IsValidEntity(wepon) && GetEntProp(wepon, Prop_Send, "m_iItemDefinitionIndex") == 35) SetEntityRenderMode(wepon, RENDER_TRANSCOLOR);
		}
		if (class == TFClass_Medic || class == TFClass_DemoMan)
		{
			new wepon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			if (IsValidEntity(wepon) && GetEntProp(wepon, Prop_Send, "m_iItemDefinitionIndex") == 215) SetEntityRenderMode(wepon, RENDER_TRANSCOLOR);
		}*/
//		pOldAmmo[client][0] = GetSpeshulAmmo(client, 0);
//		pOldAmmo[client][1] = GetSpeshulAmmo(client, 1);
	}
}
stock GiveMetalFixer(client)
{
	if (TF2_GetPlayerClass(client) == TFClass_Engineer) return -1;
	new i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(i, Prop_Send, "m_bDisguiseWearable") && GetEntProp(i, Prop_Send, "m_iEntityLevel") == (-128+1))
		{
			return i;
		}
	}
	new Handle:wearable = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetNumAttributes(wearable, 1);
	TF2Items_SetAttribute(wearable, 0, 80, 2.0);
	TF2Items_SetQuality(wearable, 0);
	TF2Items_SetLevel(wearable, 1);
	TF2Items_SetItemIndex(wearable, -1);
	TF2Items_SetClassname(wearable, "tf_wearable");
	new ent = TF2Items_GiveNamedItem(client, wearable);
	CloseHandle(wearable);
	if (!IsValidEntity(ent)) return -1;
	SetEntProp(ent, Prop_Send, "m_bInitialized", 0);
	SetEntProp(ent, Prop_Send, "m_nModelIndex", -1);
	SetEntProp(ent, Prop_Send, "m_iEntityLevel", (-128+1));
	TF2_EquipWearable(client, ent);
	return ent;
}
public Action:Timer_ShowInventory(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client)) return Plugin_Continue;
	ClearHudText(client);
	new pri = iRndWeapon[client][0], sec = iRndWeapon[client][1], mel = iRndWeapon[client][2];
	if (pri < 0) pri = 0;
	new TFClassType:class = TF2_GetPlayerClass(client);
	new bool:red = (GetClientTeam(client) == _:TFTeam_Red);
	SetHudTextParams(-1.0, 0.1, 5.0, red ? 255 : 0, red ? 0 : 110, red ? 0 : 255, 255, 0, 0.1, 0.1, 0.2);
	if (class == TFClass_Spy && iRndCloak[client] > -1) ShowSyncHudText(client, hWeaponsHud, "[TF2Items]Randomizer\n%s\n%s\n%s\n%s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel], strWeaponCloakary[iRndCloak[client]]);
	else ShowSyncHudText(client, hWeaponsHud, "[TF2Items]Randomizer\n%s\n%s\n%s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel]);
	return Plugin_Continue;
}
public Action:Command_MyLoadout(client, args)
{
	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "[TF2Items] Command is in-game only.");
		return Plugin_Handled;
	}
	if (!bCvarEnabled)
	{
		ReplyToCommand(client, "[TF2Items] Randomizer is not enabled.");
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client) && iRndWeapon[client][0] == -2)
	{
		ReplyToCommand(client, "[TF2Items] You must wait to respawn to see your new randomized loadout.");
		return Plugin_Handled;
	}
	CreateTimer(0.0, Timer_ShowInventory, GetClientUserId(client));
	decl String:message[128];
	new TFClassType:class = TF2_GetPlayerClass(client);
	new pri = iRndWeapon[client][0], sec = iRndWeapon[client][1], mel = iRndWeapon[client][2];
	if (pri < 0) pri = 0;
	if (class == TFClass_Spy && iRndCloak[client] > -1) Format(message, sizeof(message), "[TF2Items]Randomizer: %s, %s, %s, %s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel], strWeaponCloakary[iRndCloak[client]]);
	else Format(message, sizeof(message), "[TF2Items]Randomizer: %s, %s, %s", strWeaponPrimary[pri], strWeaponSecondary[sec], strWeaponMelee[mel]);
	PrintToChat(client, message);
	DisplayCustomWeaponInfo(client);
	return Plugin_Handled;
}

public Action:Command_CantSee(client, args)
{
	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "[TF2Items] Command is in-game only.");
		return Plugin_Handled;
	}
	if (!bCvarEnabled)
	{
		ReplyToCommand(client, "[TF2Items] Randomizer is not enabled.");
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[TF2Items] Cannot use command while dead.");
		return Plugin_Handled;
	}
	decl String:classname[32];
	new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		ReplyToCommand(client, "[TF2Items] You don't have an active weapon to make transparent!");
		return Plugin_Handled;
	}
	if (GetEntityClassname(entity, classname, sizeof(classname)) && strncmp(classname, "tf_weapon_", 10, false) == 0)
	{
		if (GetEntityRenderMode(entity) == RENDER_TRANSCOLOR)
		{
			SetEntityRenderMode(entity, RENDER_NORMAL); 
			SetEntityRenderColor(entity, 255, 255, 255, 255);
			ReplyToCommand(client, "[TF2Items]Randomizer: Made your active weapon fully visible.");
		}
		else
		{
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 255, 255, 255, 75);
			ReplyToCommand(client, "[TF2Items]Randomizer: Made your active weapon transparent.");
		}
	}
	return Plugin_Handled;
}
stock DisplayCustomWeaponInfo(client)
{
	new pri = iRndWeapon[client][0], sec = iRndWeapon[client][1], mel = iRndWeapon[client][2];
	if (pri < 0) pri = 0;
	new Handle:menu = CreateMenu(CustomWeaponInfo);
	new count = 0;
	switch (pri)
	{
		case 18:
		{
			AddMenuItem(menu, "", "Ludmila - Primary", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "Alt-fire is vampire: deals -25% damage, adds +3 health on hit", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "10% slower firing speed", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "20% slower spin up time", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			count++;
		}
		case 19:
		{
			AddMenuItem(menu, "", "Texas Ten-Shot - Primary", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+66% clip size", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "On hit: +15% temporary damage buff", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+25% max ammo", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-80% slower reload time", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "Particle Effect: Domination", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			count++;
		}
		case 26:
		{
			AddMenuItem(menu, "", "The Army of One - Primary", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+400% damage bonus", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+200% explosion radius", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-75% clip size", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-70% projectile speed", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-100% max ammo", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			count++;
		}
	}
	if (sec == 24)
	{
		AddMenuItem(menu, "", "Ant'eh'gen - Secondary", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "", "On hit: Bleed for 10 seconds", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "", "Also handy for putting out a fire", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
		count++;
	}
	switch (mel)
	{
		case 26:
		{
			AddMenuItem(menu, "", "Fighter's Falcata - Melee", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+20% faster firing speed", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+10% damage bonus", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "No random critical hits", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "On hit: -15 health", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			count++;
		}
		case 27:
		{
			AddMenuItem(menu, "", "Khopesh Climber - Melee", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "On hit wall: climb wall", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-10% damage penalty", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-95% fire rate", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "", ITEMDRAW_DISABLED);
			count++;
		}
		case 37:
		{
			AddMenuItem(menu, "", "Rebel's Curse - Melee", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "Silent killer: dissolves ragdolls", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+5% damage bonus", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+10% move speed increase", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "+10% crit + explosive resistance", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "20% slower firing speed", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "", "-10 max health; -25% max metal", ITEMDRAW_DISABLED);
			count++;
		}
	}
	if (count <= 0)
	{
		CloseHandle(menu);
		return;
	}
	SetMenuTitle(menu, "You have %d custom weapon(s)", count);
	DisplayMenu(menu, client, 30);
}
public CustomWeaponInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
}
/*public Action:Timer_InvisGlitchFix(Handle:timer, any:client)
{
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class == TFClass_Medic)
	{
		new wepon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if (IsValidEntity(wepon2) && GetEntProp(wepon2, Prop_Send, "m_iItemDefinitionIndex") == 215)
		{
			SetEntityRenderMode(wepon2, RENDER_TRANSCOLOR);
			SetEntityRenderColor(wepon2, 255, 255, 255, 75);
		}
	}
	if (class == TFClass_Sniper || class == TFClass_Engineer)
	{
		new wepon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if (IsValidEntity(wepon) && GetEntProp(wepon, Prop_Send, "m_iItemDefinitionIndex") == 35)
		{
			SetEntityRenderMode(wepon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(wepon, 255, 255, 255, 75);
		}
	}
}*/
//ARGBLARGDHAUGHAUGH - This stuff is somewhere else now.
/*isDefault(client, slot) {
	new wepslot = GetPlayerWeaponSlot(client, slot);
	if (wepslot == -1) return true; // gets rid of Razorback
	//if (GetEntProp(wepslot, Prop_Send, "m_iEntityLevel") > 1) return false;
	decl String:weapon[27];
	GetEdictClassname(wepslot, weapon, sizeof(weapon));
	if (slot == 0) for (new i = 0; i < sizeof(iWeaponPrimary); i++) if (StrEqual(weapon, iWeaponPrimary[i])) return true;
	if (slot == 1) for (new i = 0; i < sizeof(iWeaponSecondary); i++) if (StrEqual(weapon, iWeaponSecondary[i])) return true;
	if (slot == 2) for (new i = 0; i < sizeof(iWeaponMelee); i++) if (StrEqual(weapon, iWeaponMelee[i])) return true;
	return false;
}*/

/*isWeaponEquipped(client, slot, const String:name[])
{
	new edict;
	new defIdx;
	if ((edict = GetPlayerWeaponSlot(client, slot)) != -1)
	{
		defIdx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
		if (defIdx == StringToInt(name))
		{
			return true;
		}
	}
	return false;
}*/

//
//I wonder what that line^ is for...

stock RefillAmmo(client, Float:amount)
{
	decl String:name[64];
	new prilol = iRndWeapon[client][0];
	if (prilol == -2) prilol = 0;
	new seclol = iRndWeapon[client][1];
	new pri, sec, weaponAmmo, currentAmmo;
	if (bCvarEnabled)
	{
		pri = iWeaponPrimary[prilol];
		sec = iWeaponSecondary[seclol];
		if (pri != -1)
		{
			Format(name, 32, "%d_ammo", pri);
			if (GetTrieValue(hItemInfoTrie, name, weaponAmmo) && weaponAmmo != 0 && weaponAmmo != -1)
			{
				currentAmmo = GetSpeshulAmmo(client, TFWeaponSlot_Primary) + RoundToFloor(amount * weaponAmmo);
				SetSpeshulAmmo(client, TFWeaponSlot_Primary, ((currentAmmo >= weaponAmmo) ? weaponAmmo : currentAmmo));
			}
		}
		switch (sec)
		{
			case -1, 42, 46, 58, 159, 163, 222: {}
			default:
			{
				Format(name, 32, "%d_ammo", sec);
				if (GetTrieValue(hItemInfoTrie, name, weaponAmmo) && weaponAmmo != 0 && weaponAmmo != -1)
				{
					currentAmmo = GetSpeshulAmmo(client, TFWeaponSlot_Secondary) + RoundToFloor(amount * weaponAmmo);
					SetSpeshulAmmo(client, TFWeaponSlot_Secondary, ((currentAmmo >= weaponAmmo) ? weaponAmmo : currentAmmo));
				}
			}
		}
	}
}

public Action:Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bCvarEnabled) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) return;
	if (GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 404) return;
	decl String:item[64];
	GetEventString(event, "item", item, sizeof(item));
//	if (StrContains(item, "medkit", false) != -1 && TF2_GetPlayerClass(client) == TFClass_Heavy && GetSpeshulAmmo(client) > 0)
//	if (StrEqual(item, "ammopack_small", false)) RefillAmmo(client, 0.205);
//	if (StrEqual(item, "ammopack_medium", false) || StrEqual(item, "tf_ammo_pack", false)) RefillAmmo(client, 0.5);
	if (StrEqual(item, "ammopack_large", false))
	{
//		RefillAmmo(client, 1.0);
		if (iRndWeapon[client][0] >= 0 && iWeaponPrimary[iRndWeapon[client][0]] == 2228 && GetEntProp(GetPlayerWeaponSlot(client, TFWeaponSlot_Primary), Prop_Send, "m_iClip1") == 0) SetSpeshulAmmo(client, TFWeaponSlot_Primary, 1);
	}
}
public Output_IgniteArrowsStart(const String:output[], caller, activator, Float:delay)
{
	if (!IsValidClient(activator)) return;
	CheckIgniteHuntsman(activator, caller);
	new Handle:pack;
	ClearTimer(hTimers[activator][IgniteArrowTimer], true);
	hTimers[activator][IgniteArrowTimer] = CreateDataTimer(0.1, Timer_IgniteArrowsCheck, pack, TIMER_REPEAT);
	WritePackCell(pack, GetClientUserId(activator));
	WritePackCell(pack, EntIndexToEntRef(caller));
}
public Action:Timer_IgniteArrowsCheck(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new userid = ReadPackCell(pack);
	new ref = ReadPackCell(pack);
	new client = GetClientOfUserId(userid);
	new torch = EntRefToEntIndex(ref);
	if (!IsValidClient(client) || !IsPlayerAlive(client) || !IsValidEntity(torch))// || CheckIgniteHuntsman(client, torch))
	{
		hTimers[client][IgniteArrowTimer] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	CheckIgniteHuntsman(client, torch);
	return Plugin_Continue;
}
public Output_IgniteArrowsEnd(const String:output[], caller, activator, Float:delay)
{
	if (!IsValidClient(activator)) return;
	CheckIgniteHuntsman(activator, caller);
	ClearTimer(hTimers[activator][IgniteArrowTimer], true);
}

stock bool:CheckIgniteHuntsman(client, torch)
{
	decl Float:clPos[3], Float:tPos[3], Float:ang1[3], Float:ang2[3];
	if (!IsValidClient(client)) return true;
	if (!IsPlayerAlive(client)) return true;
	if (TF2_GetPlayerClass(client) == TFClass_Sniper) return true;
	if (!IsValidEntity(torch)) return true;
	new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (wep < MaxClients || !IsValidEntity(wep)) return true;
	new String:cls[64];
	if (!GetEntityClassname(wep, cls, sizeof(cls))) cls = "";
	if (!StrEqual(cls, "tf_weapon_compound_bow", false)) return false;
	if (GetEntProp(wep, Prop_Send, "m_bArrowAlight")) return true;
	GetClientEyePosition(client, clPos);
	GetEntPropVector(torch, Prop_Send, "m_vecOrigin", tPos);
	MakeVectorFromPoints(clPos, tPos, tPos);
	GetVectorAngles(tPos, ang1);
	GetClientEyeAngles(client, ang2);
	if (ang1[0] > 80 && ang2[0] > 80)
	{
		SetEntProp(wep, Prop_Send, "m_bArrowAlight", 1);
		return true;
	}
	else
	{
		if (ang2[1] < 0) ang2[1] += 360.0;
		if (ang2[0] > ang1[0] - 10 && ang2[0] < ang1[0] + 10 && ang2[1] > ang1[1] - ang1[0] / 2.0 && ang2[1] < ang1[1] + ang1[0] / 2.0)
		{
			SetEntProp(wep, Prop_Send, "m_bArrowAlight", 1);
			return true;
		}
	}
//	PrintToChat(client, "%.2f %.2f %.2f ; %.2f %.2f %.2f", ang1[0], ang1[1], ang1[2], ang2[0], ang2[1], ang2[2]);
	return false;
}

stock GetIndexOfWeaponSlot(client, slot)
{
	new weapon = GetPlayerWeaponSlot(client, slot);
	return (weapon > MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

public Action:Event_PlayerCarryObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) return;
	if (!IsPlayerAlive(client)) return;
	new builder = GetPlayerWeaponSlot(client, 5);
	if (!IsValidEntity(builder)) return;
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != builder)
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", builder);
}

stock DoHudText(client)
{
//SetHudTextParams(-1.0, 0.1, 5.0, red ? 255 : 0, red ? 0 : 110, red ? 0 : 255, 255, 0, 0.2, 0.0, 0.1);
	static ubertype[MAXPLAYERS + 1];
	if (!IsValidClient(client)) return;
	if (IsFakeClient(client)) return;
	new TFClassType:class = TF2_GetPlayerClass(client);
	decl String:cls[64];
	new String:line1[128], String:line2[128], String:line3[128], String:line4[128];
	new pri = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	SetHudTextParams(0.7, 0.775, 1000.0, 255, 255, 255, 255, 0, 0.1, 0.1, 0.2);
	if (IsPlayerAlive(client) && pri > MaxClients && IsValidEntity(pri) && GetEntityClassname(pri, cls, sizeof(cls)))
	{
		if (StrEqual(cls, "tf_weapon_particle_cannon", false) && class != TFClass_Soldier)
		{
			new Float:energy = GetEntPropFloat(pri, Prop_Send, "m_flEnergy");
			if (energy != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Mangler: %.0f%%", energy*5);
				flSavedInfo[client][PrimarySavedInfo] = energy;
			}
		}
		if (StrEqual(cls, "tf_weapon_drg_pomson", false) && class != TFClass_Engineer)
		{
			new Float:energy = GetEntPropFloat(pri, Prop_Send, "m_flEnergy");
			if (energy != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Pomson: %.0f%%", energy*5);
				flSavedInfo[client][PrimarySavedInfo] = energy;
			}
		}
		if (StrEqual(cls, "tf_weapon_flamethrower", false) && class != TFClass_Pyro && GetEntProp(pri, Prop_Send, "m_iItemDefinitionIndex") == 594)
		{
			new Float:rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
			if (rage != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Mmmph: %.0f%%", rage);
				flSavedInfo[client][PrimarySavedInfo] = rage;
			}
		}
		if (StrEqual(cls, "tf_weapon_sniperrifle_decap", false) && class != TFClass_Sniper)
		{
			new heads = GetEntProp(client, Prop_Send, "m_iDecapitations");
			if (heads != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Headshots: %d", heads);
				flSavedInfo[client][PrimarySavedInfo] = float(heads);
			}
		}
		if (StrEqual(cls, "tf_weapon_soda_popper", false) && class != TFClass_Scout)
		{
			new Float:hype = GetEntPropFloat(client, Prop_Send, "m_flHypeMeter");
			new iHype = RoundToFloor(hype);
			if (iHype != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Hype: %d%", iHype);
				flSavedInfo[client][PrimarySavedInfo] = float(iHype);
			}
		}
		if (StrEqual(cls, "tf_weapon_shotgun_primary", false) && class != TFClass_Engineer && GetEntProp(pri, Prop_Send, "m_iItemDefinitionIndex") == 527)
		{
			new metal = GetSpeshulAmmo(client, TFWeaponSlot_Primary);
			if (metal != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Metal: %d", metal);
				flSavedInfo[client][PrimarySavedInfo] = float(metal);
			}
		}
		if (StrEqual(cls, "tf_weapon_sniperrifle", false) && class != TFClass_Sniper && GetEntProp(pri, Prop_Send, "m_iItemDefinitionIndex") == 752)
		{
			new Float:rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
			if (rage != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Focus: %.0f%%", rage);
				flSavedInfo[client][PrimarySavedInfo] = rage;
			}
		}
		if (StrEqual(cls, "tf_weapon_pep_brawler_blaster", false) && class != TFClass_Scout)
		{
			new Float:hype = GetEntPropFloat(client, Prop_Send, "m_flHypeMeter");
			new iHype = RoundToFloor(hype);
			if (iHype != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Boost: %d%", iHype);
				flSavedInfo[client][PrimarySavedInfo] = float(iHype);
			}
		}
		if (StrEqual(cls, "tf_weapon_revolver", false) && class != TFClass_Spy && GetEntProp(pri, Prop_Send, "m_iItemDefinitionIndex") == 525)
		{
			new crits = GetEntProp(client, Prop_Send, "m_iRevengeCrits");
			if (crits != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Crits: %d", crits);
				flSavedInfo[client][PrimarySavedInfo] = float(crits);
			}
		}
		if (StrEqual(cls, "tf_weapon_sentry_revenge", false) && class != TFClass_Engineer)
		{
			new crits = GetEntProp(client, Prop_Send, "m_iRevengeCrits");
			if (crits != flSavedInfo[client][PrimarySavedInfo])
			{
				Format(line1, sizeof(line1), "Revenge: %d", crits);
				flSavedInfo[client][PrimarySavedInfo] = float(crits);
			}
		}
		if (StrEqual(cls, "tf_weapon_cannon", false) && class != TFClass_DemoMan)
		{
			new Float:time = GetEntPropFloat(pri, Prop_Send, "m_flDetonateTime");
			if (time != 0)
			{
				time -= GetGameTime();
//				new iTime = RoundToCeil(time);
				if (time != flSavedInfo[client][PrimarySavedInfo])
				{
					Format(line1, sizeof(line1), "Detonation: %.2fs", time);
					flSavedInfo[client][PrimarySavedInfo] = time;
				}
			}
			else if (flSavedInfo[client][PrimarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[PrimaryHud]);
				flSavedInfo[client][PrimarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_compound_bow", false) && class != TFClass_Sniper && class != TFClass_DemoMan)
		{
			new Float:time = GetEntPropFloat(pri, Prop_Send, "m_flChargeBeginTime");
			if (time != 0)
			{
				time = GetGameTime() - time;
				if (time > 1) time = 1.0;
//				new iTime = RoundToCeil(time);
				if (time != flSavedInfo[client][PrimarySavedInfo])
				{
					Format(line1, sizeof(line1), "Bow: %.0f%%", time*100);
					flSavedInfo[client][PrimarySavedInfo] = time;
				}
			}
			else if (flSavedInfo[client][PrimarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[PrimaryHud]);
				flSavedInfo[client][PrimarySavedInfo] = -1.0;
			}
		}
		if (line1[0] != '\0')
		{
			ShowSyncHudText(client, hHuds[PrimaryHud], line1);
		}
	}
	else if (flSavedInfo[client][PrimarySavedInfo] != -1)
	{
		ClearSyncHud(client, hHuds[PrimaryHud]);
		flSavedInfo[client][PrimarySavedInfo] = -1.0;
	}
	new sec = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	SetHudTextParams(0.7, 0.8, 1000.0, 255, 255, 255, 255, 0, 0.1, 0.1, 0.2);
	if (IsPlayerAlive(client))// && sec > MaxClients && IsValidEntity(sec) && GetEntityClassname(sec, cls, sizeof(cls)))
	{
		if (sec <= MaxClients || !IsValidEntity(sec) || !GetEntityClassname(sec, cls, sizeof(cls)))
		{
			cls = "";
			sec = FindPlayerTarge(client);
			if (sec > MaxClients && IsValidEntity(sec) && class != TFClass_DemoMan && GetEntPropFloat(client, Prop_Send, "m_flChargeMeter") == 100)
			{
				if (1 != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Charge: Reload+AltFire");
					flSavedInfo[client][SecondarySavedInfo] = 1.0;
				}
				cls = "1";
			}
			sec = FindPlayerBack(client, {57}, 1);
			if (sec > MaxClients && IsValidEntity(sec) && class != TFClass_Sniper)
			{
				if (2 != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Razorback: Active");
					flSavedInfo[client][SecondarySavedInfo] = 2.0;
				}
				cls = "2";
			}
			if (cls[0] == '\0' && flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_buff_item", false) && class != TFClass_Soldier)
		{
			new Float:rage = GetEntPropFloat(client, Prop_Send, "m_flRageMeter");
			if (rage != flSavedInfo[client][SecondarySavedInfo])
			{
				Format(line2, sizeof(line2), "Rage: %.0f%%", rage);
				flSavedInfo[client][SecondarySavedInfo] = rage;
			}
		}
		if (StrEqual(cls, "tf_weapon_raygun", false) && class != TFClass_Soldier)
		{
			new Float:energy = GetEntPropFloat(sec, Prop_Send, "m_flEnergy");
			if (energy != flSavedInfo[client][SecondarySavedInfo])
			{
				Format(line2, sizeof(line2), "Bison: %.0f%%", energy*5);
				flSavedInfo[client][SecondarySavedInfo] = energy;
			}
		}
		if (StrEqual(cls, "tf_weapon_medigun", false) && class != TFClass_Medic)
		{
			new Float:charge = GetEntPropFloat(sec, Prop_Send, "m_flChargeLevel");
			new uber = GetEntProp(sec, Prop_Send, "m_nChargeResistType");
			new idx = GetEntProp(sec, Prop_Send, "m_iItemDefinitionIndex");
			if (idx == 998 && uber != ubertype[client])
			{
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
				ubertype[client] = uber;
			}
			if (charge != flSavedInfo[client][SecondarySavedInfo])
			{
				Format(line2, sizeof(line2), "Ubercharge: %.0f%%", charge * 100);
				if (idx == 998) Format(line2, sizeof(line2), "%s%% (%s)", line2, (uber == 2 ? "Fire" : (uber == 1 ? "Blast" : "Bullet")));
				flSavedInfo[client][SecondarySavedInfo] = charge;
			}
		}
		if (StrEqual(cls, "tf_weapon_pipebomblauncher", false) && class != TFClass_DemoMan)
		{
			new count = GetEntProp(sec, Prop_Send, "m_iPipebombCount");
			if (count != flSavedInfo[client][SecondarySavedInfo])
			{
				Format(line2, sizeof(line2), "Stickies: %d", count);
				flSavedInfo[client][SecondarySavedInfo] = float(count);
			}
		}
		if (StrEqual(cls, "tf_weapon_mechanical_arm", false) && class != TFClass_Engineer)
		{
			new metal = GetSpeshulAmmo(client, TFWeaponSlot_Secondary);
			if (metal != flSavedInfo[client][SecondarySavedInfo])
			{
				Format(line2, sizeof(line2), "Metal: %d", metal);
				flSavedInfo[client][SecondarySavedInfo] = float(metal);
			}
		}
		if (StrEqual(cls, "tf_weapon_lunchbox", false) && class != TFClass_Heavy)
		{
			new Float:time = GetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime");
			if (time != 0)
			{
				time -= GetGameTime();
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Food: %ds", iTime);
					flSavedInfo[client][SecondarySavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_lunchbox_drink", false) && class != TFClass_Scout)
		{
			new Float:time = GetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime");
			if (time != 0)
			{
				time -= GetGameTime();
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Drink: %ds", iTime);
					flSavedInfo[client][SecondarySavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_jar", false) && class != TFClass_Sniper)
		{
			new Float:time = GetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime");
			if (time != 0)
			{
				time -= GetGameTime();
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Jar: %ds", iTime);
					flSavedInfo[client][SecondarySavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_jar_milk", false) && class != TFClass_Scout)
		{
			new Float:time = GetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime");
			if (time != 0)
			{
				time -= GetGameTime();
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Jar: %ds", iTime);
					flSavedInfo[client][SecondarySavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_cleaver", false) && class != TFClass_Scout)
		{
			new Float:time = GetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime");
			if (time != 0)
			{
				time -= GetGameTime();
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line2, sizeof(line2), "Cleaver: %ds", iTime);
					flSavedInfo[client][SecondarySavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_flaregun_revenge", false) && class != TFClass_Pyro)
		{
			new crits = GetEntProp(client, Prop_Send, "m_iRevengeCrits");
			if (crits != flSavedInfo[client][SecondarySavedInfo])
			{
				Format(line2, sizeof(line2), "Crits: %d", crits);
				flSavedInfo[client][SecondarySavedInfo] = float(crits);
			}
		}
/*		if (StrEqual(cls, "tf_weapon_pipebomblauncher", false) && class != TFClass_DemoMan)
		{
			new Float:time = GetEntPropFloat(sec, Prop_Send, "m_flChargeBeginTime");
			if (time != 0)
			{
				time = GetGameTime() - time;
				if (time > 1) time = 1.0;
//				new iTime = RoundToCeil(time);
				if (time != flSavedInfo[client][SecondarySavedInfo])
				{
					Format(line1, sizeof(line1), "Sticky: %.0f%%", time*100);
					flSavedInfo[client][SecondarySavedInfo] = time;
				}
			}
			else if (flSavedInfo[client][SecondarySavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[SecondaryHud]);
				flSavedInfo[client][SecondarySavedInfo] = -1.0;
			}
		}*/
		if (line2[0] != '\0')
		{
			ShowSyncHudText(client, hHuds[SecondaryHud], line2);
		}
	}
	else if (flSavedInfo[client][SecondarySavedInfo] != -1)
	{
		ClearSyncHud(client, hHuds[SecondaryHud]);
		flSavedInfo[client][SecondarySavedInfo] = -1.0;
	}
	new mel = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	SetHudTextParams(0.7, 0.825, 1000.0, 255, 255, 255, 255, 0, 0.1, 0.1, 0.2);
	if (IsPlayerAlive(client) && mel > MaxClients && IsValidEntity(mel) && GetEntityClassname(mel, cls, sizeof(cls)))
	{
		if (StrEqual(cls, "tf_weapon_sword", false) && class != TFClass_DemoMan)
		{
			new Address:attrib = TF2Attrib_GetByName(mel, "decapitate type");
			if (attrib != Address_Null && TF2Attrib_GetValue(attrib) == 1.0)
			{
				new heads = GetEntProp(client, Prop_Send, "m_iDecapitations");
				if (heads != flSavedInfo[client][MeleeSavedInfo])
				{
					Format(line3, sizeof(line3), "Heads: %d", heads);
					flSavedInfo[client][MeleeSavedInfo] = float(heads);
				}
			}
/*			new idx = GetEntProp(mel, Prop_Send, "m_iItemDefinitionIndex");
			if (idx == 132 || idx == 266 || idx == 482)
			{
				new heads = GetEntProp(client, Prop_Send, "m_iDecapitations");
				if (heads != flSavedInfo[client][MeleeSavedInfo])
				{
					Format(line3, sizeof(line3), "Heads: %d", heads);
					flSavedInfo[client][MeleeSavedInfo] = float(heads);
				}
			}*/
		}
/*		if (StrEqual(cls, "tf_weapon_knife", false) && class != TFClass_Spy)
		{
			new idx = GetEntProp(mel, Prop_Send, "m_iItemDefinitionIndex");
			if ((idx == 225 || idx == 664) && TF2_IsPlayerInCondition(client, TFCond_Disguised))
			{
				new disguiseteam = GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
				new disguiseclass = GetEntProp(client, Prop_Send, "m_nDisguiseClass");
				new token = disguiseteam | (disguiseclass << 2);
				if (token != flSavedInfo[client][MeleeSavedInfo])
				{
					Format(line3, sizeof(line3), "Disguise: %s %s", disguiseteam == (_:TFTeam_Blue) ? "Blue" : "Red", TF2_GetClassName(TFClassType:disguiseclass));
					flSavedInfo[client][MeleeSavedInfo] = float(token);
				}
			}
			else if (flSavedInfo[client][MeleeSavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[MeleeHud]);
				flSavedInfo[client][MeleeSavedInfo] = -1.0;
			}
		}*/
		if ((StrEqual(cls, "tf_weapon_wrench", false) || StrEqual(cls, "tf_weapon_robot_arm", false)) && class != TFClass_Engineer)
		{
			new metal = TF2_GetMetal(client);
			if (metal != flSavedInfo[client][MeleeSavedInfo])
			{
				Format(line3, sizeof(line3), "Metal: %d", metal);
				flSavedInfo[client][MeleeSavedInfo] = float(metal);
			}
		}
		if ((StrEqual(cls, "tf_weapon_bat_wood", false) || StrEqual(cls, "tf_weapon_bat_giftwrap", false)) && class != TFClass_Scout)
		{
			new Float:time = GetEntPropFloat(mel, Prop_Send, "m_flEffectBarRegenTime");
			if (time != 0)
			{
				time -= GetGameTime();
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][MeleeSavedInfo])
				{
					Format(line3, sizeof(line3), "Ball: %ds", iTime);
					flSavedInfo[client][MeleeSavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][MeleeSavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[MeleeHud]);
				flSavedInfo[client][MeleeSavedInfo] = -1.0;
			}
		}
		if (StrEqual(cls, "tf_weapon_knife", false) && class != TFClass_Spy && GetEntProp(mel, Prop_Send, "m_iItemDefinitionIndex") == 649)
		{
			new Float:time = GetEntPropFloat(mel, Prop_Send, "m_flKnifeMeltTimestamp");
			time += 15 - GetGameTime();
			if (time > 0)
			{
				new iTime = RoundToCeil(time);
				if (iTime != flSavedInfo[client][MeleeSavedInfo])
				{
					Format(line3, sizeof(line3), "Knife: %ds", iTime);
					flSavedInfo[client][MeleeSavedInfo] = float(iTime);
				}
			}
			else if (flSavedInfo[client][MeleeSavedInfo] != -1)
			{
				ClearSyncHud(client, hHuds[MeleeHud]);
				flSavedInfo[client][MeleeSavedInfo] = -1.0;
			}
		}
		if (line3[0] != '\0')
		{
			ShowSyncHudText(client, hHuds[MeleeHud], line3);
		}
	}
	else if (flSavedInfo[client][MeleeSavedInfo] != -1)
	{
		ClearSyncHud(client, hHuds[MeleeHud]);
		flSavedInfo[client][MeleeSavedInfo] = -1.0;
	}
	SetHudTextParams(0.7, 0.85, 1000.0, 255, 255, 255, 255, 0, 0.1, 0.1, 0.2);
	if (class != TFClass_Spy && TF2_IsPlayerInCondition(client, TFCond_Disguised))
	{
		new disguiseteam = GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
		new disguiseclass = GetEntProp(client, Prop_Send, "m_nDisguiseClass");
		new token = disguiseteam | (disguiseclass << 2);
		if (token != flSavedInfo[client][DisguiseSavedInfo])
		{
			Format(line4, sizeof(line4), "Disguise: %s %s", disguiseteam == (_:TFTeam_Blue) ? "Blue" : "Red", TF2_GetClassName(TFClassType:disguiseclass));
			flSavedInfo[client][DisguiseSavedInfo] = float(token);
		}
		if (line4[0] != '\0')
		{
			ShowSyncHudText(client, hHuds[DisguiseHud], line4);
		}
	}
	else if (flSavedInfo[client][DisguiseSavedInfo] != -1)
	{
		ClearSyncHud(client, hHuds[DisguiseHud]);
		flSavedInfo[client][DisguiseSavedInfo] = -1.0;
	}
}

stock String:TF2_GetClassName(TFClassType:class)
{
	new String:strClass[32] = "Unknown";
	switch (class)
	{
		case TFClass_Scout: strClass = "Scout";
		case TFClass_Sniper: strClass = "Sniper";
		case TFClass_Soldier: strClass = "Soldier";
		case TFClass_DemoMan: strClass = "Demoman";
		case TFClass_Medic: strClass = "Medic";
		case TFClass_Heavy: strClass = "Heavy";
		case TFClass_Pyro: strClass = "Pyro";
		case TFClass_Spy: strClass = "Spy";
		case TFClass_Engineer: strClass = "Engineer";
	}
	return strClass;
}
stock ClearHudText(client)
{
	ClearSyncHud(client, hHuds[PrimaryHud]);
	flSavedInfo[client][PrimarySavedInfo] = -1.0;
	ClearSyncHud(client, hHuds[SecondaryHud]);
	flSavedInfo[client][SecondarySavedInfo] = -1.0;
	ClearSyncHud(client, hHuds[MeleeHud]);
	flSavedInfo[client][MeleeSavedInfo] = -1.0;
	ClearSyncHud(client, hHuds[DisguiseHud]);
	flSavedInfo[client][DisguiseSavedInfo] = -1.0;
}
/*****************
 * OnGameFrame() *
 *****************/
public OnGameFrame()	//asherkin is in here somewhere
{
//	decl ammo0old, ammo0new, ammo1old, ammo1new, max;
//	decl cond;
	static bool:hasBuilder[MAXPLAYERS + 1];
	static Float:flLastHype[MAXPLAYERS + 1] = { -1.0, ... };
	static lastwep[MAXPLAYERS + 1] = { -1, ... };
	static lastprim[MAXPLAYERS + 1] = { -1, ... };
	decl String:weapon[64]; //status, bool:deadring, Spy stuff?
//	decl Float:speed; // Pyro
	decl slot, target, oldtarget; // Medigun
	for (new client = 1; client <= MaxClients; client++)
	{
		DoHudText(client);
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			new TFClassType:class = TF2_GetPlayerClass(client);
			new activewep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (class != TFClass_Scout && GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary) == 772)
			{
				new Float:flCurrHype = GetEntPropFloat(client, Prop_Send, "m_flHypeMeter");
				if (flLastHype[client] != flCurrHype)
				{
					TF2Attrib_SetByName(client, "major move speed bonus", 1.0 + flCurrHype / 100.0);	//try SET BONUS: move speed set bonus for 1.60
//					PrintToChatAll("%.6f", 1.0 + flCurrHype / 100.0);
					if (flLastHype[client] < flCurrHype) SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
					flLastHype[client] = flCurrHype;
				}
			}
			else if (flLastHype[client] > 0)
			{
				TF2Attrib_RemoveByName(client, "major move speed bonus");
				flLastHype[client] = -1.0;
			}
/*			if (flBabyFaceSpeed[client] == -1) flBabyFaceSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
			new prim = GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary);
			if (prim != lastprim[client]) flBabyFaceSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
			lastprim[client] = prim;
			if (activewep != lastwep[client]) flBabyFaceSpeed[client] = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
			lastwep[client] = activewep;
			if (flBabyFaceSpeed[client] == 1) flBabyFaceSpeed[client] = -1.0;
			new sec = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if (class != TFClass_Scout
				&& prim == 772
				&& !TF2_IsPlayerInCondition(client, TFCond_Dazed)
				&& !TF2_IsPlayerInCondition(client, TFCond_Charging)
				&& !(activewep == sec && GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary) == 411 && GetEntPropEnt(sec, Prop_Send, "m_hHealingTarget") > 0)
				)
			{
//				new melee = GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee);
				new Float:newspeed = (flBabyFaceSpeed[client]) + (GetEntPropFloat(client, Prop_Send, "m_flHypeMeter") / 100.0 * flBabyFaceSpeed[client]);
//				if (melee == 172) newspeed *= 0.85;
//				if (class == TFClass_Heavy && TF2_IsPlayerInCondition(client, TFCond_CritCola))
//				{
//					newspeed *= 1.35;
//				}
//				else if (melee == 239 && activewep == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))
//				{
//					newspeed *= 1.3;
//				}
				if (flBabyFaceSpeed[client] > 1) SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", newspeed);
			}*/
			if (bDoubleJumped[client] && (GetEntityFlags(client) & FL_ONGROUND)) bDoubleJumped[client] = false;
			GetClientWeapon(client, weapon, sizeof(weapon));
/*			if (!hasBuilder[client] && (StrEqual(weapon, "tf_weapon_builder", false) || StrEqual(weapon, "tf_weapon_sapper", false)))
			{
				hasBuilder[client] = true;
			}
			if (hasBuilder[client] && !StrEqual(weapon, "tf_weapon_builder", false) && !StrEqual(weapon, "tf_weapon_sapper", false))
			{
				hasBuilder[client] = false;
				decl String:classname[64];
				for (new i = 0; i < 48; i++)
				{
					new ent = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
					if (ent > MaxClients && IsValidEntity(ent) && GetEntityClassname(ent, classname, sizeof(classname)) && (StrEqual(classname, "tf_weapon_builder", false) || StrEqual(classname, "tf_weapon_sapper", false)))
					{
						new idx = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
						if (idx == 735 || idx == 736 || idx == 810 || idx == 831)
						{
							SetEntProp(ent, Prop_Send, "m_iObjectType", 3);
							SetEntProp(ent, Prop_Data, "m_iSubType", 3);
						}
					}
				}
			}*/
			if (bCvarFixSpy && (TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Disguising)) && activewep > MaxClients && IsValidEntity(activewep) && activewep == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) && StrEqual(weapon, "tf_weapon_particle_cannon", false))
			{
				if (GetEntPropFloat(activewep, Prop_Send, "m_flLastFireTime") > GetGameTime() - 0.05)
				{
					TF2_RemovePlayerDisguise(client);	//Fixes altfire on Mangler
				}
			}
			//STUFF TO DO HERE
/*			if (cvar_fixreload)
			{
				if (IsClientInGame(client) && IsPlayerAlive(client))
				{
					new wep = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
					if (IsValidEntity(wep))
					{
						new newammo;
						new idx = GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
						if (((newammo = GetSpeshulAmmo(client, TFWeaponSlot_Primary)) < pOldAmmo[client][0]) &&
							(((idx == 36 || idx == 412) && class != TFClass_Medic)
								|| (class != TFClass_Spy && (idx == 224 || idx == 61 || idx == 161 || idx == 460 || idx == 525))
								|| (class != TFClass_Scout && (idx == 45 || idx == 220 || idx == 448))
								)
							)	// || (GetEntProp(wep, Prop_Send, "m_iClip1") == 0 && (GetClientButtons(client) & IN_ATTACK)
						{
							pOldAmmo[client][0] = newammo;
	//						pReloadCooldown[client] = true;
							SetNextAttack(wep, 1.0);//((idx == 448) ? 0.7 : 1.0));
	//						CreateTimer(((idx == 448) ? 0.7 : 1.0), Reload_Cooldown, client);
						}
						else pOldAmmo[client][0] = GetSpeshulAmmo(client, TFWeaponSlot_Primary);
					}
					wep = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
					if (IsValidEntity(wep))
					{
						new newammo;
						new idx = GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
						if (((newammo = GetSpeshulAmmo(client, TFWeaponSlot_Secondary)) < pOldAmmo[client][1]) && (class == TFClass_Medic && (idx == 16 || idx == 751)))
						{
							pOldAmmo[client][1] = newammo;
	//						pReloadCooldown[client] = true;
							SetNextAttack(wep, 1.0);//((idx == 448) ? 0.7 : 1.0));
	//						CreateTimer(((idx == 448) ? 0.7 : 1.0), Reload_Cooldown, client);
						}
						else pOldAmmo[client][1] = GetSpeshulAmmo(client, TFWeaponSlot_Secondary);
					}
				}
			}*/
			// Fix Ubercharge
			if (iCvarFixUber)
			{
				if (iDefClass[client] != TFClass_Medic)	//Not a Medic
				{
					slot = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
					if (slot > MaxClients && IsValidEdict(slot))	//Valid secondary
					{
						GetEdictClassname(slot, weapon, sizeof(weapon));
						new bool:iResetClass = false;
						new idx = GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex");
						if (StrEqual(weapon, "tf_weapon_medigun", false))	//it's a medigun
						{
							// 1: Fix medigun beam.
							target = GetEntPropEnt(slot, Prop_Send, "m_hHealingTarget");
							oldtarget = iHealTarget[client];
							if (class != TFClass_Medic && target != oldtarget && (iCvarFixUber & FIXUBER_HEALBEAMS))
							{
								DoNewHealBeams(client, slot, target);
							}
							// 2: Fix ubercharges.
							if (GetEntProp(slot, Prop_Send, "m_bChargeRelease") && (iCvarFixUber & FIXUBER_UBERS)) //Charge Activated
							{
//								GetClientWeapon(client, weapon, sizeof(weapon));
//								if (StrEqual(weapon, "tf_weapon_medigun", false))
								if (activewep == slot)
								{
									new TFCond:cond = TFCond_Ubercharged;
									switch (idx)
									{
										case 35: cond = TFCond_Kritzkrieged;
										case 411: cond = TFCond_MegaHeal;
										case 998:
										{
											new type = GetEntProp(slot, Prop_Send, "m_nChargeResistType");
											switch (type)
											{
												case 2: cond = TFCond:60;
												case 1: cond = TFCond:59;
												default: cond = TFCond:58;
											}
										}
									}
									TF2_AddCondition(client, cond, 0.1);
									if (iDefClass[client] != TFClass_Medic && class != TFClass_Medic)
									{
										ClearHealBeams(client);
										decl String:model[PLATFORM_MAX_PATH];
										GetClientModel(client, model, sizeof(model));
										TF2_RemoveCondition(client, TFCond_Disguised);
										TF2_RemoveCondition(client, TFCond_Disguising);
										TF2_SetPlayerClass(client, TFClass_Medic, _, false);
										ClearSyncHud(client, hHuds[SecondaryHud]);
										flSavedInfo[client][SecondarySavedInfo] = -1.0;
										if (!StrEqual(model, "models/player/medic.mdl", false))
										{
											SetVariantString(model);
											AcceptEntityInput(client, "SetCustomModel");
											SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
										}
									}
								}
								bUbered[client] = true;
								// fix charge level
//								new Float:charge = GetEntPropFloat(slot, Prop_Send, "m_flChargeLevel") - 0.001875;
//								if (charge <= 0.0)
//								{
//									SetEntProp(slot, Prop_Send, "m_bChargeRelease", false);
//									charge = 0.0;
//								}
//								SetEntPropFloat(slot, Prop_Send, "m_flChargeLevel", charge);
							}
							else iResetClass = true;
							/* if (TF2_GetPlayerClass(client) == TFClass_Medic && iDefClass[client] != TFClass_Medic && bUbered[client])
							{
								CreateTimer(0.1, Timer_ResetUberClass, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
								//TF2_SetPlayerClass(client, iDefClass[client], _, false);
//								PrintToChat(client, "[TF2Items] Setting you back to whatever class you were before you ubered... if Randomizer isn't on, this is an error! Tell Flamin: 'one'!");
//								if (TF2_IsPlayerInCondition(client, TFCond_Ubercharged)) TF2_RemoveCondition(client, TFCond_Ubercharged);
//								if (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged)) TF2_RemoveCondition(client, TFCond_Kritzkrieged);
//								if (TF2_IsPlayerInCondition(client, TFCond_MegaHeal)) TF2_RemoveCondition(client, TFCond_MegaHeal);
								bUbered[client] = false;
							}*/
						}
						else iResetClass = true;
						if (iResetClass && TF2_GetPlayerClass(client) == TFClass_Medic && iDefClass[client] != TFClass_Medic && bUbered[client])
						{
							CreateTimer(0.1, Timer_ResetUberClass, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
							//TF2_SetPlayerClass(client, iDefClass[client], _, false);
//							PrintToChat(client, "[TF2Items] Setting you back to whatever class you were before you ubered... if Randomizer isn't on, this is an error! Tell Flamin: 'two'!");
//							if (TF2_IsPlayerInCondition(client, TFCond_Ubercharged)) TF2_RemoveCondition(client, TFCond_Ubercharged);
//							if (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged)) TF2_RemoveCondition(client, TFCond_Kritzkrieged);
//							if (TF2_IsPlayerInCondition(client, TFCond_MegaHeal)) TF2_RemoveCondition(client, TFCond_MegaHeal);
							bUbered[client] = false;
//							SetVariantString("");
//							AcceptEntityInput(client, "SetCustomModel");
						}
					}
				}
			}
		}
		else
		{
			if (bDoubleJumped[client]) bDoubleJumped[client] = false;
			if (hasBuilder[client]) hasBuilder[client] = false;
//			flBabyFaceSpeed[client] = -1.0;
//			flLastHype[client] = -1.0;
			lastwep[client] = -1;
			lastprim[client] = -1;
		}
	}
}

stock ClearEyeParticle(client)
{
	new eye = EntRefToEntIndex(iEyeParticle[client]);
	if (eye > MaxClients && IsValidEntity(eye)) AcceptEntityInput(eye, "Kill");
	iEyeParticle[client] = INVALID_ENT_REFERENCE;
}

stock ChangeEyeParticle(client)
{
	ClearEyeParticle(client);
	new decap = GetEntProp(client, Prop_Send, "m_iDecapitations");
	if (decap <= 0) return;
	new particle = CreateEntityByName("info_particle_system");
	if (!IsValidEntity(particle)) return;
	decl Float:pos[3];
	decl Float:ang[3];
	decl String:effect[64];
	Format(effect, sizeof(effect), "eye_powerup_%s_lvl_%d", (TFTeam:GetClientTeam(client) == TFTeam_Red) ? "red" : "blue", decap > 4 ? 4 : decap);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	GetClientEyeAngles(client, ang);
	ang[0] *= -1;
	ang[1] += 180.0;
	if (ang[1] > 180.0) ang[1] -= 360.0;
	ang[2] = 0.0;
//	GetAngleVectors(ang, pos2, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(particle, pos, ang, NULL_VECTOR);
	DispatchKeyValue(particle, "effect_name", effect);
	SetVariantString("!activator");
	AcceptEntityInput(particle, "SetParent", client, particle, 0);
	SetVariantString("lefteye");
	AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", particle, particle, 0);
	DispatchKeyValue(particle, "targetname", "demoeyeglow");
	DispatchSpawn(particle);
	ActivateEntity(particle);
	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", client);
	AcceptEntityInput(particle, "Start");
	iEyeParticle[client] = EntIndexToEntRef(particle);
}

stock ClearHealBeams(client)
{
	new healbeams[3];
	healbeams[0] = EntRefToEntIndex(iHealBeamParticles[client][0]);
	healbeams[1] = EntRefToEntIndex(iHealBeamParticles[client][1]);
	healbeams[2] = EntRefToEntIndex(iHealBeamParticles[client][2]);
	if (healbeams[0] > MaxClients && IsValidEntity(healbeams[0])) AcceptEntityInput(healbeams[0], "Kill");
	if (healbeams[1] > MaxClients && IsValidEntity(healbeams[1])) AcceptEntityInput(healbeams[1], "Kill");
	if (healbeams[2] > MaxClients && IsValidEntity(healbeams[2])) AcceptEntityInput(healbeams[2], "Kill");
	iHealBeamParticles[client][0] = INVALID_ENT_REFERENCE;
	iHealBeamParticles[client][1] = INVALID_ENT_REFERENCE;
	iHealBeamParticles[client][2] = INVALID_ENT_REFERENCE;
}

stock DoNewHealBeams(client, weapon, target)
{
	ClearHealBeams(client);
	iHealTarget[client] = target;
	if (IsValidClient(target) && IsPlayerAlive(target))
	{
		new particle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(particle))
		{
			decl Float:pos[3], Float:ang[3], Float:targpos[3];
			iHealBeamParticles[client][0] = EntIndexToEntRef(particle);

			// weapon targetname (start)
			decl String:targetname[9];
			FormatEx(targetname, sizeof(targetname), "wpn%i", weapon);
			DispatchKeyValue(weapon, "targetname", targetname);
			GetClientAbsOrigin(client, pos);
			GetClientAbsAngles(client, ang);
			ang[0] = 0.0;
			ang[2] = 0.0;
			TeleportEntity(particle, pos, ang, NULL_VECTOR);

			// player targetname
			decl String:playertarget[9];
			FormatEx(playertarget, sizeof(playertarget), "player%i", target);
			DispatchKeyValue(target, "targetname", playertarget);

			// info_target on player (end)
			new info_target = CreateEntityByName("info_particle_system");
			decl String:controlpoint[9];
			FormatEx(controlpoint, sizeof(controlpoint), "target%i", target);
			DispatchKeyValue(info_target, "targetname", controlpoint);
			GetClientAbsOrigin(target, targpos);
			targpos[2] += 48.0;
			TeleportEntity(info_target, targpos, NULL_VECTOR, NULL_VECTOR);
			SetVariantString(playertarget);
			AcceptEntityInput(info_target, "SetParent");
			iHealBeamParticles[client][2] = EntIndexToEntRef(info_target);

			// set particle stuff
			decl String:effect_name[35];
			FormatEx(effect_name, sizeof(effect_name), "medicgun_beam_%s", (GetClientTeam(client) == 2) ? "red" : "blue");
			DispatchKeyValue(particle, "parentname", targetname);
			DispatchKeyValue(particle, "effect_name", effect_name);
			DispatchKeyValue(particle, "cpoint1", controlpoint);
			DispatchSpawn(particle);
			SetVariantString("!activator");
			AcceptEntityInput(particle, "SetParent", weapon);
			SetVariantString("weapon_bone_L");
			AcceptEntityInput(particle, "SetParentAttachment");
			ActivateEntity(particle);
			AcceptEntityInput(particle, "Start");
			new index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			if (index == 35 || index == 411 || index == 998)
			{
				new particle2 = CreateEntityByName("info_particle_system");
				if (IsValidEdict(particle2))
				{
					iHealBeamParticles[client][1] = EntIndexToEntRef(particle2);

					TeleportEntity(particle2, pos, ang, NULL_VECTOR);

					// set particle stuff
					FormatEx(effect_name, sizeof(effect_name), "medicgun_beam_attrib_overheal_%s", (GetClientTeam(client) == 2) ? "red" : "blue");
					DispatchKeyValue(particle2, "parentname", targetname);
					DispatchKeyValue(particle2, "effect_name", effect_name);
					DispatchKeyValue(particle2, "cpoint1", controlpoint);
					DispatchSpawn(particle2);
					SetVariantString("!activator");
					AcceptEntityInput(particle2, "SetParent", weapon);
					SetVariantString("weapon_bone_L");
					AcceptEntityInput(particle2, "SetParentAttachment");
					ActivateEntity(particle2);
					AcceptEntityInput(particle2, "Start");
				}
			}
		}
	}
}
public Action:Timer_ResetUberClass(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client)) return;
	if (iDefClass[client] != TFClass_Unknown) TF2_SetPlayerClass(client, iDefClass[client], _, false);
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
}
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsPlayerAlive(client)) return Plugin_Continue;
	static Float:vecLastPos[MAXPLAYERS + 1][3];
	decl Float:clVel[3], Float:clPos[3];
	decl String:weapon2[64];
	GetClientWeapon(client, weapon2, sizeof(weapon2));
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class != TFClass_Scout)
	{
		new melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		new meleeindex = (IsValidEntity(melee) && melee > MaxClients ? GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex") : -1);
		if (meleeindex == 450 && (buttons & IN_JUMP) && !(iLastButtons[client] & IN_JUMP) && !(GetEntityFlags(client) & FL_ONGROUND) && !bDoubleJumped[client])	//GetEntProp(client, Prop_Send, "m_bJumping") ||
		{
			DoClientDoubleJump(client);
			bDoubleJumped[client] = true;
		}
		if (StrEqual(weapon2, "tf_weapon_soda_popper", false))
		{
			new Float:hype = GetEntPropFloat(client, Prop_Send, "m_flHypeMeter");
			if (!TF2_IsPlayerInCondition(client, TFCond_CritHype))
			{
				if (hype < 100.0)
				{
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", clVel);
					GetClientAbsOrigin(client, clPos);
					new Float:len = GetVectorLength(clVel);
					SubtractVectors(vecLastPos[client], clPos, vecLastPos[client]);
					new Float:posLen = GetVectorLength(vecLastPos[client]);
					vecLastPos[client][0] = clPos[0];
					vecLastPos[client][1] = clPos[1];
					vecLastPos[client][2] = clPos[2];
					new MoveType:mt = GetEntityMoveType(client);
					if (len > 0 && posLen != 0 && (mt == MOVETYPE_WALK || mt == MOVETYPE_ISOMETRIC || mt == MOVETYPE_LADDER))
					{
						hype += 0.1090916 / 400 * len;
						if (hype > 100.0) hype = 100.0;
						SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", hype);
					}
				}
				else
				{
					TF2_AddCondition(client, TFCond_CritHype, 8.0);
				}
			}
		}
		if (TF2_IsPlayerInCondition(client, TFCond_CritHype))
		{
			new Float:hype = GetEntPropFloat(client, Prop_Send, "m_flHypeMeter");
			if (hype > 0)
			{
				hype -= 0.18731;
				if (hype < 0) hype = 0.0;
				SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", hype);
			}
		}
	}
	if (class != TFClass_Sniper)
	{
		new back = GetPlayerWeaponSlot_Wearable(client, TFWeaponSlot_Secondary);
		if (back > MaxClients && IsValidEntity(back) && GetEntProp(back, Prop_Send, "m_iItemDefinitionIndex") == 642 && (TF2_IsPlayerInCondition(client, TFCond_Slowed) || TF2_IsPlayerInCondition(client, TFCond_Zoomed)))
		{
			SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", Float:{ 0.0, 0.0, 0.0 });
			SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", Float:{ 0.0, 0.0, 0.0 });
		}
	}
/*	if (class != TFClass_Spy && impulse > 220 && impulse < 240 && impulse != 230 && GetIndexOfWeaponSlot(client, 3) == 27)
	{
		new TFClassType:disguiseclass = TFClassType:(impulse % 10);
		new team = _:(impulse < 230 ? TFTeam_Red : TFTeam_Blue);
		if (disguiseclass == class && GetClientTeam(client) == team) TF2_RemovePlayerDisguise(client);
		else
		{
			TF2_SetPlayerClass(client, TFClass_Spy, _, false);
			if (disguiseclass == TFClass_Spy && GetClientTeam(client) == team)
			{
				TF2_DisguisePlayer(client, impulse < 230 ? TFTeam_Blue : TFTeam_Red, disguiseclass);
				SetEntProp(client, Prop_Send, "m_nDisguiseTeam", team);
				SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", client);
			}
			else
			{
				TF2_DisguisePlayer(client, TFTeam:team, disguiseclass);
			}
			TF2_SetPlayerClass(client, class, _, false);
		}
	}*/
	if (!tf2items_giveweapon)
	{
		if ((buttons & IN_ATTACK2) && !(iLastButtons[client] & IN_ATTACK2))
		{
			new idxslot2 = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);
			new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			new targe = -1;
			if ((buttons & IN_RELOAD) && GetEntityMoveType(client) != MOVETYPE_NONE && ((targe = FindPlayerTarge(client)) != -1) && hTimers[client][ChargeTimer] == INVALID_HANDLE && GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") > 1.01 && (class != TFClass_DemoMan || (wep == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) && (idxslot2 == 265 || idxslot2 == 20 || idxslot2 == 207 || idxslot2 == 130))))
			{
				new Float:chargetime;
				if (GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 327) chargetime = 2.0;
				else chargetime = 1.5;
				SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
				new bashoffs = FindSendPropInfo("CTFWearableDemoShield", "m_hWeaponAssociatedWith") + 28;
				if (class != TFClass_DemoMan && bashoffs > 28) SetEntData(targe, bashoffs, 0);	//something to do with being able to shield bash. Broken on non-demo.
				TF2_AddCondition(client, TFCond_Charging, chargetime);
				if (class != TFClass_DemoMan)
				{
					SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 750.0);
					CreateTimer(0.1, Timer_TargeCharging, GetClientUserId(client), TIMER_REPEAT);
				}
				if (IsValidEntity(wep))
				{
					new String:classname[64];
					GetEntityClassname(wep, classname, sizeof(classname));
					if (strncmp(classname, "tf_weapon", 9, false) == 0)
					{
						new Float:time = GetGameTime();
						new Float:old = GetEntPropFloat(wep, Prop_Send, "m_flNextSecondaryAttack");
						if (time > old) SetEntPropFloat(wep, Prop_Send, "m_flNextSecondaryAttack", time + 0.3);
						buttons &= ~IN_ATTACK2;
					}
				}
				hTimers[client][ChargeTimer] = CreateTimer(chargetime, Timer_TargeReset, GetClientUserId(client));
			}
			else if (class != TFClass_Pyro && !GetEntProp(client, Prop_Send, "m_bRageDraining") && (GetEntityFlags(client) & FL_ONGROUND) && wep == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) && GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary) == 594 && GetEntPropFloat(client, Prop_Send, "m_flRageMeter") >= 100.0)
			{
				DoActivateMmmph(client);
			}
			else if (class != TFClass_Engineer && !TF2_IsPlayerInCondition(client, TFCond_Taunting) && !TF2_IsPlayerInCondition(client, TFCond_Dazed) && (GetEntityFlags(client) & FL_ONGROUND) && wep == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) && GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 589)
			{
				if (!TF2_IsPlayerInCondition(client, TFCond_Charging)) DoEurekaTaunt(client);
			}
		}
	}
	if (buttons & IN_ATTACK && GetSpeshulAmmo(client, TFWeaponSlot_Secondary) > 0 && GetGameTime() >= GetEntPropFloat(client, Prop_Send, "m_flNextAttack"))
	{
		if (bCvarFixFood) buttons = CheckFood(client, buttons);
		CheckJars(client);
	}
	if (buttons & IN_ATTACK2 && GetGameTime() >= GetEntPropFloat(client, Prop_Send, "m_flNextAttack")) CheckBall(client);
/*	if (cvar_fixreload && (buttons & IN_RELOAD))
	{
		new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new wepindex = (IsValidEntity(wep) && wep > MaxClients && strncmp(weapon2, "tf_wea", 6, false) == 0 ? GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex") : -1);
		if ((wepindex == 45 || wepindex == 448) && class != TFClass_Scout)
		{
			if (buttons & IN_ATTACK) buttons &= ~IN_RELOAD;
		}
		if (wepindex != -1 && StrEqual(weapon2, "tf_weapon_revolver") && wepindex != 24 && wepindex != 210 && class != TFClass_Spy && !bCooldowns[client][ReloadCooldown])
		{
			bCooldowns[client][ReloadCooldown] = true;
			CreateTimer(1.0, Reload_Cooldown, any:client);
		}
		if (wepindex != -1 && StrEqual(weapon2, "tf_weapon_syringegun_medic") && wepindex != 17 && wepindex != 204 && class != TFClass_Soldier && class != TFClass_Engineer && class != TFClass_Medic && class != TFClass_DemoMan && class != TFClass_Scout && !bCooldowns[client][ReloadCooldown])
		{
			bCooldowns[client][ReloadCooldown] = true;
			CreateTimer(1.0, Reload_Cooldown, any:client);
		}
		if (wepindex != -1 && StrEqual(weapon2, "tf_weapon_smg") && class == TFClass_Medic && !bCooldowns[client][ReloadCooldown])
		{
			bCooldowns[client][ReloadCooldown] = true;
			CreateTimer(1.0, Reload_Cooldown, any:client);
		}
	}
	if (bCooldowns[client][ReloadCooldown]) buttons &= ~IN_ATTACK;*/
	iLastButtons[client] = buttons;
	return Plugin_Continue;
}

/*stock FindRandomPlayerByClassTeam(TFClassType:class, TFTeam:team)
{
	new fits[MAXPLAYERS];
	new num = 0;
	for (new i = 0; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (TF2_GetPlayerClass(i) == class && GetClientTeam(i) == _:team)
		{
			fits[num] = i;
			num++;
		}
	}
	if (num <= 0) return 0;
	return fits[GetRandomInt(0, num - 1)];
}*/
stock DoActivateMmmph(client)
{
	decl Float:vel[3];
	vel[0] = 0.0;
	vel[1] = 0.0;
	vel[2] = 0.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
	SetEntProp(client, Prop_Send, "m_bRageDraining", 1);
	TF2_AddCondition(client, TFCond_DefenseBuffMmmph, 2.7);
	TF2_AddCondition(client, TFCond_CritMmmph, 10.0);
	new bool:megaheal = TF2_IsPlayerInCondition(client, TFCond_MegaHeal);
	TF2_RemoveCondition(client, TFCond_MegaHeal);
	TF2_StunPlayer(client, 2.5, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
	if (megaheal) TF2_AddCondition(client, TFCond_MegaHeal, 0.1);
	if (GetClientHealth(client) < TF2_GetMaxHealth(client)) TF2_SetHealth(client, TF2_GetMaxHealth(client));
	decl String:sound[PLATFORM_MAX_PATH];
	new soundindex = GetRandomInt(1, 3);
	if (soundindex == 2) strcopy(sound, sizeof(sound), "vo/pyro_laughhappy01.wav");
	else Format(sound, sizeof(sound), "vo/pyro_paincrticialdeath0%d.wav", soundindex);
	EmitSoundToAll(sound, client);
}

stock DoEurekaTaunt(client)
{
	decl Float:vel[3];
	decl Float:pos[3];
	vel[0] = 0.0;
	vel[1] = 0.0;
	vel[2] = 0.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
	new bool:megaheal = TF2_IsPlayerInCondition(client, TFCond_MegaHeal);
	TF2_RemoveCondition(client, TFCond_MegaHeal);
	TF2_StunPlayer(client, 2.1, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);
	if (megaheal) TF2_AddCondition(client, TFCond_MegaHeal, 0.1);
//	EmitSoundToAll("weapons/drg_wrench_teleport.wav", client);
//	GetClientAbsOrigin(client, pos);
	EmitSoundToAll(")weapons/drg_wrench_teleport.wav", client, SNDCHAN_STATIC, 150, _, _, _, _, pos);
//-numClients 10 sample )weapons/drg_wrench_teleport.wav ent 0 channel 6 vol 1.00000 level 150 pitch 100 flags 0
//-numClients 9 sample )weapons/teleporter_send.wav ent 16 channel 6 vol 1.00000 level 74 pitch 100 flags 0
	CreateTimer(2.15, Timer_EurekaRespawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}
public Action:Timer_EurekaRespawn(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
	new Handle:message = StartMessageAll("PlayerTeleportHomeEffect");
	BfWriteByte(message, client);
	EndMessage();
	DoTeleportParticles(client);
/*	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		decl Float:pos[3];
		GetClientAbsOrigin(client, pos);
		pos[2] += 10.0;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		// set particle stuff
		decl String:effect_name[35];
		strcopy(effect_name, sizeof(effect_name), "drg_wrenchmotron_teleport");
		DispatchKeyValue(particle, "effect_name", effect_name);
		new startpoint = CreateEntityByName("info_particle_system");
		if (IsValidEntity(startpoint))
		{
			pos[2] += 950.0;
			TeleportEntity(startpoint, pos, NULL_VECTOR, NULL_VECTOR);
			decl String:controlpoint[9];
			FormatEx(controlpoint, sizeof(controlpoint), "target%i", startpoint);
			DispatchKeyValue(startpoint, "targetname", controlpoint);
			DispatchKeyValue(particle, "cpoint1", controlpoint);
			//Three more control points exist: 0 128 0, -128 0 0, and 0 -128 0; 0 0 1024 is this one.
		}
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "Start");
		new Handle:pack;
		CreateDataTimer(3.0, Timer_DeleteEurekaParticle, pack);//, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(pack, EntIndexToEntRef(particle));
		WritePackCell(pack, EntIndexToEntRef(startpoint));
	}*/
	CreateTimer(0.2, Timer_EurekaRespawn2, userid, TIMER_FLAG_NO_MAPCHANGE);
	//TF2_RespawnPlayer(client);
	return Plugin_Continue;
}
public Action:Timer_EurekaRespawn2(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
//	EmitSoundToAll("weapons/teleporter_send.wav", client);
	EmitSoundToAll(")weapons/teleporter_send.wav", client, SNDCHAN_STATIC, 74);
/*	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		decl Float:pos[3];
		GetClientAbsOrigin(client, pos);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		// set particle stuff
		decl String:effect_name[35];
		Format(effect_name, sizeof(effect_name), "teleported_%s", GetClientTeam(client) == (_:TFTeam_Blue) ? "blue" : "red");
		DispatchKeyValue(particle, "effect_name", effect_name);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "Start");
		new Handle:pack;
		CreateDataTimer(4.0, Timer_DeleteEurekaParticle, pack);//, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(pack, EntIndexToEntRef(particle));
		WritePackCell(pack, INVALID_ENT_REFERENCE);
	}*/
	TF2_RespawnPlayer(client);
	return Plugin_Continue;
}
public Action:Timer_DeleteEurekaParticle(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new particle = EntRefToEntIndex(ReadPackCell(pack));
	new startpoint = EntRefToEntIndex(ReadPackCell(pack));
	if (particle > MaxClients && IsValidEntity(particle)) AcceptEntityInput(particle, "Kill");
	if (startpoint > MaxClients && IsValidEntity(startpoint)) AcceptEntityInput(startpoint, "Kill");
	return Plugin_Continue;
}
public Action:Timer_TargeCharging(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client) || !TF2_IsPlayerInCondition(client, TFCond_Charging))
	{
		if (IsValidClient(client)) SetEntProp(client, Prop_Send, "m_iNextMeleeCrit", 0);
		return Plugin_Stop;
	}
	new Float:charge = GetEntPropFloat(client, Prop_Send, "m_flChargeMeter");
	if (charge <= 0)
	{
		SetEntProp(client, Prop_Send, "m_iNextMeleeCrit", 0);
		return Plugin_Stop;
	}
	if (GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 327) charge -= (0.1 / 2.0 * 100.0);
	else charge -= (0.1 / 1.5 * 100.0);
	if (charge <= 0) charge = 0.0;
	if (charge <= 33) SetEntProp(client, Prop_Send, "m_iNextMeleeCrit", 2);	//Full crit
	else if (charge <= 75) SetEntProp(client, Prop_Send, "m_iNextMeleeCrit", 1);	//Mini-crit
	SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", charge);
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 750.0);
	return Plugin_Continue;
}
public Action:Timer_TargeReset(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	DoResetChargeTimer(client, true);
}

stock DoResetChargeTimer(client, bool:end = false)
{
	ClearTimer(hTimers[client][ChargeTimer]);
	if (end && TF2_GetPlayerClass(client) != TFClass_DemoMan) hTimers[client][ChargeTimer] = CreateTimer(((GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 404) ? 6.0 : 12.0), Timer_TargeCharged, GetClientUserId(client));
}
public Action:Timer_TargeCharged(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	DoResetChargeTimer(client, false);
	if (IsValidClient(client))
	{
		EmitSoundToClient(client, "player/recharged.wav");
		SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
	}
}
public Action:Reload_Cooldown(Handle:timer, any:client)
{
	bCooldowns[client][ReloadCooldown] = false;
}

public CheckFood(client, buttons)
{
	decl String:weapon3[64];
	GetClientWeapon(client, weapon3, sizeof(weapon3));
	new sec = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (sec > MaxClients && IsValidEntity(sec))
	{
		new idx = GetEntProp(sec, Prop_Send, "m_iItemDefinitionIndex");
		if ((GetEntityFlags(client) & FL_ONGROUND) && StrEqual(weapon3, "tf_weapon_lunchbox") && TF2_GetPlayerClass(client) != TFClass_Heavy && !bCooldowns[client][EatCooldown] && !bCooldowns[client][LongEatCooldown])
		{
			new bool:megaheal = TF2_IsPlayerInCondition(client, TFCond_MegaHeal);
			TF2_RemoveCondition(client, TFCond_MegaHeal);
			TF2_StunPlayer(client, 3.8, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);
			if (megaheal) TF2_AddCondition(client, TFCond_MegaHeal, 0.1);
			if (idx == 42) SetSandvich(client);
//			if (idx == 159) SetDalokohs(client, false);
//			if (idx == 433) SetDalokohs(client, true);
			if (idx == 159 || idx == 433) SetDalokohs(client);//, true);
			if (idx == 311) SetSteak(client);
		}
		if (StrEqual(weapon3, "tf_weapon_lunchbox_drink") && TF2_GetPlayerClass(client) != TFClass_Scout)
		{
			if (bCooldowns[client][BonkCooldown] || !(GetEntityFlags(client) & FL_ONGROUND) || (idx == 46 && IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hItem"))))
			{
				buttons &= ~IN_ATTACK;
				return buttons;
			}
			bCooldowns[client][BonkCooldown] = true;
			hTimers[client][BonkTimer] = CreateTimer(31.2, Bonk_Cooldown, GetClientUserId(client));
			new bool:megaheal = TF2_IsPlayerInCondition(client, TFCond_MegaHeal);
			TF2_RemoveCondition(client, TFCond_MegaHeal);
			TF2_StunPlayer(client, 1.2, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);
			if (megaheal) TF2_AddCondition(client, TFCond_MegaHeal, 0.1);
			EmitSoundToAll("player/pl_scout_dodge_can_drink.wav", client);
			SetSpeshulAmmo(client, 1, 0);
			if (idx == 46) TF2_AddCondition(client, TFCond_Bonked, 9.2);
			if (idx == 163) TF2_AddCondition(client, TFCond_CritCola, 9.2);
			SetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + 31.2);
		}
	}
	return buttons;
}

public CheckJars(client)
{
	decl String:weapon3[64];
	GetClientWeapon(client, weapon3, sizeof(weapon3));
	if ((StrEqual(weapon3, "tf_weapon_jar") && TF2_GetPlayerClass(client) != TFClass_Sniper) || (StrEqual(weapon3, "tf_weapon_jar_milk") && TF2_GetPlayerClass(client) != TFClass_Scout)  && !bCooldowns[client][JarCooldown])
	{
		bCooldowns[client][JarCooldown] = true;
		hTimers[client][JarTimer] = CreateTimer(20.0, Jar_Cooldown, GetClientUserId(client));
	}
}

public CheckBall(client)
{
	decl String:weapon3[64];
	GetClientWeapon(client, weapon3, sizeof(weapon3));
	if (GetSpeshulAmmo(client, TFWeaponSlot_Melee) > 0 && (StrEqual(weapon3, "tf_weapon_bat_wood") || StrEqual(weapon3, "tf_weapon_bat_giftwrap")) && TF2_GetPlayerClass(client) != TFClass_Scout && !bCooldowns[client][BallCooldown])
	{
		bCooldowns[client][BallCooldown] = true;
		hTimers[client][BallTimer] = CreateTimer(15.0, Ball_Cooldown, GetClientUserId(client));
	}
	if (GetSpeshulAmmo(client, TFWeaponSlot_Melee) > 0 && GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary) != -1)
	{
		new idx = GetEntProp(GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary), Prop_Send, "m_iItemDefinitionIndex");
		if (StrEqual(weapon3, "tf_weapon_lunchbox") && (idx == 42 || idx == 311) && TF2_GetPlayerClass(client) != TFClass_Heavy && !bCooldowns[client][EatCooldown] && !bCooldowns[client][LongEatCooldown])
		{
			bCooldowns[client][EatCooldown] = true;
			bCooldowns[client][LongEatCooldown] = true;
			hTimers[client][EatTimer] = CreateTimer(30.0, Eat_CooldownTime, GetClientUserId(client));
		}
	}
}

SetSandvich(client)
{
	CreateTimer(1.0, SetSandvichTimer, GetClientUserId(client), TIMER_REPEAT);
	bCooldowns[client][EatCooldown] = true;
	if (GetClientHealth(client) < TF2_GetMaxHealth(client))
	{
		hTimers[client][EatTimer] = CreateTimer(30.1, Eat_CooldownTime, GetClientUserId(client));
		bCooldowns[client][LongEatCooldown] = true;
		new mel = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if (!(IsValidEntity(mel) && GetEntProp(mel, Prop_Send, "m_iItemDefinitionIndex") == 44))
		{
			SetSpeshulAmmo(client, TFWeaponSlot_Secondary, 0);
			new sec = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if (IsValidEntity(sec)) SetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + 30.1);
		}
	}
	else hTimers[client][EatTimer] = CreateTimer(4.3, Eat_CooldownTime, GetClientUserId(client));
}

public Action:SetSandvichTimer(Handle:timer, any:userid)
{
	static NumPrinted[MAXPLAYERS + 1] = 0;
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		NumPrinted[client] = 0;
		return Plugin_Stop;
	}
	if (NumPrinted[client] == 0) EmitSoundToAll("vo/SandwichEat09.wav", client);
	if (NumPrinted[client]++ >= 4)
	{
		NumPrinted[client] = 0;
		return Plugin_Stop;
	}
	if (GetClientHealth(client) < TF2_GetMaxHealth(client) && (GetClientHealth(client) + 75) > TF2_GetMaxHealth(client))
	{
		TF2_SetHealth(client, TF2_GetMaxHealth(client));
//		NumPrinted[client] = 0;
		return Plugin_Continue; //Stop
	}
	else if (GetClientHealth(client) < TF2_GetMaxHealth(client) && (GetClientHealth(client) + 75) < TF2_GetMaxHealth(client))
	{
		TF2_SetHealth(client, (GetClientHealth(client) + 75));
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

SetDalokohs(client)//, bool:fishcake=false)
{
	CreateTimer(1.0, SetDalokohsTimer, GetClientUserId(client), TIMER_REPEAT);
	bCooldowns[client][EatCooldown] = true;
	if (!bDalokohsBuff[client])
	{
		new wep = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if (IsValidEntity(wep)) TF2Attrib_SetByName(wep, "hidden maxhealth non buffed", 50.0);
		bDalokohsBuff[client] = true;
//		GiveWeaponOfIndex(client, (fishcake ? 2433 : 2159));
//		bDalokohsBuff[client] = (fishcake ? 2 : 1);
	}
	ClearTimer(hTimers[client][DalokohsTimer]);
	hTimers[client][DalokohsTimer] = CreateTimer(30.1, DalokohsBuffTime, GetClientUserId(client));
/*	if (GetClientHealth(client) < TF2_GetMaxHealth(client))
	{
		EatCooldownTimer[client] = CreateTimer(30.1, Eat_CooldownTime, GetClientUserId(client));
		pLongEatCooldown[client] = true;
		if (!(IsValidEntity(GetPlayerWeaponSlot(client, TFWeaponSlot_Melee)) && GetEntProp(GetPlayerWeaponSlot(client, TFWeaponSlot_Melee), Prop_Send, "m_iItemDefinitionIndex") == 44)) SetSpeshulAmmo(client, 1, 0);
	}
	else*/ hTimers[client][EatTimer] = CreateTimer(4.3, Eat_CooldownTime, GetClientUserId(client));
}

//in case Valve changes it again? I guess?
#define DALOKOHS_HEALING 25
public Action:SetDalokohsTimer(Handle:timer, any:userid)
{
	static NumPrinted[MAXPLAYERS + 1] = 0;
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		NumPrinted[client] = 0;
		return Plugin_Stop;
	}
	if (NumPrinted[client] == 0) EmitSoundToAll("vo/SandwichEat09.wav", client);
	if (NumPrinted[client]++ >= 4)
	{
		NumPrinted[client] = 0;
		return Plugin_Stop;
	}
	if (GetClientHealth(client) < TF2_GetMaxHealth(client) && (GetClientHealth(client) + DALOKOHS_HEALING > TF2_GetMaxHealth(client)))
	{
		TF2_SetHealth(client, TF2_GetMaxHealth(client));
//		NumPrinted[client] = 0;
		return Plugin_Continue; //Stop
	}
	else if (GetClientHealth(client) < TF2_GetMaxHealth(client) && (GetClientHealth(client) + DALOKOHS_HEALING) < TF2_GetMaxHealth(client))
	{
		TF2_SetHealth(client, (GetClientHealth(client) + DALOKOHS_HEALING));
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

SetSteak(client)
{
	CreateTimer(1.0, SetSteakTimer, GetClientUserId(client));
	bCooldowns[client][EatCooldown] = true;
	if (GetClientHealth(client) < TF2_GetMaxHealth(client))
	{
		hTimers[client][EatTimer] = CreateTimer(30.1, Eat_CooldownTime, GetClientUserId(client));
		bCooldowns[client][LongEatCooldown] = true;
		new mel = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if (!(IsValidEntity(mel) && GetEntProp(mel, Prop_Send, "m_iItemDefinitionIndex") == 44))
		{
			SetSpeshulAmmo(client, TFWeaponSlot_Secondary, 0);
			new sec = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if (IsValidEntity(sec)) SetEntPropFloat(sec, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + 30.1);
		}
	}
	else hTimers[client][EatTimer] = CreateTimer(4.3, Eat_CooldownTime, GetClientUserId(client));
}
public Action:SetSteakTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		EmitSoundToAll("vo/SandwichEat09.wav", client);
		TF2_AddCondition(client, TFCond_CritCola, 15.0);
		SetEntPropFloat(client, Prop_Send, "m_flEnergyDrinkMeter", 250.0);
		TF2_AddCondition(client, TFCond_RestrictToMelee, 15.0);
		CreateTimer(2.9, SteakSwitchWepTimer, userid);
	}
}
public Action:SteakSwitchWepTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		new weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if (IsValidEntity(weapon)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}
public Action:Eat_CooldownTime(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (bCooldowns[client][EatCooldown])
	{
		bCooldowns[client][EatCooldown] = false;
		if (bCooldowns[client][LongEatCooldown])
		{
			if (IsValidClient(client))
			{
				PrintHintText(client, "[TF2Items]Randomizer: Your Food has Recharged");
				EmitSoundToClient(client, "player/recharged.wav");
			}
			bCooldowns[client][LongEatCooldown] = false;
		}
		if (GetSpeshulAmmo(client, TFWeaponSlot_Secondary) < 1) SetSpeshulAmmo(client, TFWeaponSlot_Secondary, 1);
	}
	hTimers[client][EatTimer] = INVALID_HANDLE;
}

public Action:DalokohsBuffTime(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (bDalokohsBuff[client])
	{
//		new bool:fishcake = (bDalokohsBuff[client] == 2);
		bDalokohsBuff[client] = false;
		if (IsValidClient(client))
		{
			new wep = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if (IsValidEntity(wep)) TF2Attrib_RemoveByName(wep, "hidden maxhealth non buffed");
//			new active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
//			GiveWeaponOfIndex(client, (fishcake ? 433 : 159));
//			if (IsValidEntity(active)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", active);
		}
	}
	if (GetSpeshulAmmo(client, TFWeaponSlot_Secondary) < 1) SetSpeshulAmmo(client, TFWeaponSlot_Secondary, 1);
	hTimers[client][DalokohsTimer] = INVALID_HANDLE;
}

public Action:Bonk_Cooldown(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (bCooldowns[client][BonkCooldown])
	{
		bCooldowns[client][BonkCooldown] = false;
		if (IsValidClient(client))
		{
			PrintHintText(client, "[TF2Items]Randomizer: Your Drink has Recharged");
			EmitSoundToClient(client, "player/recharged.wav");
		}
	}
	if (GetSpeshulAmmo(client, TFWeaponSlot_Secondary) < 1) SetSpeshulAmmo(client, TFWeaponSlot_Secondary, 1);
	hTimers[client][BonkTimer] = INVALID_HANDLE;
}

public Action:Ball_Cooldown(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (bCooldowns[client][BallCooldown])
	{
		bCooldowns[client][BallCooldown] = false;
		if (IsValidClient(client))
		{
			PrintHintText(client, "[TF2Items]Randomizer: Your Ball has Recharged");
			EmitSoundToClient(client, "player/recharged.wav");
		}
	}
	if (GetSpeshulAmmo(client, TFWeaponSlot_Melee) < 1) SetSpeshulAmmo(client, TFWeaponSlot_Melee, 1);
	hTimers[client][BallTimer] = INVALID_HANDLE;
}

public Action:Jar_Cooldown(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	new valid = IsValidClient(client);
	if (bCooldowns[client][JarCooldown])
	{
		bCooldowns[client][JarCooldown] = false;
		if (valid)
		{
			PrintHintText(client, "[TF2Items]Randomizer: Your Jar has Recharged");
			EmitSoundToClient(client, "player/recharged.wav");
		}
	}
	if (valid && GetSpeshulAmmo(client, TFWeaponSlot_Secondary) < 1) SetSpeshulAmmo(client, TFWeaponSlot_Secondary, 1);
	hTimers[client][JarTimer] = INVALID_HANDLE;
}

/*public Action:timer_uncloak(Handle:event, any:client) {
	spy_status[client] = 1;
}*/

/*stock TF2_Ubercharge(client, bool:enable) {
	if (enable) {
//		EmitSoundToClient(client, "player/invulnerable_on.wav");
		TF2_AddCondition(client, TFCond_Ubercharged, Float:999999999);
	} else {
//		EmitSoundToClient(client, "player/invulnerable_off.wav");
		TF2_RemoveCondition(client, TFCond_Ubercharged);
	}
}

stock TF2_Kritzcharge(client, bool:enable) {
	if (enable) {
//		EmitSoundToClient(client, "weapons/weapon_crit_charged_on.wav");
		TF2_AddCondition(client, TFCond_Kritzkrieged, Float:999999999);
	} else {
//		EmitSoundToClient(client, "weapons/weapon_crit_charged_off.wav");
		TF2_RemoveCondition(client, TFCond_Kritzkrieged);
	}
}

stock TF2_MegaHealcharge(client, bool:enable) {
	if (enable) {
//		EmitSoundToClient(client, "weapons/weapon_crit_charged_on.wav");
		TF2_AddCondition(client, TFCond_MegaHeal, Float:999999999);
	} else {
//		EmitSoundToClient(client, "weapons/weapon_crit_charged_off.wav");
		TF2_RemoveCondition(client, TFCond_MegaHeal);
	}
}*/

stock SetSpeshulAmmo(client, wepslot, newAmmo)
{
	new weapon = GetPlayerWeaponSlot(client, wepslot);
	if (!IsValidEntity(weapon)) return;
	new type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (type < 0 || type > 31) return;
	SetEntProp(client, Prop_Send, "m_iAmmo", newAmmo, _, type);
}

stock GetSpeshulAmmo(client, wepslot)
{
	if (!IsValidClient(client)) return 0;
	new weapon = GetPlayerWeaponSlot(client, wepslot);
	if (!IsValidEntity(weapon)) return 0;
	new type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (type < 0 || type > 31) return 0;
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, type);
}

stock TF2_GetMetal(client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return 0;
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, 3);
}

stock TF2_SetMetal(client, metal)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return;
	SetEntProp(client, Prop_Send, "m_iAmmo", metal, _, 3);
}

//http://pastebin.com/U6vwXX57
/********************
 * Mersenne Twister *
 ********************
new mt_array[624];
new mt_index;

stock mt_srand(seed) {
	mt_array[0] = seed;
	for (new i = 1; i < 624; i++) mt_array[i] = ((mt_array[i - 1] ^ (mt_array[i - 1] >> 30)) * 0x6C078965 + 1) & 0xFFFFFFFF;
}*/

stock mt_rand(min, max) {
	return RoundToNearest(GetURandomFloat() * (max - min) + min);
}

/*stock _mt_getNext() {
	if (!mt_index) _mt_generate();
	new y = mt_array[mt_index];
	y ^= (y >> 11);
	y ^= (y << 7) & 0x9D2C5680;
	y ^= (y << 15) & 0xEFC60000;
	y ^= (y >> 18);
	mt_index = (mt_index + 1) % 624;
	return y;
}

stock _mt_generate() {
	for (new i = 0; i < 623; i++) {
		new y = (mt_array[i] & 0x80000000) + ((mt_array[i + 1] % 624) & 0x7FFFFFFF);
		mt_array[i] = mt_array[(i + 397) % 624] ^ (y >> 1);
		if (y % 2) mt_array[i] ^= 0x9908B0DF;
	}
}*/
public Action:TF2Items_OnGiveNamedItem(client, String:classname[], iItemDefinitionIndex, &Handle:hItem)		//STRANGE STUFF HAPPENS HERE
{
//	static Handle:hNewItem;
	if (!bCvarEnabled) return Plugin_Continue;
	decl String:formatBuffer[32];
	new weaponSlot;
	Format(formatBuffer, 32, "%d_%s", iItemDefinitionIndex, "slot");
	if (!GetTrieValue(hItemInfoTrie, formatBuffer, weaponSlot))
	{
		return Plugin_Continue;
	}
	if (weaponSlot >= 3)
	{
		return Plugin_Continue;
	}
	if (iRndWeapon[client][0] != -2 && iRndWeapon[client][weaponSlot] > 0)
	{
		return Plugin_Handled;
	}
	//UNNECESSARY BUT OK
	if (StrEqual(classname, "tf_weapon_wrench", false) || StrEqual(classname, "tf_weapon_robot_arm", false))
	{
		if (iRndWeapon[client][2] != 0)
		{
//			if (hItem != INVALID_HANDLE) CloseHandle(hItem);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;

/*	new ammotype = -1;
	new Handle:ammotypetrie = MakeAmmotypeTrie();
	if (!GetTrieValue(ammotypetrie, classname, ammotype)) ammotype = -1;
	if (ammotype != -2) return Plugin_Continue;
	if (hItem != INVALID_HANDLE)
	{
		if (hNewItem != INVALID_HANDLE) CloseHandle(hNewItem);
		new flags = TF2Items_GetFlags(hItem);
		hNewItem = TF2Items_CreateItem(flags|OVERRIDE_ATTRIBUTES);
		if (flags & OVERRIDE_CLASSNAME)
		{
			decl String:newClassname[64];
			TF2Items_GetClassname(hItem, newClassname, sizeof(newClassname));
			TF2Items_SetClassname(hNewItem, newClassname);
		}
		if (flags & OVERRIDE_ITEM_DEF) TF2Items_SetItemIndex(hNewItem, TF2Items_GetItemIndex(hItem));
		if (flags & OVERRIDE_ITEM_LEVEL) TF2Items_SetLevel(hNewItem, TF2Items_GetLevel(hItem));
		if (flags & OVERRIDE_ITEM_QUALITY) TF2Items_SetQuality(hNewItem, TF2Items_GetQuality(hItem));
		new attribs = TF2Items_GetNumAttributes(hItem);
		new numattribs = 0;
		for (new i = 0; i < attribs; i++)
		{
			if (TF2Items_GetAttributeId(hItem, i) != 80)
			{
				TF2Items_SetAttribute(hNewItem, numattribs, TF2Items_GetAttributeId(hItem, i), TF2Items_GetAttributeValue(hItem, i));
				numattribs++;
			}
		}
		TF2Items_SetAttribute(hNewItem, attribs, 80, 2.0);
		TF2Items_SetNumAttributes(hNewItem, attribs + 1);
		CloseHandle(hItem);
		hItem = hNewItem;
//		PrintToChatAll("1");
		return Plugin_Changed;
	}
	if (hNewItem != INVALID_HANDLE) CloseHandle(hNewItem);
	hNewItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
	TF2Items_SetAttribute(hNewItem, 0, 80, 2.0);
	TF2Items_SetNumAttributes(hNewItem, 1);
//	PrintToChatAll("2");
	hItem = hNewItem;
	return Plugin_Changed;*/
}
stock Handle:PrepareItemHandle(weaponLookupIndex, TFClassType:classbased = TFClass_Unknown)
{
	new String:formatBuffer[32];
	new String:weaponClassname[64];
	new weaponIndex;
	new weaponSlot;
	new weaponQuality;
	new weaponLevel;
	new String:weaponAttribs[256];

	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "classname");
	GetTrieString(hItemInfoTrie, formatBuffer, weaponClassname, 64);

	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "index");
	GetTrieValue(hItemInfoTrie, formatBuffer, weaponIndex);

	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "slot");
	GetTrieValue(hItemInfoTrie, formatBuffer, weaponSlot);

	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "quality");
	GetTrieValue(hItemInfoTrie, formatBuffer, weaponQuality);

	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "level");
	if (!GetTrieValue(hItemInfoTrie, formatBuffer, weaponLevel))
	{
		weaponLevel = 1;
	}

	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "attribs");
	GetTrieString(hItemInfoTrie, formatBuffer, weaponAttribs, 256);

	new String:weaponAttribsArray[32][32];
	new attribCount = ExplodeString(weaponAttribs, " ; ", weaponAttribsArray, 32, 32);

	new flags = OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF | OVERRIDE_ITEM_LEVEL | OVERRIDE_ITEM_QUALITY | OVERRIDE_ATTRIBUTES;
	if (strcmp(weaponClassname, "saxxy", false) != 0) flags |= FORCE_GENERATION;
	new Handle:hWeapon = TF2Items_CreateItem(flags);
//will switch this to use the FORCE_GENERATION bit later
	if (StrEqual(weaponClassname, "tf_weapon_shotgun", false)) strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_soldier");
	if (strcmp(weaponClassname, "tf_weapon_shotgun_hwg", false) == 0 || strcmp(weaponClassname, "tf_weapon_shotgun_pyro", false) == 0 || strcmp(weaponClassname, "tf_weapon_shotgun_soldier", false) == 0)
	{
		switch (classbased)
		{
			case TFClass_Heavy: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_hwg");
			case TFClass_Soldier: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_soldier");
			case TFClass_Pyro: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_pyro");
		}
/* 		switch (classbased)
		{
			case TFClass_Heavy, TFClass_Pyro, TFClass_Soldier:
			{
				strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun");
				TF2Items_SetFlags(hWeapon, TF2Items_GetFlags(hWeapon) & ~FORCE_GENERATION);
			}
		} */
	}
	if (strcmp(weaponClassname, "tf_weapon_shovel", false) == 0 && (weaponIndex == 154 || weaponIndex == 264) && classbased == TFClass_DemoMan)
	{
		strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_bottle");
	}
	// #if defined TF2ITEMSOLD
	// if (strcmp(weaponClassname, "saxxy", false) == 0)	//this line
	// {													//this line
//		if (weaponIndex == 423)
//		{
		// switch (classbased)								//these lines
		// {
			// case TFClass_Scout: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_bat");
			// case TFClass_Sniper: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_club");
			// case TFClass_Soldier: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shovel");
			// case TFClass_DemoMan: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_bottle");
			// case TFClass_Engineer: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_wrench");
			// case TFClass_Pyro: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_fireaxe");
			// case TFClass_Heavy: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_fireaxe");
			// case TFClass_Spy: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_knife");
			// case TFClass_Medic: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_bonesaw");
		// }
//pyro shotgun?
//		}
// /*		if (weaponLookupIndex == 199)
		// {
			// switch classbased:
			// {
				// case TFClass_Engineer: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_primary");
				// case TFClass_Soldier: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_soldier");
				// case TFClass_Heavy: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_hwg");
				// case TFClass_Pyro: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_pyro");
				// default: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_primary");
			// }
		// }*/
	// }													//this line
// #endif

	TF2Items_SetClassname(hWeapon, weaponClassname);
	TF2Items_SetItemIndex(hWeapon, weaponIndex);
	TF2Items_SetLevel(hWeapon, weaponLevel);
	TF2Items_SetQuality(hWeapon, weaponQuality);

	if (attribCount > 1) {
		new attrIdx;
		new Float:attrVal;
		TF2Items_SetNumAttributes(hWeapon, attribCount/2);
		new i2 = 0;
		for (new i = 0; i < attribCount; i+=2) {
			attrIdx = StringToInt(weaponAttribsArray[i]);
			if (attrIdx <= 0)
			{
				LogError("Tried to set attribute index to %d on weapon of index %d, attrib string was '%s', count was %d", attrIdx, weaponLookupIndex, weaponAttribs, attribCount);
				continue;
			}
			switch (attrIdx)
			{
				case 133, 143, 147, 152, 184, 185, 186, 192, 193, 194, 198, 211, 214, 227, 228, 229, 262, 294, 302, 372, 373, 374, 379, 381, 383, 403, 420:
				{
					attrVal = Float:StringToInt(weaponAttribsArray[i+1]);
				}
				default:
				{
					attrVal = StringToFloat(weaponAttribsArray[i+1]);
				}
			}
			TF2Items_SetAttribute(hWeapon, i2, attrIdx, attrVal);
			i2++;
		}
	} else {
		TF2Items_SetNumAttributes(hWeapon, 0);
	}
	FixForWeaponAmmo(hWeapon, classbased, weaponClassname, (attribCount/2 > 0) ? attribCount/2 : 0);
	return hWeapon;
}
stock FixForWeaponAmmo(Handle:hWeapon, TFClassType:class, String:classname[], attribs)
{
	if (class < TFClass_Unknown || class > TFClass_Engineer) return;
	if (attribs >= 16) return;
	new ammotype = GetAmmoType(classname);
	if (ammotype != 1 && ammotype != 2 && ammotype != -2) return;
	if (ammotype == -2)
	{
//		if (class == TFClass_Engineer) return;
//		TF2Items_SetAttribute(hWeapon, attribs, 80, 2.0);	//MUST ACCOUNT FOR GRU HERE EVENTUALLY, OK? I think I should just equip an invisible wearable that does it, actually. I think I shall.
//		TF2Items_SetNumAttributes(hWeapon, attribs + 1);
		return;
	}
	static classmaxs[TFClassType][3];
	if (classmaxs[TFClass_Scout][1] != 32)
	{
		classmaxs[TFClass_Scout][1] = 32;
		classmaxs[TFClass_Scout][2] = 36;
		classmaxs[TFClass_Sniper][1] = 25;
		classmaxs[TFClass_Sniper][2] = 75;
		classmaxs[TFClass_Soldier][1] = 20;
		classmaxs[TFClass_Soldier][2] = 32;
		classmaxs[TFClass_DemoMan][1] = 16;
		classmaxs[TFClass_DemoMan][2] = 24;
		classmaxs[TFClass_Medic][1] = 150;
		classmaxs[TFClass_Medic][2] = 150;
		classmaxs[TFClass_Heavy][1] = 200;
		classmaxs[TFClass_Heavy][2] = 32;
		classmaxs[TFClass_Pyro][1] = 200;
		classmaxs[TFClass_Pyro][2] = 32;
		classmaxs[TFClass_Spy][1] = 20;
		classmaxs[TFClass_Spy][2] = 24;
		classmaxs[TFClass_Engineer][1] = 32;
		classmaxs[TFClass_Engineer][2] = 200;
	}
	new Handle:hAmmoTrie = MakeAmmoTrie();
	new ammo;
	new attribute = 37;
	if (ammotype == 2) attribute = 25;
	if (!GetTrieValue(hAmmoTrie, classname, ammo)) return;
	TF2Items_SetAttribute(hWeapon, attribs, attribute, float(ammo)/float(classmaxs[class][ammotype]));
	TF2Items_SetNumAttributes(hWeapon, attribs + 1);
}
stock GetAmmoType(String:classname[])
{
	new Handle:ammotypetrie = MakeAmmotypeTrie();
	new ammotype = 0;
	if (!GetTrieValue(ammotypetrie, classname, ammotype)) return 0;
	return ammotype;
}
stock Handle:MakeAmmoTrie(bool:remake = false)
{
	static Handle:hTrie = INVALID_HANDLE;
	if (remake)
	{
		CloseHandle(hTrie);
		hTrie = INVALID_HANDLE;
	}
	if (hTrie != INVALID_HANDLE) return hTrie;
	hTrie = CreateTrie();
	//scout
	SetTrieValue(hTrie, "tf_weapon_scattergun", 32);
	SetTrieValue(hTrie, "tf_weapon_handgun_scout_primary", 36);
	SetTrieValue(hTrie, "tf_weapon_handgun_scout_secondary", 36);
	SetTrieValue(hTrie, "tf_weapon_soda_popper", 32);
	SetTrieValue(hTrie, "tf_weapon_pep_brawler_blaster", 32);
	SetTrieValue(hTrie, "tf_weapon_pistol_scout", 36);
	SetTrieValue(hTrie, "tf_weapon_lunchbox_drink", 1);
	SetTrieValue(hTrie, "tf_weapon_jar_milk", 1);
	SetTrieValue(hTrie, "tf_weapon_cleaver", 1);
	SetTrieValue(hTrie, "tf_weapon_bat_wood", 1);
	SetTrieValue(hTrie, "tf_weapon_bat_giftwrap", 1);

	// Soldier
	SetTrieValue(hTrie, "tf_weapon_rocketlauncher", 20);
	SetTrieValue(hTrie, "tf_weapon_rocketlauncher_directhit", 20);
	SetTrieValue(hTrie, "tf_weapon_shotgun_soldier", 32);

	// Pyro
	SetTrieValue(hTrie, "tf_weapon_flamethrower", 200);
	SetTrieValue(hTrie, "tf_weapon_shotgun_pyro", 32);
	SetTrieValue(hTrie, "tf_weapon_flaregun", 32);

	// Demo
	SetTrieValue(hTrie, "tf_weapon_grenadelauncher", 16);
	SetTrieValue(hTrie, "tf_weapon_cannon", 16);
	SetTrieValue(hTrie, "tf_weapon_pipebomblauncher", 24);

	// Heavy
	SetTrieValue(hTrie, "tf_weapon_minigun", 200);
	SetTrieValue(hTrie, "tf_weapon_shotgun_hwg", 32);
	SetTrieValue(hTrie, "tf_weapon_lunchbox", 1);

	// Engineer
	SetTrieValue(hTrie, "tf_weapon_shotgun_primary", 32);
	SetTrieValue(hTrie, "tf_weapon_sentry_revenge", 32);
	SetTrieValue(hTrie, "tf_weapon_shotgun_building_rescue", 32);
	SetTrieValue(hTrie, "tf_weapon_pistol", 200);
	SetTrieValue(hTrie, "tf_weapon_mechanical_arm", 200);

	// Medic
	SetTrieValue(hTrie, "tf_weapon_syringegun_medic", 150);
	SetTrieValue(hTrie, "tf_weapon_crossbow", 150);

	// Sniper
	SetTrieValue(hTrie, "tf_weapon_sniperrifle", 25);
	SetTrieValue(hTrie, "tf_weapon_sniperrifle_decap", 25);
	SetTrieValue(hTrie, "tf_weapon_compound_bow", 25);
	SetTrieValue(hTrie, "tf_weapon_smg", 75);
	SetTrieValue(hTrie, "tf_weapon_jar", 1);

	// Spy
	SetTrieValue(hTrie, "tf_weapon_revolver", 24);

	return hTrie;
}
stock Handle:MakeAmmotypeTrie(bool:remake = false)
{
	static Handle:hTrie = INVALID_HANDLE;
	if (remake)
	{
		CloseHandle(hTrie);
		hTrie = INVALID_HANDLE;
	}
	if (hTrie != INVALID_HANDLE) return hTrie;
	hTrie = CreateTrie();
	//scout
	SetTrieValue(hTrie, "tf_weapon_scattergun", 1);
	SetTrieValue(hTrie, "tf_weapon_handgun_scout_primary", 2);
	SetTrieValue(hTrie, "tf_weapon_handgun_scout_secondary", 2);
	SetTrieValue(hTrie, "tf_weapon_soda_popper", 1);
	SetTrieValue(hTrie, "tf_weapon_pep_brawler_blaster", 1);
	SetTrieValue(hTrie, "tf_weapon_pistol_scout", 2);
	SetTrieValue(hTrie, "tf_weapon_lunchbox_drink", 5);
	SetTrieValue(hTrie, "tf_weapon_jar_milk", 5);
	SetTrieValue(hTrie, "tf_weapon_cleaver", 5);
	SetTrieValue(hTrie, "tf_weapon_bat_wood", 4);
	SetTrieValue(hTrie, "tf_weapon_bat_giftwrap", 4);

	// Soldier
	SetTrieValue(hTrie, "tf_weapon_rocketlauncher", 1);
	SetTrieValue(hTrie, "tf_weapon_rocketlauncher_directhit", 1);
	SetTrieValue(hTrie, "tf_weapon_shotgun_soldier", 2);

	// Pyro
	SetTrieValue(hTrie, "tf_weapon_flamethrower", 1);
	SetTrieValue(hTrie, "tf_weapon_shotgun_pyro", 2);
	SetTrieValue(hTrie, "tf_weapon_flaregun", 2);

	// Demo
	SetTrieValue(hTrie, "tf_weapon_grenadelauncher", 1);
	SetTrieValue(hTrie, "tf_weapon_cannon", 1);
	SetTrieValue(hTrie, "tf_weapon_pipebomblauncher", 2);

	// Heavy
	SetTrieValue(hTrie, "tf_weapon_minigun", 1);
	SetTrieValue(hTrie, "tf_weapon_shotgun_hwg", 2);
	SetTrieValue(hTrie, "tf_weapon_lunchbox", 4);

	// Engineer
	SetTrieValue(hTrie, "tf_weapon_shotgun_primary", 1);
	SetTrieValue(hTrie, "tf_weapon_sentry_revenge", 1);
	SetTrieValue(hTrie, "tf_weapon_shotgun_building_rescue", 1);
	SetTrieValue(hTrie, "tf_weapon_pistol", 2);
	SetTrieValue(hTrie, "tf_weapon_mechanical_arm", 3);

	// Medic
	SetTrieValue(hTrie, "tf_weapon_syringegun_medic", 1);
	SetTrieValue(hTrie, "tf_weapon_crossbow", 1);

	// Sniper
	SetTrieValue(hTrie, "tf_weapon_sniperrifle", 1);
	SetTrieValue(hTrie, "tf_weapon_sniperrifle_decap", 1);
	SetTrieValue(hTrie, "tf_weapon_compound_bow", 1);
	SetTrieValue(hTrie, "tf_weapon_smg", 2);
	SetTrieValue(hTrie, "tf_weapon_jar", 4);

	// Spy
	SetTrieValue(hTrie, "tf_weapon_revolver", 2);

	//Melee (for metal)
	SetTrieValue(hTrie, "tf_weapon_wrench", -2);
	SetTrieValue(hTrie, "tf_weapon_shovel", -2);
	SetTrieValue(hTrie, "tf_weapon_bottle", -2);
	SetTrieValue(hTrie, "tf_weapon_fists", -2);
	SetTrieValue(hTrie, "tf_weapon_bat", -2);
	SetTrieValue(hTrie, "tf_weapon_bonesaw", -2);
	SetTrieValue(hTrie, "tf_weapon_sword", -2);
	SetTrieValue(hTrie, "tf_weapon_fireaxe", -2);
	SetTrieValue(hTrie, "tf_weapon_robot_arm", -2);
	SetTrieValue(hTrie, "tf_weapon_bat_wood", -2);
	SetTrieValue(hTrie, "tf_weapon_club", -2);
	SetTrieValue(hTrie, "tf_weapon_bat_fish", -2);
	SetTrieValue(hTrie, "tf_weapon_stickbomb", -2);
	SetTrieValue(hTrie, "tf_weapon_knife", -2);
	SetTrieValue(hTrie, "saxxy", -2);
	return hTrie;
}
CreateItemInfoTrie()
{
	if (hItemInfoTrie != INVALID_HANDLE)
	{
		CloseHandle(hItemInfoTrie);
	}
	hItemInfoTrie = CreateTrie();
	AddCustomHardcodedToTrie(hItemInfoTrie);


}
stock AddCustomHardcodedToTrie(Handle:trie)
{
//bat
	SetTrieString(trie, "0_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "0_index", 0); 
	SetTrieValue(trie, "0_slot", 2); 
	SetTrieValue(trie, "0_quality", 0); 
	SetTrieValue(trie, "0_level", 1); 
	//SetTrieString(trie, "0_attribs", ""); 
	SetTrieValue(trie, "0_ammo", -1); 

//fire axe
	SetTrieString(trie, "2_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "2_index", 2); 
	SetTrieValue(trie, "2_slot", 2); 
	SetTrieValue(trie, "2_quality", 0); 
	SetTrieValue(trie, "2_level", 1); 
	//SetTrieString(trie, "2_attribs", "178 ; .5 ; 2 ; 1.5 ; 267 ; 1"); 
	SetTrieValue(trie, "2_ammo", -1); 

//kukri
	SetTrieString(trie, "3_classname", "tf_weapon_club"); 
	SetTrieValue(trie, "3_index", 3); 
	SetTrieValue(trie, "3_slot", 2); 
	SetTrieValue(trie, "3_quality", 0); 
	SetTrieValue(trie, "3_level", 1); 
	//SetTrieString(trie, "3_attribs", ""); 
	SetTrieValue(trie, "3_ammo", -1); 

//knife
	SetTrieString(trie, "4_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "4_index", 4); 
	SetTrieValue(trie, "4_slot", 2); 
	SetTrieValue(trie, "4_quality", 0); 
	SetTrieValue(trie, "4_level", 1); 
	//SetTrieString(trie, "4_attribs", "31 ; 3"); 
	SetTrieValue(trie, "4_ammo", -1); 

//fists
	SetTrieString(trie, "5_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "5_index", 5); 
	SetTrieValue(trie, "5_slot", 2); 
	SetTrieValue(trie, "5_quality", 0); 
	SetTrieValue(trie, "5_level", 1); 
	//SetTrieString(trie, "5_attribs", ""); 
	SetTrieValue(trie, "5_ammo", -1); 

//shovel
	SetTrieString(trie, "6_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "6_index", 6); 
	SetTrieValue(trie, "6_slot", 2); 
	SetTrieValue(trie, "6_quality", 0); 
	SetTrieValue(trie, "6_level", 1); 
	//SetTrieString(trie, "6_attribs", ""); 
	SetTrieValue(trie, "6_ammo", -1); 

//wrench
	SetTrieString(trie, "7_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "7_index", 7); 
	SetTrieValue(trie, "7_slot", 2); 
	SetTrieValue(trie, "7_quality", 0); 
	SetTrieValue(trie, "7_level", 1); 
	//SetTrieString(trie, "7_attribs", "6 ; 0.35 ; 286 ; 3"); 
	SetTrieValue(trie, "7_ammo", -1); 

//bonesaw
	SetTrieString(trie, "8_classname", "tf_weapon_bonesaw"); 
	SetTrieValue(trie, "8_index", 8); 
	SetTrieValue(trie, "8_slot", 2); 
	SetTrieValue(trie, "8_quality", 0); 
	SetTrieValue(trie, "8_level", 1); 
	//SetTrieString(trie, "8_attribs", "6 ; 0.8 ; 149 ; 30"); 
	SetTrieValue(trie, "8_ammo", -1); 

//shotgun engineer
	SetTrieString(trie, "9_classname", "tf_weapon_shotgun_primary"); //); 
	SetTrieValue(trie, "9_index", 9); 
	SetTrieValue(trie, "9_slot", 0); 
	SetTrieValue(trie, "9_quality", 0); 
	SetTrieValue(trie, "9_level", 1); 
	//SetTrieString(trie, "9_attribs", "4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5"); 
	SetTrieValue(trie, "9_ammo", 32); 

//shotgun soldier
	SetTrieString(trie, "10_classname", "tf_weapon_shotgun_soldier"); //); 
	SetTrieValue(trie, "10_index", 10); 
	SetTrieValue(trie, "10_slot", 1); 
	SetTrieValue(trie, "10_quality", 0); 
	SetTrieValue(trie, "10_level", 1); 
	//SetTrieString(trie, "10_attribs", "4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5"); 
	SetTrieValue(trie, "10_ammo", 32); 

//shotgun heavy
	SetTrieString(trie, "11_classname", "tf_weapon_shotgun_hwg"); //); 
	SetTrieValue(trie, "11_index", 11); 
	SetTrieValue(trie, "11_slot", 1); 
	SetTrieValue(trie, "11_quality", 0); 
	SetTrieValue(trie, "11_level", 1); 
	//SetTrieString(trie, "11_attribs", "4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5"); 
	SetTrieValue(trie, "11_ammo", 32); 

//shotgun pyro
	SetTrieString(trie, "12_classname", "tf_weapon_shotgun_pyro"); //); 
	SetTrieValue(trie, "12_index", 12); 
	SetTrieValue(trie, "12_slot", 1); 
	SetTrieValue(trie, "12_quality", 0); 
	SetTrieValue(trie, "12_level", 1); 
	//SetTrieString(trie, "12_attribs", "4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5"); 
	SetTrieValue(trie, "12_ammo", 32); 

//scattergun
	SetTrieString(trie, "13_classname", "tf_weapon_scattergun"); 
	SetTrieValue(trie, "13_index", 13); 
	SetTrieValue(trie, "13_slot", 0); 
	SetTrieValue(trie, "13_quality", 0); 
	SetTrieValue(trie, "13_level", 1); 
	//SetTrieString(trie, "13_attribs", "97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8"); 
	SetTrieValue(trie, "13_ammo", 32); 

//sniper rifle
	SetTrieString(trie, "14_classname", "tf_weapon_sniperrifle"); 
	SetTrieValue(trie, "14_index", 14); 
	SetTrieValue(trie, "14_slot", 0); 
	SetTrieValue(trie, "14_quality", 0); 
	SetTrieValue(trie, "14_level", 1); 
	//SetTrieString(trie, "14_attribs", "41 ; 5"); 
	SetTrieValue(trie, "14_ammo", 25); 

//minigun
	SetTrieString(trie, "15_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "15_index", 15); 
	SetTrieValue(trie, "15_slot", 0); 
	SetTrieValue(trie, "15_quality", 0); 
	//SetTrieValue(trie, "15_level", 1); 
	SetTrieString(trie, "15_attribs","76;5 ; 6;.9 ; 16;20" );

//smg
	SetTrieString(trie, "16_classname", "tf_weapon_smg"); 
	SetTrieValue(trie, "16_index", 16); 
	SetTrieValue(trie, "16_slot", 1); 
	SetTrieValue(trie, "16_quality", 0); 
	SetTrieValue(trie, "16_level", 1); 
	//SetTrieString(trie, "16_attribs","6;0.3 ; 1;0.6 ; 78;8 ; 4;3" );
	SetTrieValue(trie, "16_ammo", 75); 

//syringe gun
	SetTrieString(trie, "17_classname", "tf_weapon_syringegun_medic"); 
	SetTrieValue(trie, "17_index", 17); 
	SetTrieValue(trie, "17_slot", 0); 
	SetTrieValue(trie, "17_quality", 0); 
	SetTrieValue(trie, "17_level", 1); 
	//SetTrieString(trie, "17_attribs", "6 ; 0.7 ; 17 ; 0.05 ; 76 ; 3"); 
	SetTrieValue(trie, "17_ammo", 150); 

//rocket launcher
	SetTrieString(trie, "18_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "18_index", 18); 
	SetTrieValue(trie, "18_slot", 0); 
	SetTrieValue(trie, "18_quality", 0); 
	SetTrieValue(trie, "18_level", 1); 
	//SetTrieString(trie, "18_attribs","104;0.32 ; 99;1 ; 2;5 ; 97;1.4 ; 3;0.25 ; 15;1" );
	SetTrieValue(trie, "18_ammo", 20); 

//grenade launcher
	SetTrieString(trie, "19_classname", "tf_weapon_grenadelauncher"); 
	SetTrieValue(trie, "19_index", 19); 
	SetTrieValue(trie, "19_slot", 0); 
	SetTrieValue(trie, "19_quality", 0); 
	SetTrieValue(trie, "19_level", 1); 
	//SetTrieString(trie, "19_attribs","411;10 ; 4;4 ; 76;10 ; 413;1 ; 417;1 ; 394;0.08 ; 241;0.5 ; 15;1 ; 470;0.5" );
	SetTrieValue(trie, "19_ammo", 150); 
	
//sticky launcher
	SetTrieString(trie, "20_classname", "tf_weapon_pipebomblauncher"); 
	SetTrieValue(trie, "20_index", 20); 
	SetTrieValue(trie, "20_slot", 1); 
	SetTrieValue(trie, "20_quality", 0); 
	SetTrieValue(trie, "20_level", 1); 
	//SetTrieString(trie, "20_attribs","96;0.5 ; 78;10 ; 6;0.3" );
	SetTrieValue(trie, "20_ammo", 100); 

//flamethrower
	SetTrieString(trie, "21_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "21_index", 21); 
	SetTrieValue(trie, "21_slot", 0); 
	SetTrieValue(trie, "21_quality", 0); 
	SetTrieValue(trie, "21_level", 1); 
	//SetTrieString(trie, "21_attribs","171;0.25 ; 256;0.1 ; 254;4" ); 
	SetTrieValue(trie, "21_ammo", 200); 

//pistol engineer
	SetTrieString(trie, "22_classname", "tf_weapon_pistol"); 
	SetTrieValue(trie, "22_index", 22); 
	SetTrieValue(trie, "22_slot", 1); 
	SetTrieValue(trie, "22_quality", 0); 
	SetTrieValue(trie, "22_level", 1); 
	//SetTrieString(trie, "22_attribs", "97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05"); 
	SetTrieValue(trie, "22_ammo", 200); 

//pistol scout
	SetTrieString(trie, "23_classname", "tf_weapon_pistol_scout"); 
	SetTrieValue(trie, "23_index", 23); 
	SetTrieValue(trie, "23_slot", 1); 
	SetTrieValue(trie, "23_quality", 0); 
	SetTrieValue(trie, "23_level", 1); 
	//SetTrieString(trie, "23_attribs", "97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05"); 

//revolver
	SetTrieString(trie, "24_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "24_index", 24); 
	SetTrieValue(trie, "24_slot", 0); 
	SetTrieValue(trie, "24_quality", 0); 
	SetTrieValue(trie, "24_level", 1); 
	//SetTrieString(trie, "24_attribs", "6 ; 0.3 ; 78 ; 5"); 
	SetTrieValue(trie, "24_ammo", 24); 

//build pda engineer
	SetTrieString(trie, "25_classname", "tf_weapon_pda_engineer_build"); 
	SetTrieValue(trie, "25_index", 25); 
	SetTrieValue(trie, "25_slot", 3); 
	SetTrieValue(trie, "25_quality", 0); 
	SetTrieValue(trie, "25_level", 1); 
	//SetTrieString(trie, "25_attribs", ""); 
	SetTrieValue(trie, "25_ammo", -1); 

//destroy pda engineer
	SetTrieString(trie, "26_classname", "tf_weapon_pda_engineer_destroy"); 
	SetTrieValue(trie, "26_index", 26); 
	SetTrieValue(trie, "26_slot", 4); 
	SetTrieValue(trie, "26_quality", 0); 
	SetTrieValue(trie, "26_level", 1); 
	//SetTrieString(trie, "26_attribs", ""); 
	SetTrieValue(trie, "26_ammo", -1); 

//disguise kit spy
	SetTrieString(trie, "27_classname", "tf_weapon_pda_spy"); 
	SetTrieValue(trie, "27_index", 27); 
	SetTrieValue(trie, "27_slot", 3); 
	SetTrieValue(trie, "27_quality", 0); 
	SetTrieValue(trie, "27_level", 1); 
	//SetTrieString(trie, "27_attribs", ""); 
	SetTrieValue(trie, "27_ammo", -1); 

//builder
	SetTrieString(trie, "28_classname", "tf_weapon_builder"); 
	SetTrieValue(trie, "28_index", 28); 
	SetTrieValue(trie, "28_slot", 5); 
	SetTrieValue(trie, "28_quality", 0); 
	SetTrieValue(trie, "28_level", 1); 
	//SetTrieString(trie, "28_attribs", ""); 
	SetTrieValue(trie, "28_ammo", -1); 

//medigun
	SetTrieString(trie, "29_classname", "tf_weapon_medigun"); 
	SetTrieValue(trie, "29_index", 29); 
	SetTrieValue(trie, "29_slot", 1); 
	SetTrieValue(trie, "29_quality", 0); 
	SetTrieValue(trie, "29_level", 1); 
	//SetTrieString(trie, "29_attribs","314;2 ; 11;3 ; 26;100" );
	SetTrieValue(trie, "29_ammo", -1); 

//invis watch
	SetTrieString(trie, "30_classname", "tf_weapon_invis"); 
	SetTrieValue(trie, "30_index", 30); 
	SetTrieValue(trie, "30_slot", 4); 
	SetTrieValue(trie, "30_quality", 0); 
	SetTrieValue(trie, "30_level", 1); 
	//SetTrieString(trie, "30_attribs", "128 ; 1 ; 107 ; 3 ; 35 ; 5 ; 34 ; 0.5"); 
	SetTrieValue(trie, "30_ammo", -1); 

/*flaregun engineerpistol
	SetTrieString(trie, "31_classname", "tf_weapon_flaregun"); 
	SetTrieValue(trie, "31_index", 31); 
	SetTrieValue(trie, "31_slot", 1); 
	SetTrieValue(trie, "31_quality", 0); 
	SetTrieValue(trie, "31_level", 1); 
	SetTrieString(trie, "31_attribs", ""); 
	SetTrieValue(trie, "31_ammo", 16); */

//Sapper
	SetTrieString(trie, "735_classname", "tf_weapon_builder"); 
	SetTrieValue(trie, "735_index", 735); 
	SetTrieValue(trie, "735_slot", 1); 
	SetTrieValue(trie, "735_quality", 0); 
	SetTrieValue(trie, "735_level", 1); 
	//SetTrieString(trie, "735_attribs", ""); 
	SetTrieValue(trie, "735_ammo", -1); 

//Upgradeable Sapper
	SetTrieString(trie, "736_classname", "tf_weapon_builder"); 
	SetTrieValue(trie, "736_index", 736); 
	SetTrieValue(trie, "736_slot", 1); 
	SetTrieValue(trie, "736_quality", 6); 
	SetTrieValue(trie, "736_level", 1); 
	//SetTrieString(trie, "736_attribs", "292 ;24"); 
	SetTrieValue(trie, "736_ammo", -1); 

//Upgradeable build pda engineer
	SetTrieString(trie, "737_classname", "tf_weapon_pda_engineer_build"); 
	SetTrieValue(trie, "737_index", 737); 
	SetTrieValue(trie, "737_slot", 3); 
	SetTrieValue(trie, "737_quality", 6); 
	SetTrieValue(trie, "737_level", 1); 
	//SetTrieString(trie, "737_attribs", ""); 
	SetTrieValue(trie, "737_ammo", -1); 

//kritzkrieg
	SetTrieString(trie, "35_classname", "tf_weapon_medigun"); 
	SetTrieValue(trie, "35_index", 35); 
	SetTrieValue(trie, "35_slot", 1); 
	SetTrieValue(trie, "35_quality", 6); 
	SetTrieValue(trie, "35_level", 8); 
	//SetTrieString(trie, "35_attribs","18;1 ; 10;3 ; 26;100" ); 
	SetTrieValue(trie, "35_ammo", -1); 

//blutsauger
	SetTrieString(trie, "36_classname", "tf_weapon_syringegun_medic"); 
	SetTrieValue(trie, "36_index", 36); 
	SetTrieValue(trie, "36_slot", 0); 
	SetTrieValue(trie, "36_quality", 6); 
	SetTrieValue(trie, "36_level", 5); 
	//SetTrieString(trie, "36_attribs", "16 ; 30 ; 180 ; 150"); 
	SetTrieValue(trie, "36_ammo", 150); 

//ubersaw
	SetTrieString(trie, "37_classname", "tf_weapon_bonesaw"); 
	SetTrieValue(trie, "37_index", 37); 
	SetTrieValue(trie, "37_slot", 2); 
	SetTrieValue(trie, "37_quality", 6); 
	SetTrieValue(trie, "37_level", 10); 
	//SetTrieString(trie, "37_attribs", "5 ; 2 ; 17 ; 1"); 
	SetTrieValue(trie, "37_ammo", -1); 

//axetinguisher
	SetTrieString(trie, "38_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "38_index", 38); 
	SetTrieValue(trie, "38_slot", 2); 
	SetTrieValue(trie, "38_quality", 6); 
	SetTrieValue(trie, "38_level", 10); 
	//SetTrieString(trie, "38_attribs", "20 ; 1 ; 21 ; 0 ; 22 ; 1 ; 2 ; 1.5"); 
	SetTrieValue(trie, "38_ammo", -1); 

//flaregun pyro
	SetTrieString(trie, "39_classname", "tf_weapon_flaregun"); 
	SetTrieValue(trie, "39_index", 39); 
	SetTrieValue(trie, "39_slot", 1); 
	SetTrieValue(trie, "39_quality", 6); 
	SetTrieValue(trie, "39_level", 10); 
	//SetTrieString(trie, "39_attribs", "6 ; 0.25 ; 78 ; 3");
	SetTrieValue(trie, "39_ammo", 16); 

//backburner
	SetTrieString(trie, "40_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "40_index", 40); 
	SetTrieValue(trie, "40_slot", 0); 
	SetTrieValue(trie, "40_quality", 6); 
//	SetTrieString(trie, "40_attribs", "23 ;1.0 ;24 ;1.0 ;28 ;0.0 ;2 ;1.15"); 	//these are the old backburner attribs (before april 14th, 2011)
//	SetTrieString(trie, "40_attribs", "170 ;2.5 ;24 ;1.0 ;28 ;0.0 ;2 ;1.10"); 	//old pyromania jun 27 2012
	//SetTrieString(trie, "40_attribs","255;2 ; 256;2 ; 24;1 ; 162;1.5 ; 164;1.5" );
	SetTrieValue(trie, "40_ammo", 200); 

//natascha
	SetTrieString(trie, "41_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "41_index", 41); 
	SetTrieValue(trie, "41_slot", 0); 
	SetTrieValue(trie, "41_quality", 6); 
	SetTrieValue(trie, "41_level", 5); 
	//SetTrieString(trie, "41_attribs","32;2 ; 1;0.66 ; 76;10 ; 6;.1 ; 106;5" );
	SetTrieValue(trie, "41_ammo", 200); 

//sandvich
	SetTrieString(trie, "42_classname", "tf_weapon_lunchbox"); 
	SetTrieValue(trie, "42_index", 42); 
	SetTrieValue(trie, "42_slot", 1); 
	SetTrieValue(trie, "42_quality", 6); 
	SetTrieValue(trie, "42_level", 1); 
	//SetTrieString(trie, "42_attribs", "200 ; 1 ; 144 ; 3"); 
	SetTrieValue(trie, "42_ammo", 1); 

//killing gloves of boxing
	SetTrieString(trie, "43_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "43_index", 43); 
	SetTrieValue(trie, "43_slot", 2); 
	SetTrieValue(trie, "43_quality", 6); 
	SetTrieValue(trie, "43_level", 7); 
	//SetTrieString(trie, "43_attribs", "31 ; 30 ; 107 ; 1.3 ; 128 ; 1 ; 2 ; 2 ; 5 ; 1.5"); 
	SetTrieValue(trie, "43_ammo", -1); 

//sandman
	SetTrieString(trie, "44_classname", "tf_weapon_bat_wood"); 
	SetTrieValue(trie, "44_index", 44); 
	SetTrieValue(trie, "44_slot", 2); 
	SetTrieValue(trie, "44_quality", 6); 
	SetTrieValue(trie, "44_level", 15); 
	//SetTrieString(trie, "44_attribs","278;.25 ; 279;3 ; 38;1" );
	SetTrieValue(trie, "44_ammo", 1); 

//bonk atomic punch
	SetTrieString(trie, "46_classname", "tf_weapon_lunchbox_drink"); 
	SetTrieValue(trie, "46_index", 46); 
	SetTrieValue(trie, "46_slot", 1); 
	SetTrieValue(trie, "46_quality", 6); 
	SetTrieValue(trie, "46_level", 5); 
	//SetTrieString(trie, "46_attribs", ""); 
	SetTrieValue(trie, "46_ammo", 1); 

//huntsman
	SetTrieString(trie, "56_classname", "tf_weapon_compound_bow"); 
	SetTrieValue(trie, "56_index", 56); 
	SetTrieValue(trie, "56_slot", 0); 
	SetTrieValue(trie, "56_quality", 6); 
	SetTrieValue(trie, "56_level", 10); 
	//SetTrieString(trie, "56_attribs", "76 ; 3 ; 318 ; 0.5 ; 1 ; 0.8"); 
	SetTrieValue(trie, "56_ammo", 12); 

//razorback (broken NO LONGER)
	SetTrieString(trie, "57_classname", "tf_wearable"); 
	SetTrieValue(trie, "57_index", 57); 
	SetTrieValue(trie, "57_slot", 1); 
	SetTrieValue(trie, "57_quality", 6); 
	SetTrieValue(trie, "57_level", 10); 
	//SetTrieString(trie, "57_attribs", "52 ;1 ;292 ;5.0"); 

//jarate
	SetTrieString(trie, "58_classname", "tf_weapon_jar"); 
	SetTrieValue(trie, "58_index", 58); 
	SetTrieValue(trie, "58_slot", 1); 
	SetTrieValue(trie, "58_quality", 6); 
	SetTrieValue(trie, "58_level", 5); 
	//SetTrieString(trie, "58_attribs","278;.40 ; 279;3 ; 99;3" );
	SetTrieValue(trie, "58_ammo", 1); 

//dead ringer
	SetTrieString(trie, "59_classname", "tf_weapon_invis"); 
	SetTrieValue(trie, "59_index", 59); 
	SetTrieValue(trie, "59_slot", 4); 
	SetTrieValue(trie, "59_quality", 6); 
	SetTrieValue(trie, "59_level", 5); 
	//SetTrieString(trie, "59_attribs", "33 ; 1 ; 34 ; .9 ; 35 ; 5 ; 292 ; 9"); 
	SetTrieValue(trie, "59_ammo", -1); 

//cloak and dagger
	SetTrieString(trie, "60_classname", "tf_weapon_invis"); 
	SetTrieValue(trie, "60_index", 60); 
	SetTrieValue(trie, "60_slot", 4); 
	SetTrieValue(trie, "60_quality", 6); 
	SetTrieValue(trie, "60_level", 5); 
	//SetTrieString(trie, "60_attribs", "48 ; 2 ; 35 ; 5"); 
	SetTrieValue(trie, "60_ammo", -1); 

//ambassador
	SetTrieString(trie, "61_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "61_index", 61); 
	SetTrieValue(trie, "61_slot", 0); 
	SetTrieValue(trie, "61_quality", 6); 
	SetTrieValue(trie, "61_level", 5); 
	//SetTrieString(trie, "61_attribs","51;1 ; 5;2 ; 2;2 ; 392;0.05" );
	SetTrieValue(trie, "61_ammo", 24); 

//direct hit
	SetTrieString(trie, "127_classname", "tf_weapon_rocketlauncher_directhit"); 
	SetTrieValue(trie, "127_index", 127); 
	SetTrieValue(trie, "127_slot", 0); 
	SetTrieValue(trie, "127_quality", 6); 
	SetTrieValue(trie, "127_level", 1); 
	//SetTrieString(trie, "127_attribs", "103 ; 3.5 ; 100 ; 0.01 ; 2 ; 3 ; 114 ; 1"); 
	SetTrieValue(trie, "127_ammo", 20); 

//equalizer
	SetTrieString(trie, "128_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "128_index", 128); 
	SetTrieValue(trie, "128_slot", 2); 
	SetTrieValue(trie, "128_quality", 6); 
	SetTrieValue(trie, "128_level", 10); 
	//SetTrieString(trie, "128_attribs", "2 ; 3.5 ; 128 ; 1"); 
	SetTrieValue(trie, "128_ammo", -1); 

//buff banner
	SetTrieString(trie, "129_classname", "tf_weapon_buff_item"); 
	SetTrieValue(trie, "129_index", 129); 
	SetTrieValue(trie, "129_slot", 1); 
	SetTrieValue(trie, "129_quality", 6); 
	SetTrieValue(trie, "129_level", 5); 
	//SetTrieString(trie, "129_attribs","116;1 ; 357;3" );
	SetTrieValue(trie, "129_ammo", -1); 

//scottish resistance
	SetTrieString(trie, "130_classname", "tf_weapon_pipebomblauncher"); 
	SetTrieValue(trie, "130_index", 130); 
	SetTrieValue(trie, "130_slot", 1); 
	SetTrieValue(trie, "130_quality", 6); 
	SetTrieValue(trie, "130_level", 5); 
	//SetTrieString(trie, "130_attribs", "119 ; 1 ; 4 ; 4 ; 76 ; 10 ; 121 ; 1 ; 78 ; 3 ; 88 ; 60 ; 120 ; .6 ; 96 ; 0.5 ; 6 ; 0.5"); 
	SetTrieValue(trie, "130_ammo", 36); 

//chargin targe (broken NO LONGER)
	SetTrieString(trie, "131_classname", "tf_wearable_demoshield"); 
	SetTrieValue(trie, "131_index", 131); 
	SetTrieValue(trie, "131_slot", 1); 
	SetTrieValue(trie, "131_quality", 6); 
	SetTrieValue(trie, "131_level", 10); 
	//SetTrieString(trie, "131_attribs","60;0.1 ; 64;0.1 ; 527;1" );

//eyelander
	SetTrieString(trie, "132_classname", "tf_weapon_sword"); 
	SetTrieValue(trie, "132_index", 132); 
	SetTrieValue(trie, "132_slot", 2); 
	SetTrieValue(trie, "132_quality", 6); 
	SetTrieValue(trie, "132_level", 5); 
	//SetTrieString(trie, "132_attribs","26;75 ; 107;1.1 ; 292;6 ; 388;6 ; 219;1" );
	SetTrieValue(trie, "132_ammo", -1); 

//gunboats (broken NO LONGER)
	SetTrieString(trie, "133_classname", "tf_wearable"); 
	SetTrieValue(trie, "133_index", 133); 
	SetTrieValue(trie, "133_slot", 1); 
	SetTrieValue(trie, "133_quality", 6); 
	SetTrieValue(trie, "133_level", 10); 
	//SetTrieString(trie, "133_attribs","135;0 ; 275;1 ; 112;0.05 ; 107;1.25" );

//wrangler
	SetTrieString(trie, "140_classname", "tf_weapon_laser_pointer"); 
	SetTrieValue(trie, "140_index", 140); 
	SetTrieValue(trie, "140_slot", 1); 
	SetTrieValue(trie, "140_quality", 6); 
	SetTrieValue(trie, "140_level", 5); 
	//SetTrieString(trie, "140_attribs", ""); 
	SetTrieValue(trie, "140_ammo", -1); 

//frontier justice
	SetTrieString(trie, "141_classname", "tf_weapon_sentry_revenge"); 
	SetTrieValue(trie, "141_index", 141); 
	SetTrieValue(trie, "141_slot", 0); 
	SetTrieValue(trie, "141_quality", 6); 
	SetTrieValue(trie, "141_level", 5); 
	//SetTrieString(trie, "141_attribs", "136 ; 1 ; 15 ; 1 ; 3 ; 0.75"); 
	SetTrieValue(trie, "141_ammo", 32); 

//gunslinger
	SetTrieString(trie, "142_classname", "tf_weapon_robot_arm"); 
	SetTrieValue(trie, "142_index", 142); 
	SetTrieValue(trie, "142_slot", 2); 
	SetTrieValue(trie, "142_quality", 6); 
	SetTrieValue(trie, "142_level", 15); 
	//SetTrieString(trie, "142_attribs", "124 ; 1 ; 125 ; 250"); 
	SetTrieValue(trie, "142_ammo", -1); 

//homewrecker
	SetTrieString(trie, "153_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "153_index", 153); 
	SetTrieValue(trie, "153_slot", 2); 
	SetTrieValue(trie, "153_quality", 6); 
	SetTrieValue(trie, "153_level", 5); 
	//SetTrieString(trie, "153_attribs","137;10 ; 146;1 ; 169;0.1 ; 2;2 ; 252;0.01" );
	SetTrieValue(trie, "153_ammo", -1); 

//pain train
	SetTrieString(trie, "154_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "154_index", 154); 
	SetTrieValue(trie, "154_slot", 2); 
	SetTrieValue(trie, "154_quality", 6); 
	SetTrieValue(trie, "154_level", 5); 
	//SetTrieString(trie, "154_attribs", "68 ; 10 ; 67 ; 2"); 
	SetTrieValue(trie, "154_ammo", -1); 

//southern hospitality
	SetTrieString(trie, "155_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "155_index", 155); 
	SetTrieValue(trie, "155_slot", 2); 
	SetTrieValue(trie, "155_quality", 6); 
	SetTrieValue(trie, "155_level", 20); 
	//SetTrieString(trie, "155_attribs", "149 ; 30 ; 276 ; 1"); 
	SetTrieValue(trie, "155_ammo", -1); 

//dalokohs bar
	SetTrieString(trie, "159_classname", "tf_weapon_lunchbox"); 
	SetTrieValue(trie, "159_index", 159); 
	SetTrieValue(trie, "159_slot", 1); 
	SetTrieValue(trie, "159_quality", 6); 
	SetTrieValue(trie, "159_level", 1); 
	//SetTrieString(trie, "159_attribs", "139 ; 1"); 
	SetTrieValue(trie, "159_ammo", 1); 

//lugermorph
	SetTrieString(trie, "160_classname", "tf_weapon_pistol"); 
	SetTrieValue(trie, "160_index", 160); 
	SetTrieValue(trie, "160_slot", 1); 
	SetTrieValue(trie, "160_quality", 3); 
	SetTrieValue(trie, "160_level", 5); 
	//SetTrieString(trie, "160_attribs", "97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05"); 
	SetTrieValue(trie, "160_ammo", 36); 

//big kill
	SetTrieString(trie, "161_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "161_index", 161); 
	SetTrieValue(trie, "161_slot", 0); 
	SetTrieValue(trie, "161_quality", 6); 
	SetTrieValue(trie, "161_level", 5); 
	//SetTrieString(trie, "161_attribs", "6 ; 0.3 ; 78 ; 5"); 
	SetTrieValue(trie, "161_ammo", 24); 

//crit a cola
	SetTrieString(trie, "163_classname", "tf_weapon_lunchbox_drink"); 
	SetTrieValue(trie, "163_index", 163); 
	SetTrieValue(trie, "163_slot", 1); 
	SetTrieValue(trie, "163_quality", 6); 
	SetTrieValue(trie, "163_level", 5); 
	//SetTrieString(trie, "163_attribs","278;.25 ; 144;2" );
	SetTrieValue(trie, "163_ammo", 1); 

//golden wrench
	SetTrieString(trie, "169_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "169_index", 169); 
	SetTrieValue(trie, "169_slot", 2); 
	SetTrieValue(trie, "169_quality", 6); 
	SetTrieValue(trie, "169_level", 25); 
	//SetTrieString(trie, "169_attribs", "6 ; 0.35 ; 286 ; 3 ; 150 ; 1"); 
	SetTrieValue(trie, "169_ammo", -1); 

//tribalmans shiv
	SetTrieString(trie, "171_classname", "tf_weapon_club"); 
	SetTrieValue(trie, "171_index", 171); 
	SetTrieValue(trie, "171_slot", 2); 
	SetTrieValue(trie, "171_quality", 6); 
	SetTrieValue(trie, "171_level", 5); 
	//SetTrieString(trie, "171_attribs", "149 ; 10 ; 208 ; 1"); 
	SetTrieValue(trie, "171_ammo", -1); 

//scotsmans skullcutter
	SetTrieString(trie, "172_classname", "tf_weapon_sword"); 
	SetTrieValue(trie, "172_index", 172); 
	SetTrieValue(trie, "172_slot", 2); 
	SetTrieValue(trie, "172_quality", 6); 
	SetTrieValue(trie, "172_level", 5); 
	//SetTrieString(trie, "172_attribs", "2 ;1.2 ;54 ;0.85"); 
	SetTrieValue(trie, "172_ammo", -1); 

//The Vita-Saw
	SetTrieString(trie, "173_classname", "tf_weapon_bonesaw"); 
	SetTrieValue(trie, "173_index", 173); 
	SetTrieValue(trie, "173_slot", 2); 
	SetTrieValue(trie, "173_quality", 6); 
	SetTrieValue(trie, "173_level", 5); 
	//SetTrieString(trie, "173_attribs","188;100 ; 125;100 ; 144;2" );
	SetTrieValue(trie, "173_ammo", -1); 

//Upgradeable bat
	SetTrieString(trie, "190_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "190_index", 190); 
	SetTrieValue(trie, "190_slot", 2); 
	SetTrieValue(trie, "190_quality", 6); 
	SetTrieValue(trie, "190_level", 1); 
	//SetTrieString(trie, "190_attribs", ""); 
	SetTrieValue(trie, "190_ammo", -1); 

//Upgradeable bottle
	SetTrieString(trie, "191_classname", "tf_weapon_bottle"); 
	SetTrieValue(trie, "191_index", 191); 
	SetTrieValue(trie, "191_slot", 2); 
	SetTrieValue(trie, "191_quality", 6); 
	SetTrieValue(trie, "191_level", 1); 
	//SetTrieString(trie, "191_attribs", "394 ; 0.35"); 
	SetTrieValue(trie, "191_ammo", -1); 

//Upgradeable fire axe
	SetTrieString(trie, "192_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "192_index", 192); 
	SetTrieValue(trie, "192_slot", 2); 
	SetTrieValue(trie, "192_quality", 6); 
	SetTrieValue(trie, "192_level", 1); 
	//SetTrieString(trie, "192_attribs", "178 ; .5 ; 2 ; 1.5 ; 267 ; 1"); 
	SetTrieValue(trie, "192_ammo", -1); 

//Upgradeable kukri
	SetTrieString(trie, "193_classname", "tf_weapon_club"); 
	SetTrieValue(trie, "193_index", 193); 
	SetTrieValue(trie, "193_slot", 2); 
	SetTrieValue(trie, "193_quality", 6); 
	SetTrieValue(trie, "193_level", 1); 
	//SetTrieString(trie, "193_attribs", ""); 
	SetTrieValue(trie, "193_ammo", -1); 

//Upgradeable knife
	SetTrieString(trie, "194_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "194_index", 194); 
	SetTrieValue(trie, "194_slot", 2); 
	SetTrieValue(trie, "194_quality", 6); 
	SetTrieValue(trie, "194_level", 1); 
	//SetTrieString(trie, "194_attribs", "31 ; 3"); 
	SetTrieValue(trie, "194_ammo", -1); 

//Upgradeable fists
	SetTrieString(trie, "195_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "195_index", 195); 
	SetTrieValue(trie, "195_slot", 2); 
	SetTrieValue(trie, "195_quality", 6); 
	SetTrieValue(trie, "195_level", 1); 
	//SetTrieString(trie, "195_attribs", ""); 
	SetTrieValue(trie, "195_ammo", -1); 

//Upgradeable shovel
	SetTrieString(trie, "196_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "196_index", 196); 
	SetTrieValue(trie, "196_slot", 2); 
	SetTrieValue(trie, "196_quality", 6); 
	SetTrieValue(trie, "196_level", 1); 
	//SetTrieString(trie, "196_attribs", ""); 
	SetTrieValue(trie, "196_ammo", -1); 

//Upgradeable wrench
	SetTrieString(trie, "197_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "197_index", 197); 
	SetTrieValue(trie, "197_slot", 2); 
	SetTrieValue(trie, "197_quality", 6); 
	SetTrieValue(trie, "197_level", 1); 
	//SetTrieString(trie, "197_attribs", "6 ; 0.35 ; 286 ; 3"); 
	SetTrieValue(trie, "197_ammo", -1); 

//Upgradeable bonesaw
	SetTrieString(trie, "198_classname", "tf_weapon_bonesaw"); 
	SetTrieValue(trie, "198_index", 198); 
	SetTrieValue(trie, "198_slot", 2); 
	SetTrieValue(trie, "198_quality", 6); 
	SetTrieValue(trie, "198_level", 1); 
	//SetTrieString(trie, "198_attribs", "6 ; 0.8 ; 149 ; 30"); 
	SetTrieValue(trie, "198_ammo", -1); 

//Upgradeable shotgun engineer
	SetTrieString(trie, "199_classname", "tf_weapon_shotgun_primary"); 
	SetTrieValue(trie, "199_index", 199); 
	SetTrieValue(trie, "199_slot", 0); 
	SetTrieValue(trie, "199_quality", 6); 
	SetTrieValue(trie, "199_level", 1); 
	//SetTrieString(trie, "199_attribs", "4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5"); 
	SetTrieValue(trie, "199_ammo", 32); 

/*Upgradeable shotgun other classes - appears in custom trie stuff below
	SetTrieString(trie, "4199_classname", "tf_weapon_shotgun_soldier"); 
	SetTrieValue(trie, "4199_index", 199); 
	SetTrieValue(trie, "4199_slot", 1); 
	SetTrieValue(trie, "4199_quality", 6); 
	SetTrieValue(trie, "4199_level", 1); 
	//SetTrieString(trie, "4199_attribs", ""); 
	SetTrieValue(trie, "4199_ammo", 32); */

//Upgradeable scattergun
	SetTrieString(trie, "200_classname", "tf_weapon_scattergun"); 
	SetTrieValue(trie, "200_index", 200); 
	SetTrieValue(trie, "200_slot", 0); 
	SetTrieValue(trie, "200_quality", 6); 
	SetTrieValue(trie, "200_level", 1); 
	//SetTrieString(trie, "200_attribs", "97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8"); 
	SetTrieValue(trie, "200_ammo", 32); 

//Upgradeable sniper rifle
	SetTrieString(trie, "201_classname", "tf_weapon_sniperrifle"); 
	SetTrieValue(trie, "201_index", 201); 
	SetTrieValue(trie, "201_slot", 0); 
	SetTrieValue(trie, "201_quality", 6); 
	SetTrieValue(trie, "201_level", 1); 
	//SetTrieString(trie, "201_attribs", "41 ; 5"); 
	SetTrieValue(trie, "201_ammo", 25); 

//Upgradeable minigun
	SetTrieString(trie, "202_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "202_index", 202); 
	SetTrieValue(trie, "202_slot", 0); 
	SetTrieValue(trie, "202_quality", 6); 
	SetTrieValue(trie, "202_level", 1); 
	//SetTrieString(trie, "202_attribs", "76 ; 5 ; 6 ; .9 ; 16 ; 20"); 
	SetTrieValue(trie, "202_ammo", 200); 

//Upgradeable smg
	SetTrieString(trie, "203_classname", "tf_weapon_smg"); 
	SetTrieValue(trie, "203_index", 203); 
	SetTrieValue(trie, "203_slot", 1); 
	SetTrieValue(trie, "203_quality", 6); 
	SetTrieValue(trie, "203_level", 1); 
	//SetTrieString(trie, "203_attribs", "6 ; 0.3 ; 1 ; 0.4 ; 78 ; 8 ; 4 ; 3"); 
	SetTrieValue(trie, "203_ammo", 250); 

//Upgradeable syringe gun
	SetTrieString(trie, "204_classname", "tf_weapon_syringegun_medic"); 
	SetTrieValue(trie, "204_index", 204); 
	SetTrieValue(trie, "204_slot", 0); 
	SetTrieValue(trie, "204_quality", 6); 
	SetTrieValue(trie, "204_level", 1); 
	//SetTrieString(trie, "204_attribs", "6 ; 0.7 ; 17 ; 0.05 ; 76 ; 3"); 
	SetTrieValue(trie, "204_ammo", 150); 

//Upgradeable rocket launcher
	SetTrieString(trie, "205_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "205_index", 205); 
	SetTrieValue(trie, "205_slot", 0); 
	SetTrieValue(trie, "205_quality", 6); 
	SetTrieValue(trie, "205_level", 1); 
	//SetTrieString(trie, "205_attribs", "104 ; 0.32 ; 99 ; 1.3 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1"); 
	SetTrieValue(trie, "205_ammo", 20); 

//Upgradeable grenade launcher
	SetTrieString(trie, "206_classname", "tf_weapon_grenadelauncher"); 
	SetTrieValue(trie, "206_index", 206); 
	SetTrieValue(trie, "206_slot", 0); 
	SetTrieValue(trie, "206_quality", 6); 
	SetTrieValue(trie, "206_level", 1); 
	//SetTrieString(trie, "206_attribs", "411 ; 20 ; 4 ; 5 ; 76 ; 10 ; 413 ; 1 ; 417 ; 1 ; 394 ; 0.08 ; 241 ; 0.4 ; 15 ; 1"); 

//Upgradeable sticky launcher
	SetTrieString(trie, "207_classname", "tf_weapon_pipebomblauncher"); 
	SetTrieValue(trie, "207_index", 207); 
	SetTrieValue(trie, "207_slot", 1); 
	SetTrieValue(trie, "207_quality", 6); 
	SetTrieValue(trie, "207_level", 1); 
	//SetTrieString(trie, "207_attribs", "96 ; 0.3 ; 78 ; 10 ; 6 ; 0.3"); 
	SetTrieValue(trie, "207_ammo", 24); 

//Upgradeable flamethrower
	SetTrieString(trie, "208_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "208_index", 208); 
	SetTrieValue(trie, "208_slot", 0); 
	SetTrieValue(trie, "208_quality", 6); 
	SetTrieValue(trie, "208_level", 1); 
	//SetTrieString(trie, "208_attribs", "171 ; 0.25 ; 256 ; 0.1 ; 255 ; .5 ; 257 ; .05"); 
	SetTrieValue(trie, "208_ammo", 200); 

//Upgradeable pistol
	SetTrieString(trie, "209_classname", "tf_weapon_pistol"); 
	SetTrieValue(trie, "209_index", 209); 
	SetTrieValue(trie, "209_slot", 1); 
	SetTrieValue(trie, "209_quality", 6); 
	SetTrieValue(trie, "209_level", 1); 
	//SetTrieString(trie, "209_attribs", "97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05"); 
	SetTrieValue(trie, "209_ammo", 100); 
	//36 for scout, 200 for engy, but idk what to use.

//Upgradeable revolver
	SetTrieString(trie, "210_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "210_index", 210); 
	SetTrieValue(trie, "210_slot", 0); 
	SetTrieValue(trie, "210_quality", 6); 
	SetTrieValue(trie, "210_level", 1); 
	//SetTrieString(trie, "210_attribs", "6 ; 0.3 ; 78 ; 5"); 
	SetTrieValue(trie, "210_ammo", 24); 

//Upgradeable medigun
	SetTrieString(trie, "211_classname", "tf_weapon_medigun"); 
	SetTrieValue(trie, "211_index", 211); 
	SetTrieValue(trie, "211_slot", 1); 
	SetTrieValue(trie, "211_quality", 6); 
	SetTrieValue(trie, "211_level", 1); 
	//SetTrieString(trie, "211_attribs", "314 ; 2 ; 11 ; 3"); 
	SetTrieValue(trie, "211_ammo", -1); 

//Upgradeable invis watch
	SetTrieString(trie, "212_classname", "tf_weapon_invis"); 
	SetTrieValue(trie, "212_index", 212); 
	SetTrieValue(trie, "212_slot", 4); 
	SetTrieValue(trie, "212_quality", 6); 
	SetTrieValue(trie, "212_level", 1); 
	//SetTrieString(trie, "212_attribs", "128 ; 1 ; 107 ; 3 ; 35 ; 5 ; 34 ; 0.5"); 
	SetTrieValue(trie, "212_ammo", -1); 

//The Powerjack
	SetTrieString(trie, "214_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "214_index", 214); 
	SetTrieValue(trie, "214_slot", 2); 
	SetTrieValue(trie, "214_quality", 6); 
	SetTrieValue(trie, "214_level", 5); 
//	SetTrieString(trie, "214_attribs", "180 ;75 ;2 ;1.25 ;15 ;0"); 	//old attribs (before april 14, 2011)
	//SetTrieString(trie, "214_attribs","26;100 ; 180;150 ; 107;1.17 ; 128;0 ; 412;1 ; 62;1" );
	SetTrieValue(trie, "214_ammo", -1); 

//The Degreaser
	SetTrieString(trie, "215_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "215_index", 215); 
	SetTrieValue(trie, "215_slot", 0); 
	SetTrieValue(trie, "215_quality", 6); 
	SetTrieValue(trie, "215_level", 10); 
	//SetTrieString(trie, "215_attribs", "178 ; .05 ; 66 ; 0.5"); 
	SetTrieValue(trie, "215_ammo", 200); 

//The Shortstop
	SetTrieString(trie, "220_classname", "tf_weapon_handgun_scout_primary"); 
	SetTrieValue(trie, "220_index", 220); 
	SetTrieValue(trie, "220_slot", 0); 
	SetTrieValue(trie, "220_quality", 6); 
	SetTrieValue(trie, "220_level", 1); 
	//SetTrieString(trie, "220_attribs", "26 ; 250 ; 16 ; 15 ; 78 ; 3 ; 2 ; 1.2"); 
	SetTrieValue(trie, "220_ammo", 36); 

//The Holy Mackerel
	SetTrieString(trie, "221_classname", "tf_weapon_bat_fish"); 
	SetTrieValue(trie, "221_index", 221); 
	SetTrieValue(trie, "221_slot", 2); 
	SetTrieValue(trie, "221_quality", 6); 
	SetTrieValue(trie, "221_level", 42); 
	//SetTrieString(trie, "221_attribs", "292 ;7.0 ;388 ;7.0"); 
	SetTrieValue(trie, "221_ammo", -1); 

//Mad Milk
	SetTrieString(trie, "222_classname", "tf_weapon_jar_milk"); 
	SetTrieValue(trie, "222_index", 222); 
	SetTrieValue(trie, "222_slot", 1); 
	SetTrieValue(trie, "222_quality", 6); 
	SetTrieValue(trie, "222_level", 5); 
	//SetTrieString(trie, "222_attribs", "292 ;4.0"); 
	SetTrieValue(trie, "222_ammo", 1); 

//L'Etranger
	SetTrieString(trie, "224_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "224_index", 224); 
	SetTrieValue(trie, "224_slot", 0); 
	SetTrieValue(trie, "224_quality", 6); 
	SetTrieValue(trie, "224_level", 5); 
	//SetTrieString(trie, "224_attribs", "6 ; 0.3 ; 1 ; 0.15 ; 166 ; 150 ; 78 ; 5"); 
	SetTrieValue(trie, "224_ammo", 24); 

//Your Eternal Reward
	SetTrieString(trie, "225_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "225_index", 225); 
	SetTrieValue(trie, "225_slot", 2); 
	SetTrieValue(trie, "225_quality", 6); 
	SetTrieValue(trie, "225_level", 1); 
	//SetTrieString(trie, "225_attribs", "154 ; 1 ; 144 ; 1 ; 155 ; 0"); 
	SetTrieValue(trie, "225_ammo", -1); 

//The Battalion's Backup
	SetTrieString(trie, "226_classname", "tf_weapon_buff_item"); 
	SetTrieValue(trie, "226_index", 226); 
	SetTrieValue(trie, "226_slot", 1); 
	SetTrieValue(trie, "226_quality", 6); 
	SetTrieValue(trie, "226_level", 10); 
	//SetTrieString(trie, "226_attribs","116;2 ; 357;5 ; 26;100" );
	SetTrieValue(trie, "226_ammo", -1); 

//The Black Box
	SetTrieString(trie, "228_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "228_index", 228); 
	SetTrieValue(trie, "228_slot", 0); 
	SetTrieValue(trie, "228_quality", 6); 
	SetTrieValue(trie, "228_level", 5); 
	//SetTrieString(trie, "228_attribs","16;150 ; 5;1 ; 180;150 ; 3;0.75" );
	SetTrieValue(trie, "228_ammo", 20); 

//The Sydney Sleeper
	SetTrieString(trie, "230_classname", "tf_weapon_sniperrifle"); 
	SetTrieValue(trie, "230_index", 230); 
	SetTrieValue(trie, "230_slot", 0); 
	SetTrieValue(trie, "230_quality", 6); 
	SetTrieValue(trie, "230_level", 1); 
	//SetTrieString(trie, "230_attribs", "41 ; 2 ; 42 ; 1 ; 175 ; 15"); 
	SetTrieValue(trie, "230_ammo", 25); 

//darwin's danger shield (broken NO LONGER)
	SetTrieString(trie, "231_classname", "tf_wearable"); 
	SetTrieValue(trie, "231_index", 231); 
	SetTrieValue(trie, "231_slot", 1); 
	SetTrieValue(trie, "231_quality", 6); 
	SetTrieValue(trie, "231_level", 10); 
	//SetTrieString(trie, "231_attribs", "26 ; 250"); 

//The Bushwacka
	SetTrieString(trie, "232_classname", "tf_weapon_club"); 
	SetTrieValue(trie, "232_index", 232); 
	SetTrieValue(trie, "232_slot", 2); 
	SetTrieValue(trie, "232_quality", 6); 
	SetTrieValue(trie, "232_level", 5); 
	//SetTrieString(trie, "232_attribs","6;1 ; 107;1.2 ; 128;1 ; 179;1 ; 2;2 ; 28;1" );
	SetTrieValue(trie, "232_ammo", -1); 

//Rocket Jumper
	SetTrieString(trie, "237_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "237_index", 237); 
	SetTrieValue(trie, "237_slot", 0); 
	SetTrieValue(trie, "237_quality", 6); 
	SetTrieValue(trie, "237_level", 1); 
//	//SetTrieString(trie, "237_attribs", "1 ;0.0 ;181 ;2.0 ;76 ;3.0 ;65 ;2.0 ;67 ;2.0 ;61 ;2.0"); 		//pre-may31 2012;before sep15, 2011, used to be 181 ;1.0
	SetTrieString(trie, "237_attribs", "134 ; 2 ; 181 ; 2 ; 476 ; -1 ; 318 ; 0.1 ; 4 ; 10 ; 76 ; 10 ; 128 ; 1 ; 275 ; 1"); 
	SetTrieValue(trie, "237_ammo", 60); 

//gloves of running urgently
	//SetTrieString(trie, "239_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "239_index", 239); 
	SetTrieValue(trie, "239_slot", 2); 
	SetTrieValue(trie, "239_quality", 6); 
	SetTrieValue(trie, "239_level", 10); 
//	SetTrieString(trie, "239_attribs", "128 ; 1.0 ; 107 ; 1.3 ; 1 ; 0.5 ; 191 ; -6.0 ; 144 ; 2.0"); 
	//SetTrieString(trie, "239_attribs", "107 ; 1.83 ; 128 ; 1"); 
	SetTrieValue(trie, "239_ammo", -1); 

//Frying Pan (Now if only it had augment slots)
//	SetTrieString(trie, "264_classname", "tf_weapon_shovel"); 
	SetTrieString(trie, "264_classname", "saxxy"); 
	SetTrieValue(trie, "264_index", 264); 
	SetTrieValue(trie, "264_slot", 2); 
	SetTrieValue(trie, "264_quality", 6); 
	SetTrieValue(trie, "264_level", 5); 
	//SetTrieString(trie, "264_attribs", "6 ; 0.5 ; 208 ; 1 ; 1 ; 0.5 ; 134 ; 1"); 
	SetTrieValue(trie, "264_ammo", -1); 

//sticky jumper
	SetTrieString(trie, "265_classname", "tf_weapon_pipebomblauncher"); 
	SetTrieValue(trie, "265_index", 265); 
	SetTrieValue(trie, "265_slot", 1); 
	SetTrieValue(trie, "265_quality", 6); 
	SetTrieValue(trie, "265_level", 1); 
	//SetTrieString(trie, "265_attribs", "78 ;3.0 ;181 ;1.0 ;1 ;0.0 ;15 ;0.0 ;400 ;1.0 ;280 ;14.0"); 
//	SetTrieString(trie, "265_attribs", "181 ;1.0 ;78 ;3.0 ;280 ;14.0 ;1 ;0.0 ;15 ;0.0"); 	//pre-may31 2012
//	SetTrieString(trie, "265_attribs", "1 ;0.0 ;181 ;1.0 ;78 ;3.0 ;65 ;2.0 ;67 ;2.0 ;61 ;2.0"); 	//old pre-sep15,2011 update
	//SetTrieString(trie, "265_attribs", "134 ; 2 ; 181 ; 2 ; 476 ; -1 ; 318 ; 0.1 ; 4 ; 10 ; 275 ; 1 ; 78 ; 10"); 

//horseless headless horsemann's headtaker
	SetTrieString(trie, "266_classname", "tf_weapon_sword"); 
	SetTrieValue(trie, "266_index", 266); 
	SetTrieValue(trie, "266_slot", 2); 
	SetTrieValue(trie, "266_quality", 5); 
	SetTrieValue(trie, "266_level", 5); 
	//SetTrieString(trie, "266_attribs","26;75 ; 107;1.1 ; 292;6 ; 388;6 ; 219;1" );
	SetTrieValue(trie, "266_ammo", -1); 

//lugermorph from Poker Night
	SetTrieString(trie, "294_classname", "tf_weapon_pistol"); 
	SetTrieValue(trie, "294_index", 294); 
	SetTrieValue(trie, "294_slot", 1); 
	SetTrieValue(trie, "294_quality", 6); 
	SetTrieValue(trie, "294_level", 5); 
	//SetTrieString(trie, "294_attribs", "97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05"); 
	SetTrieValue(trie, "294_ammo", 36); 

//Enthusiast's Timepiece
	SetTrieString(trie, "297_classname", "tf_weapon_invis"); 
	SetTrieValue(trie, "297_index", 297); 
	SetTrieValue(trie, "297_slot", 4); 
	SetTrieValue(trie, "297_quality", 6); 
	SetTrieValue(trie, "297_level", 5); 
	//SetTrieString(trie, "297_attribs", ""); 
	SetTrieValue(trie, "297_ammo", -1); 

//The Iron Curtain
	SetTrieString(trie, "298_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "298_index", 298); 
	SetTrieValue(trie, "298_slot", 0); 
	SetTrieValue(trie, "298_quality", 6); 
	SetTrieValue(trie, "298_level", 5); 
	//SetTrieString(trie, "298_attribs", "76 ; 5 ; 6 ; .9 ; 16 ; 20"); 
	SetTrieValue(trie, "298_ammo", 200); 

//Amputator
	SetTrieString(trie, "304_classname", "tf_weapon_bonesaw"); 
	SetTrieValue(trie, "304_index", 304); 
	SetTrieValue(trie, "304_slot", 2); 
	SetTrieValue(trie, "304_quality", 6); 
	SetTrieValue(trie, "304_level", 15); 
	//SetTrieString(trie, "304_attribs", "129 ; 10"); 
	SetTrieValue(trie, "304_ammo", -1); 

//Crusader's Crossbow
	SetTrieString(trie, "305_classname", "tf_weapon_crossbow"); 
	SetTrieValue(trie, "305_index", 305); 
	SetTrieValue(trie, "305_slot", 0); 
	SetTrieValue(trie, "305_quality", 6); 
	SetTrieValue(trie, "305_level", 15); 
	//SetTrieString(trie, "305_attribs","199;1 ; 97;.25 ; 76;2.6" );
	SetTrieValue(trie, "305_ammo", 38); 

//Ullapool Caber
	SetTrieString(trie, "307_classname", "tf_weapon_stickbomb"); 
	SetTrieValue(trie, "307_index", 307); 
	SetTrieValue(trie, "307_slot", 2); 
	SetTrieValue(trie, "307_quality", 6); 
	SetTrieValue(trie, "307_level", 10); 
	//SetTrieString(trie, "307_attribs", "15 ;0"); 
	SetTrieValue(trie, "307_ammo", -1); 

//Loch-n-Load
	SetTrieString(trie, "308_classname", "tf_weapon_grenadelauncher"); 
	SetTrieValue(trie, "308_index", 308); 
	SetTrieValue(trie, "308_slot", 0); 
	SetTrieValue(trie, "308_quality", 6); 
	SetTrieValue(trie, "308_level", 10); 
	//SetTrieString(trie, "308_attribs","103;2.7 ; 2;2.5 ; 3;0.25 ; 127;2 ; 207;1.50 ; 15;1 ; 99;1.1" ); 
	SetTrieValue(trie, "308_ammo", 16); 

//Warrior's Spirit
	SetTrieString(trie, "310_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "310_index", 310); 
	SetTrieValue(trie, "310_slot", 2); 
	SetTrieValue(trie, "310_quality", 6); 
	SetTrieValue(trie, "310_level", 10); 
	//SetTrieString(trie, "310_attribs", "26 ; 200 ; 180 ; 100 ; 2 ; 10"); 
	SetTrieValue(trie, "310_ammo", -1); 

//Buffalo Steak Sandvich
	SetTrieString(trie, "311_classname", "tf_weapon_lunchbox"); 
	SetTrieValue(trie, "311_index", 311); 
	SetTrieValue(trie, "311_slot", 1); 
	SetTrieValue(trie, "311_quality", 6); 
	SetTrieValue(trie, "311_level", 1); 
	//SetTrieString(trie, "311_attribs", "144 ;2"); 
	SetTrieValue(trie, "311_ammo", 1); 

//Brass Beast
	SetTrieString(trie, "312_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "312_index", 312); 
	SetTrieValue(trie, "312_slot", 0); 
	SetTrieValue(trie, "312_quality", 6); 
	SetTrieValue(trie, "312_level", 5); 
	//SetTrieString(trie, "312_attribs","2;2 ; 86;2 ; 183;0.005 ; 266;1 ; 106;0.1" );
	SetTrieValue(trie, "312_ammo", 200); 

//Candy Cane
	SetTrieString(trie, "317_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "317_index", 317); 
	SetTrieValue(trie, "317_slot", 2); 
	SetTrieValue(trie, "317_quality", 6); 
	SetTrieValue(trie, "317_level", 25); 
	//SetTrieString(trie, "317_attribs", "203 ; 1"); 
	SetTrieValue(trie, "317_ammo", -1); 

//Boston Basher
	SetTrieString(trie, "325_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "325_index", 325); 
	SetTrieValue(trie, "325_slot", 2); 
	SetTrieValue(trie, "325_quality", 6); 
	SetTrieValue(trie, "325_level", 25); 
	//SetTrieString(trie, "325_attribs", "149 ; 30 ; 204 ; 0"); 
	SetTrieValue(trie, "325_ammo", -1); 

//Backscratcher
	SetTrieString(trie, "326_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "326_index", 326); 
	SetTrieValue(trie, "326_slot", 2); 
	SetTrieValue(trie, "326_quality", 6); 
	SetTrieValue(trie, "326_level", 10); 
	//SetTrieString(trie, "326_attribs", "69 ; 0 ; 2 ; 4 ; 108 ; 3"); 
	SetTrieValue(trie, "326_ammo", -1); 

//Claidheamh Mòr
	SetTrieString(trie, "327_classname", "tf_weapon_sword"); 
	SetTrieValue(trie, "327_index", 327); 
	SetTrieValue(trie, "327_slot", 2); 
	SetTrieValue(trie, "327_quality", 6); 
	SetTrieValue(trie, "327_level", 5); 
	//SetTrieString(trie, "327_attribs", "202 ; 10"); 
	SetTrieValue(trie, "327_ammo", -1); 

//Jag
	SetTrieString(trie, "329_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "329_index", 329); 
	SetTrieValue(trie, "329_slot", 2); 
	SetTrieValue(trie, "329_quality", 6); 
	SetTrieValue(trie, "329_level", 15); 
	//SetTrieString(trie, "329_attribs", "286 ; 3 ; 1 ; 0 ; 327 ; 1 ; 92 ; 10"); 
	SetTrieValue(trie, "329_ammo", -1); 

//Fists of Steel
	SetTrieString(trie, "331_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "331_index", 331); 
	SetTrieValue(trie, "331_slot", 2); 
	SetTrieValue(trie, "331_quality", 6); 
	SetTrieValue(trie, "331_level", 10); 
	//SetTrieString(trie, "331_attribs","177;2 ; 128;1 ; 205;0 ; 206;5 ; 107;1.3 ; 2;2" ); 
	SetTrieValue(trie, "331_ammo", -1); 

//Sharpened Volcano Fragment
	SetTrieString(trie, "348_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "348_index", 348); 
	SetTrieValue(trie, "348_slot", 2); 
	SetTrieValue(trie, "348_quality", 6); 
	SetTrieValue(trie, "348_level", 10); 
	//SetTrieString(trie, "348_attribs", "208 ; 1 ; 20 ; 1 ; 6 ; 0.3 ; 1 ; 0.5"); 
	SetTrieValue(trie, "348_ammo", -1); 

//Sun on a Stick
	SetTrieString(trie, "349_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "349_index", 349); 
	SetTrieValue(trie, "349_slot", 2); 
	SetTrieValue(trie, "349_quality", 6); 
	SetTrieValue(trie, "349_level", 10); 
//	SetTrieString(trie, "349_attribs", "209 ;1.0 ;1 ;0.85 ;153 ;1.0"); 	//old pre april 14, 2011 attribs
	//SetTrieString(trie, "349_attribs", "20 ;1.0 ;1 ;0.75"); 
	SetTrieValue(trie, "349_ammo", -1); 

//Detonator
	SetTrieString(trie, "351_classname", "tf_weapon_flaregun"); 
	SetTrieValue(trie, "351_index", 351); 
	SetTrieValue(trie, "351_slot", 1); 
	SetTrieValue(trie, "351_quality", 6); 
	SetTrieValue(trie, "351_level", 10); 
	//SetTrieString(trie, "351_attribs","58;2.5 ; 144;1 ; 275;1 ; 135;0 ; 318;0.5 ; 78;3" );
	SetTrieValue(trie, "351_ammo", 16); 

//Soldier's Sashimono - The Concheror
	SetTrieString(trie, "354_classname", "tf_weapon_buff_item"); 
	SetTrieValue(trie, "354_index", 354); 
	SetTrieValue(trie, "354_slot", 1); 
	SetTrieValue(trie, "354_quality", 6); 
	SetTrieValue(trie, "354_level", 5); 
	//SetTrieString(trie, "354_attribs","116;3 ; 57;15" );
	SetTrieValue(trie, "354_ammo", -1); 

//Gunbai - Fan o'War
	SetTrieString(trie, "355_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "355_index", 355); 
	SetTrieValue(trie, "355_slot", 2); 
	SetTrieValue(trie, "355_quality", 6); 
	SetTrieValue(trie, "355_level", 5); 
	//SetTrieString(trie, "355_attribs", "218 ; 1 ; 149 ; 10 ; 337 ; 1 ; 1 ; 0.1 ; 6 ; 0.75 ; 340 ; 1"); 
	SetTrieValue(trie, "355_ammo", -1); 

//Kunai - Conniver's Kunai
	SetTrieString(trie, "356_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "356_index", 356); 
	SetTrieValue(trie, "356_slot", 2); 
	SetTrieValue(trie, "356_quality", 6); 
	SetTrieValue(trie, "356_level", 1); 
	//SetTrieString(trie, "356_attribs", "125 ; -100 ; 140 ; -150 ; 220 ; 99900"); 
	SetTrieValue(trie, "356_ammo", -1); 

//Soldier Katana - The Half-Zatoichi
	SetTrieString(trie, "357_classname", "tf_weapon_katana"); 
	SetTrieValue(trie, "357_index", 357); 
	SetTrieValue(trie, "357_slot", 2); 
	SetTrieValue(trie, "357_quality", 6); 
	SetTrieValue(trie, "357_level", 5); 
	//SetTrieString(trie, "357_attribs", "220 ; 100 ; 226 ; 1 ; 180 ; 500 ; 14 ; 1"); 
	SetTrieValue(trie, "357_ammo", -1); 

//Shahanshah
	SetTrieString(trie, "401_classname", "tf_weapon_club"); 
	SetTrieValue(trie, "401_index", 401); 
	SetTrieValue(trie, "401_slot", 2); 
	SetTrieValue(trie, "401_quality", 6); 
	SetTrieValue(trie, "401_level", 5); 
	//SetTrieString(trie, "401_attribs", "224 ; 5 ; 225 ; 0.1"); 
	SetTrieValue(trie, "401_ammo", -1); 

//Bazaar Bargain
	SetTrieString(trie, "402_classname", "tf_weapon_sniperrifle_decap"); 
	SetTrieValue(trie, "402_index", 402); 
	SetTrieValue(trie, "402_slot", 0); 
	SetTrieValue(trie, "402_quality", 6); 
	SetTrieValue(trie, "402_level", 10); 
	//SetTrieString(trie, "402_attribs", "237 ; 1 ; 222 ; 1 ; 223 ; 1"); 
	SetTrieValue(trie, "402_ammo", 25); 

//Persian Persuader
	SetTrieString(trie, "404_classname", "tf_weapon_sword"); 
	SetTrieValue(trie, "404_index", 404); 
	SetTrieValue(trie, "404_slot", 2); 
	SetTrieValue(trie, "404_quality", 6); 
	SetTrieValue(trie, "404_level", 10); 
	//SetTrieString(trie, "404_attribs", "249 ;2.0 ;258 ;1.0 ;15 ;0.0"); 
	SetTrieValue(trie, "404_ammo", -1); 

//Ali Baba's Wee Booties
	SetTrieString(trie, "405_classname", "tf_wearable"); 
	SetTrieValue(trie, "405_index", 405); 
	SetTrieValue(trie, "405_slot", 0); 
	SetTrieValue(trie, "405_quality", 6); 
	SetTrieValue(trie, "405_level", 10); 
	//SetTrieString(trie, "405_attribs", "246 ; 10 ; 26 ; 250"); 
	SetTrieValue(trie, "405_ammo", -1); 

//Splendid Screen
	SetTrieString(trie, "406_classname", "tf_wearable_demoshield"); 
	SetTrieValue(trie, "406_index", 406); 
	SetTrieValue(trie, "406_slot", 1); 
	SetTrieValue(trie, "406_quality", 6); 
	SetTrieValue(trie, "406_level", 10); 
	//SetTrieString(trie, "406_attribs", "247 ; 1 ; 248 ; 700 ; 60 ; 0.8 ; 64 ; 0.85"); 
	SetTrieValue(trie, "406_ammo", -1); 

//Quick Fix
	SetTrieString(trie, "411_classname", "tf_weapon_medigun"); 
	SetTrieValue(trie, "411_index", 411); 
	SetTrieValue(trie, "411_slot", 1); 
	SetTrieValue(trie, "411_quality", 6); 
	SetTrieValue(trie, "411_level", 8); 
	//SetTrieString(trie, "411_attribs","8;3 ; 10;2 ; 231;2 ; 144;2 ; 57;15" );
	SetTrieValue(trie, "411_ammo", -1); 

//Overdose
	SetTrieString(trie, "412_classname", "tf_weapon_syringegun_medic"); 
	SetTrieValue(trie, "412_index", 412); 
	SetTrieValue(trie, "412_slot", 0); 
	SetTrieValue(trie, "412_quality", 6); 
	SetTrieValue(trie, "412_level", 5); 
	//SetTrieString(trie, "412_attribs","144;1 ; 6;0.001 ; 1;0.5 ; 96;0.3 ; 3;0.4 ; 107;1.25 ; 76;2" ); 
	SetTrieValue(trie, "412_ammo", 150); 

//Solemn Vow (Also known as Hippocrates)
	SetTrieString(trie, "413_classname", "tf_weapon_bonesaw"); 
	SetTrieValue(trie, "413_index", 413); 
	SetTrieValue(trie, "413_slot", 2); 
	SetTrieValue(trie, "413_quality", 6); 
	SetTrieValue(trie, "413_level", 10); 
	//SetTrieString(trie, "413_attribs", "269 ;1.0"); 
	SetTrieValue(trie, "413_ammo", -1); 

//Liberty Launcher
	SetTrieString(trie, "414_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "414_index", 414); 
	SetTrieValue(trie, "414_slot", 0); 
	SetTrieValue(trie, "414_quality", 6); 
	SetTrieValue(trie, "414_level", 25); 
	//SetTrieString(trie, "414_attribs","103;2.7 ; 6;0.5 ; 1;1 ; 4;1.5 ; 318;0.9 ; 76;2 ; 135;.5 ; 275;1" );
	SetTrieValue(trie, "414_ammo", 40); 

//Reserve Shooter
	SetTrieString(trie, "415_classname", "tf_weapon_shotgun_soldier"); //); 
	SetTrieValue(trie, "415_index", 415); 
	SetTrieValue(trie, "415_slot", 1); 
	SetTrieValue(trie, "415_quality", 6); 
	SetTrieValue(trie, "415_level", 10); 
	//SetTrieString(trie, "415_attribs", "178 ;0.85 ;265 ;3.0 ;3 ;0.5"); 
	SetTrieValue(trie, "415_ammo", 32); 

//Market Gardener
	SetTrieString(trie, "416_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "416_index", 416); 
	SetTrieValue(trie, "416_slot", 2); 
	SetTrieValue(trie, "416_quality", 6); 
	SetTrieValue(trie, "416_level", 10); 
	//SetTrieString(trie, "416_attribs", "178 ; .5 ; 2 ; 2 ; 267 ; 1 ; 15 ; 0 ; 5 ; 1.75"); 
	SetTrieValue(trie, "416_ammo", -1); 

//Saxxy
	SetTrieString(trie, "423_classname", "saxxy"); 
	SetTrieValue(trie, "423_index", 423); 
	SetTrieValue(trie, "423_slot", 2); 
	SetTrieValue(trie, "423_quality", 6); 
	SetTrieValue(trie, "423_level", 25); 
	//SetTrieString(trie, "423_attribs", "150 ;1.0"); 
	SetTrieValue(trie, "423_ammo", -1); 

//Tomislav
	SetTrieString(trie, "424_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "424_index", 424); 
	SetTrieValue(trie, "424_slot", 0); 
	SetTrieValue(trie, "424_quality", 6); 
	SetTrieValue(trie, "424_level", 5); 
	//SetTrieString(trie, "424_attribs", "107 ; 1.3 ; 1 ; 0.6 ; 75 ; 2.13 ; 238 ; 1 ; 87 ; 0.1 ; 128 ; 1"); 
	SetTrieValue(trie, "424_ammo", 200); 

//Family Business
	SetTrieString(trie, "425_classname", "tf_weapon_shotgun_hwg"); 
	SetTrieValue(trie, "425_index", 425); 
	SetTrieValue(trie, "425_slot", 1); 
	SetTrieValue(trie, "425_quality", 6); 
	SetTrieValue(trie, "425_level", 10); 
	//SetTrieString(trie, "425_attribs", "4 ; 3.3 ; 6 ; 0.5 ; 25 ; 3.3 ; 1 ; 0.85"); 
	SetTrieValue(trie, "425_ammo", 32); 

//Eviction Notice
	SetTrieString(trie, "426_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "426_index", 426); 
	SetTrieValue(trie, "426_slot", 2); 
	SetTrieValue(trie, "426_quality", 6); 
	SetTrieValue(trie, "426_level", 10); 
	//SetTrieString(trie, "426_attribs", "1 ; 0.7 ; 6 ; 0.25 ; 107 ; 1.4 ; 128 ; 1"); 
	SetTrieValue(trie, "426_ammo", -1); 

//Fishcake
	SetTrieString(trie, "433_classname", "tf_weapon_lunchbox"); 
	SetTrieValue(trie, "433_index", 433); 
	SetTrieValue(trie, "433_slot", 1); 
	SetTrieValue(trie, "433_quality", 6); 
	SetTrieValue(trie, "433_level", 1); 
	//SetTrieString(trie, "433_attribs", "139 ;1"); 
	SetTrieValue(trie, "433_ammo", 1); 

//Cow Mangler 5000
	SetTrieString(trie, "441_classname", "tf_weapon_particle_cannon"); 
	SetTrieValue(trie, "441_index", 441); 
	SetTrieValue(trie, "441_slot", 0); 
	SetTrieValue(trie, "441_quality", 6); 
	SetTrieValue(trie, "441_level", 30); 
	//SetTrieString(trie, "441_attribs", "281 ;1.0 ;282 ;1.0 ;15 ;0.0 ;284 ;1.0 ;288 ;1.0"); 
	SetTrieValue(trie, "441_ammo", -1); 

//Righteous Bison
	SetTrieString(trie, "442_classname", "tf_weapon_raygun"); 
	SetTrieValue(trie, "442_index", 442); 
	SetTrieValue(trie, "442_slot", 1); 
	SetTrieValue(trie, "442_quality", 6); 
	SetTrieValue(trie, "442_level", 30); 
	//SetTrieString(trie, "442_attribs", "281 ;1.0 ;283 ;1.0 ;285 ;0.0 ;284 ;1.0"); 
	SetTrieValue(trie, "442_ammo", -1); 

//Mantreads
	SetTrieString(trie, "444_classname", "tf_wearable"); 
	SetTrieValue(trie, "444_index", 444); 
	SetTrieValue(trie, "444_slot", 1); 
	SetTrieValue(trie, "444_quality", 6); 
	SetTrieValue(trie, "444_level", 10); 
	//SetTrieString(trie, "444_attribs","259;1 ; 252;0.01 ; 2;100 ; 129;10" );
	SetTrieValue(trie, "444_ammo", -1); 

//Disciplinary Action
	SetTrieString(trie, "447_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "447_index", 447); 
	SetTrieValue(trie, "447_slot", 2); 
	SetTrieValue(trie, "447_quality", 6); 
	SetTrieValue(trie, "447_level", 10); 
	//SetTrieString(trie, "447_attribs","251;1 ; 1;0 ; 264;20 ; 263;10 ; 394;0.25 ; 107;1.25 ; 128;1" );
	SetTrieValue(trie, "447_ammo", -1); 

//Soda Popper
	SetTrieString(trie, "448_classname", "tf_weapon_soda_popper"); 
	SetTrieValue(trie, "448_index", 448); 
	SetTrieValue(trie, "448_slot", 0); 
	SetTrieValue(trie, "448_quality", 6); 
	SetTrieValue(trie, "448_level", 10); 
	//SetTrieString(trie, "448_attribs", "97 ; 0.5 ; 6 ; 0.25 ; 418 ; 1 ; 43 ; 1 ; 37 ; 3 ; 107 ; 1.1 ; 128 ; 1 ; 3 ; 0.5"); 
	SetTrieValue(trie, "448_ammo", 32); 

//Winger
	SetTrieString(trie, "449_classname", "tf_weapon_handgun_scout_secondary"); 
	SetTrieValue(trie, "449_index", 449); 
	SetTrieValue(trie, "449_slot", 1); 
	SetTrieValue(trie, "449_quality", 6); 
	SetTrieValue(trie, "449_level", 15); 
	//SetTrieString(trie, "449_attribs", "2 ; 2.5 ; 78 ; 1.5 ; 5 ; 1.5 ; 326 ; 2.5"); 
	SetTrieValue(trie, "449_ammo", 36); 

//Atomizer
	SetTrieString(trie, "450_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "450_index", 450); 
	SetTrieValue(trie, "450_slot", 2); 
	SetTrieValue(trie, "450_quality", 6); 
	SetTrieValue(trie, "450_level", 10); 
	//SetTrieString(trie, "450_attribs", "250 ; 10"); 
	SetTrieValue(trie, "450_ammo", -1); 

//Three-Rune Blade
	SetTrieString(trie, "452_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "452_index", 452); 
	SetTrieValue(trie, "452_slot", 2); 
	SetTrieValue(trie, "452_quality", 6); 
	SetTrieValue(trie, "452_level", 10); 
	//SetTrieString(trie, "452_attribs", "149 ; 30 ; 204 ; 0"); 
	SetTrieValue(trie, "452_ammo", -1); 

//Postal Pummeler
	SetTrieString(trie, "457_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "457_index", 457); 
	SetTrieValue(trie, "457_slot", 2); 
	SetTrieValue(trie, "457_quality", 6); 
	SetTrieValue(trie, "457_level", 10); 
	//SetTrieString(trie, "457_attribs", "20 ; 1 ; 21 ; 0 ; 22 ; 1 ; 2 ; 1.5");
	SetTrieValue(trie, "457_ammo", -1); 

//Enforcer
	SetTrieString(trie, "460_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "460_index", 460); 
	SetTrieValue(trie, "460_slot", 0); 
	SetTrieValue(trie, "460_quality", 6); 
	SetTrieValue(trie, "460_level", 5); 
	//SetTrieString(trie, "460_attribs","2;3.1 ; 5;4 ; 3;0.16 ; 299;1 ; 78;0.25" );
//	SetTrieString(trie, "460_attribs", "2 ;1.2 ;253 ;0.5"); 	//pre-may31 2012
	SetTrieValue(trie, "460_ammo", 24); 

//Big Earner
	//SetTrieString(trie, "461_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "461_index", 461); 
	SetTrieValue(trie, "461_slot", 2); 
	SetTrieValue(trie, "461_quality", 6); 
	SetTrieValue(trie, "461_level", 1); 
	SetTrieString(trie, "461_attribs", "166 ; 150"); 
	SetTrieValue(trie, "461_ammo", -1); 

//Maul
	//SetTrieString(trie, "466_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "466_index", 466); 
	SetTrieValue(trie, "466_slot", 2); 
	SetTrieValue(trie, "466_quality", 6); 
	SetTrieValue(trie, "466_level", 5); 
	SetTrieString(trie, "466_attribs", "137 ; 10 ; 146 ; 1 ; 169 ; 99 ; 128 ; 1"); 
	SetTrieValue(trie, "466_ammo", -1); 

//Conscientious Objector
	//SetTrieString(trie, "474_classname", "saxxy"); 
	SetTrieValue(trie, "474_index", 474); 
	SetTrieValue(trie, "474_slot", 2); 
	SetTrieValue(trie, "474_quality", 6); 
	SetTrieValue(trie, "474_level", 25); 
	//SetTrieString(trie, "474_attribs", ""); 
	SetTrieValue(trie, "474_ammo", -1); 

//Nessie's Nine Iron
	SetTrieString(trie, "482_classname", "tf_weapon_sword"); 
	SetTrieValue(trie, "482_index", 482); 
	SetTrieValue(trie, "482_slot", 2); 
	SetTrieValue(trie, "482_quality", 6); 
	SetTrieValue(trie, "482_level", 5); 
	//SetTrieString(trie, "482_attribs","26;75 ; 107;1.1 ; 292;6 ; 388;6 ; 219;1" );
	SetTrieValue(trie, "482_ammo", -1); 

//The Original
	SetTrieString(trie, "513_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "513_index", 513); 
	SetTrieValue(trie, "513_slot", 0); 
	SetTrieValue(trie, "513_quality", 6); 
	SetTrieValue(trie, "513_level", 5); 
	//SetTrieString(trie, "513_attribs","104;0.32 ; 99;1 ; 2;5 ; 97;1.4 ; 3;0.25 ; 15;1" );
	SetTrieValue(trie, "513_ammo", 20); 

//The Diamondback
	SetTrieString(trie, "525_classname", "tf_weapon_revolver"); 
	SetTrieValue(trie, "525_index", 525); 
	SetTrieValue(trie, "525_slot", 0); 
	SetTrieValue(trie, "525_quality", 6); 
	SetTrieValue(trie, "525_level", 5); 
	//SetTrieString(trie, "525_attribs", "296 ;1.0 ;1 ;0.85 ;15 ;0.0"); 
	SetTrieValue(trie, "525_ammo", 24); 

//The Machina
	SetTrieString(trie, "526_classname", "tf_weapon_sniperrifle"); 
	SetTrieValue(trie, "526_index", 526); 
	SetTrieValue(trie, "526_slot", 0); 
	SetTrieValue(trie, "526_quality", 6); 
	SetTrieValue(trie, "526_level", 5); 
	//SetTrieString(trie, "526_attribs", "308 ; 1 ; 297 ; 0 ; 304 ; 100 ; 1 ; 0.1 ; 149 ; 10"); 
	SetTrieValue(trie, "526_ammo", 25); 

//The Widowmaker
	SetTrieString(trie, "527_classname", "tf_weapon_shotgun_primary"); 
	SetTrieValue(trie, "527_index", 527); 
	SetTrieValue(trie, "527_slot", 0); 
	SetTrieValue(trie, "527_quality", 6); 
	SetTrieValue(trie, "527_level", 5); 
	//SetTrieString(trie, "527_attribs", "298 ; 20 ; 301 ; 1 ; 303 ; -1 ; 299 ; 100 ; 6 ; 0.8 ; 80 ; 1.5 ; 307 ; 1 ; 113 ; 25"); 
	SetTrieValue(trie, "527_ammo", 200); 

//The Short Circuit
	SetTrieString(trie, "528_classname", "tf_weapon_mechanical_arm"); 
	SetTrieValue(trie, "528_index", 528); 
	SetTrieValue(trie, "528_slot", 1); 
	SetTrieValue(trie, "528_quality", 6); 
	SetTrieValue(trie, "528_level", 5); 
	//SetTrieString(trie, "528_attribs","298;15 ; 301;1 ; 300;1 ; 307;1 ; 303;-1 ; 312;1 ; 299;100 ; 6;1 ; 80;1.5 ; 113;25" );
	SetTrieValue(trie, "528_ammo", 200); 

//Unarmed Combat
	SetTrieString(trie, "572_classname", "tf_weapon_bat_fish"); 
	SetTrieValue(trie, "572_index", 572); 
	SetTrieValue(trie, "572_slot", 2); 
	SetTrieValue(trie, "572_quality", 6); 
	SetTrieValue(trie, "572_level", 13); 
	//SetTrieString(trie, "572_attribs", "332 ;1.0 ;292 ;7.0 ;388 ;7.0"); 
	SetTrieValue(trie, "572_ammo", -1); 

//Wanga Prick
	SetTrieString(trie, "574_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "574_index", 574); 
	SetTrieValue(trie, "574_slot", 2); 
	SetTrieValue(trie, "574_quality", 6); 
	SetTrieValue(trie, "574_level", 54); 
	//SetTrieString(trie, "574_attribs", "154 ;1.0 ;156 ;1.0 ;155 ;1.0 ;144 ;1.0"); 
	SetTrieValue(trie, "574_ammo", -1); 

//Apoco-Fists
	SetTrieString(trie, "587_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "587_index", 587); 
	SetTrieValue(trie, "587_slot", 2); 
	SetTrieValue(trie, "587_quality", 6); 
	SetTrieValue(trie, "587_level", 10); 
	//SetTrieString(trie, "587_attribs", "309 ;1.0"); 
	SetTrieValue(trie, "587_ammo", -1); 

//Pomson 6000
	SetTrieString(trie, "588_classname", "tf_weapon_drg_pomson"); 
	SetTrieValue(trie, "588_index", 588); 
	SetTrieValue(trie, "588_slot", 0); 
	SetTrieValue(trie, "588_quality", 6); 
	SetTrieValue(trie, "588_level", 10); 
	//SetTrieString(trie, "588_attribs", "281 ;1.0 ;285 ;1.0 ;337 ;10.0 ;338 ;20.0"); 
	SetTrieValue(trie, "588_ammo", -1); 

//Eureka Effect
	SetTrieString(trie, "589_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "589_index", 589); 
	SetTrieValue(trie, "589_slot", 2); 
	SetTrieValue(trie, "589_quality", 6); 
	SetTrieValue(trie, "589_level", 20); 
	//SetTrieString(trie, "589_attribs", "352 ;1.0 ;353 ;1.0"); 
	SetTrieValue(trie, "589_ammo", -1); 

//Third Degree
	SetTrieString(trie, "593_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "593_index", 593); 
	SetTrieValue(trie, "593_slot", 2); 
	SetTrieValue(trie, "593_quality", 6); 
	SetTrieValue(trie, "593_level", 10); 
	//SetTrieString(trie, "593_attribs", "107 ; 1.5 ; 128 ; 1 ; 360 ; 1 ; 226 ; 1 ; 66 ; 0.75 ; 64 ; .5 ; 2 ; 2.5"); 
	SetTrieValue(trie, "593_ammo", -1); 

//Phlogistinator
	SetTrieString(trie, "594_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "594_index", 594); 
	SetTrieValue(trie, "594_slot", 0); 
	SetTrieValue(trie, "594_quality", 6); 
	SetTrieValue(trie, "594_level", 10); 
//	SetTrieString(trie, "594_attribs", "368 ;1.0 ;116 ;5.0 ;356 ;1.0 ;357 ;1.2 ;350 ;1.0 ;144 ;1.0 ;15 ;0.0"); 
	//SetTrieString(trie, "594_attribs","368;1 ; 116;5 ; 356;1 ; 144;1 ; 551;1 ; 350;1 ; 201;2" );
	SetTrieValue(trie, "594_ammo", 200); 

//Manmelter
	SetTrieString(trie, "595_classname", "tf_weapon_flaregun_revenge"); 
	SetTrieValue(trie, "595_index", 595); 
	SetTrieValue(trie, "595_slot", 1); 
	SetTrieValue(trie, "595_quality", 6); 
	SetTrieValue(trie, "595_level", 30); 
	//SetTrieString(trie, "595_attribs", "103 ; 1.9 ; 350 ; 1"); 
	SetTrieValue(trie, "595_ammo", -1); 

//Bootlegger
	SetTrieString(trie, "608_classname", "tf_wearable"); 
	SetTrieValue(trie, "608_index", 608); 
	SetTrieValue(trie, "608_slot", 0); 
	SetTrieValue(trie, "608_quality", 6); 
	SetTrieValue(trie, "608_level", 10); 
	//SetTrieString(trie, "608_attribs", "246 ; 10 ; 26 ; 250"); 
	SetTrieValue(trie, "608_ammo", -1); 

//Scottish Handshake
	SetTrieString(trie, "609_classname", "tf_weapon_bottle"); 
	SetTrieValue(trie, "609_index", 609); 
	SetTrieValue(trie, "609_slot", 2); 
	SetTrieValue(trie, "609_quality", 6); 
	SetTrieValue(trie, "609_level", 10); 
	//SetTrieString(trie, "609_attribs", "394 ; 0.35"); 
	SetTrieValue(trie, "609_ammo", -1); 

//Sharp Dresser
	SetTrieString(trie, "638_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "638_index", 638); 
	SetTrieValue(trie, "638_slot", 2); 
	SetTrieValue(trie, "638_quality", 6); 
	SetTrieValue(trie, "638_level", 1); 
	//SetTrieString(trie, "638_attribs", "31 ; 3"); 
	SetTrieValue(trie, "638_ammo", -1); 

//Cozy Camper
	SetTrieString(trie, "642_classname", "tf_wearable"); 
	SetTrieValue(trie, "642_index", 642); 
	SetTrieValue(trie, "642_slot", 1); 
	SetTrieValue(trie, "642_quality", 6); 
	SetTrieValue(trie, "642_level", 10); 
	//SetTrieString(trie, "642_attribs", "57 ; 10 ; 377 ; 0.001 ; 376 ; 1 ; 378 ; 2"); 

//Wrap Assassin
	SetTrieString(trie, "648_classname", "tf_weapon_bat_giftwrap"); 
	SetTrieValue(trie, "648_index", 648); 
	SetTrieValue(trie, "648_slot", 2); 
	SetTrieValue(trie, "648_quality", 6); 
	SetTrieValue(trie, "648_level", 15); 
	//SetTrieString(trie, "648_attribs", "346 ;1.0 ;1 ;0.3"); 
	SetTrieValue(trie, "648_ammo", 1); 

//Spy-cicle
	SetTrieString(trie, "649_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "649_index", 649); 
	SetTrieValue(trie, "649_slot", 2); 
	SetTrieValue(trie, "649_quality", 6); 
	SetTrieValue(trie, "649_level", 1); 
	//SetTrieString(trie, "649_attribs", "347 ; 1 ; 156 ; 1 ; 60 ; 100 ; 361 ; 2 ; 365 ; 3"); 
	SetTrieValue(trie, "649_ammo", 1); 

//Festive Minigun 2011
	SetTrieString(trie, "654_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "654_index", 654); 
	SetTrieValue(trie, "654_slot", 0); 
	SetTrieValue(trie, "654_quality", 6); 
	SetTrieValue(trie, "654_level", 1); 
	//SetTrieString(trie, "654_attribs", "76 ; 5 ; 6 ; .9 ; 16 ; 20"); 
	SetTrieValue(trie, "654_ammo", 200); 

//Holiday Punch
	SetTrieString(trie, "656_classname", "tf_weapon_fists"); 
	SetTrieValue(trie, "656_index", 656); 
	SetTrieValue(trie, "656_slot", 2); 
	SetTrieValue(trie, "656_quality", 6); 
	SetTrieValue(trie, "656_level", 10); 
	//SetTrieString(trie, "656_attribs", "107 ; 1.3 ; 358 ; 1 ; 362 ; 1 ; 369 ; 1 ; 363 ; 1 ; 6 ; 0.25 ; 1 ; 0 ; 128 ; 1 ; 179 ; 1"); 
	SetTrieValue(trie, "656_ammo", -1); 

//Festive Rocket Launcher 2011
	SetTrieString(trie, "658_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "658_index", 658); 
	SetTrieValue(trie, "658_slot", 0); 
	SetTrieValue(trie, "658_quality", 6); 
	SetTrieValue(trie, "658_level", 1); 
	//SetTrieString(trie, "658_attribs", "104 ; 0.32 ; 99 ; 1.3 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1"); 
	SetTrieValue(trie, "658_ammo", 20); 

//Festive Flamethrower 2011
	SetTrieString(trie, "659_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "659_index", 659); 
	SetTrieValue(trie, "659_slot", 0); 
	SetTrieValue(trie, "659_quality", 6); 
	SetTrieValue(trie, "659_level", 1); 
	//SetTrieString(trie, "659_attribs", "171 ; 0.25 ; 256 ; 0.1 ; 255 ; .5 ; 257 ; .05"); 
	SetTrieValue(trie, "659_ammo", 200); 

//Festive Bat 2011
	SetTrieString(trie, "660_classname", "tf_weapon_bat"); 
	SetTrieValue(trie, "660_index", 660); 
	SetTrieValue(trie, "660_slot", 2); 
	SetTrieValue(trie, "660_quality", 6); 
	SetTrieValue(trie, "660_level", 1); 
	//SetTrieString(trie, "660_attribs", ""); 
	SetTrieValue(trie, "660_ammo", -1); 

//Festive Sticky Launcher 2011
	SetTrieString(trie, "661_classname", "tf_weapon_pipebomblauncher"); 
	SetTrieValue(trie, "661_index", 661); 
	SetTrieValue(trie, "661_slot", 1); 
	SetTrieValue(trie, "661_quality", 6); 
	SetTrieValue(trie, "661_level", 1); 
	//SetTrieString(trie, "661_attribs", "96 ; 0.3 ; 78 ; 10 ; 6 ; 0.3"); 
	SetTrieValue(trie, "661_ammo", 24); 

//Festive Wrench 2011
	SetTrieString(trie, "662_classname", "tf_weapon_wrench"); 
	SetTrieValue(trie, "662_index", 662); 
	SetTrieValue(trie, "662_slot", 2); 
	SetTrieValue(trie, "662_quality", 6); 
	SetTrieValue(trie, "662_level", 1); 
	//SetTrieString(trie, "662_attribs", "6 ; 0.35 ; 286 ; 3"); 
	SetTrieValue(trie, "662_ammo", -1); 

//Festive Medigun 2011
	SetTrieString(trie, "663_classname", "tf_weapon_medigun"); 
	SetTrieValue(trie, "663_index", 663); 
	SetTrieValue(trie, "663_slot", 1); 
	SetTrieValue(trie, "663_quality", 6); 
	SetTrieValue(trie, "663_level", 1); 
	//SetTrieString(trie, "663_attribs", "314 ; 2 ; 11 ; 3"); 
	SetTrieValue(trie, "663_ammo", -1); 

//Festive Sniper Rifle 2011
	SetTrieString(trie, "664_classname", "tf_weapon_sniperrifle"); 
	SetTrieValue(trie, "664_index", 664); 
	SetTrieValue(trie, "664_slot", 0); 
	SetTrieValue(trie, "664_quality", 6); 
	SetTrieValue(trie, "664_level", 1); 
	//SetTrieString(trie, "664_attribs", "41 ; 5"); 
	SetTrieValue(trie, "664_ammo", 25); 

//Festive Knife 2011
	SetTrieString(trie, "665_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "665_index", 665); 
	SetTrieValue(trie, "665_slot", 2); 
	SetTrieValue(trie, "665_quality", 6); 
	SetTrieValue(trie, "665_level", 1); 
	//SetTrieString(trie, "665_attribs", "31 ; 3"); 
	SetTrieValue(trie, "665_ammo", -1); 

//Festive Scattergun 2011
	SetTrieString(trie, "669_classname", "tf_weapon_scattergun"); 
	SetTrieValue(trie, "669_index", 669); 
	SetTrieValue(trie, "669_slot", 0); 
	SetTrieValue(trie, "669_quality", 6); 
	SetTrieValue(trie, "669_level", 1); 
	//SetTrieString(trie, "669_attribs", "97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8"); 
	SetTrieValue(trie, "669_ammo", 32); 

//Black Rose
	SetTrieString(trie, "727_classname", "tf_weapon_knife"); 
	SetTrieValue(trie, "727_index", 727); 
	SetTrieValue(trie, "727_slot", 2); 
	SetTrieValue(trie, "727_quality", 6); 
	SetTrieValue(trie, "727_level", 1); 
	//SetTrieString(trie, "727_attribs", "31 ; 3"); 
	SetTrieValue(trie, "727_ammo", -1); 

//Beggar's Bazooka
	SetTrieString(trie, "730_classname", "tf_weapon_rocketlauncher"); 
	SetTrieValue(trie, "730_index", 730); 
	SetTrieValue(trie, "730_slot", 0); 
	SetTrieValue(trie, "730_quality", 6); 
	SetTrieValue(trie, "730_level", 1); 
	//SetTrieString(trie, "730_attribs","411;20 ; 4;7.5 ; 76;10 ; 413;1 ; 417;1 ; 394;0.07 ; 241;0.45 ; 135;.05 ; 15;1 ; 475;1.05" );
	SetTrieValue(trie, "730_ammo", 150); 
	
//Lollichop
	SetTrieString(trie, "739_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "739_index", 739); 
	SetTrieValue(trie, "739_slot", 2); 
	SetTrieValue(trie, "739_quality", 6); 
	SetTrieValue(trie, "739_level", 1); 
	//SetTrieString(trie, "739_attribs", "178 ; .5 ; 2 ; 1.5 ; 267 ; 1 ; 15 ; 0"); 
	SetTrieValue(trie, "739_ammo", -1); 

//Scorch Shot
	SetTrieString(trie, "740_classname", "tf_weapon_flaregun"); 
	SetTrieValue(trie, "740_index", 740); 
	SetTrieValue(trie, "740_slot", 1); 
	SetTrieValue(trie, "740_quality", 6); 
	SetTrieValue(trie, "740_level", 10); 
	//SetTrieString(trie, "740_attribs","99;3 ; 25;0.5 ; 416;3 ; 72;.5 ; 74;.5" ); 
	SetTrieValue(trie, "740_ammo", 16); 

//Rainblower
	SetTrieString(trie, "741_classname", "tf_weapon_flamethrower"); 
	SetTrieValue(trie, "741_index", 741); 
	SetTrieValue(trie, "741_slot", 0); 
	SetTrieValue(trie, "741_quality", 6); 
	SetTrieValue(trie, "741_level", 10); 
	//SetTrieString(trie, "741_attribs", "171 ; 0.25 ; 256 ; 0.1 ; 255 ; .5 ; 257 ; .05"); 
	SetTrieValue(trie, "741_ammo", 200); 

//Cleaner's Carbine
	SetTrieString(trie, "751_classname", "tf_weapon_smg"); 
	SetTrieValue(trie, "751_index", 751); 
	SetTrieValue(trie, "751_slot", 1); 
	SetTrieValue(trie, "751_quality", 6); 
	SetTrieValue(trie, "751_level", 1); 
	//SetTrieString(trie, "751_attribs", "31 ; 30"); 
	SetTrieValue(trie, "751_ammo", 75); 

//Hitman's Heatmaker
	SetTrieString(trie, "752_classname", "tf_weapon_sniperrifle"); 
	SetTrieValue(trie, "752_index", 752); 
	SetTrieValue(trie, "752_slot", 0); 
	SetTrieValue(trie, "752_quality", 6); 
	SetTrieValue(trie, "752_level", 1); 
	//SetTrieString(trie, "752_attribs", "219 ; 1 ; 329 ; 0.1 ; 387 ; 100 ; 398 ; 50 ; 116 ; 6"); 
	SetTrieValue(trie, "752_ammo", 25); 

//Baby Face's Blaster
	SetTrieString(trie, "772_classname", "tf_weapon_pep_brawler_blaster"); 
	SetTrieValue(trie, "772_index", 772); 
	SetTrieValue(trie, "772_slot", 0); 
	SetTrieValue(trie, "772_quality", 6); 
	SetTrieValue(trie, "772_level", 10); 
	//SetTrieString(trie, "772_attribs", "106 ; 0.6 ; 107 ; 1.3 ; 418 ; 1 ; 491 ; 0"); 
	SetTrieValue(trie, "772_ammo", 32); 

//Pretty Boy's Pocket Pistol
	SetTrieString(trie, "773_classname", "tf_weapon_handgun_scout_secondary"); 
	SetTrieValue(trie, "773_index", 773); 
	SetTrieValue(trie, "773_slot", 1); 
	SetTrieValue(trie, "773_quality", 6); 
	SetTrieValue(trie, "773_level", 10); 
	//SetTrieString(trie, "773_attribs", "26 ; 150 ; 275 ; 1"); 
	SetTrieValue(trie, "773_ammo", 36); 

//Escape Plan
	SetTrieString(trie, "775_classname", "tf_weapon_shovel"); 
	SetTrieValue(trie, "775_index", 775); 
	SetTrieValue(trie, "775_slot", 2); 
	SetTrieValue(trie, "775_quality", 6); 
	SetTrieValue(trie, "775_level", 10); 
	//SetTrieString(trie, "775_attribs", "107 ; 1.45 ; 128 ; 1 ; 414 ; 0"); 
	SetTrieValue(trie, "775_ammo", -1); 

//Red-Tape Recorder
	SetTrieString(trie, "810_classname", "tf_weapon_sapper"); 
	SetTrieValue(trie, "810_index", 810); 
	SetTrieValue(trie, "810_slot", 1); 
	SetTrieValue(trie, "810_quality", 6); 
	SetTrieValue(trie, "810_level", 1); 
	//SetTrieString(trie, "810_attribs", "433 ;0.5 ;426 ;0.0"); 
	SetTrieValue(trie, "810_ammo", -1); 

//Huo Long Heater
	SetTrieString(trie, "811_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "811_index", 811); 
	SetTrieValue(trie, "811_slot", 0); 
	SetTrieValue(trie, "811_quality", 6); 
	SetTrieValue(trie, "811_level", 1); 
	//SetTrieString(trie, "811_attribs","430;150 ; 431;0 ; 60;.3 ; 87;0.5 ; 527;1" );

//Flying Guillotine
	SetTrieString(trie, "812_classname", "tf_weapon_cleaver"); 
	SetTrieValue(trie, "812_index", 812); 
	SetTrieValue(trie, "812_slot", 1); 
	SetTrieValue(trie, "812_quality", 6); 
	SetTrieValue(trie, "812_level", 1); 
	//SetTrieString(trie, "812_attribs","278;.25 ; 616;1" );
	SetTrieValue(trie, "812_ammo", 1); 

//Neon Annihilator
	SetTrieString(trie, "813_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "813_index", 813); 
	SetTrieValue(trie, "813_slot", 2); 
	SetTrieValue(trie, "813_quality", 6); 
	SetTrieValue(trie, "813_level", 1); 
	//SetTrieString(trie, "813_attribs", "146 ; 1 ; 438 ; 1 ; 2 ; 1.5"); 
	SetTrieValue(trie, "813_ammo", -1); 

//Promo Red-Tape Recorder
	SetTrieString(trie, "831_classname", "tf_weapon_sapper"); 
	SetTrieValue(trie, "831_index", 831); 
	SetTrieValue(trie, "831_slot", 1); 
	SetTrieValue(trie, "831_quality", 1); 
	SetTrieValue(trie, "831_level", 1); 
	//SetTrieString(trie, "831_attribs", "433 ;0.5 ;426 ;0.0 ;153 ;1.0"); 
	SetTrieValue(trie, "831_ammo", -1); 

//Promo Huo Long Heater
	SetTrieString(trie, "832_classname", "tf_weapon_minigun"); 
	SetTrieValue(trie, "832_index", 832); 
	SetTrieValue(trie, "832_slot", 0); 
	SetTrieValue(trie, "832_quality", 1); 
	SetTrieValue(trie, "832_level", 1); 
	//SetTrieString(trie, "832_attribs", "430 ; 50 ; 431 ; 0"); 
	SetTrieValue(trie, "832_ammo", 200); 

//Promo Flying Guillotine
	SetTrieString(trie, "833_classname", "tf_weapon_cleaver"); 
	SetTrieValue(trie, "833_index", 833); 
	SetTrieValue(trie, "833_slot", 1); 
	SetTrieValue(trie, "833_quality", 1); 
	SetTrieValue(trie, "833_level", 1); 
	//SetTrieString(trie, "833_attribs", "435 ;1.0 ;437 ;65536.0 ;15 ;0.0 ;153 ;1.0"); 
	SetTrieValue(trie, "833_ammo", 1); 

//Promo Neon Annihilator
	SetTrieString(trie, "834_classname", "tf_weapon_fireaxe"); 
	SetTrieValue(trie, "834_index", 834); 
	SetTrieValue(trie, "834_slot", 2); 
	SetTrieValue(trie, "834_quality", 1); 
	SetTrieValue(trie, "834_level", 1); 
	//SetTrieString(trie, "834_attribs", "146 ; 1 ; 438 ; 1 ; 2 ; 1.5"); 
	SetTrieValue(trie, "834_ammo", -1); 

//Ap-Sap
	SetTrieString(trie, "933_classname", "tf_weapon_sapper"); 
	SetTrieValue(trie, "933_index", 933); 
	SetTrieValue(trie, "933_slot", 1); 
	SetTrieValue(trie, "933_quality", 6); 
	SetTrieValue(trie, "933_level", 1); 
	//SetTrieString(trie, "933_attribs", "451 ;1.0 ;452 ;3.0"); 
	SetTrieValue(trie, "933_ammo", -1); 

//Bat Outta Hell
	SetTrieString(trie, "939_classname", "saxxy"); 
	SetTrieValue(trie, "939_index", 939); 
	SetTrieValue(trie, "939_slot", 2); 
	SetTrieValue(trie, "939_quality", 6); 
	SetTrieValue(trie, "939_level", 5); 
	//SetTrieString(trie, "939_attribs", ""); 
	SetTrieValue(trie, "939_ammo", -1); 

//Quackenbirdt
	SetTrieString(trie, "947_classname", "tf_weapon_invis"); 
	SetTrieValue(trie, "947_index", 947); 
	SetTrieValue(trie, "947_slot", 4); 
	SetTrieValue(trie, "947_quality", 6); 
	SetTrieValue(trie, "947_level", 30); 
	//SetTrieString(trie, "947_attribs", ""); 
	SetTrieValue(trie, "947_ammo", -1); 

//Memory Maker
	SetTrieString(trie, "954_classname", "saxxy"); 
	SetTrieValue(trie, "954_index", 954); 
	SetTrieValue(trie, "954_slot", 2); 
	SetTrieValue(trie, "954_quality", 6); 
	SetTrieValue(trie, "954_level", 50); 
	//SetTrieString(trie, "954_attribs", ""); 
	SetTrieValue(trie, "954_ammo", -1); 

//Loose Cannon
	SetTrieString(trie, "996_classname", "tf_weapon_cannon"); 
	SetTrieValue(trie, "996_index", 996); 
	SetTrieValue(trie, "996_slot", 0); 
	SetTrieValue(trie, "996_quality", 6); 
	SetTrieValue(trie, "996_level", 10); 
	//SetTrieString(trie, "996_attribs", "103 ; 2 ; 4 ; 5 ; 318 ; .3 ; 6 ; 0.3 ; 1 ; 0.7 ; 76 ; 15 ; 15 ; 1 ; 43 ; 1"); 
	SetTrieValue(trie, "996_ammo", 16); 

//Rescue Ranger
	SetTrieString(trie, "997_classname", "tf_weapon_shotgun_building_rescue"); 
	SetTrieValue(trie, "997_index", 997); 
	SetTrieValue(trie, "997_slot", 0); 
	SetTrieValue(trie, "997_quality", 6); 
	SetTrieValue(trie, "997_level", 1); 
	//SetTrieString(trie, "997_attribs", "469 ; 1 ; 474 ; 100 ; 4 ; 3.3 ; 37 ; 3 ; 6 ; 0.5"); 
	SetTrieValue(trie, "997_ammo", 16); 

//Vaccinator
	SetTrieString(trie, "998_classname", "tf_weapon_medigun"); 
	SetTrieValue(trie, "998_index", 998); 
	SetTrieValue(trie, "998_slot", 1); 
	SetTrieValue(trie, "998_quality", 6); 
	SetTrieValue(trie, "998_level", 8); 
	//SetTrieString(trie, "998_attribs","10;5 ; 144;3 ; 473;3 ; 292;1 ; 293;2 ; 60;.5 ; 64;.5 ; 66;.5 ; 8;2" );
	SetTrieValue(trie, "998_ammo", -1); 

//Ham Shank
	SetTrieString(trie, "1013_classname", "saxxy"); 
	SetTrieValue(trie, "1013_index", 1013); 
	SetTrieValue(trie, "1013_slot", 2); 
	SetTrieValue(trie, "1013_quality", 6); 
	SetTrieValue(trie, "1013_level", 5); 
	//SetTrieString(trie, "1013_attribs", ""); 
	SetTrieValue(trie, "1013_ammo", -1); 

//force a nature
	SetTrieString(trie, "45_classname", "tf_weapon_scattergun"); 
	SetTrieValue(trie, "45_index", 45); 
	SetTrieValue(trie, "45_slot", 0); 
	SetTrieValue(trie, "45_quality", 6); 
	SetTrieValue(trie, "45_level", 10); 
	//SetTrieString(trie, "45_attribs","44;1 ; 45;16 ; 3;0.166 ; 43;1 ; 1;.35 ; 106;5 ; 37;5 ; 97;0.8" );
	SetTrieValue(trie, "45_ammo", 32); 

//bottle
	SetTrieString(trie, "1_classname", "tf_weapon_bottle");
	SetTrieValue(trie, "1_index", 1);
	SetTrieValue(trie, "1_slot", 2);
	SetTrieValue(trie, "1_quality", 0);
	SetTrieValue(trie, "1_level", 1);
	//SetTrieString(trie, "1_attribs", "394 ; 0.35");
	SetTrieValue(trie, "1_ammo", -1);
    
//Upgradeable shotgun other classes
	SetTrieString(trie, "4199_classname", "tf_weapon_shotgun_soldier");
	SetTrieValue(trie, "4199_index", 199);
	SetTrieValue(trie, "4199_slot", 1);
	SetTrieValue(trie, "4199_quality", 6);
	SetTrieValue(trie, "4199_level", 1);
	//SetTrieString(trie, "4199_attribs", "");
	SetTrieValue(trie, "4199_ammo", 32);

//valve rocket launcher
	SetTrieString(trie, "9018_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "9018_index", 18);
	SetTrieValue(trie, "9018_slot", 0);
	SetTrieValue(trie, "9018_quality", 8);
	SetTrieValue(trie, "9018_level", 100);
	//SetTrieString(trie, "9018_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9018_ammo", 200);

//valve sticky launcher
	SetTrieString(trie, "9020_classname", "tf_weapon_pipebomblauncher");
	SetTrieValue(trie, "9020_index", 20);
	SetTrieValue(trie, "9020_slot", 1);
	SetTrieValue(trie, "9020_quality", 8);
	SetTrieValue(trie, "9020_level", 100);
	//SetTrieString(trie, "9020_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9020_ammo", 200);

//valve sniper rifle
	SetTrieString(trie, "9014_classname", "tf_weapon_sniperrifle");
	SetTrieValue(trie, "9014_index", 14);
	SetTrieValue(trie, "9014_slot", 0);
	SetTrieValue(trie, "9014_quality", 8);
	SetTrieValue(trie, "9014_level", 100);
	//SetTrieString(trie, "9014_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9014_ammo", 200);

//valve scattergun
	SetTrieString(trie, "9013_classname", "tf_weapon_scattergun");
	SetTrieValue(trie, "9013_index", 13);
	SetTrieValue(trie, "9013_slot", 0);
	SetTrieValue(trie, "9013_quality", 8);
	SetTrieValue(trie, "9013_level", 100);
	//SetTrieString(trie, "9013_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9013_ammo", 200);

//valve flamethrower
	SetTrieString(trie, "9021_classname", "tf_weapon_flamethrower");
	SetTrieValue(trie, "9021_index", 21);
	SetTrieValue(trie, "9021_slot", 0);
	SetTrieValue(trie, "9021_quality", 8);
	SetTrieValue(trie, "9021_level", 100);
	//SetTrieString(trie, "9021_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9021_ammo", 400);

//valve syringe gun
	SetTrieString(trie, "9017_classname", "tf_weapon_syringegun_medic");
	SetTrieValue(trie, "9017_index", 17);
	SetTrieValue(trie, "9017_slot", 0);
	SetTrieValue(trie, "9017_quality", 8);
	SetTrieValue(trie, "9017_level", 100);
	//SetTrieString(trie, "9017_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9017_ammo", 300);

//valve minigun
	SetTrieString(trie, "9015_classname", "tf_weapon_minigun");
	SetTrieValue(trie, "9015_index", 15);
	SetTrieValue(trie, "9015_slot", 0);
	SetTrieValue(trie, "9015_quality", 8);
	SetTrieValue(trie, "9015_level", 100);
	//SetTrieString(trie, "9015_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9015_ammo", 400);

//valve revolver
	SetTrieString(trie, "9024_classname", "tf_weapon_revolver");
	SetTrieValue(trie, "9024_index", 24);
	SetTrieValue(trie, "9024_slot", 0);
	SetTrieValue(trie, "9024_quality", 8);
	SetTrieValue(trie, "9024_level", 100);
	//SetTrieString(trie, "9024_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9024_ammo", 100);

//valve shotgun engineer
	SetTrieString(trie, "9009_classname", "tf_weapon_shotgun_primary");
	SetTrieValue(trie, "9009_index", 9);
	SetTrieValue(trie, "9009_slot", 0);
	SetTrieValue(trie, "9009_quality", 8);
	SetTrieValue(trie, "9009_level", 100);
	//SetTrieString(trie, "9009_attribs", "2 ; 1.15 ; 4 ; 1.5 ; 6 ; 0.85 ; 110 ; 15.0 ; 20 ; 1.0 ; 26 ; 50.0 ; 31 ; 5.0 ; 32 ; 0.30 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.15 ; 134 ; 2.0");
	SetTrieValue(trie, "9009_ammo", 100);

//valve medigun
	SetTrieString(trie, "9029_classname", "tf_weapon_medigun");
	SetTrieValue(trie, "9029_index", 29);
	SetTrieValue(trie, "9029_slot", 1);
	SetTrieValue(trie, "9029_quality", 8);
	SetTrieValue(trie, "9029_level", 100);
	//SetTrieString(trie, "9029_attribs", "8 ; 1.15 ; 10 ; 1.15 ; 13 ; 0.0 ; 26 ; 50.0 ; 53 ; 1.0 ; 60 ; 0.85 ; 123 ; 1.5 ; 134 ; 2.0");
	SetTrieValue(trie, "9029_ammo", -1);

//ludmila
	SetTrieString(trie, "2041_classname", "tf_weapon_minigun");
	SetTrieValue(trie, "2041_index", 15);
	SetTrieValue(trie, "2041_slot", 0);
	SetTrieValue(trie, "2041_quality", 10);
	SetTrieValue(trie, "2041_level", 5);
	//SetTrieString(trie, "2041_attribs", "29 ; 1 ; 86 ; 1.2 ; 5 ; 1.1");
	SetTrieValue(trie, "2041_ammo", 200);
	SetTrieString(trie, "2041_viewmodel", "models/weapons/c_models/c_v_ludmila/c_v_ludmila.mdl");

//spycrab pda
	SetTrieString(trie, "9027_classname", "tf_weapon_pda_spy");
	SetTrieValue(trie, "9027_index", 27);
	SetTrieValue(trie, "9027_slot", 3);
	SetTrieValue(trie, "9027_quality", 2);
	SetTrieValue(trie, "9027_level", 100);
	//SetTrieString(trie, "9027_attribs", "128 ; 1.0 ; 412 ; 0.0 ; 70 ; 2.0 ; 53 ; 1.0 ; 68 ; -3.0 ; 400 ; 1.0 ; 134 ; 9.0");
	SetTrieValue(trie, "9027_ammo", -1);

//fire retardant suit (revolver does no damage)
	SetTrieString(trie, "2061_classname", "tf_weapon_revolver");
	SetTrieValue(trie, "2061_index", 61);
	SetTrieValue(trie, "2061_slot", 0);
	SetTrieValue(trie, "2061_quality", 10);
	SetTrieValue(trie, "2061_level", 5);
	//SetTrieString(trie, "2061_attribs", "168 ; 1.0 ; 1 ; 0.0");
	SetTrieValue(trie, "2061_ammo", -1);

//valve cheap rocket launcher
	SetTrieString(trie, "8018_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "8018_index", 18);
	SetTrieValue(trie, "8018_slot", 0);
	SetTrieValue(trie, "8018_quality", 8);
	SetTrieValue(trie, "8018_level", 100);
	//SetTrieString(trie, "8018_attribs", "2 ; 100.0 ; 4 ; 91.0 ; 6 ; 0.25 ; 110 ; 500.0 ; 26 ; 250.0 ; 31 ; 10.0 ; 107 ; 3.0 ; 97 ; 0.4 ; 134 ; 2.0");
	SetTrieValue(trie, "8018_ammo", 200);

//PCG cheap Community rocket launcher
	SetTrieString(trie, "7018_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "7018_index", 18);
	SetTrieValue(trie, "7018_slot", 0);
	SetTrieValue(trie, "7018_quality", 7);
	SetTrieValue(trie, "7018_level", 100);
	//SetTrieString(trie, "7018_attribs", "26 ; 500.0 ; 110 ; 500.0 ; 6 ; 0.25 ; 4 ; 200.0 ; 2 ; 100.0 ; 97 ; 0.2 ; 134 ; 4.0");
	SetTrieValue(trie, "7018_ammo", 200);

//derpFaN
	SetTrieString(trie, "8045_classname", "tf_weapon_scattergun");
	SetTrieValue(trie, "8045_index", 45);
	SetTrieValue(trie, "8045_slot", 0);
	SetTrieValue(trie, "8045_quality", 8);
	SetTrieValue(trie, "8045_level", 99);
	//SetTrieString(trie, "8045_attribs", "44 ; 1.0 ; 6 ; 0.25 ; 45 ; 2.0 ; 2 ; 10.0 ; 4 ; 100.0 ; 43 ; 1.0 ; 26 ; 500.0 ; 110 ; 500.0 ; 97 ; 0.2 ; 31 ; 10.0 ; 107 ; 3.0 ; 134 ; 4.0");
	SetTrieValue(trie, "8045_ammo", 200);

//Trilby's Rebel Pack - Texas Ten-Shot
	SetTrieString(trie, "2141_classname", "tf_weapon_shotgun_primary");	//used to be tf_weapon_sentry_revenge
	SetTrieValue(trie, "2141_index", 141);
	SetTrieValue(trie, "2141_slot", 0);
	SetTrieValue(trie, "2141_quality", 10);
	SetTrieValue(trie, "2141_level", 10);
	//SetTrieString(trie, "2141_attribs", "4 ; 1.66 ; 19 ; 0.15 ; 76 ; 1.25 ; 96 ; 1.8 ; 134 ; 3.0 ; 3 ; 1.0");
	SetTrieValue(trie, "2141_ammo", 40);

//Trilby's Rebel Pack - Texan Love
	SetTrieString(trie, "2161_classname", "tf_weapon_shotgun_pyro");
	SetTrieValue(trie, "2161_index", 460);
	SetTrieValue(trie, "2161_slot", 1);
	SetTrieValue(trie, "2161_quality", 10);
	SetTrieValue(trie, "2161_level", 10);
	//SetTrieString(trie, "2161_attribs", "2 ; 1.4 ; 106 ; 0.65 ; 6 ; 0.80 ; 146 ; 1.0 ; 97 ; 0.7 ; 69 ; 0.80 ; 45 ; 0.3 ; 106 ; 0.0");
	SetTrieValue(trie, "2161_ammo", 24);

//direct hit LaN
	SetTrieString(trie, "2127_classname", "tf_weapon_rocketlauncher_directhit");
	SetTrieValue(trie, "2127_index", 127);
	SetTrieValue(trie, "2127_slot", 0);
	SetTrieValue(trie, "2127_quality", 10);
	SetTrieValue(trie, "2127_level", 1);
	//SetTrieString(trie, "2127_attribs", "3 ; 0.5 ; 103 ; 1.8 ; 2 ; 1.25 ; 114 ; 1.0 ; 67 ; 1.1");
	SetTrieValue(trie, "2127_ammo", 20);

//dalokohs bar Effect
	SetTrieString(trie, "2159_classname", "tf_weapon_lunchbox");
	SetTrieValue(trie, "2159_index", 159);
	SetTrieValue(trie, "2159_slot", 1);
	SetTrieValue(trie, "2159_quality", 6);
	SetTrieValue(trie, "2159_level", 1);
	//SetTrieString(trie, "2159_attribs", "140 ; 50 ; 139 ; 1");
	SetTrieValue(trie, "2159_ammo", 1);

//fishcake Effect
	SetTrieString(trie, "2433_classname", "tf_weapon_lunchbox");
	SetTrieValue(trie, "2433_index", 433);
	SetTrieValue(trie, "2433_slot", 1);
	SetTrieValue(trie, "2433_quality", 6);
	SetTrieValue(trie, "2433_level", 1);
	//SetTrieString(trie, "2433_attribs", "140 ; 50 ; 139 ; 1");
	SetTrieValue(trie, "2433_ammo", 1);

//The Army of One
	SetTrieString(trie, "2228_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "2228_index", 228);
	SetTrieValue(trie, "2228_slot", 0);
	SetTrieValue(trie, "2228_quality", 10);
	SetTrieValue(trie, "2228_level", 5);
	SetTrieString(trie, "2228_attribs", "2 ; 5.0 ; 99 ; 3.0 ; 521 ; 1.0 ; 3 ; 0.25 ; 104 ; 0.3 ; 77 ; 0.0 ; 16 ; 0.0");
	SetTrieValue(trie, "2228_ammo", 0);
	SetTrieString(trie, "2228_model", "models/advancedweaponiser/fbomb/c_fbomb.mdl");
	SetTrieString(trie, "2228_viewmodel", "models/advancedweaponiser/fbomb/c_fbomb.mdl");

//Shotgun for all
	SetTrieString(trie, "2009_classname", "tf_weapon_sentry_revenge");
	SetTrieValue(trie, "2009_index", 141);
	SetTrieValue(trie, "2009_slot", 0);
	SetTrieValue(trie, "2009_quality", 0);
	SetTrieValue(trie, "2009_level", 1);
	//SetTrieString(trie, "2009_attribs", "");
	SetTrieValue(trie, "2009_ammo", 32);

//Another weapon by Trilby- Fighter's Falcata
	SetTrieString(trie, "2193_classname", "tf_weapon_club");
	SetTrieValue(trie, "2193_index", 193);
	SetTrieValue(trie, "2193_slot", 2);
	SetTrieValue(trie, "2193_quality", 10);
	SetTrieValue(trie, "2193_level", 5);
	SetTrieString(trie, "2193_attribs", "6 ; 0.8 ; 2 ; 1.1 ; 15 ; 0 ; 98 ; -15");
	SetTrieValue(trie, "2193_ammo", -1);

//Khopesh Climber- MECHA! (the Slag)
	SetTrieString(trie, "2171_classname", "tf_weapon_club");
	SetTrieValue(trie, "2171_index", 171);
	SetTrieValue(trie, "2171_slot", 2);
	SetTrieValue(trie, "2171_quality", 10);
	SetTrieValue(trie, "2171_level", 11);
	SetTrieString(trie, "2171_attribs", "1 ; 0.9 ; 5 ; 1.95 ; 149 ; 6.0");
	SetTrieValue(trie, "2171_ammo", -1);
	SetTrieString(trie, "2171_model", "models/advancedweaponiser/w_sickle_sniper.mdl");
	SetTrieString(trie, "2171_viewmodel", "models/advancedweaponiser/w_sickle_sniper.mdl");

//Robin's new cheap Rocket Launcher
	SetTrieString(trie, "9205_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "9205_index", 205);
	SetTrieValue(trie, "9205_slot", 0);
	SetTrieValue(trie, "9205_quality", 8);
	SetTrieValue(trie, "9205_level", 100);
	SetTrieString(trie, "9205_attribs", "2 ; 10100.0 ; 4 ; 1100.0 ; 6 ; 0.25 ; 16 ; 250.0 ; 31 ; 10.0 ; 103 ; 1.5 ; 107 ; 2.0 ; 134 ; 2.0");
	SetTrieValue(trie, "9205_ammo", 200);

//Trilby's Rebel Pack - Rebel's Curse
	SetTrieString(trie, "2197_classname", "tf_weapon_wrench");
	SetTrieValue(trie, "2197_index", 197);
	SetTrieValue(trie, "2197_slot", 2);
	SetTrieValue(trie, "2197_quality", 10);
	SetTrieValue(trie, "2197_level", 13);
	SetTrieString(trie, "2197_attribs", "156 ; 1.0 ; 2 ; 1.05 ; 107 ; 1.1 ; 62 ; 0.90 ; 64 ; 0.90 ; 125 ; -10.0 ; 5 ; 1.2 ; 81 ; 0.75 ; 436 ; 1.0");
	SetTrieValue(trie, "2197_ammo", -1);
	SetTrieString(trie, "2197_model", "models/custom/weapons/rebelscurse/c_wrench_v2.mdl");
	SetTrieString(trie, "2197_viewmodel", "models/custom/weapons/rebelscurse/c_wrench_v2.mdl");

//Jar of Ants - Ant'eh'gen
	SetTrieString(trie, "2058_classname", "tf_weapon_jar");
	SetTrieValue(trie, "2058_index", 58);
	SetTrieValue(trie, "2058_slot", 1);
	SetTrieValue(trie, "2058_quality", 10);
	SetTrieValue(trie, "2058_level", 6);
	SetTrieString(trie, "2058_attribs", "149 ; 10.0 ; 134 ; 12.0");
	SetTrieValue(trie, "2058_ammo", 1);
	SetTrieString(trie, "2058_model", "models/custom/weapons/antehgen/urinejar.mdl");
	SetTrieString(trie, "2058_viewmodel", "models/custom/weapons/antehgen/urinejar.mdl");

//The Horsemann's Axe
	SetTrieString(trie, "9266_classname", "tf_weapon_sword");
	SetTrieValue(trie, "9266_index", 266);
	SetTrieValue(trie, "9266_slot", 2);
	SetTrieValue(trie, "9266_quality", 5);
	SetTrieValue(trie, "9266_level", 100);
	SetTrieString(trie, "9266_attribs", "15 ; 0 ; 26 ; 600.0 ; 2 ; 999.0 ; 107 ; 4.0 ; 109 ; 0.0 ; 57 ; 50.0 ; 69 ; 0.0 ; 68 ; -1 ; 53 ; 1.0 ; 27 ; 1.0 ; 180 ; -25 ; 219 ; 1.0 ; 134 ; 8.0");
	SetTrieValue(trie, "9266_ammo", -1);

//Goldslinger
	SetTrieString(trie, "5142_classname", "tf_weapon_robot_arm");
	SetTrieValue(trie, "5142_index", 142);
	SetTrieValue(trie, "5142_slot", 2);
	SetTrieValue(trie, "5142_quality", 6);
	SetTrieValue(trie, "5142_level", 25);
	SetTrieString(trie, "5142_attribs", "124 ; 1 ; 26 ; 25.0 ; 15 ; 0 ; 150 ; 1");
	SetTrieValue(trie, "5142_ammo", -1);
//	SetTrieString(trie, "5142_model", "models/custom/weapons/goldslinger/engineer_v3.mdl"); //horridly broken
//	SetTrieString(trie, "5142_model", "models/custom/weapons/goldslinger/c_engineer_gunslinger.mdl");	//also does not work
	SetTrieString(trie, "5142_viewmodel", "models/custom/weapons/goldslinger/c_engineer_gunslinger.mdl");
	
	
		//HOPEFULLY THIS WILL OVERWRITE
	SetTrieString(trie, "730_attribs","411 ; 20 ; 4 ; 5 ; 76 ; 10 ; 413 ; 1 ; 417 ; 1 ; 394 ; 0.07 ; 241 ; 0.55 ; 135 ; .05 ; 15 ; 0 ; 475 ; 1.05 ; 214 ; 1" );
	SetTrieString(trie, "18_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "127_attribs","103 ; 3.5 ; 100 ; 0.01 ; 2 ; 3 ; 114 ; 1 ; 214 ; 1 ; 215 ; 60" );
	SetTrieString(trie, "414_attribs","103 ; 1.5 ; 6 ; 0.5 ; 1 ; 1 ; 4 ; 1.5 ; 318 ; 0.9 ; 76 ; 2 ; 488 ; 3 ; 214 ; 1" );
	SetTrieString(trie, "228_attribs","26 ; 100 ; 16 ; 150 ; 5 ; 1 ; 180 ; 150 ; 3 ; 0.75 ; 214 ; 1" );
	SetTrieString(trie, "1085_attribs","26 ; 100 ; 16 ; 150 ; 5 ; 1 ; 180 ; 150 ; 3 ; 0.75 ; 214 ; 1" );
	SetTrieString(trie, "441_attribs","28 ; 1 ; 281 ; 1 ; 103 ; 2.5 ; 3 ; 0.25 ; 318 ; 0.05 ; 285 ; 1 ; 75 ; 10 ; 214 ; 1" );
	SetTrieString(trie, "444_attribs","259 ; 1 ; 252 ; 0.01 ; 2 ; 100 ; 129 ; 10 ; 214 ; 1" );
	SetTrieString(trie, "21_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4 ; 214 ; 1" );
	SetTrieString(trie, "40_attribs","255 ; 3 ; 256 ; 2 ; 24 ; 1 ; 162 ; 1.5 ; 164 ; 1.5 ; 214 ; 1" );
	SetTrieString(trie, "1146_attribs","255 ; 3 ; 256 ; 2 ; 24 ; 1 ; 162 ; 1.5 ; 164 ; 1.5 ; 214 ; 1" );
	SetTrieString(trie, "351_attribs","58 ; 2.5 ; 144 ; 1 ; 275 ; 1 ; 135 ; 0 ; 318 ; 0.5 ; 78 ; 3 ; 214 ; 1" );
	SetTrieString(trie, "740_attribs","99 ; 3 ; 25 ; 0.5 ; 416 ; 3 ; 72 ; .5 ; 74 ; .5 ; 214 ; 1" );
	SetTrieString(trie, "39_attribs","6 ; 0.25 ; 78 ; 3 ; 214 ; 1" );
	SetTrieString(trie, "1081_attribs","6 ; 0.25 ; 78 ; 3 ; 214 ; 1" );
	SetTrieString(trie, "595_attribs","103 ; 1.9 ; 350 ; 1 ; 96 ; 0.8 ; 6 ; 0.8 ; 2 ; 2 ; 74 ; 0 ; 20 ; 1 ; 367 ; 1 ; 28 ; 0 ; 214 ; 1" );
	SetTrieString(trie, "415_attribs","178 ; 0.05 ; 265 ; 60 ; 214 ; 1 ; 6 ; 0.75 ; 96 ; 0.75" );
	SetTrieString(trie, "2_attribs","178 ; .5 ; 2 ; 1.5 ; 267 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "348_attribs","208 ; 1 ; 20 ; 1 ; 6 ; 0.3 ; 1 ; 0.5 ; 214 ; 1" );
	SetTrieString(trie, "214_attribs","26 ; 100 ; 180 ; 150 ; 107 ; 1.17 ; 128 ; 0 ; 214 ; 1 ; 412 ; 1 ; 62 ; 1" );
	SetTrieString(trie, "215_attribs","178 ; .2 ; 26 ; 25 ; 107 ; 1.1 ; 57 ; 5 ; 214 ; 1 ; 66 ; 0.5" );
	SetTrieString(trie, "326_attribs","69 ; 0 ; 2 ; 3 ; 108 ; 3 ; 214 ; 1" );
	SetTrieString(trie, "153_attribs","137 ; 10 ; 146 ; 1 ; 169 ; 0.1 ; 2 ; 1 ; 252 ; 0.01 ; 214 ; 1 ; 128 ; 1 ; 67 ; 1.5 ; 206 ; 3" );
	SetTrieString(trie, "813_attribs","146 ; 1 ; 438 ; 1 ; 2 ; 2 ; 214 ; 1" );
	SetTrieString(trie, "38_attribs","20 ; 1 ; 21 ; 0 ; 22 ; 1 ; 2 ; 1.5 ; 638 ; 0 ; 214 ; 1" );
	SetTrieString(trie, "593_attribs","107 ; 1.3 ; 128 ; 1 ; 360 ; 1 ; 226 ; 1 ; 66 ; 0.75 ; 64 ; .5 ; 2 ; 2 ; 214 ; 1" );
	SetTrieString(trie, "412_attribs","144 ; 1 ; 6 ; 0.001 ; 1 ; 0.5 ; 96 ; 0.3 ; 3 ; 0.4 ; 107 ; 1.25 ; 76 ; 2 ; 214 ; 1" );
	SetTrieString(trie, "19_attribs","411 ; 10 ; 4 ; 4 ; 76 ; 10 ; 413 ; 1 ; 417 ; 1 ; 394 ; 0.08 ; 241 ; 0.75 ; 15 ; 0 ; 470 ; 0.5 ; 214 ; 1" );
	SetTrieString(trie, "20_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3 ; 214 ; 1" );
	SetTrieString(trie, "130_attribs","119 ; 1 ; 4 ; 4 ; 76 ; 10 ; 121 ; 1 ; 78 ; 3 ; 88 ; 60 ; 120 ; .6 ; 96 ; 0.5 ; 6 ; 0.5 ; 214 ; 1" );
	SetTrieString(trie, "308_attribs","103 ; 2.7 ; 2 ; 2.5 ; 3 ; 0.25 ; 127 ; 2 ; 207 ; 1.50 ; 15 ; 1 ; 99 ; 1.1 ; 214 ; 1" );
	SetTrieString(trie, "996_attribs","103 ; 1 ; 4 ; 1 ; 318 ; 1 ; 6 ; 1 ; 1 ; 1.5 ; 76 ; 5 ; 15 ; 1 ; 43 ; 1 ; 466 ; 1 ; 179 ; 1 ; 207 ; .25 ; 15 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "405_attribs","246 ; 10 ; 26 ; 200" );
	SetTrieString(trie, "608_attribs","246 ; 10 ; 26 ; 200" );
	SetTrieString(trie, "406_attribs","247 ; 1 ; 248 ; 700 ; 60 ; 0.8 ; 64 ; 0.85 ; 214 ; 1" );
	SetTrieString(trie, "131_attribs","60 ; 0.25 ; 64 ; 0.25 ; 527 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "1144_attribs","60 ; 0.25 ; 64 ; 0.25 ; 527 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "1_attribs","394 ; 0.5 ; 214 ; 1" );
	SetTrieString(trie, "327_attribs","202 ; 10 ; 214 ; 1" );
	SetTrieString(trie, "132_attribs","292 ; 6 ; 388 ; 6 ; 219 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "1082_attribs","292 ; 6 ; 388 ; 6 ; 219 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "266_attribs","292 ; 6 ; 388 ; 6 ; 219 ; 1 ; 214 ; 1" );
	SetTrieString(trie, "482_attribs","292 ; 6 ; 388 ; 6 ; 219 ; 1 ; 214 ; 1 ; 215 ; 300 ; 216 ; 600" );
	SetTrieString(trie, "357_attribs","220 ; 100 ; 226 ; 1 ; 180 ; 500 ; 125 ; 150 ; 140 ; -150 ; 214 ; 1" );
	SetTrieString(trie, "416_attribs","178 ; .5 ; 2 ; 2.5 ; 267 ; 1 ; 15 ; 0 ; 5 ; 1.75" );
	SetTrieString(trie, "128_attribs","2 ; 3.5 ; 128 ; 1" );
	SetTrieString(trie, "775_attribs","107 ; 1.45 ; 128 ; 1 ; 414 ; 0 ; 235 ; 1" );
	SetTrieString(trie, "447_attribs","251 ; 1 ; 1 ; 0 ; 264 ; 20 ; 263 ; 10 ; 394 ; 0.25 ; 107 ; 1.25 ; 128 ; 1" );
	SetTrieString(trie, "133_attribs","135 ; 0 ; 275 ; 1 ; 112 ; 0.05 ; 107 ; 1.25" );
	SetTrieString(trie, "354_attribs","116 ; 3 ; 57 ; 15" );
	SetTrieString(trie, "129_attribs","116 ; 1 ; 357 ; 4" );
	SetTrieString(trie, "226_attribs","116 ; 2 ; 357 ; 5 ; 26 ; 100" );
	SetTrieString(trie, "811_attribs","430 ; 150 ; 431 ; 0 ; 60 ; .3 ; 87 ; 0.5 ; 527 ; 1" );
	SetTrieString(trie, "15_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "424_attribs","107 ; 1.3 ; 1 ; 0.8 ; 75 ; 2.13 ; 238 ; 1 ; 87 ; 0.1 ; 128 ; 1" );
	SetTrieString(trie, "312_attribs","2 ; 2 ; 86 ; 2 ; 183 ; 0.005 ; 266 ; 1 ; 106 ; 0.1" );
	SetTrieString(trie, "41_attribs","32 ; 2 ; 1 ; 0.66 ; 76 ; 10 ; 6 ; .1 ; 106 ; 5 ; 323 ; 2" );
	SetTrieString(trie, "159_attribs","139 ; 1 ; 201 ; .8 ; 551 ; 1" );
	SetTrieString(trie, "42_attribs","200 ; 1 ; 144 ; 3 ; 201 ; 1 ; 551 ; 1" );
	SetTrieString(trie, "425_attribs","4 ; 3.3 ; 6 ; 0.5 ; 25 ; 3.3 ; 1 ; 0.85" );
	SetTrieString(trie, "5_attribs","326 ; 2 ; 128 ; 1 ; 107 ; 1.3 ; 275 ; 1 ; 2 ; 2" );
	SetTrieString(trie, "239_attribs","107 ; 1.83 ; 128 ; 1 ; 414 ; 0" );
	SetTrieString(trie, "1084_attribs","107 ; 1.83 ; 128 ; 1 ; 414 ; 0" );
	SetTrieString(trie, "331_attribs","177 ; 3 ; 128 ; 1 ; 205 ; 0 ; 206 ; 5 ; 107 ; 1.3 ; 2 ; 2" );
	SetTrieString(trie, "310_attribs","26 ; 200 ; 180 ; 100 ; 2 ; 10" );
	SetTrieString(trie, "43_attribs","31 ; 30 ; 107 ; 1.3 ; 128 ; 1 ; 2 ; 2 ; 5 ; 1.5" );
	SetTrieString(trie, "426_attribs","1 ; 0.7 ; 6 ; 0.25 ; 107 ; 1.4 ; 128 ; 1 ; 149 ; 10" );
	SetTrieString(trie, "656_attribs","107 ; 1.3 ; 358 ; 1 ; 362 ; 1 ; 369 ; 1 ; 363 ; 1 ; 1 ; 0 ; 128 ; 1 ; 28 ; 10000" );
	SetTrieString(trie, "450_attribs","250 ; 10" );
	SetTrieString(trie, "317_attribs","203 ; 1 ; 108 ; 3 ; 412 ; 1 ; 62 ; 1" );
	SetTrieString(trie, "325_attribs","149 ; 30 ; 204 ; 0" );
	SetTrieString(trie, "448_attribs","97 ; 0.5 ; 6 ; 0.25 ; 418 ; 0 ; 43 ; 1 ; 37 ; 3 ; 107 ; 1 ; 128 ; 1 ; 3 ; .5" );
	SetTrieString(trie, "220_attribs","26 ; 50 ; 16 ; 15 ; 78 ; 3 ; 2 ; 1.2 ; 526 ; 2 ; 438 ; 1" );
	SetTrieString(trie, "45_attribs","44 ; 1 ; 45 ; 16 ; 3 ; 0.166 ; 43 ; 1 ; 1 ; .35 ; 106 ; 5 ; 37 ; 5 ; 97 ; 0.8" );
	SetTrieString(trie, "1078_attribs","44 ; 1 ; 45 ; 16 ; 3 ; 0.166 ; 43 ; 1 ; 1 ; .35 ; 106 ; 5 ; 37 ; 5 ; 97 ; 0.8" );
	SetTrieString(trie, "13_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "772_attribs","106 ; 0.6 ; 107 ; 1.3 ; 418 ; 1 ; 491 ; 0" );
	SetTrieString(trie, "773_attribs","26 ; 150 ; 275 ; 1 ; 412 ; 1 ; 62 ; 1" );
	SetTrieString(trie, "23_attribs","97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05" );
	SetTrieString(trie, "22_attribs","97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05" );
	SetTrieString(trie, "294_attribs","97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05" );
	SetTrieString(trie, "160_attribs","97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05" );
	SetTrieString(trie, "209_attribs","97 ; 0.8 ; 78 ; 4 ; 1 ; 0.65 ; 6 ; 0.05" );
	SetTrieString(trie, "449_attribs","2 ; 2.5 ; 78 ; 1.5 ; 5 ; 1.5 ; 326 ; 2 ; 275 ; 1" );
	SetTrieString(trie, "355_attribs","218 ; 1 ; 149 ; 10 ; 337 ; 1 ; 1 ; 0.1 ; 6 ; 0.75 ; 340 ; 1" );
	SetTrieString(trie, "7_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "589_attribs","286 ; 3 ; 465 ; 6 ; 2043 ; 1 ; 94 ; 1 ; 148 ; 0 ; 352 ; 1 ; 276 ; 1" );
	SetTrieString(trie, "155_attribs","286 ; 3 ; 94 ; 3 ; 148 ; 2.15 ; 345 ; 10 ; 80 ; 3 ; 2 ; 3 ; 2043 ; 4 ; 6 ; 2 ; 412 ; 1 ; 62 ; 1 ; 149 ; 10" );
	SetTrieString(trie, "142_attribs","124 ; 1 ; 125 ; 175 ; 321 ; 2" );
	SetTrieString(trie, "329_attribs","286 ; 3 ; 2 ; 1.25 ; 327 ; 1 ; 92 ; 10" );
	SetTrieString(trie, "997_attribs","469 ; 1 ; 474 ; 100 ; 4 ; 3.3 ; 37 ; 3 ; 6 ; 0.5 ; 280 ; 18 ; 1 ; 0.3" );
	SetTrieString(trie, "527_attribs","298 ; 20 ; 301 ; 1 ; 303 ; -1 ; 299 ; 100 ; 6 ; 0.8 ; 80 ; 1.5 ; 307 ; 1 ; 113 ; 25" );
	SetTrieString(trie, "141_attribs","136 ; 1 ; 15 ; 1 ; 3 ; 0.75" );
	SetTrieString(trie, "9_attribs","4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5" );
	SetTrieString(trie, "528_attribs","298 ; 7 ; 301 ; 1 ; 300 ; 1 ; 307 ; 1 ; 303 ; -1 ; 312 ; 1 ; 299 ; 100 ; 6 ; 1 ; 80 ; 1.5 ; 113 ; 25" );
	SetTrieString(trie, "140_attribs","26 ; 75 ; 57 ; 5 ; 135 ; 0" );
	SetTrieString(trie, "1086_attribs","26 ; 75 ; 57 ; 5 ; 135 ; 0" );
	SetTrieString(trie, "29_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "35_attribs","18 ; 1 ; 10 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "411_attribs","8 ; 3 ; 10 ; 2 ; 231 ; 2 ; 144 ; 2 ; 57 ; 15 ; 11 ; 0.5" );
	SetTrieString(trie, "305_attribs","199 ; 1 ; 97 ; .25 ; 76 ; 2.6" );
	SetTrieString(trie, "1079_attribs","199 ; 1 ; 97 ; .25 ; 76 ; 2.6" );
	SetTrieString(trie, "998_attribs","10 ; 5 ; 144 ; 3 ; 473 ; 3 ; 292 ; 1 ; 293 ; 2 ; 7 ; 1 ; 499 ; 1" );
	SetTrieString(trie, "173_attribs","188 ; 100 ; 125 ; 100 ; 144 ; 2" );
	SetTrieString(trie, "30_attribs","128 ; 1 ; 107 ; 3 ; 35 ; 5 ; 34 ; 0.5" );
	SetTrieString(trie, "61_attribs","51 ; 1 ; 5 ; 2 ; 2 ; 2 ; 392 ; 0.05" );
	SetTrieString(trie, "224_attribs","6 ; 0.3 ; 1 ; 0.15 ; 166 ; 150 ; 78 ; 5" );
	SetTrieString(trie, "24_attribs","6 ; 0.3 ; 78 ; 5" );
	SetTrieString(trie, "1142_attribs","6 ; 0.3 ; 78 ; 5" );
	SetTrieString(trie, "210_attribs","6 ; 0.3 ; 78 ; 5" );
	SetTrieString(trie, "460_attribs","2 ; 3.1 ; 5 ; 4 ; 3 ; 0.16 ; 299 ; 1 ; 78 ; 0.25" );
	SetTrieString(trie, "16_attribs","6 ; 0.3 ; 1 ; 0.6 ; 78 ; 8 ; 4 ; 3 ; 266 ; 1" );
	SetTrieString(trie, "203_attribs","6 ; 0.3 ; 1 ; 0.6 ; 78 ; 8 ; 4 ; 3 ; 266 ; 1" );
	SetTrieString(trie, "1149_attribs","6 ; 0.3 ; 1 ; 0.6 ; 78 ; 8 ; 4 ; 3 ; 266 ; 1" );
	SetTrieString(trie, "14_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "230_attribs","41 ; 2 ; 42 ; 1 ; 175 ; 15 ; 179 ; 1" );
	SetTrieString(trie, "526_attribs","308 ; 1 ; 297 ; 0 ; 304 ; 100 ; 1 ; 0.1 ; 305 ; 1" );
	SetTrieString(trie, "402_attribs","237 ; 1 ; 222 ; 1 ; 223 ; 1 ; 390 ; 2" );
	SetTrieString(trie, "752_attribs","219 ; 1 ; 329 ; 0 ; 387 ; 100 ; 398 ; 50 ; 116 ; 6 ; 318 ; .25 ; 76 ; 2.5" );
	SetTrieString(trie, "751_attribs","6 ; 0.7 ; 613 ; 30 ; 4 ; 1.5 ; 78 ; 2" );
	SetTrieString(trie, "231_attribs","26 ; 200" );
	SetTrieString(trie, "642_attribs","57 ; 10 ; 377 ; 0.001 ; 376 ; 1 ; 378 ; 2 ; 412 ; 1 ; 62 ; 1" );
	SetTrieString(trie, "56_attribs","76 ; 3 ; 318 ; 0.5 ; 1 ; 1 ; 266 ; 1 ; 26 ; 50" );
	SetTrieString(trie, "1092_attribs","76 ; 3 ; 318 ; 0.5 ; 1 ; 1 ; 266 ; 1 ; 26 ; 50" );
	SetTrieString(trie, "17_attribs","6 ; 0.7 ; 17 ; 0.05 ; 76 ; 3" );
	SetTrieString(trie, "37_attribs","5 ; 2.5 ; 17 ; 1" );
	SetTrieString(trie, "1003_attribs","5 ; 2.5 ; 17 ; 1" );
	SetTrieString(trie, "4_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "356_attribs","125 ; -100 ; 140 ; -150 ; 220 ; 99900" );
	SetTrieString(trie, "225_attribs","154 ; 1 ; 144 ; 1 ; 155 ; 0" );
	SetTrieString(trie, "649_attribs","347 ; 1 ; 156 ; 1 ; 359 ; 3 ; 361 ; 6 ; 365 ; 3" );
	SetTrieString(trie, "461_attribs","166 ; 150 ; 107 ; 1.1 ; 125 ; -20 ; 57 ; 1 ; 258 ; 1 ; 251 ; 1 ; 264 ; 1.25 ; 263 ; 1.25" );
	SetTrieString(trie, "59_attribs","33 ; 1 ; 34 ; .9 ; 35 ; 2 ; 292 ; 9" );
	SetTrieString(trie, "60_attribs","48 ; 2 ; 35 ; 5" );
	SetTrieString(trie, "401_attribs","224 ; 5 ; 225 ; 0.1" );
	SetTrieString(trie, "171_attribs","149 ; 10 ; 208 ; 1" );
	SetTrieString(trie, "264_attribs","6 ; 0.5 ; 208 ; 1 ; 1 ; 0.5 ; 134 ; 1" );
	SetTrieString(trie, "200_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "669_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "799_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "808_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "888_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "897_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "906_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "915_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "964_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "973_attribs","97 ; 0.75 ; 37 ; 3 ; 106 ; 0.05 ; 45 ; 2 ; 6 ; 0.75 ; 15 ; 1 ; 1 ; .8" );
	SetTrieString(trie, "1005_attribs","76 ; 3 ; 318 ; 0.5 ; 1 ; 1 ; 266 ; 1 ; 26 ; 50" );
	SetTrieString(trie, "201_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "664_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "851_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "792_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "801_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "881_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "890_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "899_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "908_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "857_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "966_attribs","41 ; 5 ; 390 ; 2" );
	SetTrieString(trie, "205_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "658_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "513_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "800_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "809_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "889_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "898_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "907_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "916_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "965_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "974_attribs","104 ; 0.32 ; 99 ; 1 ; 2 ; 5 ; 97 ; 1.4 ; 3 ; 0.25 ; 15 ; 1" );
	SetTrieString(trie, "298_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "202_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "654_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "793_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "802_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "882_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "891_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "900_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "909_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "958_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "967_attribs","76 ; 5 ; 6 ; .9 ; 16 ; 20" );
	SetTrieString(trie, "206_attribs","411 ; 10 ; 4 ; 4 ; 76 ; 10 ; 413 ; 1 ; 417 ; 1 ; 394 ; 0.08 ; 241 ; 0.75 ; 15 ; 0 ; 470 ; 0.5" );
	SetTrieString(trie, "1007_attribs","411 ; 10 ; 4 ; 4 ; 76 ; 10 ; 413 ; 1 ; 417 ; 1 ; 394 ; 0.08 ; 241 ; 0.75 ; 15 ; 0 ; 470 ; 0.5" );
	SetTrieString(trie, "207_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "661_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "797_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "806_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "886_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "895_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "904_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "913_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "962_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "971_attribs","96 ; 0.5 ; 78 ; 10 ; 6 ; 0.3" );
	SetTrieString(trie, "1006_attribs","51 ; 1 ; 5 ; 2 ; 2 ; 2 ; 392 ; 0.05" );
	SetTrieString(trie, "727_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "194_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "665_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "794_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "803_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "883_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "892_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "901_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "910_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "959_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "968_attribs","31 ; 5 ; 394 ; 0.5" );
	SetTrieString(trie, "199_attribs","4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5" );
	SetTrieString(trie, "1141_attribs","4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5" );
	SetTrieString(trie, "141_attribs","136 ; 1 ; 15 ; 1 ; 3 ; 0.75" );
	SetTrieString(trie, "169_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "197_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "662_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "795_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "804_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "884_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "893_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "902_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "911_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "960_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "969_attribs","6 ; 0.35 ; 286 ; 3 ; 1 ; .75 ; 15 ; 1" );
	SetTrieString(trie, "204_attribs","6 ; 0.3 ; 17 ; 0.05" );
	SetTrieString(trie, "211_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "663_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "796_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "805_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "885_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "894_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "903_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "912_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "961_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "970_attribs","314 ; 2 ; 11 ; 3 ; 26 ; 100" );
	SetTrieString(trie, "208_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "659_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "798_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "807_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "887_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "896_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "905_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "914_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "963_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "972_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "452_attribs","149 ; 30 ; 204 ; 0" );
	SetTrieString(trie, "192_attribs","178 ; .5 ; 2 ; 1.5 ; 267 ; 1 ; 15 ; 0" );
	SetTrieString(trie, "739_attribs","178 ; .5 ; 2 ; 1.5 ; 267 ; 1 ; 15 ; 0" );
	SetTrieString(trie, "457_attribs","20 ; 1 ; 21 ; 0 ; 22 ; 1 ; 2 ; 1.5" );
	SetTrieString(trie, "1000_attribs","20 ; 1 ; 21 ; 0 ; 22 ; 1 ; 2 ; 1.5 ; 638 ; 0" );
	SetTrieString(trie, "466_attribs","137 ; 10 ; 146 ; 1 ; 169 ; 0.1 ; 2 ; 1 ; 252 ; 0.01 ; 214 ; 1 ; 128 ; 1 ; 67 ; 1.5 ; 206 ; 3" );
	SetTrieString(trie, "834_attribs","146 ; 1 ; 438 ; 1 ; 2 ; 1.5" );
	SetTrieString(trie, "191_attribs","394 ; 0.5" );
	SetTrieString(trie, "609_attribs","394 ; 0.5" );
	SetTrieString(trie, "154_attribs","68 ; 5 ; 67 ; 2" );
	SetTrieString(trie, "741_attribs","171 ; 0.25 ; 256 ; 0.1 ; 254 ; 4" );
	SetTrieString(trie, "638_attribs","31 ; 3" );
	SetTrieString(trie, "10_attribs","4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5" );
	SetTrieString(trie, "12_attribs","4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5" );
	SetTrieString(trie, "11_attribs","4 ; 1.5 ; 6 ; 0.5 ; 25 ; 3.3 ; 318 ; 0.5" );
	SetTrieString(trie, "36_attribs","16 ; 30 ; 180 ; 150" );
	SetTrieString(trie, "8_attribs","6 ; 0.8 ; 149 ; 30" );
	SetTrieString(trie, "1143_attribs","6 ; 0.8 ; 149 ; 30" );
	SetTrieString(trie, "304_attribs","129 ; 10 ; 128 ; 0" );
	SetTrieString(trie, "1104_attribs","644 ; 9 ; 621 ; .1 ; 4 ; 1.5 ; 1 ; .75 ; 318 ; 0.75 ; 76 ; 2 ; 135 ; 0 ; 275 ; 1 ; 6 ; 1" );
	SetTrieString(trie, "1103_attribs","613 ; 15 ; 179 ; 1 ; 106 ; 1 ; 76 ; 3 ; 3 ; 1 ; 619 ; 1" );
	SetTrieString(trie, "1098_attribs","378 ; 2 ; 41 ; 2.5 ; 306 ; 0 ; 636 ; 1 ; 637 ; 1" );
	SetTrieString(trie, "812_attribs","278 ; .25 ; 616 ; 1 ; 437 ; 1" );
	SetTrieString(trie, "163_attribs","278 ; .25 ; 144 ; 2" );
	SetTrieString(trie, "232_attribs","107 ; 1.2 ; 128 ; 1 ; 179 ; 1 ; 2 ; 1.5 ; 28 ; 0" );
	SetTrieString(trie, "58_attribs","278 ; .40 ; 279 ; 3 ; 99 ; 3" );
	SetTrieString(trie, "44_attribs","278 ; .4 ; 279 ; 3 ; 38 ; 1" );
	SetTrieString(trie, "0_attribs","215 ; 300 ; 216 ; 600 ; 2 ; 3 ; 15 ; 0" );
	SetTrieString(trie, "194_attribs","215 ; 300 ; 216 ; 600 ; 2 ; 3 ; 15 ; 0" );
	SetTrieString(trie, "594_attribs","368 ; 1 ; 116 ; 5 ; 356 ; 1 ; 144 ; 1 ; 551 ; 1 ; 350 ; 1 ; 201 ; 2" );
	SetTrieString(trie, "222_attribs","278 ; .40 ; 99 ; 3 ; 129 ; 5" );
	SetTrieString(trie, "1121_attribs","278 ; .40 ; 99 ; 3 ; 129 ; 5" );
	SetTrieString(trie, "735_attribs","425 ; 1.75 ; 427 ; 10" );
	SetTrieString(trie, "736_attribs","425 ; 1.75 ; 427 ; 10" );
	SetTrieString(trie, "1080_attribs","425 ; 1.75 ; 427 ; 10" );
	SetTrieString(trie, "1102_attribs","425 ; 1.75 ; 427 ; 10" );
	SetTrieString(trie, "933_attribs","425 ; 1.75 ; 427 ; 10" );
	SetTrieString(trie, "588_attribs","337 ; 5 ; 338 ; 5 ; 339 ; 1 ; 340 ; 1 ; 349 ; 0 ; 6 ; .3 ; 1 ; 0.1 ; 28 ; 0" );
	SetTrieString(trie, "1150_attribs","670 ; 0.01 ; 669 ; 1 ; 4 ; 0.75 ; 97 ; 0.7 ; 126 ; -2 ; 6 ; 0.5 ; 15 ; 1" );
	SetTrieString(trie, "1151_attribs","100 ; 0.85 ; 6 ; 0.7 ; 97 ; 0.5 ; 671 ; 1 ; 684 ; 3" );
	SetTrieString(trie, "1153_attribs","708 ; 1 ; 709 ; 0.5 ; 710 ; 1 ; 711 ; 0 ; 651 ; 0.25 ; 644 ; 9 ; 97 ; 0.2 ; 394 ; 0.5 ; 424 ; 1.5 ; 25 ; 5 ; 76 ; 5 ; 128 ; 1" );
	SetTrieString(trie, "237_attribs","134 ; 2 ; 181 ; 2 ; 476 ; -1 ; 318 ; 0.1 ; 4 ; 10 ; 76 ; 10 ; 128 ; 1 ; 275 ; 1 ; 169 ; 0.1 ; 252 ; 0.7" );
	SetTrieString(trie, "265_attribs","134 ; 2 ; 181 ; 2 ; 476 ; -1 ; 318 ; 0.1 ; 4 ; 10 ; 275 ; 1 ; 78 ; 10 ; 88 ; 8" );


//TF2 BETA SECTION, THESE MAY NOT WORK AT ALL
//Beta Pocket Rocket Launcher
	SetTrieString(trie, "19010_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "19010_index", 127);
	SetTrieValue(trie, "19010_slot", 0);
	SetTrieValue(trie, "19010_quality", 4);
	SetTrieValue(trie, "19010_level", 25);
	SetTrieString(trie, "19010_attribs", "232 ; 6.0 ; 111 ; -10.0");
	SetTrieValue(trie, "19010_ammo", 20);

//Beta Quick Fix
	SetTrieString(trie, "186_classname", "tf_weapon_medigun");
	SetTrieValue(trie, "186_index", 29);
	SetTrieValue(trie, "186_slot", 1);
	SetTrieValue(trie, "186_quality", 4);
	SetTrieValue(trie, "186_level", 5);
	SetTrieString(trie, "186_attribs", "144 ; 2.0 ; 8 ; 1.4 ; 10 ; 1.4 ; 231 ; 2.0");
	SetTrieValue(trie, "186_ammo", -1);

//Pocket Shotgun
	SetTrieString(trie, "19011_classname", "tf_weapon_shotgun_soldier");
	SetTrieValue(trie, "19011_index", 10);
	SetTrieValue(trie, "19011_slot", 1);
	SetTrieValue(trie, "19011_quality", 4);
	SetTrieValue(trie, "19011_level", 10);
	SetTrieString(trie, "19011_attribs", "233 ; 1.20 ; 234 ; 1.3");
	SetTrieValue(trie, "19011_ammo", 32);

//Beta Split Equalizer 1
	SetTrieString(trie, "19012_classname", "tf_weapon_shovel");
	SetTrieValue(trie, "19012_index", 128);
	SetTrieValue(trie, "19012_slot", 2);
	SetTrieValue(trie, "19012_quality", 4);
	SetTrieValue(trie, "19012_level", 10);
	SetTrieString(trie, "19012_attribs", "235 ; 2.0 ; 236 ; 1.0");
	SetTrieValue(trie, "19012_ammo", -1);

//Beta Split Equalizer 2
	SetTrieString(trie, "19013_classname", "tf_weapon_shovel");
	SetTrieValue(trie, "19013_index", 128);
	SetTrieValue(trie, "19013_slot", 2);
	SetTrieValue(trie, "19013_quality", 4);
	SetTrieValue(trie, "19013_level", 10);
	SetTrieString(trie, "19013_attribs", "115 ; 1.0 ; 236 ; 1.0");
	SetTrieValue(trie, "19013_ammo", -1);

//Beta Sniper Rifle 1
	SetTrieString(trie, "19015_classname", "tf_weapon_sniperrifle");
	SetTrieValue(trie, "19015_index", 14);
	SetTrieValue(trie, "19015_slot", 0);
	SetTrieValue(trie, "19015_quality", 4);
	SetTrieValue(trie, "19015_level", 10);
	SetTrieString(trie, "19015_attribs", "237 ; 1.45 ; 222 ; 1.25 ; 223 ; 0.35");
	SetTrieValue(trie, "19015_ammo", 25);

//Beta Pocket Rocket Launcher 2
	SetTrieString(trie, "19016_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "19016_index", 127);
	SetTrieValue(trie, "19016_slot", 0);
	SetTrieValue(trie, "19016_quality", 4);
	SetTrieValue(trie, "19016_level", 25);
	SetTrieString(trie, "19016_attribs", "239 ; 1.15 ; 111 ; -10.0");
	SetTrieValue(trie, "19016_ammo", 20);

//Beta Pocket Rocket Launcher 2
	SetTrieString(trie, "19017_classname", "tf_weapon_rocketlauncher");
	SetTrieValue(trie, "19017_index", 127);
	SetTrieValue(trie, "19017_slot", 0);
	SetTrieValue(trie, "19017_quality", 4);
	SetTrieValue(trie, "19017_level", 25);
	SetTrieString(trie, "19017_attribs", "240 ; 0.5 ; 111 ; -10.0");
	SetTrieValue(trie, "19017_ammo", 20);

//Pocket Protector: Buff banner that builds rage by being healed, and gives minicrits for its buff but during buff, cannot gain health from being healed
	SetTrieString(trie, "2129_classname", "tf_weapon_buff_item");
	SetTrieValue(trie, "2129_index", 129);
	SetTrieValue(trie, "2129_slot", 1);
	SetTrieValue(trie, "2129_quality", 4);
	SetTrieValue(trie, "2129_level", 3);
	SetTrieString(trie, "2129_attribs", "116 ; 4");
	SetTrieValue(trie, "2129_ammo", -1);
}
PrepareAllModels()
{
	for (new i = 2058; i <= 5142; i++)
	{
		decl String:modelname[PLATFORM_MAX_PATH];
		decl String:formatBuffer[32];
		Format(formatBuffer, sizeof(formatBuffer), "%d_model", i);
		if (GetTrieString(hItemInfoTrie, formatBuffer, modelname, sizeof(modelname)))
		{
			PrepareCustomWeaponModel(modelname, formatBuffer);
		}
		Format(formatBuffer, sizeof(formatBuffer), "%d_viewmodel", i);
		if (GetTrieString(hItemInfoTrie, formatBuffer, modelname, sizeof(modelname)))
		{
			PrepareCustomWeaponModel(modelname, formatBuffer);
		}
		Format(formatBuffer, sizeof(formatBuffer), "%d_model_pv", i);
		if (GetTrieString(hItemInfoTrie, formatBuffer, modelname, sizeof(modelname)))
		{
			PrepareCustomWeaponModel(modelname, formatBuffer);
		}
		Format(formatBuffer, sizeof(formatBuffer), "%d_model_hv", i);
		if (GetTrieString(hItemInfoTrie, formatBuffer, modelname, sizeof(modelname)))
		{
			PrepareCustomWeaponModel(modelname, formatBuffer);
		}
	}
}
stock PrepareCustomWeaponModel(const String:modelname[], const String:key[])
{
	decl String:modelfile[PLATFORM_MAX_PATH + 4];
	decl String:strLine[PLATFORM_MAX_PATH];
	Format(modelfile, sizeof(modelfile), "%s.dep", modelname);
	new Handle:hStream = INVALID_HANDLE;
	if (FileExists(modelfile))
	{
		// Open stream, if possible
		hStream = OpenFile(modelfile, "r");
		if (hStream == INVALID_HANDLE)
		{
			if (bCvarDebug) LogMessage("[TF2Items Randomizer]%s: Error, can't read file containing model dependencies %s", key, modelfile);
			return;
		}

		while(!IsEndOfFile(hStream))
		{
			// Try to read line. If EOF has been hit, exit.
			ReadFileLine(hStream, strLine, sizeof(strLine));

			// Cleanup line
			CleanString(strLine);

			// If file exists...
			if (!FileExists(strLine, true))
			{
				if (bCvarDebug) LogMessage("[TF2Items Randomizer]%s: File %s doesn't exist, skipping", key, strLine);
				continue;
			}

			// Precache depending on type, and add to download table
			if (StrContains(strLine, ".vmt", false) != -1)		PrecacheDecal(strLine, true);
			else if (StrContains(strLine, ".mdl", false) != -1)	PrecacheModel(strLine, true);
			else if (StrContains(strLine, ".pcf", false) != -1)	PrecacheGeneric(strLine, true);
			if (bCvarDebug) LogMessage("[TF2Items Randomizer]%s: Preparing %s", key, strLine);
			AddFileToDownloadsTable(strLine);
		}

		// Close file
		CloseHandle(hStream);
	}
	else if (FileExists(modelname, true) && StrContains(modelname, ".mdl", false) != -1)
	{
		PrecacheModel(modelname, true);
		if (bCvarDebug) LogMessage("[TF2Items Randomizer]%s: Preparing %s", key, modelname);
	}
	else if (bCvarDebug) LogMessage("[TF2Items Randomizer]%s: cannot find valid model %s, skipping", key, modelname);
}

stock CleanString(String:strBuffer[])
{
	// Cleanup any illegal characters
	new Length = strlen(strBuffer);
	for (new iPos=0; iPos<Length; iPos++)
	{
		switch(strBuffer[iPos])
		{
			case '\r': strBuffer[iPos] = ' ';
			case '\n': strBuffer[iPos] = ' ';
			case '\t': strBuffer[iPos] = ' ';
		}
	}

	// Trim string
	TrimString(strBuffer);
}

stock TF2_GetMaxHealth(client)
{
	new maxhealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
	return ((maxhealth == -1 || maxhealth == 80896) ? GetEntProp(client, Prop_Data, "m_iMaxHealth") : maxhealth);
//	if (hMaxHealth != INVALID_HANDLE)
//		return SDKCall(hMaxHealth, client);
//	else return GetEntProp(client, Prop_Data, "m_iMaxHealth");		//backup
}

/*stock TF2_SetMaxHealth(client, MaxHealth)
{
	SetEntProp(client, Prop_Data, "m_iMaxHealth", MaxHealth);
}*/

stock TF2_SetHealth(client, NewHealth)
{
	SetEntProp(client, Prop_Send, "m_iHealth", NewHealth);
	SetEntProp(client, Prop_Data, "m_iHealth", NewHealth);
}
/*stock SaveClientBuildings(client)
{
	if (!IsValidClient(client)) return;
	new i = -1;
	while ((i = FindEntityByClassname2(i, "obj_sentrygun")) != -1)
	{
		if (GetEntPropEnt(i, Prop_Send, "m_hBuilder") == client)
		{
			SetEntPropEnt(i, Prop_Send, "m_hBuilder", -1);
			new Handle:pack;
			CreateDataTimer(0.0, Timer_ResetOwner, pack, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(pack, GetClientUserId(client));
			WritePackCell(pack, EntIndexToEntRef(i));
		}
	}
	i = -1;
	while ((i = FindEntityByClassname2(i, "obj_dispenser")) != -1)
	{
		if (GetEntPropEnt(i, Prop_Send, "m_hBuilder") == client)
		{
			SetEntPropEnt(i, Prop_Send, "m_hBuilder", -1);
			new Handle:pack;
			CreateDataTimer(0.0, Timer_ResetOwner, pack, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(pack, GetClientUserId(client));
			WritePackCell(pack, EntIndexToEntRef(i));
		}
	}
	i = -1;
	while ((i = FindEntityByClassname2(i, "obj_teleporter")) != -1)
	{
		if (GetEntPropEnt(i, Prop_Send, "m_hBuilder") == client)
		{
			SetEntPropEnt(i, Prop_Send, "m_hBuilder", -1);
			new Handle:pack;
			CreateDataTimer(0.0, Timer_ResetOwner, pack, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(pack, GetClientUserId(client));
			WritePackCell(pack, EntIndexToEntRef(i));
		}
	}
}
public Action:Timer_ResetOwner(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = GetClientOfUserId(ReadPackCell(pack));
	new obj = EntRefToEntIndex(ReadPackCell(pack));
//	PrintToChatAll("shirts %d %d", client, obj);
	if (obj <= MaxClients || !IsValidEntity(obj)) return Plugin_Stop;
	if (!IsValidClient(client))
	{
		SetVariantInt(9001);
		AcceptEntityInput(obj, "RemoveHealth");
		return Plugin_Stop;
	}
	SetEntPropEnt(obj, Prop_Send, "m_hBuilder", client);
//	PrintToChatAll("pants");
	return Plugin_Continue;
}*/
stock GiveWeaponOfIndex(client, weaponLookupIndex)
{
	if (bCvarDebug) LogMessage("Giving weapon %d to client %d %N team %d class %s", weaponLookupIndex, client, client, GetClientTeam(client), TF2_GetClassName(TF2_GetPlayerClass(client)));
	decl String:strSteamID[32];

	new weaponSlot;
	new String:formatBuffer[32];
	Format(formatBuffer, 32, "%d_%s", weaponLookupIndex, "slot");
	new bool:isValidItem = GetTrieValue(hItemInfoTrie, formatBuffer, weaponSlot);

	if (!isValidItem)
	{
		PrintToChat(client, "[TF2Items]Randomizer: Error! Tried to give you nonexistent weapon %d.", weaponLookupIndex);
		return -1;
	}

	new loopBreak = 0;
	new slotEntity = -1;
//	if (TF2_GetPlayerClass(client) == TFClass_Engineer && weaponSlot == TFWeaponSlot_Melee) SaveClientBuildings(client);
	while ((slotEntity = GetPlayerWeaponSlot(client, weaponSlot)) != -1 && loopBreak < 20)
	{
		RemovePlayerItem(client, slotEntity);
		RemoveEdict(slotEntity);
		loopBreak++;
	}
	loopBreak = 0;
	while ((slotEntity = GetPlayerWeaponSlot_Wearable(client, weaponSlot)) != -1 && loopBreak < 20)
	{
		RemoveEdict(slotEntity);
		loopBreak++;
	}
	if (weaponSlot == 1)
	{
		RemovePlayerBack(client);
		RemovePlayerTarge(client);
	}
	if (weaponSlot == 0) RemovePlayerBooties(client);

	if (weaponSlot < 3 && weaponSlot > -1)
	{
		ClearSyncHud(client, hHuds[weaponSlot]);
		flSavedInfo[client][weaponSlot] = -1.0;
	}
	new Handle:hWeapon = PrepareItemHandle(weaponLookupIndex, TF2_GetPlayerClass(client));
	new entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);

	if (!IsValidEntity(entity))
	{
		PrintToChat(client, "[TF2Items] Error giving one of your weapons D:");
		return -1;
	}
	switch (weaponLookupIndex)
	{
		case 2228:
		{
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", (-128+5));
		}
		case 2041:
		{
			SetEntProp(entity, Prop_Send, "m_nSkin", 0);
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", (-128+5));
		}
		case 2171:
		{
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", (-128+11));
			GetClientAuthString(client, strSteamID, sizeof(strSteamID));
			if (StrEqual(strSteamID, "STEAM_0:0:17402999") || StrEqual(strSteamID, "STEAM_0:1:35496121")) SetEntProp(entity, Prop_Send, "m_iEntityQuality", 9); //Mecha the Slag's Self-Made Khopesh Climber
		}
		case 2197:
		{
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", (-128+13));
/*				SetEntityRenderFx(entity, RENDERFX_PULSE_SLOW);
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 120, 10, 255, 205);*/
			if (TF2_GetMetal(client) > 150)
				TF2_SetMetal(client, 150);
		}
/*			case 215:
		{
			if (TF2_GetPlayerClass(client) == TFClass_Medic) //Medic with Degreaser: fix for screen-blocking
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, 255, 255, 255, 75);
			}
		}*/
		case 35, 411, 998:
		{
			new TFClassType:class = TF2_GetPlayerClass(client);
			//Sniper or Engineer or gunsling with Kritzkrieg: fix for screen-blocking
			if (class == TFClass_Sniper || class == TFClass_Engineer || GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee) == 142)
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, 255, 255, 255, 75);
			}
		}
		case 2058:
		{
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", (-128+6));
			GetClientAuthString(client, strSteamID, sizeof(strSteamID));
//				if (StrEqual(strSteamID, "STEAM_0:1:19100391", false)) SetEntProp(entity, Prop_Send, "m_iEntityQuality", 9); //FlaminSarge's Self-Made Jar of Ants
			if (StrEqual(strSteamID, "STEAM_0:0:6404564", false) || StrEqual(strSteamID, "STEAM_0:0:1048930", false)) SetEntProp(entity, Prop_Send, "m_iEntityQuality", 9); //Reag and BAT MAN- Self-Made Ant'eh'gen
		}
		case 142:
		{
			new secondary = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);
			if (secondary == 35 || secondary == 411 || secondary == 998)
			{
				secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
				SetEntityRenderMode(secondary, RENDER_TRANSCOLOR);
				SetEntityRenderColor(secondary, 255, 255, 255, 75);
			}
			if (TF2_GetPlayerClass(client) == TFClass_Engineer)
			{
				new flags = GetEntProp(client, Prop_Send, "m_nBody");
				if (!(flags & (1 << 1)))
				{
					flags |= (1 << 1);
					SetEntProp(client, Prop_Send, "m_nBody", flags);
				}
			}
		}
		case 45, 8045:
		{
			if (TF2_GetPlayerClass(client) == TFClass_Sniper)
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, 255, 255, 255, 75);
			}
		}
		case 9266:
		{
			new model = PrecacheModel("models/weapons/c_models/c_bigaxe/c_bigaxe.mdl");
			SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", model);
			SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", model, _, 0);
			if (TF2_GetPlayerClass(client) == TFClass_Heavy)
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, 255, 255, 255, 75);
			}
		}
		case 266:
		{
			if (TF2_GetPlayerClass(client) == TFClass_Heavy)
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, 255, 255, 255, 75);
			}
		}
		case 5142:
		{
			new primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			decl String:cls[64];
			if (primary > MaxClients && IsValidEntity(primary) && GetEntityClassname(primary, cls, sizeof(cls)))
			{
				new TFClassType:primclassfix = FixReload(client, GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex"), cls);
				if (primclassfix != TFClass_Unknown)
				{
					RemovePlayerItem(client, primary);
					EquipPlayerWeapon(client, primary);
					TF2_SetPlayerClass(client, primclassfix, _, false);
				}
			}
			new secondary = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);
			if (secondary == 35 || secondary == 411 || secondary == 998)
			{
				secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
				SetEntityRenderMode(secondary, RENDER_TRANSCOLOR);
				SetEntityRenderColor(secondary, 255, 255, 255, 75);
			}
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", (-128+25));
			if (TF2_GetPlayerClass(client) == TFClass_Engineer)
			{
				new flags = GetEntProp(client, Prop_Send, "m_nBody");
				if (!(flags & (1 << 1)))
				{
					flags |= (1 << 1);
					SetEntProp(client, Prop_Send, "m_nBody", flags);
				}
			}
		}
/*		case 735, 736, 810, 831:
		{
			decl String:classname[64];
			for (new i = 0; i < 48; i++)
			{
				new ent = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
				if (ent > MaxClients && IsValidEntity(ent) && GetEntityClassname(ent, classname, sizeof(classname)) && (StrEqual(classname, "tf_weapon_builder", false) || StrEqual(classname, "tf_weapon_sapper", false)))
				{
					new idx = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
					if (idx == 735 || idx == 736 || idx == 810 || idx == 831)
					{
						RemovePlayerItem(client, ent);
						AcceptEntityInput(ent, "Kill");
					}
				}
			}
			SetEntProp(entity, Prop_Send, "m_iObjectType", 3);
			SetEntProp(entity, Prop_Data, "m_iSubType", 3);
		}*/
	}

	decl String:classname[64];
	Format(formatBuffer, sizeof(formatBuffer), "%d_%s", weaponLookupIndex, "classname");
	GetTrieString(hItemInfoTrie, formatBuffer, classname, sizeof(classname));

	if (StrEqual(classname, "tf_weapon_builder", false) || StrEqual(classname, "tf_weapon_sapper", false))
	{
		if (weaponSlot == TFWeaponSlot_Secondary)
		{
			SetEntProp(entity, Prop_Send, "m_iObjectType", 3);
			SetEntProp(entity, Prop_Data, "m_iSubType", 3);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		}
		else
		{
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
		}
	}

	new bool:wearable = (StrContains(classname, "wearable", false) != -1 || StrContains(classname, "powerup", false) != -1);
	decl String:viewmodel[128];
	Format(formatBuffer, sizeof(formatBuffer), "%d_%s", weaponLookupIndex, "viewmodel");
	if (GetTrieString(hItemInfoTrie, formatBuffer, viewmodel, sizeof(viewmodel)) && FileExists(viewmodel, true))
	{
		new vm = CreateVM(client, viewmodel);
		if (weaponLookupIndex != 5142) SetEntPropEnt(vm, Prop_Send, "m_hWeaponAssociatedWith", entity);
		SetEntPropEnt(entity, Prop_Send, "m_hExtraWearableViewModel", vm);
		if (weaponLookupIndex == 2197) SetEntPropFloat(vm, Prop_Send, "m_flModelScale", 1.008);
	}
	decl String:worldmodel[128];
	Format(formatBuffer, sizeof(formatBuffer), "%d_%s", weaponLookupIndex, "model");
	if (GetTrieString(hItemInfoTrie, formatBuffer, worldmodel, sizeof(worldmodel)) && FileExists(worldmodel, true) && weaponLookupIndex != 169)
	{
		new model = PrecacheModel(worldmodel);
		if (weaponLookupIndex == 5142)
		{
			/*if (TF2_GetPlayerClass(client) == TFClass_Engineer)
			{
				new flags = GetEntProp(client, Prop_Send, "m_nBody");
				if (IsModelPrecached(worldmodel))
				{
					SetVariantString(worldmodel);
					AcceptEntityInput(client, "SetCustomModel");
					SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
				}
				flags |= (1 << 1);
				SetEntProp(client, Prop_Send, "m_nBody", flags);
			}*/
		}
		else if (!wearable)
		{
			SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", model);
			SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", model, _, 0);
		}
		else SetEntProp(entity, Prop_Send, "m_nModelIndex", model);
	}

#if defined _visweps_included
	new bool:wearablewep = false;
#endif
	if (wearable)
	{
		TF2_EquipWearable(client, entity);
#if defined _visweps_included
		wearablewep = true;
#endif
/*			if (weaponLookupIndex == 131)
		{
			decl String:attachment[32];
			new TFClassType:class = TF2_GetPlayerClass(client);
			switch (class)
			{
				case TFClass_Scout: strcopy(attachment, sizeof(attachment), "hand_L");
				case TFClass_Pyro, TFClass_Soldier: strcopy(attachment, sizeof(attachment), "weapon_bone_L");
				case TFClass_Engineer: strcopy(attachment, sizeof(attachment), "exhaust");
				default: strcopy(attachment, sizeof(attachment), "");
			}
			if (attachment[0] != '\0')
			{
				SetVariantString("!activator");
				AcceptEntityInput(entity, "SetParent", client);
				SetVariantString(attachment);
				AcceptEntityInput(entity, "SetParentAttachment");
			}
		}*/
	}
	else
	{
		new TFClassType:class = FixReload(client, weaponLookupIndex, classname);
		EquipPlayerWeapon(client, entity);
		if (class != TFClass_Unknown)
		{
			TF2_SetPlayerClass(client, class, _, false);
		}
		if (TF2_GetPlayerClass(client) == TFClass_Heavy && StrEqual(classname, "tf_weapon_medigun", false))
		{
			SetEntProp(entity, Prop_Send, "m_fEffects", GetEntProp(entity, Prop_Send, "m_fEffects") & ~(EF_BONEMERGE|EF_BONEMERGE_FASTCULL));
			SetEntPropVector(entity, Prop_Send, "m_vecOrigin", Float:{ 0.0, 0.0, 38.0 });
		}
	}

	new weaponAmmo = -1;
	Format(formatBuffer, sizeof(formatBuffer), "%d_%s", weaponLookupIndex, "ammo");
	GetTrieValue(hItemInfoTrie, formatBuffer, weaponAmmo);

	if (weaponAmmo != -1)
	{
		if (!IsFakeClient(client) || GetSpeshulAmmo(client, weaponSlot) < weaponAmmo) SetSpeshulAmmo(client, weaponSlot, weaponAmmo);
	}
#if defined _visweps_included
	if (bVisWeps)
	{
		decl String:indexmodel[128];
		new index = weaponLookupIndex;
		Format(formatBuffer, sizeof(formatBuffer), "%d_%s", index, "model");
		if (GetTrieString(hItemInfoTrie, formatBuffer, indexmodel, sizeof(indexmodel)) && (IsModelPrecached(indexmodel) || strcmp(indexmodel, "-1", false) == 0))
		{
			if (wearablewep) weaponSlot = 6;
			VisWep_GiveWeapon(client, weaponSlot, indexmodel, _, (weaponSlot == 1));
//				LogMessage("Setting Wep Model to %s", indexmodel);
		}
		else
		{
			if (wearablewep) weaponSlot = 6;
			new index2;
			Format(formatBuffer, sizeof(formatBuffer), "%d_%s", index, "index");
			GetTrieValue(hItemInfoTrie, formatBuffer, index2);
//				if (index2 == 193) index2 = 3;
//				if (index2 == 205) index2 = 18;
			if (index == 2041 && index2 == 41) index2 = 2041;
			if (index == 2009 && index2 == 141) index2 = 9;
			if (index == 9266 && index2 == 266) index2 = 9266;
			IntToString(index2, indexmodel, sizeof(indexmodel));
			VisWep_GiveWeapon(client, weaponSlot, indexmodel, _, (weaponSlot == 1));
//				LogMessage("Setting Wep Model to %s", indexmodel);
		}
	}
#endif
	return entity;
}
stock CreateVM(client, String:model[])
{
	new ent = CreateEntityByName("tf_wearable_vm");
	if (!IsValidEntity(ent)) return -1;
	SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);
	TF2_EquipWearable(client, ent);
	return ent;
}
stock TFClassType:FixReload(client, idx, String:classname[])
{
	new TFClassType:class = TF2_GetPlayerClass(client);
	new realindex = -1;
	new String:formatBuffer[32];
	Format(formatBuffer, 32, "%d_%s", idx, "index");
	GetTrieValue(hItemInfoTrie, formatBuffer, realindex);
	new bool:found = false;
	if (StrEqual(classname, "tf_weapon_revolver", false) && realindex != 24 && realindex != 210 && class != TFClass_Spy)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Spy, _, false);
	}
	if (StrEqual(classname, "tf_weapon_syringegun_medic", false) && realindex != 17 && realindex != 204 && class != TFClass_Medic)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Medic, _, false);
	}
	if (StrEqual(classname, "tf_weapon_smg", false) && class != TFClass_Sniper)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Sniper, _, false);
	}
	if (strncmp(classname, "tf_weapon_handgun_scout", 23, false) == 0 && class != TFClass_Scout)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Scout, _, false);
	}
	if (strncmp(classname, "tf_weapon_pistol", 16, false) == 0 && class != TFClass_Scout && class != TFClass_Engineer)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Scout, _, false);
	}
	if (StrEqual(classname, "tf_weapon_soda_popper", false) && class != TFClass_Scout)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Scout, _, false);
	}
	if (StrEqual(classname, "tf_weapon_scattergun", false) && realindex == 45 && class != TFClass_Scout)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Scout, _, false);
	}
	if (StrEqual(classname, "tf_weapon_rocketlauncher", false) && realindex == 730 && class != TFClass_Soldier)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Soldier, _, false);
	}
	if (StrEqual(classname, "tf_weapon_crossbow", false) && class != TFClass_Medic && class != TFClass_Soldier)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Medic, _, false);
	}
	if (StrEqual(classname, "tf_weapon_compound_bow", false) && class != TFClass_Sniper)
	{
		found = true;
		TF2_SetPlayerClass(client, TFClass_Sniper, _, false);
	}
	if (!found) return TFClass_Unknown;
	return class;
}
public Action:Command_Reroll(client, args)
{
	new String:arg1[32];
	if (args != 1 && args != 0)
	{
		ReplyToCommand(client, "[TF2Items] Usage: tf2items_rnd_reroll <target> or sm_reroll");
		return Plugin_Handled;
	}
	if (args == 1)
	{
		/* Get the arguments */
		GetCmdArg(1, arg1, sizeof(arg1));
	}
	else if (args == 0) arg1 = "@me"; // If no args, set arg1 to @me

	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0),
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++)
	{
		if (bCvarEnabled)
		{
			if (IsClientInGame(target_list[i]))
			{
				SetRandomization(target_list[i]);
				if (IsPlayerAlive(target_list[i]))
				{
					TF2_RespawnPlayer(target_list[i]);
				}
			}
		}
		LogAction(client, target_list[i], "\"%L\" rerolled \"%L\"", client, target_list[i]);
	}
	return Plugin_Handled;
}
public Action:Command_SetLoadout(client, args)
{
	new size = 32;
	new TFClassType:class = TFClass_Unknown;
	new wep1=-2, wep2=-2, wep3=-2, cloak=-2;
	new String:strArgs[6][size];
	if (args < 2)
	{
		ReplyToCommand(client, "[TF2Items] Usage: tf2items_rnd_set <target> <class/_> <wep1/_> <wep2/_> <wep3/_> <cloak/_>");
		return Plugin_Handled;
	}
	for (new i = 0; i < args && i < 6; i++)
	{
		GetCmdArg(i+1, strArgs[i], size);
	}
	if (args > 1)
	{
		if (StrEqual(strArgs[1], "heavyweapons", false)) strcopy(strArgs[1], size, "heavy");
		if (!StrEqual(strArgs[1], "_", false) && strArgs[1][0] != '\0')
			class = TF2_GetClass(strArgs[1]);
	}
	if (args > 2)
	{
		if (!StrEqual(strArgs[2], "_", false) && strArgs[2][0] != '\0')
			wep1 = StringToInt(strArgs[2]);
		else wep1 = -2;
		new wep = FindWepInWepsArray(wep1, TFWeaponSlot_Primary);
		if (wep == -1)
		{
			ReplyToCommand(client, "[TF2Items] Couldn't find primary weapon %d, proceeding with other arguments", wep1);
			wep1 = -1;
		}
		else wep1 = wep;
	}
	if (args > 3)
	{
		if (!StrEqual(strArgs[3], "_", false) && strArgs[3][0] != '\0')
			wep2 = StringToInt(strArgs[3]);
		else wep2 = -2;
		new wep = FindWepInWepsArray(wep2, TFWeaponSlot_Secondary);
		if (wep == -1)
		{
			ReplyToCommand(client, "[TF2Items] Couldn't find secondary weapon %d, proceeding with other arguments", wep2);
			wep2 = -2;
		}
		else wep2 = wep;
	}
	if (args > 4)
	{
		if (!StrEqual(strArgs[4], "_", false) && strArgs[4][0] != '\0')
			wep3 = StringToInt(strArgs[4]);
		else wep3 = -2;
		if (wep3 == 5) wep3 = 195;
		new wep = FindWepInWepsArray(wep3, TFWeaponSlot_Melee);
		if (wep == -1)
		{
			ReplyToCommand(client, "[TF2Items] Couldn't find melee weapon %d, proceeding with other arguments", wep3);
			wep3 = -2;
		}
		else wep3 = wep;
	}
	if (args > 5)
	{
		if (!StrEqual(strArgs[5], "_", false) && strArgs[5][0] != '\0')
			cloak = StringToInt(strArgs[5]);
		else cloak = -2;
		new wep = FindWepInWepsArray(cloak, 3);
		if (wep == -1)
		{
			ReplyToCommand(client, "[TF2Items] Couldn't find cloak %d, proceeding with other arguments", cloak);
			cloak = -2;
		}
		else cloak = wep;
	}
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

	if ((target_count = ProcessTargetString(
			strArgs[0],
			client,
			target_list,
			MAXPLAYERS,
			(args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0),
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++)
	{
		if (IsClientInGame(target_list[i]))
		{
			if (wep1 >= 0) iRndWeapon[target_list[i]][0] = wep1;
			if (wep2 >= 0) iRndWeapon[target_list[i]][1] = wep2;
			if (wep3 >= 0) iRndWeapon[target_list[i]][2] = wep3;
			if (cloak >= 0) iRndCloak[target_list[i]] = cloak;
			if (class != TFClass_Unknown)
			{
				iRndClass[target_list[i]] = class;
				if (bCvarEnabled && TF2_GetPlayerClass(target_list[i]) != class) TF2_SetPlayerClass(target_list[i], class, _, true);
			}
			if (bCvarEnabled && IsPlayerAlive(target_list[i]))
			{
				TF2_RegeneratePlayer(target_list[i]);
				iDefClass[client] = TF2_GetPlayerClass(target_list[i]);
			}
		}
		LogAction(client, target_list[i], "\"%L\" set randomization info on \"%L\" to %d %d %d %d %d", client, target_list[i], _:class, wep1, wep2, wep3, cloak);
	}
	return Plugin_Handled;
}
stock FindWepInWepsArray(wep, slot)
{
	if (wep == -1) return 0;
	if (wep < 0) return wep;
	switch (slot)
	{
		case TFWeaponSlot_Primary:
		{
			for (new i = 0; i < sizeof(iWeaponPrimary); i++)
			{
				if (wep == iWeaponPrimary[i]) return i;
			}
		}
		case TFWeaponSlot_Secondary:
		{
			for (new i = 0; i < sizeof(iWeaponSecondary); i++)
			{
				if (wep == iWeaponSecondary[i]) return i;
			}
		}
		case TFWeaponSlot_Melee:
		{
			for (new i = 0; i < sizeof(iWeaponMelee); i++)
			{
				if (wep == iWeaponMelee[i]) return i;
			}
		}
		case 3:
		{
			for (new i = 0; i < sizeof(iWeaponCloakary); i++)
			{
				if (wep == iWeaponCloakary[i]) return i;
			}
		}
	}
	return -1;
}
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (!IsValidClient(client)) return Plugin_Continue;
	//medic pyro demo work with this setup	//pyro idle is m_nSequence 1
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class != TFClass_Engineer && weapon > MaxClients && IsValidEntity(weapon) && StrEqual(weaponname, "tf_weapon_wrench", false) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 155)
	{
//		PrintToChatAll("%s", result ? "yes" : "no");
		static sequences[TFClassType+TFClassType:1][4] =	//best declaration ever
		{
			{ 0, 0, 0, 0 },
			{ 1, 5, 3, 4 },
			{ 10, 14, 12, 13 },
			{ 15, 18, 16, 17 },
			{ 2, 5, 3, 4 },
			{ 2, 5, 3, 4 },
			{ 26, 5, 27, 27 },	//heavy saxxy + fistcrit
//			{ 6, 5, 3, 4 },		//heavy fists all the way
			{ 1, 5, 3, 4 },
			{ 7, 11, 9, 10 },
			{ 0, 0, 0, 0 },
			{ 0, 0, 0, 0 }
		};
		new viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		if (sequences[class][0] != 0 && viewmodel > MaxClients && IsValidEntity(viewmodel) && GetEntPropEnt(viewmodel, Prop_Send, "m_hWeapon") == weapon)
		{
			SetEntProp(viewmodel, Prop_Send, "m_nSequence", (result || TF2_IsPlayerCritBuffed(client)) ? sequences[class][1] : sequences[class][GetRandomInt(2, 3)]);
			new Handle:pack;
			CreateDataTimer(0.5, Timer_ResetSequence, pack, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(pack, EntIndexToEntRef(viewmodel));
			WritePackCell(pack, EntIndexToEntRef(weapon));
			WritePackCell(pack, sequences[class][0]);
			WritePackCell(pack, sequences[class][1]);
			WritePackCell(pack, sequences[class][2]);
			WritePackCell(pack, sequences[class][3]);
		}
	}
	if (!tf2items_giveweapon && TF2_IsPlayerInCondition(client, TFCond_Charging) && class != TFClass_DemoMan && (StrEqual(weaponname, "tf_weapon_wrench")
			|| StrEqual(weaponname, "tf_weapon_shovel")
			|| StrEqual(weaponname, "tf_weapon_bottle")
			|| StrEqual(weaponname, "tf_weapon_fists")
			|| strncmp(weaponname, "tf_weapon_bat", 13) == 0
			|| StrEqual(weaponname, "tf_weapon_bonesaw")
			|| StrEqual(weaponname, "tf_weapon_sword")
			|| StrEqual(weaponname, "tf_weapon_fireaxe")
			|| StrEqual(weaponname, "tf_weapon_robot_arm")
//			|| StrEqual(weaponname, "tf_weapon_bat_wood")
			|| StrEqual(weaponname, "tf_weapon_club")
//			|| StrEqual(weaponname, "tf_weapon_bat_fish")
			|| StrEqual(weaponname, "tf_weapon_stickbomb")
			|| StrEqual(weaponname, "tf_weapon_knife")))
	{
		TF2_RemoveCondition(client, TFCond_Charging);
		CreateTimer(0.4, Timer_ResetMeleeCrit, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);	//SetEntProp(client, Prop_Send, "m_iNextMeleeCrit", 0);
		DoResetChargeTimer(client, true);
	}
/*	new secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (secondary != -1 && GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex") == 311 && TF2_GetPlayerClass(client) == TFClass_Heavy && TF2_IsPlayerInCondition(client, TFCond_CritCola))
	{
		if (!(StrEqual(weaponname, "tf_weapon_wrench")
			|| StrEqual(weaponname, "tf_weapon_shovel")
			|| StrEqual(weaponname, "tf_weapon_bottle")
			|| StrEqual(weaponname, "tf_weapon_fists")
			|| StrEqual(weaponname, "tf_weapon_bat")
			|| StrEqual(weaponname, "tf_weapon_bonesaw")
			|| StrEqual(weaponname, "tf_weapon_sword")
			|| StrEqual(weaponname, "tf_weapon_fireaxe")
			|| StrEqual(weaponname, "tf_weapon_robot_arm")
			|| StrEqual(weaponname, "tf_weapon_bat_wood")
			|| StrEqual(weaponname, "tf_weapon_club")
			|| StrEqual(weaponname, "tf_weapon_bat_fish")
			|| StrEqual(weaponname, "tf_weapon_stickbomb")
			|| StrEqual(weaponname, "tf_weapon_knife")
			|| StrEqual(weaponname, "tf_weapon_katana")))
		{
			if (strcmp(weaponname, "tf_weapon_minigun", false) == 0)
			{
				SetEntProp(weapon, Prop_Send, "m_iWeaponState", 0);
				TF2_RemoveCondition(client, TFCond_Slowed);
			}
			new melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			if (melee && IsValidEntity(melee)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee);
		}
	}*/
	if (bCvarFixSpy /*&& TF2_GetPlayerClass(client) == TFClass_Spy*/ && (TF2_IsPlayerInCondition(client, TFCond_Disguising) || TF2_IsPlayerInCondition(client, TFCond_Disguised)))
	{
		if (StrEqual(weaponname, "tf_weapon_flamethrower")
			|| StrEqual(weaponname, "tf_weapon_grenadelauncher")
			|| StrEqual(weaponname, "tf_weapon_pipebomblauncher")
			|| StrEqual(weaponname, "tf_weapon_compound_bow")
			|| StrEqual(weaponname, "tf_weapon_wrench")
			|| StrEqual(weaponname, "tf_weapon_shovel")
			|| StrEqual(weaponname, "tf_weapon_bottle")
			|| StrEqual(weaponname, "tf_weapon_fists")
			|| strncmp(weaponname, "tf_weapon_bat", 13) == 0
			|| StrEqual(weaponname, "tf_weapon_bonesaw")
			|| StrEqual(weaponname, "tf_weapon_sword")
			|| StrEqual(weaponname, "tf_weapon_fireaxe")
			|| StrEqual(weaponname, "tf_weapon_robot_arm")
//			|| StrEqual(weaponname, "tf_weapon_bat_wood")
			|| StrEqual(weaponname, "tf_weapon_club")
//			|| StrEqual(weaponname, "tf_weapon_bat_fish")
			|| StrEqual(weaponname, "tf_weapon_stickbomb")
			|| StrEqual(weaponname, "tf_weapon_katana")) TF2_RemovePlayerDisguise(client);
	}
	if (!tf2items_giveweapon && StrEqual(weaponname, "tf_weapon_club") && GetEntProp(weapon, Prop_Send, "m_iEntityLevel") == (-128+11) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 171)
	{
		SickleClimbWalls(client);
	}
	if (StrEqual(weaponname, "tf_weapon_rocketlauncher") && GetEntProp(weapon, Prop_Send, "m_iEntityLevel") == (-128+5) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 228)
	{
		CreateTimer(0.1, Timer_CheckForAOORocket, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}
public Action:Timer_ResetMeleeCrit(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client)) return Plugin_Stop;
	SetEntProp(client, Prop_Send, "m_iNextMeleeCrit", 0);
	return Plugin_Continue;
}
public Action:Timer_CheckForAOORocket(Handle:timer, any:userid)	//Giant 2228 (Army of One) rockets
{
	new client = GetClientOfUserId(userid);
	if (!IsValidClient(client)) return Plugin_Stop;
	new i = -1;
	decl Float:vel[3];
	while ((i = FindEntityByClassname2(i, "tf_projectile_rocket")) != -1)
	{
		if (GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client && GetEntPropFloat(i, Prop_Send, "m_flModelScale") != 1.5)
		{
			GetEntPropVector(i, Prop_Send, "m_vInitialVelocity", vel);
			new Float:speed = GetVectorLength(vel);	//m_hLauncher returns the launcher info if we really need to check index/level, but eh
			if (speed > 329 && speed < 331) SetEntPropFloat(i, Prop_Send, "m_flModelScale", 1.5);
		}
	}
	return Plugin_Continue;
}
stock TF2_IsPlayerCritBuffed(client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged)
			|| TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy)
			|| TF2_IsPlayerInCondition(client, TFCond:34)
			|| TF2_IsPlayerInCondition(client, TFCond:35)
			|| TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood)
			|| TF2_IsPlayerInCondition(client, TFCond_CritOnWin)
			|| TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture)
			|| TF2_IsPlayerInCondition(client, TFCond_CritOnKill)
			|| TF2_IsPlayerInCondition(client, TFCond_CritMmmph)
			);
}
public Action:Timer_ResetSequence(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new viewmodel = EntRefToEntIndex(ReadPackCell(pack));
	new weapon = EntRefToEntIndex(ReadPackCell(pack));
	new idle = ReadPackCell(pack);
	new others[3];
	others[0] = ReadPackCell(pack);
	others[1] = ReadPackCell(pack);
	others[2] = ReadPackCell(pack);
	if (viewmodel > MaxClients && IsValidEntity(viewmodel) && GetEntPropEnt(viewmodel, Prop_Send, "m_hWeapon") == weapon)
	{
		new seq = GetEntProp(viewmodel, Prop_Send, "m_nSequence");
		if (seq == others[0] || seq == others[1] || seq == others[2])
			SetEntProp(viewmodel, Prop_Send, "m_nSequence", idle);
	}
}
public SickleClimbWalls(client)
{
	if (!IsValidClient(client)) return;
//	if (GetPlayerClass(client) != 7) return;
//	if (!(g_iSpecialAttributes[client] & attribute_climbwalls)) return;

	decl String:classname[64];
	decl Float:vecClientEyePos[3];
	decl Float:vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);	// Get the position of the player's eyes
	GetClientEyeAngles(client, vecClientEyeAng);	// Get the angle the player is looking

	//Check for colliding entities
	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);

	if (!TR_DidHit(INVALID_HANDLE)) return;

	new TRIndex = TR_GetEntityIndex(INVALID_HANDLE);
	GetEdictClassname(TRIndex, classname, sizeof(classname));
	if (!StrEqual(classname, "worldspawn")) return;

	decl Float:fNormal[3];
	TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
	GetVectorAngles(fNormal, fNormal);

	//PrintToChatAll("Normal: %f", fNormal[0]);

	if (fNormal[0] >= 30.0 && fNormal[0] <= 330.0) return;
	if (fNormal[0] <= -30.0) return;

	decl Float:pos[3];
	TR_GetEndPosition(pos);
	new Float:distance = GetVectorDistance(vecClientEyePos, pos);

	//PrintToChatAll("Distance: %f", distance);
	if (distance >= 100.0) return;

	new Float:fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	fVelocity[2] = 600.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	ClientCommand(client, "playgamesound \"%s\"", "player\\taunt_clip_spin.wav");
	if (GetEntProp(client, Prop_Send, "m_nNumHealers") <= 0) return;
	for (new healer = 1; healer <= MaxClients; healer++)
	{
		if (!IsClientInGame(healer)) continue;
		if (!IsPlayerAlive(healer)) continue;
		new sec = GetPlayerWeaponSlot(healer, TFWeaponSlot_Secondary);
		if (IsValidEntity(sec) && GetEdictClassname(sec, classname, sizeof(classname)) && StrEqual(classname, "tf_weapon_medigun", false))	//it's a medigun
		{
			if (GetEntProp(sec, Prop_Send, "m_iItemDefinitionIndex") != 411 || client != GetEntPropEnt(sec, Prop_Send, "m_hHealingTarget"))
			{
				continue;
			}
			TeleportEntity(healer, NULL_VECTOR, NULL_VECTOR, fVelocity);
		}
	}
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return (entity != data);
}

stock bool:IsValidClient(client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
//	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

stock RemovePlayerBack(client)
{
	new edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
	{
		decl String:netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if ((idx == 57 || idx == 133 || idx == 231 || idx == 444 || idx == 642) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				if (iRndWeapon[client][1] != 0)
				{
					AcceptEntityInput(edict, "Kill");
				}
			}
		}
	}
}

stock RemovePlayerBooties(client)
{
	new edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
	{
		decl String:netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if ((idx == 405 || idx == 608) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				if (iRndWeapon[client][0] != 0)
				{
					AcceptEntityInput(edict, "Kill");
				}
			}
		}
	}
}

stock RemovePlayerTarge(client)
{
	new edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable_demoshield")) != -1)
	{
		new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
		if ((idx == 131 || idx == 406) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
		{
			if (iRndWeapon[client][1] != 0)
			{
				AcceptEntityInput(edict, "Kill");
			}
		}
	}
}

stock FindPlayerTarge(client)
{
	new edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable_demoshield")) != -1)
	{
		new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
		if ((idx == 131 || idx == 406) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
		{
			return edict;
		}
	}
	return -1;
}
stock FindPlayerBack(client, indices[], len)
{
	if (len <= 0) return -1;
	new edict = MaxClients+1;
	while ((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
	{
		decl String:netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				for (new i = 0; i < len; i++)
				{
					if (idx == indices[i]) return edict;
				}
			}
		}
	}
	return -1;
}
stock GetPlayerWeaponSlot_Wearable(client, slot)
{
	new edict = MaxClients+1;
	if (slot == TFWeaponSlot_Secondary)
	{
		while((edict = FindEntityByClassname2(edict, "tf_wearable_demoshield")) != -1)
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if ((idx == 131 || idx == 406) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				return edict;
			}
		}
	}
	edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
	{
		decl String:netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (((slot == TFWeaponSlot_Primary && (idx == 405 || idx == 608)) || (slot == TFWeaponSlot_Secondary && (idx == 57 || idx == 133 || idx == 231 || idx == 444 || idx == 642))) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				return edict;
			}
		}
	}
	return -1;
}
/*public Action:OnGetGameDescription(String:gameDesc[64])
{
	if (bCvarEnabled && bCvarGameDesc && (g_bMapLoaded || !cvar_manifix))
	{
		decl String:g_szGameDesc[64];
		Format(g_szGameDesc, 64, "%s v%s", "[TF2Items]Randomizer", PLUGIN_VERSION);
		strcopy(gameDesc, sizeof(gameDesc), g_szGameDesc);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}*/
stock FindEntityByClassname2(startEnt, const String:classname[])
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

//will eventually make this fixreload
/*stock SetNextAttack(client, Float:duration = 0.0)
{
	new Float:nextAttack = GetGameTime() + duration;
	new offset = FindSendPropInfo("CBasePlayer", "m_hMyWeapons"); //weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary)
	for(new i = 0; i < 48; i++) //48?
	{
		new weapon = GetEntDataEnt2(client, offset);
		if (weapon > 0 && IsValidEdict(weapon))
		{
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", nextAttack);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", nextAttack);
		}
		offset += 4;
	}
}*/
stock bool:TF2_SdkStartup()
{
	new Handle:hGameConf = LoadGameConfigFile("tf2items.randomizer");
	if (hGameConf == INVALID_HANDLE)
	{
		SetFailState("Couldn't load SDK functions (Randomizer). Could not locate tf2items.randomizer.txt in the gamedata folder.");
		return false;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	hSDKEquipWearable = EndPrepSDKCall();
	if (hSDKEquipWearable == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call for CTFPlayer::EquipWearable");
		CloseHandle(hGameConf);
		return false;
	}
/*	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf,SDKConf_Virtual,"CTFPlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkRemoveWearable = EndPrepSDKCall();*/

/*	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hMaxHealth = EndPrepSDKCall();
	if (hMaxHealth == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call for CTFPlayer::GetMaxHealth");
		CloseHandle(hGameConf);
		return false;
	}*/

/*	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayerShared::Heal_Radius");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	hHeal_Radius = EndPrepSDKCall();
	if (hHeal_Radius == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call for CTFPlayerShared::Heal_Radius");
		CloseHandle(hGameConf);
		return false;
	}*/

	CloseHandle(hGameConf);
	bSDKStarted = true;
	return true;
}

/*stock GetPlayerSharedPointer(client)
{
	new Address:clientaddress = GetEntityAddress(client);
	new shirts = 0;
	new pants = FindSendPropInfo("CTFPlayer", "m_nPlayerCond", _, _, shirts);
	PrintToChat(client, "address %d shared %d %d %d", clientaddress, pants, shirts, pants-shirts);
	if (clientaddress == Address_Null) return -1;
	return (_:clientaddress + (pants - shirts));	//playerSharedOffset(actual);
}

stock bool:DoAOEHeal(client, bool:start = true)
{
	new thisptr = GetPlayerSharedPointer(client);
	PrintToChat(client, "thisptr %d", thisptr);
	if (thisptr == -1) return false;
	SDKCall(hHeal_Radius, thisptr, start);
	return true;
}
public Action:Cmd_Healring(client, args)
{
	decl String:arg1[32];
	if (!IsValidClient(client)) return Plugin_Continue;
	if (args < 1) arg1 = "0";
	else GetCmdArg(1, arg1, sizeof(arg1));
	PrintToChat(client, "healring %d", !!StringToInt(arg1));
	DoAOEHeal(client, !!StringToInt(arg1));
	return Plugin_Handled;
}*/
stock TF2_EquipWearable(client, entity)
{
	if (bSDKStarted == false || hSDKEquipWearable == INVALID_HANDLE)
	{
		TF2_SdkStartup();
		LogMessage("Error: Can't call EquipWearable, SDK functions not loaded! If it continues to fail, reload plugin or restart server. Make sure your gamedata is intact!");
	}
	else
	{
		if (TF2_IsEntityWearable(entity)) SDKCall(hSDKEquipWearable, client, entity);
		else LogMessage("Error: Item %i isn't a valid wearable.", entity);
	}
}

stock bool:TF2_IsEntityWearable(entity)
{
	if (entity > MaxClients && IsValidEdict(entity))
	{
		new String:strClassname[32]; GetEdictClassname(entity, strClassname, sizeof(strClassname));
		return (strncmp(strClassname, "tf_wearable", 11, false) == 0 || strncmp(strClassname, "tf_powerup", 10, false) == 0);
	}

	return false;
}

stock DoClientDoubleJump(client)
{
	decl Float:forwardVector[3];
	new Float:x, Float:y, Float:z;
	CleanupClientDirection(client, GetClientButtons(client), x, y, z);
	forwardVector[0] = x;
	forwardVector[1] = y;
	forwardVector[2] = z;
	new Float:speed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	ScaleVector(forwardVector, speed);
//	GetClientEyeAngles(client, clientEyeAngle);
//	clientEyeAngle[2] = 290.0;
//	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
//	NormalizeVector(forwardVector, forwardVector);
//	ScaleVector(forwardVector, 290.0);
	forwardVector[2] = 245.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, forwardVector);
	DealDamage(client, 10, client, (1 << 11));	//DMG_PREVENT_PHYSICS_FORCE
}

stock DealDamage(victim, damage, attacker=0, dmg_type, String:weapon[]="")	//Thanks to pimpinjuice
{
	if (IsValidClient(victim) && IsPlayerAlive(victim) && damage > 0)
	{
		new String:dmg_str[16];
		IntToString(damage, dmg_str, sizeof(dmg_str));
		new String:dmg_type_str[32];
		IntToString(dmg_type, dmg_type_str, sizeof(dmg_type_str));
		new pointHurt = CreateEntityByName("point_hurt");
		if (IsValidEntity(pointHurt))
		{
			decl String:target[32];
			Format(target, sizeof(target), "pointhurtvictim%d", victim);
			DispatchKeyValue(victim, "targetname", target);
			DispatchKeyValue(pointHurt, "DamageTarget", target);
			DispatchKeyValue(pointHurt, "Damage", dmg_str);
			DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);
			if (!StrEqual(weapon, ""))
			{
				DispatchKeyValue(pointHurt, "classname", weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt, "Hurt", (attacker > 0 ? attacker : -1));
			DispatchKeyValue(pointHurt, "classname", "point_hurt");
			DispatchKeyValue(victim, "targetname", "notpointhurtvictim");
			AcceptEntityInput(pointHurt, "Kill");
		}
	}
}

stock CleanupClientDirection(client, buttons, &Float:x, &Float:y, &Float:z)
{
//	if (buttons & IN_LEFT) PrintToChatAll("left");
//	if (buttons & IN_RIGHT) PrintToChatAll("right");
	buttons = buttons & (IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT);
//	if (buttons & IN_FORWARD) PrintToChatAll("forward");
//	if (buttons & IN_BACK) PrintToChatAll("back");
//	if (buttons & IN_MOVELEFT) PrintToChatAll("moveleft");
//	if (buttons & IN_MOVERIGHT) PrintToChatAll("moveright");
	if ((buttons & (IN_FORWARD|IN_BACK)) == (IN_FORWARD|IN_BACK))
	{
		buttons &= ~IN_FORWARD;
		buttons &= ~IN_BACK;
	}
	if ((buttons & (IN_MOVELEFT|IN_MOVERIGHT)) == (IN_MOVELEFT|IN_MOVERIGHT))
	{
		buttons &= ~IN_MOVELEFT;
		buttons &= ~IN_MOVERIGHT;
	}
	if ((buttons & (IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT)) == 0)
	{
		x = 0.0;
		y = 0.0;
		z = 230.0;
//		PrintToChatAll("Returning prematurely");
		return;
	}
	decl Float:clientEyeAngle[3];
	GetClientEyeAngles(client, clientEyeAngle);
	clientEyeAngle[0] = 0.0;
	clientEyeAngle[2] = 0.0;
	switch (buttons)
	{
		case (IN_FORWARD|IN_MOVELEFT): clientEyeAngle[1] += 45.0;
		case (IN_FORWARD|IN_MOVERIGHT): clientEyeAngle[1] -= 45.0;
		case (IN_BACK|IN_MOVELEFT): clientEyeAngle[1] += 135.0;
		case (IN_BACK|IN_MOVERIGHT): clientEyeAngle[1] -= 135.0;
		case (IN_MOVELEFT): clientEyeAngle[1] += 90.0;
		case (IN_BACK): clientEyeAngle[1] += 179.9;
		case (IN_MOVERIGHT): clientEyeAngle[1] -= 90.0;
		default: {}
	}
	if (clientEyeAngle[1] <= -180.0) clientEyeAngle[1] += 360.0;
	if (clientEyeAngle[1] > 180.0) clientEyeAngle[1] -= 360.0;
//	PrintToChatAll("%.2f yaw", clientEyeAngle[1]);
	GetAngleVectors(clientEyeAngle, clientEyeAngle, NULL_VECTOR, NULL_VECTOR);
//	PrintToChatAll("%.2f %.2f %.2f direction", clientEyeAngle[0],clientEyeAngle[1],clientEyeAngle[2]);
	NormalizeVector(clientEyeAngle, clientEyeAngle);
//	PrintToChatAll("%.2f %.2f %.2f direnormal", clientEyeAngle[0],clientEyeAngle[1],clientEyeAngle[2]);
//	AddVectors(clientEyeAngle, vector, vector);
//	NormalizeVector(vector, vector);
	x = clientEyeAngle[0];
	y = clientEyeAngle[1];
	z = clientEyeAngle[2];
}

//Returns true if timer handle was valid and was cleared, false otherwise
stock bool:ClearTimer(&Handle:timer, bool:autoClose = false)
{
	if (timer != INVALID_HANDLE)
	{
		KillTimer(timer, autoClose);
		timer = INVALID_HANDLE;
		return true;
	}
	return false;
}

stock DoTeleportParticles(client)
{
	decl Float:pos[3];
	GetClientAbsOrigin(client, pos);
	decl String:name[32];
	name = (GetClientTeam(client) == _:TFTeam_Blue ? "player_sparkles_blue" : "player_sparkles_red");
	if (TE_SetupTFParticle(name, pos, _, _, client, 3, 0, false))
		TE_SendToAll(0.0);
	name = (GetClientTeam(client) == _:TFTeam_Blue ? "teleported_blue" : "teleported_red");
	if (TE_SetupTFParticle(name, pos, _, _, client, 0, 0, false))
		TE_SendToAll(0.0);
}
stock bool:TE_SetupTFParticle(String:Name[],
			Float:origin[3] = NULL_VECTOR,
			Float:start[3] = NULL_VECTOR,
			Float:angles[3] = NULL_VECTOR,
			entindex = -1,
			attachtype = -1,
			attachpoint = -1,
			bool:resetParticles = true)
{
	// find string table
	new tblidx = FindStringTable("ParticleEffectNames");
	if (tblidx == INVALID_STRING_TABLE)
	{
		LogError("Could not find string table: ParticleEffectNames");
		return false;
	}
	
	// find particle index
	new String:tmp[256];
	new count = GetStringTableNumStrings(tblidx);
	new stridx = INVALID_STRING_INDEX;
	for (new i = 0; i < count; i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, Name, false))
		{
			stridx = i;
			break;
		}
	}
	if (stridx == INVALID_STRING_INDEX)
	{
		LogError("Could not find particle: %s", Name);
		return false;
	}
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteFloat("m_vecStart[0]", start[0]);
	TE_WriteFloat("m_vecStart[1]", start[1]);
	TE_WriteFloat("m_vecStart[2]", start[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	if (entindex != -1)
	{
		TE_WriteNum("entindex", entindex);
	}
	if (attachtype != -1)
	{
		TE_WriteNum("m_iAttachType", attachtype);
	}
	if (attachpoint != -1)
	{
		TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
	}
	TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);
	return true;
}