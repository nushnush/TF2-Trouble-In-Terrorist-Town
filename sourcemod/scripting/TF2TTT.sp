#pragma semicolon 1

#define IsValidClient(%1) (1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsAdmin(%1) (CheckCommandAccess(%1, "", ADMFLAG_CHAT, true))
#define TAG "{green}[{default}TTT{green}]{default}"

#include <sourcemod>
#include <basecomm>
#include <morecolors>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>

#pragma newdecls required

ConVar g_Cvar_SetupTime;
ConVar g_Cvar_RoundTime;
ConVar g_Cvar_TraitorRatio;
ConVar g_Cvar_DetectiveRatio;
ConVar g_Cvar_CreditStart;
ConVar g_Cvar_KillInnoCredits;
ConVar g_Cvar_KillTraitorCredits;
ConVar g_Cvar_BodyFade;
ConVar g_Cvar_Delay;
ConVar g_Cvar_Chance;

enum Role
{
	NOROLE = 0,
	INNOCENT,
	TRAITOR,
	DETECTIVE
}

//char g_sDoorList[][] = { "func_door", "func_door_rotating", "func_movelinear" };
char g_sRoles[][] = { "NOROLE", "{lime}innocent{default}", "{fullred}traitor{default}", "{dodgerblue}detective{default}" };

ArrayList g_aForceTraitor;
ArrayList g_aForceDetective;

bool roundStarted;

float g_fStartSearchTime[MAXPLAYERS + 1];
float g_fLastSearch[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] Trouble In Terrorist Town", 
	author = "yelks", 
	description = "GMOD:TTT/CSGO:TTT Mod made for tf2", 
	version = "0.3 Beta", 
	url = "http://www.yelksdev.xyz/"
};

/* Forwards
==================================================================================================== */

#include "ttt/tttplayer.sp"
#include "ttt/shop.sp"
#include "ttt/setup.sp"
#include "ttt/buttons.sp"

public void OnPluginStart()
{
	AddServerTag("ttt");
	
	g_Cvar_SetupTime = CreateConVar("ttt_setuptime", "30", "Time in seconds to prepare before the ttt starts.", _, true, 5.0);
	g_Cvar_RoundTime = CreateConVar("ttt_roundtime", "240", "Round duration in seconds", _, true, 10.0, true, 900.0);
	g_Cvar_TraitorRatio = CreateConVar("ttt_traitor_ratio", "3", "1 Traitor out of every X players in the server", _, true, 2.0);
	g_Cvar_DetectiveRatio = CreateConVar("ttt_detective_ratio", "11", "1 Detective out of every X players in the server", _, true, 3.0);
	g_Cvar_CreditStart = CreateConVar("ttt_initialcredits", "3", "Initial amount of credits to start with.", _, true, 0.0);
	g_Cvar_KillInnoCredits = CreateConVar("ttt_kill_innocent_credits", "1", "Amount of credits to give traitors when killing a player", _, true, 0.0);
	g_Cvar_KillTraitorCredits = CreateConVar("ttt_kill_traitor_credits", "2", "Amount of credits to give innocents when killing a traitor", _, true, 0.0);
	g_Cvar_BodyFade = CreateConVar("ttt_bodyfade", "30.0", "Time in seconds until a body fades and cannot be scanned anymore.", _, true, 0.0);
	g_Cvar_Delay = CreateConVar("ttt_scan_delay", "90", "Delay for detectives to use their scanners.", _, true, 0.0);
	g_Cvar_Chance = CreateConVar("ttt_fake_chance", "20", "Chances of the scanners to fake results.", _, true, 0.0, true, 100.0);
	
	LoadTranslations("common.phrases");
	
	HookEvent("player_team", Event_PlayerTeamPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
	
	RegAdminCmd("sm_ttt_reloadconfig", Cmd_ReloadConfigs, ADMFLAG_CONFIG);
	RegConsoleCmd("sm_roles", Cmd_RoleShop);

	AddCommandListener(Listener_JoinTeam, "autoteam");
	AddCommandListener(Listener_JoinTeam, "jointeam");
	AddCommandListener(Listener_JoinClass, "joinclass");
	AddCommandListener(Listener_JoinClass, "join_class");
	
	CreateTimer(2.0, Timer_Hud, _, TIMER_REPEAT);
	
	hMap[0] = new StringMap();

	g_aForceTraitor = new ArrayList();
	g_aForceDetective = new ArrayList();
}

public void OnConfigsExecuted()
{
	FindConVar("mp_autoteambalance").SetInt(0);
	FindConVar("mp_teams_unbalance_limit").SetInt(0);

	Shop_Refresh();
}

public void OnMapStart()
{
	roundStarted = false;
	FF(false);
	SDKHook(FindEntityByClassname(MaxClients + 1, "tf_player_manager"), SDKHook_ThinkPost, ThinkPost);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_logic_arena") 
	|| StrEqual(classname, "tf_logic_koth")
	|| StrContains(classname, "tf_ammo") == 0
	|| StrContains(classname, "item_ammopack") == 0
	|| StrContains(classname, "item_healthkit") == 0)
	{
		RemoveEntity(entity);
	}
}

