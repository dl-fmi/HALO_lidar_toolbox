function [ epsilon_field ] = calculateHALOturbulenceCoupling(epsilon,skewn,cloudmask,th,sun_rise_set,time)
%calculateHALOturbulenceCoupling creates a mask indicating is the turbulence
%in contact with surface, cloud, both, or neither of them.
%
%0: no signal
%1: non turbulent
%2: connected with surface
%3: connectedt with cloud
%4: in cloud
%5: unconnected

% rm nans
skewn(isnan(epsilon)) = nan;

% Skewness field
%0: no signal
%1: pos skewness connected with surface
%2: neg skewness
%3: in cloud
%4: neg skewness connected with cloud
%5: pos skewness unconnected

% Initialize
skewness_field = zeros(size(epsilon));
skewness_field(skewn > th.vert_velo) = 1;
skewness_field(skewn <= th.vert_velo) = 2;
skewness_field(cloudmask) = 3; % cloud

% Find negative skewness connected with cloud
for ii = 1:size(skewness_field,1)
    if any(cloudmask(ii,:),2) % cloud in profile?
        for jj = size(skewness_field,2):-1:3
            % cloud top
            if skewness_field(ii,jj)==3 % if cloud
                jj2 = jj;
                % cloud bottom
                while jj2>4 && skewness_field(ii,jj2)==3
                    jj2 = jj2-1;
                end
                % if neg. skewness
                if jj2>4 && (skewness_field(ii,jj2)==2 || skewness_field(ii,jj2)==0) 
                    jj3=jj2;
                    % while neg. skewness
                    while jj3>3 && (skewness_field(ii,jj3)==2 || skewness_field(ii,jj3)==0) 
                        jj3 = jj3-1;
                        % if pos. but next range gate is negative, i.e.
                        % allow one pos. in between neg. gates
                        if skewness_field(ii,jj3)~=2 && skewness_field(ii,jj3-1)==2
                            jj3 = jj3-1;
                        end
                    end
                    % From cloud bottom to when skewness changes to pos.
                    skewness_field(ii,jj2:-1:jj3+1)=4;
                end
                
            end
        end
    end
end

% % % Find negative skewness connected to surface
% % jj7 = 4;
% % for ii7 = 1:size(skewness_field,1)
% %     if  skewness_field(ii7,jj7) == 2
% %         while skewness_field(ii7,jj7) == 2 && jj7 < size(skewness_field,2)-1
% %             jj7 = jj7 + 1;
% %         end
% %         skewness_field(ii7,4:jj7) = 6;
% %         jj7 = 4;
% %     end
% % end

% Find skewness not in contact with surface
for ii = 1:size(skewness_field,1)
    izero = find(skewness_field(ii,4:end)~=1,1,'first');
    ione = find(skewness_field(ii,4:end)==1);
    if ~isempty(ione) && ~isempty(izero)
        ione(ione<izero) = []; % if '1' higher than '0', remove
        skewness_field(ii,3+ione) = 5;
    end
end


%0: no signal
%1: non turbulent
%2: epsilon > 10^-5 & connected with surface
%3: connected with cloud
%4: in cloud
%5: unconnected
%6: epsilon > 10^⁻4 & connected to surface (convective)
epsilon_field = zeros(size(epsilon));
epsilon_field(~isnan(epsilon)) = 1;
epsilon_field(epsilon > th.epsilon) = 2; % turbulence
epsilon_field(epsilon > th.epsilon & skewness_field == 4) = 3; % connected w/ cloud
epsilon_field(cloudmask) = 4; % in cloud
epsilon_field(epsilon_field == 3 & repmat(~any(cloudmask,2),1,size(epsilon_field,2))) = 5; % if cloud driven but no clouds in profile
% epsilon_field(:,1:3) = nan; % ignore

jj = 3;
for ii = 1:size(epsilon_field,1)
    if time(ii) >= sun_rise_set(1) && time(ii) <= sun_rise_set(2)
        switch any(cloudmask(ii,:))
            case 1 % cloud within boundary layer, use also skewness
                while ~isnan(epsilon(ii,jj)) && epsilon(ii,jj) > th.epsilon && ...
                       skewness_field(ii,jj) ~= 4 && epsilon_field(ii,jj) ~= 4 
                    jj = jj + 1;
                end
            case 0 % no clouds within boundary layer, use only epsilon
                while epsilon(ii,jj) > th.epsilon
                    jj = jj + 1;
                end
        end
        if jj>4
            epsilon_field(ii,4:jj) = 2; % or 6
        end
        jj = 4;
    end
end

epsilon_field(epsilon_field==2 & epsilon > th.epsilon_hi) == 6;

% Find false positives for 'epsilon in contact with surface'
for ii = 1:size(epsilon_field,1)
    i_not = find(epsilon_field(ii,4:end)~=2 & epsilon_field(ii,4:end)~=6,1,'first'); % not connected to surface
    i_yes = find(epsilon_field(ii,4:end)==2 | epsilon_field(ii,4:end)==6); % is connected to surface
    if ~isempty(i_yes)
        i_yes(i_yes<i_not) = []; % if 'not' above 'yes' --> remove
        epsilon_field(ii,3+i_yes) = 5;
    end
end

% Fix false "in contact with cloud" in between "non turbulent"
for ii = 1:size(epsilon_field,1)
    for jj = 3:size(epsilon_field,2)-1
        if  epsilon_field(ii,jj) == 3
            jj2 = jj + 1;
            while jj2 < size(epsilon_field,2) && epsilon_field(ii,jj2) == 3
                jj2 = jj2 + 1;
            end
            % if cloud not above cloud driven within 100 m
            if ~any(ismember([epsilon_field(ii,jj2),epsilon_field(ii,jj2+1),epsilon_field(ii,jj2+2),epsilon_field(ii,jj2+3)],4))
%                 if epsilon_field(ii,jj2) == 0
                    epsilon_field(ii,jj:jj2) = 5; % "not in contact with either"
%                 end
            end
        end
    end
end


epsilon_field(isnan(epsilon) & epsilon_field ~= 4) = 0;
epsilon_field(isnan(epsilon_field)) = 0; % no signal
epsilon_field(:,1:3) = nan;
end

