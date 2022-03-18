# ATF-AutoSplitter
A [LiveSplit](https://livesplit.org) auto splitter for the VR game [After The Fall](https://afterthefall-vr.com).

In case you don't know what any of it means - LiveSplit is a very popular tool for speed-runners.
Because it's an open source project, people can write custom components for it (and many do).
An auto splitter is a component that can connect to some game instance while it's running, and control LiveSplit by reacting to events from the game.
For more details you can check out [this page all about auto-splitters](https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md).

![image](https://user-images.githubusercontent.com/7516791/159011595-1f0b477c-5338-451b-9173-d19ea6ffbead.png)

## Platforms/Services/Compatibility
I'm playing on a PC running Windows 10, using an HTC Vive (the old one) on SteamVR. I have not tested this on any other platform/service. Theoretically, it should work. But minor tweaks would probably be necessary (such as adding hashes of other versions of the game, or disabling the version checking. Hashes are used to identify the version of the detected running game process and by default nothing will run if the version is unknown).

I don't have that information, but I imagine that the first person to try it on each platform will be able to provide those hashes (and other information) easily, and I'll update the code accordingly.

I don't own any other HMDs, but will probably get a Quest2 at some point in the future. Until then, I'll be limited with what I can do for the Quest users out there...

PSVR users don't have access to the game logs (please correct me if I'm wrong!), so no PSVR support, obviously. Ever...


>***TL;DR:*** Expect some growing pains when it comes to anything other than (and IMHO - inferior to \***wink**\* \***wink**\*) Windows PC + SteamVR. All I can do is promise to do my best to help you out.

## Quick Start
1. Download LiveSplit from their official site: [http://livesplit.org/downloads/](http://livesplit.org/downloads/). (Tested on version 1.8.19)
2. There is no installer. Extract it to a directory of your choice.
3. Download the [latest release](https://github.com/cyb3rmaniak/ATF-AutoSplitter/releases/) of ATF-AutoSplitter and extract it to a directory of your choice.
4. Run LiveSplit.exe in the directory you extracted LiveSplit to.
5. Right click the main window and select *Open Splits -> From File...*
   1. ![image](https://user-images.githubusercontent.com/7516791/159006855-52979bb4-d8df-4c90-8bfb-7315ae1531c5.png)
7. Select **AfterTheFall_AllMissions.lss** in the directory you extracted ATF-AutoSplitter to. This will load the splits info, and should automatically load the layout and the auto splitter scipt with it.
8. Done. Launch AfterTheFall while AutoSplit is running in the background. It will automatically react to game events. At least for the current version of the game on Steam (v1.3.35721).
9. (Optional) - add a floating window in VR that will show LiveSplit while you'e playing. I personally use [XSOverlay](https://store.steampowered.com/app/1173510/XSOverlay) to pin the window to the back of my left hand.

## Troubleshooting
1. If the layout isn't loaded (the LiveSplit window doesn't look like the screenshot above) - Right click the window and select **Open Layout -> From File...*** and select **AfterTheFall_AllMissions.lsl** in the directory you extracted ATF-AutoSplitter to.
2. If LiveSplit doesn't react at all:
   1. Right click the LiveSplit window and select *Edit Layout...*
   2. Double-click the **Scriptable Auto Splitter** at the end of the list:
      1. ![image](https://user-images.githubusercontent.com/7516791/159008147-4a502b61-855a-4f68-8142-72ffb2b4212e.png)
   3. Make sure Script Path (at the top) points to the correct location of **AfterTheFall.asl**:
      1. ![image](https://user-images.githubusercontent.com/7516791/159008363-b8bffbe9-1fcc-4ccf-955d-a0beed2abdd8.png)

3. Any other issue - feel free to contact me in the ATF Discord (Cyb3rManiak#3419), or open an issue here (at the top).


## How this auto splitter works (parsing the game log)
Most auto splitters read the RAM, seaching for known areas of the game instance in memory. They interpret those values, monitor them, and react to changes. I've chosen not to go that route. 

Most popular games in the speed-running comminity are single-player. ATF, however, is an online-focused game. It's (currently) online only, played (mostly) with other people.
Even though it's currently possible to read the game's values from the RAM, it's likely that this will be blocked in the future. Or possibly raise some red flag if anti-cheat measures will be implemented in the future.

This is why this auto splitter reads the ATF game logs. Unless the developers decide to stop writing logs (highly unlikely) - this method will still work even if drastic changes are done to the game.

Additionaly - updates to the code to work with future versions of ATF can be done without needing to know how to use CheatEngine, what are pointer paths or how a memory scan works.

### LiveSplit terminology you should know:
- Splits are the named segments in the LiveSplit window. Splitting the timer means storing the current segment time in the split itself, and moving to the next one.
- Sub-splits are a way to group splits by parenting splits to other splits. In our case, the main splits are the ones with the scene names (Skid Row), and the sub-splits are the ones with the specific mission sections under each of the scenes (Entrance safe room).
- An attempt in LiveSplit starts when the timer is started after a reset, or the launch of LiveSplit. It ends when the timer is reset. This can be manually (from the LiveSplit menu), by the auto splitter, or by splitting until there are no more splits left (reached the end of the list).
- The timer for the attempt (***Real Time***) never stops. In order to effectively pause the timer, ***Game Time*** is used instead.
- ***Game Time*** is paused during loading screens, while waiting for all players to connect, or optionally - when all players are in a safe room.


### Operation (simplified):
1. By default the auto splitter searches for `%appdata%\..\LocalLow\Vertigo Games\AfterTheFall\Player.log`.
2. If the "Parse log from start" setting <!-- TODO: add link to settings --> is set to:
   1. If **true** - the entire log is read from the start.
   2. If **false** - only lines written after the auto splitter is initialized will be parsed and reacted to. This is **NOT** advised unless you have a very good reason to do so, and realize the consequences. See the {#settings} section for more details.
3. The built-in update() action is triggered several times each second. It reads the log file line by line, skipping all lines that don't start with an openning square bracket - \[ - since log messages begin with a timestamp in the format: "\[00:55:34.427\]". The rest of the lines don't interest us and are skipped.
4. The lines are compared to formats of known log events using [regular expressions](https://en.wikipedia.org/wiki/Regular_expression).
5. When a match is found - the auto splitter reacts and performs actions such as starting/stopping/resetting the timer, jumping to specific sections (splits) and updating some of the text labels in the layout (the ones displayed in the LiveSplit window).
6. When the auto-splitter starts, it assumes you are in the Hub. The correct information will be updated in the next step.
7. When a scene (mission/map) starts loading, the auto splitter will jump to the correct split, and then immediately usually to the first sub-split (an entrance safe room in most cases). Scene names from the game are translated to the names on the main splits [^1]. New maps added in later updates will need to be added to the lists in order for the auto splitter to work on them.
8. Certain events, along with some settings defined by the user will trigger the timer to start, stop and split[^1].
***Game Time*** in the segments. ***Make sure that in the layout you choose to use Game Time!***. <!-- TODO: Add a link to instructions -->
9. When a mission run has ended (disconnected from host, all team members are frozen or successfuly finished the mission) the times on each split are stored in the splits file, to be compared to on future runs.
10. When voting on the next mission, the auto splitter will jump to the Limbo split.
11. If a mission run ends successfuly - by default, the total game time for the entire mission will be saved on the main split of the mission. This can be changed using the settings.

>***TL;DR:*** The auto splitter reads one line at a time from the log. If it recognizes the message in that line - it will trigger actions in LiveSplit. An attempt starts when the timer is first started, and ends when it is reset. We use Game Time, that unlike Real Time, can be paused on demand (such as when loading scenes), and not count towards the attempt.

### (Pro tip) - log "replay":
While developing, I've made sure that you could "replay" old log files. Otherwise testing and debugging would have been a nightmare.
ATF renames the previous log file for backup, and creates a new log file when the game starts. You could save those files, and/or use the built-in settings that save copies of them for you in certain scenarios.

This opens the door for interesting possibilities in the future, such as:
- Resuming a previous attempt. For example - in case a crash occured in a long speed run attempt, such as playing all missions in a row. If this was implemented, it would be possible to continue from the beginning the of the crashed mission by "replaying" the log up until the start of that mission, even at a later date.
- Getting detailed information about a run from a log captured when LiveSplit wasn't running. Such as a log file from a MetaBook Oculus Quest.
- Adding detailed information to a video capture of a run ***after the fact***. Even one captured on a MetaBook Oculus Quest.
- Verifying a run's validity **to some degree** by replaying the log file and comparing to the video captured.


# DISCLAIMER:
I'm working on this mainly because it's fun. Because I want to use this tool, even when not speed-running. Hopefully others will agree.

I have never worked with LiveSplit before. I might have mistakes in my approach or do things not as they were intended.
I've tried following other examples of auto-splitters, and asked questions in the LiveSplit Discord.
However, there are very few auto-splitters out there that read and parse logs (the Talos Principle auto-splitter was a big help. Huge thanks to [u/Apple1417](https://www.reddit.com/user/Apple1417/) on Reddit for his reply to [this post](https://www.reddit.com/r/speedrun/comments/8du8lf/how_do_i_make_an_autosplitter_with_a_games_log/). It saved a lot of time and made things much clearer).

Thanks to Tedder and Ero on the Speedrun Tool Development Discord I managed to clean up my code by directly accessing some low-level classes and methods from LiveSplit.Code.Model, and not relying on the built-in actions such as split(), reset() and start() as I did before. That approach works when you monitor the RAM. When you read lines from a log file, those actions make the code more complicated and hacky. Accessing the Model classes is not something you will see in most auto splitters, so examples for those might be sparse in case you want to edit and add features to this project.

I am not responsible for ***ANYTHING*** that this code does to your machine, your LiveSplit installation, to the time-space continuum or to anything else for that matter. In this life or the next.

It could potentially erase your entire hard drive, but only after sending your private nude pics to your boss and clearing out your Bitcoin account.
Even if it causes your hamster (or you) extreme vertigo - I could NOT be blamed for it.

***YOU WERE WARNED!*** I'm providing this code AS-IS. I've wrote all 900+ lines of it in a chinese clone of the Post-it notes app, using extremely large fonts, on my smart phone after binge-drinking for a week. It was written from start to finish during ***one*** intensive night of coding, and I haven't tested it once. I think parts came to me at a waking dream, or when I blacked out for an hour or two. 

Other parts simply appeared while I was taking bathroom breaks. I honestly not sure where those actually came from, and I'm not going to investigate it further. I've seen too many horror movies to know better!

By using this code - you take full responsibility for it! (If the continuum breaks - it's ***your*** fault).

>***TL;DR:*** You can't blame me for anything. Ever.

