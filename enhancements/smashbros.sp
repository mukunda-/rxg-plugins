#pragma semicolon 1


#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <tf2_stocks>  
#include <sdkhooks>
#include <tf2items>
#include <tf2-roundend>

public Plugin myinfo = 
{
	name = "Smash Bros",
	author = "Roker",
	description = "Smash Bros",
	version = "0.1",
	url = "www.reflex-gamers.com"
};
//int g_client_userid[MAXPLAYERS+1];
int g_percent[MAXPLAYERS+1];
int g_lives[MAXPLAYERS+1];

const int HUD_PERCENT = 1;
const int HUD_LIVES = 2;
const int HUD_BLUE_LIVES = 3;
const int HUD_RED_LIVES = 4;
const int HUD_TIMER = 5;

int roundTimeLeft;

char projectileList[8][64] = {	"tf_projectile_rocket", "tf_projectile_pipe", "tf_projectile_pipe_remote", "tf_projectile_flare", "tf_projectile_arrow", 
								"tf_projectile_jar", "tf_projectile_stun_ball", "tf_projectile_cleaver"};

bool preRound = false;

public void OnPluginStart()
{
	HookEvent("player_hurt",Event_Player_Hurt);
	HookEvent("player_death",Event_Player_Death);
	HookEvent("player_spawn",Event_Player_Spawn);
	HookEvent("teamplay_round_start", Event_Round_Start);
	HookEvent("teamplay_round_active", Event_Round_Begin);
	//HookEvent("teamplay_round_win", Event_Round_End, EventHookMode_Pre);
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if(IsValidClient(i)){
			SDKHook(i, SDKHook_OnTakeDamage, Event_Damage);
		}
	}
}
public void OnMapStart(){
	char mapName[32];
	char pref[6];
	GetCurrentMap(mapName, sizeof(mapName));
	
	SplitString(mapName, "_", pref, sizeof(pref));
	if(!StrEqual(pref,"sb")){
		SetFailState("Not a Smash map!!!");
	}
}
public Action TF2_OnSetWinningTeam(&TFTeam:team, &WinReason:reason, &bool:bForceMapReset, &bool:bSwitchTeams, &bool:bDontAddScore){
	int blue;
	int red;
	getTeamLives(blue, red);
	if(blue >= 0 || red >= 0){
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
void updateHudDamage(int client){
	if(g_lives[client] > 0 && IsPlayerAlive(client)){
		SetHudTextParams(0.6, 0.6, 100.0, 255, 255, 255, 0);
		ShowHudText(client, HUD_PERCENT, "Lives: %i", g_lives[client]);
		SetHudTextParams(0.3, 0.6, 100.0, 255, 255, 255, 0);
		ShowHudText(client, HUD_LIVES, "%i\%", g_percent[client]);
	}else{
		if (!IsValidClient(client) || !IsClientObserver(client)) { return;}

		int specMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		//not specing
		if (specMode != 4 && specMode != 5) { return; }
		int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		//SetHudTextParams(-1.0, -1.0, 100.0, 255, 255, 255, 0);
		//ShowHudText(target, 3, "You are spectating: %s", GetClientName(target));
		SetHudTextParams(0.6, 0.6, 100.0, 255, 255, 255, 0);
		ShowHudText(target, 2, "Lives: %i", g_lives[target]);
		SetHudTextParams(0.3, 0.6, 100.0, 255, 255, 255, 0);
		ShowHudText(target, 1, "%i\%", g_percent[target]);
	}
}
void getTeamLives(int &blue, int &red){
	for( new i = 1; i <= MaxClients; i++ ) {
		if(IsValidClient(i)){
			if(TFTeam:GetClientTeam(i) == TFTeam_Blue){
				if(g_lives[i] > 0){
					blue += g_lives[i];
				}
			}else if(TFTeam:GetClientTeam(i) == TFTeam_Red){
				if(g_lives[i] > 0){
					red += g_lives[i];
				}
			}
		}
	}
}
void updateHudTeams(){
	int blue;
	int red;
	getTeamLives(blue, red);
	for( new i = 1; i <= MaxClients; i++ ) {
		if(IsValidClient(i)){
			SetHudTextParams(0.4, 0.01, 100.0, 68, 90, 119, 0);
			ShowHudText(i, HUD_BLUE_LIVES, "%i",blue);
			SetHudTextParams(0.6, 0.01, 100.0, 251, 82, 79, 0);
			ShowHudText(i, HUD_RED_LIVES, "%i",red);
		}
	}
	PrintToChatAll("Blue: %i", blue);
	PrintToChatAll("Red: %i", red);
}
void updateHudClock(){
	int mins = RoundToFloor(roundTimeLeft / 60.0);
	int temp = roundTimeLeft;
	while(temp >= 60){
		temp -= 60;
	}
	int secs = temp;
	for( new i = 1; i <= MaxClients; i++ ) {
		if (!IsValidClient(i)) { continue; }
		SetHudTextParams(0.6, 0.01, 100.0, 255, 255, 255, 0);
		ShowHudText(i, HUD_TIMER, "%i:%i",mins,secs);
	}	
}
bool checkWinCondition(){
	int blue;
	int red;
	TFTeam winningTeam;
	getTeamLives(blue, red);
	if(blue > red){
		winningTeam = TFTeam_Blue;
	}else if(red > blue){
		winningTeam = TFTeam_Red;
	}else{
		TF2_SetWinningTeam(winningTeam, WINREASON_STALEMATE);
	}
	TF2_SetWinningTeam(winningTeam, WINREASON_OPPONENTS_DEAD);
}
/*bool IsLastTeammateAlive(int client){
	int team = GetClientTeam(client);
	for( new i = 1; i <= MaxClients; i++ ) {
		if (!IsValidClient(i)) { continue; }
		if (i == client) { continue;}
		if (!IsPlayerAlive(i)) { continue; }
		if(GetClientTeam(client) == team){
			return true;
		}
	}
	return false;
}*/
public Action Event_Damage(client, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3]){
	if(!IsValidClient(client)) {return Plugin_Continue;}
	if(!IsValidClient(attacker)){
		if (GetClientTeam(client) == GetClientTeam(attacker)){return Plugin_Continue;}
	}
	if(preRound){return Plugin_Handled;}
	if(attacker != 0 || damageType & DMG_FALL){
		SetEntityHealth(client, GetEntProp(client,Prop_Data,"m_iMaxHealth"));
	}
	
	if(attacker == client){
		g_percent[client] += RoundFloat(damage/3.0);
		return Plugin_Continue;
	}
	if(TF2_IsPlayerInCondition(client, TFCond_OnFire)){
		TF2_RemoveCondition(client, TFCond_OnFire);
	}else if(TF2_IsPlayerInCondition(client, TFCond_Bleeding)){
		TF2_RemoveCondition(client, TFCond_Bleeding);
	}
	if(damageType & DMG_BULLET || damageType & DMG_BUCKSHOT){
		//if(TF2_IsPlayerInCondition(client, tfcond
		float vec[3];
		float angles[3];
		GetClientEyeAngles(attacker,angles);
		GetAngleVectors(angles, vec, NULL_VECTOR, NULL_VECTOR);
		
		int div = 1000;
		damageForce[0] /= div;
		damageForce[1] /= div;
		damageForce[2] /= div;
		//PrintToChatAll("Vert: %f", damageForce[2]);
		if(damageForce[2] < 0){
			damageForce[2] *= -1;
		}
		damageForce[2] + 1;
		float mult = 1.0 + g_percent[client];
		damageForce[0] *= mult;
		damageForce[1] *= mult;
		damageForce[2] *= mult;
		//vec[2] = vec[2] + Logarithm(g_percent[client]/2 + damage,1.05);
		
		
		//float pos[3];
		//GetClientAbsOrigin(client,pos);
		//if(mult > 250){
			//pos[2] += 15;
		TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, damageForce); 
		//}
		//PrintToChatAll("Mult: %f", mult);
		//PrintToChatAll("Vec: %f - %f - %f", vec[0], vec[1], vec[2]);
		
	}else if(damageType & DMG_BLAST){
		float vec[3];
		vec[0] = GetEntPropFloat(client,Prop_Send,"m_vecVelocity[0]");
		vec[1] = GetEntPropFloat(client,Prop_Send,"m_vecVelocity[1]");
		vec[2] = GetEntPropFloat(client,Prop_Send,"m_vecVelocity[2]");
		
		int div = 2000;
		damageForce[0] /= div;
		damageForce[1] /= div;
		damageForce[2] /= div;
		float mult = 1.0 + g_percent[client];
		damageForce[0] *= mult;
		damageForce[1] *= mult;
		damageForce[2] *= mult;
		
		//PrintToChatAll("Mult: %f", mult);
		TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, damageForce);  
		//setWeight(client);

	}else if(damageType & DMG_CLUB){
		float vec[3];
		float angles[3];
		GetClientEyeAngles(attacker,angles);
		GetAngleVectors(angles, vec, NULL_VECTOR, NULL_VECTOR);
		
		int div = 1500;
		damageForce[0] /= div;
		damageForce[1] /= div;
		damageForce[2] /= div;
		if(damageForce[2] < 0){
			damageForce[2] *= -1;
		}
		damageForce[2] + 5;
		float mult = 1.0 + g_percent[client];
		damageForce[0] *= mult;
		damageForce[1] *= mult;
		damageForce[2] *= mult;
		//vec[2] += 10;
		//PrintToChatAll("Vert: %f", vec[2]);
		
		
		float pos[3];
		GetClientAbsOrigin(client,pos);
		//if(mult > 250){
			//pos[2] += 15;
		TeleportEntity( client, pos, NULL_VECTOR, damageForce); 
		//}
		//PrintToChatAll("Mult: %f", mult);
		//PrintToChatAll("Vec: %f - %f - %f", vec[0], vec[1], vec[2]);

	}
	g_percent[client] += RoundFloat(damage/3.0);
	updateHudDamage(client);
	//PrintToChatAll("Percent: %i", g_percent[client]);
	return Plugin_Continue;
}
public OnClientPutInServer(client){
    SDKHook(client, SDKHook_OnTakeDamage, Event_Damage);
}
public TF2_OnConditionAdded(client, TFCond:condition){
	if(condition == TFCond_OnFire){
		TF2_RemoveCondition(client, TFCond_OnFire);
	}else if(condition == TFCond_Bleeding){
		TF2_RemoveCondition(client, TFCond_Bleeding);
	}
}
public Action Event_Round_Start( Handle event, const char[] name, bool dontBroadcast ) {
	//PrintToChatAll("State: %i ", GameRules_GetProp("m_iRoundState"));
	for( new i = 1; i <= MaxClients; i++ ) {
		if(IsValidClient(i) && IsPlayerAlive(i)){
			g_lives[i] = 3;
			updateHudDamage(i);
		}
	}
	updateHudTeams();
	preRound = true;
	CreateTimer(0.1, Timer_Destroy_Projectiles, _, TIMER_REPEAT);
	return Plugin_Continue;
}
public Action Event_Round_Begin( Handle event, const char[] name, bool dontBroadcast ) {
	roundTimeLeft = 180;
	CreateTimer(0.1, Timer_Update_Clock, _, TIMER_REPEAT);
	preRound = false;
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
/*public Action Event_Round_End( Handle event, const char[] name, bool dontBroadcast ) {
	bool red = false;
	bool blue = false;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if(!red && TFTeam:GetClientTeam(i) == TFTeam_Red && g_lives[i] > 0){
			red = true;
		}else if(TFTeam:GetClientTeam(i) == TFTeam_Blue && g_lives[i] > 0){
			blue = true;
		}
		if(red && blue){
			//return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}*/
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_lives[client]--;
	updateHudDamage(client);
	
	Handle data;
	if(g_lives[client] > 1){
		CreateDataTimer( 2.0, Respawn_Player, data);
	}else{
		CreateDataTimer( 0.5, Spectator_Hud, data);
	}
	
	WritePackCell(data, client);
	updateHudTeams();
	checkWinCondition();
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action Respawn_Player(Handle timer, Handle data){
	ResetPack(data);
	int client = ReadPackCell(data);
	CloseHandle(data);
	TF2_RespawnPlayer(client);

	updateHudDamage(client);
	return Plugin_Handled;
}
//-----------------------------------------------------------------------------
public Action Spectator_Hud(Handle timer, Handle data){
	ResetPack(data);
	int client = ReadPackCell(data);
	CloseHandle(data);
	updateHudDamage(client);
	return Plugin_Handled;
}
//-----------------------------------------------------------------------------
public Action Event_Player_Hurt( Handle event, const char[] name, bool dontBroadcast ) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client)) {return Plugin_Continue;}
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(attacker != 0){
		SetEntityHealth(client, GetEntProp(client,Prop_Data,"m_iMaxHealth"));
	}
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action TF2Items_OnGiveNamedItem(client, String:classname[], ID, &Handle:hItem){
	//PrintToChatAll("WEAPON: %i", ID);
	switch(ID){
		case 996:
		{
			Handle newWep = TF2Items_CreateItem(OVERRIDE_ALL);
			TF2Items_SetItemIndex(newWep, 19);
			TF2Items_SetNumAttributes(newWep, 0);
			TF2Items_SetClassname(newWep, "tf_weapon_grenadelauncher");
			//int weapon = TF2Items_GiveNamedItem(client, hItem);
			//EquipPlayerWeapon(client, weapon);
			hItem = newWep;
			return Plugin_Changed;
		}
		case 45:
		{
			Handle newWep = TF2Items_CreateItem(OVERRIDE_ALL);
			TF2Items_SetItemIndex(newWep, 13);
			TF2Items_SetNumAttributes(newWep, 0);
			TF2Items_SetClassname(newWep, "tf_weapon_scattergun");
			//int weapon = TF2Items_GiveNamedItem(client, hItem);
			//EquipPlayerWeapon(client, weapon);
			hItem = newWep;
			return Plugin_Changed;
		}
		case 528,140:
		{
			Handle newWep = TF2Items_CreateItem(OVERRIDE_ALL);
			TF2Items_SetItemIndex(newWep, 22);
			TF2Items_SetNumAttributes(newWep, 0);
			TF2Items_SetClassname(newWep, "tf_weapon_pistol");
			//int weapon = TF2Items_GiveNamedItem(client, hItem);
			//EquipPlayerWeapon(client, weapon);
			hItem = newWep;
			return Plugin_Changed;
		}
		
	}
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action Event_Player_Spawn( Handle event, const char[] name, bool dontBroadcast ) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client)) {return Plugin_Continue;}
	if(g_percent[client] < 3){
		TF2_AddCondition(client,TFCond_Ubercharged,3.0);
	}
	g_percent[client] = 0;
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action Timer_Destroy_Projectiles(Handle timer){
	if(!preRound){
		return Plugin_Stop;
	}
	//PrintToChatAll("Searching All");
	for (int i = 0; i < sizeof(projectileList); i++){
		//PrintToChatAll("Searching: %s", projectileList[i]);
		int ent = -1;
		int prev = 0;
		while ((ent = FindEntityByClassname(ent, projectileList[i])) != -1)
		{
			if (prev) RemoveEdict(prev);
			prev = ent;
		}
		if (prev) RemoveEdict(prev);
	}
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action Timer_Update_Clock(Handle timer){
	if(roundTimeLeft <= 0){
		checkWinCondition();
		return Plugin_Stop;
	}
	roundTimeLeft--;
	updateHudClock();
	return Plugin_Continue;
}
public OnEntityCreated(entity, const char[] classname){
	if(preRound){
		//PrintToChatAll("ent create: %s", classname);
	}
}