#define KAMEHAME_SOUND "ttt/kamehame.mp3"
#define HA_SOUND "ttt/ha.mp3"
#define CHARGE_TIME 7.2

#define TRANSFORM_SOUND "ttt/transformation.mp3"
#define TRANSFORM_TIME 6

#define DB_WIDTH_MODIFIER 1.28

bool g_bTransformed[MAXPLAYERS + 1];
static float g_fChargeTime[MAXPLAYERS + 1];
static Handle g_hTimerCharge[MAXPLAYERS + 1];
static Handle g_hTimerShoot[MAXPLAYERS + 1];
static Handle g_hSearch[MAXPLAYERS + 1];

static int g_iBeam;

void Detective_OnMapStart()
{
	AddFileToDownloadsTable("sound/ttt/transformation.mp3");
	AddFileToDownloadsTable("sound/ttt/kamehame.mp3");
	AddFileToDownloadsTable("sound/ttt/ha.mp3");

	PrecacheSound(TRANSFORM_SOUND, true);
	PrecacheSound(KAMEHAME_SOUND, true);
	PrecacheSound(HA_SOUND, true);

	g_iBeam = PrecacheModel("sprites/laser.vmt");
}

// Transformation

void Detective_Transform(const TTTPlayer player)
{
	int client = player.index;

	if (!IsPlayerAlive(client))
		return;

	if (g_bTransformed[client])
		return;

	Fade();
	EmitSoundToAll(TRANSFORM_SOUND, _, _, SNDLEVEL_RAIDSIREN);

	int ent = MaxClients + 1;
	int wearables[8], i;
	while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
		{
			wearables[i++] = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
			TF2_RemoveWearable(client, ent);
		}
	}

	for (int j = 0; j < i; j++)
	{
		player.SpawnItem("tf_wearable", wearables[j], 1, 0, "142 ; 15185211.0 ; 261 ; 15185211.0");
	}

	g_fChargeTime[client] = 0.0;
	g_bTransformed[client] = true;
}

void Fade()
{
	Handle hBf = StartMessageAll("Fade");

	if (hBf != INVALID_HANDLE)
	{
		BfWriteShort(hBf, 500); //actual duration of fade
		BfWriteShort(hBf, TRANSFORM_TIME * 500); //Holdtime
		BfWriteShort(hBf, 0x0001);
		BfWriteByte(hBf, 250);
		BfWriteByte(hBf, 250);
		BfWriteByte(hBf, 250);
		BfWriteByte(hBf, 255);
		EndMessage();
	}
}

// Super Jump

void Detective_SuperJump(int client)
{
	if (!(GetEntityFlags(client) & FL_ONGROUND))
		return;

	float eyePos[3], fwd[3];
	GetClientEyeAngles(client, eyePos);
	eyePos[0] = 0.0;

	GetAngleVectors(eyePos, fwd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fwd, fwd);
	ScaleVector(fwd, 400.0);	// Jump distance

	fwd[2] += 500.0;	// Jump height
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fwd);
}

// Kamehameha

