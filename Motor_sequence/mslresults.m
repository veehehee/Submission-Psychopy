
%% SEQUENCE LEARNING - DIAGNOSTIC ONLY

clearvars;
clc;

fprintf('\n========================================\n');
fprintf('       SEQUENCE LEARNING DATA CHECK\n');
fprintf('========================================\n');

[fileNames, folderPath] = uigetfile( ...
    {'*.xlsx;*.xls;*.xlsm;*.csv', ...
     'Excel and CSV Files (*.xlsx, *.xls, *.xlsm, *.csv)'}, ...
    'Select all five Sequence Learning files', ...
    'MultiSelect', 'on');

if isequal(fileNames,0)
    error('No files selected.');
end

if ischar(fileNames)
    fileNames = {fileNames};
end

for p = 1:numel(fileNames)

    fprintf('\n========================================\n');
    fprintf('PARTICIPANT %d: %s\n',p,fileNames{p});
    fprintf('========================================\n');

    data = readtable( ...
        fullfile(folderPath,fileNames{p}), ...
        'VariableNamingRule','preserve');

    fprintf('Total rows: %d\n',height(data));

    fprintf('\nAVAILABLE COLUMNS:\n');
    disp(data.Properties.VariableNames');

    % Display relevant columns that actually exist
    wanted = { ...
        'pos', ...
        'corr_resp', ...
        'thisN', ...
        'thisTrialN', ...
        'thisRepN', ...
        'trials.thisN', ...
        'trials.thisTrialN', ...
        'trials.thisRepN', ...
        'trials.thisIndex', ...
        'key_resp.keys', ...
        'key_resp.corr', ...
        'key_resp.rt', ...
        'trials.key_resp.keys', ...
        'trials.key_resp.corr', ...
        'trials.key_resp.rt'};

    available = data.Properties.VariableNames;

    selected = wanted(ismember(wanted,available));

    fprintf('\nTRIAL DATA:\n');
    disp(data(:,selected));

    fprintf('\nREACTION TIME SUMMARY:\n');

    rt = data.('key_resp.rt');

    fprintf('Valid RTs: %d\n',sum(isfinite(rt) & rt > 0));

    fprintf('Mean RT: %.4f\n',mean(rt(isfinite(rt) & rt > 0)));

    fprintf('\nACCURACY SUMMARY:\n');

    corr = data.('key_resp.corr');

    fprintf('Correct responses: %d\n',sum(corr == 1));
    fprintf('Incorrect responses: %d\n',sum(corr == 0));

end

fprintf('\n========================================\n');
fprintf('         DIAGNOSTIC COMPLETE\n');
fprintf('========================================\n');

