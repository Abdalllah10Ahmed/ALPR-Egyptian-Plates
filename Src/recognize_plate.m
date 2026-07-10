function [plateText, charBboxes, charImgs] = recognize_plate(plateImg, templatesFolder, showDbg)
% =========================================================================
% ECE 228 - ALPR | Stage 2: Character Recognition (The OCR Engine)
% =========================================================================

    if nargin < 3, showDbg = false; end
    
    charBboxes = [];
    charImgs = {};
    plateText = '';
    
    [imgH, imgW, ~] = size(plateImg);

    % =====================================================================
    % 1. TEMPLATE LOADING & CATEGORIZATION
    % =====================================================================
    % We split templates into digits and letters so the engine never 
    % confuses a '1' with an 'Alef'.
    templateFiles = dir(fullfile(templatesFolder, '*.png'));
    if isempty(templateFiles)
        error('No templates found in %s', templatesFolder);
    end
    
    letterTpl = {}; digitTpl = {};
    digitLabels = {'1','2','3','4','5','6','7','8','9','0'};
    
    for i = 1:length(templateFiles)
        % Read image and binarize
        img = imread(fullfile(templatesFolder, templateFiles(i).name));
        img = img > 0.5; % Ensure strict binary logic
        
        % Extract the core label (handles both "ra.png" and "ra_2.png")
        nameParts = strsplit(templateFiles(i).name, '_');
        coreLabel = strrep(nameParts{1}, '.png', '');
        
        tplStruct = struct('img', img, 'label', coreLabel);
        
        if ismember(coreLabel, digitLabels)
            digitTpl{end+1} = tplStruct; %#ok<AGROW>
        else
            letterTpl{end+1} = tplStruct; %#ok<AGROW>
        end
    end

    % =====================================================================
    % 2. PRE-PROCESSING & BINARIZATION
    % =====================================================================
    topCrop   = round(imgH * 0.18); 
    botCrop   = round(imgH * 0.85); 
    leftCrop  = round(imgW * 0.02); 
    rightCrop = round(imgW * 0.98); 
    
    roiImg = plateImg(topCrop:botCrop, leftCrop:rightCrop, :);
    [roiH, roiW, ~] = size(roiImg);
    
    grayImg = rgb2gray(roiImg);
    
    % Adaptive thresholding
    bw = imbinarize(grayImg, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', 0.45);
    bw = ~bw; 
    
    % --- WEAPON 1: THE DIVIDER KILLER ---
    midX = round(roiW / 2);
    bw(:, midX-8 : midX+8) = 0; 
    
    % --- WEAPON 2: SAFE BORDER WIPE ---
    safeTopEdge = max(1, round(roiH * 0.2)); 
    bw(1:safeTopEdge, :) = 0;           
    bw(end-12:end, :) = 0;    
    bw(:, 1:4) = 0;         
    bw(:, end-3:end) = 0;   
    
    % --- WEAPON 3: THE HORIZONTAL LINE DESTRUCTOR ---
    % If a thick shadow leaked in, it forms a solid horizontal white line.
    % Real text will never take up 55% of the plate width on a single pixel row.
    % If a row is > 55% white, it's a frame artifact. Vaporize it!
    rowSums = sum(bw, 2);
    bw(rowSums > (roiW * 0.55), :) = 0;
    
    % --- WEAPON 4: THE PURE VERTICAL HEALER ---
    % A width of 1 pixel makes it mathematically impossible to glue 
    % adjacent numbers together horizontally, but still heals vertical breaks!
    bw = imclose(bw, strel('rectangle', [6, 1]));
    bw = imopen(bw, strel('rectangle', [2, 2]));
    
    % Save the "Raw" copy
    bw_raw = bw;
    
    % The rock-solid noise filter
    bw_clean = bwareaopen(bw, 40); 

    % =====================================================================
    % 3. SEGMENTATION (REGION EXTRACTION)
    % =====================================================================
    stats = regionprops(bw_clean, 'BoundingBox', 'Image', 'Centroid');
    validStats = [];
    
    for i = 1:length(stats)
        bb = stats(i).BoundingBox;
        
        x = max(1, round(bb(1)));
        y = max(1, round(bb(2)));
        w = round(bb(3)); 
        h = round(bb(4));
        ar = w / max(h, 1);
        
        % --- THE WIDTH LIMITER ---
        % Added w < (roiW * 0.25). A single character will never span > 25% of the plate.
        % This absolutely prevents massive green boxes from passing through!
        if h > (roiH * 0.20) && h < (roiH * 0.85) && w > 6 && w < (roiW * 0.25) && ar > 0.08 && ar < 2.2
            
            % Your dialed-in look-up parameter!
            padUp = round(h * 0.25); 
            padX  = 2; 
            
            x1 = max(1, x - padX);
            x2 = min(roiW, x + w + padX - 1);
            y1 = max(safeTopEdge + 1, y - padUp);
            y2 = min(roiH, y + h - 1);
            
            % Grab the pixel data
            charImgRaw = bw_raw(y1:y2, x1:x2);
            
            % THE GUILLOTINE
            charImgRaw(1:min(2, size(charImgRaw, 1)), :) = 0;
            
            % Strict dust filter
            charImgRaw = bwareaopen(charImgRaw, 15); 
            
            % Tight crop
            rows = any(charImgRaw, 2);
            cols = any(charImgRaw, 1);
            
            if any(rows) && any(cols)
                r1 = find(rows, 1, 'first');
                r2 = find(rows, 1, 'last');
                c1 = find(cols, 1, 'first');
                c2 = find(cols, 1, 'last');
                
                finalChar = charImgRaw(r1:r2, c1:c2);
                
                newX = x1 + c1 - 1;
                newY = y1 + r1 - 1;
                newW = c2 - c1 + 1;
                newH = r2 - r1 + 1;
                
                % THE GROWTH LIMITER
                if newH > (h * 1.35) || newW > (w * 1.25)
                    finalChar = stats(i).Image;
                    newX = x; newY = y; newW = w; newH = h;
                end
            else
                finalChar = stats(i).Image;
                newX = x; newY = y; newW = w; newH = h;
            end
            
            % Package for your OCR Matcher
            s = struct();
            s.BoundingBox = [newX, newY, newW, newH];
            s.Centroid = [newX + newW/2, newY + newH/2];
            s.Image = finalChar;
            
            validStats = [validStats; s]; %#ok<AGROW>
        end
    end
    
    if isempty(validStats)
        return;
    end
    
    % =====================================================================
    % 4. SORTING (STRICT RIGHT-TO-LEFT)
    % =====================================================================
    cx = arrayfun(@(s) s.Centroid(1), validStats);
    [~, sortIdx] = sort(cx, 'descend');
    validStats = validStats(sortIdx);

    % =====================================================================
    % 5. TEMPLATE MATCHING (IoU / JACCARD INDEX)
    % =====================================================================
    detectedLetters = {};
    detectedDigits  = {};
    
    for i = 1:length(validStats)
        charImg = validStats(i).Image;
        charResized = imresize(charImg, [40, 40]);
        charResized = charResized > 0.5;
        
        % Map X and Y back to the original 200x440 image coordinates!
        realX = validStats(i).BoundingBox(1) + leftCrop - 1;
        realY = validStats(i).BoundingBox(2) + topCrop - 1;
        realW = validStats(i).BoundingBox(3);
        realH = validStats(i).BoundingBox(4);
        
        charBboxes = [charBboxes; realX, realY, realW, realH]; %#ok<AGROW>
        charImgs{end+1} = charResized; %#ok<AGROW>
        
        % Check side of the plate (Left = Digit, Right = Letter)
        isLetter = (realX + realW/2) > (imgW * 0.5);
        
        if isLetter
            templatesToSearch = letterTpl;
        else
            templatesToSearch = digitTpl;
        end
        
        % Find the best match using Intersection over Union (IoU)
        bestScore = 0;
        bestLabel = '?';
        
        for t = 1:length(templatesToSearch)
            tplImg = templatesToSearch{t}.img;
            
            % Intersection (pixels where both are white)
            intersection = sum(charResized(:) & tplImg(:));
            % Union (pixels where either is white)
            union = sum(charResized(:) | tplImg(:));
            
            score = intersection / union;
            
            if score > bestScore
                bestScore = score;
                bestLabel = templatesToSearch{t}.label;
            end
        end
        
        % Append to appropriate list based on side
        if isLetter
            detectedLetters{end+1} = bestLabel; %#ok<AGROW>
        else
            detectedDigits{end+1} = bestLabel; %#ok<AGROW>
        end
    end
    
    % Assemble final string: "letters | digits"
    strLetters = strjoin(detectedLetters, ' ');
    strDigits  = strjoin(detectedDigits, ' ');
    plateText  = sprintf('%s | %s', strLetters, strDigits);

    % =====================================================================
    % 6. DEBUG VISUALIZATION
    % =====================================================================
    if showDbg
        figure('Name', ['OCR Debug: ' plateText], 'Color', [0.15 0.15 0.15], 'Position', [150, 150, 900, 400]);
        
        subplot(2,1,1);
        imshow(plateImg); hold on;
        title(['Final Read: ' plateText], 'Color', 'w', 'FontSize', 14);
        
        for i = 1:size(charBboxes, 1)
            bb = charBboxes(i, :);
            rectangle('Position', bb, 'EdgeColor', 'g', 'LineWidth', 2);
            
            % Determine if it was recognized as letter or digit for debug text
            if (bb(1) + bb(3)/2) > (imgW * 0.5)
                lbl = detectedLetters{min(i, length(detectedLetters))};
            else
                % Offset digit index by length of letters to map back
                idx = i - length(detectedLetters);
                lbl = detectedDigits{max(1, min(idx, length(detectedDigits)))};
            end
            
            text(bb(1), bb(2) - 10, lbl, 'Color', 'g', 'FontSize', 12, 'FontWeight', 'bold');
        end
        
        subplot(2,1,2);
        imshow(bw_clean);
        title('Adaptive Binarization & Segmented Blobs', 'Color', 'w');
    end
end

