
%% ============================================================
%              PSY310 - WORD PRIMING EXPERIMENT
%                     FOUR PARTICIPANTS
%
% Calculates for each participant:
% 1. Primed (old) word completion accuracy
% 2. Non-primed (new) word completion accuracy
% 3. Priming score
%
% Priming Score = Primed Accuracy - Non-Primed Accuracy
%
% Supports Excel and CSV files.
% Blank responses are counted as incorrect.
%
% ============================================================

clearvars;
clc;

%% 1. SELECT ALL FOUR PARTICIPANT FILES

fprintf('\n========================================\n');
fprintf('          WORD PRIMING ANALYSIS\n');
fprintf('========================================\n');

fprintf('\nPlease select all FOUR participant files.\n');

% Display Excel AND CSV files
fileTypes = { ...
    '*.xlsx;*.xls;*.xlsm;*.csv', ...
    'Excel and CSV Files (*.xlsx, *.xls, *.xlsm, *.csv)'; ...
    '*.*', ...
    'All Files (*.*)'};

[fileNames, folderPath] = uigetfile( ...
    fileTypes, ...
    'Select all four Word Priming participant files', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    error('No files selected. Please run the script again.');
end

% Convert single selection to cell array
if ischar(fileNames)
    fileNames = {fileNames};
end

numberOfParticipants = numel(fileNames);

fprintf('\nFiles selected: %d\n', numberOfParticipants);

if numberOfParticipants ~= 4
    warning('Your report expects four participants, but %d files were selected.', ...
        numberOfParticipants);
end

%% 2. COLUMN NAME CANDIDATES

% Intended word completion
referenceCandidates = { ...
    'references', ...
    'trials.references', ...
    'reference', ...
    'correct_answer', ...
    'correctAnswer'};

% Old/New condition
conditionCandidates = { ...
    'old_new', ...
    'trials.old_new', ...
    'condition', ...
    'word_condition'};

% Participant's typed response
responseCandidates = { ...
    'textbox.text', ...
    'trials.textbox.text', ...
    'response', ...
    'answer', ...
    'typed_response', ...
    'word_response'};

%% 3. CREATE RESULT VARIABLES

participantNames = strings(numberOfParticipants, 1);

primedAccuracy = NaN(numberOfParticipants, 1);
nonPrimedAccuracy = NaN(numberOfParticipants, 1);
primingScores = NaN(numberOfParticipants, 1);

primedCorrect = zeros(numberOfParticipants, 1);
nonPrimedCorrect = zeros(numberOfParticipants, 1);

primedTrials = zeros(numberOfParticipants, 1);
nonPrimedTrials = zeros(numberOfParticipants, 1);

blankResponses = zeros(numberOfParticipants, 1);
validTrials = zeros(numberOfParticipants, 1);
totalRows = zeros(numberOfParticipants, 1);

%% 4. ANALYSE EACH PARTICIPANT

for p = 1:numberOfParticipants

    fprintf('\n========================================\n');
    fprintf('PARTICIPANT %d\n', p);
    fprintf('========================================\n');

    %% LOAD FILE

    currentFile = fullfile(folderPath, fileNames{p});

    [~, ~, extension] = fileparts(currentFile);

    if ~ismember(lower(extension), ...
            {'.xlsx', '.xls', '.xlsm', '.csv'})

        error('Unsupported file format: %s', extension);

    end

    data = readtable(currentFile, ...
        'VariableNamingRule', 'preserve');

    totalRows(p) = height(data);
    participantNames(p) = string(fileNames{p});

    fprintf('File: %s\n', fileNames{p});
    fprintf('Total rows: %d\n', height(data));

    %% 5. IDENTIFY REQUIRED COLUMNS

    referenceCol = findBestColumn( ...
        data, referenceCandidates, 'References');

    conditionCol = findBestColumn( ...
        data, conditionCandidates, 'Old/New condition');

    responseCol = findBestColumn( ...
        data, responseCandidates, 'Participant response');

    fprintf('\nDetected columns:\n');

    fprintf('Reference: %s\n', referenceCol);
    fprintf('Condition: %s\n', conditionCol);
    fprintf('Response: %s\n', responseCol);

    %% 6. EXTRACT DATA

    references = lower(strtrim(string(data.(referenceCol))));

    conditions = lower(strtrim(string(data.(conditionCol))));

    responses = lower(strtrim(string(data.(responseCol))));

    % Replace missing values with empty strings
    references(ismissing(references)) = "";
    conditions(ismissing(conditions)) = "";
    responses(ismissing(responses)) = "";

    % Treat common empty-response markers as blank
    blankMarker = ismember(responses, ["nan", "none", "null"]);

    responses(blankMarker) = "";

    %% 7. IDENTIFY PRIMED AND NON-PRIMED CONDITIONS

    % Normalise condition labels:
    % "non-primed" becomes "nonprimed"
    % "old_word" becomes "oldword"

    conditionKey = regexprep(conditions, '[^a-z0-9]', '');

    % Non-primed = new / not-studied words
    isNonPrimed = ismember(conditionKey, ...
        ["new", "nonprimed", "unprimed", ...
         "notprimed", "notstudied", "newword", ...
         "nonprimedword"]) | ...
         startsWith(conditionKey, "new") | ...
         contains(conditionKey, "nonprimed") | ...
         contains(conditionKey, "unprimed");

    % Primed = old / studied words
    isPrimed = ismember(conditionKey, ...
        ["old", "primed", "studied", ...
         "oldword", "primedword"]) | ...
         startsWith(conditionKey, "old") | ...
         contains(conditionKey, "studied") | ...
         contains(conditionKey, "primed");

    % Ensure non-primed labels are not classified as primed
    isPrimed = isPrimed & ~isNonPrimed;

    %% 8. CHECK CONDITION LABELS

    if ~any(isPrimed) || ~any(isNonPrimed)

        fprintf('\nUnrecognised condition labels:\n');

        disp(unique(conditions));

        error(['Cannot identify both primed and non-primed ' ...
               'conditions. Check your old_new column.']);

    end

    %% 9. IDENTIFY VALID TEST TRIALS

    % A valid trial must have:
    % 1. An intended word completion.
    % 2. A recognised condition label.
    %
    % Blank participant answers are NOT excluded.

    valid = strlength(references) > 0 & ...
            (isPrimed | isNonPrimed);

    references = references(valid);
    responses = responses(valid);

    isPrimed = isPrimed(valid);
    isNonPrimed = isNonPrimed(valid);

    validTrials(p) = sum(valid);

    blankResponses(p) = sum(strlength(responses) == 0);

    fprintf('\nValid test trials: %d\n', validTrials(p));

    fprintf('Blank responses: %d\n', blankResponses(p));

    fprintf('Excluded rows: %d\n', ...
        totalRows(p) - validTrials(p));

    %% 10. SCORE EACH RESPONSE

    % Correct completion = 1
    % Incorrect or blank completion = 0

    correct = (references == responses) & ...
              (strlength(responses) > 0);

    %% 11. CALCULATE PRIMED ACCURACY

    primedTrials(p) = sum(isPrimed);

    primedCorrect(p) = sum(correct & isPrimed);

    if primedTrials(p) > 0

        primedAccuracy(p) = ...
            primedCorrect(p) / primedTrials(p);

    end

    %% 12. CALCULATE NON-PRIMED ACCURACY

    nonPrimedTrials(p) = sum(isNonPrimed);

    nonPrimedCorrect(p) = sum(correct & isNonPrimed);

    if nonPrimedTrials(p) > 0

        nonPrimedAccuracy(p) = ...
            nonPrimedCorrect(p) / nonPrimedTrials(p);

    end

    %% 13. CALCULATE PRIMING SCORE

    primingScores(p) = ...
        primedAccuracy(p) - nonPrimedAccuracy(p);

    %% 14. DISPLAY INDIVIDUAL RESULTS

    fprintf('\n----------------------------------------\n');
    fprintf('PARTICIPANT %d RESULTS\n', p);
    fprintf('----------------------------------------\n');

    fprintf('\nPRIMED WORDS (OLD)\n');

    fprintf('Correct answers: %d / %d\n', ...
        primedCorrect(p), primedTrials(p));

    fprintf('Accuracy: %.3f\n', primedAccuracy(p));

    fprintf('Percentage: %.1f%%\n', ...
        primedAccuracy(p) * 100);

    fprintf('\nNON-PRIMED WORDS (NEW)\n');

    fprintf('Correct answers: %d / %d\n', ...
        nonPrimedCorrect(p), nonPrimedTrials(p));

    fprintf('Accuracy: %.3f\n', nonPrimedAccuracy(p));

    fprintf('Percentage: %.1f%%\n', ...
        nonPrimedAccuracy(p) * 100);

    fprintf('\nPRIMING SCORE\n');

    fprintf('Priming score: %.3f\n', primingScores(p));

end

%% 15. CREATE FINAL RESULTS TABLE

fprintf('\n\n============================================\n');
fprintf('          WORD PRIMING FINAL RESULTS\n');
fprintf('============================================\n');

wordPrimingSummary = table( ...
    (1:numberOfParticipants)', ...
    participantNames, ...
    primedCorrect, ...
    primedTrials, ...
    primedAccuracy, ...
    nonPrimedCorrect, ...
    nonPrimedTrials, ...
    nonPrimedAccuracy, ...
    primingScores, ...
    blankResponses, ...
    validTrials, ...
    totalRows, ...
    'VariableNames', { ...
    'Participant', ...
    'File', ...
    'Primed_Correct', ...
    'Primed_Total', ...
    'Primed_Accuracy', ...
    'NonPrimed_Correct', ...
    'NonPrimed_Total', ...
    'NonPrimed_Accuracy', ...
    'Priming_Score', ...
    'Blank_Responses', ...
    'Valid_Trials', ...
    'Total_Rows'});

disp(wordPrimingSummary);

%% 16. SAVE RESULTS TO EXCEL

outputFile = fullfile(folderPath, ...
    'Word_Priming_Final_Results.xlsx');

writetable(wordPrimingSummary, outputFile);

fprintf('\nResults saved to:\n%s\n', outputFile);

fprintf('\n============================================\n');
fprintf('          ANALYSIS COMPLETE\n');
fprintf('============================================\n');


%% ============================================================
%                    HELPER FUNCTION
%                IDENTIFY REQUIRED COLUMNS
% ============================================================

function columnName = findBestColumn(data, candidates, label)

    available = string(data.Properties.VariableNames);

    columnName = '';
    bestCount = -1;

    for i = 1:numel(candidates)

        index = find(strcmpi(available, candidates{i}), 1);

        if ~isempty(index)

            currentName = char(available(index));

            values = string(data.(currentName));

            values(ismissing(values)) = "";

            count = sum(strlength(strtrim(values)) > 0);

            if count > bestCount

                bestCount = count;
                columnName = currentName;

            end

        end

    end

    if isempty(columnName)

        fprintf('\nCould not identify column: %s\n', label);

        fprintf('Available columns:\n');

        disp(available');

        error('Please check the column names in your file.');

    end

end
%%

%% WORD PRIMING - CONDITION DIAGNOSTIC

clearvars;
clc;

[fileNames, folderPath] = uigetfile( ...
    {'*.xlsx;*.xls;*.xlsm;*.csv', ...
     'Excel and CSV Files (*.xlsx, *.xls, *.xlsm, *.csv)'}, ...
    'Select all four Word Priming files', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    error('No files selected.');
end

if ischar(fileNames)
    fileNames = {fileNames};
end

for p = 1:numel(fileNames)

    fprintf('\n========================================\n');
    fprintf('PARTICIPANT %d: %s\n', p, fileNames{p});
    fprintf('========================================\n');

    currentFile = fullfile(folderPath, fileNames{p});

    data = readtable(currentFile, ...
        'VariableNamingRule', 'preserve');

    fprintf('\nCOLUMN NAMES:\n');
    disp(data.Properties.VariableNames');

    % Extract condition labels
    conditions = lower(strtrim(string(data.('old_new'))));
    conditions(ismissing(conditions)) = "<missing>";

    fprintf('\nCONDITION LABELS AND FREQUENCIES:\n');

    [labels, ~, indices] = unique(conditions);
    counts = accumarray(indices, 1);

    disp(table(labels, counts, ...
        'VariableNames', {'Condition', 'NumberOfRows'}));

    % Display relevant information from every row
    fprintf('\nALL PARTICIPANT RESPONSES:\n');

    references = string(data.('Reference'));
    responses = string(data.('textbox.text'));

    references(ismissing(references)) = "";
    responses(ismissing(responses)) = "";

    details = table( ...
        (1:height(data))', ...
        conditions, ...
        references, ...
        responses, ...
        'VariableNames', ...
        {'Trial', 'Condition', 'Reference', 'Response'});

    disp(details);

end

fprintf('\nDIAGNOSTIC COMPLETE\n');
