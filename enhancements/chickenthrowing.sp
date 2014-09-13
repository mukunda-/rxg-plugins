
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Chicken Throwing",
	author = "WhiteThunder",
	description = "Chicken throwing lel",
	version = "1.2.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
new Handle:sm_chickens_gravity;
new Handle:sm_chickens_speed;
new Handle:sm_chickens_growth_timer_interval;
new Handle:sm_chickens_growth_scale_interval;
new Handle:sm_chickens_base_scale;
new Handle:sm_chickens_min_scale;
new Handle:sm_chickens_max_scale;
new Handle:sm_chickens_collision_radius;
new Handle:sm_chickens_collision_landed_mult;
new Handle:sm_chickens_combine_scale;
new Handle:sm_chickens_max_air_time;

new Float:c_gravity;
new Float:c_speed;
new Float:c_growth_timer_interval;
new Float:c_growth_scale_interval;
new Float:c_base_scale;
new Float:c_min_scale;
new Float:c_max_scale;
new Float:c_collision_radius;
new Float:c_collision_landed_mult;
new Float:c_combine_scale;
new Float:c_max_air_time;

#define GRAVITY 800.0
#define VERTICAL_OFFSET -10.0
#define CASHMODEL "models/props/cs_assault/money.mdl"
#define MAXENTITIES 2048

new bool:g_chicken_flying[MAXENTITIES];
new Float:g_chicken_scale[MAXENTITIES];
new g_chicken_trigger[MAXENTITIES];

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel(CASHMODEL);
}

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative("CHKN_ThrowChicken", Native_ThrowChicken);
	RegPluginLibrary("chickenthrowing");
}

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
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

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

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
}

