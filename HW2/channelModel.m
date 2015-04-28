%% Clear, initialize useful quantities
clear
close all
clc
rng default

%% Data

data_init;

% Plot residual energy of IIR filter (determine transient)
[h_dopp, ~] = impz(b_dopp, a_dopp);
residual_nrg = sum(h_dopp.^2) - cumsum(h_dopp.^2);
plot(0:length(residual_nrg)-1, 10*log10(residual_nrg)), 
xlim([0 100]), grid on, box on, title('Residual energy of I.R. of the IIR filter')
xlabel('Transient length (samples)'), ylabel('Residual energy (dB)')
% Doppler filter shape
[Hf, f] = freqz(b_dopp, a_dopp, 1000, 'whole');
figure, plot(f/(2*pi), 20*log10(abs(Hf)))
ylim([0, 12])
title('Frequency response of the Doppler filter')

%% Criterion for Nh
%TODO: Michele comment better!
% Normalize the complete exp but consider just the queue

h = 1/tau_rms*exp(-(0:899)*Tc/tau_rms);
h = h.*(1-C^2)/sum(h);

for N_h = 1:20; % To be determined
    deltah = h(N_h+1:end);
    lambda_n(N_h) = 1/(snr_lin * sum(abs(deltah)));
end

figure
plot(1:length(lambda_n), 10*log10(lambda_n), 'd-')
grid on, title('\Lambda_n')
xlabel('N_h'), ylabel('\Lambda_n [dB]')
axis([1 4 -2 10]), ax = gca; ax.XTick = 1:5;

%% Display the PDP for the channel

% The PDP is the sampling of a continuous time exponential PDP with
% tau_rms / T = 0.3, so tau_rms / Tc = 1.2
% See 4.224 for reference
N_h = 3; % as determined
tau = 0:Tc:N_h-1;
M_iTc = 1/tau_rms * exp(-tau/tau_rms); % 
% normalize pdp: it must be sum(E[|htilde_i|^2]) = 1 - C^2
M_iTc = M_iTc.*(1-C^2)/sum(M_iTc);
M_d = sum(M_iTc);

pdp = M_iTc;
% add LOS component power
pdp(1) = pdp(1) + C^2;
pdp_log = 10*log10(pdp); 

% plot the normalised PDP
figure, stem(tau, pdp_log), title('PDP'), xlabel('iTc'), ylabel('E[|h_i(nTc)|^2]');
grid on;
axis([-0.25 2.25 -15 0]), ax = gca; ax.XTick = 0:2;
legend('PDP', 'Location', 'SouthWest')

%% Generation of impulse responses

channel_generator;

%% Show the behavior of |h_1(nTc)| for n = 0:1999, dropping the transient

