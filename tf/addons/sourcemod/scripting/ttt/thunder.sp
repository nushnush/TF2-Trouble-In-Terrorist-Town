
#define SOUND_THUNDER "ambient/explosions/explode_9.wav"

int g_SmokeSprite;
int g_LightningSprite;

void Thunder_OnMapStart()
{
	PrecacheSound(SOUND_THUNDER, true);
	g_SmokeSprite = PrecacheModel("sprites/steam1.vmt");
	g_LightningSprite = PrecacheModel("sprites/lgtning.vmt");
}

void PerformThunder(const TTTPlayer player, int target)
{
	int client = player.index;

	float fPosition[3];
	float fImpact[3];
	float fDifference[3];

	GetClientEyePosition(client, fPosition);
	GetClientAbsOrigin(target, fImpact);

	float fDistance = GetVectorDistance(fPosition, fImpact);
	float fPercent = (40.0 / fDistance);

	fDifference[0] = fPosition[0] + ((fImpact[0] - fPosition[0]) *fPercent);
	fDifference[1] = fPosition[1] + ((fImpact[1] - fPosition[1]) *fPercent) - 0.08;
	fDifference[2] = fPosition[2] + ((fImpact[2] - fPosition[2]) *fPercent);

	int color[4] = { 255, 255, 255, 255 };
	float dir[3];

	TE_SetupBeamPoints(fDifference, fImpact, g_LightningSprite, 0, 0, 0, 0.5, 20.0, 10.0, 0, 1.0, color, 3);
	TE_SendToAll();

	TE_SetupSparks(fImpact, dir, 5000, 1000);
	TE_SendToAll();

	TE_SetupEnergySplash(fImpact, dir, false);
	TE_SendToAll();

	TE_SetupSmoke(fImpact, g_SmokeSprite, 5.0, 10);
	TE_SendToAll();

	EmitSoundToAll(SOUND_THUNDER, _, _, SNDLEVEL_RAIDSIREN);

	ForcePlayerSuicide(target);
	player.killCount++;

	if (player.killCount == 1)
	{
		CPrintToChatAll("%s {fullred}WATCH OUT:{default} The %s is on a rampage! Shoot him to survive!", TAG, g_sRoles[THUNDER]);
		TF2_RemoveAllWeapons(client);

		float fPush[3];
		fPush[2] = 800.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fPush);
		CreateTimer(0.5, Freeze, client);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != client)
			{
				TF2_RemoveWeaponSlot(i, TFWeaponSlot_Primary);
				int wep = TTTPlayer(i).SpawnItem("tf_weapon_sniperrifle", 851, 1, 6, "308 ; 1.0 ; 297 ; 1.0 ; 305 ; 1.0");
				SetAmmo(i, wep, 1);
			}
		}
	}
}

Action Freeze(Handle hTimer, int client)
{
	SetEntityMoveType(client, MOVETYPE_NONE);
	return Plugin_Stop;
}

void Thunder_OnRunCmd(const TTTPlayer player, int button)
{
	int client = player.index;
	
	if (button == IN_ATTACK2)
	{
		int target = GetClientAimTarget(client);
		if (target == -1)
		{
			return;
		}

		PerformThunder(player, target);
	}
}