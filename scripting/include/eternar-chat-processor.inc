#if defined _eternar_chat_processor_included_
    #endinput
#endif
#define _eternar_chat_processor_included_

#define MAX_TEMPLATE_LENGTH	32

/**
* Called before a chat message is sent, here the message is already processed.
*
* param sender			Author that sent the message.
* param receiver		receiver of the message.
* param template		Message's template.
* param buffer			Message's buffer.
* param maxlength		Max length of the buffer.
*
* return types
*  - Plugin_Continue	Continues the message.
*  - Plugin_Changed		Continues the message.
*  - Plugin_Handled		Stops the message.
*  - Plugin_Stop		Stops the message.
**/
forward Action ECP_OnChatMessageSendPre(int sender, int receiver, char[] template, char[] buffer, int maxlength);

/**
* Called while sending a chat message before It's sent.
* Limits on the name and message strings can be found above.
*
* param author			Author that created the message.
* param recipients		Array of clients who will receive the message.
* param msgtype			Determine the type of message.
* param name			Name of the author to be pushed.
* param message			Message from the author to be pushed.
* param processcolors	Toggle to process colors in the buffer strings.
* param removecolors	Toggle to remove colors in the buffer strings. (Requires bProcessColors = true)
*
* return types
*  - Plugin_Continue	Continues the message.
*  - Plugin_Changed		Fires the post-forward below and prints out a message.
*  - Plugin_Handled		Fires the post-forward below but doesn't print a message.
*  - Plugin_Stop		Stops the message.
**/
forward Action ECP_OnChatMessage(int& author, ArrayList recipients, char[] msgtype, char[] name, char[] message, bool & processcolors, bool & removecolors);

/**
* Called after the chat message is sent to the designated clients by the author.
*
* param author			Author that sent the message.
* param recipients		Array of clients who received the message.
* param msgtype			Determine the type of message.
* param template		Format used in the message based on the flag string.
* param name			Name of the author.
* param message			Message from the author.
* param processcolors	Check if colors were processed in the buffer strings.
* param removecolors	Check if colors were removed from the buffer strings.
*
* noreturn
**/
forward void ECP_OnChatMessagePost(int author, ArrayList recipients, const char[] msgtype, const char[] template, const char[] name, const char[] message, bool processcolors, bool removecolors);

public SharedPlugin __pl_eternar_chat_processor = 
{
	name = "Eternar Chat Processor",
	file = "Eternar/eternar_chatprocessor.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};