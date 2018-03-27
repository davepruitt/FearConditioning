function FearConditioning_V3_2 ( debug_mode )

    if (nargin < 1)
        debug_mode = 0;
    end

    %Initialize the behavior session state to be 0 (not running)
    global run;
    run = 0;

    %Set the URL for the Google Docs stage spreadsheet.
    %url = 'https://docs.google.com/spreadsheets/d/1dC5XCbhtVAIS2ZHhFVlgdRLpfU5lUbNUcoYgYCt-IzA/pub?output=tsv';  
    url = 'https://docs.google.com/spreadsheets/d/1a5Nl9cHM6SL30kVFMivb3iiXoGOKciewjXocmwyJHIs/pub?output=tsv';

    %Make the graphical user interface
    handles = Make_GUI();

    %Download the stage information from the Google Docs Spreadsheet.
    stages = GetStageInfo(url);
    if (isempty(stages))
        %If no stages were found, indicate as such on the start button.
        set(handles.start_button, 'string', 'No stages found');
    else
        %Populate the stage drop-down box
        stage_descriptions = cell(1, length(stages));
        for i = 1:length(stages)
            stage_descriptions(i) = cellstr(stages(i).description);
        end
        set(handles.stage_selection_box, 'string', stage_descriptions);
    end
    
    %Set the stages in the handles structure
    handles.stages = stages;
    
    %Connect to the arduino board
    handles.ardy = FearConditioning_Connect;   
    
    %Create some variables
    handles.rat_name = '';
    handles.require_rat_name_change = 1;
    handles.require_rat_stage_change = 1;
    handles.ardy_connected = ~isempty(handles.ardy);
    handles.no_ardy_debug_mode = debug_mode;

    %Initialize some variables and paths here where they'll be easier to find and change.

    %Set the primary local data path for saving data files.
    handles.datapath = 'C:\AFC\';                                         

    %If the primary local data path doesn't already exist...
    if ~exist(handles.datapath,'dir')                                           
        %Create the directory
        mkdir(handles.datapath);                                                
    end

    %Set the secondary server data path for saving data files.
    handles.serverpath = 'Z:\Konstanty_Behavior_Data\';                             
    
    %If an arduino connection was created
    if (handles.ardy_connected)
        %Disable music on the arduino
        handles.ardy.enable_music(0);

        %Set the name of the booth in the GUI
        booth_num = handles.ardy.booth();
        set(handles.boothname, 'string', num2str(booth_num));

        %Pause for 100ms to allow for initialization
        pause(0.1);                                                                 
    else
        set(handles.start_button, 'string', 'Not connected');
    end
    
    %Save the handles to the figure
    guidata(handles.fig, handles);    

end

