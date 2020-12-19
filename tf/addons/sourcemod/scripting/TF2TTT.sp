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
#include <sendproxy>

#pragma newdecls required

enum struct TextNodeParam
{
	float fCoord_X;
	float fCoord_Y;
	float fHoldTime;
	int iRed;
	int iBlue;
	int iGreen;
	Handle hHud;

	void DisplayAll(const char[] text)
	{
		SetHudTextParams(this.fCoord_X, this.fCoord_Y, this.fHoldTime, this.iRed, this.iGreen, this.iBlue, 255);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				ShowSyncHudText(i, this.hHud, text);
			}
		}
	}

	void DisplayClient(int client, const char[] text)
	{
		SetHudTextParams(this.fCoord_X, this.fCoord_Y, this.fHoldTime, this.iRed, this.iGreen, this.iBlue, 255);
		ShowSyncHudText(client, this.hHud, text);
	}
}

enum Role
{
	NOROLE = 0,
	INNOCENT,
	DETECTIVE,
	TRAITOR,
	DISGUISER,
	NECROMANCER,
	PESTILENCE,
	THUNDER
}

enum RoundStatus
{
	Round_Inactive = -1,
	Round_Setup,
	Round_Active,
	Round_Ended
}

TextNodeParam huds[2];
RoundStatus g_eRound;

ConVar g_cvSetupTime;
ConVar g_cvRoundTime;
ConVar g_cvTraitorRatio;
ConVar g_cvDetectiveRatio;
ConVar g_cvCreditStart;
ConVar g_cvCreditsOnRound;
ConVar g_cvKillInnoCredits;
ConVar g_cvKillTraitorCredits;
ConVar g_cvBodyFade;
ConVar g_cvScannerDelay;
ConVar g_cvScannerChance;
ConVar g_cvDisguiseDelay;
ConVar g_cvEarthquakeDelay;
ConVar g_cvRespawnDelay;
ConVar g_cvInfectDelay;
ConVar g_cvExposeCount;
ConVar g_cvKarmaTraitor;
ConVar g_cvKarmaInno;

//char g_sDoorList[][] = { "func_door", "func_door_rotating", "func_movelinear" };
char g_sRoles[][] = { "NOROLE", "{lime}Innocent{default}", "{dodgerblue}Detective{default}", "{fullred}Traitor{default}", 
"{yellow}Disguiser{default}", "{mediumpurple}Necromancer{default}", "{black}Pestilence{default}", "{strange}Thunder{default}"};

ArrayList g_aForceTraitor;
ArrayList g_aForceDetective;

Handle g_hSDKCallEquipWearable;

float g_fStartSearchTime[MAXPLAYERS + 1];
float g_fLastAbility[MAXPLAYERS + 1];

int g_iLastTouched[MAXPLAYERS + 1];
int victimCount;

public Plugin myinfo = 
{
	name = "[TF2] Trouble In Terrorist Town", 
	author = "yelks", 
	description = "GMOD:TTT/CSGO:TTT Mod made for tf2", 
	version = "0.4.1 Beta", 
	url = "http://www.yelksdev.xyz/"
};

/* Forwards
==================================================================================================== */

#include "ttt/tttplayer.sp"
#include "ttt/shop.sp"
#include "ttt/disguiser.sp"
#include "ttt/necromancer.sp"
#include "ttt/pestilence.sp"
#include "ttt/thunder.sp"
#include "ttt/detective.sp"
#include "ttt/setup.sp"
#include "ttt/buttons.sp"

