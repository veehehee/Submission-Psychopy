clear;
clc;

% Load your experiment data
data = readtable('C:\Users\Vedika Bhardwaj\Desktop\psychopy_submission_AU2420155\Intentional_binding\participant1.xlsx', ...
    'VariableNamingRule', 'preserve');

% Display all column names
disp('COLUMN NAMES IN YOUR DATA FILE:');
disp(data.Properties.VariableNames');
%%
%% INTENTIONAL BINDING EXPERIMENT
% Analysis of expected vs unexpected tones

clear;
clc;

%% 1. LOAD DATA

% Replace with your actual CSV filename
data = readtable('C:\Users\Vedika Bhardwaj\Desktop\psychopy_submission_AU2420155\Intentional_binding\participant1.xlsx', ...
    'VariableNamingRule', 'preserve');

%% 2. EXTRACT RELEVANT COLUMNS

% Tone frequency
freq = str2double(string(data.freq));

% Participant's estimated interval
estimates = str2double(strtrim(string(data.('textbox.text'))));

%% 3. IDENTIFY CONDITIONS

% Expected tone = 1000 Hz
% Unexpected tone = 400 Hz

expected = freq == 1000;
unexpected = freq == 400;

%% 4. REMOVE INVALID OR MISSING DATA

valid = isfinite(estimates) & (expected | unexpected);

expected = expected & valid;
unexpected = unexpected & valid;

%% 5. CALCULATE MEANS

meanExpected = mean(estimates(expected));
meanUnexpected = mean(estimates(unexpected));

nExpected = sum(expected);
nUnexpected = sum(unexpected);

%% 6. CALCULATE DIFFERENCE

% Positive value means expected tones had shorter estimates

difference = meanUnexpected - meanExpected;

%% 7. DISPLAY RESULTS

fprintf('\n====================================\n');
fprintf('     INTENTIONAL BINDING RESULTS\n');
fprintf('====================================\n');

fprintf('\nEXPECTED TONE (1000 Hz)\n');
fprintf('Number of trials: %d\n', nExpected);
fprintf('Mean estimated interval: %.2f ms\n', meanExpected);

fprintf('\nUNEXPECTED TONE (400 Hz)\n');
fprintf('Number of trials: %d\n', nUnexpected);
fprintf('Mean estimated interval: %.2f ms\n', meanUnexpected);

fprintf('\nCOMPARISON\n');
fprintf('Difference (unexpected - expected): %.2f ms\n', difference);

fprintf('\nTotal valid trials: %d\n', sum(valid));
fprintf('Excluded trials: %d\n', sum(~valid));

fprintf('\n====================================\n');
clear;
clc;

data = readtable("C:\Users\Vedika Bhardwaj\Desktop\psychopy_submission_AU2420155\Intentional_binding\participant1.xlsx", ...
    'VariableNamingRule', 'preserve');

%% CHECK FREQUENCY VALUES

fprintf('\n===== FREQUENCY COLUMN =====\n');

disp('Data type:');
disp(class(data.freq));

disp('Unique frequency values:');
disp(unique(string(data.freq)));

%% CHECK CONDITION VALUES

fprintf('\n===== CONDITION COLUMN =====\n');

disp(unique(string(data.condition)));

%% CHECK RESPONSE COLUMN 1

fprintf('\n===== TEXTBOX.TEXT =====\n');

disp('First 15 values:');
disp(string(data.('textbox.text')(1:min(15,height(data)))));

%% CHECK RESPONSE COLUMN 2

fprintf('\n===== TRIALS.TEXTBOX.TEXT =====\n');

disp('First 15 values:');
disp(string(data.('trials.textbox.text')(1:min(15,height(data)))));

%% CHECK NUMBER OF MISSING VALUES

fprintf('\n===== MISSING VALUES =====\n');

fprintf('Missing frequency values: %d\n', ...
    sum(ismissing(string(data.freq))));

fprintf('Missing textbox.text values: %d\n', ...
    sum(ismissing(string(data.('textbox.text')))));

fprintf('Missing trials.textbox.text values: %d\n', ...
    sum(ismissing(string(data.('trials.textbox.text')))));