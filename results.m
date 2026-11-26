
%% ============================================================
%             PSY310 - WORD PRIMING EXPERIMENT
%                    FOUR PARTICIPANTS
%
% Calculates:
% 1. Primed word completion accuracy
% 2. Non-primed word completion accuracy
% 3. Priming score
%
% Priming Score = Primed Accuracy - Non-Primed Accuracy
%
% Blank responses are counted as incorrect.
%
% ============================================================

clearvars;
clc;

%% 1. SELECT ALL FOUR PARTICIPANT EXCEL FILES

fprintf('\n========================================\n');
fprintf('       WORD PRIMING ANALYSIS\n');
fprintf('========================================\n');

fprintf('\nPlease select all FOUR participant Excel files.\n');

[fileNames, folderPath] = uigetfile( ...
    {'*.xlsx;*.xls;*.xlsm', 'Excel Files (*.xlsx, *.xls, *.xlsm)'}, ...
    'Select all four participant Excel files', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    error('No files selected. Please run the script again.');
end

% Convert a single filename into a cell array
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

validTrials = zeros(numberOfParticipants, 1);
blankResponses = zeros(numberOfParticipants, 1);
totalRows = zeros(numberOfParticipants, 1);

%% 4. ANALYSE EACH PARTICIPANT

for p = 1:numberOfParticipants

    fprintf('\n========================================\n');
    fprintf('PARTICIPANT %d\n', p);
    fprintf('========================================\n');

    %% LOAD EXCEL FILE

    currentFile = fullfile(folderPath, fileNames{p});

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

    % Remove internal spaces for word comparison
    references = regexprep(references, '\s+', '');
    responses = regexprep(responses, '\s+', '');

    %% 7. IDENTIFY PRIMED AND NON-PRIMED CONDITIONS

    % Normalise condition labels
    % Example: "non-primed" becomes "nonprimed"

    conditionKey = regexprep(conditions, '[^a-z0-9]', '');

    % Primed = old/studied words
    isPrimed = ismember(conditionKey, ...
        ["old", "primed", "studied", "oldword", "primedword"]);

    % Non-primed = new/not-studied words
    isNonPrimed = ismember(conditionKey, ...
        ["new", "nonprimed", "unprimed", ...
         "notprimed", "notstudied", "newword", ...
         "nonprimedword"]);

    %% 8. CHECK CONDITION LABELS

    if ~any(isPrimed) || ~any(isNonPrimed)

        fprintf('\nUnrecognised condition labels:\n');
        disp(unique(conditions));

        error(['Cannot identify both primed and non-primed ' ...
               'conditions. Check the old_new column.']);

    end

    %% 9. IDENTIFY VALID TEST TRIALS

    % A trial is valid for scoring if:
    % 1. It has an intended word completion.
    % 2. It has a recognised primed/non-primed condition.
    %
    % Blank participant responses remain valid trials
    % and receive a score of zero.

    valid = strlength(references) > 0 & ...
            (isPrimed | isNonPrimed);

    references = references(valid);
    responses = responses(valid);

    isPrimed = isPrimed(valid);
    isNonPrimed = isNonPrimed(valid);

    validTrials(p) = sum(valid);

    % Count blank responses
    blankResponses(p) = sum(strlength(responses) == 0);

    fprintf('\nValid test trials: %d\n', validTrials(p));

    fprintf('Blank responses: %d\n', blankResponses(p));

    fprintf('Excluded rows: %d\n', ...
        totalRows(p) - validTrials(p));

    %% 10. SCORE EACH RESPONSE

    % Correct answer = 1
    % Incorrect/blank answer = 0

    correct = (references == responses) & ...
              (strlength(responses) > 0);

    %% 11. CALCULATE PRIMED WORD ACCURACY

    primedTrials(p) = sum(isPrimed);

    primedCorrect(p) = sum(correct & isPrimed);

    if primedTrials(p) > 0

        primedAccuracy(p) = ...
            primedCorrect(p) / primedTrials(p);

    end

    %% 12. CALCULATE NON-PRIMED WORD ACCURACY

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
%                  HELPER FUNCTION
%             IDENTIFY THE CORRECT COLUMN
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

        error('Please check the column names in your Excel file.');

    end

end
