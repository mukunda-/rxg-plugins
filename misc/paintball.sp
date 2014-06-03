
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike_weapons>
#include <clientprefs>

#include <donations>

#pragma semicolon 1

//debug:
//#define MATERIAL "materials/deathshot/deathshot.vmt"
#define GLOWMAT "materials/sprites/glow.vmt"
//new g_sprite;

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "paintball",
	author = "mukunda",
	description = "paintball",
	version = "1.0.1",
	url = "www.mukunda.com"
};

//new Handle:sm_paintball_enabled;
//new paintball_round;

#define MODEL "models/rxg_paintball/paintball.mdl"

#define PB_BUFFERSIZE 512

// paintballs!
new Float:last_time;
new Float:time_passed;

new bool:pb_active[PB_BUFFERSIZE];
new Float:pb_lastpos[PB_BUFFERSIZE][3];
new Float:pb_start[PB_BUFFERSIZE];
new Float:pb_vel[PB_BUFFERSIZE][3];
new pb_client[PB_BUFFERSIZE];
new pb_color[PB_BUFFERSIZE];
new pb_ent[PB_BUFFERSIZE];
new pb_first;
new pb_next;

new bool:g_hooked[MAXPLAYERS+1];

//new Float:tec9_damage_table[] = { 130.0, 32.0, 40.0, 32.0, 32.0, 24.0, 24.0 };

//new g_active_hitgroup[MAXPLAYERS+1];

new client_color[MAXPLAYERS+1]; //
new client_glow[MAXPLAYERS+1]; // donaturs only

new Float:client_recoil[MAXPLAYERS+1];

//new Float:weapon_next_use[MAXPLAYERS+1];

//#define WEAPON_RELOAD_TIME 3.0
#define WEAPON_USE_TIME 1.0
new bool:weapon_delay[MAXPLAYERS+1];

new Handle:paint_accuracy_base;
new Float:c_accuracy_base;
new Handle:paint_accuracy_velscale;
new Float:c_accuracy_velscale;
new Handle:paint_accuracy_recoil_constant;
new Float:c_accuracy_recoil_constant;
new Handle:paint_accuracy_recoil_decay;
new Float:c_accuracy_recoil_decay;

new Handle:mp_friendlyfire;
new bool:c_friendlyfire;

//----------------------------------------------------------------------------------------------------------------------
new String:color_preset_names[][] = {
	"red",		// 0
	"green",	// 1
	"blue",		// 2
	"orange",	// 3
	"yellow",	// 4
	"cyan",		// 5
	"white",	// 6
	"magenta",	// 7
	"pink",
	"off"
};

new color_presets[] = {
	255, 0, 0,		// 0
	0, 255, 0,		// 1
	0, 0, 255,		// 2
	255, 128, 0,	// 3
	255,255,0,		// 4
	0,255,255,		// 5
	255,255,255,	// 6
	255,0,255,		// 7
	255,0,128,
	0,0,0
};


//----------------------------------------------------------------------------------------------------------------------
new paintball_colors[][3] = {
	{111,180,56},
	{211,26,31},
	{26,89,211},
	{215,215,215}
};

new String:paintball_decals[][] = {
	"rxg_paintball/green",
	"rxg_paintball/red",
	"rxg_paintball/blue",
	"rxg_paintball/white"
};

new String:paintball_color_names[][] = {
	"Green",
	"Red",
	"Blue",
	"White"
};

#define DECAL_VARIATIONS 1

new precached_decals[sizeof(paintball_decals)][DECAL_VARIATIONS];

//----------------------------------------------------------------------------------------------------------------------
new player_last_buttons[MAXPLAYERS+1];


//----------------------------------------------------------------------------------------------------------------------
new Handle:cookie_color; // integer
new Handle:cookie_glow; // red green blue

new Handle:menu_colors;

//----------------------------------------------------------------------------------------------------------------------
public PaintballColorHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_End ) {
		//CloseHandle( menu ); oh thats right we need this later
	} else if( action == MenuAction_Select ) {
		if( !AreClientCookiesCached(param1) ) return 0;
		decl String:info[32];
 
		/* Get item info */
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info));
		
		if( found ) {
			/* Tell the client */
			
			if( Donations_GetClientLevelDirect( param1 ) ) {
				SetClientCookie( param1, cookie_color, info );
				client_color[param1] = StringToInt(info);
				PrintToChat( param1, "Color changed to %s.", paintball_color_names[StringToInt(info)] );
			} else {
				PrintToChat( param1, "Awesome colors are for donators only." );
			}
		}
	}
	return 0;
}

