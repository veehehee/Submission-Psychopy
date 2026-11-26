
%% ============================================================
%       PSY310 - DELAY DISCOUNTING ANALYSIS
%                  FOUR PARTICIPANTS
%
% Reads four separate Excel files and calculates the individual
% discounting rate (k) for each participant.
%
% T = Today (immediate reward)
% L = Later (delayed reward)
%
% ============================================================

clear;
clc;

%% 1. SELECT ALL FOUR EXCEL FILES

fprintf('\nDELAY DISCOUNTING ANALYSIS\n');
fprintf('Please select all FOUR participant Excel files.\n');

[fileNames, folderPath] = uigetfile( ...
    {'*.xlsx;*.xls;*.xlsm', 'Excel Files (*.xlsx, *.xls, *.xlsm)'}, ...
    'Select all four participant files', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    error('No files selected.');
end

if ischar(fileNames)
    fileNames = {fileNames};
end

numberOfParticipants = numel(fileNames);

fprintf('\nFiles selected: %d\n', numberOfParticipants);

if numberOfParticipants ~= 4
    warning('You selected %d files. Your report expects four participants.', ...
        numberOfParticipants);
end

%% 2. RESPONSE KEY MAPPING

% Change these if your experiment used different keys.

immediateKey = "t";
delayedKey = "l";

%% 3. CREATE RESULT VARIABLES

participantNames = strings(numberOfParticipants, 1);
kValues = NaN(numberOfParticipants, 1);
maximumConsistent = NaN(numberOfParticipants, 1);
validTrials = zeros(numberOfParticipants, 1);
totalTrials = zeros(numberOfParticipants, 1);
analysisStatus = strings(numberOfParticipants, 1);

%% 4. ANALYSE EACH PARTICIPANT

for p = 1:numberOfParticipants

    fprintf('\n========================================\n');
    fprintf('PARTICIPANT %d\n', p);
    fprintf('========================================\n');

    % Read Excel file
    currentFile = fullfile(folderPath, fileNames{p});

    data = readtable(currentFile, ...
        'VariableNamingRule', 'preserve');

    totalTrials(p) = height(data);
    participantNames(p) = string(fileNames{p});

    fprintf('File: %s\n', fileNames{p});
    fprintf('Total trials/rows: %d\n', height(data));

    %% 5. CHECK REQUIRED COLUMNS

    requiredColumns = { ...
        'reward_today', ...
        'future_reward', ...
        'delay', ...
        'key_resp.keys'};

    availableColumns = data.Properties.VariableNames;

    for c = 1:numel(requiredColumns)

        if ~ismember(requiredColumns{c}, availableColumns)

            fprintf('\nAvailable columns:\n');
            disp(availableColumns');

            error('Missing required column: %s', ...
                requiredColumns{c});
        end
    end

    %% 6. EXTRACT DATA

    V = convertNumeric(data.('reward_today'));
    A = convertNumeric(data.('future_reward'));
    D = convertNumeric(data.('delay'));

    response = lower(strtrim(string(data.('key_resp.keys'))));

    %% 7. IDENTIFY PARTICIPANT CHOICES

    choseToday = response == immediateKey | ...
                 contains(response, "today") | ...
                 contains(response, "immediate");

    choseLater = response == delayedKey | ...
                 contains(response, "later") | ...
                 contains(response, "delayed");

    % Stop if the response mapping is not recognised
    if ~any(choseToday | choseLater)

        fprintf('\nUnrecognised response values:\n');
        disp(unique(response));

        error(['Check whether T means Today and L means Later ' ...
               'in this experiment.']);
    end

    %% 8. CALCULATE INDIFFERENCE-POINT VALUES

    % k* = (A/V - 1)/D

    kStar = (A ./ V - 1) ./ D;

    %% 9. REMOVE INVALID TRIALS

    valid = isfinite(V) & isfinite(A) & isfinite(D) & ...
            V > 0 & A > V & D > 0 & ...
            isfinite(kStar) & kStar > 0 & ...
            (choseToday | choseLater);

    V = V(valid);
    A = A(valid);
    D = D(valid);
    kStar = kStar(valid);

    choseToday = choseToday(valid);
    choseLater = choseLater(valid);

    validTrials(p) = sum(valid);

    fprintf('Valid trials: %d\n', validTrials(p));
    fprintf('Excluded trials: %d\n', ...
        totalTrials(p) - validTrials(p));

    if isempty(kStar)

        analysisStatus(p) = "No valid trials";
        warning('No valid trials for participant %d.', p);
        continue;

    end

    %% 10. GENERATE POSSIBLE K VALUE RANGES

    thresholds = sort(unique(kStar));

    boundaries = [0; thresholds; Inf];

    numberIntervals = length(boundaries) - 1;

    consistencyScores = zeros(numberIntervals, 1);

    %% 11. CHECK CONSISTENCY OF EACH POSSIBLE K RANGE

    for j = 1:numberIntervals

        lowerBound = boundaries(j);
        upperBound = boundaries(j + 1);

        % Select a representative k value in each interval

        if lowerBound == 0

            candidateK = upperBound / 2;

        elseif isinf(upperBound)

            candidateK = lowerBound * 2;

        else

            candidateK = sqrt(lowerBound * upperBound);

        end

        % Predictions based on the discounting rate:
        %
        % If k > k*, predict TODAY.
        % If k < k*, predict LATER.

        predictedToday = candidateK > kStar;
        predictedLater = candidateK < kStar;

        consistencyScores(j) = sum( ...
            (choseToday & predictedToday) | ...
            (choseLater & predictedLater));

    end

    %% 12. FIND THE MAXIMUM CONSISTENCY SCORE

    highestScore = max(consistencyScores);

    bestIntervals = consistencyScores == highestScore;

    firstBest = find(bestIntervals, 1, 'first');
    lastBest = find(bestIntervals, 1, 'last');

    maximumConsistent(p) = highestScore;

    %% 13. CALCULATE FINAL K VALUE

    % Check whether maximum-scoring intervals are adjacent.

    if any(~bestIntervals(firstBest:lastBest))

        kEstimate = NaN;

        analysisStatus(p) = ...
            "Multiple separate maximum-scoring ranges";

    else

        lowerEnd = boundaries(firstBest);
        upperEnd = boundaries(lastBest + 1);

        % Geometric mean of finite endpoints

        if lowerEnd >= 0 && isfinite(upperEnd)

            kEstimate = sqrt(lowerEnd * upperEnd);

            analysisStatus(p) = "Successfully calculated";

        else

            kEstimate = NaN;

            analysisStatus(p) = ...
                "Maximum-scoring range is open-ended";

        end

    end

    kValues(p) = kEstimate;

    %% 14. DISPLAY INDIVIDUAL RESULTS

    fprintf('\nMaximum consistent choices: %d / %d\n', ...
        highestScore, validTrials(p));

    fprintf('Estimated discounting rate (k): %.8f\n', ...
        kEstimate);

    fprintf('Status: %s\n', analysisStatus(p));

end

%% 15. CREATE FINAL RESULTS TABLE

fprintf('\n\n============================================\n');
fprintf('       FINAL DELAY DISCOUNTING RESULTS\n');
fprintf('============================================\n');

results = table( ...
    (1:numberOfParticipants)', ...
    participantNames, ...
    kValues, ...
    maximumConsistent, ...
    validTrials, ...
    totalTrials, ...
    analysisStatus, ...
    'VariableNames', { ...
    'Participant', ...
    'File', ...
    'Discounting_k', ...
    'Maximum_Consistent_Choices', ...
    'Valid_Trials', ...
    'Total_Rows', ...
    'Status'});

disp(results);

%% 16. SAVE RESULTS

outputFile = fullfile(folderPath, ...
    'Delay_Discounting_Final_Results.xlsx');

writetable(results, outputFile);

fprintf('\nResults saved to:\n%s\n', outputFile);

fprintf('\n============================================\n');
fprintf('           ANALYSIS COMPLETE\n');
fprintf('============================================\n');


%% ============================================================
%                 NUMERICAL CONVERSION FUNCTION
% ============================================================

function values = convertNumeric(inputValues)

    if isnumeric(inputValues) || islogical(inputValues)

        values = double(inputValues);

    else

        values = str2double(regexprep( ...
            string(inputValues), '[^0-9eE+.-]', ''));

    end

end
