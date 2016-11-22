function [] = checkoutCellDataForProject
global ANALYSIS_FOLDER;
projFolder = uigetdir([ANALYSIS_FOLDER 'Projects' filesep], 'Choose project folder');
global CELL_DATA_MASTER
cellData_folder = CELL_DATA_MASTER;% uigetdir([],'Choose cellData folder from which to copy data');

fid = fopen([projFolder filesep 'cellNames.txt'], 'r');
if fid < 0
    errordlg(['Error: cellNames.txt not found in ' projFolder]);
    return;
end
temp = textscan(fid, '%s', 'delimiter', '\n');
cellNames = temp{1};
fclose(fid);

fprintf('Checking for %g files\n', length(cellNames));

for i=1:length(cellNames)
    cellDataNames = cellNameToCellDataNames(cellNames{i});
    for j=1:length(cellDataNames)
        cellData_fname = [cellDataNames{j} '.mat'];
        if exist([ANALYSIS_FOLDER 'cellData' filesep cellData_fname], 'file') %already have the file
            %do nothing
        else
            if exist([cellData_folder filesep cellData_fname], 'file')
                disp(['Copying ' cellData_fname]);
                eval(['!cp -r ' [cellData_folder filesep cellData_fname] ' ' ANALYSIS_FOLDER 'cellData' filesep]);
            else
                disp([cellData_folder filesep cellData_fname ' not found']);
            end
        end
    end
end
disp('Done');