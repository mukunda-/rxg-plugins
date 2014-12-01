
//-----------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, 
							  String:error[], err_max ) {
							  
	CreateNative( "RGS_Request", Native_Request );
	CreateNative( "RGS_RequestH", Native_RequestH );
	CreateNative( "RGS_RequestS", Native_RequestS );
	CreateNative( "RGS_Connected", Native_Connected );
	
	RegPluginLibrary( "rxgservices" );
}

//-----------------------------------------------------------------------------
DoRequest( Handle:plugin, bool:simple, bool:front=false ) {
	
	// queue a response handler
	new info[RQ_SIZE];
	info[RQ_PLUGIN]  = _:plugin;
	info[RQ_HANDLER] = GetNativeCell(1);
	info[RQ_SIMPLE]  = simple;
	info[RQ_DATA]    = GetNativeCell(2);
	info[RQ_REQUEST] = INVALID_HANDLE;
	
	// format the request and send it.
	decl String:request[512];
	new written;
	FormatNativeString( 0, 3, 4, sizeof request, written, request );
	request[written] = '\n';
	request[written+1] = 0;
	
	if( g_connected ) {
		// send now.
		SendMessage2( request );
	} else {
		// queue.
		new Handle:pack = CreateDataPack();
		WritePackString( pack, request );
		info[RQ_REQUEST] = pack;
	}
	
	if( front ) {
		ShiftArrayUp( g_request_queue, 0 );
		SetArrayArray( g_request_queue, info );
	} else {
		PushArrayArray( g_request_queue, info ); 
	}
}

//-----------------------------------------------------------------------------
public Native_Request( Handle:plugin, numParams ) {
 
// queue the response until the service is connected.
// 
//	if( !g_connected && !g_connecting ) {
//		// not connected, give invalid response.
//		CallHandler( plugin, Function:GetNativeCell(1), true, 
//				INVALID_HANDLE, 0 );
//	}
	
	DoRequest( plugin, false );
}

//-----------------------------------------------------------------------------
public Native_RequestH( Handle:plugin, numParams ) {
 
	DoRequest( plugin, false, true );
}

//-----------------------------------------------------------------------------
public Native_RequestS( Handle:plugin, numParams ) {
//	if( !g_connected ) {
//		// not connected, give invalid response.
//		CallHandlerS( plugin, Function:GetNativeCell(1), true, "" );
//	}
	DoRequest( plugin, true );
}

//-----------------------------------------------------------------------------
public Native_Connected( Handle:plugin, numParams ) {
	return g_connected;
}
