function data = Read_Local_Spreadsheet(url)

fid = fopen(url, 'r');
urldata = char(fread(fid))';

%% Convert the single string output from urlread into a cell array corresponding to cells in the spreadsheet.
tab = sprintf('\t');                                                        %Make a tab string for finding delimiters.
newline = sprintf('\n');                                                    %Make a new-line string for finding new lines.
a = find(urldata == tab | urldata == newline);                              %Find all delimiters in the string.
a = [0, a, length(urldata)+1];                                              %Add indices for the first and last elements of the string.
urldata = [urldata, newline];                                               %Add a new line to the end of the string to avoid confusing the spreadsheet-reading loop.
column = 1;                                                                 %Count across columns.
row = 1;                                                                    %Count down rows.
data = {};                                                                  %Make a cell array to hold the spreadsheet-formated data.
for i = 2:length(a)                                                         %Step through each entry in the string.
    if a(i) == a(i-1)+1                                                     %If there is no entry for this cell...
        data{row,column} = [];                                              %...assign an empty matrix.
    else                                                                    %Otherwise...
        data{row,column} = urldata((a(i-1)+1):(a(i)-1));                    %...read one entry from the string.
    end
    if urldata(a(i)) == tab                                                 %If the delimiter was a tab...
        column = column + 1;                                                %...advance the column count.
    else                                                                    %Otherwise, if the delimiter was a new-line...
        column = 1;                                                         %...reset the column count to 1...
        row = row + 1;                                                      %...and add one to the row count.
    end
end

%% Make a numeric matrix converting every cell to a number.
checker = zeros(size(data,1),size(data,2));                                 %Pre-allocate a matrix to hold boolean is-numeric checks.
numdata = nan(size(data,1),size(data,2));                                   %Pre-allocate a matrix to hold the numeric data.
for i = 1:size(data,1)                                                      %Step through each row.      
    for j = 1:size(data,2)                                                  %Step through each column.
        numdata(i,j) = str2double(data{i,j});                               %Convert the cell contents to a double-precision number.
        %If this cell's data is numeric, or if the cell is empty, or contains a placeholder like *, -, or NaN...
        if ~isnan(numdata(i,j)) || isempty(data{i,j}) ||...
                any(strcmpi(data{i,j},{'*','-','NaN'}))
            checker(i,j) = 1;                                               %Indicate that this cell has a numeric entry.
        end
    end
end
if all(checker(:))                                                          %If all the cells have numeric entries...
    data = numdata;                                                         %...save the data as a numeric matrix.
end