%% This function executes when the Start button is pressed
function RunBehavior(handles)

    global run;
    global vid;
    
    %Open a file to save the video
    if (strcmpi(handles.record_video, 'on'))
        %BeginVideo(handles);
    end
    
    %Get the amount of extra time to be appended to both the beginning and the end of the session
    extra_time = handles.extra_time;
    
    %Get the sound number for the sound being used during this behavior
    %session
    sound_number = GetSoundNumber(handles.soundname);
    
    %Get the approximate duration of the sound being played during this
    %session (multiply by 1000 for units of ms)
    sound_duration = GetSoundDuration(handles.soundname) * 1000;
    
    %Get the VNS duration of this stage
    vns_duration = handles.vns_duration;
    
    %Calculate the total number of sounds to play
    total_sounds = handles.num_presounds + handles.num_sounds;
    
    %Decide on times to play each sound
    sound_intervals = randi([handles.isimin handles.isimax], 1, total_sounds) + (extra_time / 1000);
    
    %Create a schedule to play each sound (multiply by 1000 to convert to units of ms)
    sound_schedule = cumsum(sound_intervals) * 1000;
    
    %Create a schedule of END TIMES for each sound
    sound_schedule_end_times = sound_schedule + sound_duration;
    
    %Now, let's choose which sounds to pair with shocks
    which_sounds_to_pair = [];
    
    if (strcmpi(handles.shocktype, 'Random'))
        %Randomly choose a set of sounds to pair with shocks
        rand_perm_of_sounds = randperm(handles.num_sounds);
        total_shocks = min(handles.num_shocks, handles.num_sounds);
        which_sounds_to_pair = sort(rand_perm_of_sounds(1:total_shocks));
    elseif (strcmpi(handles.shocktype, 'Front'))
        %Pair the first N sounds with shocks
        sounds_array = 1:handles.num_sounds;
        total_shocks = min(handles.num_shocks, handles.num_sounds);
        which_sounds_to_pair = sounds_array(1:total_shocks);
    elseif (strcmpi(handles.shocktype, 'Back'))
        %Pair the last N sounds with shocks
        sounds_array = 1:handles.num_sounds;
        total_shocks = min(handles.num_shocks, handles.num_sounds);
        which_sounds_to_pair = sounds_array(end-total_shocks+1:end);
    end
    
    %Now choose actual times at which to play the sounds
    timings_of_non_pre_sounds = sound_schedule(end-handles.num_sounds+1:end);
    timings_of_paired_sounds = timings_of_non_pre_sounds(which_sounds_to_pair);
    
    %Choose actual times for each shock (calculated as an offset from sound onset)
    shock_schedule = nan(1, length(timings_of_paired_sounds));
    for t = 1:length(timings_of_paired_sounds)
        shock_schedule(t) = timings_of_paired_sounds(t) + randi([handles.shockonsetmin handles.shockonsetmax]);
    end
    
    %Now, let's calculate when to do VNS
    vns_schedule = [];
    which_sounds_to_pair_vns = [];
    is_vns_on = ~strcmpi(handles.vns_type, 'Off');
    if (is_vns_on && handles.vns_stim_count > 0)        

        if (strcmpi(handles.vns_type, 'Unpaired'))
            
                %In "Unpaired" mode, the VNS stim schedule is calculated independent of the sound and shock schedule.
                %The interval between VNS stims uses the same interval as the sounds use (isimin and isimax).
            
                %Decide on times to deliver VNS
                vns_intervals = randi([handles.isimin handles.isimax], 1, handles.vns_stim_count);
    
                %Create a schedule to deliver VNS (multiply by 1000 to convert to units of ms)
                vns_schedule = cumsum(vns_intervals) * 1000;
                
        else
            
            %If the stims are not "unpaired", then they are likely "paired". There are a few choices for "paired" stimulation.
            %"Paired Front" will pair sounds with VNS, starting with the very first sound in the sound schedule (like a left-justify in text editing)
            %"Paired Back" will pair sounds with VNS, but will "right-justify" them, so that the last VNS is paired with the last sound.
            %"Paired Random" will choose randomly from among the set of sounds to be played and pair VNS with that random selection.
            %"Centered Between (First Before)" will act like "Paired Front", but VNS stims will 
            
            %Check to see if the stage specifies a "paired" form of VNS
            if (strcmpi(handles.vns_type, 'Paired Front'))
                sounds_array = 1:handles.num_sounds;
                total_stims = min(handles.vns_stim_count, handles.num_sounds);
                which_sounds_to_pair_vns = sounds_array(1:total_stims);
            elseif (strcmpi(handles.vns_type, 'Paired Back'))
                sounds_array = 1:handles.num_sounds;
                total_stims = min(handles.vns_stim_count, handles.num_sounds);
                which_sounds_to_pair_vns = sounds_array(end - total_stims+1:end);
            elseif (strcmpi(handles.vns_type, 'Paired Random'))
                rand_perm_of_sounds = randperm(handles.num_sounds);
                total_stims = min(handles.vns_stim_count, handles.num_sounds);
                which_sounds_to_pair_vns = sort(rand_perm_of_sounds(1:total_stims));
            end
            
            %For sounds that contain multiple VNS stims, calculate the interval between stims
            intervals_between_single_sound_stims = sound_duration / handles.stims_per_sound;
            
            %Calculate the base VNS timings
            timings_of_paired_vns_sounds = timings_of_non_pre_sounds(which_sounds_to_pair_vns);
            
            %Now let's offset VNS by a constant amount if the user has requested a VNS delay/offset
            if (any(isletter(handles.vns_delay)))
                %Handle the case where the user has specified a categorical VNS delay/offset, such as centered VNS stims between sounds
                if (strcmpi(handles.vns_delay, 'centered after'))
                    ends_of_each_sound = timings_of_paired_vns_sounds + sound_duration;
                    intervals_between_sounds = [timings_of_paired_vns_sounds Inf] - [0 ends_of_each_sound];
                    
                    %Remove the first interval, which is bogus
                    if (length(intervals_between_sounds) > 1)
                        intervals_between_sounds = intervals_between_sounds(2:end);
                    end
                    
                    %The last interval, which is "Infinity", will be set to the mean of all of the other intervals
                    if (length(intervals_between_sounds) > 1)
                        if (isinf(intervals_between_sounds(end)))
                            intervals_between_sounds(end) = nanmean(intervals_between_sounds(1:end-1));
                        end
                    end
                    
                    %Calculate the timings
                    if (length(ends_of_each_sound) == length(intervals_between_sounds))
                        timings_of_paired_vns_sounds = ends_of_each_sound + (intervals_between_sounds / 2) - (sound_duration / 2);
                    end
                    
                elseif (strcmpi(handles.vns_delay, 'centered before'))
                    ends_of_each_sound = timings_of_paired_vns_sounds + sound_duration;
                    intervals_between_sounds = [timings_of_paired_vns_sounds Inf] - [0 ends_of_each_sound];
                    
                    %Remove the last interval, which is bogus
                    if (length(intervals_between_sounds) > 1)
                        intervals_between_sounds = intervals_between_sounds(1:end-1);
                    end
                    
                    %The first interval will be set to the mean of all of the other intervals
                    if (length(intervals_between_sounds) > 1)
                        intervals_between_sounds(1) = nanmean(intervals_between_sounds(2:end));
                    end
                    
                    %Calculate the timings
                    if (length(ends_of_each_sound) == length(intervals_between_sounds))
                        timings_of_paired_vns_sounds = timings_of_paired_vns_sounds - (intervals_between_sounds / 2) - (sound_duration / 2);
                    end
                    
                    %If the first VNS is less than 0, we need to offset the ENTIRE session so that the first VNS is >= 0
                    if (timings_of_paired_vns_sounds(1) < 0)
                        vns_offset_below_zero = abs(timings_of_paired_vns_sounds(1));
                        
                        %Offset the sounds
                        sound_schedule = sound_schedule + vns_offset_below_zero;
                        
                        %Offset the shocks
                        shock_schedule = shock_schedule + vns_offset_below_zero;
                        
                        %Offset the VNS times
                        timings_of_paired_vns_sounds = timings_of_paired_vns_sounds + vns_offset_below_zero;
                    end
                end
            end
            
            %Now calculate the final VNS timings based on sounds that contain multiple stims
            final_vns_timings = [];
            for i = 1:length(timings_of_paired_vns_sounds)
                
                %Calculate the offset of each stim by evenly spacing them within the duration of the sound
                new_vns_timings = timings_of_paired_vns_sounds(i) * ones(1, handles.stims_per_sound);
                offset_array = 0:(handles.stims_per_sound-1);
                offset_array = offset_array .* intervals_between_single_sound_stims;
                new_vns_timings = new_vns_timings + offset_array;
                
                final_vns_timings = [final_vns_timings new_vns_timings];
            end
            
            %Determine the VNS schedule
            timings_of_paired_vns_sounds = sort(final_vns_timings);
            vns_schedule = nan(1, length(timings_of_paired_vns_sounds));
            
            if (~any(isletter(handles.vns_delay)))
                %Handle the case where the user has specified a numeric VNS delay/offset
                for t = 1:length(timings_of_paired_vns_sounds)
                    vns_schedule(t) = timings_of_paired_vns_sounds(t) + handles.vns_delay;
                end
            else
                vns_schedule = timings_of_paired_vns_sounds;
            end
            
        end
        
    end
    
    %Start a timer
    tic;
    
    %Plot the schedule to the GUI window
    PlotSchedule(handles.session_axes, shock_schedule, handles.shockdur, sound_schedule, sound_duration, vns_schedule, handles.vns_duration, extra_time, 0);
    
    %Create copies of the sound and shock schedule that we can manipulate
    %during the session
    sound_schedule_queue = sound_schedule;
    sound_schedule_end_time_queue = sound_schedule_end_times;
    shock_schedule_queue = shock_schedule;
    vns_schedule_queue = vns_schedule;
    
    is_music_enabled = 0;
    time_of_last_music_enable = 0;
    is_sound_playing = 0;
    current_sound_end_time = 0;
    is_shock_occurring = 0;
    current_shock_end_time = 0;
    is_vns_occurring = 0;
    vns_end_time = 0;
    current_time = 0;
    
    extra_time_started = 0;
    extra_time_done = 0;
    extra_time_start = 0;
    
    %Open the data file
    fid = WriteFileHeader(handles);
    
    %Loop while the session is running
    while (run == 1)
        
        loop_start = toc;
        
        %Display image
        %colorImage = getsnapshot(vid);
        %grayImage = rgb2gray(colorImage);
        %imshow(grayImage, 'Parent', handles.webcam_axes, 'Border', 'tight');
        
        %Save this frame to the video
        if (strcmpi(handles.record_video, 'on'))
            %WriteFrames(is_sound_playing, is_shock_occurring, is_vns_occurring, current_time);
        end
        
        %If we are completely done playing sounds AND delivering shocks...
        if (isempty(sound_schedule_queue) && isempty(shock_schedule_queue) && isempty(vns_schedule_queue) && ...
            ~is_sound_playing && ~is_shock_occurring && ~is_vns_occurring)
        
            if (~extra_time_started)
                extra_time_started = 1;
                extra_time_start = current_time;
            else
                %Check to see if the extra time has been expended
                extra_time_expended = current_time - extra_time_start;
                if (extra_time_expended > handles.extra_time)
                    extra_time_done = 1;
                end
                
                if (extra_time_done)
                    %Then set the run-state to be 0.  We are finished here.
                    run = 0;
                end
            end
        
            
        end
        
        %Get the current time from the timer (and multiply by 1000 to get
        %it in units of ms)
        current_time = toc * 1000;
        %disp(current_time);
        
        %Disable sound if it has been enabled for over 200 ms since a sound
        %being started (this does not affect sounds currently playing)
        if (is_music_enabled && ((current_time - time_of_last_music_enable) > 200))
            if (~handles.no_ardy_debug_mode)
                handles.ardy.enable_music(0);
            end
            is_music_enabled = 0;
        end
        
        %Check to see if a sound is happening right now.
        if (is_sound_playing)
            %If the sound has expired, toggle the GUI
            if (current_time >= current_sound_end_time)
                is_sound_playing = 0;
                ToggleSoundTextBlockColor(handles, is_sound_playing);
                if (~handles.no_ardy_debug_mode)
                    handles.ardy.music_led_disable();
                end
            end
        end
        
        %Check to see if a shock is happening right now
        if (is_shock_occurring)
            if (current_time >= current_shock_end_time)
                if (~handles.no_ardy_debug_mode)
                    handles.ardy.shock_enable(0);
                end
                is_shock_occurring = 0;
                ToggleShockTextBlockColor(handles, is_shock_occurring);
            end
        end
        
        %Check to see if VNS is occurring right now
        if (is_vns_occurring)
            if (current_time >= vns_end_time)
                is_vns_occurring = 0;
                ToggleVNSTextBlockColor(handles, is_vns_occurring);
                if (~handles.no_ardy_debug_mode)
                    handles.ardy.VNS_led_disable();
                end
            end
        end
        
        %Check to see if it is time to play a new sound
        if (~isempty(sound_schedule_queue))
            if (current_time >= sound_schedule_queue(1))
                %Play a sound
                if (~handles.no_ardy_debug_mode)
                    handles.ardy.select_tone(sound_number);
                    handles.ardy.enable_music(1);
                end
                
                is_music_enabled = 1;
                time_of_last_music_enable = current_time;
                
                %Toggle the text box in the GUI that shows sound is playing
                is_sound_playing = 1;
                current_sound_end_time = sound_schedule_end_time_queue(1);
                ToggleSoundTextBlockColor(handles, is_sound_playing);
                WriteSessionEvent(fid, 'Sound', handles.soundname);
                
                %Dequeue the first element of the list
                sound_schedule_queue(1) = [];
                sound_schedule_end_time_queue(1) = [];
            end
        end
        
        %Check to see if it is time to deliver a new shock
        if (~isempty(shock_schedule_queue))
            if (current_time >= shock_schedule_queue(1))
                %Deliver the shock
                if (~handles.no_ardy_debug_mode)
                    handles.ardy.shock_enable(1);
                end
                is_shock_occurring = 1;
                current_shock_end_time = current_time + handles.shockdur;
                ToggleShockTextBlockColor(handles, is_shock_occurring);
                WriteSessionEvent(fid, 'Shock', '');
                
                %Dequeue the first element of the list
                shock_schedule_queue(1) = [];
            end
        end
        
        %Check to see if it is time to deliver a new VNS stim
        if (~isempty(vns_schedule_queue))
            if (current_time >= vns_schedule_queue(1))
                %Deliver the VNS
                if (~handles.no_ardy_debug_mode)
                    handles.ardy.vns_enable();
                end
                
                is_vns_occurring = 1;
                vns_end_time = current_time + handles.vns_duration;
                ToggleVNSTextBlockColor(handles, is_vns_occurring);
                WriteSessionEvent(fid, 'VNS', '');
                
                %Dequeue the first element of the list
                vns_schedule_queue(1) = [];
            end
        end
       
        %Plot the session as it currently is
        PlotSchedule(handles.session_axes, shock_schedule, handles.shockdur, sound_schedule, sound_duration, vns_schedule, handles.vns_duration, extra_time, current_time);
        
        loop_end = toc;
        
        loop_difference = loop_end - loop_start;
        %disp(num2str(loop_difference));
        
        %Pause momentarily (33 ms) so we don't hog the processor
        pause(0.033);
        
    end

    %Close the video file for writing
    if (strcmpi(handles.record_video, 'on'))
        %StopVideo();
    end
    
    %Output the total number of seconds that has elapsed during this session.
    WriteSessionEvent(fid, 'Total Session Time', num2str(current_time / 1000));

    %Close the data file
    fclose(fid);

