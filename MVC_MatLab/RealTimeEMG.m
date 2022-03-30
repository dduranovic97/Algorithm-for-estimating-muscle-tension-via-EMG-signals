function shimmer = RealTimeEMG(comPort, captureDuration)
    %PLOTANDWRITEEMGEXAMPLE - Plotting ecg signal and write to file
    %    INPUT: comPort  - String value defining the COM port number for Shimmer
    %   
    %    INPUT: captureDuration  - Numerical value defining the capture duration
    %
    %    INPUT: fileName - String value defining the name of the data file
    %
    %    OUTPUT: shimmer  - Object of the ShimmerHandleClass
    %
    % Example for Shimmer3
    addpath('./Resources/')                                                    % directory containing supporting functions
    
    %% Definitions
    close all
    
    global MVC_Coeff
    global COM_Port
 
    
    %File name definition
    file_raw = 'file_raw.dat';
    file_filtered = "file_filtered.dat";
    file_rectified = "file_rectified.dat";
    file_smoothed = "file_smoothed.dat";
    file_mvc = "file_mvc.dat";
    
    % Write files loop
    files = [file_filtered file_rectified file_smoothed file_mvc];
    
    for i = 1:4
        filename = fullfile('./', files(i));
        fid = fopen(files(i), 'wt');
        if i == 4
            fprintf(fid, '%s\t%s\t\n%s\t%s\t\n', 'CH1', 'CH2', '%', '%');
        else
            fprintf(fid, '%s\t%s\t\n%s\t%s\t\n', 'CH1', 'CH2', 'mV', 'mV');
        end
        fclose(fid);
    end
    
    % Stop loop contidition configuration (figure)
    ButtonHandle = uicontrol('Style', 'PushButton', ...                      
                         'String', 'STOP STREAM', ...
                         'Callback', 'delete(gcbf)');
                     
    ButtonHandle.Position = [200 150 200 200];
    ButtonHandle.BackgroundColor = 'r';

    %% Shimer Setup
    fs = 512;                                                                 % sample rate in [Hz]                                                         %MVC coefficient
    smoothing = 1;                                                             % 0 = movavg, 1 = rms
    N = 250;                                                                   %Window size
    
    %shimer 
    shimmer = ShimmerHandleClass(comPort);
    SensorMacros = SetEnabledSensorsMacrosClass;                               % assign user friendly macros for setenabledsensors
    
    firsttime = true;

    % Note: these constants are only relevant to this examplescript and are not used
    % by the ShimmerHandle Class
    NO_SAMPLES_IN_PLOT = 5000;                                                 % Number of samples in the plot 
    DELAY_PERIOD = 0.01;                                                        % Delay (in seconds) between data read operations
    numSamples = 0;

    %% settings

    % filtering settings
    fm = 50;                                                                   % mains frequency [Hz]
    fchp = 5;                                                                  % corner frequency highpassfilter [Hz]; Shimmer recommends 5Hz to remove DC-offset and movement artifacts
    nPoles = 4;                                                                % number of poles (HPF, LPF)
    pbRipple = 0.5;                                                            % pass band ripple (%)
    
    HPF = true;                                                                % enable (true) or disable (false) highpass filter
    LPF = true;                                                                % enable (true) or disable (false) lowpass filter
    BSF = true;                                                                % enable (true) or disable (false) bandstop filter
    
    % highpass filters for ExG channels
    if (HPF)
        hpfexg1ch1 = FilterClass(FilterClass.HPF,fs,fchp,nPoles,pbRipple);
        hpfexg1ch2 = FilterClass(FilterClass.HPF,fs,fchp,nPoles,pbRipple);
    end
    if (LPF)
        % lowpass filters for ExG channels
        lpfexg1ch1 = FilterClass(FilterClass.LPF,fs,fs/2-1,nPoles,pbRipple);
        lpfexg1ch2 = FilterClass(FilterClass.LPF,fs,fs/2-1,nPoles,pbRipple);
    end
    if (BSF)
        % bandstop filters for ExG channels;
        % cornerfrequencies at +1Hz and -1Hz from mains frequency
        bsfexg1ch1 = FilterClass(FilterClass.LPF,fs,[fm-1,fm+1],nPoles,pbRipple);
        bsfexg1ch2 = FilterClass(FilterClass.LPF,fs,[fm-1,fm+1],nPoles,pbRipple);
    end

    
    %%
    if (shimmer.connect)
        shimmer.setsamplingrate(fs);                                           % Select sampling rate
        shimmer.setinternalboard('EMG');                                       % Select internal expansion board; select 'EMG' to enable SENSOR_EXG1
        shimmer.disableallsensors;                                             % Disable other sensors
        shimmer.setenabledsensors(SensorMacros.EMG,1);                         % Enable SENSOR_EXG1, disable other sensors
        
        if (shimmer.start)                                                     % TRUE if the shimmer starts streaming 

            plotData = [];                                               
            timeStamp = [];
            filteredplotData = [];

            h.figure1=figure('Name','Shimmer EMG signals');                    % Create a handle to figure for plotting data from shimmer
            set(h.figure1, 'Position', [100, 500, 800, 400]);

            elapsedTime = 0;                                                   % Reset to 0    
            tic;                                                               % Start timer

            while (elapsedTime < captureDuration)       

                pause(DELAY_PERIOD);                                           % Pause for this period of time on each iteration to allow data to arrive in the buffer

                % [newData,signalNameArray,signalFormatArray,signalUnitArray] = shimmer.getdata('Time Stamp','c','ECG','c');   % Read the latest data from shimmer data buffer, signalFormatArray defines the format of the data and signalUnitArray the unit
                % or use 
                [newData,signalNameArray,signalFormatArray,signalUnitArray] = shimmer.getdata('c');   % Read the latest data from shimmer data buffer, signalFormatArray defines the format of the data and signalUnitArray the unit

                
                if (firsttime==true && isempty(newData)~=1)
                    firsttime = writeHeadersToFile(file_raw,signalNameArray,signalFormatArray,signalUnitArray);
                end

                if ~isempty(newData)                                           % TRUE if new data has arrived
                    
                    chIndex(1) = find(ismember(signalNameArray, 'EMG CH1'));
                    chIndex(2) = find(ismember(signalNameArray, 'EMG CH2'));
                    
                    EMGData = newData(:,chIndex);
                    EMGDataFiltered = EMGData;
                    % filter the data
                    if HPF % filter newData with highpassfilter to remove DC-offset
                        EMGDataFiltered(:,1) = hpfexg1ch1.filterData(EMGDataFiltered(:,1));
                        EMGDataFiltered(:,2) = hpfexg1ch2.filterData(EMGDataFiltered(:,2));
                    end
                    
                    if BSF % filter highpassfiltered data with bandstopfilter to suppress mains interference
                        EMGDataFiltered(:,1) = bsfexg1ch1.filterData(EMGDataFiltered(:,1));
                        EMGDataFiltered(:,2) = bsfexg1ch2.filterData(EMGDataFiltered(:,2));
                    end
                    
                    if LPF % filter bandstopfiltered data with lowpassfilter to avoid aliasing
                        EMGDataFiltered(:,1) = lpfexg1ch1.filterData(EMGDataFiltered(:,1));
                        EMGDataFiltered(:,2) = lpfexg1ch2.filterData(EMGDataFiltered(:,2));
                    end
                  
                    plotData = [plotData; EMGData];                            % Update the plotData buffer with the new ECG data
                    filteredplotData = [filteredplotData; EMGDataFiltered];    % Update the filteredplotData buffer with the new filtered ECG data
                    numPlotSamples = size(plotData,1);
                    numSamples = numSamples + size(newData,1);
                    
                    timeStampNew = newData(:,1);                                   % get timestamps
                    timeStamp = [timeStamp; timeStampNew];
                    
                    if numSamples > NO_SAMPLES_IN_PLOT
                        plotData = plotData(numPlotSamples-NO_SAMPLES_IN_PLOT+1:end,:);
                        filteredplotData = filteredplotData(numPlotSamples-NO_SAMPLES_IN_PLOT+1:end,:);
                    end
                    sampleNumber = max(numSamples-NO_SAMPLES_IN_PLOT+1,1):numSamples;
                    