public void OnPluginStart()
{
	GameData hTF2 = new GameData("sm-tf2.games");
	if (!hTF2)
		SetFailState("This plugin is desgined for a TF2 dedicated server only.");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(hTF2.GetOffset("RemoveWearable") - 1); // Assume EquipWearable is always behind RemoveWearable
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallEquipWearable = EndPrepSDKCall();
	if (!g_hSDKCallEquipWearable)
		SetFailState("Failed to create call: CBasePlayer::EquipWearable");
		
	delete hTF2;
	
	g_cvSetupTime = CreateConVar("ttt_setup_time", "30", "Time in seconds to prepare before the ttt starts.", _, true, 5.0);
	g_cvRoundTime = CreateConVar("ttt_round_time", "240", "Round duration in seconds", _, true, 10.0, true, 900.0);
	g_cvTraitorRatio = CreateConVar("ttt_traitor_ratio", "3", "1 Traitor out of every X players in the server", _, true, 2.0);
	g_cvDetectiveRatio = CreateConVar("ttt_detective_ratio", "11", "1 Detective out of every X players in the server", _, true, 3.0);
	g_cvCreditStart = CreateConVar("ttt_initial_credits", "3", "Initial amount of credits to start with.", _, true, 0.0);
	g_cvCreditsOnRound = CreateConVar("ttt_credits_on_round", "2", "Amount of credits to give when round starts.", _, true, 0.0);
	g_cvKillInnoCredits = CreateConVar("ttt_kill_innocent_credits", "1", "Amount of credits to give traitors when killing a player", _, true, 0.0);
	g_cvKillTraitorCredits = CreateConVar("ttt_kill_traitor_credits", "2", "Amount of credits to give innocents when killing a traitor", _, true, 0.0);
	g_cvBodyFade = CreateConVar("ttt_body_fade", "30.0", "Time in seconds until a body fades and cannot be scanned anymore.", _, true, 0.0);
	g_cvScannerDelay = CreateConVar("ttt_scanner_delay", "90", "Delay for detectives to use their scanners.", _, true, 0.0);
	g_cvScannerChance = CreateConVar("ttt_scanner_chance", "20", "Chances of the scanners to fake results.", _, true, 0.0, true, 100.0);
	g_cvDisguiseDelay = CreateConVar("ttt_disguise_delay", "90", "Delay for disguisers to use their ability.", _, true, 0.0);
	g_cvEarthquakeDelay = CreateConVar("ttt_earthquake_delay", "90", "Delay for necromancers to use their earthquake ability.", _, true, 0.0);
	g_cvRespawnDelay = CreateConVar("ttt_respawn_delay", "999", "Delay for necromancers to use their respawn ability.", _, true, 0.0);
	g_cvInfectDelay = CreateConVar("ttt_infect_delay", "10", "Delay for pestilences to use their infect ability.", _, true, 0.0);
	g_cvExposeCount = CreateConVar("ttt_expose_count", "3", "Amount of victims required to expost the pestilence.", _, true, 0.0);
	g_cvKarmaTraitor = CreateConVar("ttt_karma_traitor", "20", "Karma given when you kill a traitor as an innocent.", _, true, 0.0);
	g_cvKarmaInno = CreateConVar("ttt_karma_innocent", "10", "Karma lost when you kill a innocent as an innocent.", _, true, 0.0);
	
	LoadTranslations("common.phrases");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
	
	RegAdminCmd("sm_ttt_reloadconfig", Cmd_ReloadConfigs, ADMFLAG_CONFIG);
	RegConsoleCmd("sm_roles", Cmd_RoleList);
	RegConsoleCmd("sm_shop", Cmd_Shop);

	AddCommandListener(Listener_JoinTeam, "autoteam");
	AddCommandListener(Listener_JoinTeam, "jointeam");
	AddCommandListener(Listener_JoinClass, "joinclass");
	AddCommandListener(Listener_JoinClass, "join_class");
	
	hMap[0] = new StringMap();
	g_aForceTraitor = new ArrayList(2);
	g_aForceDetective = new ArrayList();

	for (int i = 0; i < sizeof(huds); i++)
		huds[i].hHud = CreateHudSynchronizer();

	InitiateHuds();
}

public void OnConfigsExecuted()
{
	InsertServerTag("ttt");

	FindConVar("mp_autoteambalance").SetInt(0);
	FindConVar("mp_teams_unbalance_limit").SetInt(0);

	Shop_Refresh();
}