end

%% This function is called when the edit rat text box is modified
function EditRat(hObject, eventdata)
    
    handles = guidata(hObject);
    
    temp_rat_name = get(handles.rat_edit_box, 'string');
    
    %Step through all reserved characters.
    for c = '/\?%*:|"<>. '                                                      
        %Kick out any reserved characters from the rat name.
        temp_rat_name(temp_rat_name == c) = [];                                                   
    end

    %If the rat's name was changed.
    if (~strcmpi(temp_rat_name, handles.rat_name))
        %Save the new rat_name
        handles.rat_name = upper(temp_rat_name);
        
        %Display in the Matlab command window that the rat name has been
        %changed
        disp([datestr(now,13) ' - Current rat is ' handles.rat_name '.']);
    end
    
    %Set a flag indicating the the rat name has been changed
    handles.require_rat_name_change = 0;
    SetStartButtonState(handles);
    
    %Change the name in the GUI
    set(handles.rat_edit_box, 'string', handles.rat_name)

    %Save the handles
    guidata(handles.fig, handles);

end

%% This function is called when you edit the stage
function EditStage(hObject, eventdata)
    
    handles = guidata(hObject);
    
    %Get the selected stage index and name
    temp = get(handles.stage_selection_box, 'Value');
    temp_str = get(handles.stage_selection_box, 'String');
    temp_str = temp_str{temp};
    
    %Now set all variables to selected stage variables
    x = handles.stages(temp);
    y = fields(handles.stages);
    
    %Loop through the fields of stage struct
    for j = 1:length(y)
        handles.(y{j}) = handles.stages(temp).(y{j});
    end
    
    %Display a message in the Matlab editor indicating that the stage has
    %been changed
    disp([datestr(now,13) ' - Current stage is ' temp_str '.']);                         

    %Set a flag indicating the the stage has been changed
    handles.require_rat_stage_change = 0;
    SetStartButtonState(handles);
    
    guidata(handles.fig, handles);

