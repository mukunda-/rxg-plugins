// Chicken tossing for toplel ok.
// Version 1.2.0

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1	

public Plugin:myinfo =
{
	name = "Chicken Tossing",
	author = "WhiteThunder",
	description = "Chicken tossing lel",
	version = "1.2.0",
	url = ""
};

#define GRAVITY 800.0
#define GRAVITY_MULT 0.5
#define SPEED 750.0
#define VERTICAL_OFFSET -10.0

public OnPluginStart()
{
	RegAdminCmd("sm_tosschicken", Command_TossChicken, ADMFLAG_SLAY);
	//RegConsoleCmd("sm_tosschicken", Command_TossChicken);
}

public Action:Command_TossChicken(client, args)
{
	if (!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	new Float:eye_pos[3];
	GetClientEyePosition(client, eye_pos);
	eye_pos[2] += VERTICAL_OFFSET;
	
	new Float:feet_pos[3];
	GetClientAbsOrigin(client, feet_pos);
	
	new Float:angles[3];
	GetClientEyeAngles(client, Float:angles);
	
	new Float:velocity[3];
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	
	//Clear vertical angle for chicken
	angles[0] = 0.0;
	
	new Float:speed_mult = 1.0;
	new Float:gravity_mult = GRAVITY_MULT;
	
	if (args > 0)
	{
		new String:speed_arg[32];
		GetCmdArg(1, speed_arg, sizeof speed_arg);
		speed_mult = StringToFloat(speed_arg);
	}
	if (args > 1)
	{
		new String:gravity_arg[32];
		GetCmdArg(2, gravity_arg, sizeof gravity_arg);
		gravity_mult = FloatAbs(StringToFloat(gravity_arg));
	}
	
	new Float:speed = SPEED * speed_mult;
	new Float:gravity = GRAVITY * gravity_mult;
	
	velocity[0] *= speed;
	velocity[1] *= speed;
	velocity[2] *= speed;
	
	//Get player velocity and apply to chicken after speed multiplier
	new Float:player_velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", player_velocity);
	player_velocity[0] *= speed_mult;
	player_velocity[1] *= speed_mult;
	AddVectors(velocity, player_velocity, velocity);
	//PrintToChatAll("xVel: %f... yVel: %f... zVel: %f", velocity[0], velocity[1], velocity[2]);
	
	//Calculate time for chicken to land on the same plane as the player
	new Float:upTime = velocity[2] / gravity;
	new Float:height = gravity * upTime * upTime / 2 + eye_pos[2] - feet_pos[2];
	new Float:time = upTime + SquareRoot(2 * height / gravity);
	//PrintToChatAll("uptime: %f... height: %f... time: %f", upTime, height, time);
	
	//Create chicken
	new chicken = CreateEntityByName("chicken");
	DispatchSpawn(chicken);
	
	//Teleport chicken to player; apply velocity and gravity
	TeleportEntity(chicken, eye_pos, angles, velocity);
	SetEntPropFloat(chicken, Prop_Data, "m_flGravity", gravity_mult);
	
	//Create timer to halt the chicken
	CreateTimer(time, StopChicken, EntIndexToEntRef(chicken));
	
	return Plugin_Handled;
}

public Action:StopChicken(Handle:timer, any:chicken)
{
	if (!IsValidEntity(chicken)) return Plugin_Handled;
	
	//Remove velocity and restore gravity
	TeleportEntity(chicken, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 0.0});
	SetEntPropFloat(chicken, Prop_Data, "m_flGravity", 1.0);
	
	return Plugin_Handled;
}
