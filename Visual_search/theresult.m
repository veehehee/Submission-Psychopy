
%% ============================================================
%             PSY310 - VISUAL SEARCH ANALYSIS
%                    FIVE PARTICIPANTS
%
% Uses pre-calculated summary data:
% Set       = Number of distractors
% Average RT = Mean reaction time
%
% Calculates:
% 1. Mean RT at 5 distractors
% 2. Mean RT at 10 distractors
% 3. Search efficiency slope
% 4. Group comparison graph
%
% Slope = (Mean RT at 10 - Mean RT at 5) / 5
%
% IMPORTANT:
% Average RT must already be calculated from accurate trials.
% ============================================================

clearvars;
clc;

%% 1. SELECT ALL FIVE PARTICIPANT FILES

fprintf('\n========================================\n');
fprintf('          VISUAL SEARCH ANALYSIS\n');
fprintf('========================================\n');

fprintf('\nPlease select all FIVE participant files.\n');

[fileNames, folderPath] = uigetfile( ...
    {'*.xlsx;*.xls;*.xlsm;*.csv', ...
     'Excel and CSV Files (*.xlsx, *.xls, *.xlsm, *.csv)'}, ...
    'Select all five Visual Search files', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    error('No files selected.');
end

if ischar(fileNames)
    fileNames = {fileNames};
end

nParticipants = numel(fileNames);

fprintf('\nFiles selected: %d\n', nParticipants);

if nParticipants ~= 5
    warning('Expected five participants, but selected %d.', ...
        nParticipants);
end

%% 2. CREATE RESULT VARIABLES

participantNames = strings(nParticipants,1);

meanRT5 = NaN(nParticipants,1);
meanRT10 = NaN(nParticipants,1);

slope = NaN(nParticipants,1);

rowsSet5 = zeros(nParticipants,1);
rowsSet10 = zeros(nParticipants,1);

totalRows = zeros(nParticipants,1);

analysisStatus = strings(nParticipants,1);

%% 3. ANALYSE EACH PARTICIPANT

for p = 1:nParticipants

    fprintf('\n========================================\n');
    fprintf('PARTICIPANT %d\n',p);
    fprintf('========================================\n');

    %% LOAD FILE

    currentFile = fullfile(folderPath,fileNames{p});

    data = readtable(currentFile, ...
        'VariableNamingRule','preserve');

    totalRows(p) = height(data);

    participantNames(p) = string(fileNames{p});

    fprintf('File: %s\n',fileNames{p});
    fprintf('Total rows: %d\n',height(data));

    %% 4. IDENTIFY ACTUAL COLUMNS

    setSizeCol = findColumn(data, ...
        {'Set','set_size','setsize','Set Size'}, ...
        'Set size');

    rtCol = findColumn(data, ...
        {'Average RT','Average_RT','mean_RT','Mean RT'}, ...
        'Average reaction time');

    fprintf('\nDetected columns:\n');
    fprintf('Set size: %s\n',setSizeCol);
    fprintf('Average RT: %s\n',rtCol);

    %% 5. DISPLAY THE IMPORTED DATA

    fprintf('\nImported summary data:\n');

    disp(data(:,{setSizeCol,rtCol}));

    %% 6. EXTRACT NUMERICAL VALUES

    setSize = convertNumeric(data.(setSizeCol));

    rt = convertNumeric(data.(rtCol));

    %% 7. IDENTIFY SET SIZE LEVELS

    uniqueSizes = unique(setSize(isfinite(setSize)));

    fprintf('\nSet size values found:\n');

    disp(uniqueSizes);

    % If Set represents total items (6 and 11),
    % convert to number of distractors (5 and 10).

    if ~isempty(uniqueSizes) && ...
       all(ismember(uniqueSizes,[6 11])) && ...
       ~any(ismember(uniqueSizes,[5 10]))

        setSize = setSize - 1;

        fprintf(['Set sizes converted from total items ' ...
                 '(6 and 11) to distractors (5 and 10).\n']);

    end

    % Check that expected set sizes are present

    if ~any(setSize == 5) || ~any(setSize == 10)

        fprintf('\nERROR: Expected set sizes 5 and 10 were not both found.\n');

        fprintf('Values detected:\n');
        disp(unique(setSize));

        error(['Please check the Set column. ' ...
               'Expected 5 and 10 distractors.']);

    end

    %% 8. REMOVE MISSING OR INVALID VALUES

    valid = isfinite(setSize) & ...
            isfinite(rt) & ...
            rt > 0 & ...
            ismember(setSize,[5 10]);

    %% 9. CHECK REACTION TIME UNITS

    validRT = rt(valid);

    % Convert seconds to milliseconds when necessary

    if ~isempty(validRT) && median(validRT) < 10

        rt = rt * 1000;

        fprintf('\nRT converted from seconds to milliseconds.\n');

    else

        fprintf('\nRT assumed to be in milliseconds.\n');

    end

    %% 10. CALCULATE MEAN RT FOR SET SIZE 5

    selected5 = valid & setSize == 5;

    values5 = rt(selected5);

    rowsSet5(p) = sum(selected5);

    if rowsSet5(p) > 0

        meanRT5(p) = mean(values5);

    end

    %% 11. CALCULATE MEAN RT FOR SET SIZE 10

    selected10 = valid & setSize == 10;

    values10 = rt(selected10);

    rowsSet10(p) = sum(selected10);

    if rowsSet10(p) > 0

        meanRT10(p) = mean(values10);

    end

    %% 12. CALCULATE SEARCH EFFICIENCY SLOPE

    if isfinite(meanRT5(p)) && isfinite(meanRT10(p))

        slope(p) = (meanRT10(p) - meanRT5(p)) / 5;

        analysisStatus(p) = "Successfully calculated";

    else

        analysisStatus(p) = "Missing set size data";

    end

    %% 13. DISPLAY INDIVIDUAL RESULTS

    fprintf('\n----------------------------------------\n');
    fprintf('PARTICIPANT %d RESULTS\n',p);
    fprintf('----------------------------------------\n');

    fprintf('\nSET SIZE 5\n');

    fprintf('Summary rows: %d\n',rowsSet5(p));

    fprintf('Mean RT: %.2f ms\n',meanRT5(p));

    fprintf('\nSET SIZE 10\n');

    fprintf('Summary rows: %d\n',rowsSet10(p));

    fprintf('Mean RT: %.2f ms\n',meanRT10(p));

    fprintf('\nSEARCH EFFICIENCY\n');

    fprintf('Slope: %.2f ms/item\n',slope(p));

    fprintf('\nStatus: %s\n',analysisStatus(p));

end

%% 14. CREATE FINAL RESULTS TABLE

fprintf('\n\n============================================\n');
fprintf('        VISUAL SEARCH FINAL RESULTS\n');
fprintf('============================================\n');

visualSearchSummary = table( ...
    (1:nParticipants)', ...
    participantNames, ...
    rowsSet5, ...
    meanRT5, ...
    rowsSet10, ...
    meanRT10, ...
    slope, ...
    analysisStatus, ...
    'VariableNames',{ ...
    'Participant', ...
    'File', ...
    'Summary_Rows_Set5', ...
    'Mean_RT_Set5_ms', ...
    'Summary_Rows_Set10', ...
    'Mean_RT_Set10_ms', ...
    'Search_Efficiency_Slope', ...
    'Status'});

disp(visualSearchSummary);

%% 15. CALCULATE GROUP MEANS

groupMean5 = mean(meanRT5,'omitnan');

groupMean10 = mean(meanRT10,'omitnan');

fprintf('\n============================================\n');
fprintf('          GROUP MEAN RESULTS\n');
fprintf('============================================\n');

fprintf('Mean RT at 5 distractors: %.2f ms\n',groupMean5);

fprintf('Mean RT at 10 distractors: %.2f ms\n',groupMean10);

fprintf('Average search efficiency slope: %.2f ms/item\n', ...
    mean(slope,'omitnan'));

%% 16. CREATE GRAPH

if isfinite(groupMean5) && isfinite(groupMean10)

    figure('Name','Visual Search Results');

    % Individual participant lines
    hold on;

    for p = 1:nParticipants

        if isfinite(meanRT5(p)) && isfinite(meanRT10(p))

            plot([5 10], ...
                [meanRT5(p) meanRT10(p)], ...
                '-o','LineWidth',1.5);

        end

    end

    % Group mean line
    plot([5 10], ...
        [groupMean5 groupMean10], ...
        '-s','LineWidth',3);

    xlabel('Number of distractors');

    ylabel('Mean reaction time (ms)');

    title('Visual Search: Reaction Time by Set Size');

    xticks([5 10]);

    grid on;

    legend([ ...
        "Participant " + string((1:nParticipants)'); ...
        "Group Mean"], ...
        'Location','best');

    hold off;

    % Save graph
    saveas(gcf,fullfile(folderPath, ...
        'Visual_Search_Graph.png'));

    savefig(gcf,fullfile(folderPath, ...
        'Visual_Search_Graph.fig'));

else

    warning('Graph could not be generated.');

end

%% 17. SAVE RESULTS TO EXCEL

outputFile = fullfile(folderPath, ...
    'Visual_Search_Final_Results.xlsx');

writetable(visualSearchSummary,outputFile);

fprintf('\nResults saved to:\n%s\n',outputFile);

fprintf('\nGraph saved as Visual_Search_Graph.png\n');

fprintf('\n============================================\n');
fprintf('          ANALYSIS COMPLETE\n');
fprintf('============================================\n');


%% ============================================================
%                  HELPER FUNCTION 1
%                 IDENTIFY COLUMNS
% ============================================================

function columnName = findColumn(data,candidates,label)

    available = string(data.Properties.VariableNames);

    columnName = '';

    for i = 1:numel(candidates)

        index = find(strcmpi(available,candidates{i}),1);

        if ~isempty(index)

            columnName = char(available(index));

            return;

        end

    end

    fprintf('\nCould not identify column: %s\n',label);

    fprintf('Available columns:\n');

    disp(available');

    error('Required column not found.');

end


%% ============================================================
%                  HELPER FUNCTION 2
%                 CONVERT TO NUMBERS
% ============================================================

function values = convertNumeric(inputValues)

    if isnumeric(inputValues) || islogical(inputValues)

        values = double(inputValues);

    else

        inputText = string(inputValues);

        inputText = regexprep(inputText,',','');

        inputText = regexprep(inputText, ...
            '[^0-9eE+.-]','');

        values = str2double(inputText);

    end

end

