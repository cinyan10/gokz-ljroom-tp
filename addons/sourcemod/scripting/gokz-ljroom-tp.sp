#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

Database g_DB = null;
char gS_CurrentMap[64];

public Plugin myinfo =
{
	name = "gokz-ljroom",
	author = "Evan (modified by ChatGPT)",
	description = "Teleport players to predefined LJ room positions based on the map",
	version = "2.1",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_lj", Command_LJ, "Teleports to the LJ room");
	RegConsoleCmd("sm_ljroom", Command_LJ, "Teleports to the LJ room");
	RegAdminCmd("sm_setlj", Command_SetLJ, ADMFLAG_GENERIC, "Set LJ room position for this map");
	RegAdminCmd("sm_deletelj", Command_DeleteLJ, ADMFLAG_GENERIC, "Delete LJ room for this map");
	RegAdminCmd("sm_dellj", Command_DeleteLJ, ADMFLAG_GENERIC, "Alias for sm_deletelj");

	SQL_DBConnect();
}

public void OnMapStart()
{
	GetCurrentMap(gS_CurrentMap, sizeof(gS_CurrentMap));
}

public Action Command_LJ(int client, int args)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM ljroom WHERE map = '%s'", gS_CurrentMap);
	g_DB.Query(SQL_GetLJ_Callback, sQuery, GetClientSerial(client));
	return Plugin_Handled;
}

public Action Command_SetLJ(int client, int args)
{
	float origin[3], angles[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
	GetClientEyeAngles(client, angles);

	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "REPLACE INTO ljroom VALUES('%s', %.2f, %.2f, %.2f, %.2f, %.2f);",
		gS_CurrentMap, origin[0], origin[1], origin[2], angles[0], angles[1]);
	g_DB.Query(SQL_SetLJ_Callback, sQuery, GetClientSerial(client));
	return Plugin_Handled;
}

public void SQL_SetLJ_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		LogError("[LJRoom] Failed to set LJ room: %s", error);
		return;
	}
	if (IsValidClient(client))
	{
		PrintToChat(client, "\x05[LJRoom]\x01 LJ room set successfully for this map.");
	}
}

public Action Command_DeleteLJ(int client, int args)
{
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM ljroom WHERE map = '%s'", gS_CurrentMap);
	g_DB.Query(SQL_DeleteLJ_Callback, sQuery, GetClientSerial(client));
	return Plugin_Handled;
}

public void SQL_DeleteLJ_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		LogError("[LJRoom] Deletion failed: %s", error);
		return;
	}
	if (IsValidClient(client))
	{
		PrintToChat(client, "\x05[LJRoom]\x01 LJ room deleted for this map.");
	}
}

public void SQL_GetLJ_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null || results.RowCount == 0)
	{
		if (IsValidClient(client))
		{
			PrintToChat(client, "\x05[LJRoom]\x01 This map does not have an LJ room configured.");
		}
		return;
	}

	float origin[3], angle[3];
	while (results.FetchRow())
	{
		origin[0] = results.FetchFloat(1);
		origin[1] = results.FetchFloat(2);
		origin[2] = results.FetchFloat(3);
		angle[0] = results.FetchFloat(4);
		angle[1] = results.FetchFloat(5);
	}

	if (IsValidClient(client))
	{
		TeleportEntity(client, origin, angle, NULL_VECTOR);
	}
}

void SQL_DBConnect()
{
	char error[256];
	g_DB = SQL_Connect("default", true, error, sizeof(error));

	if (g_DB == null)
	{
		SetFailState("[LJRoom] Failed to connect to database: %s", error);
		return;
	}

	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT name FROM sqlite_master WHERE type='table' AND name='ljroom';");
	g_DB.Query(SQL_CheckTableExist_Callback, sQuery);
}

public void SQL_CheckTableExist_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[LJRoom] Table check failed: %s", error);
		return;
	}

	if (!results.FetchRow())
	{
		// Table does not exist
		char sCreateQuery[256];
		FormatEx(sCreateQuery, sizeof(sCreateQuery), "CREATE TABLE ljroom (map TEXT PRIMARY KEY, x REAL, y REAL, z REAL, x1 REAL, y1 REAL);");
		g_DB.Query(SQL_CreateTableAndImport_Callback, sCreateQuery);
	}
}

public void SQL_CreateTableAndImport_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[LJRoom] Failed to create ljroom table: %s", error);
		return;
	}
	ImportLJRoomData();
}

void ImportLJRoomData()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/ljroom.csv");
	File file = OpenFile(path, "r");
	if (file == null)
	{
		LogError("[LJRoom] Failed to open ljroom.csv for import.");
		return;
	}

	char line[256];
	bool isFirstLine = true;
	while (!IsEndOfFile(file) && ReadFileLine(file, line, sizeof(line)))
	{
		TrimString(line);
		if (isFirstLine)
		{
			isFirstLine = false;
			continue;
		}

		char data[6][64];
		ExplodeString(line, ",", data, sizeof(data), sizeof(data[]));
		if (strlen(data[0]) < 1) continue;

		StripQuotes(data[0]);
		for (int i = 1; i < 6; i++) StripQuotes(data[i]);

		char sQuery[256];
		FormatEx(sQuery, sizeof(sQuery),
			"INSERT INTO ljroom VALUES('%s', %s, %s, %s, %s, %s);",
			data[0], data[1], data[2], data[3], data[4], data[5]);

		g_DB.Query(SQL_Import_Callback, sQuery);
	}
	CloseHandle(file);
}

public void SQL_Import_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[LJRoom] Import failed: %s", error);
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