//----------------------------------------------------------------------------------------------------------------------
public PaintballColorCookieHandler(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	if( action == CookieMenuAction_DisplayOption ) {
		Format( buffer, maxlen, "Paintball Color (%s)", paintball_color_names[client_color[client]] );
	} else if( action == CookieMenuAction_SelectOption ) {
		DisplayMenu( menu_colors, client, MENU_TIME_FOREVER );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public PaintballGlowHandler(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	if( action == CookieMenuAction_DisplayOption ) {
		Format( buffer, maxlen, "Paintball Glow" );
	} else if( action == CookieMenuAction_SelectOption ) {
		if( client_glow[client] < 0 ) {
			PrintToChat( client, "Your glow is set to \"random\"." );
		} else if( client_glow[client] == 0 ) {
			PrintToChat( client, "Your glow is \"disabled\"." );
		} else {
			PrintToChat( client, "Your glow is set to \"%06X\"", client_glow[client] );
		}
		PrintToChat( client, "Use !pbglow to change your glow color." );
		PrintToChat( client, "Use \"!pbglow off\" to disable glow" );
	}
}

CacheAllCookies() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) return;
		if( !AreClientCookiesCached(i) ) return;
		OnClientCookiesCached(i);
	}
}

public OnConVarChanged( Handle:convar, const String:oldvalue[], const String:newvalue[] ) {
	if( convar == paint_accuracy_base ) {
		c_accuracy_base = GetConVarFloat( paint_accuracy_base );
	} else if( convar == paint_accuracy_velscale ) {
		c_accuracy_velscale = GetConVarFloat( paint_accuracy_velscale );
	} else if( convar == paint_accuracy_recoil_constant ) {
		c_accuracy_recoil_constant = GetConVarFloat( paint_accuracy_recoil_constant );
	} else if( convar == paint_accuracy_recoil_decay ) {
		c_accuracy_recoil_decay = GetConVarFloat( paint_accuracy_recoil_decay );
	} else if( convar == mp_friendlyfire ) {
		c_friendlyfire = GetConVarBool( mp_friendlyfire );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookAllClients();
	
	cookie_color = RegClientCookie( "paintball_color", "Paintball Color Index", CookieAccess_Protected );
	cookie_glow = RegClientCookie( "paintball_glow", "Paintball Glow COLOUR", CookieAccess_Protected );
	
	mp_friendlyfire = FindConVar( "mp_friendlyfire" );
	HookConVarChange( mp_friendlyfire, OnConVarChanged );
	c_friendlyfire = GetConVarBool( mp_friendlyfire );
	
	paint_accuracy_base = CreateConVar( "paint_accuracy_base", "0.002", "base deviation of paintballs", FCVAR_PLUGIN );
	HookConVarChange(paint_accuracy_base,OnConVarChanged);
	c_accuracy_base = GetConVarFloat( paint_accuracy_base );
	paint_accuracy_velscale = CreateConVar( "paint_accuracy_velscale", "0.1", "how much moving throws off paintballs", FCVAR_PLUGIN );
	HookConVarChange(paint_accuracy_velscale,OnConVarChanged);
	c_accuracy_velscale = GetConVarFloat( paint_accuracy_velscale );
	paint_accuracy_recoil_constant = CreateConVar( "paint_accuracy_recoil_constant", "10.0", "how much recoil each shot adds", FCVAR_PLUGIN );
	HookConVarChange(paint_accuracy_recoil_constant,OnConVarChanged);
	c_accuracy_recoil_constant = GetConVarFloat( paint_accuracy_recoil_constant );
	paint_accuracy_recoil_decay = CreateConVar( "paint_accuracy_recoil_decay", "0.91", "rate at which person regains control 0.0 = disable recoil,1.0 = fuck shit up" );
	HookConVarChange(paint_accuracy_recoil_decay,OnConVarChanged);
	c_accuracy_recoil_decay = GetConVarFloat( paint_accuracy_recoil_decay );
	
	menu_colors = CreateMenu( PaintballColorHandler, MENU_ACTIONS_DEFAULT );
	for( new i = 0; i < sizeof(paintball_colors); i++ ) {
		decl String:text[64];
		decl String:info[64];
		Format( text, sizeof(text), "%s", paintball_color_names[i] );
		Format( info, sizeof(info), "%d", i );
		AddMenuItem( menu_colors, info, text );
	}
	SetMenuTitle( menu_colors, "Select Color (Donatur Only Hur Hur)");
	
	CacheAllCookies();
	
	SetCookieMenuItem( PaintballColorCookieHandler, 0, "Paintball Color" );
	SetCookieMenuItem( PaintballGlowHandler, 0, "Paintball Glow" );
	
	HookEvent( "round_prestart", Event_RoundStart );
	HookEvent( "player_spawn", Event_PlayerSpawn );
//	HookEvent( "weapon_fire", Event_WeaponFire );
	
	
	RegConsoleCmd( "pbtest", test );
//	RegConsoleCmd( "buy", Command_buy );
//	RegConsoleCmd( "rebuy", Command_buy );
//	RegConsoleCmd( "autobuy", Command_buy );
	
	RegConsoleCmd( "pbglow", Command_pbglow );
}

//---------------------------------------------------------------------------------------------------------------------- 
Saturate( value, min, max ) {
	if( value < min ) value = min;
	if( value > max ) value = max;
	return value;
}
public GetIntArg( index ) {
	decl String:arg[16];
	GetCmdArg(index,arg,sizeof(arg));
	return StringToInt(arg);
}

parse_hexbyte( const String:code[] ) {
	new code0,code1;
	code0 = CharToLower(code[0]);
	code1 = CharToLower(code[1]);

	new result;
	if( (code0 >= '0' && code0 <= '9') ) {
		result += (code0-'0') * 16;
	} else if( (code0 >= 'a' && code0 <= 'f' ) ) {
		result += (code0-'a'+10) * 16;
	} else {
		return -1;
	}

	if( (code1 >= '0' && code1 <= '9') ) {
		result += (code1-'0');
	} else if( (code1 >= 'a' && code1 <= 'f' ) ) {
		result += (code1-'a'+10);
	} else {
		return -1;
	}

	return result;
}

parse_digit( const String:code[] ) {
	new result;
	if( code[0] < '0' || code[0] > '9' ) return -1;
	result = code[0] - '0';
	result = result * 255 / 9;
	return result;
}
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_pbglow( client, args ) {
	if( !Donations_GetClientLevelDirect( client ) ) {
		ReplyToCommand( client, "Sweet Paintball Glows are for donators only." );
		return Plugin_Handled;
	}
	
	
	
	new bool:setcolor = false;
	new red,green,blue;
	new bool:found_preset;
	new bool:random = false;
	
	if( args == 3 ) {
		red = Saturate(GetIntArg(1),0,255);
		green = Saturate(GetIntArg(2),0,255);
		blue = Saturate(GetIntArg(3),0,255);
		setcolor=true;
	} else if( args == 1 ) {
		decl String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		

		if( StrEqual( arg, "random" ) ) {
			
			found_preset = true;
			random = true;
			setcolor = true;
		}
		
		if( !found_preset ) {
			for( new i = 0; i < sizeof(color_preset_names); i++ ) {
				if( StrEqual( arg, color_preset_names[i] ) ) {
					red = color_presets[i*3];
					green = color_presets[i*3+1];
					blue = color_presets[i*3+2];
					found_preset = true;
					setcolor = true;
					break;
				}
			}
		}

		if( !found_preset ) {
			
			
			new bool:errornous = false;
			
			new len = strlen(arg);
			if( len == 6 ) {
				// hexcode
				red = parse_hexbyte( arg );
				green = parse_hexbyte( arg[2] );
				blue = parse_hexbyte( arg[4] );

				if( red == -1 || green == -1 || blue == -1 ) errornous = true;
			} else if( len == 3 ) {
				// shortcode
				red = parse_digit(arg);
				green = parse_digit(arg[1]);
				blue = parse_digit(arg[2]);

				if( red == -1 || green == -1 || blue == -1 ) errornous = true;
			} else {
				errornous = true;
			}

			if( errornous ) {
				ReplyToCommand( client, "Invalid color!!" );
				return Plugin_Handled;
			} else {
				setcolor = true;
			}
		}
	}

	if( !setcolor ) {
		ReplyToCommand( client, "Usage: pbglow <rgb> (0-9) or <red> <green> <blue> (0-255) or RRGGBB (hexcode) or <color> (name)" );
		return Plugin_Handled;
	}
	
	if( !random ) {
		client_glow[client] = red + (green<<8) + (blue<<16);
	} else {
		client_glow[client] = -1;
	}
	decl String:cookie[64];
	Format( cookie, sizeof(cookie), "%d", client_glow[client] );
	SetClientCookie( client, cookie_glow, cookie );
	
	if( client_glow[client] == -1 ) {
		ReplyToCommand( client, "Glow set to RANDOM" );
	} else if( client_glow[client] == 0 ) { 
		ReplyToCommand( client, "Glow disabled" );
	} else {
		ReplyToCommand( client, "Glow set to %06X", client_glow[client] );
	}
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientCookiesCached( client ) {
	decl String:arg[64];
	GetClientCookie( client, cookie_color, arg, sizeof(arg) );
	client_color[client] = StringToInt( arg );
	GetClientCookie( client, cookie_glow, arg, sizeof(arg) );
	client_glow[client] = StringToInt( arg );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_buy( client, args ) {
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	
	//g_sprite = PrecacheModel(MATERIAL);
	PrecacheModel( MODEL ); // todo: real paintballs
	
	AddFileToDownloadsTable( "models/rxg_paintball/paintball.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg_paintball/paintball.mdl" );
	AddFileToDownloadsTable( "models/rxg_paintball/paintball.phy" );
	AddFileToDownloadsTable( "models/rxg_paintball/paintball.vvd" );
	AddFileToDownloadsTable( "materials/rxg_paintball/paintball.vmt" );
	AddFileToDownloadsTable( "materials/rxg_paintball/paintball.vtf" );
	
	PrecacheModel( GLOWMAT );
	for( new i = 0; i < sizeof(paintball_decals); i++ ) {
		for( new j = 0; j < DECAL_VARIATIONS; j++ ) {
			decl String:decalstring[64];
			Format( decalstring, sizeof(decalstring), "%s%02d", paintball_decals[i], j+1 );
			precached_decals[i][j] = PrecacheDecal( decalstring );
			
			decl String:file[128];
			Format( file, sizeof(file), "materials/%s.vmt", decalstring );
			AddFileToDownloadsTable( file );
			Format( file, sizeof(file), "materials/%s.vtf", decalstring );
			AddFileToDownloadsTable( file );
		}
	}
	
	for( new i = 0; i < 4; i++ ) {
		decl String:file[64];
		Format( file, sizeof(file), "*paintball/poot%d.mp3", i+1 );
		PrecacheSound( file );
		
		Format( file, sizeof(file), "sound/%s", file[1] );
		AddFileToDownloadsTable( file );
	}
	
	for( new i = 0; i < 2; i++ ) {
		decl String:file[64];
		Format( file, sizeof(file), "*paintball/purt%d.mp3", i+1 );
		PrecacheSound( file );
		
		Format( file, sizeof(file), "sound/%s", file[1] );
		AddFileToDownloadsTable( file );
	}
	
	
}

//----------------------------------------------------------------------------------------------------------------------
PlayPaintballShootSound(client) {
	new weapon = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( weapon <= 0 ) return;
	
	
	decl String:file[64];
	Format( file, sizeof(file), "*paintball/poot%d.mp3", GetRandomInt(1,4) );
	//Format( file, sizeof file, "Weapon_tec9.Single" );
	
	EmitSoundToAll( file, weapon );
	
}

//----------------------------------------------------------------------------------------------------------------------
PlaySplatSound( const Float:vec[3] ) {
	decl String:file[64];
	Format( file, sizeof(file), "*paintball/purt%d.mp3", GetRandomInt(1,2) );
	EmitAmbientSound( file, vec );
}

//----------------------------------------------------------------------------------------------------------------------
HookAllClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( g_hooked[i] ) continue;
		HookClient(i);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected(client) {
	g_hooked[client] = false;
	client_color[client] = 0;
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer(client) {	
	HookClient(client);
	
}

//----------------------------------------------------------------------------------------------------------------------
HookClient( client ) {
	SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
	//SDKHook( client, SDKHook_PreThinkPost, OnPreThinkPost ); 
	//SDKHook( client, SDKHook_ReloadPost, OnReloadPost );
	g_hooked[client] = true;
}
 

//-------------------------------------------------------------------------------------------------
/*
new counter = 0;
public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast) {

	// emit paintball
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
//	ShootPaintball( client );
}*/

//-------------------------------------------------------------------------------------------------
AddPaintball() {
	if( ((pb_next+1) % PB_BUFFERSIZE) == pb_first ) {
		PrintCenterTextAll( "*ERROR!* OUT OF PAINTBALLS *ERROR!*" );
		return -1;
	}
	new index = pb_next;
	pb_next = ((pb_next+1) % PB_BUFFERSIZE);
	return index;
}

//-------------------------------------------------------------------------------------------------
CreatePaintDecal( color, const Float:vec[3] ) { //, const Float:norm[3] ) {
	TE_Start( "World Decal" );
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteNum( "m_nIndex", precached_decals[color][GetRandomInt(0,DECAL_VARIATIONS-1)] );
	TE_SendToAll();
	
	/*
	TE_Start( "Projected Decal" );
	
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteNum( "m_nIndex", precached_decals[color][GetRandomInt(0,DECAL_VARIATIONS-1)] );
	TE_WriteFloat( "m_flDistance", 5.0 );
	decl Float:inorm[3];
	for( new i = 0; i < 3; i++ ) {
		inorm[i] = -norm[i];
	}
	
	decl Float:ang[3];
	GetVectorAngles( inorm, ang );
	TE_WriteVector( "m_angRotation", ang );
	TE_SendToAll();

*/
}

//-------------------------------------------------------------------------------------------------
ShootPaintball( client ) {
	new pb = AddPaintball();
	if( pb == -1 ) return;
	

	decl Float:start[3];
	GetClientEyePosition( client, start );
	decl Float:angles[3];
	GetClientEyeAngles( client, angles );
	
	decl Float:dir[3];
	GetAngleVectors( angles, dir, NULL_VECTOR, NULL_VECTOR );
	
	new ent = CreateEntityByName( "prop_physics_override" );
	
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	DispatchKeyValue(ent, "model", MODEL);
	new col = client_color[client];
	new glow = client_glow[client];
	if( col < 0 || col > sizeof(paintball_colors) || Donations_GetClientLevelDirect(client) == 0 ) {
		col = 0;
	}
	if( glow > 0xFFFFFF || glow < -1 || Donations_GetClientLevelDirect(client) == 0 ) {
		glow = 0;
	}
	
	SetEntityRenderColor( ent, paintball_colors[col][0]/2, paintball_colors[col][1]/2, paintball_colors[col][2]/2 );
	
	////////////SetEntPropFloat( ent, Prop_Send, "m_flModelScale", 64.0); // tiny paintballs

	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);//FLY);//VPHYSICS);   
	decl Float:ang[3];
	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );


	new Float:poop[3];
	
	poop[0] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]" );
	poop[1] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]" );
	poop[2] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[2]" );
	
	new Float:accuracy = (GetVectorLength( poop ) * c_accuracy_velscale ) + 1.0; // todo: accuracy cvar
	accuracy += client_recoil[client];
	client_recoil[client] += c_accuracy_recoil_constant;
	
	
	for( new i = 0; i < 3; i++ )
		start[i] += dir[i] * 2.0;
	for( new i = 0; i < 3; i++ )
		dir[i] += GetRandomFloat( -c_accuracy_base*accuracy,c_accuracy_base*accuracy );
	NormalizeVector( dir, dir );
	for( new i = 0; i < 3; i++ )
		dir[i] *= 2000.0;
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 ); //debris
	
	DispatchSpawn(ent);	
	TeleportEntity( ent, start, ang, dir );

	pb_ent[pb] = ent;
	pb_active[pb] = true;
	pb_start[pb] = GetGameTime();
	pb_client[pb] = client;
	pb_color[pb] = col;
	GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", pb_lastpos[pb] );
	
	SetEntProp( ent, Prop_Send, "m_usSolidFlags", 0x04); // NOT SOLID
	for( new i = 0; i < 3; i++ )
		pb_vel[pb][i] = dir[i];
	
	if( glow != 0 ) {
		new color[3];
		if( glow < 0 ) {
			color[0] = GetRandomInt( 0, 255 );
			color[1] = GetRandomInt( 0, 255 );
			color[2] = GetRandomInt( 0, 255 );
			// normalize
			new highest = color[0];
			if( highest > color[1] ) highest = color[1];
			if( highest > color[2] ) highest = color[2];
			for( new i = 0; i < 3; i++ ) 
				color[i] = (color[i] * 140) / highest;
			
		} else {
			color[0] = glow & 255;
			color[1] = (glow >>8) & 255;
			color[2] = (glow>>16)&255;
		}
		AttachGlow( ent,color );
	}
	
	PlayPaintballShootSound(client);
}

