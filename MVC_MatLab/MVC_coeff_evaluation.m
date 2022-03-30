%% Skripta za odredjivanje MSC koeficjenta (MatLab R2018a)
%
% INPUT: Subject, Shimer COM port, duration time
%  
% OUTPUT: MSC koeff izmjerenog signala (movavg i rms) kao globalna varijabla
%
%% Definicija globalnih varijabli
global subject
global c
global MVC_Coeff
global COM_Port


%% Stream setup
subject = 'Daniel';
c = date;
COM_Port  = '7';    
duration_time = 30; % [s]

%sampling frequency
fs = 512; % [Hz]
N = 250; % Window size [broj uzoraka] - (u sekundama = N/fs)

%% Create file and run MVCMeasure script

file_filtered = 'MVC_Coeff.dat';
MVCMeasure(COM_Port, duration_time);
%% Load data from writen file

EMG_raw = dlmread(file_filtered, '\t', 4,1);
%% Shimmer3 Setup



%% Obrada podataka

%kreiranje vektora x osi za plot
max_t = size(EMG_raw)-1;
t = 0:max_t;
t = t(:);
t = t/fs; %pretvorba iz broja uzorka u vrijeme

%Punovalno ispravljanje - vec filt. sign. iz shimera
EMG_punovalno_ispravljen = EMG_raw.^2;

%MOVAVG 
EMG_movavg = movmean(EMG_punovalno_ispravljen, N);

%RMS
movRMS = dsp.MovingRMS(N);
EMG_rms = movRMS(EMG_punovalno_ispravljen);

%Normalizacija
MVC_Coeff = [0;0]; 

%MVC Normalizacija (movavg)
sig1 = EMG_movavg;

[MVC_Coeff(1), X_max2] = max(sig1);
EMG_MVC_movavg = [];
for i = 1:length(sig1)
   mvc1 = sig1(i)/MVC_Coeff(1)*100;
   EMG_MVC_movavg = [EMG_MVC_movavg;mvc1];
end

%MVC Normalizacija (rms)
sig2 = EMG_rms;

[MVC_Coeff(2), X_max2] = max(sig2);
EMG_MVC_rms = [];
for i = 1:length(sig2)
   mvc2 = sig2(i)/MVC_Coeff(2)*100;
   EMG_MVC_rms = [EMG_MVC_rms;mvc2];
end

fprintf('MVC coeff (movAvg) = %f', MVC_Coeff(1))
fprintf('\nMVC coeff (rms) = %f', MVC_Coeff(2))
 
%% Plotanje
%Usporedba smoothing algoritama
figure()
plot(t,EMG_punovalno_ispravljen, 'y')
hold on 
plot(t, EMG_movavg, 'b')
hold on
plot(t, EMG_rms, 'r')
legend Rectified MovAvg RMS
title('Usporedba smoothing algoritama')
xlabel('t (s)')
ylabel('Amplitude (mV)')
grid on

%Usporedba normalizacija
figure()
plot(t, EMG_MVC_movavg, 'b')
hold on
plot(t, EMG_MVC_rms, 'r')
legend movAvg rms
title('Usporedba Normalizacija')
xlabel('t (s)')
ylabel('MVC (%)')
grid on

%% Spektar signala
sig_fft = EMG_raw;
L=length(sig_fft);
time=L/fs;
Y = fft(sig_fft);

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);

f = fs*(0:(L/2))/L;
figure()
plot(f,P1) 
title('Spektar snage signala')
xlabel('f (Hz)')
ylabel('Signal Power (uV)^2')
grid on


