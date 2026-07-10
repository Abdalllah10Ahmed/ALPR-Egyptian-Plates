% =========================================================================
% ECE 228 - ALPR | Stage 2: Batch OCR & Accuracy Report
% =========================================================================
% Runs recognize_plate() on all enhanced plates in the Results folder,
% prints the complete results table, and computes both accuracy metrics
% required by the project:
%
%   1. Character Recognition Accuracy:
%      (correctly recognized chars / total chars) x 100%
%
%   2. Plate Recognition Accuracy:
%      (plates where FULL string is correct / total plates) x 100%
%
% REQUIREMENTS:
%   - recognize_plate.m  must be in the same folder as this script
%   - Results/enhanced_XXX.jpg  files must exist  (run run_stage1_outputs.m)
%   - Templates/ folder must be populated         (run build_templates.m)
%   - ground_truth.m   must be filled in by you   (instructions below)
%
% HOW TO RUN:
%   1. Fill in the GROUND TRUTH section in ground_truth.m
%   2. Press F5 to run this script
% =========================================================================

clc; clear; close all;

% -------------------------------------------------------------------------
% CONFIGURATION
% -------------------------------------------------------------------------
RESULTS_FOLDER   = 'Results';
TEMPLATES_FOLDER = 'Templates';
NUM_IMAGES       = 50;
SHOW_DEBUG_FOR   = [11,12,13,14,15];   % e.g. [3, 7, 12] to pop debug figures for those images
                         % leave empty [] to show no debug figures

% -------------------------------------------------------------------------
% GROUND TRUTH TABLE
% -------------------------------------------------------------------------
% Fill in the correct plate text for each image index.
% Use the same label strings as your templates:
%   letters: alef ba jeem dal ra waw zay seen sad ta ain fa qaf kaf lam
%   meem noon ya ha
%   digits : 1 2 3 4 5 6 7 8 9
%
% FORMAT:  groundTruth{i} = 'label1 label2 label3 | d1 d2 d3 d4';
%
% EXAMPLE: for plate showing letters ra+seen+waw and digits 0496:
%          groundTruth{1} = 'ra seen waw | 0 4 9 6';
%
% Leave as '' for images where the plate was NOT detected in Stage 1.
% -------------------------------------------------------------------------
groundTruth = cell(1, NUM_IMAGES);
for i = 1:NUM_IMAGES
    groundTruth{i} = '';   % default: unknown / not detected
end

% ====================================================================
% FILL IN YOUR GROUND TRUTH HERE - one line per image
% (delete the examples below and replace with your actual plates)
% ====================================================================
groundTruth{1}  = 'ra noon ain | 7 2 3 4';
groundTruth{2}  = 'ra seen jeem | 3 4 6 4';
groundTruth{3}  = 'alef fa ta | 4 5 9 5';
groundTruth{4}  = 'ra dal waw | 2 1 6 9';
groundTruth{5}  = 'ra seen qaf | 4 5 2 4';
groundTruth{6}  = 'ra seen meem | 7 8 9 7';
groundTruth{7}  = 'ra dal alef | 4 8 7 7';
groundTruth{8}  = 'ra alef waw | 8 2 6 4';
groundTruth{9}  = 'dal ba jeem | 9 8 8 7';
groundTruth{10}  = 'ra jeem lam | 5 4 1 7';
groundTruth{11}  = 'dal alef fa | 6 5 7 6';
groundTruth{12}  = 'ra alef ta | 9 5 8 2';
groundTruth{13}  = 'ra sad ain | 3 6 9 2';
groundTruth{14}  = 'ra alef jeem | 6 7 6 2';
groundTruth{15}  = 'ra ta alef | 7 8 5 1';
groundTruth{16}  = 'jeem kaf ha | 8 1 9 5';
groundTruth{17}  = 'ain ra dal | 2 3 9 9';
groundTruth{18}  = 'alef ha lam | 6 5 8 4';
groundTruth{19}  = 'dal fa | 6 9 4 8';
groundTruth{20}  = 'seen noon | 5 1 3 3';
groundTruth{21}  = 'ra jeem lam | 7 1 9 8';
groundTruth{22}  = 'ra ain alef | 9 4 6 8';
groundTruth{23}  = 'ra noon alef | 8 7 8 5';
groundTruth{24}  = 'ra fa waw | 3 4 7 2';
groundTruth{25}  = 'ra ya jeem | 2 3 4 5';
groundTruth{26}  = 'dal sad ha | 5 7 5 8';
groundTruth{27}  = 'ra noon waw | 9 6 8 7';
groundTruth{28}  = 'ra seen waw | 6 9 4 5';
groundTruth{29}  = 'ra noon ain | 7 2 3 4';
groundTruth{30}  = 'ra seen jeem | 3 4 6 4';
groundTruth{31}  = 'ra dal alef | 4 9 5 2';
groundTruth{32}  = 'ha ba | 7 6 7 5';
groundTruth{33}  = 'dal ha | 9 3 5 1';
groundTruth{34}  = 'ra jeem fa | 7 4 2 7';
groundTruth{35}  = 'ra waw alef | 3 8 5 7';
groundTruth{36}  = 'ra seen alef | 9 4 5 9';
groundTruth{37}  = 'kaf jeem ta | 9 2 7 1';
groundTruth{38}  = 'ra seen dal | 5 6 4 5';
groundTruth{39}  = 'ya jeem | 6 4 3 4';
groundTruth{40}  = 'ha ba | 5 5 8 1';
groundTruth{41}  = 'ra seen jeem | 3 4 6 4';
groundTruth{42}  = 'ra waw qaf | 9 7 1 6';
groundTruth{43}  = 'ra qaf ta | 8 1 9 4';
groundTruth{44}  = 'ra qaf ta | 3 1 6 8';
groundTruth{45}  = 'dal ba waw | 2 9 8 9';
groundTruth{46}  = 'ra ta alef | 8 6 4 6';
groundTruth{47}  = 'ra noon ya | 6 3 8 1';
groundTruth{48}  = 'meem kaf | 1 9 3 1';
groundTruth{49}  = 'dal ain ya | 9 1 5 6';
groundTruth{50}  = 'ra seen waw | 6 9 4 5';
% ====================================================================

