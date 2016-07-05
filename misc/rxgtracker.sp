#include <sourcemod>
#include <sdktools>
#include <rxgcommon>
#include <dbrelay>

#pragma semicolon 1
#pragma newdecls required
	
public Plugin myinfo = 
{
	name = "RXG Tracker",
	author = "Roker",
	description = "WE'RE WATCHING YOU",
	version = "1.2.3",
	url = "www.reflex-gamers.com"
};

int userID[MAXPLAYERS];
int killAssistPoints[MAXPLAYERS];
int timePoints[MAXPLAYERS];


Handle sm_rxg_event;
Handle sm_rxg_time_points;
Handle sm_rxg_killassist_points;

bool c_rxg_event;
int c_rxg_time_points;
int c_rxg_killassist_points;

//-------------------------------------------------------------------------------------------------
void RecacheConvars() {
	c_rxg_event = GetConVarBool( sm_rxg_event );
	c_rxg_time_points = GetConVarInt( sm_rxg_time_points );
	c_rxg_killassist_points = GetConVarInt( sm_rxg_killassist_points );
}

//-------------------------------------------------------------------------------------------------
public void OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval ) {
	RecacheConvars();
}

//-----------------------------------------------------------------------------
public void OnPluginStart()
{
	sm_rxg_event = CreateConVar("sm_rxg_event", "0", "Is this an event server?", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	sm_rxg_time_points = CreateConVar( "sm_rxg_time_points", "1", "Points awarded per minute on the server.", FCVAR_PLUGIN, true, 0.0 );
	sm_rxg_killassist_points = CreateConVar( "sm_rxg_killassist_points", "1", "Points awarded for kills and assists.", FCVAR_PLUGIN, true, 0.0 );
	
	HookConVarChange( sm_rxg_event, OnConVarChanged );
	HookConVarChange( sm_rxg_time_points, OnConVarChanged );
	HookConVarChange( sm_rxg_killassist_points, OnConVarChanged );
	
	RecacheConvars();
	
	HookEvent("player_death", Event_Death, EventHookMode_Post);
}

//-----------------------------------------------------------------------------
public void OnPluginEnd(){
	for(int i=1;i<MaxClients;i++){
		if(!IsValidClient(i)) continue;
		sqlStore(i);
	}
}

//-----------------------------------------------------------------------------
public Action Event_Death(Handle event, char[] arg, bool noBroadcast){
	int attackerid = GetEventInt(event, "attacker");
	int attacker = GetClientOfUserId(attackerid);
	addKillAssistPoint(attacker, attackerid);
	
	int assisterid = GetEventInt(event, "assister");
	if(assisterid != -1){
		int assister = GetClientOfUserId(assisterid);
		addKillAssistPoint(assister, assisterid);
	}
}

//-----------------------------------------------------------------------------
public void OnClientDisconnect(int client){
	if(!IsValidClient(client)) return;
	
	PrintToServer("time on server: %f seconds", GetClientTime(client));
	PrintToServer("points awarded: %i", RoundToFloor(GetClientTime(client) / 60 * c_rxg_time_points));
	
	
	sqlStore(client);
}

//-----------------------------------------------------------------------------
void addKillAssistPoint(int client, int clientid){
	if(userID[client] == clientid){
		killAssistPoints[client] += c_rxg_killassist_points;
	}else{
		killAssistPoints[client] = c_rxg_killassist_points;
		userID[client] = GetClientUserId(client);	
	}
}
//-----------------------------------------------------------------------------
void sqlStore(int client){
	timePoints[client] = RoundToFloor(GetClientTime(client) / 60 * c_rxg_time_points);
	if(DBRELAY_IsConnected()) {
		char steamID[64];
		if( !GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID))) return;
		
		char query[1024];
		FormatEx( query, sizeof query, "SELECT userid FROM sourcebans_forums.steamuser WHERE steamid = %s", steamID);
		
		Handle data = CreateDataPack();
		WritePackCell(data, client);
		WritePackString( data, steamID );
		
		DBRELAY_TQuery( cmGetSteam, query, data );
	}
}

//-----------------------------------------------------------------------------
public void cmGetSteam( Handle owner, Handle results, const char [] error, any data ) {
	if( SQL_GetRowCount(results) != 1 ) return; //No, or multiple results
	
	if(!SQL_FetchRow(results)) return; //Couldnt get row.
	int forumID = SQL_FetchInt(results, 0);
	
	char query[1024];
	FormatEx( query, sizeof query, "SELECT usergroupid FROM sourcebans_forums.user WHERE userid = %i", forumID);
	
	DBRELAY_TQuery( cmCheckMember, query, data);
}

//-----------------------------------------------------------------------------
public void cmCheckMember( Handle owner, Handle results, const char [] error, any data ) {
	if( SQL_GetRowCount(results) != 1 ) return; //No, or multiple results
	
	
	if(!SQL_FetchRow(results)) return; //Couldnt get row.

	int groupID = SQL_FetchInt(results, 0); //usergroupid
	if(groupID <= 20 || groupID == 31) return; //Not member or banned

	
	ResetPack(data);
	char steamID[64];
	int client = ReadPackCell(data);
	ReadPackString(data, steamID, sizeof(steamID));
	
	char query[1024];
	
	FormatEx( query, sizeof query,
	"INSERT INTO sourcebans_tracker.points( account, timepoints, killassistpoints ) VALUES ( %s, %i, %i ) ON DUPLICATE KEY UPDATE timepoints = timepoints + %i, killassistpoints = killassistpoints + %i",
	steamID,
	timePoints[client], killAssistPoints[client],
	timePoints[client], killAssistPoints[client]);
	
	DBRELAY_TQuery( IgnoredSQLResult, query );
	
	if(c_rxg_event && GetClientCount() > 5){
		FormatEx( query, sizeof query,
		"INSERT INTO sourcebans_forums.event_participation VALUES ( %s, %i, now()) ON DUPLICATE KEY UPDATE minutes = minutes + %i",
		steamID, timePoints[client], timePoints[client]);
		DBRELAY_TQuery( IgnoredSQLResult, query );
	}
	
	killAssistPoints[client] = 0;
}

//-----------------------------------------------------------------------------
public void IgnoredSQLResult( Handle owner, Handle hndl, const char [] error, any data ) {
    if( !hndl ) {
        LogError( "SQL Error --- %s", error );
        return;
    }
}