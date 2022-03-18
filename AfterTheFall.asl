//state("LiveSplit", "v1.3.35721 (Steam)")
state("AfterTheFall", "v1.3.35721 (Steam)")
{
	
}

startup
{
	refreshRate = 5;
	 
	// Create and register a TimerModel to control Reset, Split and Start manually, instead of using actions.
	vars.timerModel = new TimerModel() { CurrentState = timer };
	
	// Always work in game time, since it can be paused during loading times, between missions and in the safe rooms.
	timer.CurrentTimingMethod = TimingMethod.GameTime;
	
	// Usefull methods

	#region Usefull methods

	Action<string> DebugOutput = (text) => 
	{
		print("[AfterTheFall Autosplitter] " + text);
	};
	vars.DebugOutput = DebugOutput;

	Action<string> DelayNextUpdate = (reason) => 
	{
		// vars.NextUpdate = System.DateTime.Now.AddSeconds(0.5);
		// vars.DebugOutput("Delaying next update (" + reason + ").");
	};
	vars.DelayNextUpdate = DelayNextUpdate;
	
	// Based on: https://github.com/NoTeefy/LiveSnips/blob/master/src/snippets/checksum(hashing)/checksum.asl
	Func<ProcessModuleWow64Safe, string> CalcModuleHash = (module) => 
	{
		//vars.DebugOutput("Calcuating hash of "+module.FileName);
		byte[] exeHashBytes = new byte[0];
		using (var sha = System.Security.Cryptography.MD5.Create())
		{
			using (var s = File.Open(module.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
			{
				exeHashBytes = sha.ComputeHash(s);
			}
		}
		var hash = exeHashBytes.Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
		//vars.DebugOutput("Hash: "+hash);
		return hash;
	};
	vars.CalcModuleHash = CalcModuleHash;
	
	Func<StreamReader, System.Text.RegularExpressions.Regex, string> ReadLinesUntilMatch = (streamReader, regexToMatch) =>
	{
		if (streamReader == null)
		{
			vars.DebugOutput("ReadLinesUntilMatch - streamReader was null.");
			return null;
		}

		var linesReturnedBuilder = new StringBuilder();

		string currLine;
		while (vars.logFileReader != null)
		{
			currLine = streamReader.ReadLine();
			if (currLine == null)
			{
				// No line was read. No need to continue.
				vars.DebugOutput("ERROR: Reached the end of the stream without finding a line that matches the provided regex.");
				return null; 
			}

			var match = regexToMatch.Match(currLine);
			if (match.Success)
			{
				// Found end of message
				linesReturnedBuilder.AppendLine(currLine);
				var fullMessage = linesReturnedBuilder.ToString();
				//vars.DebugOutput("Found end of message. Full message was: " + fullMessage);
				return fullMessage;
			}

			linesReturnedBuilder.AppendLine(currLine);
		}
		
		vars.DebugOutput("vars.logFileReader is now null, and the end of the message wasn't found.");
		return null;
	};
	vars.ReadLinesUntilMatch = ReadLinesUntilMatch;

	Func<StreamReader, string> GetNextImportantLine = (streamReader) =>
	{
		if (streamReader == null)
			return null;

		string lineReturned = null;
		do
		{
			lineReturned = streamReader.ReadLine();
			
			if (lineReturned == null) 
				return null; // No line was read. No need to continue.
			
			if (!lineReturned.StartsWith("["))
				continue; // If the line doesn't start with a timestamp, it's not important right now.
				
			return lineReturned;
		}
		while (lineReturned != null);
		
		return null;
	};
	vars.GetNextImportantLine = GetNextImportantLine;
	
	Action StartOrUnpauseGameTime = () =>
	{
		vars.DebugOutput("Starting or un-pausing game time...");

		//  vars.DebugOutput("timer.CurrentPhase: " + timer.CurrentPhase + ", timer.IsGameTimeInitialized: " + 
		//  	timer.IsGameTimeInitialized + " , timer.IsGameTimePaused: " + timer.IsGameTimePaused);
			
		if (timer.CurrentPhase == TimerPhase.Ended)
			vars.ResetTimer();

		if (timer.CurrentPhase == TimerPhase.Running)
		{
			vars.DebugOutput("Timer is already running. Un-pausing game time. timer.CurrentTime: " + timer.CurrentTime);
			timer.IsGameTimePaused = false;
		}
		else if (timer.CurrentPhase != TimerPhase.NotRunning)
		{
			vars.DebugOutput("WARNING: Timer was in an un-expected phase: " + timer.CurrentPhase);
		}
		else
		{
			var splitIndexBeforeStartingTimer = timer.CurrentSplitIndex;

			vars.DebugOutput("Starting timer.");
			vars.timerModel.Start();
			timer.IsGameTimePaused = false;

			// Starting the timer resets to the first split. Jump back to the split before starting.
			timer.CurrentSplitIndex = splitIndexBeforeStartingTimer;
		}

		// vars.DebugOutput("timer.CurrentPhase: " + timer.CurrentPhase + ", timer.IsGameTimeInitialized: " + 
		// 	timer.IsGameTimeInitialized + " , timer.IsGameTimePaused: " + timer.IsGameTimePaused);

	};
	vars.StartOrUnpauseGameTime = StartOrUnpauseGameTime;

	Action<string> PauseGameTime = (reason) =>
	{
		if (timer.IsGameTimePaused)
		{
			vars.DebugOutput("Was about to pause game time (" + reason + "), but it was already paused.");
		}
		else
		{
			vars.DebugOutput("Pausing game time (" + reason + "). timer.CurrentTime: " + timer.CurrentTime);
			timer.IsGameTimePaused = true;
		}
	};
	vars.PauseGameTime = PauseGameTime;

	Action ResetTimer = () =>
	{
		if (timer.CurrentPhase != TimerPhase.Ended)
		{
			vars.DebugOutput("WARNING: Attempted to reset the timer when the current phase was " + timer.CurrentPhase);
		}
		else
		{
			var splitIndexBeforeResetting = timer.CurrentSplitIndex;

			vars.DebugOutput("splitIndexBeforeResetting: " + splitIndexBeforeResetting);
			
			vars.DebugOutput("Resetting and pausing timer");
			vars.timerModel.Reset();
			vars.DebugOutput("timer.CurrentSplitIndex: " + timer.CurrentSplitIndex);
			timer.IsGameTimePaused = true;

			// Resetting the timer sets the current split to -1. Jump back to the split before the reset.
			timer.CurrentSplitIndex = splitIndexBeforeResetting;
		}
	};
	vars.ResetTimer = ResetTimer;

	Action SplitTimer = () =>
	{
		vars.DebugOutput("Splitting timer. timer.CurrentTime: " + timer.CurrentTime + ", timer.CurrentSplit.Name: " + timer.CurrentSplit.Name); 
		vars.timerModel.Split();
		
		vars.DebugOutput("New section name: " + (timer.CurrentSplit == null ? "null" : timer.CurrentSplit.Name));

		vars.DelayNextUpdate("Split section to " + (timer.CurrentSplit == null ? "null" : timer.CurrentSplit.Name));
	};
	vars.SplitTimer = SplitTimer;

	Action<string> JumpToSection = (sectionName) =>
	{
		vars.DebugOutput("About to jump to section " + sectionName + "...");

		var sectionFound = timer.Run.FirstOrDefault(section => section.Name == sectionName);
		if (sectionFound == null)
		{
			vars.DebugOutput("ERROR: Couldn't find a section with the name " + sectionName + ".");
		}
		else
		{
			var indexOfFoundSection = timer.Run.IndexOf(sectionFound);
			vars.DebugOutput("Found section " + sectionName + " at index " + indexOfFoundSection + ".");

			indexOfFoundSection++;
			vars.DebugOutput("Skipping to the first sub-section of " + sectionName + " (" + timer.Run[indexOfFoundSection].Name + ").");

			timer.CurrentSplitIndex = indexOfFoundSection;
		}
	};
	vars.JumpToSection = JumpToSection;
	
	#endregion // Usefull methods

	vars.previousMapText = " ";
	vars.NextUpdate = null;
	vars.gameTimeOnSceneStart = System.TimeSpan.Zero;

	// Game info
	vars.logPath			= null;
	vars.currSection		= null;
	vars.isLoadingScene 	= false;
	vars.isInSafeRoom		= true;
	vars.sceneName 			= "Hub";
	
	// Splits and sub-splits
	vars.currSplit 			= null;
	
	// Settings
	settings.Add("Pause timer when all players enter a safe room", true);
	settings.Add("Split timer when all players enter a safe room", true);
	settings.Add("Split timer when pushing button to exit safe room", true);
	settings.Add("Split timer between mission sections", true);
	settings.Add("Stop timer as soon as last section is clear (don't wait for button press)", false);
	settings.Add("Set game time on the main split when mission is complete", true);
	settings.Add("Save times even when disconnected or failed mission", true);
	settings.Add("Reset timer when loading a new mission", true);
	settings.Add("Reset timer when loading a new mission, but only from the Hub", false);
	settings.Add("Save game log copy when mission ends", false);
	settings.Add("Save game log copy after game is closed", true);
	settings.Add("Parse log from start", true);
	
	// Mission scene names translated to the name of the split to search for
	vars.sceneNamesToSplitNames = new Dictionary<string, string>
	{
		{ "CM01_Skidrow", 		"Skid Row" },
		{ "CM02_Downtown", 		"Quarantine Center"},
		{ "CM06_Chinatown-02", 	"Chinatown"},
		{ "CM04_BankTower", 	"Union Tower"},
		{ "CM04_BankTower-02", 	"Relay Tower"},
		{ "Hub", 				"Hub"},
		{ "Limbo", 				"Limbo"},
		{ "HM01_Chinatown", 	"Junction (Horde)"},
		{ "HM02_Highway", 		"Highway (Horde)"},
	};
	
	// Known log lines
	vars.regexes = new Dictionary<string, System.Text.RegularExpressions.Regex>
	{
		{ "SceneIsLoading", new System.Text.RegularExpressions.Regex(@"\[Info\] \[VertigoSceneManager\] Loading scene: (.*)...") }, 
		{ "SceneLoaded", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] OnSceneLoaded \((.*)\):") }, 
		{ "GameplayInitiated", new System.Text.RegularExpressions.Regex(@"\[Info\] \[ClientGameplaySystem\] \[ClientGameplaySystem\] Gameplay Initiated") }, 
		{ "SaferoomDoorOpened", new System.Text.RegularExpressions.Regex(
			@"\[Info\] \[SequenceLogger\] OnPuzzleDoorActivated \(Gameplay_PuzzleDoor\): Stub Trigger") },
		{ "SaferoomDoorOpened_alt", new System.Text.RegularExpressions.Regex(
			@"\[Info\] \[SequenceLogger\] OnDoorAirlockActivated \(Gameplay_DoorAirlock_Automatic - Enter\): Stub Trigger") },
		{ "SaferoomDoorOpened_alt2", new System.Text.RegularExpressions.Regex(
			@"\[Info\] \[SequenceLogger\] OnDoorAirlockActivated \(Gameplay_DoorAirlock_Automatic - Exit\): Stub Trigger") },
		{ "NewSectionEntered", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] Spawn\s?Idles \(Section: (.*)\):") },
		{ "NewSectionEntered_alt", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] IdleActivation \(Section[_,:]? (.*)\): Stub Trigger") },
		{ "NewSectionEntered_alt2", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] ActivateIdleZombies - (.*): Stub Trigger") },
		{ "NewSectionEntered_alt3", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] ActivateIdles \(Section:?\s?-?\s?(.*)\): Stub Trigger") },
		{ "NewSectionEntered_alt4",
			new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] OnAnyPlayerFirstVisitActivateIdleZombies \(Section[_:] (.*)\): Stub Trigger") },
		{ "NewSectionEntered_alt5", 
			new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] OnSectionTriggerAnyPlayerFirstVisit \(Section: (.*)\):") },
		{ "NewSectionEntered_alt6", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] OnSmasherTrigger01AnyPlayerFirstVisit \(Section: (.*)\):") },
		{ "NewSectionEntered_alt7", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SequenceLogger\] Idles \(Section: (.*)\):") },
		{ "CompletedSection", new System.Text.RegularExpressions.Regex(@"\[Info\] \[GameplaySection\] Completed section Section: (.*)") },
		{ "CompletedSection_alt", new System.Text.RegularExpressions.Regex(@"\[Info\] \[GameplaySection\] Completed section Section - (.*)") },
		{ "AllPlayersEnteredSaferoom", new System.Text.RegularExpressions.Regex(
			@"\[Info\] \[ServerSequencerGameSystem\] Sending sequencer trigger for sequence: OnServerVolumeFirstVisitAllPlayers, ID: (\d+) triggerID: (\d+)") },
		{ "AllPlayersEnteredSaferoom_alt", new System.Text.RegularExpressions.Regex(
			@"\[Info\] \[SequenceLogger\] OnServerVolumeFirstVisitAllPlayers \(Airlock(Automatic)?\): Stub Trigger") },
		{ "AllPlayersEnteredSaferoom_alt2", new System.Text.RegularExpressions.Regex(
			@"\[Info\] \[SequenceLogger\] OnServerVolumeFirstVisitAllPlayers \(Airlock\): Stub Trigger") },
		{ "SessionEnded", new System.Text.RegularExpressions.Regex(@"\[Info\] \[SessionGameSystem\] Session state changed to Ended, ending type: (.*)") },
		{ "InitializingMapVoteScreen", 
			new System.Text.RegularExpressions.Regex(@"\[Info\] \[MapVoteScreenBehaviour\] Initializing map vote screen\. endResult: (.*)\.\.\.") },
		{ "DifficultyChanged", new System.Text.RegularExpressions.Regex(@"\[Info\] \[GameplayDifficultySystem\] Difficulty changed to (.*)") },
		{ "PartyUpdated_Start", 
			new System.Text.RegularExpressions.Regex(@"\[Info\] \[FirebaseMessageSystem\] Received a message with context 'Party-Updated', data: {") },
		{ "PartyUpdated_End", new System.Text.RegularExpressions.Regex(@"^}") },
		{ "PartyUpdated_PlayerInfo", 
			new System.Text.RegularExpressions.Regex(
				@"""displayName"": ""(.*?)"",.*?""platform"": (\d+),.*?""userId"": ""(.*?)""",
				System.Text.RegularExpressions.RegexOptions.Singleline) },
		{ "Horde_StartingRound",  new System.Text.RegularExpressions.Regex(@"\[Info\] \[ServerHordeModeSystem\] Starting round: (.*)")}
	};
	
	// Scenes without safe rooms
	vars.scenesWithoutSaferooms = new List<string>
	{
		"Relay Tower",
		"Junction (Horde)",
		"Highway (Horde)"
	};

	// Sections right before safe rooms
	vars.sectionsBeforeSaferooms = new List<string>
	{
		"RooftopBeforeApartment",	// Skid Row
		"Apartment Lower Floor",	// Skid Row
		"Checkpoint", 				// Quarantine Zone
		"ChinaMarketSquare",		// Chinatown
		"ChinaRestaurant3", 		// Chinatown
		"LobbyExit",				// Union Tower
		"MaintenanceCloset",		// Union Tower
	};
	
	vars.sectionsBeforeExitSaferoom = new List<string>
	{
		"Construction Site",	// Skid Row
		"GarageTopFloor", 		// Quarantine Zone
		"ChinaMainSquare", 		// Chinatown
		"BankCafeteria",		// Union Tower
	};


	// Get layout components to update later
	foreach (var component in timer.Layout.LayoutComponents)
	{
		if (component.Component.ComponentName.StartsWith("Difficulty"))
		{
			vars.DebugOutput("Found difficulty text component.");
			Action<string> SetDifficultyText = (newText) => 
			{ 
				var textSettings = component.Component.GetType().GetProperty("Settings").GetValue(component.Component, null);
				var currValue = textSettings.GetType().GetProperty("Text2").GetValue(textSettings, null) as string;
				
				//vars.DebugOutput("Changing difficulty text to " + newText + " (from " + currValue + ").");
				textSettings.GetType().GetProperty("Text2").SetValue(textSettings, newText);
			};
			vars.SetDifficultyText = SetDifficultyText;
		}
		else if (component.Component.ComponentName.StartsWith("Players in party:"))
		{
			vars.DebugOutput("Found player display names text component.");
			Action<List<string>> SetPlayersDisplayNames = (newDisplayNames) => 
			{
				var textSettings = component.Component.GetType().GetProperty("Settings").GetValue(component.Component, null);
				var currValue = textSettings.GetType().GetProperty("Text2").GetValue(textSettings, null) as string;
				var newValue = string.Join(", ", newDisplayNames);

				//vars.DebugOutput("Changing players in party text to [" + newValue + "] (from [" + currValue + "]).");
				textSettings.GetType().GetProperty("Text2").SetValue(textSettings, newValue);
			};
			vars.SetPlayersDisplayNames = SetPlayersDisplayNames;
		}
		else if (component.Component.ComponentName.StartsWith(" ") || component.Component.ComponentName.StartsWith("("))
		{
			vars.DebugOutput("Found map name text component.");
			Action<string> SetMapNameText = (newText) => 
			{
				var textSettings = component.Component.GetType().GetProperty("Settings").GetValue(component.Component, null);
				var currValue = textSettings.GetType().GetProperty("Text1").GetValue(textSettings, null) as string;
				
				//vars.DebugOutput("Changing map name to " + newText + " (from " + currValue + ").");
				textSettings.GetType().GetProperty("Text1").SetValue(textSettings, newText);
				textSettings.GetType().GetProperty("Text2").SetValue(textSettings, " ");
			};
			vars.SetMapNameText = SetMapNameText;
		}
	}
}

init
{
	// For debug without launching VR - uncomment this, and the very first line in this script (//state("LiveSplit"...)
	// if (version == "")
	//  	version = "v1.2.35043 (Steam)";

	if (version == "")
	{
		var atfMainExeModule = modules.SingleOrDefault(module => 
			String.Equals(module.ModuleName, "AfterTheFall.exe", StringComparison.OrdinalIgnoreCase));
		
		// foreach (var currModule in modules)
		// 	vars.DebugOutput("Module: " + currModule.ModuleName);

		if (atfMainExeModule == null)
		{
			vars.DebugOutput("Error: couldn't find the exe module (AfterTheFall.exe).");
			return false;
		}

		var moduleSize = atfMainExeModule.ModuleMemorySize;
		var hash = vars.CalcModuleHash(atfMainExeModule);
		
		vars.DebugOutput("EXE Module: [" + atfMainExeModule.ModuleName + "]. Size: [" + moduleSize + "]. MD5 hash: [" + hash + "]");

		if (hash == "E23DE5E8BAB08636BF41E9548E6A5DF4")
		{
			// Module Size: 675840
			version = "v1.2.35043 (Steam)";
		}
		/*
		// Fallback for possible older versions.
		else if (moduleSize == 3805184)
		{
			version = "v1.1.34250 (Steam)";
		}
		*/

		var atfGameModule = modules.SingleOrDefault(module => 
			String.Equals(module.ModuleName, "GameAssembly.dll", StringComparison.OrdinalIgnoreCase));

		if (atfGameModule == null)
		{
			vars.DebugOutput("Error: couldn't find the main game module (GameAssembly.dll).");
			return false;
		}

		moduleSize = atfGameModule.ModuleMemorySize;
		hash = vars.CalcModuleHash(atfGameModule);
		
		vars.DebugOutput("Main game module: [" + atfGameModule.ModuleName + "]. Size: [" + moduleSize + "]. MD5 hash: [" + hash + "]");

		if (hash == "0536A3BB828C0AED653FB1E86C002C1B")
		{
			// Module Size: 82661376
			version = "v1.3.35721 (Steam)";
		}
		/*
		// Fallback for possible older versions.
		else if (moduleSize == 3805184)
		{
			version = "v1.1.34250 (Steam)";
		}
		*/
	}
	
	if (version == "")
	{
		vars.DebugOutput("No recognized version was found. Auto-Splitter will NOT work.");
		return false;
	}
	
	// Open the log file
	var appDataDir = System.Environment.GetEnvironmentVariable("appdata");
	string logPath = appDataDir + @"\..\LocalLow\Vertigo Games\AfterTheFall\Player.log";
	//logPath = appDataDir + @"\..\LocalLow\Vertigo Games\AfterTheFall\LiveSplit_2022-03-10_23_50.Player.log";
	//logPath = appDataDir + @"\..\LocalLow\Vertigo Games\AfterTheFall\LiveSplit_2022-03-11_03_36.Player.log";
	//logPath = appDataDir + @"\..\LocalLow\Vertigo Games\AfterTheFall\Horde_Over30\Player.log";
	
	if (!File.Exists(logPath)) 
	{
		vars.DebugOutput("Log file wasn't found. logPath was: " + logPath);
	}
	else
	{
		vars.DebugOutput("Found log. logPath was: " + logPath);
		vars.logPath = logPath;
		vars.logFileReader = new StreamReader(new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
		
		if (!settings["Parse log from start"])
		{
			vars.DebugOutput("NOT parsing the log from the start. Skipping to the end before reading new lines.");
			vars.logFileReader.ReadToEnd();
		}
	}	

	vars.PauseGameTime("init");
	timer.IsGameTimeInitialized = true;
}

update
{
	// When we return false here, it prevents the rest of the actions from running (start, split, reset etc.).
	// This is important for performance!
    if (version == "" || vars == null || vars.logPath == null)
		return false;

	if (vars.NextUpdate != null)
	{
		if (System.DateTime.Now < vars.NextUpdate)
		{
			//vars.DebugOutput((vars.NextUpdate - System.DateTime.Now).TotalSeconds + " seconds before next update");
			return false;
		}
		vars.NextUpdate = null;
	}
		
	// Read lines from the log and search for known ones...

	string currLine = null;
	while (vars.logFileReader != null) 
	{
		currLine = vars.GetNextImportantLine(vars.logFileReader);
		if (currLine == null) 
			return false; // No line was read. No need to continue.
		
		#region Find known lines

		// Check against known lines...
		
		var match = vars.regexes["SceneIsLoading"].Match(currLine);
		if (match.Success)
		{
			// Started loading a scene.
			var newSceneName = match.Groups[1].Value;
			vars.DebugOutput("Loading the scene [" + newSceneName + "]...");
			
			newSceneName = vars.sceneNamesToSplitNames[newSceneName];
			vars.DebugOutput("Translated the scene name to [" + newSceneName + "].");
			
			vars.isLoadingScene = true;
			vars.IsSessionActive = false;
			vars.currSection = null;
			
			//vars.DebugOutput("CurrentPhase: " + timer.CurrentPhase);
			//vars.DebugOutput("CurrentSplitIndex: " + timer.CurrentSplitIndex);
			var currSplit = timer.CurrentSplit;
			
			vars.DebugOutput("vars.sceneName: " + vars.sceneName + ", CurrentSplit: " + (timer.CurrentSplit == null ? "null" : timer.CurrentSplit.Name));
			
			vars.isInSafeRoom = true;

			if (timer.CurrentPhase == TimerPhase.Running && !timer.IsGameTimePaused)
				vars.PauseGameTime("Started loading a new scene");

			if (newSceneName == "Hub")
			{
				vars.DebugOutput("Jumping to Hub split.");
				timer.CurrentSplitIndex = 0;
				vars.sceneName = newSceneName;
				vars.SetMapNameText(vars.previousMapText);
				continue;
			}
			else
			{
				if ( settings["Reset timer when loading a new mission"] || 
					(settings["Reset timer when loading a new mission, but only from the Hub"] && vars.sceneName == "Hub"))
				{
					vars.DebugOutput("Resetting timer before loading a new mission.");
					//vars.DebugOutput("timer.CurrentPhase: " + timer.CurrentPhase + ", timer.IsGameTimeInitialized: " + 
					//	timer.IsGameTimeInitialized + " , timer.IsGameTimePaused: " + timer.IsGameTimePaused);
					vars.timerModel.Reset();
					timer.IsGameTimePaused = true;
					// vars.DebugOutput("timer.CurrentPhase: " + timer.CurrentPhase + ", timer.IsGameTimeInitialized: " + 
					// 	timer.IsGameTimeInitialized + " , timer.IsGameTimePaused: " + timer.IsGameTimePaused);
				}
				
				vars.sceneName = newSceneName;
				vars.SetMapNameText("(" + newSceneName + ")");

				vars.JumpToSection(vars.sceneName);
				continue;
			}
		}
		
		if (vars.isLoadingScene)
		{
			if (vars.sceneName == "Hub")
			{
				// Wait for scene to finish loading
				match = vars.regexes["SceneLoaded"].Match(currLine);
				if (match.Success)
				{
					// Hub is ready
					vars.isLoadingScene = false;
					vars.DebugOutput("Hub is loaded.");
					
					vars.SetPlayersDisplayNames(new List<string> { "Not in party." }); 
					vars.SetDifficultyText("Not set yet.");
					continue;
				}
			}
			else
			{
				// Wait for scene to finish loading, and for all players to connect
				match = vars.regexes["GameplayInitiated"].Match(currLine);
				if (match.Success)
				{
					// Scene is ready and all players are connected.
					vars.isLoadingScene = false;
					vars.IsSessionActive = true;
					vars.gameTimeOnSceneStart = timer.CurrentTime.GameTime;

					vars.DebugOutput("Scene is ready (" + vars.sceneName + ") and all players are connected. " +
						"GameTime: " + vars.gameTimeOnSceneStart.ToString());

					// In relay tower the elevator doors open when all players are connected. There is no safe room door to exit.
					// In horde mode maps there is no door to open.
					var doesSceneStartsInSaferoom = !vars.scenesWithoutSaferooms.Contains(vars.sceneName);
					//vars.DebugOutput("vars.sceneName: " + vars.sceneName + ", doesSceneStartsInSaferoom: " + doesSceneStartsInSaferoom);

					if (!doesSceneStartsInSaferoom || !settings["Pause timer when all players enter a safe room"])
						vars.StartOrUnpauseGameTime();
					
					if (!doesSceneStartsInSaferoom)
					{
						vars.isInSafeRoom = false;
						timer.CurrentSplitIndex++;
						vars.DebugOutput("Skipped to next section without using split (" + timer.CurrentSplit.Name + ")");
					}

					vars.DelayNextUpdate("GameplayInitiated.");
					continue;
				}
			}
		}
		
		match = vars.regexes["SaferoomDoorOpened"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["SaferoomDoorOpened_alt"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["SaferoomDoorOpened_alt2"].Match(currLine);
			
		if (match.Success)
		{
			vars.DebugOutput("Saferoom door is open. currSection: " + vars.currSection + 
				", timer.CurrentSplit.Name: " + (timer.CurrentSplit == null ? "None (null)" : timer.CurrentSplit.Name));
			vars.DebugOutput(currLine);
			
			if (!vars.isInSafeRoom)
			{
				vars.DebugOutput("Entrance to a safe room is now open.");
				
				if (vars.sectionsBeforeExitSaferoom.Contains(vars.currSection))
				{
					vars.DebugOutput("This was the last section. The door opened is to the exit safe room.");
					
					if (settings["Stop timer as soon as last section is clear (don't wait for button press)"])
					{
						vars.SplitTimer();
						vars.PauseGameTime();
						return false;
					}
				}
			}
			else
			{
				vars.DebugOutput("Exit from a saferoom is now open.");
				
				vars.isInSafeRoom = false;

				// If the game time was paused when the level was loaded or players entered the safe room - Un-pause it.
				if (settings["Pause timer when all players enter a safe room"])
					vars.StartOrUnpauseGameTime();
				
				if (settings["Split timer when pushing button to exit safe room"])
					vars.SplitTimer();
			}
			continue;
		}
		
		match = vars.regexes["CompletedSection"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["CompletedSection_alt"].Match(currLine);
		
		if (match.Success)
		{
			// Completed a section in the mission
			var completedSection = match.Groups[1].Value;
			
			vars.DebugOutput("(Ignored) Completed section [" + completedSection + "].");
			continue;
		}
		
		match = vars.regexes["NewSectionEntered"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt2"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt3"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt4"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt5"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt6"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["NewSectionEntered_alt7"].Match(currLine);
			
		if (match.Success)
		{
			// Entered a new section
			var newSection = match.Groups[1].Value;
			
			if (String.IsNullOrEmpty(vars.currSection))
			{
				vars.DebugOutput("Entered the first section of the mission: [" + newSection + "]. timer.CurrentSplit.Name: " + timer.CurrentSplit.Name);
				vars.currSection = newSection;
				vars.DebugOutput(currLine);
				continue;
			}
			
			if (vars.currSection == newSection)
			{
				vars.DebugOutput("Ignoring new section " + newSection + ". Already in that section.");
				continue;
			}

			vars.DebugOutput(
				"Moved from section [" + vars.currSection + "] to [" + newSection + "]. " +
				"timer.CurrentSplit.Name: [" + timer.CurrentSplit.Name + "]. timer.CurrentTime: " + timer.CurrentTime);
			vars.DebugOutput(currLine);
			
			var shouldSplitTimer = settings["Split timer between mission sections"];
			if (shouldSplitTimer && vars.sectionsBeforeSaferooms.Contains(vars.currSection))
			{
				vars.DebugOutput("The new section (" + newSection + ") is AFTER the saferoom we are in. NOT splitting the timer at this point.");
				shouldSplitTimer = false;
			}
			
			vars.currSection = newSection;
			
			if (shouldSplitTimer)
			{
				vars.SplitTimer();
				return false;
			}
			
			continue;
		}
		
		match = vars.regexes["AllPlayersEnteredSaferoom"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["AllPlayersEnteredSaferoom_alt"].Match(currLine);
		if (!match.Success)
			match = vars.regexes["AllPlayersEnteredSaferoom_alt2"].Match(currLine);
			
		if (match.Success)
		{
			if (vars.isInSafeRoom)
			{
				vars.DebugOutput("Already is in safe room. Ignoring message about all players entering.");
				continue;
			}
			
			// All players have entered the safe room
			vars.DebugOutput("All players have entered a saferoom.");
			vars.isInSafeRoom = true;
			
			if (settings["Pause timer when all players enter a safe room"])
				vars.PauseGameTime("All players have entered a saferoom");
			
			if (settings["Split timer when all players enter a safe room"])
			{
				vars.SplitTimer();
				return false;
			}

			continue;
		}
		
		match = vars.regexes["SessionEnded"].Match(currLine);
		if (match.Success)
		{
			// Mission ended (maybe succesfully, maybe not. Maybe was disconnected).
			string reason = match.Groups[1].Value;
			
			vars.DebugOutput("Session ended. Reason was: " + reason + ". Current split: " + 
				(timer.CurrentSplit == null ? "None (null)" : timer.CurrentSplit.Name));
			vars.DebugOutput(currLine); 
			
			if (timer.CurrentPhase == TimerPhase.Running)
			{
				if (!vars.IsSessionActive)
				{
					vars.DebugOutput("Ignoring Session Ended message (session was not active).");
					continue;
				}

				vars.PauseGameTime("Session Ended");
				vars.IsSessionActive = false;
				vars.previousMapText = "(Previous was " + vars.sceneName + " - " + reason + ")";

				if (reason == "Completed" || settings["Save times even when disconnected or failed mission"])
				{
					if (reason != "Completed")
					{
						vars.DebugOutput("Un-doing last split.");
						//vars.DebugOutput(timer.CurrentSplit.Name + ": " + timer.CurrentSplit.SplitTime.GameTime);
						vars.timerModel.UndoSplit();
						//vars.DebugOutput(timer.CurrentSplit.Name + ": " + timer.CurrentSplit.SplitTime.GameTime); 
					}
					else
					{
						vars.SplitTimer();
						
						if (settings["Set game time on the main split when mission is complete"])
						{
							// Set the time on the main split (the one with the mission name)
							var sectionFound = timer.Run.FirstOrDefault(section => section.Name == vars.sceneName);
							if (sectionFound == null)
							{
								vars.DebugOutput("ERROR: Couldn't find a split with the name " + vars.sceneName);
							}
							else
							{
								var segment = (LiveSplit.Model.Segment)sectionFound;
								var gameTime = timer.CurrentTime.GameTime - vars.gameTimeOnSceneStart;
								segment.SplitTime = new Time(realTime: null, gameTime: gameTime);

								vars.DebugOutput("Set game time for split " + segment.Name + " to " + segment.SplitTime.GameTime + ".");
							}
						}
					}

					// Save all times to be compared to later.
					vars.DebugOutput("Saving times.");
					vars.timerModel.UpdateTimes();
				}
			}
			
			if (settings["Save game log copy when mission ends"] && !String.IsNullOrEmpty(vars.logPath))
			{
				try
				{
					string time = System.DateTime.Now.ToString("yyyy-MM-dd_HH_mm");
					
					var appDataDir = System.Environment.GetEnvironmentVariable("appdata");
					System.IO.DirectoryInfo dirInfo = new DirectoryInfo(appDataDir + "/../LocalLow");
					var localLowDir = dirInfo.FullName;
					
					var newFilename = System.IO.Path.Combine(
						localLowDir, 
						@"Vertigo Games\AfterTheFall\LiveSplit_" + time + "_" + vars.sceneName + ".Player.log.");
						
					vars.DebugOutput("Saving a copy of the current game log file as [" + newFilename + "].");
					File.Copy(vars.logPath, newFilename);
				}
				catch (Exception ex)
				{
					vars.DebugOutput("Error: Couldn't save a copy of the log file: " + ex.ToString());
				}
			}
			
			return false; 
		}

		match = vars.regexes["InitializingMapVoteScreen"].Match(currLine);
		if (match.Success)
		{
			if (vars.sceneName == "Hub") 
			{
				vars.DebugOutput("Not jumping to the Limbo section, since currently in the Hub.");	
				continue;
			}

			// Moving to the limbo to vote on maps
			var endResult = match.Groups[1].Value;
			
			vars.DebugOutput("Jumping to the Limbo section. End result of the run was: " + endResult);

			// Junp to the Limbo section
			timer.CurrentSplitIndex = 1;
			vars.sceneName = "Limbo";
			continue;
		}

		match = vars.regexes["DifficultyChanged"].Match(currLine);
		if (match.Success)
		{
			// Moving to the limbo to vote on maps
			var newDifficulty = match.Groups[1].Value;
			vars.DebugOutput("Difficulty changed to: " + newDifficulty);
			vars.SetDifficultyText(newDifficulty);

			continue;
		}

		match = vars.regexes["PartyUpdated_Start"].Match(currLine);
		if (match.Success)
		{
			// Found the start of a party update message (happens when players join or leave the party)
			//vars.DebugOutput("Found the start of a party update message.");
			//vars.DebugOutput(currLine);

			// Read until reaching the end of the message
			var fullMessage = vars.ReadLinesUntilMatch(vars.logFileReader, vars.regexes["PartyUpdated_End"]);
			if (fullMessage == null)
			{
				vars.DebugOutput("ERROR: message returned was null.");	
				continue;
			}

			//vars.DebugOutput("Full message: " + fullMessage); 

			// Get players' names from the message
			var playerInfoMatches = vars.regexes["PartyUpdated_PlayerInfo"].Matches(fullMessage);
			if (playerInfoMatches == null || playerInfoMatches.Count == 0)
			{
				vars.DebugOutput("WARNING: Couldn't parse player information from message. Probably just left party.");
				continue;
			}

			//vars.DebugOutput("playerInfoMatches.Count: " + playerInfoMatches.Count);

			var displayNames = new List<string>();
			for	(int currIndex = 0 ; currIndex < playerInfoMatches.Count ; currIndex++)
			{
				var currPlayerMatch = playerInfoMatches[currIndex];
				displayNames.Add(currPlayerMatch.Groups[1].Value);
			}

			vars.SetPlayersDisplayNames(displayNames);
			continue;
		}

		match = vars.regexes["Horde_StartingRound"].Match(currLine);
		if (match.Success)
		{
			// Split every 5 rounds (on round 1, 6, 11, 16 etc.)
			var waveNumber = int.Parse(match.Groups[1].Value);
			vars.DebugOutput("Starting new wave (" + waveNumber + "). timer.CurrentTime: " + timer.CurrentTime);
			if (waveNumber > 5 && waveNumber % 5 == 1)
				vars.SplitTimer();
		}

		#endregion // Find known lines
	}
	
	// No recognized line was found.
	return false;
}

exit
{
	if (settings["Save game log copy after game is closed"] && !String.IsNullOrEmpty(vars.logPath))
	{
		try
		{
			string time = System.DateTime.Now.ToString("yyyy-MM-dd_HH_mm");
			
			var appDataDir = System.Environment.GetEnvironmentVariable("appdata");
			System.IO.DirectoryInfo dirInfo = new DirectoryInfo(appDataDir + "/../LocalLow");
			var localLowDir = dirInfo.FullName;
			
			var newFilename = System.IO.Path.Combine(localLowDir, @"Vertigo Games\AfterTheFall\LiveSplit_" + time + ".Player.log.");
			vars.DebugOutput("Saving a copy of the current game log file as [" + newFilename + "].");
			File.Copy(vars.logPath, newFilename);
		}
		catch (Exception ex)
		{
			vars.DebugOutput("Error: Couldn't save a copy of the log file: " + ex.ToString());
		}
	}
	
	if (timer.CurrentPhase == TimerPhase.Running)
		vars.PauseGameTime("Game was closed");
	
	if (vars.logFileReader != null)
	{
		vars.logFileReader.Dispose();
		vars.logFileReader = null; // Free the lock on the logfile, so folders can be renamed/etc.
	}
}