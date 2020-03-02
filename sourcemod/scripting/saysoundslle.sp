/* put the line below after all of the includes!
#pragma newdecls required
*/

#pragma semicolon 1
#pragma dynamic 65536

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <kento_csgocolors>
#include <chat-processor>

float g_lastplay[MAXPLAYERS + 1];
Handle g_listkv = INVALID_HANDLE;
Handle  g_Cookie_SaysoundVol = INVALID_HANDLE;
float g_fSaysoundVolume[MAXPLAYERS + 1];

public Plugin myinfo =
{
  name        = "SaysoundsLLE",
  author      = "k725, Kento",
  description = "Saysounds(Lite Lite Edition)",
  version     = "1.4.0",
  url         = ""
};

public void OnPluginStart()
{
  g_Cookie_SaysoundVol = RegClientCookie("saysound_vol", "Opt in or out of Saysound", CookieAccess_Private);
  RegConsoleCmd("sm_saysound", SetSaysoundEnabled, "Opt in or out of Saysounds");

  LoadTranslations("saysoundslle.phrases");

  for(int i = 1; i <= MaxClients; i++)
	{ 
		if(IsValidClient(i) && !IsFakeClient(i) && !AreClientCookiesCached(i))	OnClientCookiesCached(i);
	}
}

public void OnPluginEnd()
{
  Handles_Close();
}

public void OnClientConnected(int client) {
  if (IsFakeClient(client)) {
      return;
  }
  g_fSaysoundVolume[client] = 0.0;

  /* enable playing by default for quickplayers */
  char  connect_method[5];
  GetClientInfo(client, "cl_connectmethod", connect_method, sizeof(connect_method));
  if (strncmp("quick", connect_method, 5, false) == 0 ||
      strncmp("match", connect_method, 5, false) == 0) {
      g_fSaysoundVolume[client] = 0.0;
  }
}

public void OnMapStart()
{
  for (int index = 1; index <= MAXPLAYERS; index++) 
    g_lastplay[index] = 0.0;

  Handles_Close();

  char cfgfile[PLATFORM_MAX_PATH + 1];
  char filelocation[PLATFORM_MAX_PATH + 1];
  char filelocationFake[PLATFORM_MAX_PATH + 1];

  BuildPath(Path_SM, cfgfile, sizeof(cfgfile), "configs/saysounds.cfg");

  if(FileExists(cfgfile))
  {
    g_listkv = CreateKeyValues("Sound Combinations");
    FileToKeyValues(g_listkv, cfgfile);
    KvRewind(g_listkv);

    if (KvGotoFirstSubKey(g_listkv))
    {
      do {
        filelocation[0] = '\0';

        KvGetString(g_listkv, "file", filelocation, sizeof(filelocation), "");

        if (filelocation[0] != '\0')
        {
          Format(filelocationFake, sizeof(filelocationFake), "*%s", filelocation);
          Format(filelocation, sizeof(filelocation), "sound/%s", filelocation);

          AddFileToDownloadsTable(filelocation);
          AddToStringTable(FindStringTable("soundprecache"), filelocationFake);
        }
      } while (KvGotoNextKey(g_listkv));
    }
  }
}

public void OnMapEnd()
{
  Handles_Close();
}

public void OnClientAuthorized(int client, const char[] auth)
{
  if(client != 0)
    g_lastplay[client] = 0.0;
}


public void OnClientCookiesCached(int client) {
    char  buffer[11];
    GetClientCookie(client, g_Cookie_SaysoundVol, buffer, sizeof(buffer));
    if (strlen(buffer) > 0) {
        g_fSaysoundVolume[client] = StringToFloat(buffer);
        PrintToChat(client, "%s  %.2f", buffer, g_fSaysoundVolume[client]);
    }
}

bool ClientHasSaysoundEnabled(int client) {
    return g_fSaysoundVolume[client] > 0.0;
}

public Action SetSaysoundEnabled(int client, int args) {
  if (IsValidClient(client) && !IsFakeClient(client))
  {
    Menu vol_menu = new Menu(VolMenuHandler);
    
    char menutitle[64];
    Format(menutitle, sizeof(menutitle), "%T", "Vol Menu Title", client);
    vol_menu.SetTitle(menutitle);
    
    char mute[64];
    Format(mute, sizeof(mute), "%T", "Mute", client);
    
    vol_menu.AddItem("0", mute);
    vol_menu.AddItem("0.2", "20%");
    vol_menu.AddItem("0.4", "40%");
    vol_menu.AddItem("0.6", "60%");
    vol_menu.AddItem("0.8", "80%");
    vol_menu.AddItem("1.0", "100%");
    vol_menu.Display(client, 0);
  }
}

public int VolMenuHandler(Menu menu, MenuAction action, int client,int param)
{
  if(action == MenuAction_Select)
  {
    char vol[1024];
    GetMenuItem(menu, param, vol, sizeof(vol));
    
    g_fSaysoundVolume[client] = StringToFloat(vol);
    CPrintToChat(client, "%T", "Volume", client, g_fSaysoundVolume[client]);
    
    SetClientCookie(client, g_Cookie_SaysoundVol, vol);
  }
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
  char filelocation[PLATFORM_MAX_PATH + 1];
  char filelocationFake[PLATFORM_MAX_PATH + 1];
  char text[64];
  float thetime = GetGameTime();

  if (g_listkv != INVALID_HANDLE) 
  {
    KvRewind(g_listkv);

    if (KvJumpToKey(g_listkv, message)) {
      KvGetString(g_listkv, "file", filelocation, sizeof(filelocation));
      KvGetString(g_listkv, "text", text, sizeof(text));
      if (filelocation[0] != '\0') {
        if (g_lastplay[author] < thetime) {
            if (message[0] && IsValidClient(author)) {
                g_lastplay[author] = thetime + 1.5;
                Format(filelocationFake, sizeof(filelocationFake), "*%s", filelocation);
                for (int i = 1; i <= MaxClients; i++) {
                    if (IsValidClient(i) && !IsFakeClient(i) && ClientHasSaysoundEnabled(i) && FindValueInArray(recipients, GetClientUserId(i)) != -1) {
                      EmitSoundToClient(i, filelocationFake, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, g_fSaysoundVolume[i]);
                      if(!StrEqual(text, "")) Format(message, MAXLENGTH_MESSAGE, "%s", text);
                    }
                }
            }
        } else
        CPrintToChat(author, "%T", "Cooldown");
      }
    }
  }

  return Plugin_Changed;
}

static bool IsValidClient(int client)
{
  if (client == 0 || !IsClientConnected(client) || IsFakeClient(client) || !IsClientInGame(client))
    return false;

  return true;
}

static Handles_Close()
{
  if (g_listkv != INVALID_HANDLE)
  {
    CloseHandle(g_listkv);
    g_listkv = INVALID_HANDLE;
  }
}