figure, hold on
plot(0:1999, abs(h_mat(2, 1:2000).'))
grid on, box on, xlabel('nT_c'), ylabel('|h_1(nT_c)|')
title('|h_1(nT_C)|')

%% Show all |h_i|'s
% Just for debugging purposes

figure, hold on
plot(0:9999, abs(h_mat(:, 1:10000).'))
grid on, box on, xlabel('Time samples'), ylabel('|h_i(nT_C)|_{dB}')
legend('h_0', 'h_1', 'h_2')
title('|h_i|')

%% Histogram of h_1

% Plot of the required histogram
figure, histogram(abs(h_mat(2, 1:1000)).'/sqrt(M_iTc(2)), 100, 'Normalization','pdf', 'DisplayStyle', 'stairs');
title('Experimental PDF from 1000 samples of |h_1|/sqrt(E[|h_1|^2])')

% This plot can be used to explain that because of the correlation we can't
% get a nice pdf (too little samples, correlation in peaks)
figure, 
subplot 121
histogram(abs(h_mat(2, 1:1000).'), 100, 'Normalization','pdf', 'DisplayStyle', 'stairs');
camroll(90)
title('1000 samples of |h_1|')
subplot 122
plot(0:999, abs(h_mat(2, 1:1000).'));
title('Realization of h_1 over which the histogram is computed');
grid on

% Here we show that the experimental PDF gets better with more samples
figure
subplot 211
histogram(abs(h_mat(2, 1: 10000).')/sqrt(M_iTc(2)), 20,'Normalization','pdf', 'DisplayStyle', 'stairs')
title('10000 samples of |h_1|')
hold on
a = 0:0.01:3;
plot(a, 2.*a.*exp(-a.^2), 'LineWidth', 1.5);  % Theoretical PDF (page 308, BC)
hold off
legend('h1', 'Rayleigh pdf');
subplot 212
histogram(abs(h_mat(2, 1: 100000).')/sqrt(M_iTc(2)), 20,'Normalization','pdf', 'DisplayStyle', 'stairs')
title('100000 samples of |h_1|')
hold on
a = 0:0.01:3;
plot(a, 2.*a.*exp(-a.^2), 'LineWidth', 1.5);  % Theoretical PDF (page 308, BC)
hold off
legend('h1', 'Rayleigh pdf');

%% Histograms of h_1 in subsequent disjoint intervals
% TODO: bring it in the report
% The variability shows that these intervals of 1000 samples are too small.
% Looking at |g1| in one of these intervals, we observe that this quantity
% has an oscillatory trend. In fact, h1(nTc) for different n's are
% identically distributed rv's, but they are not independent. Whenever
% there is a peak (max or min), the values of g1 for consecutive
% time instants are similar, therefore they build up on the histogram,
% showing a small number of peaks in the histogram itself. These peaks are
% the values of g1 around the instants nTc in which it has a local max or min.
% If we take a sufficiently large time window, the number of maxima and
% minima increases, and they can be considered independent if they are
% enough (?).
% Considering two different realizations of the channel impulse response,
% two samples of g1 at the same time (taken from these two realizations)
% are not only identically distributed, but also independent. Therefore
% with as little as 1000 such samples we observe a distribution very close
% to a Rayleigh distribution, as we expect from our model.

% Uncomment the following code to see that variability

% figure
% width = 1000;
% for i = 0:9
%     histogram(abs(h_mat(2, (i*width + 1):((i+1)*width)).')/sqrt(pdp_gauss(2)), 100)
%     axis([0 2.5 0 0.05*width])
%     pause
% end

%% Autocorrelation of h_1
% TODO remove, just for debugging
% begin = 1;
% end_factor = 0.3;
% h1_temp = h_mat(2, begin:end*end_factor).';
% N_corr = 5000; %floor(length(g1_temp/10)); % there are lot of samples!
% 
% autoc_1_intime = autocorrelation(h1_temp, N_corr);
% z = (0:length(autoc_1_intime)-1)*2*pi*fd; %support for bessel function, LAG not actual time
% M_1 = autoc_1_intime(1); %stat power of g_1 over the considered support in time
% bess = besselj(0, z); %bessel function of order 0
% 
% figure, plot(real(autoc_1_intime)), hold on, plot(bess*M_1)
% legend('Real(r_g(\Delta t))', 'Bessel function, first type, order 0')
% title('Autoc from t=0')
% 
% begin = 30000;
% end_factor = 0.5;
% h1_temp = h_mat(2, begin:end*end_factor).';
% N_corr = 4000; %floor(length(g1_temp/10)); % there are lot of samples!
% 
% autoc_1_intime = autocorrelation(h1_temp, N_corr);
% z = (0:length(autoc_1_intime)-1)*2*pi*fd;
% M_1 = autoc_1_intime(1);
% bess = besselj(0, z);
% 
% figure, plot(real(autoc_1_intime)), hold on, plot(bess*M_1)
% legend('Real(r_h(\Delta t))', 'Bessel function, first type, order 0')
% title(sprintf('Autoc from t=%d', begin))


%% Simulation
% TODO: Michele comment
numexp = 1000;
h_samples_needed = 200000 + ceil(Tp/Tc*length(h_dopp)); % Some will be dropped because of transient, since
% enough time, memory and computational power are available 
w_samples_needed = ceil(h_samples_needed / Tp);
transient = ceil(Tp/Tc*length(h_dopp));

h_1 = zeros(numexp, 1);
for k = 1:numexp
    disp(k)
    w = wgn(w_samples_needed,1,0,'complex');
    hprime = filter(b_dopp, a_dopp, w);
    % Interpolation
    t = 1:length(hprime);
    t_fine = Tq/Tp:Tq/Tp:length(hprime);
    h_fine = interp1(t, hprime, t_fine, 'spline');
    % Drop the transient
    h_notrans = h_fine(50000:end);
    % Energy scaling
    h_1(k) = h_notrans(152);  % it should be multiplied by sqrt(pdp(2)) but since
    % for the histogram it is required to divide for the same factor then
    % we drop this computation to save computational time
end

figure, 
histogram(abs(h_1), 20, 'Normalization','pdf', 'DisplayStyle', 'stairs')
title('|h1(151T_C)| over 1000 realizations vs Rayleigh pdf')
hold on
a = 0:0.01:3;
plot(a, 2.*a.*exp(-a.^2), 'LineWidth', 1.5);  % Theoretical PDF (page 308, BC)
hold off
legend('h1', 'Rayleigh pdf');