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

StringMap hMap[MAXPLAYERS+1];

ConVar g_Cvar_SetupTime;
ConVar g_Cvar_RoundTime;
ConVar g_Cvar_TraitorRatio;
ConVar g_Cvar_DetectiveRatio;
ConVar g_Cvar_CreditStart;
ConVar g_Cvar_KillCredits;
ConVar g_Cvar_BodyFade;

enum Role
{
	NOROLE = 0,
	INNOCENT,
	TRAITOR,
	DETECTIVE
}

methodmap TTTPlayer
{
	public TTTPlayer(const int index)
	{
		return view_as< TTTPlayer >(index);
	}

	property int index 
	{
		public get()			{ return view_as< int >(this); }
	}

	property StringMap hMap
	{
		public get()			{ return hMap[this.index]; }
	}

	public any GetProp(const char[] key)
	{
		any val; 
		this.hMap.GetValue(key, val);
		return val;
	}
	public void SetProp(const char[] key, any val)
	{
		this.hMap.SetValue(key, val);
	}
	public float GetPropFloat(const char[] key)
	{
		float val; 
		this.hMap.GetValue(key, val);
		return val;
	}
	public void SetPropFloat(const char[] key, float val)
	{
		this.hMap.SetValue(key, val);
	}
	/*public int GetPropString(const char[] key, char[] buffer, int maxlen)
	{
		return this.hMap.GetString(key, buffer, maxlen);
	}
	public void SetPropString(const char[] key, const char[] val)
	{
		this.hMap.SetString(key, val);
	}
	public void GetPropArray(const char[] key, any[] buffer, int maxlen)
	{
		this.hMap.GetArray(key, buffer, maxlen);
	}
	public void SetPropArray(const char[] key, const any[] val, int maxlen)
	{
		this.hMap.SetArray(key, val, maxlen);
	}*/

	property Role role
	{
		public get() 				{ return this.GetProp("role"); }
		public set( const Role i )	{ this.SetProp("role", i); }
	}

	property int killCount
	{
		public get() 				{ return this.GetProp("killCount"); }
		public set( const int i )	{ this.SetProp("killCount", i); }
	}

	property int credits
	{
		public get() 				{ return this.GetProp("credits"); }
		public set( const int i )	{ this.SetProp("credits", i); }
	}

	property int karma
	{
		public get() 				{ return this.GetProp("karma"); }
		public set( const int i )	{ this.SetProp("karma", i); }
	}

	property float deathTime
	{
		public get() 				{ return this.GetPropFloat("deathTime"); }
		public set( const float i )	{ this.SetPropFloat("deathTime", i); }
	}

	public int SpawnWeapon(const char[] name, int index, int level, int qual, const char[] att = NULL_STRING)
	{
		Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL);
		int client = this.index;
		char weaponClassname[64];
		strcopy(weaponClassname, sizeof(weaponClassname), name);
		if (StrContains(weaponClassname, "tf_weapon_shotgun") > -1)
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Heavy: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_hwg");
				case TFClass_Soldier: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_soldier");
				case TFClass_Pyro: strcopy(weaponClassname, sizeof(weaponClassname), "tf_weapon_shotgun_pyro");
			}
		}
		TF2Items_SetClassname(hWeapon, weaponClassname);
		TF2Items_SetItemIndex(hWeapon, index);
		TF2Items_SetLevel(hWeapon, level);
		TF2Items_SetQuality(hWeapon, qual);
		
		char atts[32][32];
		int count = ExplodeString(att, " ; ", atts, 32, 32);
		if (att[0]) 
		{
			TF2Items_SetNumAttributes(hWeapon, count / 2);
			int i2 = 0;
			for (int i = 0; i < count; i += 2) 
			{
				TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
				i2++;
			}
		}
		else TF2Items_SetNumAttributes(hWeapon, 0);

		int entity = TF2Items_GiveNamedItem(client, hWeapon);
		SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", true);
		delete hWeapon;
		EquipPlayerWeapon(client, entity);
		return entity;
	}

	public void GiveInitialWeapon()
	{
		int client = this.index;
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		int wep = this.SpawnWeapon("tf_weapon_shotgun_soldier", 10, 1, 6);
		SetAmmo(client, wep, 16);
	}

	public void ShowRoleMenu()
	{
		Panel panel = new Panel();
		panel.SetTitle("[TF2] Trouble In Terrorist Town:");
		
		if (this.role == INNOCENT)
		{
			panel.DrawItem("You are an innocent.");
			panel.DrawItem("Survive the to win the round!");
			panel.DrawItem("Killing innocents as an innocent lowers your karma, which lowers your damage.");
		}
		else if (this.role == TRAITOR)
		{
			panel.DrawItem("You are A TRAITOR.");
			panel.DrawItem("Kill all the innocents without dying!");
			panel.DrawItem("You can see who your fellow traitors are.");
			panel.DrawItem("Open the Secoreboard to view the buy menu");
		}
		else if (this.role == DETECTIVE)
		{
			panel.DrawItem("You are A DETECTIVE!");
			panel.DrawItem("Kill all the traitors without dying!");
			panel.DrawItem("Killing innocents as an innocent lowers your karma, which lowers your damage.");
		}
		else
		{
			panel.DrawItem("You don't have a role.");
			panel.DrawItem("Wait for the current round to end!");
		}

		panel.DrawItem("Press Reload to inspect a body.");
		panel.Send(this.index, RoleMenu, 15);
		delete panel;
	}

	public void Setup()
	{
		int client = this.index;
		if (IsPlayerAlive(client))
		{
			int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
			SetEntProp(client, Prop_Send, "m_lifeState", 2);
			TF2_ChangeClientTeam(client, this.role == DETECTIVE ? TFTeam_Blue : TFTeam_Red);
			SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
		}
		else
		{
			TF2_ChangeClientTeam(client, this.role == DETECTIVE ? TFTeam_Blue : TFTeam_Red);
			TF2_RespawnPlayer(client);
		}
				
		TF2_SetPlayerClass(client, TFClass_Soldier);
		TF2_RegeneratePlayer(client);
		this.GiveInitialWeapon();
		this.ShowRoleMenu();
		this.credits = g_Cvar_CreditStart.IntValue;

		if (this.role == DETECTIVE)
		{
			TF2_AddCondition(client, TFCond_CritCola, TFCondDuration_Infinite);
		}
	}

	public void Reset()
	{
		int karma = this.karma;
		this.hMap.Clear();
		this.karma = karma;
	}
};

