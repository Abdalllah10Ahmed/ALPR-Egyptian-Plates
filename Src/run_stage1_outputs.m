% =========================================================================
% ECE 228 - ALPR | Stage 1: Complete Output Generator
% =========================================================================
% This script produces ALL required Stage 1 deliverables for all 50 images:
%
%   OUTPUT 1 - Annotated image   : original photo with green bounding box
%              Saved to Results/annotated_XXX.jpg
%
%   OUTPUT 2 - Enhanced plate    : tight, straight, standardized plate crop
%              Saved to Results/enhanced_XXX.jpg
%
%   OUTPUT 3 - Detection result  : printed to console [DETECTED] / [FAILED]
%
%   OUTPUT 4 - Report figures    : 2-panel figure (annotated + zoomed plate)
%              Saved to Results/figure_XXX.jpg  (only for detected plates)
%
%   BONUS    - Summary montage   : all enhanced plates tiled in one figure
%              Saved to Results/summary_montage.jpg
%
% REQUIREMENTS:
%   plate_rec_v2.m  and  enhance_plate.m  must be in the same folder.
%   Dataset folder must contain img_001.jpg ... img_050.jpg
%
% HOW TO RUN:
%   Simply press Run (F5). Everything is automatic.
% =========================================================================

clc; clear; close all;

% -------------------------------------------------------------------------
% CONFIGURATION
% -------------------------------------------------------------------------
DATASET_FOLDER = 'Dataset';
RESULTS_FOLDER = 'Results';
NUM_IMAGES     = 50;

% Bounding box display settings
BBOX_COLOR     = [0, 220, 60];    % RGB color for bounding box  (green)
BBOX_THICKNESS = 6;               % Bounding box border thickness in pixels

% Standard output size (must match what enhance_plate.m produces)
PLATE_OUT_H    = 200;
PLATE_OUT_W    = 440;

% -------------------------------------------------------------------------
% FOLDER SETUP
% -------------------------------------------------------------------------
if ~exist(RESULTS_FOLDER, 'dir')
    mkdir(RESULTS_FOLDER);
end

% -------------------------------------------------------------------------
% TRACKING VARIABLES
% -------------------------------------------------------------------------
detectedCount  = 0;
failedCount    = 0;
allThumbs      = cell(1, NUM_IMAGES);   % for summary montage
resultTable    = cell(NUM_IMAGES, 3);   % {filename, status, bbox_str}

fprintf('==========================================================\n');
fprintf('  ECE 228 ALPR - Stage 1: Complete Output Generator\n');
fprintf('==========================================================\n\n');

