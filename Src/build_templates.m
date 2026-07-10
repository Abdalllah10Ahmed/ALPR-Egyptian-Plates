% =========================================================================
% ECE 228 - ALPR | Template Builder (Interactive)
% =========================================================================
% Run this script ONCE to build your character template library.
% It walks you through your enhanced plates one by one, lets you draw a
% box around each character, type its label, and saves the binary template.
%
% OUTPUT: Templates/ folder with one .png per character class, e.g.:
%   Templates/r.png   Templates/s.png   Templates/w.png
%   Templates/0.png   Templates/1.png   ... Templates/9.png
%
% HOW TO USE:
%   1. Run this script (F5).
%   2. A plate image appears zoomed in.
%   3. Draw a tight box around ONE character, double-click to confirm.
%   4. Type the character label in the console and press Enter.
%      Use the label list below. Type 'skip' to skip a plate.
%      Type 'done' when you have collected enough examples.
%   5. Repeat for all 27 character classes (18 letters + 9 digits).
%      You only need 1-3 examples per class minimum.
%
% ARABIC LETTER LABELS (type exactly as shown):
%   alef  ba    jeem  dal   ra    waw   seen  sad  ya
%   ta    ain   fa    qaf   kaf   lam   meem  noon ha
%
% DIGIT LABELS (just type the digit):
%    1  2  3  4  5  6  7  8  9
%
% TIP: Work through your clearest plates first (001, 002, 003...).
%      You can run this script multiple times - new crops are ADDED to the
%      existing Templates folder, never deleted.
% =========================================================================

clc; clear; close all;

% -------------------------------------------------------------------------
% CONFIGURATION
% -------------------------------------------------------------------------
ENHANCED_FOLDER  = 'Results';     % folder with enhanced_XXX.jpg files
TEMPLATES_FOLDER = 'Templates';   % output folder for templates
TEMPLATE_SIZE    = [40, 40];      % all templates saved at this size

% The 27 valid label strings (used to validate what the user types)
VALID_LABELS = { ...
    'alef', 'ba',   'jeem', 'dal',  'ra',  'seen', ...
    'sad',  'ta',   'ain',  'fa',   'qaf',  'kaf',  'lam',  ...
    'meem', 'noon', 'waw',  'ya',   'ha',   ...
    '1', '2', '3', '4', '5', '6', '7', '8', '9'};

% -------------------------------------------------------------------------
% SETUP
% -------------------------------------------------------------------------
if ~exist(TEMPLATES_FOLDER, 'dir')
    mkdir(TEMPLATES_FOLDER);
end

% Collect enhanced plate files
plateFiles = dir(fullfile(ENHANCED_FOLDER, 'enhanced_*.jpg'));
if isempty(plateFiles)
    plateFiles = dir(fullfile(ENHANCED_FOLDER, 'enhanced_*.png'));
end
if isempty(plateFiles)
    fprintf('[ERROR] No enhanced_*.jpg files found in "%s".\n', ENHANCED_FOLDER);
    fprintf('        Run run_stage1_outputs.m first.\n');
    return;
end

fprintf('==========================================================\n');
fprintf('  ECE 228 ALPR - Interactive Template Builder\n');
fprintf('  Found %d enhanced plates.\n', length(plateFiles));
fprintf('  Templates will be saved to: "%s"\n', TEMPLATES_FOLDER);
fprintf('==========================================================\n');
fprintf('  COMMANDS:\n');
fprintf('    Type a label -> saves the crop as a template\n');
fprintf('    skip         -> skip this plate, go to next\n');
fprintf('    done         -> stop and exit\n');
fprintf('==========================================================\n\n');

% Show label reference card
fprintf('  LETTER LABELS:\n');
fprintf('  alef=  ba=  jeem=  dal=  ha=  waw=  zay=\n');
fprintf('  seen=  sad=  ta=  ain=  fa=  qaf=  kaf=\n');
fprintf('  lam=  meem=  noon=\n');
fprintf('  DIGIT LABELS: 0 1 2 3 4 5 6 7 8 9\n\n');

% Track how many samples saved per class
savedCount = containers.Map('KeyType', 'char', 'ValueType', 'int32');
for v = 1:length(VALID_LABELS)
    savedCount(VALID_LABELS{v}) = 0;
end

% Check for already-saved templates and load their counts
for v = 1:length(VALID_LABELS)
    lbl = VALID_LABELS{v};
    existing = dir(fullfile(TEMPLATES_FOLDER, [lbl '_*.png']));
    if ~isempty(existing)
        savedCount(lbl) = length(existing);
    end
    % Also count the primary (no suffix) template
    if isfile(fullfile(TEMPLATES_FOLDER, [lbl '.png']))
        savedCount(lbl) = savedCount(lbl) + 1;
    end
end

% -------------------------------------------------------------------------
% MAIN LOOP - iterate over plates
% -------------------------------------------------------------------------
stopAll = false;