char g_sDoorList[][] = { "func_door", "func_door_rotating", "func_movelinear" };
char g_sRoles[][] = { "NOROLE", "{lime}innocent{default}", "{fullred}traitor{default}", "{dodgerblue}detective{default}" };

bool roundStarted;

/*float g_fStartSearchTime[MAXPLAYERS + 1];
float g_fLastSearch[MAXPLAYERS + 1];*/
float g_fLastMessage[MAXPLAYERS + 1];

//Handle g_hScanTimer[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] Trouble In Terrorist Town", 
	author = "yelks", 
	description = "GMOD:TTT/CSGO:TTT Mod made for tf2", 
	version = "0.1 Beta", 
	url = "http://www.yelksdev.xyz/"
};

/* Forwards
==================================================================================================== */

#include "ttt/shop.sp"
#include "ttt/setup.sp"

public void OnPluginStart()
{
	AddServerTag("ttt");

	/*g_Cvar_Delay = CreateConVar("ttt_scan_delay", "90", "Delay for detectives to use their scanners.", _, true, 0.0);
	g_Cvar_Chance = CreateConVar("ttt_fake_chance", "20", "Chances of the scanners to fake results.", _, true, 0.0, true, 100.0);*/
	g_Cvar_SetupTime = CreateConVar("ttt_setuptime", "30", "Time in seconds to prepare before the ttt starts.", _, true, 5.0);
	g_Cvar_RoundTime = CreateConVar("ttt_roundtime", "240", "Round duration in seconds", _, true, 10.0);
	g_Cvar_TraitorRatio = CreateConVar("ttt_traitor_ratio", "3", "1 Traitor out of every X players in the server", _, true, 2.0);
	g_Cvar_DetectiveRatio = CreateConVar("ttt_detective_ratio", "11", "1 Detective out of every X players in the server", _, true, 3.0);
	g_Cvar_CreditStart = CreateConVar("ttt_initialcredits", "3", "Initial amount of credits to start with.", _, true, 0.0);
	g_Cvar_KillCredits = CreateConVar("ttt_killcredits", "1", "Amount of credits to give traitors when killing a player", _, true, 0.0);
	g_Cvar_BodyFade = CreateConVar("ttt_bodyfade", "30.0", "Time in seconds until a body fades and cannot be scanned anymore.", _, true, 0.0);
	
	LoadTranslations("common.phrases");
	
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
	
	RegAdminCmd("sm_ttt_reloadconfig", Cmd_ReloadConfigs, ADMFLAG_CONFIG);

	AddCommandListener(Listener_JoinTeam, "autoteam");
	AddCommandListener(Listener_JoinTeam, "jointeam");
	AddCommandListener(Listener_JoinClass, "joinclass");
	AddCommandListener(Listener_JoinClass, "join_class");
	
	CreateTimer(2.0, Timer_Hud, _, TIMER_REPEAT);
	
	hMap[0] = new StringMap();
}

