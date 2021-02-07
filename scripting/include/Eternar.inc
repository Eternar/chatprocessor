#if defined _Eternar_included_
    #endinput
#endif
#define _Eternar_included_

#define MAX_PLUGIN_NAME_LENTGH		32
#define MAX_DESCRIPTION_LENGTH		128
#define MAX_AUTHOR_LENGTH			64
#define MAX_PLUGIN_FILEPATH_LENGTH	(MAX_PLUGIN_NAME_LENTGH * 2)

#define GITHUB_REPOSITORY_LENGTH	100

#define Eternar_Available()			(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "Eternar_GetVersion") == FeatureStatus_Available)

enum LogLevel
{
    Debug = 0,
    Info,
    Warning,
    Error,
    Critical
}

/* Callback function that will be called when the plugin is started. */
typedef PluginStartedCallback = function void ();

/**
* Called when the API has loaded.
*
* @noreturn
**/
forward void Eternar_OnLoaded();

/**
* Called right before the API is unloaded.
*
* @noreturn
**/
forward void Eternar_OnUnloaded();

/**
* Called when a new Plugin is started using Eternar_StartPlugin(...)
*
* @noreturn
**/
forward void Eternar_OnPluginStarted();

/**
* Called when a Plugin is stopped using Eternar_StopPlugin()
*
* @noreturn
**/
forward void Eternar_OnPluginStopped();

/**
 * Returns the current API version
 *
 * @return			Current API Version.
*/
native int Eternar_GetVersion();

/**
 * Starts the current plugin.
 *
 * @param callback	Callback function that will be called when the plugin is started.
 *
 * @return			https://github.com/alliedmodders/sourcemod/blob/b14c18ee64fc822dd6b0f5baea87226d59707d5a/public/IPluginSys.h#L66-L106
*/
native PluginStatus Eternar_StartPlugin(PluginStartedCallback callback = INVALID_FUNCTION);

/**
 * Stops the current plugin.
 *
 * @noreturn
*/
native void Eternar_StopPlugin();

public SharedPlugin __pl_Eternar = 
{
	name = "Eternar API",
	file = "Eternar.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_Eternar_SetNTVOptional()
{
	MarkNativeAsOptional("Eternar_GetVersion");
	MarkNativeAsOptional("Eternar_StartPlugin");
	MarkNativeAsOptional("Eternar_StopPlugin");
}
#endif