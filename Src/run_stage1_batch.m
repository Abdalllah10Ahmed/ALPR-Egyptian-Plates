% =========================================================================
% ECE 228 - ALPR | Stage 1: Batch Evaluator & Montage Generator
% =========================================================================
clc; clear; close all;

% --- 1. FOLDER SETUP ---
datasetFolder = 'Dataset'; 
resultsFolder = 'Results'; 

% Create Results folder if it doesn't exist
if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder);
end

numImages = 50;
detectedCount = 0;
allCroppedPlates = cell(1, numImages);

fprintf('===================================================\n');
fprintf('Starting ALPR Stage 1 Batch Evaluation...\n');
fprintf('===================================================\n');

% --- 2. BATCH PROCESSING LOOP ---
for i = 1:numImages
    % Construct the required filename: img_001.jpg to img_050.jpg
    filename = sprintf('img_%03d.jpg', i);
    imgPath = fullfile(datasetFolder, filename);
    
    % Check if file actually exists in the folder
    if ~isfile(imgPath)
        fprintf('Warning: File %s not found. Skipping...\n', filename);
        continue;
    end
    
    % Run the ALPR function. 
    % IMPORTANT: We pass 'false' to suppress the 6-panel UI from popping up!
    try
        % STEP 1: Detect and Crop (The 86% Accuracy Masterpiece)
        [bestBbox, rawCrop, ~] = plate_rec_v2(imgPath, false);
        
        if ~isempty(rawCrop)
            detectedCount = detectedCount + 1;
            
            % STEP 2: Enhance and Flatten (Separated safely!)
            finalCroppedPlate = enhance_plate(rawCrop);
            
            % Resize the crop to a standard size just for the summary montage
            stdCrop = imresize(finalCroppedPlate, [60, 200]);
            allCroppedPlates{i} = stdCrop;
            
            % Save the enhanced image to the Results folder
            outName = sprintf('crop_%03d.jpg', i);
            imwrite(finalCroppedPlate, fullfile(resultsFolder, outName));
            fprintf('[SUCCESS] %s -> Plate Detected, Enhanced, and Saved.\n', filename);
        else
            % Create a red "FAILED" block for the summary montage
            failImg = zeros(60, 200, 3, 'uint8');
            failImg(:,:,1) = 255; % Pure Red
            allCroppedPlates{i} = failImg;
            fprintf('[FAILED]  %s -> NO PLATE DETECTED.\n', filename);
        end
    catch ME
        fprintf('[ERROR]   %s -> Code crashed: %s\n', filename, ME.message);
    end
end

% --- 3. SHOW ALL RESULTS AT ONCE (MONTAGE) ---
% Remove empty cells in case you have less than 50 images right now
validPlates = allCroppedPlates(~cellfun(@isempty, allCroppedPlates));

if ~isempty(validPlates)
    hFig = figure('Name', 'ALPR Stage 1 - Batch Summary', 'Color', [0.12 0.12 0.12], 'Position', [100, 100, 1200, 800]);
    
    % Use MATLAB's montage function to tile all the crops together
    montage(validPlates, 'Size', [5, 10], 'ThumbnailSize', [60 200], 'BackgroundColor', [0.12 0.12 0.12]);
    
    titleStr = sprintf('ALPR Stage 1 Results: %d / %d Detected (%.1f%% Accuracy)', ...
        detectedCount, numImages, (detectedCount/numImages)*100);
    title(titleStr, 'Color', 'w', 'FontSize', 16, 'FontWeight', 'bold');
end

fprintf('===================================================\n');
fprintf('Batch Processing Complete!\n');
fprintf('Total Detection Accuracy: %.1f%%\n', (detectedCount/numImages)*100);
fprintf('Check the "Results" folder for the saved images.\n');
fprintf('===================================================\n');