void Detective_ChargeKame(int client)
{
	if (!g_bTransformed[client])
		return;

	if (g_hTimerCharge[client] != null || g_hTimerShoot[client] != null)
		return;

	EmitSoundToAll(KAMEHAME_SOUND, _, _, SNDLEVEL_RAIDSIREN);
	g_fChargeTime[client] = 0.0;
	g_hTimerCharge[client] = CreateTimer(0.1, Timer_Charge, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_Charge(Handle timer, int data)
{
	int client = GetClientOfUserId(data);

	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		g_hTimerCharge[client] = null;
		return Plugin_Stop;
	}

	if (g_fChargeTime[client] >= CHARGE_TIME)
	{
		g_hTimerCharge[client] = null;
		return Plugin_Stop;
	}

	float percentage = (g_fChargeTime[client] / CHARGE_TIME) * 100.0;
	char strProgressBar[128];

	for (int i = 0; i < percentage / 5; i++)
	{
		Format(strProgressBar, sizeof(strProgressBar), "%s█", strProgressBar);
	}

	char text[140];
	FormatEx(text, sizeof(text), "%.0f%%\n%s", percentage, strProgressBar);
	huds[1].DisplayClient(client, text);

	g_fChargeTime[client] += 0.1;
	return Plugin_Continue;
}

void ShootKamehameha(int client)
{
	EmitSoundToAll(HA_SOUND, _, _, SNDLEVEL_RAIDSIREN);
	g_fChargeTime[client] = 0.0;
	g_hTimerShoot[client] = CreateTimer(0.1, Timer_Beam, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_Beam(Handle timer, int data)
{
	int client = GetClientOfUserId(data);

	if (IsValidClient(client))
	{
		if (!IsPlayerAlive(client))
		{
			g_hTimerShoot[client] = null;
			return Plugin_Stop;
		}

		float fPosition[3];
		float fImpact[3];
		float fDifference[3];
		float eyeAngles[3];

		GetClientEyePosition(client, fPosition);
		GetClientEyeAngles(client, eyeAngles);
		Handle trace = TR_TraceRayFilterEx(fPosition, eyeAngles, MASK_ALL, RayType_Infinite, TraceFilterNotSelf, client);
		if (TR_DidHit(trace))
			TR_GetEndPosition(fImpact, trace);
		CloseHandle(trace);

		float fDistance = GetVectorDistance(fPosition, fImpact);
		float fPercent = (40.0 / fDistance);

		fDifference[0] = fPosition[0] + ((fImpact[0] - fPosition[0]) * fPercent);
		fDifference[1] = fPosition[1] + ((fImpact[1] - fPosition[1]) * fPercent) - 0.08;
		fDifference[2] = fPosition[2] + ((fImpact[2] - fPosition[2]) * fPercent);

		static int colorLayer4[4]; 
		static int colorLayer2[4]; 
		SetColorRGBA(colorLayer4, 40, 140, 165, 255);
		SetColorRGBA(colorLayer2,  (((colorLayer4[0] * 6) + (255 * 2)) / 8), (((colorLayer4[1] * 6) + (255 * 2)) / 8), (((colorLayer4[2] * 6) + (255 * 2)) / 8), 255);
		
		TE_SetupBeamPoints(fDifference, fImpact, g_iBeam, 0, 0, 0, 0.18, 
		DB_ClampBeamWidth(50 * DB_WIDTH_MODIFIER), DB_ClampBeamWidth(50 * DB_WIDTH_MODIFIER), 0, 0.5, colorLayer2, 3);
		
		TE_SendToAll();
		
		TE_SetupBeamPoints(fDifference, fImpact, g_iBeam, 0, 0, 0, 0.18, 
		DB_ClampBeamWidth(100 * DB_WIDTH_MODIFIER), DB_ClampBeamWidth(100 * DB_WIDTH_MODIFIER), 0, 0.5, colorLayer4, 3); // amp was 1.0, now 0.5 (plus 3 above)
		
		TE_SendToAll();

		static int counter[MAXPLAYERS+1];
		counter[client]++;

		if (counter[client] % 5 == 0)
		{
			int iBomb = CreateEntityByName("tf_generic_bomb");
			DispatchKeyValueVector(iBomb, "origin", fImpact);
			DispatchKeyValueFloat(iBomb, "damage", 500.0);
			DispatchKeyValueFloat(iBomb, "radius", 400.0);
			DispatchKeyValue(iBomb, "health", "1");
			DispatchKeyValue(iBomb, "explode_particle", "fireSmokeExplosion2");
			DispatchKeyValue(iBomb, "sound", SOUND_THUNDER);
			DispatchSpawn(iBomb);

			AcceptEntityInput(iBomb, "Detonate");
		} 

		if (counter[client] >= 15)
		{
			counter[client] = 0;
			g_hTimerShoot[client] = null;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

void SetColorRGBA(int color[4], int r, int g, int b, int a)
{
	color[0] = r;
	color[1] = g;
	color[2] = b;
	color[3] = a;
}

float DB_ClampBeamWidth(float w)
{
	return w > 128.0 ? 128.0 : w;
}

bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	return (entity == 0 && entityhit != entity);
}

// Scan Players

void PerformScan(int client)
{
	int target = GetClientAimTarget(client);
	if (target == -1)
	{
		return;
	}

	float now = GetEngineTime();
	if (g_fLastAbility[client] + g_cvScannerDelay.IntValue - now > 0)
	{
		CPrintToChat(client, "%s Please wait %0.1f seconds before using the scanner again.", TAG, g_fLastAbility[client] + g_cvScannerDelay.IntValue - now);
		return;
	}

	float pos[3], pos2[3];
	GetClientAbsOrigin(client, pos);
	GetClientAbsOrigin(target, pos2);
	if (GetVectorDistance(pos, pos2) >= 100.0)
	{
		return;
	}

	g_fStartSearchTime[client] = now;
	delete g_hSearch[client];
	g_hSearch[client] = CreateTimer(0.1, ScanPlayer, client, TIMER_REPEAT);
}

Action ScanPlayer(Handle timer, int client)
{
	if (g_hSearch[client] == null || TTTPlayer(client).role != DETECTIVE || !IsMeleeActive(client))
	{
		g_hSearch[client] = null;
		return Plugin_Stop;
	}

	int target = GetClientAimTarget(client);
	if (target == -1)
	{
		g_hSearch[client] = null;
		return Plugin_Stop;
	}

	float now = GetEngineTime();
	int progress = RoundToNearest(now - g_fStartSearchTime[client]);

	if (progress >= 5)
	{
		g_fLastAbility[client] = now;
		Role role = TTTPlayer(target).role;
		bool isTraitor = role >= TRAITOR;

		// default: 20% chance to fake results
		isTraitor = GetRandomInt(1, 100) <= g_cvScannerChance.IntValue ? !isTraitor : isTraitor;
		CPrintToChat(client, "%s %N is %s.", TAG, target, !isTraitor ? g_sRoles[INNOCENT] : g_sRoles[role]);
		g_hSearch[client] = null;
		return Plugin_Stop;
	}

	char szBuffer[32];
	int len = Format(szBuffer, sizeof(szBuffer), "[");
	for (int i = 0; i < 5; i++)
		len += Format(szBuffer[len], sizeof(szBuffer) - len, progress >= i ? "|" : "  ");
	Format(szBuffer[len], sizeof(szBuffer) - len, "]");

	SetHudTextParams(-1.0, 0.3, 0.1, 255, 255, 255, 255);
	ShowHudText(client, 5, "Scanning %N\n%s", target, szBuffer);
	ShowHudText(target, 5, "You are being scanned!\n%s", szBuffer);

	return Plugin_Continue;
}

// Events

void Detective_OnRunCmd(const TTTPlayer player, int button)
{
	int client = player.index;

	if (button == IN_USE)
	{
		if (!IsMeleeActive(client))
			return;

		PerformScan(player.index);
	}
	else if (button == IN_ATTACK2)
	{
		if (!g_bTransformed[client])
			Detective_Transform(player);
		else
			Detective_ChargeKame(client);
	}
	else if (button == IN_JUMP)
	{
		Detective_SuperJump(client);
	}
}

void Detective_OnRelease(int client, int button)
{
	if (button == IN_USE)
	{
		delete g_hSearch[client];
	}
	else if (button == IN_ATTACK2)
	{
		if (!g_bTransformed[client])
			return;

		delete g_hTimerCharge[client];
		delete g_hTimerShoot[client];

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				StopSound(i, SNDCHAN_AUTO, KAMEHAME_SOUND);
			}
		}

		if (g_fChargeTime[client] >= CHARGE_TIME && IsPlayerAlive(client))
		{
			ShootKamehameha(client);
		}
	}
}