//-------------------------------------------------------------------------------------------------
bool:OnPlayerWantsToFire( client ) {

	new weap = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( weap == -1 ) return false;
	
	decl String:classname[64];
	classname[7] = 0;
	GetEntityClassname( weap, classname, sizeof(classname) );
	new WeaponType:wtype = GetWeaponType( classname );
	if( wtype == WeaponTypeGrenade || wtype == WeaponTypeArmor || wtype == WeaponTypeKnife || wtype == WeaponTypeOther || wtype == WeaponTypeShield || wtype == WeaponTypeNone ) {
		return false; // non paintball weaps!
	}

	
	if( weapon_delay[client] ) {
		new Float:time = GetEntPropFloat( weap, Prop_Send, "m_flNextPrimaryAttack" );
	 
		if( GetGameTime() < time ) {
			return false;
		} else {
			DisableWeaponFire( weap );
			weapon_delay[client] = false;
		}
	} else {
		/// //????
		DisableWeaponFire( weap );
	}
	
	new ammo = GetEntProp( weap, Prop_Send, "m_iClip1" );
	
	if( ammo > 0 ) {
		ammo--;
		SetEntProp( weap, Prop_Send, "m_iClip1", ammo );
		ShootPaintball(client);
		if( IsWeaponEmpty(weap) ) {
			weapon_delay[client] = true;
			EnableWeaponFire( weap );
		}
	}
	
	return true;
}