%% Obrada
                    filtered_ispravljeno = abs(EMGDataFiltered);
                    filtered_ispravljeno_plot = abs(filteredplotData);
                    
                    if smoothing == 0
                        filtered_smoothed = movmean(filtered_ispravljeno, N);
                        filtered_smoothed_plot = movmean(filtered_ispravljeno_plot, N);
                        koef = MVC_Coeff(1);
                    else if smoothing == 1
                         movRMS = dsp.MovingRMS(N);
                         filtered_smoothed = movRMS(filtered_ispravljeno);
                         filtered_smoothed_plot = movRMS(filtered_ispravljeno_plot);
                         koef = MVC_Coeff(2);
                        end
                    end
                    
                    MVC = (filtered_smoothed/koef*100); 
                    MVC_plot = (filtered_smoothed_plot/koef)*100;
                    
                    
%% Write data into files

                    dlmwrite(file_raw, newData, '-append', 'delimiter', '\t','precision',16); % Append the new data to the file in a tab delimited format
                    dlmwrite(file_filtered, EMGDataFiltered, '-append', 'delimiter', '\t','precision',16);
                    dlmwrite(file_smoothed, filtered_smoothed, '-append', 'delimiter', '\t','precision',16);
                    dlmwrite(file_mvc, MVC, '-append', 'delimiter', '\t','precision',16);
                    dlmwrite(file_rectified, filtered_ispravljeno, '-append', 'delimiter', '\t','precision',16);
                
