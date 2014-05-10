
#include <sourcemod>
#include <cURL>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = 
{
	name = "RXG Cycle",
	author = "mukunda",
	description = "Mapcycle plugin",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
};


//-------------------------------------------------------------------------------------------------
new CURLDefaultOpt[][2] = {
	{_:CURLOPT_NOSIGNAL,		1}, ///use for threaded only
	{_:CURLOPT_NOPROGRESS,		1},
	{_:CURLOPT_TIMEOUT,			30},
	{_:CURLOPT_CONNECTTIMEOUT,	60},
	{_:CURLOPT_VERBOSE,			0}
};

#define HTTP_RESPONSE_OK 200

//-------------------------------------------------------------------------------------------------
enum {
	MAPINFO_RESULT_ERROR,
	MAPINFO_RESULT_OKAY,
	MAPINFO_RESULT_NOTFOUND
};
//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "rxgcycle_test", Command_test );
	
}

//-------------------------------------------------------------------------------------------------
public Action:Command_test( client, args ) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof arg );
	new id = StringToInt(arg);
	Format( arg, sizeof arg, "%d", id );
	
	decl String:tempfile[256];
	BuildPath( Path_SM, tempfile, sizeof tempfile, "data/rxgcycle_map_query.txt" );
	
	new Handle:curl = curl_easy_init();
	curl_easy_setopt_int_array( curl, CURLDefaultOpt, sizeof( CURLDefaultOpt ) );


	new Handle:outfile = curl_OpenFile( tempfile, "wb" );
	curl_easy_setopt_string( curl, CURLOPT_URL, "http://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/?key=C82379571661D5229FC27E9164CC76CF&format=vdf" );
	curl_easy_setopt_handle( curl, CURLOPT_WRITEDATA, outfile );
	curl_easy_setopt_int( curl, CURLOPT_POST, 1 );
	new Handle:post = curl_httppost();
	
	curl_formadd( post, CURLFORM_COPYNAME, "itemcount", CURLFORM_COPYCONTENTS, "1", CURLFORM_END ); 
	curl_formadd( post, CURLFORM_COPYNAME, "publishedfileids[0]", CURLFORM_COPYCONTENTS, arg, CURLFORM_END ); 
	curl_easy_setopt_handle( curl, CURLOPT_HTTPPOST, post );
	
	new Handle:pack = CreateDataPack();
	WritePackCell( pack, _:outfile );
	WritePackString( pack, tempfile );
	curl_easy_perform_thread( curl, OnGetMapInfo, pack );
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnGetMapInfo( Handle:hndl, CURLcode:code, any:data ) {
	
	new Handle:file;
	decl String:tempfile[256]; 
	ResetPack(data);
	file = Handle:ReadPackCell(data);
	ReadPackString( data, tempfile, sizeof tempfile );
	CloseHandle(data);
	CloseHandle(file);
	
	new response;
	curl_easy_getinfo_int(hndl,CURLINFO_RESPONSE_CODE,response);
	CloseHandle(hndl);
	if( code != CURLE_OK || response != HTTP_RESPONSE_OK ) {
		PrintToChatAll( "ERROR GETTING MAPINFO" );
		return;
	}
	

	new Handle:result;
	response = ParseMapInfo( tempfile, result );
	if( response == MAPINFO_RESULT_ERROR ) {
		PrintToChatAll( "\x01 \x02 error" ); 
	}  else if( response == MAPINFO_RESULT_NOTFOUND ) {
		PrintToChatAll( "\x01 \x02 notfound" ); 
	} else {
		decl String:text[256];
		ReadPackString( result, text, sizeof text );
		Format( text, sizeof text, "TITLE: %s", text );
		PrintToChatAll( text );
	
		ReadPackString( result, text, sizeof text );
		Format( text, sizeof text, "DESC: %s", text );
		ReplaceString( text, sizeof text, "\r\n", "  " );
		ReplaceString( text, sizeof text, "\n", "  " );
		if( strlen( text ) > 100 ) {
			text[100] = 0;
			Format( text, sizeof text, "%s...", text );
		}
		PrintToChatAll( text );
		
		new size = ReadPackCell(result);
		new views = ReadPackCell(result);
		new favs = ReadPackCell(result);
		new subs = ReadPackCell(result);
		CloseHandle(result);
		
		FormatEx( text, sizeof text, "size=%d, views=%d, favs=%d, subs=%d", size, views, favs, subs );
		PrintToChatAll( text );
		
	}
	
}


//-------------------------------------------------------------------------------------------------
ParseMapInfo( const String:file[], &Handle:values ) {
	new Handle:kv = CreateKeyValues( "response" );
	
	if( !FileToKeyValues( kv, file ) ) { CloseHandle(kv); return MAPINFO_RESULT_ERROR; }
	if( KvGetNum( kv, "result" ) != 1 ) { CloseHandle(kv); return MAPINFO_RESULT_ERROR; }
	if( !KvJumpToKey( kv, "publishedfiledetails" ) ) { CloseHandle(kv); return MAPINFO_RESULT_ERROR; }
	if( !KvJumpToKey( kv, "0" ) ) { CloseHandle(kv); return MAPINFO_RESULT_ERROR; }
	
	new result = KvGetNum( kv, "result" );
	if( KvGetNum( kv, "banned" ) ) { CloseHandle(kv); return MAPINFO_RESULT_ERROR; }
	if( result == 9 ) { CloseHandle(kv); return MAPINFO_RESULT_NOTFOUND; }
	if( result != 1 ) { CloseHandle(kv); return MAPINFO_RESULT_ERROR; }
	
	
	
	values = CreateDataPack();
	decl String:text[256];
	KvGetString( kv, "title", text,sizeof text );
	WritePackString(values, text );
	KvGetString( kv, "description", text,sizeof text );
	WritePackString(values, text );
	WritePackCell(values, KvGetNum( kv, "file_size" ) );
	WritePackCell(values, KvGetNum( kv, "views" ) );
	WritePackCell(values, KvGetNum( kv, "favorited" ) );
	WritePackCell(values, KvGetNum( kv, "subscriptions" ) );
	CloseHandle(kv);
	ResetPack(values);
	
	return MAPINFO_RESULT_OKAY;
}