% =========================================================================
% MAIN LOOP
% =========================================================================
for i = 1:NUM_IMAGES

    filename = sprintf('img_%03d.jpg', i);
    imgPath  = fullfile(DATASET_FOLDER, filename);

    % Store result for the summary table
    resultTable{i, 1} = filename;

    % --- Check file exists ---
    if ~isfile(imgPath)
        fprintf('[SKIP]     %s -> file not found\n', filename);
        resultTable{i, 2} = 'NOT FOUND';
        resultTable{i, 3} = '-';

        % Red placeholder for montage
        ph = zeros(PLATE_OUT_H, PLATE_OUT_W, 3, 'uint8');
        ph(:,:,1) = 120;
        allThumbs{i} = ph;
        continue;
    end

    % --- Load original image (kept for annotation) ---
    try
        imgRGB = imread(imgPath);
    catch
        fprintf('[ERROR]    %s -> could not read image\n', filename);
        resultTable{i, 2} = 'READ ERROR';
        resultTable{i, 3} = '-';
        continue;
    end

    % =====================================================================
    % STEP 1: PLATE DETECTION  (plate_rec_v2)
    % =====================================================================
    try
        [bestBbox, rawCrop, ~] = plate_rec_v2(imgPath, false);
    catch ME
        fprintf('[ERROR]    %s -> plate_rec_v2 crashed: %s\n', filename, ME.message);
        resultTable{i, 2} = 'CRASH';
        resultTable{i, 3} = '-';
        allThumbs{i} = make_fail_thumb(PLATE_OUT_H, PLATE_OUT_W, 255);
        continue;
    end

    % =====================================================================
    % STEP 2: HANDLE NOT-DETECTED CASE
    % =====================================================================
    if isempty(rawCrop) || isempty(bestBbox)
        failedCount = failedCount + 1;
        fprintf('[FAILED]   %s -> NO PLATE DETECTED\n', filename);

        resultTable{i, 2} = 'NOT DETECTED';
        resultTable{i, 3} = '-';

        allThumbs{i} = make_fail_thumb(PLATE_OUT_H, PLATE_OUT_W, 200);
        continue;
    end

    % =====================================================================
    % STEP 3: PLATE ENHANCEMENT  (enhance_plate)
    % =====================================================================
    try
        finalPlate = enhance_plate(rawCrop);
    catch ME
        fprintf('[ERROR]    %s -> enhance_plate crashed: %s\n', filename, ME.message);
        finalPlate = imresize(rawCrop, [PLATE_OUT_H, PLATE_OUT_W]);
    end

    % Guarantee standard size even if enhance_plate returned a different size
    if size(finalPlate, 1) ~= PLATE_OUT_H || size(finalPlate, 2) ~= PLATE_OUT_W
        finalPlate = imresize(finalPlate, [PLATE_OUT_H, PLATE_OUT_W]);
    end

    % =====================================================================
    % OUTPUT 1: ANNOTATED IMAGE  (original + green bounding box)
    % =====================================================================
    annotated = draw_bbox(imgRGB, bestBbox, BBOX_COLOR, BBOX_THICKNESS);
    annotatedName = sprintf('annotated_%03d.jpg', i);
    imwrite(annotated, fullfile(RESULTS_FOLDER, annotatedName), 'Quality', 95);

    % =====================================================================
    % OUTPUT 2: ENHANCED PLATE CROP
    % =====================================================================
    enhancedName = sprintf('enhanced_%03d.jpg', i);
    imwrite(finalPlate, fullfile(RESULTS_FOLDER, enhancedName), 'Quality', 95);

    % =====================================================================
    % OUTPUT 3: PRINTED DETECTION RESULT
    % =====================================================================
    bboxStr = sprintf('[x=%d y=%d w=%d h=%d]', ...
        round(bestBbox(1)), round(bestBbox(2)), ...
        round(bestBbox(3)), round(bestBbox(4)));

    fprintf('[DETECTED] %s -> Bbox: %s\n', filename, bboxStr);

    % =====================================================================
    % OUTPUT 4: REPORT FIGURE  (2-panel: annotated original + zoomed plate)
    % =====================================================================
    figName   = sprintf('figure_%03d.jpg', i);
    figPath   = fullfile(RESULTS_FOLDER, figName);
    save_report_figure(annotated, finalPlate, bestBbox, filename, figPath);

    % =====================================================================
    % Store for summary montage
    % =====================================================================
    detectedCount = detectedCount + 1;
    allThumbs{i}  = imresize(finalPlate, [60, 200]);

    resultTable{i, 2} = 'DETECTED';
    resultTable{i, 3} = bboxStr;

end % end main loop

% =========================================================================
% SUMMARY MONTAGE  (all enhanced plates tiled together)
% =========================================================================
fprintf('\n----------------------------------------------------------\n');
fprintf('  Generating summary montage...\n');

% Fill any empty cells with grey placeholder for not-detected images
for i = 1:NUM_IMAGES
    if isempty(allThumbs{i})
        ph = ones(60, 200, 3, 'uint8') * 60;
        allThumbs{i} = ph;
    end
end

hFig = figure('Name', 'ALPR Stage 1 - All Results', ...
              'Color',    [0.10 0.10 0.10], ...
              'Position', [50, 50, 1200, 700]);

montage(allThumbs, ...
        'Size',            [5, 10], ...
        'ThumbnailSize',   [60, 200], ...
        'BackgroundColor', [0.10 0.10 0.10]);

accuracy = (detectedCount / NUM_IMAGES) * 100;
titleStr  = sprintf('Stage 1 Results: %d / %d Detected  (%.1f%% Accuracy)  |  Red = Not Detected', ...
                    detectedCount, NUM_IMAGES, accuracy);
