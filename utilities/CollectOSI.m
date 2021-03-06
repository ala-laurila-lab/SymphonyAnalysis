function [OSICells, OSI, OSAng] = CollectOSI(analysisClass)
global ANALYSIS_FOLDER

if nargin == 0
    [fname, pathname] = uigetfile([ANALYSIS_FOLDER filesep 'analysisTrees' filesep '*.mat'], 'Load analysisTree');
end

load(fullfile(pathname, fname)); %loads analysisTree
global analysisTree
T = analysisTree;
%analysisClass = 'DriftingGratingsAnalysis';
analysisClass = 'BarsMultiAngleAnalysis';

nodes = getTreeLevel_new(T, 'class', analysisClass);
L = length(nodes);

Count = 1;
OSICells = {'cell array of character vectors'};

for i=1:L
    curNode = nodes(i);
    cellName = {T.getCellName(curNode)};
    
    if any(contains(OSICells, cellName));
        continue
    else
    	curNode = T.subtree(curNode);
    	OSICells(Count) = cellName;
    	
    	Switch analysisClass
    		case analysisClass == 'DriftingGratingsAnalysis'
    			curNodeData = curNode.get(4);
    			OSI(Count) = curNodeData.F1amplitude_OSI;
        		OSAng(Count) = curNodeData.F1amplitude_OSang;
    		case analysisClass == 'BarsMultiAngleAnalysis'
        		curNodeData = curNode.get(1);
				OSI(Count) = curdNodeData.spikeCount_stimInterval_baselineSubtracted_OSI
        		OSAng(Count) = curNodeData.spikeCount_stimInterval_baselineSubtracted_OSang
       		otherwise
        		display('We don't recognize this analysisClass')
       		end	
        
        Count = Count + 1;
    end
end