end

%% This function is called when the start / stop button is pressed
function StartButton(hObject, eventdata)

    global run;
    handles = guidata(hObject);
    
    if run == 0
        
        %Verify that we can actually start the behavior session.
        go = VerifyStart(handles);
        
        %If everything looks good, start behavior
        if (go)
            %Set the text of the button to say "Stop", and change the color to
            %red
            set(handles.start_button, 'string', 'Stop');
            set(handles.start_button, 'foregroundcolor', [1 0 0]);

            %Disable editing of the rat and stage while the session is running
            set(handles.rat_edit_box, 'enable', 'off');                                      
            set(handles.stage_selection_box, 'enable', 'off');

            %Set the run state
            run = 1;
            
            %Clear the session axes for the upcoming session
            cla(handles.session_axes);
            hold(handles.session_axes, 'off');

            %Run the behavior program
            RunBehavior(handles);
            
            %Edit the session axes title to indicate the session has finished
            session_axes_title = get(handles.session_axes, 'title');
            title_text = session_axes_title.String;
            title(handles.session_axes, ['SESSION ENDED --- ' title_text], 'Color', [1 0 0]);

        end
    
    end
    
    % The rest of this code gets executed under 2 conditions:
    % (1) The "Stop" button is pressed
    % (2) The session finishes due to reaching the end of its sound/shock
    % schedule.
    
    %If the user clicked "Stop", change the text to say "Start", and
    %the color to be green
    set(handles.start_button, 'string', 'Start');
    set(handles.start_button, 'foregroundcolor', [0 0.7 0]);

    %Allow the rat name and stage to be edited again
    set(handles.rat_edit_box, 'enable', 'on');                                      
    set(handles.stage_selection_box, 'enable', 'on');

    %Set the flags indicating that the rat name and stage must be
    %changed
    handles.require_rat_name_change = 1;
    handles.require_rat_stage_change = 1;

    %Set the start button state
    SetStartButtonState(handles);

    %Set the run state to 0, indicating that the session has stopped.
    run = 0;
    
    %Save the handles structure
    guidata(handles.fig, handles);

end

