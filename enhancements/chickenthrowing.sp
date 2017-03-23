
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Chicken Throwing",
	author = "WhiteThunder",
	description = "Chicken throwing lel",
	version = "1.3.2",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
Handle sm_chickens_gravity;
Handle sm_chickens_speed;
Handle sm_chickens_growth_timer_interval;
Handle sm_chickens_growth_scale_interval;
Handle sm_chickens_base_scale;
Handle sm_chickens_min_scale;
Handle sm_chickens_max_scale;
Handle sm_chickens_collision_radius;
Handle sm_chickens_collision_landed_mult;
Handle sm_chickens_combine_scale;
Handle sm_chickens_max_air_time;

float c_gravity;
float c_speed;
float c_growth_timer_interval;
float c_growth_scale_interval;
float c_base_scale;
float c_min_scale;
float c_max_scale;
float c_collision_radius;
float c_collision_landed_mult;
float c_combine_scale;
float c_max_air_time;

#define GRAVITY 800.0
#define VERTICAL_OFFSET -10.0
#define CASHMODEL "models/props/cs_assault/money.mdl"
#define MAXENTITIES 2048

bool g_chicken_flying[MAXENTITIES];
float g_chicken_scale[MAXENTITIES];
int g_chicken_trigger[MAXENTITIES];

//-----------------------------------------------------------------------------
public void OnMapStart() {
	PrecacheModel(CASHMODEL);
}

//-----------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("CHKN_ThrowChicken", Native_ThrowChicken);
	RegPluginLibrary("chickenthrowing");
}

//-----------------------------------------------------------------------------
void RecacheConvars() {
	c_gravity = GetConVarFloat( sm_chickens_gravity );
	c_speed = GetConVarFloat( sm_chickens_speed );
	c_growth_timer_interval = GetConVarFloat( sm_chickens_growth_timer_interval );
	c_growth_scale_interval = GetConVarFloat( sm_chickens_growth_scale_interval );
	c_base_scale = GetConVarFloat( sm_chickens_base_scale );
	c_min_scale = GetConVarFloat( sm_chickens_min_scale );
	c_max_scale = GetConVarFloat( sm_chickens_max_scale );
	c_collision_radius = GetConVarFloat( sm_chickens_collision_radius );
	c_collision_landed_mult = GetConVarFloat( sm_chickens_collision_landed_mult );
	c_combine_scale = GetConVarFloat( sm_chickens_combine_scale );
	c_max_air_time = GetConVarFloat( sm_chickens_max_air_time );
}

//-----------------------------------------------------------------------------
public void OnConVarChanged(Handle cvar, const char[] oldval, const char[] newval) {
	RecacheConvars();
}

