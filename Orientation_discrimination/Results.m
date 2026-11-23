%% Signal Detection Analysis (d' and criterion c) for PsychoPy orientation_disc data
% Works in base MATLAB (no Statistics Toolbox needed).
% Put this file in the same folder as the CSV, or edit csvFile below.

clear; clc; close all;

csvFile = 'C:\Users\Vedika Bhardwaj\Desktop\Semesters\Monsoon_2026\PSY310_Lab\Psychopy\tutorial_two\data\01_orientation_disc_2026-11-22_20h41.31.655.csv';

%% 1. Load data
T = readtable(csvFile, 'VariableNamingRule', 'preserve');

resp  = string(T.('trials.key_resp.keys'));   % "up" / "down"
corr  = T.('trials.key_resp.corr');           % 1 = correct, 0 = incorrect
tilt  = T.('trials.tilt');                    % logged tilt (deg, integer)
rt    = T.('trials.key_resp.rt');

% Keep only real trials (the first and last rows of the file are not trials)
valid = ~ismissing(resp) & ~isnan(corr);
resp = resp(valid); corr = corr(valid); tilt = tilt(valid); rt = rt(valid);
nTrials = numel(resp);

%% 2. Classify trials
% "down" = observer says "tilted" (signal present); "up" = "not tilted".
% Stimulus identity is taken from the correctness column, because a few
% sub-1-degree tilts are logged as 0 in the file.
sayYes   = (resp == "down");
isSignal = (sayYes & corr == 1) | (~sayYes & corr == 0);

H  = sum( isSignal &  sayYes);   % hits
M  = sum( isSignal & ~sayYes);   % misses
FA = sum(~isSignal &  sayYes);   % false alarms
CR = sum(~isSignal & ~sayYes);   % correct rejections

nSig = H + M;
nNoi = FA + CR;

%% 3. SDT measures
zf = @(p) sqrt(2) * erfinv(2*p - 1);          % inverse normal CDF (= norminv)

hitRate = H / nSig;
faRate  = FA / nNoi;

% Log-linear correction (Hautus, 1995), used only if a rate is 0 or 1
if hitRate == 0 || hitRate == 1 || faRate == 0 || faRate == 1
    hitRate = (H + 0.5) / (nSig + 1);
    faRate  = (FA + 0.5) / (nNoi + 1);
    disp('Extreme rate found: log-linear correction applied.');
end

zH = zf(hitRate);
zF = zf(faRate);

dprime = zH - zF;                 % sensitivity
c      = -(zH + zF) / 2;          % criterion
beta   = exp(c * dprime);         % likelihood ratio at criterion
propCorrect = (H + CR) / nTrials;

%% 4. Print results
fprintf('\n--- Response matrix ---\n');
fprintf('Hits = %d | Misses = %d | False alarms = %d | Correct rejections = %d\n', H, M, FA, CR);
fprintf('Signal trials = %d | Noise trials = %d | Total = %d\n', nSig, nNoi, nTrials);
fprintf('\n--- Rates ---\n');
fprintf('Hit rate = %.3f | False-alarm rate = %.3f | Proportion correct = %.2f\n', hitRate, faRate, propCorrect);
fprintf('z(H) = %.3f | z(F) = %.3f\n', zH, zF);
fprintf('\n--- SDT measures ---\n');
fprintf("d' = %.3f\nc  = %.3f\nbeta = %.3f\n", dprime, c, beta);
fprintf('Mean RT = %.3f s (median %.3f s)\n\n', mean(rt), median(rt));

%% 5. Figure
fig = figure('Color', 'w', 'Position', [100 100 1000 420]);

% Panel A: signal and noise distributions with the criterion
subplot(1, 2, 1); hold on;
x = linspace(-4, dprime + 4, 600);
pdfN = @(x, mu) exp(-(x - mu).^2 / 2) / sqrt(2*pi);
plot(x, pdfN(x, 0),      'Color', [0.35 0.35 0.35], 'LineWidth', 2);
plot(x, pdfN(x, dprime), 'Color', [0.12 0.31 0.47], 'LineWidth', 2);
crit = dprime/2 + c;                                   % criterion location on the evidence axis
xline(crit, '--r', 'LineWidth', 1.5);
legend({'Noise', 'Signal', 'Criterion'}, 'Location', 'northeast', 'Box', 'off');
xlabel('Internal evidence'); ylabel('Probability density');
title(sprintf("Estimated distributions (d' = %.2f, c = %.2f)", dprime, c), 'Color', 'k');
set(gca, 'Box', 'off', 'FontSize', 11, 'XColor', 'k', 'YColor', 'k');

% Panel B: hit rate by tilt size (signal trials only)
subplot(1, 2, 2);
absTilt = abs(tilt);
levels  = unique(absTilt(isSignal));
hr = zeros(size(levels)); n = zeros(size(levels));
for k = 1:numel(levels)
    idx   = isSignal & absTilt == levels(k);
    n(k)  = sum(idx);
    hr(k) = sum(idx & sayYes) / n(k);
end
bar(levels, hr, 'FaceColor', [0.12 0.31 0.47]);
for k = 1:numel(levels)
    text(levels(k), hr(k) + 0.03, sprintf('n=%d', n(k)), 'HorizontalAlignment', 'center');
end
ylim([0 1.1]); xlabel('|Tilt| (degrees, as logged)'); ylabel('Hit rate');
title('Hit rate by tilt size', 'Color', 'k'); set(gca, 'Box', 'off', 'FontSize', 11, 'XColor', 'k', 'YColor', 'k');

saveas(fig, 'sdt_figure.png');