%% This function makes our GUI
function handles = Make_GUI(handles)

    set(0,'units','centimeters');
    pos = get(0,'screensize');  
    h = 22;%0.8*pos(4);
    w = 4*h/3;  

    figure_color = [1 1 1];

    %Create the main figure window
    handles.fig = figure(...
        'name', 'Auditory Fear Conditioning', ...
        'units', 'centimeters', ...
        'Position', [pos(3)/2-w/2, pos(4)/2-h/2, w*0.7, h*0.7], ...
        'Color', figure_color, ...
        'Menubar', 'none', ...
        'Resize', 'off');
    
    %Create the primary vertical stack panel for this figure
    primary_panel = uix.VBox( ...
        'parent', handles.fig, ...
        'Spacing', 10, ...
        'Padding', 10, ...
        'BackgroundColor', figure_color);

    %Place a text block at the top with the title of the program
    handles.programlabel = uicontrol( ...
        'parent', primary_panel, ...
        'style', 'text', ...
        'string', 'Arduino Fear Conditioning V3.2', ...
        'fontweight', 'bold', ...
        'fontsize', 18, ...
        'horizontalalignment', 'center', ...
        'backgroundcolor', figure_color, ...
        'foregroundcolor', [0 0 0]);                    

    %Create a one-row grid for the rat name and booth name
    ui_stack_panel = uix.HBox('Parent', primary_panel, ...
        'BackgroundColor', figure_color, ...
        'Spacing', 20, ...
        'Units', 'normalized', ...
        'Spacing', 0.05);

    uicontrol('parent', ui_stack_panel, 'visible', 'off');

    %Create labels and text boxes for the rat name and booth name
    %Rat name label and text box
    handles.ratlabel = uicontrol( ...
        'parent', ui_stack_panel, ...
        'style', 'text', ...
        'string', 'Rat:', ...
        'units', 'normalized', ...
        'fontweight', 'bold', ...
        'fontsize', 20, ...
        'horizontalalignment', 'center', ...
        'backgroundcolor', get(handles.fig, 'color'));                    
    handles.rat_edit_box = uicontrol( ...
        'parent', ui_stack_panel, ...
        'Style', 'edit', ...
        'String', '', ...
        'units', 'normalized', ...
        'fontsize', 16);

    %Booth name label and edit box
    handles.boothlabel = uicontrol( ...
        'parent', ui_stack_panel, ...
        'style', 'text', ...
        'string', 'Booth:', ...
        'units', 'normalized', ...
        'fontweight', 'bold', ...
        'fontsize', 20, ...
        'horizontalalignment', 'center', ...
        'backgroundcolor', get(handles.fig, 'color'));                    
    handles.boothname = uicontrol( ...
        'parent', ui_stack_panel, ...
        'Style', 'text', ...
        'String', '', ...
        'units', 'normalized', ...
        'fontsize', 16, ...
        'backgroundcolor', figure_color);

    uicontrol('parent', ui_stack_panel, 'visible', 'off');

    %Set the width of each element in the rat/booth stack panel
    set(ui_stack_panel, 'Widths', [-0.5 -1 -1.5 -1 -1.5 -0.5]);

    %Create a drop-down box for the stage selection
    stage_selection_stack_panel = uix.HBox('parent', primary_panel, ...
        'BackgroundColor', figure_color);

    handles.stagelabel = uicontrol( ...
        'parent', stage_selection_stack_panel, ...
        'style', 'text', ...
        'string', 'Stage:', ...
        'fontweight', 'bold', ...
        'fontsize', 20, ...
        'horizontalalignment', 'center', ...
        'backgroundcolor', figure_color);

    handles.stage_selection_box = uicontrol( ...
        'parent', stage_selection_stack_panel, ...
        'Style', 'popupmenu', ...              
        'String', 'No stages', ...
        'units', 'normalized', ...
        'Value', 1, ...
        'fontsize', 16);

    set(stage_selection_stack_panel, 'Widths', [-1 -4]);

    %Create the start button
    handles.start_button = uicontrol( ...
        'parent', primary_panel, ...
        'style', 'pushbutton', ...
        'string', 'Start', ...
        'horizontalalignment', 'center', ...
        'fontsize', 32, ...
        'foregroundcolor', [0 0.7 0], ...
        'fontweight', 'bold', ...
        'enable', 'off');

    %Create text areas that will be used to indicate when VNS, tones, and
    %shocks are happening

    vns_tone_shock_stack_panel = uix.HBox('parent', primary_panel, 'Spacing', 10);

    handles.vns_state_text = uicontrol( ...
        'parent', vns_tone_shock_stack_panel, ...
        'style', 'text',...
        'string', 'VNS',...
        'horizontalalignment', 'center',...
        'fontsize', 24, ...
        'foregroundcolor', [0 0.7 0], ...
        'fontweight', 'bold', ...
        'backgroundcolor', [0.1 0.1 0.1]);  
    handles.tone_state_text = uicontrol( ...
        'parent', vns_tone_shock_stack_panel, ...
        'style', 'text', ...
        'string', 'Sound', ...
        'horizontalalignment', 'center', ...
        'fontsize', 24, ...
        'foregroundcolor', [0 0.7 0], ...
        'fontweight', 'bold', ...
        'backgroundcolor', [0.1 0.1 .1]);  
    handles.shock_state_text = uicontrol( ...
        'parent', vns_tone_shock_stack_panel, ...
        'style', 'text', ...
        'string', 'Shock', ...
        'horizontalalignment', 'center', ...
        'fontsize', 24, ...
        'foregroundcolor', [0 0.7 0], ...
        'fontweight', 'bold', ...
        'backgroundcolor', [0.1 0.1 0.1]); 

    set(vns_tone_shock_stack_panel, 'Widths', [-1 -1 -1]);
    
    axes_horizontal_panel = uix.HBox( ...
        'parent', primary_panel, ...
        'Spacing', 10, ...
        'Padding', 10, ...
        'BackgroundColor', figure_color);
    
    %Create a webcam image slot
    %handles.webcam_axes = axes('parent', axes_horizontal_panel);
    %handles.webcam_image = image(zeros(640, 480, 3), 'Parent', handles.webcam_axes);
    %set(handles.webcam_axes, 'Box', 'off');
    
    %Create a session plot
    handles.session_axes = axes('parent', axes_horizontal_panel);
    set(handles.session_axes, 'YLim', [0.5 3.5]);
    set(handles.session_axes, 'YTick', [1 2 3]);
    set(handles.session_axes, 'YTickLabel', {'Shocks', 'Sounds', 'VNS'});
    
    %Set the height of the axes panel
    %set(axes_horizontal_panel, 'Widths', [-1 -2]);
    
    %Set the heights of each element of the primary vertical stack panel layout
    set(primary_panel, 'Heights', [30 30 40 80 40 200]);
    
    %Set callback functions for the start button, the rat edit box, and the
    %stage selection box
    set(handles.start_button, 'callback', @StartButton);                        
    set(handles.rat_edit_box, 'callback', @EditRat);
    set(handles.stage_selection_box, 'callback', @EditStage);
    
    %Save all of the panels for future use
    handles.panels = [primary_panel ui_stack_panel stage_selection_stack_panel vns_tone_shock_stack_panel];
    
