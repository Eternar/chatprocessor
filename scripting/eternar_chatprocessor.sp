#include <sourcemod>
#include <multicolors>

#include <Eternar>
#include <eternar-chat-processor>

#define GetProtoStatus()	(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)

#pragma tabsize 0;
#pragma newdecls required;
#pragma semicolon 1;

enum ConVariables
{
	ConVar_Enabled = 0,
	ConVar_StripBypass,
	ConVar_StripColors,
	ConVar_AllChat,
	ConVar_DeadChat,
	ConVar_RestrictDeadChat,
	ConVar_GOTV,
	ConVar_Count
}

enum Forwards
{
	Forward_OnChatMessage_Pre = 0,
	Forward_OnChatMessage,
	Forward_OnChatMessage_Post,
	Forward_Count
}

GlobalForward GlobalForwards[Forward_Count];
ConVar ConsoleVariables[ConVar_Count];
EngineVersion GameEngine;
StringMap Templates;

bool g_bProtoBuf;
bool g_bMessage[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Chat Processor",
	author = "Eternar",
	description = "Manage Chat Features",
	version = "1.0.0",
	url = "https://github.com/Eternar/chatprocessor"
};

public void OnPluginStart()
{
	if(Eternar_Available() && Eternar_GetVersion() >= 100000)
	{
		Eternar_StartPlugin(OnPluginStarted);
	}
}

