#include <sourcemod>
#include <socket>
#include <rxgservices>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxgservices",
	author = "mukunda",
	description = "RXG Services Interface",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//-----------------------------------------------------------------------------
new String:g_buffer[4096];
new g_bufferpos = 0;

//-----------------------------------------------------------------------------
enum {
	RS_READY,
	RS_RT2,
	RS_RT3
};

new g_rstate          = RS_READY;
new Handle:g_response = INVALID_HANDLE;

//-----------------------------------------------------------------------------
// the service connection
new Handle:g_socket = INVALID_HANDLE;
new bool:g_connecting = false;
new bool:g_connected = false;

new Handle:rgs_password;
new Handle:rgs_address;
new Handle:rgs_port;

new Handle:g_ConnectedForward;

//-----------------------------------------------------------------------------
new Handle:g_request_queue;

enum {
	RQ_PLUGIN,
	RQ_HANDLER,
	RQ_SIMPLE,
	RQ_DATA,
	RQ_REQUEST,
	RQ_SIZE
};
//-----------------------------------------------------------------------------
// additional source files

#include "rgs/natives.sp"

//-----------------------------------------------------------------------------
public OnPluginStart() {  
	g_request_queue = CreateArray( RQ_SIZE ); 
	rgs_password = CreateConVar( "rgs_password", "", 
								 "RXG Services Password", FCVAR_PLUGIN );
	rgs_address = CreateConVar( "rgs_address", "", 
								 "RXG Services Address", FCVAR_PLUGIN );
	rgs_port = CreateConVar( "rgs_port", "12107", 
								 "RXG Services Port", FCVAR_PLUGIN );
	
	g_ConnectedForward = CreateGlobalForward( "RGS_OnConnected", ET_Ignore );
} 

//-----------------------------------------------------------------------------
public OnConfigsExecuted() {
	Connect();
}

/** ---------------------------------------------------------------------------
 * Try to connect to the services.
 */
Connect() {
	if( g_connecting || g_connected ) return;
	 
	decl String:address[256];
	new port;
	GetConVarString( rgs_address, address, sizeof address );
	port = GetConVarInt( rgs_port );
	if( address[0] == 0 || port == 0 ) return;
	
	g_connecting = true; 
	g_socket = SocketCreate(SOCKET_TCP, OnSocketError);
	 
	SocketConnect(
		g_socket, OnSocketConnected, OnSocketReceive, 
		OnSocketDisconnected, address, port );
}

/** ---------------------------------------------------------------------------
 * [TIMER] Retry the connection.
 */
public Action:RetryConnect( Handle:timer ) {
	Connect();
	return Plugin_Handled;
}

/** ---------------------------------------------------------------------------
 * Call a response handler.
 *
 * @param plugin  Plugin owning the handler.
 * @param handler Handler function.
 * @param resp    Response handle.
 * @param data    Userdata.
 * @param rtype   Response type.
 */
CallHandler( Handle:plugin, Function:handler, bool:error, 
			 Handle:resp, any:data, rtype ) {
			 
	if( handler == INVALID_FUNCTION ) return;
	Call_StartFunction( plugin, handler );
	Call_PushCell( error );
	Call_PushCell( resp );
	Call_PushCell( data );
	Call_PushCell( rtype );
	Call_Finish();
}
	
/** ---------------------------------------------------------------------------
 * Call a simple response handler.
 *
 * @param plugin  Plugin owning the handler.
 * @param handler Handler function.
 * @param resp    Response string.
 * @param data    Userdata.
 */
CallHandlerS( Handle:plugin, Function:handler, bool:error, 
			  String:data[], any:data ) {
			  
	if( handler == INVALID_FUNCTION ) return;
	Call_StartFunction( plugin, handler );
	Call_PushCell( error );
	Call_PushString( data );
	Call_PushCell( data );
	Call_Finish();
}

/** ---------------------------------------------------------------------------
 * Create a response datapack.
 */
CreateResponsePack() {
	CloseResponse();
	g_response = CreateDataPack();
}

/** ---------------------------------------------------------------------------
 * Create a response key-values.
 */
CreateResponseKV() {
	CloseResponse();
	g_response = CreateKeyValues( "Response" );
}

/** ---------------------------------------------------------------------------
 * Reset the response handle.
 */