end

%% This function reads in the stages information for the Google Docs stages spreadsheet.
function stages = GetStageInfo(url)

    %Initialize urldata to be an empty array
    urldata = [];
    stages = [];

    %Try to read in the stages information from the web.
    try                                                                         
        
        %Load the stage information from the google spreadsheet
        urldata = Read_Google_Spreadsheet_Lindsey(url);
        
        %Save a backup of the stage information to a local file
        try
            Save_Local_Spreadsheet(urldata, 'fear_stages.txt');
        catch err3
            disp('Was not able to save backup stage spreadsheet!');
        end
        
    catch err                                                                   
        %If there's an error, first tell the user
        disp('Could not read Google Spreadsheet!');
        
        %Attempt to read the local backup spreadsheet
        try
            backup_spreadsheet = 'fear_stages.txt';
            urldata = Read_Local_Spreadsheet(backup_spreadsheet);
        catch err2
            %Warn the user about the error
            disp('Could not read the local spreadsheet!');
            
            %And then return from the function
            return;
        end
    end

    %List the column headings with their associated stages structure fields.
    fields = {'stage','number';...
        'description','description';...
        'Program Type','program';...
        'Sound Name 1', 'soundname';...
        'Sound Name 2', 'soundnameb';...
        'Number of Presounds','num_presounds';...
        'number of sounds','num_sounds';...
        'inter-sound interval minimum (seconds)','isimin';...
        'inter-sound interval maximum (seconds)','isimax';...
        'number of shocks','num_shocks';...
        'shock duration (ms)','shockdur';...
        'Shock Delivery Type', 'shocktype'; ...
        'Shock Onset Minimum (ms)', 'shockonsetmin';...
        'Shock Onset Maximum (ms)', 'shockonsetmax';...
        'Number of VNS Stims','vns_stim_count'; ...
        'Type of VNS', 'vns_type'; ...
        'VNS Delay (ms)', 'vns_delay'; ...
        'VNS Duration', 'vns_duration'; ...
        'Record Video', 'record_video'; ...
        'Extra Time', 'extra_time'; ...
        'Stims Per Sound', 'stims_per_sound' ...
        };

    %Step through each column heading.
    for c = 1:size(fields,1)                                                    
        
        %Find the column index for this column heading.
        a = strncmpi(fields{c,1},urldata(1,:),length(fields{c,1}));             
        
        %Step through each listed stages.
        for i = 2:size(urldata,1)                                               
            %Grab the entry for this stages.
            temp = urldata{i,a};
            
            %Kick out any apostrophes in the entry.
            temp(temp == 39) = [];                 
            
            %If there's any text characters in the entry...
            if any(temp > 59)                   
                %Save the field value as a string.
                stages(i-1).(fields{c,2}) = temp;                                
            else                                                              
                %Otherwise, if there's no text characters in the entry.
                %Evaluate the entry and save the field value as a number.
                stages(i-1).(fields{c,2}) = str2double(temp);                    
            end
        end
    end
    
    %Step through the stagess.
    for i = 1:length(stages)
        %Add the stage number to the stage description.
        stages(i).description = [stages(i).number ': ' stages(i).description];     
    end

end

%% Enable/Disable the start button as necessary
function SetStartButtonState ( handles )

    if (~handles.require_rat_name_change && ~handles.require_rat_stage_change && ...
            ~isempty(handles.stages))
        if (handles.no_ardy_debug_mode || handles.ardy_connected)
            set(handles.start_button, 'enable', 'on');
        end
    else
        set(handles.start_button, 'enable', 'off');
    end

end

%% Checks to see if the sound file selected is valid
function valid_sound = IsValidSoundFile ( sound_name )

    if (any(strcmpi(sound_name, {'war zone (30 seconds)', 'gunfire', 'twitter', '9khz', '4khz', '2khz10s', '9khz10s'})))
        valid_sound = 1;
    else
        valid_sound = 0;
    end

end

%% Gets the number associated with a sound file
function sound_number = GetSoundNumber ( sound_name )
    sound_number = 0;
    if (strcmpi(sound_name, 'war zone (30 seconds)'))
        sound_number = 6;
    elseif (strcmpi(sound_name, 'gunfire'))
        sound_number = 0;
    elseif (strcmpi(sound_name, 'twitter'))
        sound_number = 1;
    elseif (strcmpi(sound_name, '9khz'))
        sound_number = 2;
    elseif (strcmpi(sound_name, '4khz'))
        sound_number = 3;
    elseif (strcmpi(sound_name, '2khz10s'))
        sound_number = 4;
    elseif (strcmpi(sound_name, '9khz10s'))
        sound_number = 5;
    end
end