public void OnClientPutInServer(int client)
{
	delete hMap[client];
	hMap[client] = new StringMap();

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_GetMaxHealth, OnGetMaxHealth);
	
	TTTPlayer player = TTTPlayer(client);
	player.karma = 100;
	player.credits = g_Cvar_CreditStart.IntValue;
}

public void OnClientDisconnect_Post(int client)
{
	if(!roundStarted)
		return;

	int traitorCount = GetRoleCount(TRAITOR);
	int innoCount = GetRoleCount(INNOCENT);

	if (traitorCount == 0 && innoCount > 0)
	{
		CPrintToChatAll("%s Last traitor has disconnected, innocents won!", TAG);
		ForceTeamWin();
	}
	else if (innoCount == 0 && traitorCount > 0)
	{
		CPrintToChatAll("%s Last innocent has disconnected, traitors won!", TAG);
		ForceTeamWin();
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (condition == TFCond_Zoomed)
	{
		SetEntPropFloat(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_flChargedDamage", 150.0);
	}
}

/* Listeners
==================================================================================================== */

Action Listener_JoinTeam(int client, const char[] command, int args)
{
	if (!args && StrEqual(command, "jointeam", false))
		return Plugin_Handled;

	if (StrEqual(command, "autoteam", false))
		return Plugin_Handled;
	
	if (!IsValidClient(client))
		return Plugin_Continue;

	if (!roundStarted)
		return Plugin_Continue;
	
	CPrintToChat(client, "%s Please wait for the current round to end.", TAG);
	return Plugin_Handled;
}

Action Listener_JoinClass(int client, const char[] command, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	if (roundStarted)
	{
		CPrintToChat(client, "%s You cannot change class during the round.", TAG);
		return Plugin_Handled;
	}

	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));

	if (!StrEqual(arg, "soldier", false) && !StrEqual(arg, "pyro", false) && !StrEqual(arg, "heavyweapons", false))
	{
		TF2_SetPlayerClass(client, TFClass_Soldier);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

/* Cmds
==================================================================================================== */

public Action Cmd_ReloadConfigs(int client, int args)
{
	Shop_Refresh();
	return Plugin_Handled;
}

public Action Cmd_RoleShop(int client, int args)
{
	OpenShop(TTTPlayer(client));
	return Plugin_Handled;
}

/* Event Hooks
==================================================================================================== */

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers") || GetClientCount() < 2) 
		return;

	OpenDoors();
	RequestFrame(MakeRoundTimer);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			TF2_ChangeClientTeam(i, TFTeam_Red);
		}
	}
}

public void OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	StartTTT();
}