public void OnMapStart()
{
	SDKHook(FindEntityByClassname(MaxClients + 1, "tf_player_manager"), SDKHook_ThinkPost, PlayerManagerThink);

	Necromancer_OnMapStart();
	Thunder_OnMapStart();
	Detective_OnMapStart();

	CreateTimer(huds[0].fHoldTime + 0.1, Timer_Hud, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	g_eRound = Round_Inactive;
	FF(false);
}

public Action Timer_Hud(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			Role role = TTTPlayer(i).role;

			if (g_eRound != Round_Active)
			{
				huds[0].DisplayClient(i, "Round pending");
			}
			else if (!IsPlayerAlive(i) && g_eRound == Round_Active)
			{
				huds[0].DisplayClient(i, "You are dead");
			}
			else if (role >= TRAITOR)
			{
				if (role == PESTILENCE)
				{
					if (IsValidClient(g_iLastTouched[i]))
					{
						char text[128];
						FormatEx(text, sizeof(text), "Pestilence\nCurrent Victim: %N", g_iLastTouched[i]);
						huds[0].DisplayClient(i, text);
					}
					else
					{
						huds[0].DisplayClient(i, "Pestilence");
					}
				}
				else
				{
					huds[0].DisplayClient(i, "Traitor");
				}
			}
			else if (role == DETECTIVE)
			{
				huds[0].DisplayClient(i, "Detective");
			}
			else if (role == INNOCENT)
			{
				huds[0].DisplayClient(i, "Innocent");
			}
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_logic_arena") 
	|| StrEqual(classname, "tf_logic_koth")
	|| StrEqual(classname, "tf_dropped_weapon")
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
	player.credits = g_cvCreditStart.IntValue;
}

public void OnClientDisconnect(int client)
{
	SendProxy_Unhook(client, "m_bGlowEnabled", SendProxy_Glow);
}

public void OnClientDisconnect_Post(int client)
{
	if (g_eRound != Round_Active)
		return;

	int traitorCount = GetRoleCount(true);
	int innoCount = GetRoleCount(false);

	if (traitorCount == 0 && innoCount > 0)
	{
		CPrintToChatAll("%s Last traitor has disconnected, innocents won!", TAG);
		ForceTeamWin(2);
	}
	else if (innoCount == 0 && traitorCount > 0)
	{
		CPrintToChatAll("%s Last innocent has disconnected, traitors won!", TAG);
		ForceTeamWin(3);
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

public Action Listener_JoinTeam(int client, const char[] command, int args)
{
	if (!args && StrEqual(command, "jointeam", false))
		return Plugin_Handled;

	if (StrEqual(command, "autoteam", false))
		return Plugin_Handled;
	
	if (!IsValidClient(client))
		return Plugin_Continue;

	if (g_eRound != Round_Active) // it's ok to enter teams
		return Plugin_Continue;
	
	CPrintToChat(client, "%s Please wait for the current round to end.", TAG);
	return Plugin_Handled;
}

public Action Listener_JoinClass(int client, const char[] command, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	if (g_eRound == Round_Active)
	{
		CPrintToChat(client, "%s You cannot change class during the round.", TAG);
		return Plugin_Handled;
	}

	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));

	if (!StrEqual(arg, "soldier", false) && !StrEqual(arg, "pyro", false) && !StrEqual(arg, "heavyweapons", false))
	{
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

public Action Cmd_Shop(int client, int args)
{
	OpenShop(TTTPlayer(client));
	return Plugin_Handled;
}

public Action Cmd_RoleList(int client, int args)
{
	Menu menu = new Menu(Handler_RoleList);
	menu.SetTitle("[TTT] Meet The Roles:");
	menu.AddItem("Innocent", "Innocent");
	menu.AddItem("Detective", "Detective");
	menu.AddItem("Traitor", "Traitor");
	menu.AddItem("Disguiser", "Disguiser");
	menu.AddItem("Necromancer", "Necromancer");
	menu.AddItem("Pestilence", "Pestilence");
	menu.AddItem("Thunder", "Thunder");
	menu.Display(client, 30);
	return Plugin_Handled;
}

public int Handler_RoleList(Menu menu, MenuAction action, int client, int param2) 
{  
	if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if(StrEqual(info, "Innocent"))
		{
			TTTPlayer(client).ShowRoleMenu(INNOCENT);
		}
		else if(StrEqual(info, "Detective"))
		{
			TTTPlayer(client).ShowRoleMenu(DETECTIVE);
		}
		else if(StrEqual(info, "Traitor"))
		{
			TTTPlayer(client).ShowRoleMenu(TRAITOR);
		}
		else if(StrEqual(info, "Disguiser"))
		{
			TTTPlayer(client).ShowRoleMenu(DISGUISER);
		}
		else if(StrEqual(info, "Necromancer"))
		{
			TTTPlayer(client).ShowRoleMenu(NECROMANCER);
		}
		else if(StrEqual(info, "Pestilence"))
		{
			TTTPlayer(client).ShowRoleMenu(PESTILENCE);
		}
		else if(StrEqual(info, "Thunder"))
		{
			TTTPlayer(client).ShowRoleMenu(THUNDER);
		}
	}
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
			g_fLastAbility[i] = 0.0;
			TF2_ChangeClientTeam(i, TFTeam_Red);
			TF2_RespawnPlayer(i);
		}
	}
}