%% Gets the duration (in units of seconds) of a sound
function sound_duration = GetSoundDuration ( sound_name )

    %Declare the constants that are the durations for each sound
    sound_duration = 0;
    if (strcmpi(sound_name, 'war zone (30 seconds)'))
        sound_duration = 30;
    elseif (strcmpi(sound_name, 'gunfire'))
        sound_duration = 6;
    elseif (strcmpi(sound_name, 'twitter'))
        sound_duration = 6;
    elseif (strcmpi(sound_name, '9khz'))
        sound_duration = 6;
    elseif (strcmpi(sound_name, '4khz'))
        sound_duration = 6;
    elseif (strcmpi(sound_name, '2khz10s'))
        sound_duration = 6;
    elseif (strcmpi(sound_name, '9khz10s'))
        sound_duration = 6;
    end
    
end

%% This function verifies some parameters before the behavior session is allowed to start
function go = VerifyStart ( handles )

    %"Go" by default is a 1
    go = 1;

    %Make sure the sound name for the selected stage is valid
    if (~IsValidSoundFile(handles.soundname))
        disp('Please select correct sound type on stage spreadsheet!');
        go = 0;
    end
    
    %If a second sound is being used...
    if (~isnan(handles.soundnameb))
        %Make sure the second sound name is also valid
        if (~IsValidSoundFile(handles.soundnameb))
            disp('Please select correct sound type on stage spreadsheet!');
            go = 0;
        end
    end

    %Display some question dialogs to the user.
    %This will force undergrads to confirm the stage and the rat names.
    qstring = ['Are you sure animal ' handles.rat_name ' on stage ' handles.description '?'];
    choice = questdlg(qstring, 'Confirm Rat and Stage', 'Yes', 'No', 'No');
    if strcmpi(choice, 'No')
        go = 0;
    end

    if (go == 1)
        disp('Beginning behavior session');
    else
        disp('Problems have been encountered that must be checked before behavior can begin.');
    end
    
end

%% Toggles the background color of the "tone" text block
function ToggleSoundTextBlockColor ( handles, is_sound_playing )

    if (is_sound_playing)
        set(handles.tone_state_text, 'foregroundcolor', [1 0 0]);
        set(handles.tone_state_text, 'backgroundcolor', [0 0.7 0]);
    else
        set(handles.tone_state_text, 'foregroundcolor', [0 0.7 0]);
        set(handles.tone_state_text, 'backgroundcolor', [0 0 0]);
    end

end

%% Toggles the background color of the "shock" text block
function ToggleShockTextBlockColor ( handles, is_shock_happening )

    if (is_shock_happening)
        set(handles.shock_state_text, 'foregroundcolor', [1 0 0]);
        set(handles.shock_state_text, 'backgroundcolor', [0 0.7 0]);
    else
        set(handles.shock_state_text, 'foregroundcolor', [0 0.7 0]);
        set(handles.shock_state_text, 'backgroundcolor', [0 0 0]);
    end

end

%% Toggles the background color of the "vns" text block
function ToggleVNSTextBlockColor ( handles, is_vns_happening )

    if (is_vns_happening)
        set(handles.vns_state_text, 'foregroundcolor', [1 0 0]);
        set(handles.vns_state_text, 'backgroundcolor', [0 0.7 0]);
    else
        set(handles.vns_state_text, 'foregroundcolor', [0 0.7 0]);
        set(handles.vns_state_text, 'backgroundcolor', [0 0 0]);
    end

end

%% Plots the shock and sounds schedule to the session axes
function PlotSchedule ( session_axes, shock_schedule, shock_duration, sound_schedule, sound_duration, vns_schedule, vns_duration, extra_time, current_time )

    %Convert everything to minutes
    current_time = current_time ./ (1000 * 60);
    shock_schedule = shock_schedule ./ (1000 * 60);
    shock_duration = shock_duration ./ (1000 * 60);
    sound_schedule = sound_schedule ./ (1000 * 60);
    sound_duration = sound_duration ./ (1000 * 60);
    vns_schedule = vns_schedule ./ (1000 * 60);
    vns_duration = vns_duration ./ (1000 * 60);
    extra_time = extra_time ./ (1000 * 60);

    %Set the session axes as the current axis
    axes(session_axes);
    
    %Clear the session axes
    cla(session_axes);
    
    %Hold the session axes
    hold(session_axes, 'on');
    
    %Plot each shock
    for i = 1:length(shock_schedule)
        x1 = shock_schedule(i);
        x2 = shock_schedule(i) + shock_duration;
        line([x1 x2], [1 1], 'Color', [0 0.7 0], 'LineWidth', 2, 'LineStyle', '-', 'Marker', 'o', 'MarkerFaceColor', [0 0.7 0], 'MarkerSize', 2);
    end
    
    %Plot each sound
    for i = 1:length(sound_schedule)
        x1 = sound_schedule(i);
        x2 = sound_schedule(i) + sound_duration;
        line([x1 x2], [2 2], 'Color', [0 0 1], 'LineWidth', 2, 'LineStyle', '-', 'Marker', 'o', 'MarkerFaceColor', [0 0 1], 'MarkerSize', 2);
    end
    
    %Plot each VNS
    for i = 1:length(vns_schedule)
        x1 = vns_schedule(i);
        x2 = vns_schedule(i) + vns_duration;
        line([x1 x2], [3 3], 'Color', [1 0 0], 'LineWidth', 2, 'LineStyle', '-', 'Marker', 'o', 'MarkerFaceColor', [1 0 0], 'MarkerSize', 2);
    end
    
    %Plot a line indicating where we currently are in the session
    line([current_time current_time], ylim, 'LineWidth', 1, 'LineStyle', '--', 'Marker', 'none', 'Color', [0 0 1]);
    
    %Calculate the x-axis limits
    max_xlim = max([(shock_schedule + shock_duration) (sound_schedule + sound_duration) (vns_schedule + vns_duration)]) + extra_time;
    if (isempty(max_xlim))
        max_xlim = 1;
    end
    set(session_axes, 'XLim', [0 max_xlim]);
    xlabel('Time (min)');
    
    title_string = ['Session time: ' datestr(current_time/(24*60), 'HH:MM:SS')];
    title(session_axes, title_string, 'Color', [0 0 0]);
    