public Action Event_PlayerTeamPre(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
	if (!roundStarted)
		return Plugin_Continue;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!IsValidClient(victim))
		return Plugin_Continue;

	TTTPlayer pVictim = TTTPlayer(victim);

	int traitorCount = GetRoleCount(TRAITOR);
	int innoCount = GetRoleCount(INNOCENT);

	if (pVictim.role == INNOCENT)
		innoCount--;
	else if (pVictim.role == TRAITOR)
		traitorCount--;

	if (traitorCount == 0 && innoCount > 0)
	{
		CPrintToChatAll("%s All the traitors have died, and the innocents won!", TAG);
		ForceTeamWin();
	}
	else if (innoCount == 0 && traitorCount > 0)
	{
		CPrintToChatAll("%s The innocents have died, and the traitors won!", TAG);
		ForceTeamWin();
	}

	CreateTimer(0.0, CreateRagdoll, pVictim);

	TF2_ChangeClientTeam(victim, TFTeam_Spectator);

	if (!IsAdmin(victim))
		SetClientListeningFlags(victim, VOICE_MUTED);
	
	if (!IsValidClient(attacker) || attacker == victim)
		return Plugin_Handled;

	TTTPlayer pAttacker = TTTPlayer(attacker);
	pAttacker.killCount++;

	if(pAttacker.role == TRAITOR && pVictim.role != TRAITOR) // TRAITOR KILLS INNO/DET
	{
		pAttacker.credits += g_Cvar_KillInnoCredits.IntValue;

		if (pAttacker.killCount % 3 == 0)
		{
			CPrintToChat(attacker, "%s You can now use the {fullred}INSTANT KILL{default} with your melee weapon!", TAG);
		}
	}
	else if(pAttacker.role != TRAITOR && pVictim.role == TRAITOR) // INNO/DET KILLS TRAITOR
	{
		pAttacker.credits += g_Cvar_KillTraitorCredits.IntValue;
		pAttacker.karma += 20;

		if (pAttacker.karma > 110)
		{
			pAttacker.karma = 110;
		}	
	}
	else if (pAttacker.role != TRAITOR && pVictim.role != TRAITOR) // INNO/DET KILLS INNO/DET
	{
		pAttacker.karma -= 10;

		if (pAttacker.karma < 10)
		{
			pAttacker.karma = 10;
		}
	}
	
	return Plugin_Handled;
}

public void OnRoundEnd(const char[] output, int caller, int activator, float delay)
{
	ForceTeamWin();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			SetClientListeningFlags(i, VOICE_NORMAL);
			TTTPlayer(i).Reset();
		}
	}

	roundStarted = false;
	FF(false);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] message)
{
	if (!IsPlayerAlive(client) && !IsAdmin(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsPlayerAlive(i))
			{
				CPrintToChat(i, "*DEAD* {teamcolor}%N {default}: %s", client, message);
			}
		}
		return Plugin_Handled;
	}
	else if (StrEqual(command, "say_team") && IsPlayerAlive(client) && TTTPlayer(client).role == TRAITOR)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && TTTPlayer(i).role == TRAITOR)
			{
				CPrintToChat(i, "(TRAITOR) {red}%N {default}: %s", client, message);
			}
		}
		return Plugin_Handled;
	}
	else if (StrEqual(command, "say_team") && IsPlayerAlive(client) && TTTPlayer(client).role != TRAITOR)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Timer_Hud(Handle timer)
{
	Handle hHudRole = CreateHudSynchronizer();
	SetHudTextParams(0.7, 0.6, 1.9, 255, 255, 255, 255);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			TTTPlayer player = TTTPlayer(i);

			if (!roundStarted)
			{
				ShowSyncHudText(i, hHudRole, "Round pending");
			}
			else if (!IsPlayerAlive(i) && roundStarted)
			{
				ShowSyncHudText(i, hHudRole, "You are dead");
			}
			else if (player.role == TRAITOR)
			{
				char traitors[256];
				for (int j = 1; j <= MaxClients; j++)
				{
					if (IsValidClient(j) && TTTPlayer(j).role == TRAITOR && j != i)
					{
						Format(traitors, sizeof(traitors), "%s\n%N", traitors, j);
					}
				}

				ShowSyncHudText(i, hHudRole, "You are A TRAITOR\n%s%s", traitors[0] ? "Traitors Teammates:" : "", traitors);
			}
			else if (player.role == DETECTIVE)
			{
				ShowSyncHudText(i, hHudRole, "You are A DETECTIVE");
			}
			else if (player.role == INNOCENT)
			{
				ShowSyncHudText(i, hHudRole, "You are an innocent");
			}
		}
	}
	
	CloseHandle(hHudRole);
}

