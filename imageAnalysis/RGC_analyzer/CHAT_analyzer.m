function [X_flat, Y_flat, Z_flat_ON, Z_flat_OFF] = CHAT_analyzer(image_fname, Nchannels, CHAT_channel, resampleSquares, pixelRes_XY)
imageData = bfopen(image_fname);
rawImageSequence = imageData{1,1};
CHATsequence_raw = rawImageSequence(CHAT_channel:Nchannels:end,1);

% pixelRes_Z = 0.2;
% resampleSquares = 8;

Nframes = length(CHATsequence_raw);
[pixX, pixY] = size(CHATsequence_raw{1});
resampleFactor = pixX / resampleSquares;
voxelsX = round(pixX/resampleFactor);
voxelsY = round(pixY/resampleFactor);
CHATsequence = zeros(voxelsX, voxelsY, Nframes);

CHATsequence_raw_mat = zeros(pixX, pixY, Nframes);
for i=1:Nframes
    CHATsequence(:,:,i) = imresize(CHATsequence_raw{i}, 1/resampleFactor);
    CHATsequence_raw_mat(:,:,i) = CHATsequence_raw{i};
end


% full projection figure
CHAT_proj_full = squeeze(max(CHATsequence_raw_mat, [], 3));
figure(11);
imagesc(CHAT_proj_full);
projImageAx = gca;
r = [];


% clear('CHATsequence_raw_mat', 'CHATsequence_raw');


% for i=1:voxelsX
%     for j=1:voxelsY
%
%         curProj = squeeze(CHATsequence(i,j,:));
%         curProj = smooth(curProj, 9);
%
%         [peakHeight, peakLoc] = findpeaks(curProj);
%         peakLoc
%         diff(peakLoc) .* pixelRes_Z
%
%         pause(0.1)
%     end
% end


orange = [1 .4 0];



% output chat position
CHAT_pos = ones(voxelsX, voxelsY, 2)*nan;

figure(12);
clf;
projAx = gca;
pixStepX = pixX / voxelsX;
pixStepY = pixY / voxelsY;

% while 1
%     i = randi(voxelsX);
%     j = randi(voxelsY);