//-------------------------------------------------------------------------------------------------
public Action:Command_ThrowChicken(client, args) {
	
	if (client == 0 && args == 0) return Plugin_Handled;
	
	new Float:speed = c_speed;
	new Float:gravity = c_gravity;
	new Float:scale = c_base_scale;
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if (args == 0) {
		target_list[0] = client;
		target_count = 1;
	}
	
	if (args > 0) {
		new String:targets_arg[32];
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
		new String:scale_arg[32];
		GetCmdArg(2, scale_arg, sizeof scale_arg);
		scale = FloatAbs(StringToFloat(scale_arg));
	}
	
	if (args > 2) {
		new String:speed_arg[32];
		GetCmdArg(3, speed_arg, sizeof speed_arg);
		speed = StringToFloat(speed_arg);
	}
	
	if (args > 3) {
		new String:gravity_arg[32];
		GetCmdArg(4, gravity_arg, sizeof gravity_arg);
		gravity = FloatAbs(StringToFloat(gravity_arg));
	}
	
	for (new i = 0; i < target_count; i++) {
		ThrowChicken(target_list[i], scale, speed, gravity);
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
ThrowChicken(client, Float:scale, Float:speed, Float:gravity) {

	if (!IsPlayerAlive(client)) {
		return false;
	}
	
	new Float:eye_pos[3];
	GetClientEyePosition(client, eye_pos);
	eye_pos[2] += VERTICAL_OFFSET;
	
	new Float:feet_pos[3];
	GetClientAbsOrigin(client, feet_pos);
	
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	
	new Float:velocity[3];
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
	new Float:player_velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", player_velocity);
	AddVectors(velocity, player_velocity, velocity);
	//PrintToChatAll("xVel: %f... yVel: %f... zVel: %f", velocity[0], velocity[1], velocity[2]);
	
	//Calculate time for chicken to land on the same plane as the player
	new Float:upTime = velocity[2] / gravity;
	new Float:height = gravity * upTime * upTime / 2 + eye_pos[2] - feet_pos[2];
	new Float:time = upTime + SquareRoot(2 * height / gravity);
	if( time > c_max_air_time ) time = c_max_air_time;
	//PrintToChatAll("uptime: %f... height: %f... time: %f", upTime, height, time);
	
	if (scale < c_min_scale) scale = c_min_scale;
	else if (scale > c_max_scale) scale = c_max_scale;
	
	//Create chicken
	new chicken = CreateEntityByName("chicken");
	SetEntPropEnt(chicken, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", scale);
	DispatchSpawn(chicken);
	
	//Teleport chicken to player; apply velocity and gravity
	SetEntityMoveType(chicken, MOVETYPE_FLYGRAVITY);
	SetEntPropFloat(chicken, Prop_Data, "m_flGravity", gravity / GRAVITY);
	TeleportEntity(chicken, eye_pos, angles, velocity);
	
	//Create timer to stop the chicken
	CreateTimer(time, StopChicken, EntIndexToEntRef(chicken));
	AddTrigger(chicken);
	g_chicken_scale[chicken] = scale;
	g_chicken_flying[chicken] = true;
	
	return false;
}

//-------------------------------------------------------------------------------------------------
AddTrigger(parent, Float:collision_scale = 1.0) {

	new ent = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(ent, "spawnflags", "1");

	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", parent);

	SetEntityModel(ent, CASHMODEL);

	new Float:minbounds[3];
	new Float:maxbounds[3];
	new Float:scale = GetEntPropFloat(parent, Prop_Data, "m_flModelScale");
	for (new i = 0; i < 3; i++) {
		minbounds[i] = -c_collision_radius * scale * collision_scale;
		maxbounds[i] = c_collision_radius * scale * collision_scale;
	}

	SetEntPropVector(ent, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxbounds);
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4|8 |0x400); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	SetEntProp(ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test

	new enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);

	new Float:pos[3];
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);

	SDKHook(ent, SDKHook_StartTouchPost, OnChickenCollide);
	g_chicken_trigger[parent] = ent;
	return ent;
}

//-------------------------------------------------------------------------------------------------
public Action:OnChickenCollide(trigger, target) {

	new String:target_class[128];
	GetEdictClassname(target, target_class, sizeof(target_class));

	new chicken = GetEntPropEnt(trigger, Prop_Data, "m_pParent");
	new thrower = GetEntPropEnt(chicken, Prop_Send, "m_hOwnerEntity");

	if (StrEqual(target_class, "chicken")) {
		new other_thrower = GetEntPropEnt(target, Prop_Send, "m_hOwnerEntity");

		new changing_chicken;
		new Float:scale_change;
		new Float:target_scale = g_chicken_scale[target];
		new Float:chicken_scale = g_chicken_scale[chicken];

		//if one of the clients is not valid, treat as ally chickens
		new bool:enemy_chickens = IsValidClient(thrower) && IsValidClient(other_thrower) && GetClientTeam(thrower) != GetClientTeam(other_thrower);

		if (!enemy_chickens && (target_scale >= c_max_scale || chicken_scale >= c_max_scale) ||
			enemy_chickens && (target_scale <= c_min_scale || chicken_scale <= c_min_scale)) {
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
			KillChicken(chicken);
		} else {
			scale_change = target_scale;
			KillChicken(target);
		}
		
		scale_change *= c_combine_scale;

		if (g_chicken_flying[changing_chicken]) {
			g_chicken_flying[changing_chicken] = false;
		}

		new Float:actual_scale = GetEntPropFloat(changing_chicken, Prop_Data, "m_flModelScale");

		if (!enemy_chickens && actual_scale < g_chicken_scale[changing_chicken]) {
			g_chicken_scale[changing_chicken] += scale_change;
		} else if (enemy_chickens && actual_scale > g_chicken_scale[changing_chicken]) {
			g_chicken_scale[changing_chicken] -= scale_change;
		} else {
			if (enemy_chickens) {
				g_chicken_scale[changing_chicken] -= scale_change;
				CreateTimer(c_growth_timer_interval, ShrinkChicken, EntIndexToEntRef(changing_chicken), TIMER_REPEAT);
			} else {
				g_chicken_scale[changing_chicken] += scale_change;
				CreateTimer(c_growth_timer_interval, GrowChicken, EntIndexToEntRef(changing_chicken), TIMER_REPEAT);
			}
		}

	} else if (target > 0 && target <= MaxClients && target != thrower && g_chicken_flying[chicken]) {
		//KillChicken(chicken);
	}
}

//-------------------------------------------------------------------------------------------------
KillChicken(chicken) {
	if (IsValidEntity(chicken)) {
		//AcceptEntityInput(g_chicken_trigger[chicken], "Kill");
		AcceptEntityInput(chicken, "Break");
		//TeleportEntity(chicken, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		//CreateTimer(0.0, KillChickenTimer, EntIndexToEntRef(chicken));
	}
}

//-------------------------------------------------------------------------------------------------
public Action:KillChickenTimer(Handle:timer, any:chicken) {
	if (IsValidEntity(chicken)) {
		AcceptEntityInput(chicken, "Break");
	}
}

//-------------------------------------------------------------------------------------------------
public Action:GrowChicken(Handle:timer, any:chicken) {

	if (!IsValidEntity(chicken)) {
		return Plugin_Handled;
	}
	
	new chicken_index = EntRefToEntIndex(chicken);
	new Float:scale = GetEntPropFloat(chicken, Prop_Data, "m_flModelScale");

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

//-------------------------------------------------------------------------------------------------
public Action:ShrinkChicken(Handle:timer, any:chicken) {
	
	if (!IsValidEntity(chicken)) {
		return Plugin_Handled;
	}
	
	new chicken_index = EntRefToEntIndex(chicken);
	new Float:scale = GetEntPropFloat(chicken, Prop_Data, "m_flModelScale");
	
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

//-------------------------------------------------------------------------------------------------
public Action:StopChicken(Handle:timer, any:chicken)
{
	if (!IsValidEntity(chicken)) return Plugin_Handled;

	//Remove velocity and restore gravity
	TeleportEntity(chicken, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	SetEntPropFloat(chicken, Prop_Data, "m_flGravity", 1.0);

	new chicken_index = EntRefToEntIndex(chicken);
	g_chicken_flying[chicken_index] = false;

	AcceptEntityInput(g_chicken_trigger[chicken_index], "Kill");
	AddTrigger(chicken_index, c_collision_landed_mult);
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Native_ThrowChicken(Handle:plugin, numParams) {
	new client = GetNativeCell(1);
	ThrowChicken(client, c_base_scale, c_speed, c_gravity);
}

//-----------------------------------------------------------------------------
stock bool:IsValidClient( client ) {
	return ( client > 0 && client <= MaxClients && IsClientInGame(client) );
}
