#if defined _traceeyes_included
	#endinput
#endif

#define _traceeyes_included

#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceEyesFilter( entity, contentsMask ) {
	return false;
}

stock bool:TraceEyes( client, Float:result[3] ) {
	decl Float:start[3];
	decl Float:angles[3];

	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angles );

	TR_TraceRayFilter( start, angles, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_Infinite, TraceEyesFilter );

	if( TR_DidHit() ) {
		TR_GetEndPosition( result );
		
		return true;
	}
	return false;
}
