
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "replaceslides",
	author = "REFLEX-GAMERS",
	description = "replace office projector slides",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------
new String:target_names[4][64] = {
	"InstanceAuto1-slideshow_projector_image1",
	"InstanceAuto1-slideshow_projector_image2",
	"InstanceAuto1-slideshow_projector_image3",
	"InstanceAuto1-slideshow_projector_image4"
};

new Handle:target_trie;

//----------------------------------------------------------------------------------------------------------------------
new String:textures[4][128] = {
	"rxg/slides/2_1",
	"rxg/slides/2_2",
	"rxg/slides/2_3",
	"rxg/slides/2_4"
};
   
//----------------------------------------------------------------------------------------------------------------------
#define SLIDESHOW_SPEED 10.0

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	target_trie = CreateTrie();
	for( new i = 0; i < sizeof target_names; i++ ) {
		SetTrieValue( target_trie, target_names[i], i );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	 
	for( new i = 0; i < sizeof(textures); i++ ) {
		decl String:download[128];
		FormatEx( download, sizeof download, "materials/%s.vtf", textures[i] );
		PrecacheGeneric( download ); // no idea what this does but this program works.
		AddFileToDownloadsTable( download );
	}
	ReplaceSlides();
}

//----------------------------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
  
	ReplaceSlides();
}
  
//----------------------------------------------------------------------------------------------------------------------
ReplaceSlides() {
	new ent = -1;
	while( (ent = FindEntityByClassname( ent, "env_projectedtexture" )) != -1 ) {
		decl String:name[64]; 
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof(name) );
		 
		new index;
		if( GetTrieValue( target_trie, name, index ) ) {
			SetEntPropString( ent, Prop_Send, "m_SpotlightTextureName", textures[index] );
		}
	}

	ent = -1;
	while( (ent = FindEntityByClassname( ent, "logic_timer" )) != -1 ) {
		decl String:name[64];
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof(name) );
		if( StrEqual( name, "InstanceAuto1-slide_show_projector_timer" ) ) {
			SetEntPropFloat( ent, Prop_Data, "m_flRefireTime", SLIDESHOW_SPEED );
			break;
		}
	}
}