//-------------------------------------------------------------------------------------------------
bool:IsWeaponEmpty( weap ) {
	return GetEntProp( weap, Prop_Send, "m_iClip1" ) == 0;
}

//-------------------------------------------------------------------------------------------------
bool:IsWeaponFull( weap ) {
	return GetEntProp( weap, Prop_Send, "m_iClip1" ) == 100; // todo: not hardcoded
}

//-------------------------------------------------------------------------------------------------
#define CLIENT_WEAPONS_MAX 64
StripPlayerWeapons( client ) {
	for( new i = 0; i < 64; i++ ) {
		new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		if( ent <= 0 ) continue;
		if( ent == GetPlayerWeaponSlot( client, int:SlotKnife ) ) continue;
	
		CS_DropWeapon(client, ent, true, true);
		AcceptEntityInput(ent, "Kill");
	}
}

//-------------------------------------------------------------------------------------------------
#define WEAPON_AMMO_BACKPACK 1452
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event,"userid") );
	if( !client ) return;
	StripPlayerWeapons(client);
	new ent = GivePlayerItem( client, "weapon_tec9" );
	new a = GetEntProp( ent, Prop_Send, "m_iPrimaryAmmoType" );
	
	//DisableWeaponFire( ent );
	weapon_delay[client] = true;
	
	//weapon_next_use[client] = GetGameTime() + WEAPON_USE_TIME;
	
	SetEntProp( client, Prop_Send, "m_iAmmo", 200, _, a );
