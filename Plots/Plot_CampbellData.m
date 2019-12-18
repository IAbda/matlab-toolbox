function [num,txt,CampbellPlotData] = Plot_CampbellData(xlsx_file,SheetName,TitleText)
%% [num,txt,CampbellPlotData] = Plot_CampbellData(xlsx_file,SheetName,TitleText)
% Required Input:
%  xlsx_file        - name of the Excel file with Campbell data in it. This
%                     would be generated by campbell_diagram_data() after
%                     running MBC3 on FAST linearization results.
% Optional Input:
%  SheetName        - Name of worksheet in xlsx_file that contains the mode 
%                     identification table (format described below). If 
%                     omitted, this will read the first worksheet in the 
%                     file.
%  TitleText        - Title to display on the plots. If omitted, 
%                     "Campbell Diagram" is used.
%
% Outputs:
%  num              - numeric data from the mode identification table
%                     worksheet
%  txt              - text data from the mode identification table
%                     worksheet
%  CampbellPlotData - Data structure containing the natural frequencies
%                     and damping values, as well as labels and x-axis
%                     values plotted in the Campbell diagram.
%
% ---------------- Mode Identification Table Format -----------------------
% This table must not contain any non-empty cells to the left or top.
% Note that the row numbers listed below are NOT part of the table.
% 
% Row 1: 
%            Mode Number Table Title. There must be only text in this row, 
%            and it will be ignored.
% Row 2: 
%   Column 1: 
%             Label--including units--for x-axis of Campbell diagram.
%             Typically "Rotor Speed (rpm)" or "Wind Speed (m/s)"
%   Columns 2 through N+1: 
%             numeric values for x-axis of the Campbell
%             diagram (N columns = N points on the x-axis)
% Rows 3 through 2+M (one row per mode to plot):
%   Column 1: 
%             Mode name (e.g., 1st Tower FA); if the text "(not shown)"--
%             which is case sensitive--is included in the mode name, this 
%             mode will not be included on the plot.
%   Columns 2 through N+1: 
%             integer, "K", that indicates which mode number represents  
%             this mode name in the worksheet associated with the column.
%             Examples for Column "C" in Row (Mode) "R":
%             - If Row 2, Column 1 starts with "Rotor", then
%               the frequency will be found in for mode numer "K" in the 
%               worksheet labeled with the rotor speed in (Row 2, Column C) 
%               (e.g., "14 RPM"). 
%             - If (Row 2, Column 1) starts with "Wind", then the 
%               worksheet to be searched is labeled "10 mps" if Row 2, 
%               Column C is 10.
%
%%


% if SheetName is not used, function will use the first worksheet
if nargin < 3
    TitleText = 'Campbell Diagram';
    
    if nargin < 2
        SheetName = ''; %default to the first sheet in the Excel file
    end
end
ReadFromXLS = true;

nColsPerMode = 5; %newer formats use nColsPerMode = 5; % older format use nColsPerMode = 4;
% plotRotSpeed = true;
plotRotSpeed = false;
PlotRevs = false;
FreqCutoff = 300; %Hz

if ReadFromXLS
    [num,txt] = xlsread(xlsx_file,SheetName);

    % remove table name (so indices between num and txt match better)
    txt = txt(2:end,:);
    
    sheetLabels = num(1,:)';
    if plotRotSpeed
        [op_num,op_txt] = xlsread(xlsx_file,'OP');
        CampbellPlotData.xValues = op_num(2,:)';
        xAxisLabel = 'Rotor Speed (rpm)';
    else
        xAxisLabel  = txt{1,1};
        CampbellPlotData.xValues = sheetLabels;
    end
    nx = length(CampbellPlotData.xValues);

    lineIndices = num(2:end,:);
    nLines = size(lineIndices,1);
    CampbellPlotData.lineLabels  = txt(2: nLines+1, 1);

    %% for each column (wind or rotor speed), open the worksheet and get the frequencies and damping
    CampbellData = cell( nx, 1);
    if strcmpi(txt{1,1}(1:5),'Rotor')
        ending = ' RPM';
        plotRotSpeed = true;
    elseif strcmpi(txt{1,1}(1:4),'Wind')
        ending = ' mps';
    else
        ending = '';
    end
    

    for i=1:nx
        WorksheetName = [ num2str(sheetLabels(i)) ending ];
        d = xlsread(xlsx_file, WorksheetName);

        CampbellData{i}.NaturalFreq_Hz = d(2, 1:nColsPerMode:end)';
        CampbellData{i}.DampedFreqs_Hz = d(3, 1:nColsPerMode:end)';
        CampbellData{i}.DampRatios     = d(4, 1:nColsPerMode:end)';    
    end

