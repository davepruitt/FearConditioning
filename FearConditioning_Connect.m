function ardy = FearConditioning_Connect(varargin)

port = instrhwinfo('serial');                                               %Grab information about the available serial ports.
if isempty(port)                                                            %If no serial ports were found on this computer...
    error(['ERROR IN CONNECT_2AFC: There are no available serial '...
        'ports on this computer.']);                                        %Show an error.
end
port = port.SerialPorts;                                                    %Pair down the list of serial ports to only those available.
busyports = instrfind;                                                      %Grab all the ports currently in use.
if ~isempty(busyports)                                                      %If there are any ports currently in use...
    busyports = {busyports.Port};                                           %Make a list of their port addresses.
    if iscell(busyports{1})                                                 %If there's more than one busy port.
        busyports = busyports{1}';                                          %Kick out the extraneous port name parts.
    end
else                                                                        %Otherwise...
    busyports = {};                                                         %Make an empty list for comparisons.
end

[booth_pairings, local, port_matching_file] = Get_Port_Assignments;         %Call the subfunction to get the booth-port pairings.

uiheight = 2;                                                               %Set the height for all buttons.
temp = [10,length(port)*(uiheight+0.1)+0.1];                                %Set the width and height of the port selection figure.
set(0,'units','centimeters');                                               %Set the screensize units to centimeters.
pos = get(0,'ScreenSize');                                                  %Grab the screensize.
pos = [pos(3)/2-temp(1)/2,pos(4)/2-temp(2)/2,temp(1),temp(2)];              %Scale a figure position relative to the screensize.
fig1 = figure('units','centimeters',...
    'Position',pos,...
    'resize','off',...
    'MenuBar','none',...
    'name','Select A Serial Port',...
    'numbertitle','off');                                                   %Set the properties of the figure.
        
for i = 1:length(port)
    
    if (~isempty(booth_pairings))
        b = find(strcmpi(local, booth_pairings(:, 1)) & strcmpi(port{i}, booth_pairings(:, 2)));
    else
        b = [];
    end
    
    if (isempty(b))
        b = '?';
    else
        b = num2str(booth_pairings{b(1), 3});
    end
    
    if any(strcmpi(port{i}, busyports))
        txt = ['Booth ' b ' (' port{i} '): busy (reset?)'];
    else
        txt = ['Booth ' b ' (' port{i} '): available'];
    end
           
    uicontrol(fig1,'style','pushbutton',...
        'string',txt,...
        'units','centimeters',...
        'position',[0.1 temp(2)-i*(uiheight+0.1) 9.8 uiheight],...
        'fontweight','bold',...
        'fontsize',14,...
        'callback',...
        ['guidata(gcbf,' num2str(i) '); uiresume(gcbf);']);                     %Make a button for the port showing that it is busy.
end
        
uiwait(fig1);
if ishandle(fig1)
    i = guidata(fig1);
    port = port{i};
    close(fig1);
    checkreset = 0;
else
    port = [];
end        

listbox = [];                                                               %Create a variable to hold a listbox handle.

