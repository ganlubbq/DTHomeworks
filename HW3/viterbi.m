function [ detected, pbit, num_bit_errors ] = viterbi( packet, r, hi, N1, N2, L1, L2 )
%VITERBI

% State: most recent is at the left, as in the book, and it has lowest weight
% (thus, in the base-M representation, it is of course the rightmost one).

%fprintf('Viterbi started.\n')
if (L1 > N1) || (L2 > N2)
    disp('The considered precursors and postcursors cannot be more that the actual ones!')
    return
end


% --- Setup

M = 4;
symb = [1+1i, 1-1i, -1+1i, -1-1i]; % possible transmitted symbols (QPSK)
N = N1 + N2 + 1;
L = L1 + L2 + 1;
MEMORY = 20 * N;        %
Ns = M ^ (L1+L2);               % Number of states
r  =  r(1+N1-L1 : end-N2+L2);   % Discard initial and final samples of r
hi = hi(1+N1-L1 : end-N2+L2);   % Discard initial and final samples of hi
TMAX = length(r) + 100;         % Max value of time k
SURVSEQ_OFFS = L-1;



% --- Init stuff

tStart = tic;   % Use a variable to avoid conflict with parallel calls to tic/toc
survSeq = zeros(Ns, min(TMAX, 2*MEMORY));
survSeq(:, 1+SURVSEQ_OFFS) = symb(mod(0:Ns-1, M) + 1);
survSeq_writingcol = 1+SURVSEQ_OFFS;
% TODO: init the first elements to the end of ML sequence.
% TODO: if we use u_mat we actually don't need SURVSEQ_OFFS I think.
survSeq_shift = 0;
detectedSymb = zeros(1, length(packet));
cost = zeros(Ns, 1); % Define Gamma(-1), i.e. the cost, for each state

% -- Define u_mat matrix
ndigits = L1 + L2; % n digits of the state
statevec = zeros(1, ndigits); % symbol index, from the oldest to the newest
i = ndigits;
umat = zeros(Ns, M);
for state = 1:Ns
    for j = 1:M
        lastsymbols = [symb(statevec + 1), symb(j)];   % symbols, from the oldest to the newest
        umat(state, j) = lastsymbols * flipud(hi);
    end
    
    % Update statevec
    statevec(i) = statevec(i) + 1;
    l = i;
    while (statevec(l) >= M && l > 1)
        statevec(l) = 0;
        l = l-1;
        statevec(l) = statevec(l) + 1;
    end
end


% --- Main loop