else
%%    %FILL THIS IN, SO WE DON'T HAVE TO READ THE SPREADSHEET!!!
% use varargin...
%     CampbellPlotData.lineLabels = modesDesc;
%     if plotRotSpeed    
%         CampbellPlotData.xValues =
%         xAxisLabel = 'Rotor Speed (rpm)';
%     else
%         CampbellPlotData.xValues =
%         xAxisLabel =  'Wind Speed (mps)';    
%     end
end

if plotRotSpeed
    PlotRevs = true;
end
   
CampbellPlotData.NotMapped_x = [];
CampbellPlotData.NotMapped_Freq = [];
CampbellPlotData.NotMapped_Damp = [];

%% Get data in format for plotting
for i= 1:nx
    NotAvail = isnan( lineIndices(:,i) ) | lineIndices(:,i)==0;
    lineIndices(NotAvail,i) = 1;
    
    CampbellPlotData.NaturalFreq_Hz(:,i) = CampbellData{i}.NaturalFreq_Hz( lineIndices(:,i) );
    CampbellPlotData.DampRatios(    :,i) = CampbellData{i}.DampRatios(     lineIndices(:,i) );
    
    CampbellPlotData.NaturalFreq_Hz(NotAvail,i) = NaN;
    CampbellPlotData.DampRatios(    NotAvail,i) = NaN;  

    
    unusedModes = setxor(1:length(CampbellData{i}.NaturalFreq_Hz), lineIndices(:,i) ); %"set exclusive or"
    unusedModes = unusedModes(unusedModes~=0);
    if ~isempty(unusedModes)
        CampbellPlotData.NotMapped_x = [CampbellPlotData.NotMapped_x 
                                        ones(length(unusedModes),1)*CampbellPlotData.xValues(i) ];
        CampbellPlotData.NotMapped_Freq = [CampbellPlotData.NotMapped_Freq 
                                        CampbellData{i}.NaturalFreq_Hz(unusedModes)];
        CampbellPlotData.NotMapped_Damp = [CampbellPlotData.NotMapped_Damp 
                                        CampbellData{i}.DampRatios(unusedModes)];
    end
end

%% Plot the data
LineStyles = {'g:', '-', '-+', '-o', '-^', '-s', '-x', '-d', '-.', ...
                    ':', ':+', ':o', ':^', ':s', ':x', ':d', ':.', ...
                   '--','--+','--o','--^','--s','--x','--d','--.'};
% LineStyles = {'g:', '.', '+', 'o', '^', 's', 'x', 'd', ...
%                     '.', '+', 'o', '^', 's', 'x', 'd', ...
%                     '.', '+', 'o', '^', 's', 'x', 'd', ...
%                     '.', '+', 'o', '^', 's', 'x', 'd', ...
%                     '.', '+', 'o', '^', 's', 'x', 'd', ...
%                     '.', '+', 'o', '^', 's', 'x', 'd'  };
figure;

for p=1:2
    ax=subplot(1,2,p);
    hold on;
    ax.Box = 'on';
    ax.FontSize = 15;
    xlabel( xAxisLabel )
    grid on;
end

for i=1:nLines
    
    if isempty( strfind( CampbellPlotData.lineLabels{i},'(not shown)' ) )    
        if (any(CampbellPlotData.NaturalFreq_Hz(i,:)<FreqCutoff))
            i_line = mod(i-1, length(LineStyles))+1;
            subplot(1,2,1)    
            plot( CampbellPlotData.xValues, CampbellPlotData.NaturalFreq_Hz(i,:), LineStyles{i_line}, 'LineWidth',2, 'DisplayName',CampbellPlotData.lineLabels{i} );

            subplot(1,2,2)    
            plot( CampbellPlotData.xValues, CampbellPlotData.DampRatios(i,:), LineStyles{i_line}, 'LineWidth',2, 'DisplayName',CampbellPlotData.lineLabels{i} );        
        end
    end
    
end



subplot(1,2,1)
plot( CampbellPlotData.NotMapped_x, CampbellPlotData.NotMapped_Freq , '.', 'DisplayName','Unmapped modes' )
ylabel( 'Natural Frequency (Hz)' )
if PlotRevs
    PerRev = [1 3:3:15];
    Revs = (CampbellPlotData.xValues) * PerRev /60;
    
    plot(CampbellPlotData.xValues,Revs,'k-');
    for i=1:length(PerRev)
        text( 'String',[num2str(PerRev(i)) 'P'],'Position',[CampbellPlotData.xValues(end) Revs(end,i) 0]);
    end
end

subplot(1,2,2)
plot( CampbellPlotData.NotMapped_x, CampbellPlotData.NotMapped_Damp , '.', 'DisplayName','Unmapped modes' )
ylabel( 'Damping Ratio (-)' )
legend show;


axes('Position',[0 0 1 1],'Xlim',[0 1],'Ylim',[0  1],'Box','off','Visible','off','Units','normalized', 'clipping' , 'off');
text(0.5, 0.96,TitleText, 'FontSize',20, 'HorizontalAlignment','Center');


%%    
return;
end
