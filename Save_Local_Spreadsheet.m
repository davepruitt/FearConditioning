function Save_Local_Spreadsheet ( urldata, file_name )

    %Open a text-formatted configuration file to save the stage information.
    fid = fopen(file_name, 'wt');
    
    for i = 1:size(urldata, 1)                                               %Step through the rows of the stage data.
        for j = 1:size(urldata, 2)                                           %Step through the columns of the stage data.
            fprintf(fid, '%s', urldata{i,j});                                %Write each element of the stage data as tab-separated values.
            if j < size(urldata, 2)                                          %If this isn't the end of a row...
                fprintf(fid, '\t');                                          %Write a tab to the file.
            elseif i < size(urldata, 1)                                      %Otherwise, if this isn't the last row...
                fprintf(fid, '\n');                                          %Write a carriage return to the file.
            end
        end
    end
    
    %Close the file
    fclose(fid); 

end