for k = 1 : length(r)
    
    % "Pointer" to the column we are gonna write in this iteration
    survSeq_writingcol = survSeq_writingcol + 1;
    
    % Initialize the costs of the new states to -1
    costnew = - ones(Ns, 1);
    
    % Vector of the predecessors: the i-th element is the predecessor at
    % time k-1 of the i-th state at time k.
    pred = zeros(Ns, 1);
    
    % Counter for the new state. It is determined iteratively even though a
    % closed form expression exists: (mod(state-1, M^(N1+N2-1)) * M + j).
    newstate = 0;
    
    
    for state = 1 : Ns  % Cycle through all states, at time k-1 (?)
        
        for j = 1 : M   % M possibilities for the new symbol
            
            % Index of the new state: it's mod(state-1, M^(N1+N2-1)) * M + j
            newstate = newstate + 1;
            if newstate > Ns, newstate = 1; end
            
            % Supposed new sequence, obtained from the old state adding a new symbol.
            %supposednewseq = [survSeq(state, 1:survSeq_writingcol-1), symb(j)];
            
            % Compute desired signal u assuming the input sequence is the one above
            %supposednewseq = supposednewseq(end-L+1:end);
            %u = supposednewseq * flipud(hi);
            
            % Desired signal u assuming the input sequence is the one above
            u = umat(state, j);
            
            % Compute the cost of the new state assuming this input sequence,
            % then update the cost of the new state, and overwrite the predecessor,
            % if this transition has a lower cost than before.
            newstate_cost = cost(state) + abs(r(k) - u)^2;
            if costnew(newstate) == -1 ...     % not assigned yet, or...
                    || costnew(newstate) > newstate_cost    % ...found path with lower cost
                costnew(newstate) = newstate_cost;
                pred(newstate) = state;
            end
        end
    end
    
    % Handle memory. If we were gonna write to the last column, first we store
    % the oldest chunk of the decided sequence (we decide it for good), then
    % we shift the matrix to make room for new data.
    if survSeq_writingcol == size(survSeq, 2)
        
        % Take the first row of old decided states and store it before erasing it.
        detectedSymb(1+survSeq_shift : survSeq_shift+MEMORY) = survSeq(1, 1:MEMORY);
        
        % Shift of half the size, that is our memory.
        survSeq(:, 1:MEMORY) = survSeq(:, MEMORY+1:end);
        survSeq_shift = survSeq_shift + MEMORY;
        survSeq_writingcol = MEMORY; % Actually it is (SIZE-MEMORY)
    end
    
    
    % The following operations strongly affect the computation time, if
    % the number of states is not too large. Otherwise the bottleneck is
    % the number of iterations of the inner loops above.
    % TODO optimize the way matrices are handled. Avoid creating so many.
    
    temp = zeros(size(survSeq));
    for newstate = 1:Ns
        temp(newstate, 1:survSeq_writingcol) = ...
            [survSeq(pred(newstate), 1:survSeq_writingcol-1), symb(mod(newstate-1, M)+1)];
    end
    survSeq = temp;
    
    
    %     % For each new state, see where its predecessor is (which row according to
    %     % statemap), then add newstate at the end of that survival sequence, and iterate
    %     % for all new states. Finally, update the statemap according to the new states at k.
    %     % Instead of sorting the rows according to the new states at k, we
    %     % store a map so as to keep track of the row in which a certain state
    %     % at time k is.
    %
    %     % These are the states at k-1 that were discarded by the algorithm, so
    %     % we can overwrite them
    %     deadsequences = setdiff(1:Ns, unique(pred)); % data in A that is not in B
    %     deadseq_idx = 1;
    %     alreadyused = false(Ns, 1); % refers to the true index of the matrix
    %     for newstate = 1:Ns
    %         if ~alreadyused(statemap(pred(newstate)))
    %             survSeq(statemap(pred(newstate)), survSeq_writingcol) = newstate;
    %             alreadyused(statemap(pred(newstate))) = true;
    %         else
    %             survSeq(statemap(deadsequences(deadseq_idx)), 1:survSeq_writingcol) = ...
    %                 [survSeq(statemap(pred(newstate)), 1:survSeq_writingcol-1), newstate];
    %             alreadyused(statemap(deadsequences(deadseq_idx))) = true; % shouldn't need this, I think
    %             deadseq_idx = deadseq_idx + 1;
    %         end
    %     end
    %     statemap = survSeq(:, survSeq_writingcol);
    
    
    
    %allcosts(:, k) = cost;
    
    % Update the cost to be used as cost at time k-1 in the next iteration
    cost = costnew;
end

%printprogress('', msg_delete);
toc(tStart)



% --- Finish storing, then get the symbols

detectedSymb(1+survSeq_shift : survSeq_shift+survSeq_writingcol-1) = ...
    survSeq(1, 1:survSeq_writingcol-1);
detectedSymb = detectedSymb(1+SURVSEQ_OFFS : end);
detected = detectedSymb;
detected = detected(2:length(packet)+1);    % Discard first symbol (time k=-1)



% --- Output results

[pbit, num_bit_errors] = BER(packet, detected);

num_errors = sum(packet-detected.' ~= 0);
fprintf('P_err = %.g (%d errors)\n', num_errors / length(packet), num_errors)
fprintf('P_bit = %.g (%d errors)\n', pbit, num_bit_errors)

% figure, hold on
% stem(-L1:length(r)-1-L1, real(r))
% stem(0:length(packet)-1, real(packet), 'x')
% stem(0:length(detected)-1, real(detected), 'd')
% legend('r', 'sent', 'detected')

end