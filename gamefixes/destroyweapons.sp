#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Destroy Weapons",
	author = "Roker",
	description = "Destroys weapons of fallen players.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

public void OnEntityCreated(int entity, char[] classname){
	if(StrEqual(classname, "tf_dropped_weapon")){
		AcceptEntityInput(entity, "kill");
	}
}