#include <sourcemod>
#include <sdktools>
#include <gokz/core>
#include <gokz/localdb>

#pragma semicolon 1
#pragma newdecls required

Database gH_DB = null;
char gS_CurrentMap[64];

public Plugin myinfo =
{
    name        = "gokz-ljroom-tp",
    author      = "Evan (modified by Cinyan10)",
    description = "Teleport players to predefined LJ room positions stored in GOKZ DB",
    version     = "2.2",
    url         = ""
};

// ──────────────────────────────────────────────────────────────────────────────
// Lifecycle
// ──────────────────────────────────────────────────────────────────────────────
public void OnPluginStart()
{
    RegConsoleCmd("sm_lj", Command_LJ, "Teleport to the LJ room");
    RegConsoleCmd("sm_ljroom", Command_LJ, "Teleport to the LJ room");
    RegAdminCmd("sm_setlj", Command_SetLJ, ADMFLAG_GENERIC, "Set LJ room position for this map");
    RegAdminCmd("sm_deletelj", Command_DeleteLJ, ADMFLAG_GENERIC, "Delete LJ room for this map");
    RegAdminCmd("sm_dellj", Command_DeleteLJ, ADMFLAG_GENERIC, "Alias for sm_deletelj");

    gH_DB = GOKZ_DB_GetDatabase();
    if (gH_DB == null)
    {
        CreateTimer(2.0, Timer_RetryDB, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        DB_EnsureTables();
    }
}

public void OnMapStart()
{
    GetCurrentMap(gS_CurrentMap, sizeof(gS_CurrentMap));
}

public Action Timer_RetryDB(Handle timer)
{
    if (gH_DB == null)
    {
        gH_DB = GOKZ_DB_GetDatabase();
        if (gH_DB == null) return Plugin_Continue;
        DB_EnsureTables();
    }
    return Plugin_Stop;
}

// ──────────────────────────────────────────────────────────────────────────────
// Commands
// ──────────────────────────────────────────────────────────────────────────────
public Action Command_LJ(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    if (gH_DB == null)
    {
        GOKZ_PrintToChat(client, true, "{red}The database is not ready yet. Please try again later.");
        return Plugin_Handled;
    }

    char query[256];
    FormatEx(query, sizeof(query),
        "SELECT x,y,z,pitch,yaw FROM LJRooms WHERE map_name = '%s' LIMIT 1;", gS_CurrentMap);
    SQL_TQuery(gH_DB, SQL_GetLJ_Callback, query, GetClientUserId(client));
    return Plugin_Handled;
}

public Action Command_SetLJ(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    if (gH_DB == null)
    {
        GOKZ_PrintToChat(client, true, "{red}The database is not ready yet. Please try again later.");
        return Plugin_Handled;
    }

    float origin[3], angles[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
    GetClientEyeAngles(client, angles);

    char query[512];
    FormatEx(query, sizeof(query),
        "INSERT INTO LJRooms (map_name,x,y,z,pitch,yaw) \
         VALUES ('%s', %.2f, %.2f, %.2f, %.2f, %.2f) \
         ON DUPLICATE KEY UPDATE x=VALUES(x), y=VALUES(y), z=VALUES(z), pitch=VALUES(pitch), yaw=VALUES(yaw);",
        gS_CurrentMap, origin[0], origin[1], origin[2], angles[0], angles[1]);

    SQL_TQuery(gH_DB, SQL_SetLJ_Callback, query, GetClientUserId(client));
    return Plugin_Handled;
}

public Action Command_DeleteLJ(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    if (gH_DB == null)
    {
        GOKZ_PrintToChat(client, true, "{red}The database is not ready yet. Please try again later.");
        return Plugin_Handled;
    }

    char query[256];
    FormatEx(query, sizeof(query),
        "DELETE FROM LJRooms WHERE map_name = '%s';", gS_CurrentMap);

    SQL_TQuery(gH_DB, SQL_DeleteLJ_Callback, query, GetClientUserId(client));
    return Plugin_Handled;
}

// ──────────────────────────────────────────────────────────────────────────────
// Callbacks
// ──────────────────────────────────────────────────────────────────────────────
public void SQL_SetLJ_Callback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client)) return;
    if (error[0])
    {
        LogError("[LJRoom] Failed to set LJ room: %s", error);
        GOKZ_PrintToChat(client, true, "{red}Failed to set LJ room.");
        return;
    }
    GOKZ_PrintToChat(client, true, "{lime}LJ room set successfully for this map.");
}

public void SQL_DeleteLJ_Callback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client)) return;
    if (error[0])
    {
        LogError("[LJRoom] Failed to delete LJ room: %s", error);
        GOKZ_PrintToChat(client, true, "{red}Failed to delete LJ room.");
        return;
    }
    GOKZ_PrintToChat(client, true, "{lime}LJ room deleted for this map.");
}

public void SQL_GetLJ_Callback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client)) return;

    if (error[0])
    {
        LogError("[LJRoom] Failed to load LJ room: %s", error);
        GOKZ_PrintToChat(client, true, "{red}Failed to load LJ room. Please try again later.");
        return;
    }

    if (results == null || !results.FetchRow())
    {
        GOKZ_PrintToChat(client, true, "{yellow}This map does not have an LJ room configured.");
        return;
    }

    float origin[3], angles[3];
    origin[0] = results.FetchFloat(0);
    origin[1] = results.FetchFloat(1);
    origin[2] = results.FetchFloat(2);
    angles[0] = results.FetchFloat(3);
    angles[1] = results.FetchFloat(4);
    angles[2] = 0.0;

    TeleportEntity(client, origin, angles, NULL_VECTOR);
    GOKZ_PrintToChat(client, true, "{lime}Teleported to LJ room.");
}

// ──────────────────────────────────────────────────────────────────────────────
// Database Setup
// ──────────────────────────────────────────────────────────────────────────────
void DB_EnsureTables()
{
    if (gH_DB == null) return;

    char createSql[512];
    strcopy(createSql, sizeof(createSql),
        "CREATE TABLE IF NOT EXISTS LJRooms ( \
            id INT UNSIGNED NOT NULL AUTO_INCREMENT, \
            map_name VARCHAR(64) NOT NULL, \
            x FLOAT NOT NULL, \
            y FLOAT NOT NULL, \
            z FLOAT NOT NULL, \
            pitch FLOAT NOT NULL, \
            yaw FLOAT NOT NULL, \
            PRIMARY KEY (id), \
            UNIQUE KEY uniq_map (map_name) \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
    );
    SQL_TQuery(gH_DB, DB_Generic_CB, createSql);
}

public void DB_Generic_CB(Database db, DBResultSet results, const char[] error, any data)
{
    if (error[0])
        LogError("[LJRoom] DB error: %s", error);
}