end

%% This function initializes the video frames array to be empty
function BeginVideo ( handles )

    global vid;
    global vid_writer;

    %Create a file name
    session_date = now;
    date_string = datestr(session_date, 'YYYYmmDD_HHMMSS');
    file_name = [handles.rat_name '_' date_string '.mp4'];
    path_name = [handles.datapath '\' handles.rat_name '\' handles.number];

    %Create the path if it doesn't exist
    if (~exist(path_name, 'dir'))
        mkdir(path_name);
    end

    %Create a webcam object that saves video to disk
    vid = videoinput('winvideo', 1, 'RGB24_640x480');
    set(vid, 'FramesPerTrigger', Inf);
    set(vid, 'LoggingMode', 'memory');
    %set(vid, 'LoggingMode', 'disk');
    %set(vid, 'DiskLogger', VideoWriter([path_name '\' file_name], 'MPEG-4'));
    
    %Start saving data
    vid_writer = VideoWriter([path_name '\' file_name], 'MPEG-4');
    open(vid_writer);
    
    preview(vid, handles.webcam_image);
    
    %Start the camera recording
    start(vid);
    
end

%% This function writes frames to a file
function WriteFrames (is_sound_playing, is_shock_occurring, is_vns_occurring, current_time)

    global vid;
    global vid_writer;

    [frames, times] = getdata(vid, get(vid, 'FramesAvailable'));
    
    %Return if no frames need to be processed
    if (isempty(frames))
        return;
    end
    
    %Return if the number of rows (Y-axis) is less than 480
    if (size(frames, 1) < 480)
        return;
    end
    
    %Return if the number of columns (X-axis) is less than 640
    if (size(frames, 2) < 640)
        return;
    end
    
    %If the number of rows is greater than 480, then reduce it to 480.
    if (size(frames, 1) > 480)
        frames = frames(1:480, :, :, :);
    end
    
    %If the number of columns is greater than 640, then reduce it to 640.
    if (size(frames, 2) > 640)
        frames = frames(:, 1:640, :, :);
    end
    
    for i = 1:size(frames, 4)
        
        if (is_vns_occurring)
            frames(:, :, :, i) = insertText(frames(:, :, :, i), [1 1], 'VNS', 'FontSize', 24, 'BoxColor', 'green', 'BoxOpacity', 0.4, 'TextColor', 'white');
            %frames(1:100, 1:100, 1, i) = 255;
            %frames(1:100, 1:100, 2, i) = 0;
            %frames(1:100, 1:100, 3, i) = 0;
        end
        
        if (is_sound_playing)
            frames(:, :, :, i) = insertText(frames(:, :, :, i), [100 1], 'Sound', 'FontSize', 24, 'BoxColor', 'green', 'BoxOpacity', 0.4, 'TextColor', 'white');
            %frames(1:100, 101:200, 1, i) = 0;
            %frames(1:100, 101:200, 2, i) = 255;
            %frames(1:100, 101:200, 3, i) = 0;
        end
        
        if (is_shock_occurring)
            frames(:, :, :, i) = insertText(frames(:, :, :, i), [200 1], 'Shock', 'FontSize', 24, 'BoxColor', 'green', 'BoxOpacity', 0.4, 'TextColor', 'white');
            %frames(1:100, 201:300, 1, i) = 0;
            %frames(1:100, 201:300, 2, i) = 0;
            %frames(1:100, 201:300, 3, i) = 255;
        end
        
        frames(:, :, :, i) = insertText(frames(:, :, :, i), [300 1], num2str(current_time), 'FontSize', 24, 'BoxColor', 'green', 'BoxOpacity', 0.4, 'TextColor', 'white');
        
    end
    
    writeVideo(vid_writer, frames);
    
end

%% This function saves all video frames
function StopVideo (  )

    global vid;
    global vid_writer;

    closepreview(vid);
    
    stop(vid);
    
    close(vid_writer);

end

%% Writes a file header for the saved data file
function fid = WriteFileHeader ( handles )

    %Create a file name
    session_date = now;
    date_string = datestr(session_date, 'YYYYmmDD_HHMMSS');
    file_name = [handles.rat_name '_' date_string '.ArdyFear'];
    path_name = [handles.datapath '\' handles.rat_name '\' handles.number];

    %Create the path if it doesn't exist
    if (~exist(path_name, 'dir'))
        mkdir(path_name);
    end
    
    %Create/Open file for writing
    fid = fopen([path_name '\' file_name], 'wt');
    
    %Write the file header
    fprintf(fid, 'Rat Name: %s\n', handles.rat_name);
    fprintf(fid, 'Stage Name: %s\n', handles.number);
    fprintf(fid, 'Date: %s\n', datestr(session_date));
    
end

%% Writes an event that occurred in the session out to the data file
function WriteSessionEvent ( fid, event_type_string, sound_name_string )

    event_time = now;
    event_string = [datestr(event_time) ' - ' event_type_string];
    if (strcmpi(event_type_string, 'Sound'))
        event_string = [event_string ', ' sound_name_string];
    elseif (strcmpi(event_type_string, 'Total Session Time'))
        event_string = [event_type_string ' = ' sound_name_string];
    end
    event_string = [event_string '\n'];
    
    fprintf(fid, event_string);

end

%% This function is meant to change the background colors of all UI panels and the main figure
function ChangeFigureColor ( handles, new_color )

    for i = 1:length(handles.panels)
        set(handles.panels(i), 'backgroundcolor', new_color);
    end
    
    set(handles.fig, 'Color', new_color);

end
































