title(titleStr, 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');

montageFile = fullfile(RESULTS_FOLDER, 'summary_montage.jpg');
exportgraphics(hFig, montageFile, 'Resolution', 150);

% =========================================================================
% PRINT FINAL SUMMARY TABLE
% =========================================================================
fprintf('\n==========================================================\n');
fprintf('  FINAL RESULTS TABLE\n');
fprintf('==========================================================\n');
fprintf('  %-18s  %-14s  %s\n', 'File', 'Status', 'BBox');
fprintf('  %s\n', repmat('-', 1, 60));
for i = 1:NUM_IMAGES
    if ~isempty(resultTable{i, 1})
        fprintf('  %-18s  %-14s  %s\n', ...
            resultTable{i,1}, resultTable{i,2}, resultTable{i,3});
    end
end
fprintf('==========================================================\n');
fprintf('  DETECTED  : %d / %d\n', detectedCount, NUM_IMAGES);
fprintf('  FAILED    : %d / %d\n', NUM_IMAGES - detectedCount, NUM_IMAGES);
fprintf('  ACCURACY  : %.1f%%\n',  accuracy);
fprintf('==========================================================\n');
fprintf('  Saved to  : "%s" folder\n', RESULTS_FOLDER);
fprintf('    annotated_XXX.jpg  - original with bounding box\n');
fprintf('    enhanced_XXX.jpg   - clean cropped plate\n');
fprintf('    figure_XXX.jpg     - 2-panel report figure\n');
fprintf('    summary_montage.jpg- all plates tiled\n');
fprintf('==========================================================\n');


% =========================================================================
% HELPER FUNCTIONS
% =========================================================================

% -------------------------------------------------------------------------
% draw_bbox: draws a colored filled-border rectangle on an RGB image.
%   img   - uint8 RGB image
%   bb    - [x, y, w, h] bounding box (MATLAB regionprops convention)
%   color - [R, G, B]  values 0-255
%   thick - border thickness in pixels
% -------------------------------------------------------------------------
function img = draw_bbox(img, bb, color, thick)
    [imgH, imgW, ~] = size(img);

    x1 = max(1,    round(bb(1)));
    y1 = max(1,    round(bb(2)));
    x2 = min(imgW, round(bb(1) + bb(3) - 1));
    y2 = min(imgH, round(bb(2) + bb(4) - 1));

    % Draw four sides (top, bottom, left, right) by writing color to pixel bands
    % Top edge
    r1t = max(1, y1);
    r2t = min(imgH, y1 + thick - 1);
    img(r1t:r2t, x1:x2, 1) = color(1);
    img(r1t:r2t, x1:x2, 2) = color(2);
    img(r1t:r2t, x1:x2, 3) = color(3);

    % Bottom edge
    r1b = max(1, y2 - thick + 1);
    r2b = min(imgH, y2);
    img(r1b:r2b, x1:x2, 1) = color(1);
    img(r1b:r2b, x1:x2, 2) = color(2);
    img(r1b:r2b, x1:x2, 3) = color(3);

    % Left edge
    c1l = max(1, x1);
    c2l = min(imgW, x1 + thick - 1);
    img(y1:y2, c1l:c2l, 1) = color(1);
    img(y1:y2, c1l:c2l, 2) = color(2);
    img(y1:y2, c1l:c2l, 3) = color(3);

    % Right edge
    c1r = max(1, x2 - thick + 1);
    c2r = min(imgW, x2);
    img(y1:y2, c1r:c2r, 1) = color(1);
    img(y1:y2, c1r:c2r, 2) = color(2);
    img(y1:y2, c1r:c2r, 3) = color(3);
end


% -------------------------------------------------------------------------
% save_report_figure: builds and saves the 2-panel report figure.
%   annotated  - original image with bbox already drawn
%   plateImg   - enhanced plate crop
%   bestBbox   - [x,y,w,h] for zoomed inset label
%   titleStr   - image filename shown as title
%   savePath   - full path to save the .jpg figure
% -------------------------------------------------------------------------
function save_report_figure(annotated, plateImg, bestBbox, titleStr, savePath)
    try
        hFig = figure('Visible', 'off', ...
                      'Color',    [0.10 0.10 0.10], ...
                      'Position', [200, 200, 900, 340]);

        % --- Left panel: annotated original ---
        ax1 = subplot(1, 2, 1);
        imshow(annotated);
        bboxStr = sprintf('Bbox: x=%d  y=%d  w=%d  h=%d', ...
            round(bestBbox(1)), round(bestBbox(2)), ...
            round(bestBbox(3)), round(bestBbox(4)));
        title({['Image: ' titleStr], bboxStr}, ...
              'Color', 'w', 'FontSize', 8, 'Interpreter', 'none');

        % --- Right panel: zoomed enhanced plate ---
        ax2 = subplot(1, 2, 2);
        imshow(plateImg);
        title('Zoomed Plate (Enhanced)', ...
              'Color', [0.1 0.95 0.1], 'FontSize', 10, 'FontWeight', 'bold');

        % Style both axes
        set(ax1, 'Color', [0.08 0.08 0.08]);
        set(ax2, 'Color', [0.08 0.08 0.08]);

        sgtitle('DETECTED  -  ECE 228 ALPR Stage 1', ...
                'Color', [0.1 0.95 0.1], 'FontSize', 12, 'FontWeight', 'bold');

        exportgraphics(hFig, savePath, 'Resolution', 120);
        close(hFig);
    catch
        % Non-critical: skip saving the figure if something goes wrong
    end
end


% -------------------------------------------------------------------------
% make_fail_thumb: creates a colored failure block for the montage.
% -------------------------------------------------------------------------
function thumb = make_fail_thumb(H, W, redLevel)
    thumb = zeros(H, W, 3, 'uint8');
    thumb(:,:,1) = redLevel;
end