%% Ploting               
                    set(0,'CurrentFigure',h.figure1);   
                    
%                     % Plot Raw Signal (CH1)
%                     subplot(5,2,1);                                        % Create subplot
%                     signalIndex = chIndex(1);
%                     plot(sampleNumber,plotData(:,1));                      % Plot the ecg for channel 1 of SENSOR_EXG1
%                     legendName1=[signalFormatArray{signalIndex} ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
%                     legend(legendName1);                                   % Add legend to plot
%                     xlim([sampleNumber(1) sampleNumber(end)]);
%                     
%                     % Plot Raw Signal (CH2)
%                     subplot(5,2,2);                                        % Create subplot
%                     signalIndex = chIndex(2);
%                     plot(sampleNumber,plotData(:,2));                      % Plot the ecg for channel 2 of SENSOR_EXG1
%                     legendName1=[signalFormatArray{signalIndex} ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
%                     legend(legendName1);                                   % Add legend to plot
%                     xlim([sampleNumber(1) sampleNumber(end)]);

                    % Plot filtered Signal (CH1)
                    subplot(3,2,1);                                        % Create subplot
                    signalIndex = chIndex(1);
                    plot(sampleNumber/fs,filteredplotData(:,1));              % Plot the filtered ecg for channel 1 of SENSOR_EXG1
                    legendName1=[signalFormatArray{signalIndex} ' ' 'filtered' ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
                    legend(legendName1);                                   % Add legend to plot
                    xlim([sampleNumber(1)/fs sampleNumber(end)/fs]);
                    
                    % Plot filtered Signal (CH2)
                    subplot(3,2,2);                                        % Create subplot
                    signalIndex = chIndex(2);
                    plot(sampleNumber/fs,filteredplotData(:,2));              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
                    legendName1=[signalFormatArray{signalIndex} ' ' 'filtered' ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
                    legend(legendName1);                                   % Add legend to plot
                    xlim([sampleNumber(1)/fs sampleNumber(end)/fs]);
                    
                    %plot rectified signal (CH1)
                    subplot(3,2,3);                                        % Create subplot
                    signalIndex = chIndex(1);
                    plot(sampleNumber/fs,filtered_ispravljeno_plot(:,1), 'y');              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
                    legendName1=[signalFormatArray{signalIndex} ' ' 'punovalno ispravljen' ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
                    legend(legendName1);                                   % Add legend to plot
                    xlim([sampleNumber(1)/fs sampleNumber(end)/fs]);
                    
                    
                    %Plot rectified signal (CH2)
                    subplot(3,2,4);                                        % Create subplot
                    signalIndex = chIndex(2);
                    plot(sampleNumber/fs,filtered_ispravljeno_plot(:,2), 'y');              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
                    legendName1=[signalFormatArray{signalIndex} ' ' 'punovalno ispravljen' ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
                    legend(legendName1);                                   % Add legend to plot
                    xlim([sampleNumber(1)/fs sampleNumber(end)/fs]);
                    
%                     %Plot smoothed signal (CH1)
%                     subplot(5,2,7);                                        % Create subplot
%                     signalIndex = chIndex(1);
%                     plot(sampleNumber, filtered_smoothed(:,1), 'r');              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
%                     legendName1=[signalFormatArray{signalIndex} ' ' 'smoothed' ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
%                     legend(legendName1);                                   % Add legend to plot
%                     xlim([sampleNumber(1) sampleNumber(end)]);
%                     
%                     %Plot smoothed signal (CH2)
%                     subplot(5,2,8);                                        % Create subplot
%                     signalIndex = chIndex(2);
%                     plot(sampleNumber, filtered_smoothed(:,2), 'r');              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
%                     legendName1=[signalFormatArray{signalIndex} ' ' 'smoothed' ' ' signalNameArray{signalIndex} ' (' signalUnitArray{signalIndex} ')'];  
%                     legend(legendName1);                                   % Add legend to plot
%                     xlim([sampleNumber(1) sampleNumber(end)]);
                      
                    %Plot normalised signal(CH1) 
                    subplot(3,2,5);                                        % Create subplot
                    signalIndex = chIndex(1);
                    plot(sampleNumber/fs, MVC_plot(:,1), 'b');              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
                    legendName1=[signalFormatArray{signalIndex} ' ' 'MVC' ' ' signalNameArray{signalIndex} ' (% *) '];  
                    legend(legendName1);                                   % Add legend to plot
                    xlim([sampleNumber(1)/fs sampleNumber(end)/fs]);
                    
                    %Plot normalised signal(CH2) 
                    subplot(3,2,6);                                        % Create subplot
                    signalIndex = chIndex(2);
                    plot(sampleNumber/fs, MVC_plot(:,2), 'b');              % Plot the filtered ecg for channel 2 of SENSOR_EXG1
                    legendName1=[signalFormatArray{signalIndex} ' ' 'MVC' ' ' signalNameArray{signalIndex} ' (% *) '];  
                    legend(legendName1);                                   % Add legend to plot
                    xlim([sampleNumber(1)/fs sampleNumber(end)/fs]);
                    
                    % Stop condition
                    if ~ishandle(ButtonHandle)                                 % Ubacen stop condition
                        fprintf('\n Data stream stopped by user! \n');
                        break;  
                    end
                    pause(0.01);
                    
                end

                elapsedTime = elapsedTime + toc;                           % Update elapsedTime with the time that elapsed since starting the timer
                tic;                                                       % Start timer           
                
            end  

            elapsedTime = elapsedTime + toc;                               % Update elapsedTime with the time that elapsed since starting the timer
            fprintf('The percentage of received packets: %d \n',shimmer.getpercentageofpacketsreceived(timeStamp)); % Detect loss packets
            shimmer.stop;                                                  % Stop data streaming                                                    

        end 

    end
    
    shimmer.disconnect;
  
    clear shimmer ;
end % RealTimeEMG