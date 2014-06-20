#include <sourcemod> 
#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "latenightmayhem",
	author = "roker + PRAY&SPRAY = oh SHIT",
	description = "Changes settings at different times",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

new Handle:sm_latehour;
new c_latehour;
new Handle:sm_earlyhour;
new c_earlyhour; 
new Handle:mp_timelimit;
new old_timelimit; 
new setting ;

enum {
	NULLMODE,
	NIGHTMODE,
	DAYMODE
};

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_latehour = GetConVarInt( sm_latehour );
	c_earlyhour = GetConVarInt( sm_earlyhour ); 
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	// RECACHE CONVARS WHEN THEY CHANGE
	RecacheConvars();
	// now they are in HOT MEMORY ready to be ACCESSED.
}

CacheTimeLimit() {
	old_timelimit = GetConVarInt( mp_timelimit );
}
 
//-------------------------------------------------------------------------------------------------
public OnPluginStart() {	
	sm_latehour = CreateConVar( "sm_latehour", "00", "Hour late settings should kick in.", FCVAR_PLUGIN );
	sm_earlyhour = CreateConVar( "sm_earlyhour", "10", "Hour default settings should kick in.", FCVAR_PLUGIN );
	HookConVarChange( sm_latehour, OnConVarChanged );
	HookConVarChange( sm_earlyhour, OnConVarChanged ); 
	RecacheConvars(); // you see this clean ass shit man? this is how you make convars.
	
	//c_defaultmaptime = CreateConVar( "sm_defaultmaptime", "30.0", "Default map time.", FCVAR_PLUGIN );
	
	mp_timelimit = FindConVar( "mp_timelimit" ); 
	CacheTimeLimit();
	
	CreateTimer(300.0, CheckTime, _, TIMER_REPEAT); // CHECK EVERY 5 MINUTES
}

//-------------------------------------------------------------------------------------------------
public OnConfigsExecuted() {	
	setting = NULLMODE;
	CacheTimeLimit(); // THIS PROBABLY ISN'T NECESSARY but.
	Update();
}

//-------------------------------------------------------------------------------------------------
public Action:CheckTime(Handle:timer){ 
	Update();
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public Update(){

	decl String:time[30];	
	new hour;
	FormatTime(time, sizeof(time), "%H", GetTime());
	hour = StringToInt(time); 
	if( c_latehour < c_earlyhour ){
		if( hour >= c_latehour && hour < c_earlyhour ){
			ChangeSetting( NIGHTMODE );
		} else {
			ChangeSetting( DAYMODE );
		}
	} else {
		if(hour >= c_latehour || hour < c_earlyhour ){
			ChangeSetting( NIGHTMODE );
		} else {
			ChangeSetting( DAYMODE );
		}
	} 
}

//-------------------------------------------------------------------------------------------------
ChangeSetting( newsetting ) {
	if( setting == newsetting ) return;
	setting = newsetting;
	
	decl String:map[30];
	GetCurrentMap(map,sizeof(map));
	//PrintToServer("test%i",StrContains(map,"plr_hightower",false));
	if( setting == NIGHTMODE ){
		if( StrContains(map,"plr_hightower",false) != 0 ){
			SetConVarString( FindConVar("sm_nextmap"), "plr_hightower");
		} else {
			SetConVarInt( mp_timelimit, 0 );
		}
		ServerCommand( "sm plugins unload rockthevote" );
	} else {
		ServerCommand( "sm plugins load rockthevote" );
		SetConVarInt( mp_timelimit, old_timelimit );
	}
}