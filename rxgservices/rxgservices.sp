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

//-----------------------------------------------------------------------------
new Handle:g_request_queue;

enum {
	RQ_PLUGIN,
	RQ_HANDLER,
	RQ_SIZE
};

#include "rgs/natives.sp"
	
//-----------------------------------------------------------------------------
public OnPluginStart() {  
	g_request_queue = CreateArray( RQ_SIZE );
	Connect(); 
} 

/** ---------------------------------------------------------------------------
 * Try to connect to the services.
 */
Connect() {
	if( g_connecting || g_connected ) return;
	g_connecting = true;
	g_socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(
		g_socket, OnSocketConnected, OnSocketReceive, 
		OnSocketDisconnected, "services.reflex-gamers.com", 12107 );
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
 * @param data    Data to pass to function.
 */
CallHandler( Handle:plugin, Function:handler, Handle:data ) {
	Call_StartFunction( plugin, handler );
	Call_PushCell( data );
	Call_Finish();
}

/** ---------------------------------------------------------------------------
 * Create a response datapack.
 */
CreateResponsePack() {
	if( g_response != INVALID_HANDLE ) CloseHandle(g_response);
	g_response = CreateDataPack();
}

/** ---------------------------------------------------------------------------
 * Create a response key-values.
 */
CreateResponseKV() {
	if( g_response != INVALID_HANDLE ) CloseHandle(g_response);
	g_response = CreateKeyValues( "Response" );
}

/** ---------------------------------------------------------------------------
 * Pop a response handler and call it.
 *
 * @param data    Data to pass to function.
 * @param close   Close the data handle.
 * @returns false on failure.
 */
bool:PopHandler( Handle:data = INVALID_HANDLE, bool:close = true ) {
	if( GetArraySize( g_request_queue ) == 0 ) {
		if( close ) CloseHandle(data);
		return false;
	}
	
	CallHandler( GetArrayCell( g_request_queue, 0, 0 ), 
				 GetArrayCell( g_request_queue, 0, 1 ), 
				 data );
				 
	RemoveFromArray( g_request_queue, 0 );
	if( close ) CloseHandle(data);
	return true;
}

/** ---------------------------------------------------------------------------
 * Send a message to the services.
 *
 * @param format Format of message.
 * @param ...    Formatted arguments.
 */
SendMessage( const String:format[], any:... ) {
	decl String:request[512];
	new length = VFormat( request, sizeof request, format, 2 );
	request[length] = '\n';
	request[length+1] = 0;
	SocketSend( g_socket, request );
}

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
	
	decl String:game[32];
	GetGameFolderName( game, sizeof game );
	SendMessage( "HELLO rxg %s", game );
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
		if( strncmp( data, "RT1: ", 5 ) == 0 ) {
			// RT1 TYPE RESPONSE
			
			new Handle:pack = CreateDataPack();
			WritePackString( pack, data[5] );
			return PopHandler( pack );
		} else if( strncmp( data, "RT2:", 4 ) == 0 ) {
			g_rstate = RS_RT2;
			CreateResponsePack();
		} else if( strncmp( data, "RT3:", 4 ) == 0 ) {
			g_rstate = RS_RT3;
			CreateResponseKV();
		}
	} else if( g_rstate == RS_RT2 ) {
		if( data[0] == ':' ) {
			// another line
			WritePackString( g_response, data );
		} else if( data[0] == 0 ) {
			// terminator
			g_rstate = RS_READY;
			return PopHandler( g_response );
		} else {
			// error.
			return false;
		}
	} else if( g_rstate == RS_RT3 ) {
		if( data[0] == 0 ) {
			// terminator
			g_rstate = RS_READY;
			return PopHandler( g_response );
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
		CloseHandle( socket ); // todo, wrap closehandle in a funciton that cleans up 
		                      // intermediate data.
		CreateTimer( 30.0, RetryConnect );
	}
}

//-----------------------------------------------------------------------------
public OnSocketDisconnected( Handle:socket, any:data ) {
	
	g_connecting = false;
	g_connected = false;
	LogError( "Disconnected from services." );
	CloseHandle( socket );
	CreateTimer( 15.0, RetryConnect );
}

//-----------------------------------------------------------------------------
public OnSocketError( Handle:socket, const errorType, 
					  const errorNum, any:data ) {
					  
	g_connecting = false;
	g_connected = false;
	LogError( "Socket error %d (errno %d)", errorType, errorNum );
	CloseHandle(socket);
	CreateTimer( 60.0, RetryConnect );
}