public void OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	StartTTT();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsValidClient(client))
	{
		return;
	}

	if (g_eRound == Round_Active)
	{
		ForcePlayerSuicide(client);
	}
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
	if (g_eRound != Round_Active)
		return Plugin_Continue;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!IsValidClient(victim))
		return Plugin_Continue;

	TTTPlayer pVictim = TTTPlayer(victim);

	int traitorCount = GetRoleCount(true);
	int innoCount = GetRoleCount(false);

	if (pVictim.role == INNOCENT)
		innoCount--;
	else if (pVictim.role >= TRAITOR)
		traitorCount--;

	if (traitorCount == 0 && innoCount > 0)
	{
		CPrintToChatAll("%s All the traitors have died, and the innocents won!", TAG);
		ForceTeamWin(2);
	}
	else if (innoCount == 0 && traitorCount > 0)
	{
		CPrintToChatAll("%s The innocents have died, and the traitors won!", TAG);
		ForceTeamWin(3);
	}

	CreateTimer(0.0, CreateRagdoll, pVictim);

	if (!IsAdmin(victim))
		SetClientListeningFlags(victim, VOICE_MUTED);

	victimCount++;
	
	if (!IsValidClient(attacker) || attacker == victim)
		return Plugin_Handled;

	TTTPlayer pAttacker = TTTPlayer(attacker);
	pAttacker.killCount++;

	pVictim.killerRole = pAttacker.role;

	if (pAttacker.role >= TRAITOR && pVictim.role < TRAITOR) // TRAITOR KILLS INNO/DET
	{
		pAttacker.credits += g_cvKillInnoCredits.IntValue;

		if (pAttacker.role == TRAITOR && pAttacker.killCount % 3 == 0)
		{
			CPrintToChat(attacker, "%s You can now use the {fullred}INSTANT KILL{default} with your melee weapon!", TAG);
		}
	}
	else if (pAttacker.role < TRAITOR && pVictim.role >= TRAITOR) // INNO/DET KILLS TRAITOR
	{
		pAttacker.credits += g_cvKillTraitorCredits.IntValue;
		pAttacker.karma += g_cvKarmaTraitor.IntValue;

		if (pAttacker.karma > 110)
		{
			pAttacker.karma = 110;
		}	
	}
	else if (pAttacker.role < TRAITOR && pVictim.role < TRAITOR) // INNO/DET KILLS INNO/DET
	{
		pAttacker.karma -= g_cvKarmaInno.IntValue;

		if (pAttacker.karma < 10)
		{
			pAttacker.karma = 10;
		}
	}
	
	return Plugin_Handled;
}