% -------------------------------------------------------------------------
% CHECK TEMPLATES EXIST
% -------------------------------------------------------------------------
if ~exist(TEMPLATES_FOLDER, 'dir') || isempty(dir(fullfile(TEMPLATES_FOLDER, '*.png')))
    fprintf('[ERROR] No templates found in "%s".\n', TEMPLATES_FOLDER);
    fprintf('        Run build_templates.m first to create character templates.\n');
    return;
end

templateFiles = dir(fullfile(TEMPLATES_FOLDER, '*.png'));
fprintf('==========================================================\n');
fprintf('  ECE 228 ALPR - Stage 2: Batch OCR\n');
fprintf('  Loaded %d template images from "%s"\n', ...
        length(templateFiles), TEMPLATES_FOLDER);
fprintf('==========================================================\n\n');

% -------------------------------------------------------------------------
% TRACKING VARIABLES
% -------------------------------------------------------------------------
% Per-plate results
ocrResults    = cell(1, NUM_IMAGES);    % recognized text string
isDetected    = false(1, NUM_IMAGES);   % was the plate detected in Stage 1?
plateCorrect  = false(1, NUM_IMAGES);   % full plate string correct?

% Character-level tracking
totalChars    = 0;   % total ground truth characters across all plates
correctChars  = 0;   % characters recognized correctly

% -------------------------------------------------------------------------
% MAIN LOOP
% -------------------------------------------------------------------------
for i = 1:NUM_IMAGES
    enhancedPath = fullfile(RESULTS_FOLDER, sprintf('enhanced_%03d.jpg', i));

    if ~isfile(enhancedPath)
        ocrResults{i} = '[NOT DETECTED]';
        fprintf('[SKIP]  img_%03d -> no enhanced file\n', i);
        continue;
    end

    % Load enhanced plate
    try
        enhancedPlate = imread(enhancedPath);
    catch
        ocrResults{i} = '[READ ERROR]';
        fprintf('[ERROR] img_%03d -> could not read enhanced plate\n', i);
        continue;
    end

    isDetected(i) = true;

    % Run recognition
    showDbg = ismember(i, SHOW_DEBUG_FOR);
    try
        [plateText, ~, ~] = recognize_plate(enhancedPlate, TEMPLATES_FOLDER, showDbg);
    catch ME
        plateText = '[CRASH]';
        fprintf('[ERROR] img_%03d -> recognize_plate crashed: %s\n', i, ME.message);
    end

    if isempty(plateText)
        plateText = '[NO CHARS]';
    end

    ocrResults{i} = plateText;

    % --- Accuracy computation vs ground truth ---
    gt = strtrim(groundTruth{i});

    if ~isempty(gt)
        % Parse ground truth and recognized text into token lists
        gtTokens  = parse_plate_tokens(gt);
        recTokens = parse_plate_tokens(plateText);

        totalChars = totalChars + length(gtTokens);

        % Count matching tokens positionally
        nCompare = min(length(gtTokens), length(recTokens));
        matched  = 0;
        for t = 1:nCompare
            if strcmpi(gtTokens{t}, recTokens{t})
                matched = matched + 1;
            end
        end
        correctChars = correctChars + matched;

        % Full plate correct only if ALL tokens match AND same length
        if length(gtTokens) == length(recTokens) && matched == length(gtTokens)
            plateCorrect(i) = true;
        end

        % Console log
        if plateCorrect(i)
            fprintf('[OK]    img_%03d  GT: %-28s  REC: %-28s  [CORRECT]\n', ...
                    i, gt, plateText);
        else
            fprintf('[MISS]  img_%03d  GT: %-28s  REC: %-28s  [WRONG]\n', ...
                    i, gt, plateText);
        end
    else
        % No ground truth provided - just print the result
        fprintf('[REC]   img_%03d  -> %s\n', i, plateText);
    end
