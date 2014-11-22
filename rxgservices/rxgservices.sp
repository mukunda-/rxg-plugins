 
#include <sourcemod>
#include <socket

#include <rxgservices>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "respawn",
	author = "mukunda",
	description = "respawn player",
	version = "1.0.0",
	url = "www.mukunda.com"
};

// the service connection
new Handle:g_socket = INVALID_HANDLE;
new bool:g_connecting = false;
new bool:g_connected = false;

new Handle:g_request_queue;

enum {
	RQ_PLUGIN,
	RQ_HANDLER, 
	RQ_SIZE
};

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
 * Send a message to the services.
 *
 * @param format Format of message.
 * @param ...    Formatted arguments.
 */
SendMessage( const char *format, any:... ) {
	decl String:request[256];
	new length = VFormat( request, sizeof request, format, 2 );
	SocketSend( g_socket, request, length+1 );
}

/** ---------------------------------------------------------------------------
 * Callback when a connection is established.
 */
public OnSocketConnected(Handle:socket, any:data ) {
	g_connected = true;
	g_connecting = false;
	
	decl String:game[32];
	GetGameFolderName( game, sizeof game );
	SendMessage( "HELLO rxg %s", game );
}

//-----------------------------------------------------------------------------
public OnSocketReceive( Handle:socket, String:receiveData[], 
						const dataSize, any:data ) {
	
	
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
