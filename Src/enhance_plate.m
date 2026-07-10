% =========================================================================
% ECE 228 - ALPR | Stage 1.5: The Blue Ruler Edge-Lock
% =========================================================================
function finalPlate = enhance_plate(croppedPlate)
    finalPlate = croppedPlate; % Safe fallback
    
    try
        [origH, origW, ~] = size(croppedPlate);

        % ==========================================
        % 1. FIND THE TILT ANGLE
        % ==========================================
        hsv = rgb2hsv(croppedPlate);
        blueMask = (hsv(:,:,1) > 0.50) & (hsv(:,:,1) < 0.75) & (hsv(:,:,2) > 0.15) & (hsv(:,:,3) > 0.15);
        blueMask = imclose(blueMask, strel('rectangle', [5, 20]));
        blueMask = bwareaopen(blueMask, 100);

        stats = regionprops(blueMask, 'Orientation', 'Area');
        if isempty(stats), return; end
        [~, maxIdx] = max([stats.Area]);
        tiltAngle = stats(maxIdx).Orientation;

        % ==========================================
        % 2. ROTATE ON A MASSIVE BLACK CANVAS
        % ==========================================
        % Pad heavily so we don't clip the corners of the plate during rotation
        padSize = round(origW * 0.30);
        imgPadded = padarray(croppedPlate, [padSize, padSize], 0, 'both');
        rotImg = imrotate(imgPadded, -tiltAngle, 'bilinear', 'loose');
        
        % ==========================================
        % 3. LOCATE THE "BLUE RULER" IN THE FLAT IMAGE
        % ==========================================
        rotHSV = rgb2hsv(rotImg);
        rotBlue = (rotHSV(:,:,1) > 0.50) & (rotHSV(:,:,1) < 0.75) & (rotHSV(:,:,2) > 0.15) & (rotHSV(:,:,3) > 0.15);
        rotBlue = imclose(rotBlue, strel('rectangle', [5, 20]));
        rotBlue = imfill(rotBlue, 'holes');
        rotBlue = bwareaopen(rotBlue, 200);

        statsRot = regionprops(rotBlue, 'BoundingBox', 'Area');
        if isempty(statsRot), return; end
        [~, maxIdx] = max([statsRot.Area]);
        bb = statsRot(maxIdx).BoundingBox; 
        
        bx = round(bb(1)); by = round(bb(2)); bw = round(bb(3)); bh = round(bb(4));

        % ==========================================
        % 4. STRICT LOCK ON LEFT, RIGHT, AND TOP
        % ==========================================
        % The Egyptian Blue Band spans the absolute exact width of the plate.
        % It also touches the exact top edge. We use it as a physical ruler!
        % (We shave 2 pixels inward just to guarantee we drop the plastic side frames)
        x1 = bx + 2;
        x2 = bx + bw - 2;
        y1 = by;

        % ==========================================
        % 5. DYNAMIC CORRIDOR SCAN FOR THE BOTTOM
        % ==========================================
        % We look STRICTLY in the vertical corridor directly below the blue band.
        % This makes it physically impossible to scan the black rotation triangles!
        rotGray = rgb2gray(rotImg);
        ySearchEnd = min(size(rotGray, 1), y1 + round(bh * 4.5));
        searchRegion = rotGray(y1:ySearchEnd, x1:x2);

        % Find the text inside this isolated corridor
        tex = stdfilt(searchRegion, ones(3,3));
        texMask = tex > (max(tex(:)) * 0.20);
        texMask = imclose(texMask, strel('rectangle', [3, round(bw*0.1)]));

        rowTex = sum(texMask, 2);
        textRows = find(rowTex > (bw * 0.05)); % Row must have at least 5% text texture

        if ~isempty(textRows)
            textBottomLocal = textRows(end);
            % Shave the plate just below the text (adds a small 20% white lip)
            y2 = y1 + textBottomLocal + round(bh * 0.20);
        else
            % Mathematical fallback if text is completely invisible in the shadow
            y2 = y1 + round(bh * 3.3);
        end

        % Ensure final bounds are safe to prevent matrix out-of-bounds errors
        x1 = max(1, x1); x2 = min(size(rotImg, 2), x2);
        y1 = max(1, y1); y2 = min(size(rotImg, 1), y2);

        % ==========================================
        % 6. THE PERFECT SHAVE & STANDARDIZE
        % ==========================================
        perfectCrop = rotImg(y1:y2, x1:x2, :);
        finalPlate = imresize(perfectCrop, [200, 440]);

    catch
        % Silently fail to safe fallback
    end
end