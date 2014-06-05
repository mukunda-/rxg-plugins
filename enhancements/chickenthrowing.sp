// Chicken throwing command and api
// Version 1.0.0

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "Chicken Throwing",
	author = "WhiteThunder",
	description = "Chicken throwing lel",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define GRAVITY 800.0
#define SPEED 750.0
#define VERTICAL_OFFSET -10.0

#define GROWTH_TIMER_INVERVAL 0.1
#define GROWTH_SCALE_INTERVAL 0.1
#define BASE_SCALE 1.0
#define MIN_SCALE 0.4
#define MAX_SCALE 6.0
#define COLLISION_RADIUS 5.0
#define COLLISION_LANDED_MULT 5.0
#define COMBINATION_MULT 0.3

#define CASHMODEL "models/props/cs_assault/money.mdl"
#define MAXENTITIES 2048

new bool:g_chicken_flying[MAXENTITIES];
new Float:g_chicken_scale[MAXENTITIES];
new g_chicken_trigger[MAXENTITIES];

public OnMapStart() {
	PrecacheModel(CASHMODEL);
}

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative("CHKN_ThrowChicken", Native_ThrowChicken);
	RegPluginLibrary("chickenthrowing");
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_throwchicken", Command_ThrowChicken, ADMFLAG_SLAY);
}

//-------------------------------------------------------------------------------------------------
public Action:Command_ThrowChicken(client, args) {
	
	if (client == 0 && args == 0) return Plugin_Handled;
	
	new Float:speed = SPEED;
	new Float:gravity = GRAVITY;
	new Float:scale = BASE_SCALE;
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
ThrowChicken(client, Float:scale, Float:speed, Float:gravity)
{
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
		gravity = GRAVITY;
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
	//PrintToChatAll("uptime: %f... height: %f... time: %f", upTime, height, time);
	
	if (scale < MIN_SCALE) scale = MIN_SCALE;
	
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
		minbounds[i] = -COLLISION_RADIUS * scale * collision_scale;
		maxbounds[i] = COLLISION_RADIUS * scale * collision_scale;
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

		new bool:enemy_chickens = GetClientTeam(thrower) != GetClientTeam(other_thrower);

		if (!enemy_chickens && (target_scale >= MAX_SCALE || chicken_scale >= MAX_SCALE) ||
			enemy_chickens && (target_scale <= MIN_SCALE || chicken_scale <= MIN_SCALE)) {
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
		
		scale_change *= COMBINATION_MULT;

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
				CreateTimer(GROWTH_TIMER_INVERVAL, ShrinkChicken, EntIndexToEntRef(changing_chicken), TIMER_REPEAT);
			} else {
				g_chicken_scale[changing_chicken] += scale_change;
				CreateTimer(GROWTH_TIMER_INVERVAL, GrowChicken, EntIndexToEntRef(changing_chicken), TIMER_REPEAT);
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

	if (FloatAbs(scale - g_chicken_scale[chicken_index]) < GROWTH_SCALE_INTERVAL) {
		SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", g_chicken_scale[chicken_index]);
		return Plugin_Stop;
	}
	
	if (scale >= g_chicken_scale[chicken_index] || scale >= MAX_SCALE) {
		return Plugin_Stop;
	}

	SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", scale + GROWTH_SCALE_INTERVAL);

	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public Action:ShrinkChicken(Handle:timer, any:chicken) {
	
	if (!IsValidEntity(chicken)) {
		return Plugin_Handled;
	}
	
	new chicken_index = EntRefToEntIndex(chicken);
	new Float:scale = GetEntPropFloat(chicken, Prop_Data, "m_flModelScale");
	
	if (FloatAbs(scale - g_chicken_scale[chicken_index]) < GROWTH_SCALE_INTERVAL) {
		SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", g_chicken_scale[chicken_index]);
		return Plugin_Stop;
	}
	
	if (scale <= g_chicken_scale[chicken_index] || scale <= MIN_SCALE) {
		return Plugin_Stop;
	}
	
	SetEntPropFloat(chicken, Prop_Data, "m_flModelScale", scale - GROWTH_SCALE_INTERVAL);
	
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
	AddTrigger(chicken_index, COLLISION_LANDED_MULT);
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Native_ThrowChicken(Handle:plugin, numParams) {
	new client = GetNativeCell(1);
	new Float:scale = Float:GetNativeCell(2);
	new Float:speed = Float:GetNativeCell(3);
	new Float:gravity = Float:GetNativeCell(4);
	ThrowChicken(client, scale, speed, gravity);
}
