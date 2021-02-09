# Chat Processor
Our version of chat processor that allows other plugins to interact with the chat features.

## Installation

You can install this plugin using our ingame package manager ([API](https://github.com/Eternar/API))

## Usage
```C#
public Action ECP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	Format(name, MAXLENGTH_NAME, "{red}%s", name);
	Format(message, MAXLENGTH_MESSAGE, "{blue}%s", message);
	return Plugin_Changed;
}
```
