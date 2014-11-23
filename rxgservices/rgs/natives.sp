
//-----------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, 
							  String:error[], err_max ) {
							  
	CreateNative( "RGS_Request", Native_Request );
	CreateNative( "RGS_RequestS", Native_RequestS );
	CreateNative( "RGS_Connected", Native_Connected );
	
	RegPluginLibrary( "rxgservices" );
}

//-----------------------------------------------------------------------------
DoRequest( Handle:plugin, bool:simple) {
	
	// queue a response handler
	new info[RQ_SIZE];
	info[RQ_PLUGIN]  = _:plugin;
	info[RQ_HANDLER] = GetNativeCell(1);
	info[RQ_SIMPLE] = simple;
	PushArrayArray( g_request_queue, info );
	
	// format the request and send it.
	decl String:request[512];
	new written;
	FormatNativeString( 0, 2, 3, sizeof request, written, request );
	request[written] = '\n';
	request[written+1] = 0;
	SendMessage2( request );
}

//-----------------------------------------------------------------------------
public Native_Request( Handle:plugin, numParams ) {

	if( !g_connected ) {
		// not connected, give invalid response.
		CallHandler( plugin, Function:GetNativeCell(1), true, 
				INVALID_HANDLE, 0 );
	}
	
	DoRequest( plugin, false );
}

//-----------------------------------------------------------------------------
public Native_RequestS( Handle:plugin, numParams ) {
	if( !g_connected ) {
		// not connected, give invalid response.
		CallHandlerS( plugin, Function:GetNativeCell(1), true, "" );
	}
	DoRequest( plugin, true );
}

//-----------------------------------------------------------------------------
public Native_Connected( Handle:plugin, numParams ) {
	return g_connected;
}
