#include <sourcemod>
#include <loghelper>

#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_VERSION "1.0.1"

#define UPDATER_URL "http://github.nikkii.us/logstats/master/updater.txt"

new Handle:g_hCvarVersion;
new Handle:g_hCvarAutoUpdate;
new Handle:g_hCvarSupStats;

// Emulate supplemental stats
new bool:g_bSupStats = false;
new bool:g_bBlockLog = false;

new String:g_aClasses[10][64] = {
	"undefined",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavyweapons",
	"pyro",
	"spy",
	"engineer"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin");
	MarkNativeAsOptional("ReloadPlugin");
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "Logs.tf Stats",
	author = "Nikki",
	description = "Logs additional stats for logs.tf, similar to supstats",
	version = PLUGIN_VERSION,
	url = "http://logs.tf"
};

public OnPluginStart() {
	g_hCvarVersion = CreateConVar("sm_logstats_version", PLUGIN_VERSION, "LogStats Version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarAutoUpdate = CreateConVar("sm_logstats_autoupdate", "1", "Enables/Disables Auto Update for LogStats", 0, true, 0.0, true, 1.0);
	g_hCvarSupStats = CreateConVar("sm_logstats_supstats", "0", "Enables/Disables Supplemental stats compat mode", 0, true, 0.0, true, 1.0);
	
	g_bSupStats = GetConVarBool(g_hCvarSupStats);
	
	HookConVarChange(g_hCvarSupStats, ConVarChange_SupStats);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("player_spawn", Event_PlayerSpawned);
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_chargedeployed", Event_ChargeDeployed);
	HookEvent("player_chargedeployed", Event_ChargeDeployedPre, EventHookMode_Pre);
	
	AddGameLogHook(OnGameLog);
	
	LogMapLoad();
}

public ConVarChange_SupStats(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_bSupStats = GetConVarBool(convar);
}

// Updater support
public OnAllPluginsLoaded() {
	CheckUpdater(LibraryExists("updater"));
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater"))
		CheckUpdater(true);
}

public OnLibraryRemoved(const String:name[]) {
	if(StrEqual(name, "updater"))
		CheckUpdater(false);
}
	
CheckUpdater(bool:hasUpdater = false) {
	if(hasUpdater && GetConVarBool(g_hCvarAutoUpdate)) {
		Updater_AddPlugin(UPDATER_URL);
		
		decl String:version[12];
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		SetConVarString(g_hCvarVersion, version);
	} else {
		SetConVarString(g_hCvarVersion, PLUGIN_VERSION);
	}
}

public Action:Updater_OnPluginChecking() {
	if(!GetConVarBool(g_hCvarAutoUpdate)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}

// Events

public Event_PlayerHealed(Handle:event, const String:name[], bool:dontBroadcast) {
	new healer = GetClientOfUserId(GetEventInt(event, "healer"));
	new patient = GetClientOfUserId(GetEventInt(event, "patient"));
	new amount = GetEventInt(event, "amount");
	
	decl String:healingProps[64];
	Format(healingProps, sizeof(healingProps), " (healing \"%d\")", amount);
	LogPlyrPlyrEvent(healer, patient, "triggered", "healed", false, healingProps);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(client != attacker && attacker != 0) {
		new damage = GetEventInt(event, "damageamount");
		decl String:damageProps[64];
		Format(damageProps, sizeof(damageProps), " (damage \"%d\")", damage);
		
		if(g_bSupStats) {
			// Supstats uses a player event, not player player.
			LogPlayerEvent(attacker, "triggered", "damage", false, damageProps);
		} else {
			LogPlyrPlyrEvent(attacker, client, "triggered", "damage", false, damageProps);
		}
	}
}

public Event_PlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast) {
	LogPlayerEvent(GetClientOfUserId(GetEventInt(event, "userid")), "spawned as", g_aClasses[GetEventInt(event, "class")]); 
}

public Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:item[64];
	GetEventString(event, "item", item, sizeof(item));
	
	LogPlayerEvent(client, "picked up item", item);
}

public Action:Event_ChargeDeployedPre(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!g_bSupStats) {
		g_bBlockLog = true;
	}
	return Plugin_Continue;
}

public Event_ChargeDeployed(Handle:event, const String:name[], bool:dontBroadcast) {
	if (g_bBlockLog) {
		g_bBlockLog = false;
		
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new target = GetClientOfUserId(GetEventInt(event, "targetid"));
		
		decl String:medigun[32];
		new weaponIndex = -1;
		
		new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if(IsValidEntity(entity)) {
			weaponIndex = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
		}
		
		switch(weaponIndex) {
			case 35: {
				Format(medigun, sizeof(medigun), "kritzkrieg");
			}
			case 411: {
				Format(medigun, sizeof(medigun), "quickfix");
			}
			case 998: {
				Format(medigun, sizeof(medigun), "vaccinator");
			}
			default: {
				Format(medigun, sizeof(medigun), "stock");
			}
		}
		
		decl String:chargeProps[64];
		Format(chargeProps, sizeof(chargeProps), " (medigun \"%s\")", medigun);
		LogPlyrPlyrEvent(client, target, "triggered", "chargedeployed", false, chargeProps);
	}
}

public Action:OnGameLog(const String:message[]) {
	if (g_bBlockLog)
		return Plugin_Handled;
	return Plugin_Continue;
}