public void OnRoundEnd(const char[] output, int caller, int activator, float delay)
{
	CPrintToChatAll("%s The innocents remained alive, they win!", TAG);
	ForceTeamWin(2);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			TTTPlayer player = TTTPlayer(i);
			if (player.role >= TRAITOR)
			{
				CPrintToChatAll("%s {red}%N {default}(%s) has murdered {purple}%i{default} players.", TAG, i, g_sRoles[player.role], player.killCount);
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
			}

			SendProxy_Unhook(i, "m_bGlowEnabled", SendProxy_Glow);
			SetClientListeningFlags(i, VOICE_NORMAL);
			player.Reset();
		}
	}
	
	g_eRound = Round_Ended;
	FF(false);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] message)
{
	if (!IsPlayerAlive(client))
	{
		if (TTTPlayer(client).role == NECROMANCER && StrEqual(message, "respawn", false))
		{
			float now = GetEngineTime();
			if (g_fLastAbility[client] + g_cvRespawnDelay.IntValue - now > 0)
			{
				CPrintToChat(client, "%s Please wait %0.1f seconds before resurrecting members again.", TAG, g_cvRespawnDelay.IntValue - (now - g_fLastAbility[client]));
				return Plugin_Handled;
			}

			PerformResurrect();
			g_fLastAbility[client] = now;
			return Plugin_Handled;
		}

		if (!IsAdmin(client))
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
	}
	else if (StrEqual(command, "say_team") && IsPlayerAlive(client) && TTTPlayer(client).role >= TRAITOR)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && TTTPlayer(i).role >= TRAITOR)
			{
				CPrintToChat(i, "(TRAITOR) {red}%N {default}: %s", client, message);
			}
		}

		return Plugin_Handled;
	}
	else if (StrEqual(command, "say_team") && IsPlayerAlive(client) && TTTPlayer(client).role < TRAITOR)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/* SDK Hooks
==================================================================================================== */

public void PlayerManagerThink(int entity)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (TF2_GetClientTeam(i) <= TFTeam_Spectator)
			{
				SetEntProp(entity, Prop_Send, "m_iTeam", 2, _, i);
			}	

			SetEntProp(entity, Prop_Send, "m_bAlive", true, _, i);
			SetEntProp(entity, Prop_Send, "m_iTotalScore", 1, _, i);
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_eRound == Round_Active && IsValidClient(victim) && IsValidClient(attacker) && victim != attacker)
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

void InitiateHuds()
{
	huds[0].fCoord_X = -1.0;
	huds[0].fCoord_Y = 0.15;
	huds[0].fHoldTime = 0.9;
	huds[0].iRed = 255;
	huds[0].iGreen = 255;
	huds[0].iBlue = 255;

	huds[1].fCoord_X = 0.17;
	huds[1].fCoord_Y = 0.04;
	huds[1].fHoldTime = 0.1;
	huds[1].iRed = 255;
	huds[1].iGreen = 0;
	huds[1].iBlue = 0;
}

void InsertServerTag(const char[] tagToInsert)
{
	ConVar tags = FindConVar("sv_tags");
	char tagsText[256];
	// Insert server tag at end
	tags.GetString(tagsText, sizeof(tagsText));
	if (StrContains(tagsText, tagToInsert, true) == -1)
	{
		Format(tagsText, sizeof(tagsText), "%s,%s", tagsText, tagToInsert);
		tags.SetString(tagsText);
		// If failed, insert server tag at start
		tags.GetString(tagsText, sizeof(tagsText));
		if (StrContains(tagsText, tagToInsert, true) == -1)
		{
			Format(tagsText, sizeof(tagsText), "%s,%s", tagToInsert, tagsText);
			tags.SetString(tagsText);
		}
	}
}

Action CreateRagdoll(Handle timer, const TTTPlayer player)
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

	player.deathTime = GetEngineTime();

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
	FormatEx(command, sizeof(command), "OnUser1 !self:kill::%0.1f:1", g_cvBodyFade.FloatValue);
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

int GetRoleCount(bool traitor=true)
{
	int count = 0;
	
	if (traitor)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && TTTPlayer(i).role >= TRAITOR)
				count++;
		}
	}
	else 
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && TTTPlayer(i).role == INNOCENT)
				count++;
		}
	}
	
	return count;
}

void Swap(int client, TFTeam team)
{
	if (IsPlayerAlive(client))
	{
		int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		TF2_ChangeClientTeam(client, team);
		SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
	}
	else 
	{
		TF2_ChangeClientTeam(client, team);
		TF2_RespawnPlayer(client);
	}
}

void ForceTeamWin(int team)
{
	g_eRound = Round_Ended;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			Swap(i, (TTTPlayer(i).role >= TRAITOR) ? TFTeam_Blue : TFTeam_Red);
		}
	}

	int entity = FindEntityByClassname(MaxClients + 1, "team_control_point_master");

	if (entity == -1)
	{
		entity = CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}

	char command[64];
	FormatEx(command, sizeof(command), "OnUser1 !self:SetWinner:%i:0.5:1", team);
	SetVariantString(command);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
}

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