//-----------------------------------------------------------------------------
public void OnPluginStart() {

	LoadTranslations("common.phrases");
	
	sm_chickens_gravity = CreateConVar( "sm_chickens_gravity", "800", "Chicken gravity while flying.", FCVAR_PLUGIN, true, 0.1 );
	sm_chickens_speed = CreateConVar( "sm_chickens_speed", "750", "Chicken speed while flying.", FCVAR_PLUGIN, true, 0.0 );
	sm_chickens_growth_timer_interval = CreateConVar( "sm_chickens_growth_timer_interval", "0.1", "Seconds between growth intervals.", FCVAR_PLUGIN, true, 0.1, true, 1.0 );
	sm_chickens_growth_scale_interval = CreateConVar( "sm_chickens_growth_scale_interval", "0.1", "Fraction of scale to grow per interval.", FCVAR_PLUGIN, true, 0.1, true, 10.0 );
	sm_chickens_base_scale = CreateConVar( "sm_chickens_base_scale", "1.0", "Base size for all thrown chickens.", FCVAR_PLUGIN, true, 0.1 );
	sm_chickens_min_scale = CreateConVar( "sm_chickens_min_scale", "0.4", "Minimum chicken size allowed.", FCVAR_PLUGIN, true, 0.1 );
	sm_chickens_max_scale = CreateConVar( "sm_chickens_max_scale", "6.0", "Maximum chicken size allowed.", FCVAR_PLUGIN, true, 0.1 );
	sm_chickens_collision_radius = CreateConVar( "sm_chickens_collision_radius", "5.0", "Radius of collision box for interacting with non-world objects.", FCVAR_PLUGIN, true, 1.0 );
	sm_chickens_collision_landed_mult = CreateConVar( "sm_chickens_collision_landed_mult", "5.0", "Multiplier by which to increase collision box after landing.", FCVAR_PLUGIN, true, 1.0 );
	sm_chickens_combine_scale = CreateConVar( "sm_chickens_combine_scale", "0.5", "When chickens collide, this is the fraction of one chicken's scale that will be added to the other.", FCVAR_PLUGIN, true, 0.1 );
	sm_chickens_max_air_time = CreateConVar( "sm_chickens_max_air_time", "10", "Maximum time a chicken may remain in flight.", FCVAR_PLUGIN, true, 0.1, true, 30.0 );
	
	HookConVarChange( sm_chickens_gravity, OnConVarChanged );
	HookConVarChange( sm_chickens_speed, OnConVarChanged );
	HookConVarChange( sm_chickens_growth_timer_interval, OnConVarChanged );
	HookConVarChange( sm_chickens_growth_scale_interval, OnConVarChanged );
	HookConVarChange( sm_chickens_base_scale, OnConVarChanged );
	HookConVarChange( sm_chickens_min_scale, OnConVarChanged );
	HookConVarChange( sm_chickens_max_scale, OnConVarChanged );
	HookConVarChange( sm_chickens_collision_radius, OnConVarChanged );
	HookConVarChange( sm_chickens_collision_landed_mult, OnConVarChanged );
	HookConVarChange( sm_chickens_combine_scale, OnConVarChanged );
	HookConVarChange( sm_chickens_max_air_time, OnConVarChanged );
	RecacheConvars();
	
	RegAdminCmd("sm_throwchicken", Command_ThrowChicken, ADMFLAG_SLAY);
	RegAdminCmd("sm_slaychickens", Command_SlayChickens, ADMFLAG_RCON);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

//-----------------------------------------------------------------------------
public Action Event_RoundStart(Handle event, const char[] name, bool db) {
	SlayChickens(false);
}

//-----------------------------------------------------------------------------
int SlayChickens(bool breakChicken = false) {
	int chicken_count = 0;
	
	int ent = -1;
	while ((ent = FindEntityByClassname( ent, "chicken" )) != -1) {
		char entname[64];
		GetEntPropString(ent, Prop_Data, "m_iName", entname, sizeof(entname));
		if (StrEqual(entname, "RXG_CHICKEN")) {
			KillChicken(ent, breakChicken);
			chicken_count++;
		}
	}
	
	return chicken_count;
}

//-----------------------------------------------------------------------------
public Action Command_SlayChickens(int client, int args) {
	int chicken_count = SlayChickens(true);
	
	if (chicken_count == 0) {
		ReplyToCommand(client, "[SM] No chickens found.");
		return Plugin_Handled;
	}
	
	char player_name[64];
	
	if (client == 0) {
		player_name = "Console";
	} else {
		GetClientName(client, player_name, sizeof player_name);
	}
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}
		if (CheckCommandAccess(i, "sm_kick", ADMFLAG_KICK, true)) {
			PrintToChat(i, "[SM] %s slayed all %i chicken(s).", player_name, chicken_count);
		} else {
			PrintToChat(i, "[SM] Admin slayed all %i chicken(s).", chicken_count);
		}
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action Command_ThrowChicken(int client, int args) {
	
	if (client == 0 && args == 0) return Plugin_Handled;
	
	float speed = c_speed;
	float gravity = c_gravity;
	float scale = c_base_scale;
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if (args == 0) {
		target_list[0] = client;
		target_count = 1;
	}
	
	if (args > 0) {
		char targets_arg[32];
		GetCmdArg(1, targets_arg, sizeof targets_arg);
		
		target_count = ProcessTargetString(
			targets_arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED & COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml
		);
		
		if (target_count < 1) {
			ReplyToCommand(client, "[SM] No matching client found");
			return Plugin_Handled;
		}
	}
	
	if (args > 1) {
		char scale_arg[32];
		GetCmdArg(2, scale_arg, sizeof scale_arg);
		scale = FloatAbs(StringToFloat(scale_arg));
	}
	
	if (args > 2) {
		char speed_arg[32];
		GetCmdArg(3, speed_arg, sizeof speed_arg);
		speed = StringToFloat(speed_arg);
	}
	
	if (args > 3) {
		char gravity_arg[32];
		GetCmdArg(4, gravity_arg, sizeof gravity_arg);
		gravity = FloatAbs(StringToFloat(gravity_arg));
	}
	
	for (int i = 0; i < target_count; i++) {
		ThrowChicken(target_list[i], scale, speed, gravity);
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
bool ThrowChicken(int client, float scale, float speed, float gravity) {

	if (!IsPlayerAlive(client)) {
		return false;
	}
	
	float eye_pos[3];
	GetClientEyePosition(client, eye_pos);
	eye_pos[2] += VERTICAL_OFFSET;
	
	float feet_pos[3];
	GetClientAbsOrigin(client, feet_pos);
	
	float angles[3];
	GetClientEyeAngles(client, angles);
	
	float velocity[3];
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	
	//Clear vertical angle for chicken
	angles[0] = 0.0;
	
	//No dividing by 0
	if (gravity == 0.0) {
		gravity = c_gravity;
	}
	
	velocity[0] *= speed;
	velocity[1] *= speed;
	velocity[2] *= speed;
	
	//Get player velocity and apply to chicken
	float player_velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", player_velocity);
	AddVectors(velocity, player_velocity, velocity);
	//PrintToChatAll("xVel: %f... yVel: %f... zVel: %f", velocity[0], velocity[1], velocity[2]);
	
	//Calculate time for chicken to land on the same plane as the player
	float upTime = velocity[2] / gravity;
	float height = gravity * upTime * upTime / 2 + eye_pos[2] - feet_pos[2];
	float time = upTime + SquareRoot(2 * height / gravity);
	if( time > c_max_air_time ) time = c_max_air_time;
	//PrintToChatAll("uptime: %f... height: %f... time: %f", upTime, height, time);
	
	if (scale < c_min_scale) scale = c_min_scale;
	else if (scale > c_max_scale) scale = c_max_scale;
	
	//Create chicken
	int chicken = CreateEntityByName("chicken");
	SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", scale);
	DispatchKeyValue(chicken, "targetname", "RXG_CHICKEN");
	DispatchSpawn(chicken);
	
	//Teleport chicken to player; apply velocity and gravity
	SetEntityMoveType(chicken, MOVETYPE_FLYGRAVITY);
	SetEntPropFloat(chicken, Prop_Data, "m_flGravity", gravity / GRAVITY);
	TeleportEntity(chicken, eye_pos, angles, velocity);
	
	// make the chicken follow the player
	AcceptEntityInput(chicken, "Use", client);
	
	//Create timer to stop the chicken
	CreateTimer(time, StopChicken, EntIndexToEntRef(chicken));
	AddTrigger(chicken);
	g_chicken_scale[chicken] = scale;
	g_chicken_flying[chicken] = true;
	
	return false;
}

//-----------------------------------------------------------------------------
int AddTrigger(int parent, float collision_scale = 1.0) {

	int ent = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(ent, "spawnflags", "1");

	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", parent);

	SetEntityModel(ent, CASHMODEL);

	float minbounds[3];
	float maxbounds[3];
	float scale = GetEntPropFloat(parent, Prop_Data, "m_flModelScale");
	for (int i = 0; i < 3; i++) {
		minbounds[i] = -c_collision_radius * scale * collision_scale;
		maxbounds[i] = c_collision_radius * scale * collision_scale;
	}

	SetEntPropVector(ent, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxbounds);
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4|8 |0x400); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	SetEntProp(ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test

	int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);

	float pos[3];
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);

	SDKHook(ent, SDKHook_StartTouchPost, OnChickenCollide);
	g_chicken_trigger[parent] = ent;
	return ent;
}

//-----------------------------------------------------------------------------
public Action OnChickenCollide(int trigger, int target) {

	char target_class[128];
	GetEdictClassname(target, target_class, sizeof(target_class));

	int chicken = GetEntPropEnt(trigger, Prop_Data, "m_pParent");
	
	if (StrEqual(target_class, "chicken")) {
		int changing_chicken;
		float scale_change;
		float target_scale = g_chicken_scale[target];
		float chicken_scale = g_chicken_scale[chicken];

		if (target_scale >= c_max_scale || chicken_scale >= c_max_scale) {
			return;
		}

		if (g_chicken_flying[chicken] && g_chicken_flying[target]) {
			changing_chicken = chicken;
		} else if (g_chicken_flying[chicken]) {
			changing_chicken = target;
		} else if (g_chicken_flying[target]) {
			changing_chicken = chicken;
		} else if (target_scale > chicken_scale) {
			changing_chicken = target;
		} else {
			changing_chicken = chicken;
		}
		
		if (changing_chicken == target) {
			scale_change = chicken_scale;
			KillChicken(chicken, true);
		} else {
			scale_change = target_scale;
			KillChicken(target, true);
		}
		
		scale_change *= c_combine_scale;

		if (g_chicken_flying[changing_chicken]) {
			g_chicken_flying[changing_chicken] = false;
		}

		float actual_scale = GetEntPropFloat(changing_chicken, Prop_Data, "m_flModelScale");

		if (actual_scale < g_chicken_scale[changing_chicken]) {
			g_chicken_scale[changing_chicken] += scale_change;
		} else {
			g_chicken_scale[changing_chicken] += scale_change;
			CreateTimer(c_growth_timer_interval, GrowChicken, EntIndexToEntRef(changing_chicken), TIMER_REPEAT);
		}
	}
}

//-----------------------------------------------------------------------------
void KillChicken(int chicken, bool breakChicken = false) {
	if (IsValidEntity(chicken)) {
		//AcceptEntityInput(g_chicken_trigger[chicken], "Kill");
		if (breakChicken) {
			AcceptEntityInput(chicken, "Break");
		} else {
			AcceptEntityInput(chicken, "Kill");
		}
	}
}

//-----------------------------------------------------------------------------
public Action GrowChicken(Handle timer, any chicken) {

	if (!IsValidEntity(chicken)) {
		return Plugin_Handled;
	}
	
	int chicken_index = EntRefToEntIndex(chicken);
	float scale = GetEntPropFloat(chicken, Prop_Data, "m_flModelScale");

	if (FloatAbs(scale - g_chicken_scale[chicken_index]) < c_growth_scale_interval) {
		SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", g_chicken_scale[chicken_index]);
		return Plugin_Stop;
	}
	
	if (scale >= g_chicken_scale[chicken_index] || scale >= c_max_scale) {
		return Plugin_Stop;
	}

	SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", scale + c_growth_scale_interval);

	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public Action ShrinkChicken(Handle timer, any chicken) {
	
	if (!IsValidEntity(chicken)) {
		return Plugin_Handled;
	}
	
	int chicken_index = EntRefToEntIndex(chicken);
	float scale = GetEntPropFloat(chicken, Prop_Data, "m_flModelScale");
	
	if (FloatAbs(scale - g_chicken_scale[chicken_index]) < c_growth_scale_interval) {
		SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", g_chicken_scale[chicken_index]);
		return Plugin_Stop;
	}
	
	if (scale <= g_chicken_scale[chicken_index] || scale <= c_min_scale) {
		return Plugin_Stop;
	}
	
	SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", scale - c_growth_scale_interval);
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public Action StopChicken(Handle timer, any chicken)
{
	if (!IsValidEntity(chicken)) return Plugin_Handled;

	//Remove velocity and restore gravity
	TeleportEntity(chicken, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
	SetEntPropFloat(chicken, Prop_Data, "m_flGravity", 1.0);

	int chicken_index = EntRefToEntIndex(chicken);
	g_chicken_flying[chicken_index] = false;

	// delete old chicken trigger
	int chicken_trigger = g_chicken_trigger[chicken_index];
	if (IsValidEntity(chicken_trigger)) {
		AcceptEntityInput(chicken_trigger, "Kill");
	}
	
	// add new trigger with higher collision radius
	AddTrigger(chicken_index, c_collision_landed_mult);
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public int Native_ThrowChicken(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	ThrowChicken(client, c_base_scale, c_speed, c_gravity);
}

//-----------------------------------------------------------------------------
stock bool IsValidClient( int client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