CloseResponse() {
	if( g_response == INVALID_HANDLE ) return;
	CloseHandle( g_response );
	g_response = INVALID_HANDLE;
}

/** ---------------------------------------------------------------------------
 * Pop a response handler and call it.
 *
 * @param rtype   Response type.
 * @returns false on failure.
 */
bool:PopHandler( rtype ) {
	
	if( GetArraySize( g_request_queue ) == 0 ) {
		CloseResponse();
		return false;
	}
	
	decl handler[RQ_SIZE];
	GetArrayArray( g_request_queue, 0, handler );
	new Handle:h_plugin = Handle:handler[RQ_PLUGIN];
	new Function:h_function = Function:handler[RQ_HANDLER];
	new userdata = handler[RQ_DATA];
	if( handler[RQ_REQUEST] != INVALID_HANDLE ) {
		// this request never actually got sent. how depressing
		CloseHandle( handler[RQ_REQUEST] );
	}
	RemoveFromArray( g_request_queue, 0 );
	
	if( rtype == 0 || rtype == 1 || rtype == 2 ) {
		ResetPack( g_response );
	} else if( rtype == 3 ) {
		KvRewind( g_response );
	}
	
	if( h_function != INVALID_FUNCTION ) {
		
		if( handler[RQ_SIMPLE] ) {
		
			// 0 or 1, ERR or RT1, both are simple messages.
			if( rtype == 0 || rtype == 1 ) {
				decl String:text[4096]; 
				ReadPackString( g_response, text, sizeof text );
				CallHandlerS( h_plugin, h_function, 
							  rtype == 0, text, userdata );
			} else {  
				CallHandlerS( h_plugin, h_function, 
							  rtype == 0, "", userdata ); 
			}
		} else {
		
			CallHandler( h_plugin, h_function, rtype == 0, g_response, 
						 userdata, rtype );
		}
	} 
	 
	CloseResponse();
	return true;
}

/** ---------------------------------------------------------------------------
 * Pop all response handlers and send errors.
 *
 */
ResetResponseQueue() {
	while( GetArraySize(g_request_queue) > 0 ) {
		CreateResponsePack();
		WritePackString( g_response, "RESET An error occurred." );
		PopHandler(0);
	}
}

/** ---------------------------------------------------------------------------
 * Send a message to the services.
 *
 * @param format Format of message.
 * @param ...    Formatted arguments.
 */
 /*
SendMessage( const String:format[], any:... ) {
	decl String:request[512];
	new length = VFormat( request, sizeof request, format, 2 );
	request[length] = '\n';
	request[length+1] = 0;
	SocketSend( g_socket, request );
}*/

/** ---------------------------------------------------------------------------
 * Send a complete message to the services.
 *
 * @param message Message to send.
 */
SendMessage2( const String:message[] ) {
	SocketSend( g_socket, message );
}

/** ---------------------------------------------------------------------------
 * Callback when a connection is established.
 */
public OnSocketConnected(Handle:socket, any:data ) {
	g_connected = true;
	g_connecting = false;
	
	g_rstate = RS_READY;
	g_bufferpos = 0;

	decl String:pass[64];
	GetConVarString( rgs_password, pass, sizeof pass );
	if( pass[0] != 0 ) {
		decl String:game[32];
		GetGameFolderName( game, sizeof game );
		RGS_RequestH( INVALID_FUNCTION, "AUTH \"%s\" rxg %s", pass, game );
	}
	
	// flush queue
	FlushQueued();
	
	Call_StartForward(g_ConnectedForward);
	Call_Finish();
}

/** ---------------------------------------------------------------------------
 * Flush any waiting requests.
 */
FlushQueued() {
	for( new i = 0; i < GetArraySize( g_request_queue ); i++ ) {
		new Handle:rq = Handle:GetArrayCell( g_request_queue, i, RQ_REQUEST );
		if( rq != INVALID_HANDLE ) {
			decl String:request[512];
			ResetPack(rq);
			ReadPackString( rq, request, sizeof request );
			SendMessage2( request );
			CloseHandle( rq );
			SetArrayCell( g_request_queue, i, INVALID_HANDLE, RQ_REQUEST );
		}
	}
}

/** ---------------------------------------------------------------------------
 * Process a line from a response.
 *
 * @param data Line of response.
 * @returns true if successful, false if unexpected data was encountered and
 *          the stream should terminate.
 */