/* SDK Hooks
==================================================================================================== */

public void ThinkPost(int entity)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if(TF2_GetClientTeam(i) <= TFTeam_Spectator)
				SetEntProp(entity, Prop_Send, "m_iTeam", 2, _, i);

			SetEntProp(entity, Prop_Send, "m_bAlive", true, _, i);
			SetEntProp(entity, Prop_Send, "m_iTotalScore", 1, _, i);
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (roundStarted && IsValidClient(victim) && IsValidClient(attacker) && victim != attacker)
	{
		TTTPlayer pAttacker = TTTPlayer(attacker);
		TTTPlayer pVictim = TTTPlayer(victim);

		if (pAttacker.role == TRAITOR && IsMeleeActive(attacker) && pAttacker.killCount >= 3)
		{
			pAttacker.killCount -= 3;
			CPrintToChat(attacker, "%s You just used your INSTANT KILL.", TAG);
			damage = 9999.0;
			return Plugin_Changed;
		}
		
		if (/*g_hScanTimer[attacker] != null ||*/ (pVictim.role == DETECTIVE && pAttacker.role == DETECTIVE))
		{
			damage = 0.0;
			return Plugin_Changed;
		}	

		damage *= pAttacker.karma / 100.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action OnGetMaxHealth(int client, int &maxhealth)
{
	if (!IsValidClient(client)) 
		return Plugin_Continue;

	maxhealth = 200;
	return Plugin_Changed;
}

/* Functions
==================================================================================================== */

public Action CreateRagdoll(Handle timer, const TTTPlayer player)
{
	SpawnRagdoll(player, "deadbody");
}

stock void SpawnRagdoll(const TTTPlayer player, const char[] name)
{
	int client = player.index;
	int BodyRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (IsValidEdict(BodyRagdoll))
	{
		AcceptEntityInput(BodyRagdoll, "kill");
	}

	player.deathTime = GetGameTime();

	int ent = CreateEntityByName("prop_ragdoll");
	char m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
	DispatchKeyValue(ent, "model", m_ModelName);
	DispatchKeyValue(ent, "targetname", name);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	
	SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 1);
	AcceptEntityInput(ent, "EnableMotion");
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);

	float fOrigin[3];
	GetClientEyePosition(client, fOrigin); // not using abs position cause body can get stuck in the floor
	float fAngles[3];
	GetClientAbsAngles(client, fAngles);
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);

	TeleportEntity(ent, fOrigin, fAngles, fVelocity);

	char command[64];
	FormatEx(command, sizeof(command), "OnUser1 !self:kill::%0.1f:1", g_Cvar_BodyFade.FloatValue);
	SetVariantString(command);
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser1");
}

stock bool IsMeleeActive(int client)
{
	int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	return (weapon == melee);
}

stock void SetAmmo(int client, int iWeapon, int iAmmo)
{
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != -1) SetEntProp(client, Prop_Data, "m_iAmmo", iAmmo, _, iAmmoType);
}

stock int GetRoleCount(Role role, bool alive = true)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (TTTPlayer(i).role != role)
			continue;

		if (alive && !IsPlayerAlive(i))
			continue;

		count++;
	}
	return count;
}

stock void FakeDeath(int client, TFTeam team)
{
	int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	TF2_ChangeClientTeam(client, team);
	SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
}

stock void ForceTeamWin()
{
	int entity = FindEntityByClassname(MaxClients + 1, "team_control_point_master");
	
	if (entity == -1)
	{
		entity = CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	
	SetVariantInt(2);
	AcceptEntityInput(entity, "SetWinner");
}

public int RoleMenu(Menu menu, MenuAction action, int param1, int param2) {  }

/* Debug output
==================================================================================================== */

/*void DebugText(const char[] text, any ...) 
{
	int len = strlen(text) + 255;
	char[] format = new char[len];
	VFormat(format, len, text, 2);
	CPrintToChatAll("{collectors}[TTT Debug] {white}%s", format);
	PrintToServer("[TTT Debug] %s", format);
}*/