if ~isempty(port) && checkreset && any(strcmpi(port,busyports))             %If that serial port is busy...
    i = questdlg(['Serial port ''' port ''' is busy. Reset and use '...
        'this port?'],['Reset ''' port '''?'],'Reset','Cancel','Reset');    %Ask the user if they want to reset the busy port.
    if strcmpi(i,'Cancel')                                                  %If the user selected "Cancel"...
        port = [];                                                          %...set the selected port to empty.
    end
end

if isempty(port)                                                            %If no port was selected.
    warning(['CONNECT_MOTOTRAK:NoPortChosen','No serial port chosen '...
        'for Ardyardy. Connection to the Arduino was aborted.']);     %Show a warning.
    ardy = [];                                                              %Set the function output to empty.
    return;                                                                 %Exit the Connect_MotoTrak function.
end
if any(strcmpi(port,busyports))                                             %If the specified port is already busy...
    i = find(strcmpi(port,busyports));                                      %Find the index of the specified ports in the list of all busy ports.
    temp = instrfind;                                                       %Grab all the open serial connections.
    fclose(temp(i));                                                        %Close the busy serial connection.
    delete(temp(i));                                                        %Delete the existing serial connection.
end
serialcon = serial(port,'baudrate',115200);                                 %Set up the serial connection on the specified port.
try                                                                         %Try to open the serial port for communication.
    fopen(serialcon);                                                       %Open the serial port.
catch err                                                                   %If no connection could be made to the serial port...
    delete(serialcon);                                                      %...delete the serial object...
    error(['ERROR IN CONNECT_MOTOTRAK: Could not open a serial '...
        'connection on port ''' port ''' (' err.message ').']);             %Show an error.
end
message = 'Connecting to the Arduino...';                                   %Create the beginning of message to show the user.
if isempty(listbox)                                                         %If the user didn't specify a listbox...
    pos = get(0,'ScreenSize');                                              %Grab the screensize.
    pos = [0.3*pos(3),0.55*pos(4),0.4*pos(3),0.1*pos(4)];                   %Scale a figure position relative to the screensize.
    fig1 = figure;                                                          %Make a figure to show the progress of the Arduino connection.
    set(fig1,'Units', get(0, 'Units'), 'Position',pos,'MenuBar','none','name',...
        'Arduino Connection','numbertitle','off');                          %Set the properties of the figure.
    t = uicontrol(fig1,'style','text',...
    'string',message,...
	'units','normalized',...
	'position',[.01 .01 .98 .98],...
    'fontweight','bold',...
    'horizontalalignment','left',...
    'fontsize',14,...
    'backgroundcolor',get(fig1,'color'));                                   %Make a text label to show the Arduino connection status.
else                                                                        %Otherwise, if the user specified a listbox...
    t = 0;                                                                  %Create a dummy handle for the non-existent text label.
    set(listbox,'string',message,'value',1);                                %Show the Arduino connection status in the listbox.
end
tic;                                                                        %Start a timer.
while toc < 10                                                              %Loop for 10 seconds to wait for the Arduino to initialize.
    if serialcon.BytesAvailable > 0                                         %If there's bytes available on the serial line...
        break                                                               %Break out of the waiting loop.
    else                                                                    %Otherwise...
        message(end+1) = '.';                                               %Add a period to the end of the message.
        if ishandle(t) && isempty(listbox)                                  %If the user hasn't closed the figure and hasn't specified a listbox...
            set(t,'string',message);                                        %Update the message in the text label on the figure.
        elseif ~isempty(listbox)                                            %Or, if the user did specify a listbox...
            set(listbox,'string',message,'value',[]);                       %Update the message in the listbox.
        end
        pause(0.5);                                                         %Pause for 500 milliseconds.
    end
end
if serialcon.BytesAvailable > 0                                             %if there's a reply on the serial line.
    temp = fscanf(serialcon,'%c',serialcon.BytesAvailable);                 %Read the reply into a temporary matrix.
end
tic;                                                                        %Start a timer.
while toc < 10;                                                             %Loop for 10 seconds or until a reply is noted.
    fwrite(serialcon,'A','uchar');                                          %Send the check status code to the Arduino board.
    if serialcon.BytesAvailable > 0                                         %If there's bytes available on the serial line...
        message = [message 'Connected!'];                                   %Add to the message to show that the connection was successful.
        if ishandle(t) && isempty(listbox)                                  %If the user hasn't closed the figure and hasn't specified a listbox...
            set(t,'string',message);                                        %Update the message in the text label on the figure.
        elseif ~isempty(listbox)                                            %Or, if the user did specify a listbox...
            set(listbox,'string',message,'value',[]);                       %Update the message in the listbox.
        end
        break                                                               %Break out of the waiting loop.
    else                                                                    %Otherwise...
        message(end+1) = '.';                                               %Add a period to the end of the message.
        if ishandle(t) && isempty(listbox)                                  %If the user hasn't closed the figure and hasn't specified a listbox...
            set(t,'string',message);                                        %Update the message in the text label on the figure.
        elseif ~isempty(listbox)                                            %Or, if the user did specify a listbox...
            set(listbox,'string',message,'value',[]);                       %Update the message in the listbox.
        end
        pause(0.5);                                                         %Pause for 500 milliseconds.
    end
end

while serialcon.BytesAvailable > 0                                          %Loop through the replies on the serial line.
    pause(0.01);                                                            %Pause for 50 milliseconds.
    temp = fscanf(serialcon,'%d');                                          %Read each reply, replacing the last.
end
if isempty(temp) || temp(1) ~= 1                                            %If no status reply was received or the wrong sketch is indicated...
    delete(serialcon);                                                      %Delete the serial object.
    fprintf(1,'COULD NOT CONNECT!\n');                                      %End the connection message with an error.
    error(['ERROR IN Connect_Ardy2AFC: Arduino board is not responding.'...
        '  Check to make sure the Arduino is connected to the '...
        'specified serial port and that it is running the '...
        'FearConditioning_Main.ino sketch.']);                              %Show an error.
else                                                                        %Otherwise...
    fprintf(1,['Arduino is connected and FearConditioning_Main.ino is detected as '...
        'running.']);                                                       %Show that the connection was successful.
end        

%Save details about the connection to the output structure.
ardy.port = port;                                                           %Save the port address to the output structure.
ardy.serialcon = serialcon;                                                 %Save the handle for the serial connection for debugging purposes.        

%Basic functions
ardy.stream_enable = @(i)simple_command(serialcon,'gi',i);                  %Set the function for enabling or disabling the stream.
ardy.read_stream = @()read_stream(serialcon);                               %Set the function for reading values from the stream.
ardy.clear = @()clear_stream(serialcon);                                    %Set the function for clearing the serial line prior to streaming.

%Basic status functions.

ardy.set_booth = @(int)long_command(serialcon,'Bnn',[],int);                %Set the function for setting the booth number saved on the Arduino.
ardy.booth = @()simple_return(serialcon,'b',1);                             %Set the function for returning the booth number saved on the Arduino.
                                        
%Input / output functions
ardy.shock_enable = @(i)simple_command(serialcon,'Ci', i);                  %Turn shock on or off
ardy.vns_enable = @()simple_command(serialcon,'D', i);                      %Turn on vns pulse
ardy.select_tone = @(int)long_command(serialcon,'Enn', [], int);            %Select tone
ardy.enable_music = @(i)simple_command(serialcon,'Fi', i);                  %Turn on/off music
ardy.read_music = @()simple_return(serialcon, 'G', 1);                      %Read back from Music Player to determine if music is playing
ardy.music_led_disable = @()simple_command(serialcon, 'H', i);              %Turn off Music LED
ardy.VNS_led_disable = @()simple_command(serialcon, 'J', i);                %Turn off Music LED

pause(2);
close(fig1);

%Clean any junk leftover on the serial line
while serialcon.BytesAvailable > 0
    fscanf(serialcon, '%d', serialcon.BytesAvailable);
end

Set_Port_Assignments(booth_pairings,local,port_matching_file,...
    port,ardy.booth());                                               %Save the port-to-booth pairings for the next start-up.

end

%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function simple_command(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
end

%% This function reads in the values from the data stream when streaming is enabled.
function output = read_stream(serialcon)
tic;                                                                        %Start a timer.
while serialcon.BytesAvailable == 0 && toc < 0.05                           %Loop for 50 milliseconds or until there's a reply on the serial line.
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
output = [];                                                                %Create an empty matrix to hold the serial line reply.
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    try 
        streamdata = fscanf(serialcon,'%d')';
        output(end+1,:) = streamdata(1:2);                                  %Read each byte and save it to the output matrix.
    catch
    end
end
end


%% This function sends the specified command to the Arduino, replacing any "i" characters with the specified input number.
function output = simple_return(serialcon,command,i)
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
output = fscanf(serialcon,'%d');                                            %Check the serial line for a reply.
end

%% This function sends commands with 16-bit integers broken up into 2 characters encoding each byte.
function long_command(serialcon,command,i,int)     
command(command == 'i') = num2str(i);                                       %Convert the specified input number to a string.
i = dec2bin(int16(int),16);                                                 %Convert the 16-bit integer to a 16-bit binary string.
byteA = bin2dec(i(1:8));                                                    %Find the character that codes for the first byte.
byteB = bin2dec(i(9:16));                                                   %Find the character that codes for the second byte.
i = findstr(command,'nn');                                                  %Find the spot for the 16-bit integer bytes in the command.
command(i:i+1) = char([byteA, byteB]);                                      %Insert the byte characters into the command.
fwrite(serialcon,command,'uchar');                                          %Send the command to the Arduino board.
end

%% This function clears any residual streaming data from the serial line prior to streaming.
function clear_stream(serialcon)
tic;                                                                        %Start a timer.
while serialcon.BytesAvailable == 0 && toc < 0.05                           %Loop for 50 milliseconds or until there's a reply on the serial line.
    pause(0.001);                                                           %Pause for 1 millisecond to keep from overwhelming the processor.
end
while serialcon.BytesAvailable > 0                                          %Loop as long as there's bytes available on the serial line...
    fscanf(serialcon,'%d');                                                 %Read each byte and discard it.
end
end

%% This function writes the port-booth assignment file.
function Set_Port_Assignments(booth_pairings,local,port_matching_file,port,booth)
if ~isempty(booth_pairings)                                                 %If a booth-to-port pairings file was found...
    i = find(strcmpi(local,booth_pairings(:,1)) & ...
        strcmpi(port,booth_pairings(:,2)));                                 %Check to see if this port is already matched to a booth number.
else                                                                        %Otherwise, if a booth-to-port pairings file wasn't found...
    i = [];                                                                 %Show that no booth-to-port match was found.
end
if ~isempty(i)                                                              %If a match was found...
    b = booth_pairings{i(1),3};                                             %Grab the booth number matched to this port on this computer.
    if b ~= booth                                                           %If the current booth number doesn't match in the file...
        booth_pairings{i(1),3} = booth;                                     %Save the new booth number.
        if length(i) > 1                                                    %If more than one match was found...
        booth_pairings(i(2:end),:) = [];                                    %Kick out the redundant matches.
        end
    end
else                                                                        %Otherwise, if a match wasn't found...
    b = [];                                                                 %Set the booth number to an empty matrix.
    booth_pairings(end+1,1:3) = {local,port,booth};                         %Save the booth-to-port assignment.
end
if isempty(b) || b ~= booth                                                 %If the booth on this port isn't yet assigned or the booth number doesn't match...
    fid = fopen(port_matching_file,'wt');                                   %Open a new text file to write the booth-to-port pairing to.
    fprintf(fid,'%s\t','COMPUTER:');                                        %Write the computer column heading to the file.
    fprintf(fid,'%s\t','PORT:');                                            %Write the port column heading to the file.
    fprintf(fid,'%s\n','BOOTH:');                                           %Write the booth column heading to the file.
    for i = 1:size(booth_pairings,1)                                        %Step through the listed booth-to-port pairings.
        fprintf(fid,'%s\t',booth_pairings{i,1});                            %Write the computer name to the file.
        fprintf(fid,'%s\t',booth_pairings{i,2});                            %Write the port to the file.
        fprintf(fid,'%1.0f\n',booth_pairings{i,3});                         %Write the booth number to the file.
    end
    fclose(fid);                                                            %Close the pairing file.
end
end


%% This function reads in the port-booth assignment file.
function [booth_pairings, local, port_matching_file] = Get_Port_Assignments
if isdeployed                                                               %If this is deployed code...
    temp = pwd;                                                             %Set the destination directory to the current directory.
else                                                                        %Otherwise, if this isn't deployed code...
    temp = mfilename('fullpath');                                           %Grab the full path and filename of the current *.m file.
    temp(find(temp == '\' | temp == '/',1,'last'):end) = [];                %Kick out the filename to capture just the path.
end
port_matching_file = [temp '\fear_port_booth_pairings.txt'];                %Set the expected name of the pairing file.
if exist(port_matching_file,'file')                                         %If the pairing file exists...
    try                                                                     %Attempt to open and read the pairing file.
        fid = fopen(port_matching_file,'rt');                               %Open the pairing file for reading.
        temp = textscan(fid,'%s');                                          %Read in the booth-port pairings.
        fclose(fid);                                                        %Close the pairing file.
        if mod(length(temp{1}),3) ~= 0                                      %If the data in the file isn't formated into 3 columns...
            booth_pairings = {};                                            %Set the pairing cell array to be an empty cell.
        else                                                                %Otherwise...
            booth_pairings = cell(3,length(temp{1})/3-1);                   %Create a 3-column cell array to hold the booth-to-port assignments.
            for i = 4:length(temp{1})                                       %Step through the elements of the text.
                booth_pairings(i-3) = temp{1}(i);                           %Match each entry to it's correct row and column.
            end
            booth_pairings = booth_pairings';                               %Transpose the pairing cell array.
            for i = 1:size(booth_pairings)                                  %Step through each row in the pairing cell array.
                booth_pairings{i,3} = str2double(booth_pairings{i,3});      %Convert each string to a number.
            end
            booth_pairings(isnan([booth_pairings{:,3}]),:) = [];            %Kick out any rows where the booth number was unreadable.
        end
    catch err                                                               %If any error occured while reading the pairing file.
        booth_pairings = {};                                                %Set the pairing cell array to be an empty cell.
        warning('FearConditioning_Connect:PairingFileReadError',['The '...
            'booth-to-port pairing file was unreadable! ' err.identifier]); %Show that the pairing file couldn't be read.
    end
else                                                                        %Otherwise, if the pairing file doesn't exist.
    booth_pairings = {};                                                    %Set the pairing cell array to be an empty cell.
end
[temp, local] = system('hostname');                                         %Grab the local computer name.
local(local < 33) = [];                                                     %Kick out any spaces and carriage returns from the computer name.
end