public void OnConfigsExecuted()
{
	FindConVar("mp_autoteambalance").SetInt(0);

	Shop_Refresh();
}

public void OnMapStart()
{
	roundStarted = false;
	
	FF(false);

	SDKHook(FindEntityByClassname(-1, "tf_player_manager"), SDKHook_ThinkPost, ThinkPost);
}

public void ThinkPost(int entity)
{
	int arr[MAXPLAYERS + 1] = { 1, ... };
	SetEntDataArray(entity, FindSendPropInfo("CTFPlayerResource", "m_bAlive"), arr, MAXPLAYERS + 1);
	SetEntDataArray(entity, FindSendPropInfo("CTFPlayerResource", "m_iTotalScore"), arr, MAXPLAYERS + 1);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_logic_arena") 
	|| StrEqual(classname, "tf_logic_koth")
	|| StrContains(classname, "tf_ammo") > -1 
	|| StrContains(classname, "item_ammopack") > -1 
	|| StrContains(classname, "item_healthkit") > -1)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public void OnClientPutInServer(int client)
{
	delete hMap[client];
	hMap[client] = new StringMap();

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	TTTPlayer(client).karma = 100;
}

public void OnClientDisconnect_Post(int client)
{
	if (!roundStarted)
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

	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));

	if (!StrEqual(arg, "soldier", false))
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

/* Event Hooks
==================================================================================================== */

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers")) 
		return;

	OpenDoors();
	RequestFrame(MakeRoundTimer);
}

public void OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	StartTTT();
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
	if (!roundStarted)
		return Plugin_Continue;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!IsValidClient(victim))
		return Plugin_Continue;

	TTTPlayer player = TTTPlayer(victim);

	int traitorCount = GetRoleCount(TRAITOR);
	int innoCount = GetRoleCount(INNOCENT);

	if(player.role == INNOCENT)
		innoCount--;
	else if(player.role == TRAITOR)
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

	CreateTimer(0.0, CreateRagdoll, player);

	if (!IsAdmin(victim))
		SetClientListeningFlags(victim, VOICE_MUTED);
	
	if (!IsValidClient(attacker) || attacker == victim)
		return Plugin_Handled;

	Role victimRole = player.role;
	player = TTTPlayer(attacker);
	player.killCount++;
	player.credits += g_Cvar_KillCredits.IntValue;

	if (player.role != TRAITOR)
	{
		if (victimRole != TRAITOR)
		{
			player.karma -= 10;

			if (player.karma < 10)
			{
				player.karma = 10;
			}	
		}
		else 
		{
			player.karma += 10;

			if (player.karma > 110)
			{
				player.karma = 110;
			}	
		}
	}
	else if (player.role == TRAITOR && player.killCount == 3)
	{
		CPrintToChat(attacker, "%s You can now use the {fullred}INSTANT KILL{default} with your melee weapon!", TAG);
	}
	
	return Plugin_Handled;
}