//	SetEntData( ent, WEAPON_AMMO_BACKPACK, 200 );
}

 
//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	ResetPaintballData();
}

//-------------------------------------------------------------------------------------------------
ResetPaintballData() {
	for( new i = 0; i < PB_BUFFERSIZE; i++ ) {
		pb_ent[i] = 0;
		pb_active[i] = false;
	}
	pb_first = pb_next = 0;
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_Clients( entity, contentsMask, any:data ) {
	if( entity != data ) {
		return true;
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_Clients2( entity, contentsMask, any:data ) {
	if( entity > MaxClients ) return false;
	if( entity != data ) {
		return true;
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
public Action:test( client, args ) {

/*
	decl Float:start[3];
	decl Float:dir[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, dir );
	TR_TraceRayFilter( start, dir, CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_MONSTER|CONTENTS_DEBRIS|CONTENTS_HITBOX, RayType_Infinite,TraceFilter_Clients, client );
	if( TR_DidHit() ) {
		PrintToChatAll( "hit %d %d", TR_GetHitGroup(), TR_GetEntityIndex()  );
	} else {
		PrintToChatAll( "nohit"  );
	}
	
	new Float:end[3];
	new Float:norm[3];
	GetAngleVectors( dir, norm, NULL_VECTOR, NULL_VECTOR );
	end[0] = start[0] + norm[0] * 2000.0;
	end[1] = start[1] + norm[1] * 2000.0;
	end[2] = start[2] + norm[2] * 2000.0;
		
	new color[4];
	color[0] = 128;
	color[1] = 128;
	color[2] = 0;
	color[3] = 255;
	TE_SetupBeamPoints( end,start, g_sprite, 0, 0,0, 10.0, 0.4, 0.4, 2, 0.0, color, 4);
	
	TE_SendToAll();
	*/
	
	
	new weapon = GetPlayerWeaponSlot( client, _:SlotPistol );
	EnableWeaponFire(weapon);
	//if( weapon != -1 ) DisableWeaponFire( weapon );

	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnGameFrame() {
	time_passed = GetGameTime() -last_time;
	last_time = GetGameTime();

	UpdatePaintballs();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		client_recoil[i] *= c_accuracy_recoil_decay;
	}
}

//-------------------------------------------------------------------------------------------------
AttachGlow( parent, color[3] ) {
	new ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", ent );
	SetEntityModel( ent, GLOWMAT );
	SetEntityRenderColor( ent, color[0], color[1], color[2] );
	SetEntityRenderMode( ent, RENDER_WORLDGLOW );//RENDER_GLOW );
	DispatchKeyValue( ent, "GlowProxySize", "5.0" );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "20.0" ); 
	DispatchKeyValue( ent, "scale", "10.0" );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent",parent );
	new Float:pos[3];

	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
}

//-------------------------------------------------------------------------------------------------
UpdatePaintballs() {
	new newfirst = pb_next;
	for( new i = pb_first; i != pb_next; i = (i+1) % PB_BUFFERSIZE ) {

		if( !pb_active[i] ) continue;
		if( !IsValidEntity( pb_ent[i] ) ) {
			pb_active[i] = false;
			continue;
		}
		new Float:time = GetGameTime() - pb_start[i];
		if( time > 2.0 ) {
			pb_active[i] = false;
			AcceptEntityInput( pb_ent[i], "Kill" );
			continue;
		}
		if( newfirst == pb_next ) newfirst = i;
		decl Float:vec[3];		
		GetEntPropVector( pb_ent[i], Prop_Data, "m_vecAbsOrigin", vec );
		// run trace
		TR_TraceRayFilter( pb_lastpos[i], vec, MASK_SHOT, RayType_EndPoint,TraceFilter_Clients, pb_client[i] );
		if( TR_DidHit() ) {
			new target = TR_GetEntityIndex();

			decl Float:pos[3];
			TR_GetEndPosition( pos );
			PlaySplatSound( pos );
			if( target <= 0 ) {
				//world hit

				pb_active[i] = false;
				AcceptEntityInput( pb_ent[i], "Kill" );
				//todo:apply decal
				
				//decl Float:norm[3];
				//TR_GetPlaneNormal( INVALID_HANDLE, norm );
				CreatePaintDecal( pb_color[i], pos );//, norm );
				continue;
			} else {
				pb_active[i] = false;
				AcceptEntityInput( pb_ent[i], "Kill" );
				
				decl String:classname[64];
				GetEntityClassname(target,classname,sizeof(classname));
				if( StrEqual(classname,"func_breakable_surf") ) {
					new Float:poop[3] = {0.5,0.5,100.0};
					SetVariantVector3D(poop);
					AcceptEntityInput( target, "Shatter" );
				} else {
				
					// if target is a player and friendlyfire is disabled, skip damage/push for teammates
					if( !c_friendlyfire && target <= MaxClients ) {
						if( GetClientTeam(target) == GetClientTeam(pb_client[i]) ) {
							continue;
						}
					}
					TeleportEntity( target, NULL_VECTOR, NULL_VECTOR, pb_vel[i] );
					SDKHooks_TakeDamage( target,target, pb_client[i], 900.0 );
				}
				continue;
				
			}
			
			
			
		}
		for( new j = 0; j < 3; j++ ) {
			pb_lastpos[i][j] = vec[j];
		}

	
		for( new j = 0; j < 3; j++ ) {
			pb_vel[i][2] -= 100.0 * time_passed;
			pb_vel[i][j] *= Pow(0.99,time_passed) ;
		}
		TeleportEntity( pb_ent[i], NULL_VECTOR, NULL_VECTOR, pb_vel[i] );

	}
	pb_first = newfirst;
}

//-------------------------------------------------------------------------------------------------
DisableWeaponFire( weapon ) {
	
	// do not disable knife
	decl String:classname[64];
	GetEntityClassname( weapon, classname, sizeof(classname) );
	if( StrEqual( classname, "weapon_knife" ) ) return;

	SetEntPropFloat( weapon, Prop_Send, "m_flNextPrimaryAttack", 262144.0 );
	SetEntPropFloat( weapon, Prop_Send, "m_flNextSecondaryAttack", 262144.0 );

}

//-------------------------------------------------------------------------------------------------
EnableWeaponFire( weapon ) {
	
	decl String:classname[64];
	GetEntityClassname( weapon, classname, sizeof(classname) );
	if( StrEqual( classname, "weapon_knife" ) ) return;
	
	SetEntPropFloat( weapon, Prop_Send, "m_flNextPrimaryAttack", 0.0 );
	SetEntPropFloat( weapon, Prop_Send, "m_flNextSecondaryAttack", 0.0 );
}


//-------------------------------------------------------------------------------------------------
/*
FirePlayerWeapon( client ) {
	new weapon = GetEntPropEnt( client, Prop_Send,"m_hActiveWeapon" );
	
	new vm = GetEntPropEnt( client, Prop_Send, "m_hViewModel" );
	PrintToChatAll( "%d - %d", weapon, vm );
	PrintToChatAll( "@ %d ", GetEntPropEnt( vm, Prop_Data, "m_hWeapon" ) );
	SetEntProp( vm, Prop_Send, "m_nSequence", 1 );
	SetEntProp( vm, Prop_Send, "m_nNewSequenceParity", 1 );
}*/
TryReload(client) {
	if( weapon_delay[client] ) return;
	
	new weap = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( weap == -1 ) return;
	decl String:classname[64];
	GetEntityClassname( weap, classname, sizeof(classname) );
	if( StrEqual(classname,"weapon_knife") ) return;
	
	if( IsWeaponFull(weap) ) return;
	
	weapon_delay[client] = true;
	EnableWeaponFire(weap);
	
}

//-------------------------------------------------------------------------------------------------
public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {
	if( !IsPlayerAlive(client) ) return Plugin_Continue;
	//if( IsFakeClient(client) ) return Plugin_Continue; // DEBUG-BYPASS
	if( weapon ) {
	
		weapon_delay[client] = true;
		
		SetEntPropFloat( weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + WEAPON_USE_TIME ); // you leave me no choice...
		  
	}
	new oldbuttons = buttons;
	
	if( buttons & IN_RELOAD ) {
		TryReload(client);
		 
	}
	
	
	if( ((player_last_buttons[client]^buttons)&buttons) & IN_ATTACK ) {
		// shoot1
		if( OnPlayerWantsToFire(client) ) {
		
			buttons &= ~IN_ATTACK;
		}
		
		//FirePlayerWeapon(client);
	}
	/* fuck it
	if( buttons & IN_SPEED ) {
		
		//buttons &= ~IN_SPEED;
		//PrintToServer( "%f = ==", GetEntPropFloat( client, Prop_Send, "m_fForceTeam" ) );
		//SetEntPropFloat( client, Prop_Send, "m_fForceTeam",3.0 );
	} else {
		
		//SetEntPropFloat( client, Prop_Send, "m_flFriction", 1.0 );
	}
	*/
	// x-axis speed.
	 
	
	
	player_last_buttons[client] = oldbuttons;
	
	return Plugin_Changed;
}
/* fuck it
public OnPreThinkPost( client ) {
	
	SetEntPropFloat( client, Prop_Send, "m_flMaxspeed",500.0 );
	new Float:poop[3];
	
	poop[0] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]" );
	poop[1] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]" );
	poop[2] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[2]" );
	
	PrintToServer( "%f %f", poop[0], poop[1] );
	poop[0] = 50.0;
	poop[1] = 50.0;
	
	SetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]" ,poop[0] );
	SetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]",poop[1]  );
}
*/
//-------------------------------------------------------------------------------------------------
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3]) {
	if(!(attacker > 0 && attacker <= MaxClients && victim > 0 && victim <= MaxClients)) {
		return Plugin_Continue;
	}
	if( damage <= 0 || weapon <= 0 ) return Plugin_Handled;
	if( !IsValidEntity( weapon ) ) {
		return Plugin_Handled;
	}

	decl String:weapon_name[32];
	GetEntityClassname( weapon, weapon_name, sizeof(weapon_name) );
	if( StrEqual( weapon_name, "weapon_knife" ) ) { // 1hit knife kill
		damage = 9000.0;
		return Plugin_Changed;
	}
	damage = 0.0;
	return Plugin_Changed;


/*
	// wjere the magic happens
	new hg = g_active_hitgroup[victim];
	if( hg < 1 || hg > 7 ) return Plugin_Handled;
	new Float:expected_damage = tec9_damage_table[hg-1];
	if( damage < expected_damage * 0.7 ) {
		// too weak
		damage = 0.0;
		return Plugin_Handled;
	} else {
		damage = 900.0;
	}*/
	//return Plugin_Changed;
}

//-------------------------------------------------------------------------------------------------

/* PLACE UNUSED CODE BELOW! */





//-------------------------------------------------------------------------------------------------
/*
//----------------------------------------------------------------------------------------------------------------------
public OnTraceAttackPost(victimID, attackerID, inflictor, Float:damage, damagetype, ammotype, hitbox, hitgroup) {

	// verify valid message
	if (!(hitgroup > 0 && attackerID > 0 && attackerID <= MaxClients && victimID > 0 && victimID <= MaxClients)) {
		return;
	}
	g_active_hitgroup[victimID] = hitgroup;
}

*/

