% This script solves the second problem.
clear
close all
clc

rng default

parpool(4);

%% Known channel, DFE, uncoded data (HW3)

% The design of the DFE equalizer has to be carried out assuming the
% channel is known
% From the assigned impulse response
t0 = 6;
N1 = 0;
N2 = 4;

snr_vec_knownch_uncoded = 0:14;
seq_lengths_knownch_uncoded = 2.^[13 13 13 13 13 13 13 15 18 18 20 20 22 23 23];
Pbit_knownch_uncoded = zeros(length(snr_vec_knownch_uncoded),1);

parfor snr_idx = 1:length(snr_vec_knownch_uncoded)
    curr_snr = snr_vec_knownch_uncoded(snr_idx);
    fprintf('Known channel, uncoded, snr = %d\n', curr_snr);
    
    % Generate the current needed sequence
    bits = randi([0 1], 1, seq_lengths_knownch_uncoded(snr_idx));
    symbols = bitmap(bits.');
    
    % Send through the channel
    [rcv_symb, sigma_w, h] = channel_output(symbols, 10^(curr_snr/10), false);
    rcv_symb = rcv_symb(t0:end-7)/h(t0);
    hi = h(t0-N1:t0+N2)/h(t0);
    
    % Receiver: filter with DFE
    M1_dfe = 15;
    D_dfe = M1_dfe - 1;
    M2_dfe = N2 + M1_dfe - 1 - D_dfe;
    [~, rcv_bits] = DFE_filter(rcv_symb, hi.', N1, N2, sigma_w, D_dfe, M1_dfe, M2_dfe, false, false);
    rcv_bits = ibmap(rcv_bits);
    
    % Compute the Pbit and store it
    Pbit_knownch_uncoded(snr_idx) = sum(xor(rcv_bits.', bits))/length(bits);
    
end

% Save current results
save('Problem2_knownch_uncoded', 'snr_vec_knownch_uncoded', ...
   'seq_lengths_knownch_uncoded', 'Pbit_knownch_uncoded');

%% Known channel, DFE, coded data
% The design of the DFE equalizer has to be carried out assuming the
% channel is known
% From the assigned impulse response
t0 = 6;
N1 = 0;
N2 = 4;

% Get optimal number of bits
desired_bits = 2^22;
% Compute the closest number of bits that both interleaver and encoder will
% like
found = false;
bit_number = 0;
while(~found)
    search_step = 32400;
    bit_number = bit_number + search_step;
    if (bit_number > desired_bits)
        found = true;
    end
end

snr_vec_knownch_coded = [1, 1.5, 2:0.1:2.5];  % Pbit falls at 2.2 dBs
seq_lengths_knownch_coded = bit_number*ones(1, length(snr_vec_knownch_coded));
Pbit_knownch_coded = zeros(length(snr_vec_knownch_coded),1);

parfor snr_idx = 1:length(snr_vec_knownch_coded)
    curr_snr = snr_vec_knownch_coded(snr_idx);
    fprintf('Known channel, coded, snr = %d\n', curr_snr);
    
    % Generate the current needed sequence
    bits = randi([0 1], 1, seq_lengths_knownch_coded(snr_idx));
    
    enc_bits = encodeBits(bits);
    
    int_enc_bits = interleaver(enc_bits);  % Interleave the encoded bits
    
    symbols = bitmap(int_enc_bits.');
    
    % Send through the channel
    [rcv_symb, sigma_w, h] = channel_output(symbols, 10^(curr_snr/10), false);
    rcv_symb = rcv_symb(t0:end-7)/h(t0);
    hi = h(t0-N1:t0+N2)/h(t0);
    
    % Receiver: filter with DFE
    M1_dfe = 15;
    D_dfe = M1_dfe - 1;
    M2_dfe = N2 + M1_dfe - 1 - D_dfe;
    [~, rcv_bits] = DFE_filter(rcv_symb, hi.', N1, N2, sigma_w, D_dfe, M1_dfe, M2_dfe, true, false);
    
    % Compute Log Likelihood Ratio
    llr = zeros(2*length(symbols),1);
    llr(1:2:end) = -2*real(rcv_bits)/(sigma_w/2);
    llr(2:2:end) = -2*imag(rcv_bits)/(sigma_w/2);
    
    % Decode the bits
    llr = deinterleaver(llr); % Deinterleave the loglikelihood ratio first
    dec_bits = decodeBits(llr).';
    
    % Compute the Pbit and store it
    Pbit_knownch_coded(snr_idx) = sum(xor(dec_bits, bits))/length(bits);
    
end

% Save current results
save('Problem2_knownch_coded', 'snr_vec_knownch_coded', ...
   'seq_lengths_knownch_coded', 'Pbit_knownch_coded');


%% Estimated channel, DFE, uncoded data
% L = 31
% The design of the DFE equalizer has to be carried out assuming the
% channel is known
% From the assigned impulse response
t0 = 6;
N1 = 0;
N2 = 4;
L = 31;
Nseq = 7;

snr_vec_estch_uncoded = 0:14;
seq_lengths_estch_uncoded = 2.^[13 13 13 13 13 13 13 13 13 14 15 15 18 18 18] -1;
Pbit_estch_uncoded = zeros(length(snr_vec_estch_uncoded),1);

parfor snr_idx = 1:length(snr_vec_estch_uncoded)
    curr_snr = snr_vec_estch_uncoded(snr_idx);
    fprintf('Estimated channel, uncoded, snr = %d\n', curr_snr);
    
    % Send through the channel
    [packet, rcv_symb, sigma_w] = txrc(seq_lengths_estch_uncoded(snr_idx), curr_snr);
    
    % Perform estimation
    [h, est_sigma_w] = get_channel_info(rcv_symb(t0:t0+L+Nseq-1), N1, N2);
    
    rcv_symb = rcv_symb(t0:end-7)/h(N1+1);
    hi = h / h(N1+1);
    
    % Receiver: filter with DFE
    M1_dfe = 15;
    D_dfe = M1_dfe - 1;
    M2_dfe = N2 + M1_dfe - 1 - D_dfe;
    [~, rcv_bits] = DFE_filter(rcv_symb, hi, N1, N2, est_sigma_w, D_dfe, M1_dfe, M2_dfe, false, false);
    rcv_bits = ibmap(rcv_bits);
    packet = ibmap(packet);
    
    % Compute the Pbit and store it
    Pbit_estch_uncoded(snr_idx) = sum(xor(rcv_bits, packet))/length(packet);
    
end

% Save current results
save('Problem2_estch_uncoded', 'snr_vec_estch_uncoded', ...
   'seq_lengths_estch_uncoded', 'Pbit_estch_uncoded');

%% Estimated channel, DFE, coded data
% In this section we don't use the txrc function for now. This is because
% txrc only accepts L_data such that an ML sequence can be directly
% created.

% The design of the DFE equalizer has to be carried out assuming the
% channel is known
% From the assigned impulse response
t0 = 6;
N1 = 0;
N2 = 4;
L = 31;
Nseq = 7;

% Get optimal number of bits
% desired_bits = 2^22;
% % Compute the closest number of bits that both interleaver and encoder will
% % like
% found = false;
% bit_number = 0;
% while(~found)
%     search_step = 32400;
%     bit_number = bit_number + search_step;
%     if (bit_number > desired_bits)
%         found = true;
%     end
% end

snr_vec_estch_coded = [1, 2, 3, 3.2:0.05:3.6];  % Pbit falls at 3.5 dB
seq_lengths_estch_coded = bit_number*ones(1, length(snr_vec_estch_coded));
Pbit_estch_coded = zeros(length(snr_vec_estch_coded),1);

parfor snr_idx = 1:length(snr_vec_estch_coded)
    curr_snr = snr_vec_estch_coded(snr_idx);
    fprintf('Estimated channel, coded, snr = %d\n', curr_snr);
    
    % Generate the current needed sequence
    packet = randi([0 1], 1, seq_lengths_estch_coded(snr_idx));
    
    enc_packet = encodeBits(packet);
    int_enc_packet = interleaver(enc_packet);  % Interleave the encoded bits
    
    symbols = [ts_generation(L, Nseq); bitmap(int_enc_packet.')];
    
    % Send through the channel
    [rcv_symb, sigma_w, ~] = channel_output(symbols, 10^(curr_snr/10), false);
    
    % Perform estimation
    [h, est_sigma_w] = get_channel_info(rcv_symb(t0:t0+L+Nseq-1), N1, N2);
    
    rcv_symb = rcv_symb(t0:end-7)/h(N1+1);
    hi = h / h(N1+1);
    
    % Receiver: filter with DFE
    M1_dfe = 15;
    D_dfe = M1_dfe - 1;
    M2_dfe = N2 + M1_dfe - 1 - D_dfe;
    [~, rcv_bits] = DFE_filter(rcv_symb, hi, N1, N2, est_sigma_w, D_dfe, M1_dfe, M2_dfe, true, false);
    
    % Compute Log Likelihood Ratio
    llr = zeros(2*length(packet),1);
    llr(1:2:end) = -2*real(rcv_bits(L+Nseq+1:end))/(est_sigma_w/2);
    llr(2:2:end) = -2*imag(rcv_bits(L+Nseq+1:end))/(est_sigma_w/2);
   
    llr = deinterleaver(llr); % Deinterleave the loglikelihood ratio first
   
    dec_packet = decodeBits(llr).';
    
    % Compute the Pbit and store it
    Pbit_estch_coded(snr_idx) = sum(xor(dec_packet, packet))/length(packet);
    
end

% Save current results
save('Problem2_estch_coded', 'snr_vec_estch_coded', ...
   'seq_lengths_estch_coded', 'Pbit_estch_coded');

%% Plot BER graphs

load('Problem2_estch_uncoded.mat');
load('Problem2_estch_coded.mat');
load('Problem2_knownch_uncoded.mat');
load('Problem2_knownch_coded.mat');

figure, semilogy(snr_vec_knownch_uncoded, Pbit_knownch_uncoded), hold on
semilogy(snr_vec_knownch_coded, Pbit_knownch_coded), hold on
semilogy(snr_vec_estch_uncoded, Pbit_estch_uncoded, '--')
semilogy(snr_vec_estch_coded, Pbit_estch_coded, '--')
xlabel('snr [dB]'), ylabel('BER')
ylim([10^-5, 10^-0.1])
xlim([0, 14])
legend('Known channel, uncoded', 'Known channel, coded', ...
    'Estimated channel, uncoded', 'Estimated channel, coded');

%% Clean parpool
delete(gcp)