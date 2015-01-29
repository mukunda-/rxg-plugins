new Handle:AllowPickup = INVALID_HANDLE;
new Handle:AwpAllowPickup = INVALID_HANDLE;
new Handle:AdminImmunity = INVALID_HANDLE;
new Handle:RestrictSound = INVALID_HANDLE;
#if defined WARMUP
new Handle:WarmUp = INVALID_HANDLE;
new Handle:WarmupTime = INVALID_HANDLE;
new Handle:grenadegive = INVALID_HANDLE;
new Handle:ffcvar = INVALID_HANDLE;
new Handle:warmupff = INVALID_HANDLE;
new Handle:WarmupRespawnTime = INVALID_HANDLE;
new Handle:WarmupRespawn = INVALID_HANDLE;
#endif

#if defined PERPLAYER
new Handle:PerPlayerRestrict = INVALID_HANDLE;
new Handle:PerPlayerBots = INVALID_HANDLE;
new Handle:PerPlayerSpecs = INVALID_HANDLE;
#endif

//Convar Handles
new Handle:hRestrictCVarsT[_:WeaponID-4];//No shield, No None, No Defuser, No SCAR17
new Handle:hRestrictCVarsCT[_:WeaponID-4];//No shield, No None, No C4, No SCAR17
new Handle:g_version = INVALID_HANDLE;
new CvarArrayHandleValCT[_:WeaponID];
new CvarArrayHandleValT[_:WeaponID];

new Handle:mp_maxmoney = INVALID_HANDLE;
new Handle:hHeAmmo = INVALID_HANDLE;
new Handle:hFlashAmmo = INVALID_HANDLE;
new Handle:hSmokeAmmo = INVALID_HANDLE;

CreateConVars()
{
	new x = 0;
	new y = 0;
	decl String:cvar[64];
	decl String:desc[128];
	for(new i = 0; i < _:WeaponID; i++)
	{
		if(WeaponID:i == WEAPON_NONE || WeaponID:i == WEAPON_SHIELD || WeaponID:i == WEAPON_SCAR17 || AllowedGame[WeaponID:i] == -1 || (g_iGame == GAME_CSS && (AllowedGame[WeaponID:i] != 1 && AllowedGame[WeaponID:i] != 2)) || (g_iGame == GAME_CSGO && (AllowedGame[WeaponID:i] != 1 && AllowedGame[WeaponID:i] != 3)))
		{
			CvarArrayHandleValCT[WeaponID:i] = -1;
			CvarArrayHandleValT[WeaponID:i] = -1;
			continue;
		}
		if(WeaponID:i != WEAPON_DEFUSER)
		{
			if(WeaponID:i != WEAPON_C4)
			{
				Format(cvar, sizeof(cvar), "sm_restrict_%s_t", weaponNames[WeaponID:i]);
			}
			else
			{
				Format(cvar, sizeof(cvar), "sm_restrict_%s", weaponNames[WeaponID:i]);
			}
			Format(desc, sizeof(desc), "-1 = unrestricted, 0 = restricted, positive numbers = number allowed for Terrorists . Weapon:%s", weaponNames[WeaponID:i]);
			hRestrictCVarsT[x] = CreateConVar(cvar, "-1", desc);
			CvarArrayHandleValT[WeaponID:i] = x;
			x++;
		}
		else
		{
			CvarArrayHandleValT[WeaponID:i] = -1;
		}
		if(WeaponID:i != WEAPON_C4)
		{
			if(WeaponID:i != WEAPON_DEFUSER)
			{
				Format(cvar, sizeof(cvar), "sm_restrict_%s_ct", weaponNames[WeaponID:i]);
			}
			else
			{
				Format(cvar, sizeof(cvar), "sm_restrict_%s", weaponNames[WeaponID:i]);
			}
			Format(desc, sizeof(desc), "-1 = unrestricted, 0 = restricted, positive numbers = number allowed for Counter-Terrorists. Weapon:%s", weaponNames[WeaponID:i]);
			hRestrictCVarsCT[y] = CreateConVar(cvar, "-1", desc);
			CvarArrayHandleValCT[WeaponID:i] = y;
			y++;
		}
		else
		{
			CvarArrayHandleValCT[WeaponID:i] = -1;
		}
	}
	
	AllowPickup		= CreateConVar("sm_allow_restricted_pickup", "0", "Set to 0 to ONLY allow pickup if under the max allowed. Set to 1 to allow restricted weapon pickup");
	AwpAllowPickup	= CreateConVar("sm_allow_awp_pickup", "1", "Set to 0 to allow awp pickup ONLY if it is under the max allowed. Set to 1 to use sm_allow_restricted_pickup method.");
	AdminImmunity 	= CreateConVar("sm_weapon_restrict_immunity", "0", "Enables admin immunity so admins can buy restricted weapons");
	
	RestrictSound	= CreateConVar("sm_restricted_sound", "sound/buttons/weapon_cant_buy.wav", "Sound to play when a weapon is restricted (leave blank to disable)");
		
	mp_maxmoney 	= FindConVar("mp_maxmoney");
	if(g_iGame == GAME_CSS)
	{
		hHeAmmo			= FindConVar("ammo_hegrenade_max");
		hFlashAmmo		= FindConVar("ammo_flashbang_max");
		hSmokeAmmo		= FindConVar("ammo_smokegrenade_max");
	}
	#if defined WARMUP
	WarmUp 			= CreateConVar("sm_warmup_enable", "1", "Enable warmup.");
	WarmupTime		= CreateConVar("sm_warmup_time", "45", "How long in seconds warmup lasts");
	grenadegive		= CreateConVar("sm_warmup_infinite", "1", "Weather or not give infinite grenades if warmup weapon is grenades");
	warmupff		= CreateConVar("sm_warmup_disable_ff", "1", "If 1 disables ff during warmup. If 0 leaves ff enabled");
	WarmupRespawn	= CreateConVar("sm_warmup_respawn", "1", "Respawn players during warmup");
	WarmupRespawnTime = CreateConVar("sm_warmup_respawn_time", "0.5", "Time after death before respawning player");
	ffcvar			= FindConVar("mp_friendlyfire");
	#endif
	#if defined PERPLAYER
	PerPlayerRestrict = CreateConVar("sm_perplayer_restrict", "0", "If enabled will restrict awp per player count");
	PerPlayerBots 	  = CreateConVar("sm_perplayer_bots", "1", "If enabled will count bots in per player restricts");
	PerPlayerSpecs	  = CreateConVar("sm_perplayer_specs", "1", "If enabled will count specs in per player restricts");
	RegServerCmd("sm_perplayer_debug", Perplayer_Debug, "Command used to debug per player stuff");
	HookConVarChange(PerPlayerRestrict, PerPlayerConVarChange);
	HookConVarChange(PerPlayerBots, PerPlayerConVarChange);
	HookConVarChange(PerPlayerSpecs, PerPlayerConVarChange);
	#endif
	AutoExecConfig(true, "weapon_restrict");
	
	g_version = CreateConVar("sm_weaponrestrict_version", PLUGIN_VERSION, "Weapon restrict version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
}
#if defined PERPLAYER
public PerPlayerConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CheckPerPlayer();
}
#endif