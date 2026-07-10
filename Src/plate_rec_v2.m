function [bestBbox, croppedPlate, scoreLog] = plate_rec_v2(inputPath, showUI)
% =========================================================================
% ECE 228 - ALPR | Stage 1: The Masterpiece (Anti-Logo & Anti-Grille Fix)
% =========================================================================
    if nargin < 2
        showUI = true; 
    end
    % --- 1. LOAD & VALIDATE INPUT ---
    if ischar(inputPath) || isstring(inputPath)
        imgRGB = imread(char(inputPath));
    elseif isnumeric(inputPath) && ndims(inputPath) >= 2
        imgRGB = inputPath;
    else
        error('Invalid input');
    end
    
    if ~isa(imgRGB, 'uint8')
        imgRGB = im2uint8(imgRGB);
    end
    if size(imgRGB, 3) == 1
        imgRGB = cat(3, imgRGB, imgRGB, imgRGB);
    end
    imgH = size(imgRGB, 1);
    imgW = size(imgRGB, 2);
    imgCenterX = imgW / 2.0;
    bestBbox = [];
    croppedPlate = [];
    scoreLog = table();
    
    % --- 2. PRE-PROCESSING ---
    grayImg = rgb2gray(imgRGB);
    claheImg = adapthisteq(grayImg, 'ClipLimit', 0.02, 'NumTiles', [8, 8]);
    gaussKernel = fspecial('gaussian', [3, 3], 1.0);
    smoothGray = imfilter(grayImg, gaussKernel, 'replicate');
    
    % --- 3. EDGE DETECTION ---
    [~, autoThresh] = edge(smoothGray, 'sobel');
    
    % Using 0.30 here based on our earlier fix to catch the Arabic letters!
    edgeThresh = autoThresh * 0.33; 
    
    edgeImgFull = edge(smoothGray, 'sobel', edgeThresh);
    edgeImgVert = edge(smoothGray, 'sobel', edgeThresh, 'vertical');
    edgeImgHorz = edge(smoothGray, 'sobel', edgeThresh, 'horizontal');
    
    % --- 4. MORPHOLOGY ---
    seClose = strel('rectangle', [3, 35]);
    morphImg = imclose(edgeImgVert, seClose);
    morphImg = imopen(morphImg, strel('rectangle', [2, 2]));
    morphImg = imfill(morphImg, 'holes');
    morphImg = bwareaopen(morphImg, 40);
    
    % --- 5. REGION EXTRACTION & HARD FILTERS ---
    stats = regionprops(morphImg, 'BoundingBox', 'Area', 'Extent');
    logRows = {};
    
    % رفع الحد الأدنى للعرض لقتل الفتافيت
    minWidth = 0.08 * imgW;
    maxWidth = 0.55 * imgW; 
    safeYTop = 0.35 * imgH; % نزلنا السقف شوية لتجنب هواية الكبوت والمساحات
    safeYBot = 0.95 * imgH;
    safeXLeft = 0.10 * imgW;
    safeXRight = 0.90 * imgW;
    
    for k = 1:length(stats)
        bb = stats(k).BoundingBox;
        x = bb(1); y = bb(2); w = bb(3); h = bb(4);
        A = stats(k).Area;
        E = stats(k).Extent;
        ar = w / max(h, 1);
        
        % أ. القيود الهندسية
        if ar < 1.4 || ar > 3.0, continue; end 
        if E < 0.20, continue; end 
        if A < 150, continue; end % رفعنا المساحة لقتل اللوجوهات الصغيرة جداً
        if w < minWidth || w > maxWidth, continue; end 
        
        % ب. تفعيل مناطق الحظر
        if y < safeYTop || (y + h) > safeYBot, continue; end
        if x < safeXLeft || (x + w) > safeXRight, continue; end
        
        % ج. بوابة خط المنتصف
        centerTolerance = 0.15 * imgW; 
        if (x > imgCenterX + centerTolerance) || ((x + w) < imgCenterX - centerTolerance)
            continue; 
        end
        
        % --- 6. ADVANCED HEURISTIC SCORING (التقييم المضاد للوجو والشبكة) ---
        r1 = max(1, round(y)); r2 = min(imgH, round(y + h - 1));
        c1 = max(1, round(x)); c2 = min(imgW, round(x + w - 1));
        boxPixels = (r2 - r1 + 1) * (c2 - c1 + 1);
        
        % 1. Vertical Edge Density (كثافة الحروف)
        roiVert = edgeImgVert(r1:r2, c1:c2);
        vertDensity = sum(roiVert(:)) / boxPixels;
        
        % 2. Aspect Ratio Score (النسبة الذهبية للوحة 2.2)
        arScore = exp(-0.5 * ((ar - 2.2) / 1.5)^2);
        
        % 3. Extent / Solidity Score (قاتل الشبكات المفرغة)
        extentScore = E^2;

        % 4. H/V Edge Balance (قاتل الإكصدام والشبكة الأفقية)
        roiHorz = edgeImgHorz(r1:r2, c1:c2);
        nVert = sum(roiVert(:));
        nHorz = sum(roiHorz(:));
        vhRatio = nVert / max(nHorz, 1);
        if vhRatio < 0.8
            vhMult = 0.1; % عقاب شديد لأي حاجة خطوطها بالعرض
        else
            vhMult = vhRatio;
        end

        % 5. Contrast (يقتل الأسفلت)
        roiClahe = double(claheImg(r1:r2, c1:c2));
        roiMean = max(mean(roiClahe(:)), 1.0); 
        roiStd = std(roiClahe(:));
        contrastCV = min((roiStd / roiMean) / 0.5, 1.0)^2; 
        
        % 6. Center Bias (يفضل اللي في النص بالظبط)
        boxCentreX = x + w / 2.0;
        centerMult = exp(-2.0 * abs(boxCentreX - imgCenterX) / imgCenterX);

        % 7. Bottom Bonus Cubed (يجبر الكود يبص تحت على الإكصدام)
        bottomBonus = ((y + h) / imgH)^3;
        
        % 8. Plate Brightness (يقتل اللوجو الكروم اللي على شبكة سوداء)
        roiGray = double(grayImg(r1:r2, c1:c2));
        meanBrightness = mean(roiGray(:)) / 255.0; % Will be high for white plates, low for grilles
        
        % --- WEAPON 1: THE BLUE BAND CHECK (Egyptian Plates) ---
        roiRGB = imgRGB(r1:r2, c1:c2, :);
        roiHSV = rgb2hsv(roiRGB);
        
        % In HSV, blue hue is roughly between 0.55 and 0.75
        blueMask = (roiHSV(:,:,1) > 0.55) & (roiHSV(:,:,1) < 0.75) & (roiHSV(:,:,2) > 0.4);
        blueRatio = sum(blueMask(:)) / boxPixels;
        
        % If there is almost zero blue, KILL IT. It's not an Egyptian plate.
        if blueRatio < 0.02
            continue; 
        end
        
        % If it has good blue, give it a massive multiplier
        blueBonus = 1.0 + (blueRatio * 20); 

        % --- WEAPON 2: THE TEXT CROSSING COUNT (Anti-Empty-Space) ---
        midRow = round((r2-r1+1)/2); % Find the vertical middle of the box
        if midRow > 0 && midRow <= size(roiVert, 1)
            % Extract the middle horizontal line from the edge image
            middleSlice = roiVert(midRow, :);
            
            % Count how many times the pixels transition from 0 to 1 (finding an edge)
            transitions = sum(diff(middleSlice) > 0);
            
            % If there are not enough text strokes, kill it
            if transitions < 6
               continue; 
            end
        end

        % 💡 المعادلة النهائية (The Nuclear Option - Removed sqrt(A))
        finalScore = vertDensity * arScore * extentScore * vhMult * contrastCV * centerMult * bottomBonus * meanBrightness * blueBonus;
        
        logRows{end+1} = {x, y, w, h, A, arScore, extentScore, vhMult, finalScore}; %#ok<AGROW>
        
    end
    
    % --- 7. SELECTION & TIGHT CROPPING ---
    if isempty(logRows)
        if showUI, visualize_pipeline(imgRGB, claheImg, edgeImgVert, morphImg, scoreLog, bestBbox, safeXLeft, safeYTop, safeXRight-safeXLeft, safeYBot-safeYTop, imgCenterX); end
        return;
    end
    
    scoreLog = cell2table(vertcat(logRows{:}), ...
        'VariableNames', {'X', 'Y', 'W', 'H', 'Area', 'ArScore', 'ExtentScore', 'VHMult', 'FinalScore'});
    scoreLog = sortrows(scoreLog, 'FinalScore', 'descend');
    bestBbox = [scoreLog.X(1), scoreLog.Y(1), scoreLog.W(1), scoreLog.H(1)];
    
    % --- DYNAMIC PADDING FIX ---
    % Instead of fixed pixels, calculate padding as a percentage of the box size.
    % This adapts automatically to how far away the car is.
    % --- DYNAMIC ASYMMETRIC PADDING FIX ---
    boxW = bestBbox(3);
    boxH = bestBbox(4);
    
    % 1. Horizontal: Add 20% to left and right to capture the wide Arabic letters
    padX = round(boxW * 0.20); 
    
    % 2. Vertical: Egyptian Blue Band is always on TOP. Pad aggressively upwards!
    padY_top = round(boxH * 0.50); % 50% upwards reach for the blue band
    padY_bot = round(boxH * 0.15); % 15% downwards reach for the bottom lip
    
    xCrop = max(1, round(bestBbox(1)) - padX);
    yCrop = max(1, round(bestBbox(2)) - padY_top);
    xEnd = min(imgW, round(bestBbox(1) + boxW - 1) + padX);
    yEnd = min(imgH, round(bestBbox(2) + boxH - 1) + padY_bot);
    
    croppedPlate = imgRGB(yCrop:yEnd, xCrop:xEnd, :);
    
    % --- 8. VISUALIZATION ---
    if showUI
        visualize_pipeline(imgRGB, claheImg, edgeImgVert, morphImg, scoreLog, bestBbox, safeXLeft, safeYTop, safeXRight-safeXLeft, safeYBot-safeYTop, imgCenterX);
    end
