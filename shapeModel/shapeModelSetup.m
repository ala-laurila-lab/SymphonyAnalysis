% shapeModelSetup


%% Setup cell data from ephys

% generate RF map for EX and IN
% import completed maps

load(sprintf('rfmaps_%s_%s.mat', cellName, acName));
ephys_data_raw = data;

e_positions = {};
e_voltages = sort(voltages);
e_numVoltages = length(e_voltages);
e_intensities = intensities;
e_numIntensities = length(intensities);
clear voltages
clear intensities
s_voltageLegend = {};
for vi = 1:e_numVoltages
    s_voltageLegend{vi} = num2str(e_voltages(vi));
end
s_voltageLegend = {'ex','in'};
s_voltageLegend{end+1} = 'Combined';


sim_endTime = 2.0;
sim_timeStep = 0.002;
sim_spaceResolution = 3; % um per point
s_edgelength = 350;%max(cell_rfPositions);
c_extent = 0; % start and make in loop:

T = 0:sim_timeStep:sim_endTime;

% dims for: time, X, Y
sim_dims = round([length(T), s_edgelength / sim_spaceResolution, s_edgelength / sim_spaceResolution]);
e_map = nan * zeros(sim_dims(2), sim_dims(3), e_numVoltages);

ii = 1; % just use first intensity for now
for vi = 1:e_numVoltages
    e_vals(vi,:) = ephys_data_raw(vi, ii, 2);
    pos = ephys_data_raw{vi, ii, 1:2};
    e_positions{vi, ii} = pos; %#ok<*SAGROW>
end

if plotSpatialGraphs
    figure(90);clf;
    set(gcf, 'Name','Spatial Graphs','NumberTitle','off');
    axesSpatialData = tight_subplot(e_numVoltages, 2);
end

X = linspace(-0.5 * sim_dims(2) * sim_spaceResolution, 0.5 * sim_dims(2) * sim_spaceResolution, sim_dims(2));
Y = linspace(-0.5 * sim_dims(3) * sim_spaceResolution, 0.5 * sim_dims(3) * sim_spaceResolution, sim_dims(3));
[mapY, mapX] = meshgrid(Y,X);
distanceFromCenter = sqrt(mapY.^2 + mapX.^2);

                    %  ex  in
% shiftsByDimVoltage = [-30,-30;  % x
%                       -30,-30]; % y
shiftsByDim = analysisData.positionOffset;

for vi = 1:e_numVoltages
    
%     c = griddata(e_positions{vi, ii}(:,1), e_positions{vi, ii}(:,2), e_vals{vi,ii,:}, mapX, mapY);
%     e_map(:,:,vi) = c;
    
    % add null corners to ground the spatial map at edges
    positions = e_positions{vi, ii};
    vals = e_vals{vi,ii,:};
%     positions = vertcat(positions, [X(1),Y(1);X(end),Y(1);X(end),Y(end);X(1),Y(end)]);
%     vals = vertcat(vals, [0,0,0,0]');
    F = scatteredInterpolant(positions(:,1), positions(:,2), vals,...
        'linear','none');
    
    m = F(mapX + shiftsByDim(1), mapY + shiftsByDim(2)) * sign(e_voltages(vi));
    m(isnan(m)) = 0;
    m(m < 0) = 0;
    m = m ./ max(m(:));
    e_map(:,:,vi) = m;
%     e_map(:,:,vi) = e_map(:,:,vi) - min(min(e_map(:,:,vi)));

    c_extent = max(c_extent, max(distanceFromCenter(m > 0)));
    
    if plotSpatialGraphs
        axes(axesSpatialData((vi-1)*2+1))
%         imgDisplay(X,Y,e_map(:,:,vi))
        plotSpatialData(mapX,mapY,e_map(:,:,vi))
        title(s_voltageLegend{vi});
        colormap parula
        axis equal
    %     surface(mapX, mapY, zeros(size(mapX)), c)
    end
    
end


% Import temporal filter from cell & resample
filter_resampledOn = {};
for vi = 1:e_numVoltages
    filter_resampledOn{vi} = normg(resample(filterOn{vi}, round(1/sim_timeStep), 1000));
    filter_resampledOn{vi}(end) = -1*sum(filter_resampledOn{vi}(1:end-1));
end


% subunit locations, using generate positions
c_subunitSpacing = 20;
c_subunit2SigmaWidth = 40;
c_subunit2SigmaWidth_surround = 80;
c_subunitSurroundRatio = 0.0;

c_subunitSigma = c_subunit2SigmaWidth / 2;
c_subunitSigma_surround = c_subunit2SigmaWidth_surround / 2;
c_subunitCenters = generatePositions('triangular', [c_extent, c_subunitSpacing, 0]);
c_numSubunits = size(c_subunitCenters,1);

% subunit RF profile, using gaussian w/ set radius (function)
c_subunitRf = zeros(sim_dims(2), sim_dims(3), c_numSubunits);
for si = 1:c_numSubunits
    center = c_subunitCenters(si,:);
    dmap = (mapX - center(1)).^2 + (mapY - center(2)).^2; % no sqrt, so
    rf_c = exp(-(dmap / (2 * c_subunitSigma .^ 2))); % no square
    rf_s = exp(-(dmap / (2 * c_subunitSigma_surround .^ 2))); % no square

    rf = rf_c - c_subunitSurroundRatio * rf_s;
    rf = rf ./ max(rf(:));
    c_subunitRf(:,:,si) = rf;
end

% calculate connection strength for each subunit, for each voltage
s_subunitStrength = zeros(e_numVoltages, c_numSubunits);
for vi = 1:e_numVoltages
    for si = 1:c_numSubunits

        rfmap = e_map(:,:,vi);
        sumap = c_subunitRf(:,:,si);
        [~,I] = max(sumap(:));
        [x,y] = ind2sub([sim_dims(2), sim_dims(3)], I);
        s_subunitStrength(vi,si) = rfmap(x,y);
    end
end

% remove unconnected subunits
nullSubunits = sum(s_subunitStrength) < eps;
c_subunitRf(:,:,nullSubunits) = [];
s_subunitStrength(:,nullSubunits) = [];
c_subunitCenters(nullSubunits',:) = [];
c_numSubunits = size(s_subunitStrength,2);

% plot the spatial graphs
if plotSpatialGraphs
    for vi = 1:e_numVoltages
        axes(axesSpatialData((vi - 1) * 2 + 2))
    %     imagesc(sum(c_subunitRf, 3))
        d = zeros(sim_dims(2), sim_dims(3));
        for si = 1:c_numSubunits
            d = d + c_subunitRf(:,:,si) * s_subunitStrength(vi,si);
        end
        plotSpatialData(mapX,mapY,d)
        axis equal
        title('all subunits scaled by maps')
        hold on
        % plot points at the centers of subunits
        plot(c_subunitCenters(:,1), c_subunitCenters(:,2),'r.')
        
    end
end