# findstation

I found a way to read the sector XML files in an usable way within Avorion ingame scripts :)

This means i managed to create a mod which can be used to **search for specific stations in every found/created sector in your galaxy!**

*Search UI:*  
![screenshot](http://gdurl.com/Bddn)

*Search Command:*  
![screenshot](http://gdurl.com/9wjq)


*The script basically works by searching through all existing sector files, reads their data and searches for the given term ->
This implementation is a workaround until proper access to sector data is provided by the game for scripts, and some functions used for file access by this script even may be permitted in the future due to security/performance reasons (mods being able to read/write any file on the system is never good in terms of security)!*

_**The mod stays alpha until sector data is provided by game API!**_

### BACKUP YOUR FILES/GALAXY!

##  COMMANDS

### /findstationui  
Enables/disables the UI *(menu item & window)* for station search.

*Usage:*   
`/findstationui`   
`/findstationui enable`   
`/findstationui disable`


### /findstation  
Finds near stations in any of the found/created sectors in the galaxy and displays them in chat-window.

*Usage:*   
`/findstation <SEARCHTERM>`

*Parameters:*   
`<SEARCHTERM>` = term to search in station names *(spaces possible, case-insensitive)*


### /findstationconfig  
Used to set the configuration values for /findstation command.

*Usage:*   
`/findstationconfig galaxy <GALAXYNAME>`   
`/findstationconfig galaxypath <GALAXYPATH>`   
`/findstationconfig searchmode <MODE>`  
`/findstationconfig maxresults <NUMBER>`  
`/findstationconfig framesectorloads <NUMBER>`  
`/findstationconfig maxconcurrent <NUMBER>`  
`/findstationconfig searchdelay <NUMBER>`

*Parameters:*  
`<GALAXYNAME>` = name of current galaxy  
`<GALAXYPATH>` = full directory path for galaxy  
`<MODE>` = one of the available search modes 'player' or 'galaxy'  
`<NUMBER>` = any positive number or 0


##  INSTALLATION
Download the ZIP file of the **[latest release](https://github.com/w00zla/avorion-findstation/releases)** and extract it to `<Avorion>\data\` directory, like with other mods.

*No vanilla script files will be overwritten, so there should be no problems with other mods!*

**Server/Client:** The scripts are _**server- and client-side**_ by now!   
Following files have to be available on the **client** for multiplayer games:
```
scripts\entity\findstation\searchui.lua
textures\icons\findstation\searchstation.png
```

*TIP: If you disable the /findstationui command on your server (and thus not using the search UI), no client files need to be installed at all!*


# HOW TO

### First use in galaxy:
The mod tries to auto-detect the configuration when first search is executed in a galaxy.  
If the auto-configuration fails, you must execute `/findstationconfig` and configure the name of the galaxy *(this has only to be done once per galaxy)*:  
**`/findstationconfig galaxy <GALAXYNAME>`**  
*Example:*  
`/findstationconfig galaxy myfirstgalaxy`

If you want to use the search UI, you must enable it first by using:  
**`/findstationui`**  
If you want to hide/disable the UI and remove or uninstall the script, then use:  
**`/findstationui disable`**


### First use in galaxy (dedicated server with "--datapath"):
The mod tries to auto-detect the configuration when first search is executed in a galaxy.  
If the auto-configuration fails, and you use the `--datapath` parameter for your server, you must execute `/findstationconfig` and configure the directory path of the galaxy *(this has only to be done once per galaxy)*. Just use the same path as for `--datapath` plus the galaxy name:  
**`/findstationconfig galaxypath <GALAXYPATH>`**  
*Example:*  
`/findstationconfig galaxypath C:\avorionserver\galaxies\myfirstgalaxy`


### Performance tweaking:
If your searches are too slow or performance cost of searches is too high then you can modify some of the configs to tune the behavior (use `/findstationconfig` for this):

__*framesectorloads*__:   
- defines the maximum number of searched/loaded sector files per frame (quite like "file reads per frame")
- higher values mean faster search but more performance cost
- possible values: 0 - 1000000 *(0 disables the limit)*
- default: 10

__*maxresults*__:   
- defines after how many found results the search will stop
- lower values means faster search in some cases, but also gives you less output obviously
- possible values: 0 - 99999999 *(0 disables the limit)*
- default: 30


### Search modes:
The available search modes define which sectors are searched for stations:

__*searchmode*__:   
- defines the search mode to be used for all searches
- possible values: 
    - `player` *(search only in sectors discovered by player)*
    - `galaxy` *(search in all sectors created in the galaxy)*
- default: player


### Advanced server configuration:
These configs will help server admins to keep impact of searches on server load at a minumum and to prevent flood/spam:

__*maxconcurrent*__:   
- defines the maximum number of concurrent searches, meaning how many players can have a search running at the same time
- possible values: 0 - 99999999 *(0 disables the limit)*
- default: 0

__*searchdelay*__:   
- defines the minimum time (in seconds) a player has to wait before he can start a new search, after each search
- possible values: 0 - 99999999 *(0 disables the limit)*
- default: 0