end

% =========================================================================
% VISUALIZATION HELPER
% =========================================================================
function visualize_pipeline(imgRGB, claheImg, edgeImgVert, morphImg, scoreLog, bestBbox, roiX, roiY, roiW, roiH, imgCenterX)
    hFig = figure('Name', 'ALPR Stage 1 - Anti-Logo & Grille Fix', 'NumberTitle', 'off', 'Color', [0.12 0.12 0.12], 'Position', [40, 40, 1200, 680]);
    
    subplot(2, 3, 1); imshow(imgRGB); hold on;
    rectangle('Position', [roiX, roiY, roiW, roiH], 'EdgeColor', 'y', 'LineWidth', 2, 'LineStyle', '--');
    title('1. Original + Safe Zones', 'Color', 'w', 'FontSize', 10);
    
    subplot(2, 3, 2); imshow(claheImg, []);
    title('2. Brightness Map (CLAHE)', 'Color', 'w', 'FontSize', 10);
    
    subplot(2, 3, 3); imshow(edgeImgVert);
    title('3. Texture (Vertical Edges)', 'Color', 'w', 'FontSize', 10);
    
    subplot(2, 3, 4); imshow(morphImg);
    title('4. Morphological Blocks', 'Color', 'w', 'FontSize', 10);
    
    subplot(2, 3, 5); imshow(imgRGB); hold on;
    rectangle('Position', [roiX, roiY, roiW, roiH], 'EdgeColor', 'y', 'LineWidth', 1.5, 'LineStyle', '--');
    
    plot([imgCenterX, imgCenterX], [1, size(imgRGB,1)], 'c:', 'LineWidth', 1.5);
    if ~isempty(scoreLog) && height(scoreLog) > 0
        for k = 1:height(scoreLog)
            gb = [scoreLog.X(k), scoreLog.Y(k), scoreLog.W(k), scoreLog.H(k)];
            rectangle('Position', gb, 'EdgeColor', [0.2, 0.5, 1.0], 'LineWidth', 1.0);
        end
    end
    if ~isempty(bestBbox)
        rectangle('Position', bestBbox, 'EdgeColor', [0.1, 0.9, 0.1], 'LineWidth', 3.0);
    end
    hold off;
    title('5. Logic Evaluation (Shape & Solidity Evaluated)', 'Color', 'w', 'FontSize', 10);
    
    subplot(2, 3, 6);
    if ~isempty(bestBbox)
        boxW = bestBbox(3); boxH = bestBbox(4);
        padX = round(boxW * 0.20); 
        padY_top = round(boxH * 0.50); 
        padY_bot = round(boxH * 0.15);
        
        xCrop = max(1, round(bestBbox(1)) - padX);
        yCrop = max(1, round(bestBbox(2)) - padY_top);
        xEnd = min(size(imgRGB,2), round(bestBbox(1) + boxW - 1) + padX);
        yEnd = min(size(imgRGB,1), round(bestBbox(2) + boxH - 1) + padY_bot);
        
        imshow(imgRGB(yCrop:yEnd, xCrop:xEnd, :));
        title('6. Cropped Plate (Asymmetric)', 'Color', [0.1 0.9 0.1], 'FontSize', 11, 'FontWeight', 'bold');
    else
        imshow(zeros(60, 200, 3, 'uint8'));
        text(100, 30, 'NO PLATE DETECTED', 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        title('6. Cropped Plate', 'Color', 'w', 'FontSize', 10);
    end
    
    axList = findall(hFig, 'Type', 'axes');
    for ax = axList(:)'
        set(ax, 'Color', [0.08 0.08 0.08]);
        ax.XColor = [0.6 0.6 0.6]; ax.YColor = [0.6 0.6 0.6];
    end
    sgtitle('ALPR Stage 1: The Masterpiece (Anti-Logo & Grille Fix)', 'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold');
end