for i = 1:length(plateFiles)
    if stopAll, break; end

    plateImg = imread(fullfile(ENHANCED_FOLDER, plateFiles(i).name));

    fprintf('--- Plate: %s ---\n', plateFiles(i).name);
    fprintf('    Draw boxes around characters. Close figure to go to next plate.\n');

    % Display the plate zoomed in (scale up 2x for easier clicking)
    [pH, pW, ~] = size(plateImg);
    displayImg  = imresize(plateImg, [pH*2, pW*2]);

    hFig = figure('Name', ['Template Builder - ' plateFiles(i).name], ...
                  'Color', [0.10 0.10 0.10], ...
                  'Position', [50, 200, min(1200, pW*2 + 40), pH*2 + 80]);
    imshow(displayImg);
    title(['Plate: ' plateFiles(i).name ' | Draw box around a character, double-click to confirm'], ...
          'Color', 'w', 'FontSize', 10, 'Interpreter', 'none');
    colormap gray;

    % Let user crop characters one by one until they close the figure
    while ishandle(hFig)
        try
            % imcrop returns coordinates in DISPLAY image space
            [charCropDisplay, rectDisplay] = imcrop(displayImg);
        catch
            break;  % figure was closed
        end

        if isempty(charCropDisplay) || ~ishandle(hFig)
            break;
        end

        % Convert crop rectangle back to original image coordinates
        xOrig = round(rectDisplay(1) / 2);
        yOrig = round(rectDisplay(2) / 2);
        wOrig = round(rectDisplay(3) / 2);
        hOrig = round(rectDisplay(4) / 2);

        % Safety clamp
        xOrig = max(1, min(xOrig, pW));
        yOrig = max(1, min(yOrig, pH));
        x2    = min(pW, xOrig + wOrig - 1);
        y2    = min(pH, yOrig + hOrig - 1);

        if x2 <= xOrig || y2 <= yOrig
            fprintf('  [!] Crop too small, try again.\n');
            continue;
        end

        % Get the crop from the ORIGINAL resolution plate
        charOrig = plateImg(yOrig:y2, xOrig:x2, :);

        % Show the cropped character for confirmation
        figure('Name', 'Cropped Character Preview', ...
               'Position', [700, 400, 200, 200], ...
               'Color', [0.10 0.10 0.10]);
        imshow(imresize(charOrig, [120, 120]));
        title('This character?', 'Color', 'w', 'FontSize', 11);

        % Ask for label
        fprintf('  What character is this? (label / skip / done): ');
        labelInput = strtrim(input('', 's'));

        close(findobj('Name', 'Cropped Character Preview'));

        if strcmpi(labelInput, 'done')
            stopAll = true;
            break;
        end

        if strcmpi(labelInput, 'skip')
            fprintf('  Skipped.\n');
            break;
        end

        % Validate label
        isValid = any(strcmpi(VALID_LABELS, labelInput));
        if ~isValid
            fprintf('  [!] Unknown label "%s". Valid labels:\n', labelInput);
            fprintf('      %s\n', strjoin(VALID_LABELS, '  '));
            continue;
        end

        labelInput = lower(labelInput);

        % Process: grayscale -> binarize -> resize
        if size(charOrig, 3) == 3
            charGray = rgb2gray(charOrig);
        else
            charGray = charOrig;
        end

        % Otsu threshold - characters are dark on white background
        level    = graythresh(charGray);
        charBin  = ~imbinarize(charGray, level);   % invert: chars = white on black

        % Remove tiny noise blobs
        charBin  = bwareaopen(charBin, 10);

        % Tight crop: find actual character bounding box
        rows = any(charBin, 2);
        cols = any(charBin, 1);
        if any(rows) && any(cols)
            rmin = find(rows, 1, 'first');
            rmax = find(rows, 1, 'last');
            cmin = find(cols, 1, 'first');
            cmax = find(cols, 1, 'last');
            charBin = charBin(rmin:rmax, cmin:cmax);
        end

        % Resize to standard template size
        charResized = imresize(charBin, TEMPLATE_SIZE);
        charResized = charResized > 0.5;   % re-binarize after resize interpolation

        % Save template - if first sample use plain name, otherwise numbered
        existingCount = savedCount(labelInput);
        if existingCount == 0
            saveName = [labelInput '.png'];
        else
            saveName = sprintf('%s_%d.png', labelInput, existingCount + 1);
        end

        savePath = fullfile(TEMPLATES_FOLDER, saveName);
        imwrite(uint8(charResized) * 255, savePath);
        savedCount(labelInput) = savedCount(labelInput) + 1;

        fprintf('  [SAVED] "%s" -> %s  (total for this class: %d)\n', ...
                labelInput, saveName, savedCount(labelInput));

        % Update figure title with count
        if ishandle(hFig)
            figure(hFig);
            title(sprintf('Plate: %s | Saved %d templates so far - draw next character', ...
                          plateFiles(i).name, sum(cell2mat(values(savedCount)))), ...
                  'Color', [0.1 0.9 0.1], 'FontSize', 10, 'Interpreter', 'none');
        end
    end

    if ishandle(hFig), close(hFig); end
end

% -------------------------------------------------------------------------
% SUMMARY
% -------------------------------------------------------------------------
fprintf('\n==========================================================\n');
fprintf('  Template Building Complete!\n');
fprintf('==========================================================\n');
fprintf('  %-10s  %s\n', 'Label', 'Count');
fprintf('  %s\n', repmat('-', 1, 25));

totalSaved = 0;
missingLabels = {};
for v = 1:length(VALID_LABELS)
    lbl   = VALID_LABELS{v};
    count = savedCount(lbl);
    totalSaved = totalSaved + count;
    if count == 0
        missingLabels{end+1} = lbl; %#ok<AGROW>
        fprintf('  %-10s  %d  <-- MISSING\n', lbl, count);
    else
        fprintf('  %-10s  %d\n', lbl, count);
    end
end

fprintf('==========================================================\n');
fprintf('  Total templates saved: %d\n', totalSaved);
if ~isempty(missingLabels)
    fprintf('  Missing classes (%d): %s\n', ...
            length(missingLabels), strjoin(missingLabels, ', '));
    fprintf('  Run this script again to fill the missing classes.\n');
else
    fprintf('  All 27 classes covered! Ready for recognition.\n');
end
fprintf('==========================================================\n');