while any(isnan(CHAT_pos(:)))
    i = randi(voxelsX);
    j = randi(voxelsY);
    while ~isnan(CHAT_pos(i,j,1))
        i = randi(voxelsX);
        j = randi(voxelsY);
    end
    
    % display current square on projection image
    r = rectangle('Parent', projImageAx, 'Position', [(i-1)*pixStepX, (j-1)*pixStepY, pixStepX, pixStepY], 'EdgeColor', 'r');
    
    
    hold(projAx, 'off');
    
    % add image statistics curves per frame
    i_ = (i-1) * resampleFactor;
    j_ = (j-1) * resampleFactor;
    
    stats = {'variance','maximum','mean','median','far cov','near cov'};
    proj_by_stat_frame = zeros(length(stats), Nframes);
    
    stack = mean(CHATsequence_raw_mat(i_+(1:resampleFactor),j_+(1:resampleFactor),:));
    stackMean = mean(stack(:));
    filledFraction = [];
    for z = 1:Nframes
        sliceArea = squeeze(CHATsequence_raw_mat(i_+(1:resampleFactor),j_+(1:resampleFactor),z));
        sliceArea = sliceArea(:) ./ stackMean;
        filledFraction(z) = sum(sliceArea(:) > 0.1 * max(sliceArea(:))) / length(sliceArea(:));
        proj_by_stat_frame(1,z) = var(sliceArea(:))./length(sliceArea(:));
        proj_by_stat_frame(2,z) = max(sliceArea(:));
        proj_by_stat_frame(3,z) = mean(sliceArea(:));
        proj_by_stat_frame(4,z) = median(sliceArea(:));
        
        nearCovDist = 10;
        if z > nearCovDist && z < (Nframes - nearCovDist)
            lowerSlice = squeeze(CHATsequence_raw_mat(i_+(1:resampleFactor),j_+(1:resampleFactor), z-nearCovDist));
            upperSlice = squeeze(CHATsequence_raw_mat(i_+(1:resampleFactor),j_+(1:resampleFactor), z+nearCovDist));
            coLower = cov(sliceArea(:), lowerSlice(:));
            coUpper = cov(sliceArea(:), upperSlice(:));
            proj_by_stat_frame(5,z) = coLower(1,2) + coUpper(1,2);
        end
        
        nearCovDist = 3;
        if z > nearCovDist && z < (Nframes - nearCovDist)
            lowerSlice = squeeze(CHATsequence_raw_mat(i_+(1:resampleFactor),j_+(1:resampleFactor), z-nearCovDist));
            upperSlice = squeeze(CHATsequence_raw_mat(i_+(1:resampleFactor),j_+(1:resampleFactor), z+nearCovDist));
            coLower = cov(sliceArea(:), lowerSlice(:));
            coUpper = cov(sliceArea(:), upperSlice(:));
            proj_by_stat_frame(6,z) = coLower(1,2) + coUpper(1,2);
        end
    end
    
    % smooth and normalize the stats
    smooth_order = 13;
    for s = 1:length(stats)
        proj_by_stat_frame(s,:) = smooth(proj_by_stat_frame(s,:), smooth_order);
        proj_by_stat_frame(s,:) = proj_by_stat_frame(s,:) - min(abs(proj_by_stat_frame(s,:)));
        proj_by_stat_frame(s,:) = proj_by_stat_frame(s,:) ./ max(abs(proj_by_stat_frame(s,:)));
    end
    
    
    % plot image statistics
    hold(projAx, 'off');
    for s=1:length(stats)
        plot(projAx, proj_by_stat_frame(s,:), 'LineWidth', 1);
        hold(projAx, 'on');
    end
    %     plot(projAx, filledFraction, 'LineWidth',3);
    ylabel(projAx,'ChAT flourescence');
    xlabel(projAx,'z-position (frame)')
    
    
    % find interesting features of the stats
    interest_by_stat_frame = zeros(size(proj_by_stat_frame));
    for s = 1:length(stats)
        interest_by_stat_frame(s,:) = find_projection_interest(proj_by_stat_frame(s,:));
    end
    %     hold(interestAx, 'off');
    %     for s=1:length(stats)
    %         plot(interestAx, interest_by_stat_frame(s,:), 'LineWidth', 0.5);
    %         hold(interestAx, 'on');
    %     end
    overallInterest = nanmean(interest_by_stat_frame, 1) .* filledFraction .* (filledFraction > 0.3);
    overallInterest = overallInterest ./ max(overallInterest);
    plot(projAx, overallInterest, 'LineWidth', 5);
    
    % look for peaks 4.8 um apart
    %     thickDetector = zeros(size(overallInterest));
    %     thickDetector(1:12) = gausswin(12);
    %     thickDetector(round(4.8 / pixelRes_Z)+6 + (-5:6)) = gausswin(12);
    %     detection = fliplr(conv(thickDetector, overallInterest, 'same'));
    %     plot(interestAx, detection./max(detection), 'LineWidth', 3);
    
    
    % display detected peaks
    % find peaks in profile
    [peakHeight, peakLoc] = findpeaks(overallInterest);
    peakLoc(peakHeight < 0.1) = [];
    peakHeight(peakHeight < 0.1) = [];
    
    % find local minima of derivative 2
    %     [peakHeight1, peakLoc1] = findpeaks(-1*curProj_d2);
    %     peakHeight1 = -1 * peakHeight1;
    %     for p=1:length(peakHeight1)
    %         if peakHeight1(p) < 0
    %             peakHeight = [peakHeight; curProj(peakLoc1(p))];
    %             peakLoc = [peakLoc; peakLoc1(p)+1];
    %         end
    %     end
    
    line([0,Nframes],[0,0], 'Parent',projAx)
    
    
    legend(projAx,stats,'Location','best');
    
    
    numPeaks = length(peakLoc);
    distances = zeros(numPeaks);
    if numPeaks > 0
        
        % distances between peaks
        %         for p = 1:numPeaks
        %             for q = 1:numPeaks
        %                 distances(p,q) = peakLoc(p) - peakLoc(q);
        %                 if abs((distances(p,q) * pixelRes_Z) - 4.1) < 1.3
        %                     line([peakLoc(p), peakLoc(q)], [.5,.5]*mean(peakHeight([p,q])), 'Color','g','LineWidth', 3, 'Parent', projAx)
        %                 end
        %             end
        %         end
        %         distances = distances * pixelRes_Z;
        
        for p = 1:numPeaks
            line([peakLoc(p), peakLoc(p)], [0, 1], 'Parent', projAx, 'Color', 'green')
        end
    end
    
    
    % show chosen peaks from neighbors
    lowers = [];
    uppers = [];
    for ii = [-1,0,1]
        for jj = [-1,0,1]
            if i + ii < 1 || i + ii > voxelsX || j + jj < 1 || j + jj > voxelsY
                continue
            end
            if ~isnan(CHAT_pos(i + ii, j + jj, 1))
                poss = CHAT_pos(i + ii, j + jj, 1);
                line([poss, poss], [0, 1], 'Parent', projAx, 'Color',orange,'LineWidth', 2)
                lowers(end+1) = poss;
                poss = CHAT_pos(i + ii, j + jj, 2);
                line([poss, poss], [0, 1], 'Parent', projAx, 'Color','r','LineWidth', 2)
                uppers(end+1) = poss;
            end
        end
    end
    
    % peak lines from algorithm
    numPeaks = length(peakLoc);
    if numPeaks > 0
        
        % distances between peaks
        %         for p = 1:numPeaks
        %             for q = 1:numPeaks
        %                 distances(p,q) = peakLoc(p) - peakLoc(q);
        %                 if abs((distances(p,q) * pixelRes_Z) - 4.1) < 1.3
        %                     line([peakLoc(p), peakLoc(q)], [.5,.5]*mean(peakHeight([p,q])), 'Color','g','LineWidth', 3, 'Parent', projAx)
        %                 end
        %             end
        %         end
        %         distances = distances * pixelRes_Z;
        
        for p = 1:numPeaks
            line([peakLoc(p), peakLoc(p)], [0, 1], 'Parent', projAx, 'Color', 'green')
        end
    end    
    
    figure(14);clf;
    activeFrames = 1:Nframes;%find(overallInterest > 0);
    num_activeFrames = length(activeFrames);
    dim1 = round(ceil(sqrt(num_activeFrames)));
    dim2 = round(ceil(num_activeFrames / dim1));
    ha = tight_subplot(dim1, dim2, .01);
    
    % show all layers in a big figure
    for zi = 1:num_activeFrames
        z = activeFrames(zi);
        % projection in subplot
        i_ = (i-1) * resampleFactor;
        j_ = (j-1) * resampleFactor;
        
        sliceArea = squeeze(CHATsequence_raw_mat(i_+(1:resampleFactor), j_+(1:resampleFactor), z));
        
        ax = ha(zi);
