#include <sourcemod>
#include <loghelper>

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

public Plugin:myinfo =
{
	name = "Logs.tf Stats",
	author = "Nikki",
	description = "Logs additional stats for logs.tf, similar to supstats",
	version = SOURCEMOD_VERSION,
	url = "http://logs.tf"
};

public OnPluginStart() {
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("player_spawn", Event_PlayerSpawned);
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_chargedeployed", Event_ChargeDeployed);
	HookEvent("player_chargedeployed", Event_ChargeDeployedPre, EventHookMode_Pre);
	
	AddGameLogHook(OnGameLog);
	
	LogMapLoad();
}

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
		LogPlyrPlyrEvent(client, attacker, "triggered", "damage", false, damageProps);
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
	g_bBlockLog = true;
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