end

% -------------------------------------------------------------------------
% RESULTS TABLE (for report)
% -------------------------------------------------------------------------
fprintf('\n');
fprintf('==========================================================\n');
fprintf('  FULL RESULTS TABLE\n');
fprintf('==========================================================\n');
fprintf('  %-10s  %-10s  %-30s  %-30s  %s\n', ...
        'Image', 'Detected', 'Ground Truth', 'Recognized', 'Correct?');
fprintf('  %s\n', repmat('-', 1, 95));

detectedCount = 0;
for i = 1:NUM_IMAGES
    fname = sprintf('img_%03d', i);
    if isDetected(i)
        detectedCount = detectedCount + 1;
        detStr  = 'YES';
        recStr  = ocrResults{i};
        if isempty(recStr), recStr = '-'; end
        gt      = strtrim(groundTruth{i});
        if isempty(gt), gt = '(no GT)'; end
        corrStr = '';
        if ~isempty(strtrim(groundTruth{i}))
            if plateCorrect(i)
                corrStr = 'YES';
            else
                corrStr = 'NO';
            end
        end
    else
        detStr  = 'NO';
        recStr  = '-';
        gt      = strtrim(groundTruth{i});
        if isempty(gt), gt = '-'; end
        corrStr = '-';
    end

    fprintf('  %-10s  %-10s  %-30s  %-30s  %s\n', ...
            fname, detStr, gt, recStr, corrStr);
end

% -------------------------------------------------------------------------
% ACCURACY METRICS
% -------------------------------------------------------------------------
detectionAcc = (detectedCount / NUM_IMAGES) * 100;

platesWithGT = sum(~cellfun(@(x) isempty(strtrim(x)), groundTruth));

if platesWithGT > 0
    plateRecAcc = (sum(plateCorrect) / platesWithGT) * 100;
else
    plateRecAcc = 0;
end

if totalChars > 0
    charRecAcc = (correctChars / totalChars) * 100;
else
    charRecAcc = 0;
end

fprintf('\n==========================================================\n');
fprintf('  ACCURACY METRICS\n');
fprintf('==========================================================\n');
fprintf('  Detection Accuracy    : %d / %d = %.1f%%\n', ...
        detectedCount, NUM_IMAGES, detectionAcc);
fprintf('  ---\n');
fprintf('  Plates with GT labels : %d\n', platesWithGT);
fprintf('  ---\n');
fprintf('  Plate Recognition Acc : %d / %d = %.1f%%\n', ...
        sum(plateCorrect), platesWithGT, plateRecAcc);
fprintf('  (full plate string must be exactly correct)\n');
fprintf('  ---\n');
fprintf('  Character Recog. Acc  : %d / %d = %.1f%%\n', ...
        correctChars, totalChars, charRecAcc);
fprintf('  (per character, positional)\n');
fprintf('==========================================================\n');

% -------------------------------------------------------------------------
% SAVE RESULTS TO CSV (for the report table)
% -------------------------------------------------------------------------
csvPath = fullfile(RESULTS_FOLDER, 'ocr_results.csv');
try
    fid = fopen(csvPath, 'w');
    fprintf(fid, 'Image,Detected,GroundTruth,Recognized,PlateCorrect\r\n');
    for i = 1:NUM_IMAGES
        fname   = sprintf('img_%03d.jpg', i);
        detStr  = 'NO';
        recStr  = '';
        gt      = strtrim(groundTruth{i});
        corrStr = '';

        if isDetected(i)
            detStr  = 'YES';
            recStr  = ocrResults{i};
            if isempty(recStr), recStr = ''; end
            if ~isempty(gt)
                if plateCorrect(i)
                    corrStr = 'YES';
                else
                    corrStr = 'NO';
                end
            end
        end

        fprintf(fid, '%s,%s,"%s","%s",%s\r\n', fname, detStr, gt, recStr, corrStr);
    end
    fclose(fid);
    fprintf('  Results saved to: %s\n', csvPath);
catch
    fprintf('  [WARN] Could not save CSV results file.\n');
end

fprintf('==========================================================\n');


% =========================================================================
% HELPER: parse_plate_tokens
%   Splits a plate string into a flat list of character tokens,
%   ignoring the divider '|' symbol.
% =========================================================================
function tokens = parse_plate_tokens(plateStr)
    parts  = strsplit(strtrim(plateStr));
    tokens = {};
    for k = 1:length(parts)
        p = strtrim(parts{k});
        if ~isempty(p) && ~strcmp(p, '|')
            tokens{end+1} = lower(p); %#ok<AGROW>
        end
    end
end
