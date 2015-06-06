function [ Jmin, psi, r ] = DFE_filter(x, hi, N1, N2, est_sigmaw, D, M1, M2, coding, verb)
% Function that performs DFE filtering. It needs
% packet is the sequence of sent symbols
% x is the received samples vector in T, normalized by h0
% h is the estimated impulse response in T, normalized by h0
% N1 is the estimated number of precursors
% N2 is the estimated number of postcursors
% est_sigmaw is the estimated variance of the noise
% t0 timing phase
% D is the delay of the FF filter
% M1 is the number of coefficients of FF filter
% M2 is the number of coefficients of FB filter, set to 0 to get LE
% if verb is true then plots will be plotted

% Power of the input sequence
sigma_a = 2;

% Zero padding of the i.r.
nb0 = 60;
nf0 = 60;
hi = [zeros(nb0,1); hi; zeros(nf0,1)];

% Get the Weiner-Hopf solution
p = zeros(M1, 1);
for i = 0:(M1 - 1)
    p(i+1) = sigma_a * conj(hi(N1+nb0+1+D-i));
end

R = zeros(M1);
for row = 0:(M1-1)
    for col = 0:(M1-1)
        first_sum = (hi((nb0+1):(N1+N2+nb0+1))).' * ...
            conj(hi((nb0+1-(row-col)):(N1+N2+nb0+1-(row-col))));
        second_sum = (hi((N1+nb0+1+1+D-col):(N1+nb0+1+M2+D-col))).' * ...
            conj((hi((N1+nb0+1+1+D-row):(N1+nb0+1+M2+D-row))));
        r_w = (row == col) * est_sigmaw; % This is a delta only if there is no g_M.
        
        R(row+1, col+1) = sigma_a * (first_sum - second_sum) + r_w;
        
    end
end

c_opt = R \ p;

Jmin = sigma_a*(1-c_opt.'* flipud(hi(N1+nb0+1+D-M1+1:N1+nb0+1+D)));

b = zeros(M2,1);
for i = 1:M2
    b(i) = - (fliplr(c_opt.')*hi((i+D+N1+nb0+1-M1+1):(i+D+N1+nb0+1)));
end

psi = conv(hi(nb0+1:nb0+1+N1+N2),c_opt);

if (verb == true)
    % Plot hhat, c, psi=conv(h,c), b and get a sense of what is happening
    figure
    subplot(4,1,1)
    stem(-N1:N2, abs(hi(nb0+1:nb0+1+N1+N2))), title('|h_{hat} normalized|'), xlim([-5 8]), ylim([0 1])
    subplot(4,1,2)
    stem(abs(c_opt)), title('|c|'), xlim([1 14]), ylim([0 1])
    subplot(4,1,3)
    stem(-N1:-N1+length(psi)-1, abs(psi)), title('|psi|'), xlim([-N1 -N1+length(psi)]), ylim([0 1])
    subplot(4,1,4)
    stem(abs(b)), title('|b|'), xlim([1 14]), ylim([0 1])
end

y = zeros(length(x) + D , 1); % output of ff filter
r = zeros(length(x) + D, 1);
detected = zeros(length(x) + D, 1); % output of td
for k = 0:length(x) - 1 + D
    if (k < M1 - 1)
        xconv = [flipud(x(1:k+1)); zeros(M1 - k - 1, 1)];
    elseif k > length(x)-1 && k < length(x) - 1 + M1
        xconv = [zeros(k-length(x)+1, 1); flipud(x(end - M1 + 1 + k - length(x) + 1:end))];
    elseif k >= length(x) - 1 + M1 % just in case D is greater than M1
        xconv = zeros(M1, 1);
    else
        xconv = flipud(x(k-M1+1 + 1:k + 1));
    end
    
    if (k <= M2)
        a_old = [flipud(detected(1:k)); zeros(M2 - k, 1)];
    else
        a_old = flipud(detected(k-M2+1:k));
    end
    
    y(k+1) = c_opt.'*xconv;
    r(k+1) = y(k+1) + b.'*a_old;
    detected(k+1) = qpsk_td(r(k+1));
end

if (coding == true)
   r = r(D+1:end);
else % if coding is not used return the decisions
   r = detected(D+1:end);
end

end