bool:HandleResponseLine( String:data[] ) {
	if( g_rstate == RS_READY ) {
		if( strncmp( data, "[RT1]", 5 ) == 0 ) {
		
			// in case the message is exactly "[RT1]" without a trailing space
			// extend the null terminator so we dont mess up below.
			if( data[5] == 0 ) data[6] = 0;
			
			// RT1 RESPONSE
			CreateResponsePack();
			WritePackString( g_response, data[6] );
			return PopHandler( 1 );
			
		} else if( strncmp( data, "[RT2]", 5 ) == 0 ) {
			// RT2 RESPONSE
			g_rstate = RS_RT2;
			CreateResponsePack();
			
		} else if( strncmp( data, "[RT3]", 5 ) == 0 ) {
			// RT3 RESPONSE
			g_rstate = RS_RT3;
			CreateResponseKV();
			
		} else if( strncmp( data, "[ERR]", 5 ) == 0 ) {
		
			// (see rt1)
			if( data[5] == 0 ) data[6] = 0;
			
			// ERR RESPONSE
			LogError( "Services error: %s", data );
			CreateResponsePack();
			WritePackString( g_response, data[6] );
			return PopHandler( 0 );
		}
	} else if( g_rstate == RS_RT2 ) {
		if( data[0] == ':' ) {
			// another line
			WritePackString( g_response, data );
		} else if( data[0] == 0 ) {
			// terminator
			g_rstate = RS_READY;
			return PopHandler( 2 );
		} else {
			// error. unexpected
			return false;
		}
	} else if( g_rstate == RS_RT3 ) {
		if( data[0] == 0 ) {
			// terminator
			g_rstate = RS_READY;
			return PopHandler( 3 );
		}
		
		new pos = FindCharInString( data, ':' );
		if( data[pos] == -1 ) return false;
		if( data[pos+1] != ' ' ) return false;
		data[pos] = 0;
		KvSetString( g_response, data, data[pos+2] );
	}
	return true;
}

/** ---------------------------------------------------------------------------
 * Process data received from the socket.
 *
 * @param data Data received from socket.
 * @param size Length of data.
 * @returns true if successful, false if the stream has become invalid and
 *          should be terminated.
 */
bool:ProcessRecv( String:data[], size ) {
	if( size == 0 ) return true;
	
	new end = -1;
	for( new i = 0; i < size; i++ ) {
		if( data[i] == '\n' ) {
			end = i;
			break;
		}
	}
	
	if( end == -1 ) {
		// delimiter not found ,buffer and wait for more data.
		strcopy( g_buffer[g_bufferpos], 
				 sizeof(g_buffer) - g_bufferpos, data );
		g_bufferpos += size;
		return true;
	} else {
		// delimiter found, copy the last part and process the line.
		if( end != 0 ) {
			data[end] = 0;
			strcopy( g_buffer[g_bufferpos], 
					 sizeof( g_buffer ) - g_bufferpos, data );
		}
		
		if( !HandleResponseLine( g_buffer ) ) {
			return false;
		}
		
		// rinse and repeat.
		g_bufferpos = 0;
		return ProcessRecv( data[(size+1)], size - (end+1) );
	}
}

//-----------------------------------------------------------------------------
public OnSocketReceive( Handle:socket, String:receiveData[], 
						const dataSize, any:data ) {
	
	if( !ProcessRecv( receiveData, dataSize ) ) {
		LogError( "Encountered a stream error." );
		Reconnect( 30.0 );
	}
}

//-----------------------------------------------------------------------------
Close() {
	// empty stack.
	g_connecting = false;
	g_connected = false;
	CloseHandle( g_socket );
	
	ResetResponseQueue();
}

/** ---------------------------------------------------------------------------
 * Close the socket and reconnect.
 *
 * @param delay Delay to wait before reconnecting.
 */
Reconnect( Float:delay = 0.0 ) {
	Close();
	CreateTimer( delay, RetryConnect );
}

//-----------------------------------------------------------------------------
public OnSocketDisconnected( Handle:socket, any:data ) {
	LogError( "Disconnected from services." );
	Reconnect( 15.0 );
}

//-----------------------------------------------------------------------------
public OnSocketError( Handle:socket, const errorType, 
					  const errorNum, any:data ) {
					  
	LogError( "Socket error %d (errno %d)", errorType, errorNum );
	Reconnect( 60.0 );
}