%         ax = subplot(dim1, dim2, z);
        %         axes(ax);
        imagesc(sliceArea, 'Parent', ax);
%         colormap(ax, 'gray')
        title(ax, z)
        set(ax, 'XTickLabel', '');
        set(ax, 'YTickLabel', '');
        set(ax, 'XTick',[]);
        set(ax, 'YTick',[]);
        if any(lowers == z)
            box(ax, 'on');
            set(ax, 'XColor',orange);
            set(ax, 'YColor',orange);
            set(ax, 'LineWidth',3);
        elseif any(uppers == z)
            box(ax, 'on');
            set(ax, 'XColor','red');
            set(ax, 'YColor','red');
            set(ax, 'LineWidth',3);
        elseif any(peakLoc == z)
            box(ax, 'on');
            set(ax, 'XColor','green');
            set(ax, 'YColor','green');
            set(ax, 'LineWidth',3);
        else
            box(ax, 'off');
        end
    end
    
    %     if numPeaks == 2 && abs(abs(diff(peakLoc) * pixelRes_Z) - 4.1) < 1.3
    %         CHAT_pos(i,j,:) = peakLoc;
    %         figure(94)
    %         surf(squeeze(CHAT_pos(:,:,1)))
    % %         else
    % %             pause
    %     end
    

    levels = [nan;nan];
    for pp = 1:2
        while true
            w = waitforbuttonpress;
            if w == 0
                t = get(gca, 'title');
                v = str2double(t.String);
                levels(pp,1) = v;
