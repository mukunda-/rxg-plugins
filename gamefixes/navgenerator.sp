#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "",
	author = "Roker",
	description = "",
	version = "1.0",
	url = ""
};

public void OnMapStart(){
	char map[64];
	GetCurrentMap(map, sizeof(map));
	Format(map, sizeof(map), "maps/%s.nav", map);
	if(!FileExists(map)){
		ServerCommand("sv_cheats 1");
		ServerCommand("nav_generate");
	}else{
		ServerCommand("mp_timelimit 1");
	}
}