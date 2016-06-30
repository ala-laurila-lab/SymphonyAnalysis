nonLinearFit = {};

if plotOutputCurrents
    figure(102);clf;
    set(gcf, 'Name','Output Currents','NumberTitle','off');
    dim1 = ceil(sqrt(stim_numOptions));
    dim2 = ceil(stim_numOptions / dim1);
    outputAxes = tight_subplot(dim1, dim2, .02, .02);
end

out_valsByOptions = [];

plot_timeLims = [0, 2];
timeOffsetSim = 0.14;
timeOffsetSpikes = -.35;
ephysScale = .002;
simScale = [1, .4];
combineScale = [2.5, 1, -.1]; % ex, in, spikes (don't get combined)
% displayScale = [5,2.2];
plotYLimsScale = 1;

nonLinearCell = {[],[]};
nonLinearSim = {[],[]};

fitnessScoreByOptionCurrent = [];

for optionIndex = 1:stim_numOptions
    outputSignals = [];
    outputLabels = {};
    
    ang = stim_barDirections(optionIndex);
    % Output scale
    sim_responseSubunitsCombinedScaled = sim_responseSubunitsCombinedByOption{optionIndex};
    for vi = 1:e_numVoltages
        sim_responseSubunitsCombinedScaled(vi,:) = simScale(vi) * combineScale(vi) * sim_responseSubunitsCombinedScaled(vi,:);
    end
    
    % Combine Ex and In
    sim_responseCurrent = sum(sim_responseSubunitsCombinedScaled, 1);
    out_valsByOptions(optionIndex, 1) = -1*sum(sim_responseCurrent(sim_responseCurrent < 0)) / sim_dims(1);


    if plotOutputCurrents
        axes(outputAxes(plotGrid(optionIndex, 1, 1)));
        
        Tsim = T+timeOffsetSim;
        sel = Tsim > plot_timeLims(1) & Tsim < plot_timeLims(2);
        Tsim = Tsim(sel);
%         plot(Tsim(sel), sim_responseSubunitsCombinedScaled(:,sel))
        outputSignals(end+[1:2],:) = sim_responseSubunitsCombinedScaled(:,sel);
        outputLabels{end+1} = 'ex_s';
        outputLabels{end+1} = 'in_s';
        
%         if ~isempty(nonLinearFit)
%             for vi = 1:e_numVoltages
%                 plot(Tsim(sel), polyval(nonLinearFit{vi}, sim_responseSubunitsCombinedScaled(:,sel)))        
%             end
%         end
        
        % combined sim
        outputSignals(end+1,:) = sim_responseCurrent(sel);
        outputLabels{end+1} = 'comb_s';
        
        % ephys responses (ex, in, spikes)
        if plotCellResponses
            Esel = T > plot_timeLims(1) & T < plot_timeLims(2);
            simShift = timeOffsetSim / sim_timeStep;
            cell_responses = [];
            for vi = 1:2%3 %enables spikes
                mn = ephysScale * c_responses{vi, c_angles == ang}.mean;
                
                mn = combineScale(vi) * resample(mn, round(1/sim_timeStep), 10000);
                cell_responses(vi,:) = mn;
                rcell = cell_responses(vi,Esel);
                outputSignals(end+1,:) = rcell(simShift:end);
                l = {'ex_e','in_e','spike_e'};
                outputLabels{end+1} = l{vi};

%                 if vi < 3
%                     plot(T(Esel), mn(Esel))
%                 else
%                     plot(T(Esel) + timeOffsetSpikes, mn(Esel));
%                 end
                
                
            end
            % ephys combined values
            cell_responsesCombined = sum(cell_responses(1:2,:));
            rcell = cell_responsesCombined(Esel);
            outputSignals(end+1,:) = rcell(simShift:end);
            outputLabels{end+1} = 'comb_e';
            
            % extract values for comparison plot
            out_valsByOptions(optionIndex, 2) = -1*sum(cell_responsesCombined(cell_responsesCombined < 0)) / sim_dims(1);        
%             out_valsByOptions(optionIndex, 3) = -1*sum(cell_responses(3,:)) / sim_dims(1);            
        end
        
        % then plot all the signals together
        plotSelect = logical([1,1,0,1,1,0]);
        plot(Tsim, outputSignals(plotSelect,:)');
        legend(outputLabels(plotSelect),'Location','Best');
        xlim(plot_timeLims);
        
        
        fitAnalysisWindow = Tsim > 0.6 & Tsim < 1.4;
        for oi = 1:3
            fitnessScoreByOptionCurrent(optionIndex,oi) = rsquare(outputSignals(3+oi,fitAnalysisWindow),outputSignals(oi,fitAnalysisWindow));
        end
        
        title(sprintf('angle %d, fit: %d, %d, %d', ang, round(100*fitnessScoreByOptionCurrent(optionIndex,1)),...
                        round(100*fitnessScoreByOptionCurrent(optionIndex,2)),...
                        round(100*fitnessScoreByOptionCurrent(optionIndex,3))))


        % investigate nonlinearities relative to the ephys data
        for vi = 1:2
            simShift = timeOffsetSim / sim_timeStep;

            rsim = sim_responseSubunitsCombinedScaled(vi,sel);
            rcell = cell_responses(vi,Esel);
            rcell = rcell(simShift:end);
            nonLinearCell{vi} = horzcat(nonLinearCell{vi}, rcell);
            nonLinearSim{vi} = horzcat(nonLinearSim{vi}, rsim);
            
%             axes(outputAxes(plotGrid(optionIndex, vi + 1, 3)));            
%             plot(rsim,rcell,'.')
%             hold on
%             plot(rcell)
%             hold off
        end
    end
    
end

if plotOutputNonlinearity

    figure(114)
    set(gcf, 'Name','Nonlinearity view','NumberTitle','off');
    for vi = 1:2
        subplot(2,1,vi)
        plot(nonLinearSim{vi}, nonLinearCell{vi},'.')
        % ignore values near 0 for fitting
        sigValues = abs(nonLinearSim{vi}) > 0.03 & abs(nonLinearCell{vi}) > 0.03;
        nonLinearFit{vi} = polyfit(nonLinearSim{vi}(sigValues), nonLinearCell{vi}(sigValues), 2);
        hold on
        plot(nonLinearSim{vi}, polyval(nonLinearFit{vi}, nonLinearSim{vi}))
        hold off
        title(e_voltages(vi))
        grid on
        xlabel('Simulation')
        ylabel('Cell ephys')
    end
end

% linkaxes(outputAxes)
% ylim([-1,.6]*.001)

% display combined output over stim options
if plotResultsByOptions
    figure(110);clf;
    set(gcf, 'Name','Processed outputs over options','NumberTitle','off');

    % compare combined current to spikes to get an RGC output nonlinearity
    out_valsByOptions = out_valsByOptions ./ max(out_valsByOptions(:));
    nonlinOutput = polyfit(out_valsByOptions(:,1), out_valsByOptions(:,3),1);
    out_valsByOptions(:,4) = polyval(nonlinOutput, out_valsByOptions(:,1));

    ordering = [3,1,4];
    % ordering = 1;
    for ti = ordering
        a = deg2rad(stim_barDirections)';

    %     a = stim_barDirections';
        p = out_valsByOptions(:,ti) / max(out_valsByOptions(:));
        p = p ./ mean(p);

        a(end+1) = a(1);
        p(end+1) = p(1);
        polar(a, p)
        hold on
    end
    hold off
    legs = {'sim currents','ephys currents','ephys spikes','sim curr nonlin'};
    legend(legs(ordering))
    % plot(stim_spotDiams, out_valsByOptions)
end

% output spiking nonlinearity maybe
%
% figure(160)
% 
% plot(out_valsByOptions(:,1), out_valsByOptions(:,2),'o');
% % title('current dif to 
% 
% sse = sum((out_valsByOptions(:,4) - out_valsByOptions(:,3)).^2);
% %  of nonlin scaled current diff, to spike rate 
% fprintf('SSE %f\n', sse);
