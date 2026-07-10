% =========================================================================
% ECE 228 - ALPR | MAIN EXECUTION SCRIPT (Single Image End-to-End)
% =========================================================================
clc; clear; close all;

% --- 1. CONFIGURATION ---
DATASET_FOLDER   = 'Dataset';
TEMPLATES_FOLDER = 'Templates';
RESULTS_FOLDER   = 'Results';

% ---------------------------------------------------------
% 👉 CHANGE THIS NAME TO TEST DIFFERENT IMAGES!
imageName = 'img_044.jpg'; 
% ---------------------------------------------------------

imgPath = fullfile(DATASET_FOLDER, imageName);

fprintf('==========================================================\n');
fprintf('  ALPR Pipeline Running for: %s\n', imageName);
fprintf('==========================================================\n');

% Check if folders/files exist safely
if ~isfile(imgPath)
    error('Image %s not found in %s folder. Make sure the name is correct.', imageName, DATASET_FOLDER);
end
if ~exist(TEMPLATES_FOLDER, 'dir') || isempty(dir(fullfile(TEMPLATES_FOLDER, '*.png')))
    error('No templates found! Please run build_templates.m first to generate them.');
end
if ~exist(RESULTS_FOLDER, 'dir')
    mkdir(RESULTS_FOLDER);
end

% --- 2. STAGE 1: PLATE DETECTION ---
fprintf('[1/3] Detecting License Plate...\n');
imgRGB = imread(imgPath);

% We pass 'false' to hide the 6-panel debug UI from Stage 1 
[bestBbox, rawCrop, ~] = plate_rec_v2(imgRGB, false); 

if isempty(rawCrop) || isempty(bestBbox)
    fprintf('  -> [FAILED] No plate detected in the image.\n');
    return;
end
fprintf('  -> [SUCCESS] Plate detected at [x:%d, y:%d, w:%d, h:%d]\n', ...
    round(bestBbox(1)), round(bestBbox(2)), round(bestBbox(3)), round(bestBbox(4)));

% --- 3. STAGE 1.5: PLATE ENHANCEMENT ---
fprintf('[2/3] Enhancing and Flattening Plate...\n');
finalPlate = enhance_plate(rawCrop);

% Standardize the size (same logic used in your batch scripts)
if size(finalPlate, 1) ~= 200 || size(finalPlate, 2) ~= 440
    finalPlate = imresize(finalPlate, [200, 440]);
end

% Save enhanced plate to the Results folder
imwrite(finalPlate, fullfile(RESULTS_FOLDER, ['enhanced_' imageName]));

% --- 4. STAGE 2: OCR & RECOGNITION ---
fprintf('[3/3] Running Character Recognition...\n');
% The 'true' parameter automatically opens your 2-panel OCR Debug Window!
[plateText, charBboxes, charImgs] = recognize_plate(finalPlate, TEMPLATES_FOLDER, true);

% --- 5. FINAL OUTPUTS ---
fprintf('\n==========================================================\n');
fprintf('  FINAL RECOGNIZED TEXT :  %s\n', plateText);
fprintf('==========================================================\n');

% Show the original image with the detected green bounding box
hFig = figure('Name', ['Stage 1 Detection: ' imageName], 'Color', [0.15 0.15 0.15], 'Position', [100, 500, 700, 400]);
imshow(imgRGB); hold on;
rectangle('Position', bestBbox, 'EdgeColor', [0, 0.8, 0], 'LineWidth', 4);
title(['Stage 1 Detected BBox | File: ' imageName], 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');

% Save the annotated original image to the Results folder
saveas(hFig, fullfile(RESULTS_FOLDER, ['annotated_' imageName]));
fprintf('Saved enhanced and annotated images to "%s" folder.\n', RESULTS_FOLDER);