public void OnRoundEnd(const char[] output, int caller, int activator, float delay)
{
	ForceTeamWin();
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
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

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (roundStarted && IsValidClient(victim) && IsValidClient(attacker) && victim != attacker)
	{
		TTTPlayer pAttacker = TTTPlayer(attacker);
		TTTPlayer pVictim = TTTPlayer(victim);

		if (pAttacker.role == TRAITOR && IsMeleeActive(attacker) && pAttacker.killCount >= 3)
		{
			pAttacker.killCount = 0;
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

/* Scanner & Shop
==================================================================================================== */

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!roundStarted || !IsPlayerAlive(client) || TF2_GetClientTeam(client) <= TFTeam_Spectator)
		return Plugin_Continue;
	
	if (buttons & IN_RELOAD)
	{
		int target = GetClientAimTarget(client, false);
		if (target == -1) 
			return Plugin_Continue;

		char name[64];
		GetEntPropString(target, Prop_Data, "m_iName", name, sizeof(name));

		if (StrEqual(name, "deadbody") || StrEqual(name, "fakebody"))
		{
			float now = GetGameTime();
			if (now - g_fLastMessage[client] > 1) // Prevent spam
			{
				TTTPlayer player = TTTPlayer(GetEntPropEnt(target, Prop_Data, "m_hOwnerEntity"));
				CPrintToChat(client, "%s {community}%N{default} was %s and died %0.1f seconds ago.", TAG, player.index, g_sRoles[player.role], now - player.deathTime);
				g_fLastMessage[client] = now;
			}
		}
		else if (StrEqual(name, "explosivebody"))
		{
			float origin[3];
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", origin); // Position of the body

			int iBomb = CreateEntityByName("tf_generic_bomb");
			DispatchKeyValueVector(iBomb, "origin", origin);
			DispatchKeyValueFloat(iBomb, "damage", 500.0);
			DispatchKeyValueFloat(iBomb, "radius", 500.0);
			DispatchKeyValue(iBomb, "health", "1");
			DispatchKeyValue(iBomb, "explode_particle", "fireSmokeExplosion2");
			DispatchKeyValue(iBomb, "sound", "vo/null.mp3");
			DispatchSpawn(iBomb);
			AcceptEntityInput(iBomb, "Detonate");
			
			AcceptEntityInput(target, "Kill");	
		}

		return Plugin_Continue;
	}
	else 
	{
		TTTPlayer player = TTTPlayer(client);
		if (buttons & IN_SCORE && player.role == TRAITOR)
		{
			OpenShop(player);
		}
	}
	
	return Plugin_Continue;
}

/* Functions
==================================================================================================== */

public Action CreateRagdoll(Handle timer, const TTTPlayer player)
{
	SpawnRagdoll(player, "deadbody");
}

void SpawnRagdoll(const TTTPlayer player, const char[] name)
{
	int client = player.index;
	int BodyRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (IsValidEdict(BodyRagdoll))
	{
		AcceptEntityInput(BodyRagdoll, "kill");
	}

	player.deathTime = GetGameTime();

	int ent = CreateEntityByName("prop_ragdoll");
	DispatchKeyValue(ent, "model", "models/player/soldier.mdl");
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

bool IsMeleeActive(int client)
{
	int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	return (weapon == melee);
}

void SetAmmo(int client, int iWeapon, int iAmmo)
{
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != -1) SetEntProp(client, Prop_Data, "m_iAmmo", iAmmo, _, iAmmoType);
}

/*int GetMaxAmmo(int client, int iWeapon)
{
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != -1) return GetEntProp(client, Prop_Data, "m_iAmmo", _, iAmmoType);
	return -1;
}*/

int GetRoleCount(Role role, bool alive = true)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (TTTPlayer(i).role != role)
			continue;

		if(alive && !IsPlayerAlive(i))
			continue;

		count++;
	}
	return count;
}

void ForceTeamWin()
{
	int entity = FindEntityByClassname(-1, "team_control_point_master");
	
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