%                 box(ax(v), 'on');
%                 set(ax(v), 'XColor','black');
%                 set(ax(v), 'YColor','black');
%                 set(ax(v), 'LineWidth',3);
                break;
            elseif w == 1 % keyboard
                key = get(gca, 'CurrentCharacter');
                disp(key);
                levels(pp,1) = -1;
                break;
            end
        end
    end
    levels = sort(levels);
    disp(levels');
    CHAT_pos(i,j,:) = levels;
    
    
    
%     figure(12);
%     repeatPeakPick = true;
%     while repeatPeakPick
%         
%         
%         
%         % input 1
%         [px, ~] = ginput(1);
%         %             hold(peaksAx, 'on');
%         pos1 = round(px);
%         %             px = round(px);
%         %             if px>0
%         %                 scatter(projAx, px, curProj(px), 'rx');
%         %             end
%         
%         % input 2
%         [px, ~] = ginput(1);
%         pos2 = round(px);
%         %             px = round(px);
%         %             if px>0
%         %                 scatter(projAx, px, curProj(px), 'rx');
%         %             end
%         
%         
%         key = input('ok?: [ok=return, skip=s, redo now=r, redo later=d]', 's');
%         switch key
%             case 'r'
%                 repeatPeakPick = true;
%             case 's'
%                 repeatPeakPick = false;
%                 set(r, 'EdgeColor', 'g');
%                 CHAT_pos(i,j,[1,2]) = [-1, -1];
%             case 'd'
%                 repeatPeakPick = false;
%                 set(r, 'EdgeColor', 'b');
%             otherwise % save result
%                 chatFrames = sort([pos1, pos2]);
%                 CHAT_pos(i,j,1) = chatFrames(1);
%                 CHAT_pos(i,j,2) = chatFrames(2);
%                 repeatPeakPick = false;
%                 text((i-1)*pixStepX+1, (j-1)*pixStepY+pixStepY/2, [num2str(round(chatFrames(1))), ', ' num2str(round(chatFrames(2)))], 'Parent', projImageAx)
%                 set(r, 'EdgeColor', 'k');
%         end
%     end
%     disp(squeeze(CHAT_pos(i,j,:)))
    %         curProj = curProj' - min(curProj);
    %         [x_fit, proj_fit] = CHAT_fitter(curProj, 2); %fit 2 peaks
    %         keyboard;
end

% convert the -1 for skipped to NaN for later processing
CHAT_pos(CHAT_pos(:) == -1) = NaN;


%clean up outliers
im_std_1 = stdfilt(squeeze(CHAT_pos(:,:,1)));
im_std_2 = stdfilt(squeeze(CHAT_pos(:,:,2)));
im_med_1 = inpaint_nans(medfilt2(squeeze(CHAT_pos(:,:,1)), 'symmetric'));
im_med_2 = inpaint_nans(medfilt2(squeeze(CHAT_pos(:,:,2)), 'symmetric'));

for i=1:voxelsX
    for j=1:voxelsY
        if isnan(CHAT_pos(i,j,1)) || abs(CHAT_pos(i,j,1) - im_med_1(i,j)) > 2*im_std_1(i,j)
            % disp('replacing value')
            % i
            % j
            CHAT_pos(i,j,1) = im_med_1(i,j);
        end
        if isnan(CHAT_pos(i,j,2)) || abs(CHAT_pos(i,j,2) - im_med_2(i,j)) > 2*im_std_2(i,j)
            % disp('replacing value')
            % i
            % j
            CHAT_pos(i,j,2) = im_med_2(i,j);
        end
    end
end

%format into x,y,z, values
[Xvals, Yvals] = meshgrid(resampleFactor * [1:voxelsX] * pixelRes_XY, resampleFactor * [1:voxelsY] * pixelRes_XY);
X_flat = reshape(Xvals, [1, (pixX./resampleFactor)^2]);
Y_flat = reshape(Yvals, [1, (pixX./resampleFactor)^2]);
Z_flat_ON = reshape(squeeze(CHAT_pos(:,:,1)), [1, (pixX./resampleFactor)^2]);
Z_flat_OFF = reshape(squeeze(CHAT_pos(:,:,2)), [1, (pixX./resampleFactor)^2]);