public void Eternar_OnLoaded()
{
	OnPluginStart();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("Eternar Chat Processor");
	GlobalForwards[Forward_OnChatMessage_Pre] 	= new GlobalForward("ECP_OnChatMessageSendPre", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String, Param_Cell);
	GlobalForwards[Forward_OnChatMessage] 		= new GlobalForward("ECP_OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_String, Param_CellByRef, Param_CellByRef);
	GlobalForwards[Forward_OnChatMessage_Post]	= new GlobalForward("ECP_OnChatMessagePost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public void OnPluginEnd()
{
	if(Eternar_Available())
		Eternar_StopPlugin();
}

public void OnPluginStarted()
{
	ConsoleVariables[ConVar_Enabled]			= CreateConVar("eternar_cp_enabled", "1", "Plugin Status");
	ConsoleVariables[ConVar_StripBypass]		= CreateConVar("eternar_cp_strip_bypass", "b", "Flag that bypass color strip | requires: eternar_cp_strip_colors 1");
	ConsoleVariables[ConVar_StripColors]		= CreateConVar("eternar_cp_strip_colors", "1", "Remove color codes from the name and the message before processing the output");
	ConsoleVariables[ConVar_AllChat]			= CreateConVar("eternar_cp_allchat", "0", "Allows both teams to communicate with each other through team chat");
	ConsoleVariables[ConVar_DeadChat]			= CreateConVar("eternar_cp_deadchat", "1", "Controls how dead communicate");
	ConsoleVariables[ConVar_RestrictDeadChat]	= CreateConVar("eternar_cp_deadchat_restrict", "0", "Restricts the chat for dead players entirely");
	ConsoleVariables[ConVar_GOTV]				= CreateConVar("eternar_cp_gotv_recipient", "1", "GOTV clients should receive the chat messages?");
	
	AutoExecConfig(true, "Eternar/eternar-chat-processor");
	LoadTranslations("common.phrases");

	GameEngine = GetEngineVersion();
	g_bProtoBuf = GetProtoStatus();
	Templates = new StringMap();

	char szGame[64];
	GetGameFolderName(szGame, sizeof(szGame));
	
	char szFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szFilePath, sizeof(szFilePath), "configs/Eternar/chat-processor.cfg");
	
	KeyValues kv = new KeyValues("ChatProcessor");

	if (kv.ImportFromFile(szFilePath) && kv.JumpToKey(szGame) && kv.GotoFirstSubKey(false))
	{
		Templates.Clear();
		
		char szKey[256];
		char szValue[256];

		do {
			kv.GetSectionName(szKey, sizeof(szKey));
			kv.GetString(NULL_STRING, szValue, sizeof(szValue));
			
			TrimString(szKey);
			Templates.SetString(szKey, szValue);
		} while (kv.GotoNextKey(false));
	} else LogError("Error parsing the flag message formatting config for game '%s'.", szGame);
	delete kv;
}

public void OnConfigsExecuted()
{
	UserMsg SayText2 = GetUserMessageId("SayText2");
	if(SayText2 == INVALID_MESSAGE_ID)
	{
		SetFailState("Unable to hook SayText2");
	}

	HookUserMessage(SayText2, OnSayText2, true);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(!ConsoleVariables[ConVar_Enabled].BoolValue)
		return Plugin_Continue;

	if (client > 0 && StrContains(command, "say") != -1)
		g_bMessage[client] = true;

	return Plugin_Continue;
}

public Action OnSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!ConsoleVariables[ConVar_Enabled].BoolValue)
		return Plugin_Continue;
	
	int author = g_bProtoBuf ? PbReadInt(msg, "ent_idx") : BfReadByte(msg);
	if(author <= 0)
		return Plugin_Continue;
	
	char szTemplate[MAX_TEMPLATE_LENGTH];
	if(g_bProtoBuf) PbReadString(msg, "msg_name", szTemplate, sizeof(szTemplate));
	else BfReadString(msg, szTemplate, sizeof(szTemplate));
	TrimString(szTemplate);

	char szFormat[MAX_BUFFER_LENGTH];
	Templates.GetString(szTemplate, szFormat, sizeof(szFormat));

	if(!szFormat[0]) Format(szFormat, sizeof(szFormat), "{1} : {2}");
	if(g_bMessage[author]) g_bMessage[author] = false;
	else if(reliable) return Plugin_Stop;

	char szName[MAX_NAME_LENGTH];
	if(g_bProtoBuf) PbReadString(msg, "params", szName, sizeof(szName), 0);
	else { if(BfGetNumBytesLeft(msg)) BfReadString(msg, szName, sizeof(szName)); }
	
	char szMessage[MAX_MESSAGE_LENGTH];
	if(g_bProtoBuf) PbReadString(msg, "params", szMessage, sizeof(szMessage), 1);
	else { if(BfGetNumBytesLeft(msg)) BfReadString(msg, szMessage, sizeof(szMessage)); }

	if(ConsoleVariables[ConVar_StripColors].BoolValue)
	{
		char szFlag[20];
		ConsoleVariables[ConVar_StripBypass].GetString(szFlag, sizeof(szFlag));

		if(!szFlag[0] || !CheckCommandAccess(author, NULL_STRING, ReadFlagString(szFlag), true))
		{
			CRemoveTags(szName, sizeof(szName));
			CRemoveTags(szMessage, sizeof(szMessage));
		}
	}

	ArrayList alRecipients = new ArrayList();

	int iTeam = GetClientTeam(author);
	bool bAllTalk = ConsoleVariables[ConVar_AllChat].BoolValue;
	bool bDeadTalk = ConsoleVariables[ConVar_DeadChat].BoolValue;
	bool bDeadRestrict = ConsoleVariables[ConVar_RestrictDeadChat].BoolValue;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || (!ConsoleVariables[ConVar_GOTV].BoolValue && (IsFakeClient(i) || IsClientSourceTV(i))))
			continue;

		int userId = GetClientUserId(i);
		if(alRecipients.FindValue(userId) == -1)
		{
			alRecipients.Push(userId);
			continue;
		}

		bool bAlive = IsPlayerAlive(i);
		if(bDeadRestrict && !bAlive)
			continue;

		if(!IsPlayerAlive(author) && !bDeadTalk && bAlive)
			continue;

		if(!bAllTalk && StrContains(szTemplate, "_All") == -1 && iTeam != GetClientTeam(i))
			continue;

		alRecipients.Push(userId);
	}

	bool bRemoveColors = false;
	bool bProcessColors = true;

	char szOriginalTemplate[MAX_TEMPLATE_LENGTH];
	strcopy(szOriginalTemplate, sizeof(szOriginalTemplate), szTemplate);

	char szOriginalName[MAX_NAME_LENGTH];
	strcopy(szOriginalName, sizeof(szOriginalTemplate), szName);

	char szOriginalMessage[MAX_MESSAGE_LENGTH];
	strcopy(szOriginalMessage, sizeof(szOriginalTemplate), szMessage);

	Call_StartForward(GlobalForwards[Forward_OnChatMessage]);
	Call_PushCellRef(author);
	Call_PushCell(alRecipients);
	Call_PushStringEx(szTemplate, sizeof(szTemplate), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(szName, sizeof(szName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(szMessage, sizeof(szMessage), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCellRef(bProcessColors);
	Call_PushCellRef(bRemoveColors);

	Action iResults;
	int error = Call_Finish(iResults);

	if (error != SP_ERROR_NONE)
	{
		delete alRecipients;
		ThrowNativeError(error, "Global Forward 'ECP_OnChatMessage' has failed to fire. [Error code: %i]", error);
		return Plugin_Continue;
	}

	if (!StrEqual(szTemplate, szOriginalTemplate))
	{
		strcopy(szTemplate, sizeof(szTemplate), szOriginalTemplate);
		
		szFormat[0] = '\0';
		Templates.GetString(szTemplate, szFormat, sizeof(szFormat));
		
		if (strlen(szFormat) == 0) FormatEx(szFormat, sizeof(szFormat), "{1} : {2}");
	}

	if (StrEqual(szOriginalName, szName)) Format(szName, sizeof(szName), "\x03%s", szName);
	if (StrEqual(szOriginalMessage, szMessage)) Format(szMessage, sizeof(szMessage), "\x01%s", szMessage);
	
	DataPack pack = new DataPack();
	pack.WriteCell(author);
	pack.WriteCell(alRecipients);
	pack.WriteString(szName);
	pack.WriteString(szMessage);
	pack.WriteString(szTemplate);
	pack.WriteCell(bProcessColors);
	pack.WriteCell(bRemoveColors);
	pack.WriteString(szFormat);
	pack.WriteCell(iResults);
	pack.WriteCell(bDeadRestrict);
	
	RequestFrame(Frame_OnChatMessage, pack);

	return Plugin_Stop;
}

public void Frame_OnChatMessage(DataPack pack)
{
	pack.Reset();

	int author = pack.ReadCell();
	ArrayList recipients = pack.ReadCell();

	char sName[MAX_NAME_LENGTH];
	pack.ReadString(sName, sizeof(sName));

	char sMessage[MAX_MESSAGE_LENGTH];
	pack.ReadString(sMessage, sizeof(sMessage));

	char sFlag[MAX_TEMPLATE_LENGTH];
	pack.ReadString(sFlag, sizeof(sFlag));

	bool bProcessColors = pack.ReadCell();
	bool bRemoveColors = pack.ReadCell();

	char sFormat[MAX_BUFFER_LENGTH];
	pack.ReadString(sFormat, sizeof(sFormat));

	Action iResults = pack.ReadCell();
	bool bRestrictDeadChat = pack.ReadCell();
	
	delete pack;

	if (bRestrictDeadChat) PrintToChat(author, "Dead chat is currently restricted.");

	char sBuffer[MAX_BUFFER_LENGTH];
	strcopy(sBuffer, sizeof(sBuffer), sFormat);

	if (iResults != Plugin_Changed && !bProcessColors || bRemoveColors) Format(sMessage, sizeof(sMessage), "\x03%s", sMessage);
	if (iResults == Plugin_Changed && bProcessColors) Format(sMessage, sizeof(sMessage), "\x01%s", sMessage);

	ReplaceString(sBuffer, sizeof(sBuffer), "{1}", sName);
	ReplaceString(sBuffer, sizeof(sBuffer), "{2}", sMessage);
	ReplaceString(sBuffer, sizeof(sBuffer), "{3}", "\x01");

	if (iResults == Plugin_Changed && bProcessColors)
	{
		CFormatColor(sBuffer, sizeof(sBuffer), author);
		if (GameEngine == Engine_CSGO) Format(sBuffer, sizeof(sBuffer), " %s", sBuffer);
	}

	if (iResults != Plugin_Stop)
	{
		int client;
		char sTempBuffer[MAX_BUFFER_LENGTH];
		
		for (int i = 0; i < recipients.Length; i++)
		{
			if ((client = GetClientOfUserId(recipients.Get(i))) > 0 && IsClientInGame(client))
			{
				strcopy(sTempBuffer, sizeof(sTempBuffer), sBuffer);
				
				Call_StartForward(GlobalForwards[Forward_OnChatMessage_Pre]);
				Call_PushCell(author);
				Call_PushCell(client);
				Call_PushStringEx(sFlag, sizeof(sFlag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushStringEx(sTempBuffer, sizeof(sTempBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCell(sizeof(sTempBuffer));
				
				int error = Call_Finish(iResults);
				
				if (error != SP_ERROR_NONE)
				{
					delete recipients;
					ThrowNativeError(error, "Global Forward 'CP_OnChatMessageSendPre' has failed to fire. [Error code: %i]", error);
					return;
				}
			
				if (iResults == Plugin_Stop || iResults == Plugin_Handled)
					continue;
				
				CPrintToChatEx(client, author, "%s", sTempBuffer);
			}
		}
	}

	Call_StartForward(GlobalForwards[Forward_OnChatMessage_Post]);
	Call_PushCell(author);
	Call_PushCell(recipients);
	Call_PushString(sFlag);
	Call_PushString(sFormat);
	Call_PushString(sName);
	Call_PushString(sMessage);
	Call_PushCell(bProcessColors);
	Call_PushCell(bRemoveColors);
	Call_Finish();
	delete recipients;
}