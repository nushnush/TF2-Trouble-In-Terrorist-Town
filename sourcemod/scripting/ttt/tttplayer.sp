StringMap hMap[MAXPLAYERS+1];

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

	public int SpawnWeapon(char[] name, int index, int level, int qual, const char[] att = NULL_STRING)
	{
		Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL);
		int client = this.index;

		TF2Items_SetClassname(hWeapon, name);
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
		int wep;
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier:
			{
				wep = this.SpawnWeapon("tf_weapon_shotgun_soldier", 10, 1, 0);
			}
			case TFClass_Pyro:
			{
				wep = this.SpawnWeapon("tf_weapon_shotgun_pyro", 12, 1, 0);
			}
			case TFClass_Heavy:
			{
				wep = this.SpawnWeapon("tf_weapon_shotgun_hwg", 11, 1, 0);
			}
			default: // because bots fuck up things
			{
				wep = this.SpawnWeapon("tf_weapon_shotgun_soldier", 10, 1, 0);
			}
		}
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
			panel.DrawItem("Open the Scoreboard to view the buy menu");
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
			FakeDeath(client, this.role == DETECTIVE ? TFTeam_Blue : TFTeam_Red);
		}
		else
		{
			TF2_ChangeClientTeam(client, this.role == DETECTIVE ? TFTeam_Blue : TFTeam_Red);
			TF2_RespawnPlayer(client);
		}
				
		TF2_RegeneratePlayer(client);
		this.GiveInitialWeapon();
		this.ShowRoleMenu();

		if (this.role == DETECTIVE)
		{
			TF2_AddCondition(client, TFCond_CritCola, TFCondDuration_Infinite);
		}
	}

	public void Reset()
	{
		int karma = this.karma;
		int credits = this.credits;

		this.hMap.Clear();

		this.karma = karma;
		this.credits = credits;
	}
};