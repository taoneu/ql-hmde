function f = delq(x, M)
%DTZL1 DTLZ1 multi-objective function
%   Syntax:
%      f = dtzl1(x, M)
%
%   Input arguments:
%      x: a n x mu matrix with mu points and n dimensions
%      M: a scalar with the number of objectives
%
%   Output argument:
%      f: a m x mu matrix with mu points and their m objectives computed at
%         the input

X=x';
Xpop=size(X,1); % 
J=ones(Xpop,M);%
HORIZON_ALL=5000;%

%% CommonParas
INV_UP=3000;
INV_LOW=0;
ORDER_LOW=0;
Nmac=4;     % 
N=2*Nmac;   % 
Ns=1;       % 
y_initial=[1500;1500;1500;1500;1500;1500;1500;1500];    % 
y_target=[2000;2000;2000;2000;1000;1000;1000;1000];     % 
alpha  =[0   0   0   0.1   0   0.9   0 0.8];% 
beta   =[0.9 1 0.9   1   0.9 1 0.9   1  ];  % 
front_m=[0  ;1  ;2  ;3  ;4  ;5  ;4  ;7  ];  % 
LTs    =[1  ;1  ;1  ;1  ;1  ;1  ;1  ;1  ];  % 
back_m =[2 0;3 0;4 0;5 7;6 0;0 0;8 0;0 0];  % 
inv_dealer=[6 8];                           % 

A=eye(N);
C=eye(N);
F=1*eye(N);%
F(2,2)=0.991;
F(3,3)=0.995;
F(4,4)=0.999;
F(5,5)=1.001;
F(6,6)=1.003;
F(7,7)=1.005;
F(8,8)=1.009;
for i =1:N %supply_net��Snet
    if i == 1
        Snet=[0 1];
    elseif i<= Ns && i >1
        Snet=[Snet; 0 i];
    else
        for j =1:length(front_m(i,:))
            Snet=[Snet; front_m(i,j) i];
        end
    end    
end
for i =1:N %
    if i==1
        max_queue_len(i)=max(LTs(i,:));%
        X_0=zeros(max_queue_len(i),1);%
        X_0(1,1)=y_initial(i,:);%
    else
        max_queue_len(i)=max(LTs(i,:));%
        X_0_new=zeros(max_queue_len(i),1);%
        X_0_new(1,1)=y_initial(i,:);%
        X_0=[X_0;X_0_new];%
    end
end
for i =1:N %
    A(i,i)=1-alpha(i);
end
for i =1:N %
    Bn=zeros(max_queue_len(i),nnz(front_m)+Ns);%nnz
    [c, ~, ~]=intersect(i,inv_dealer);%
    if isempty(c)%
        for j=1:length(back_m(i,:))%
            for k =1:size(Snet,1)%
                if i==Snet(k,1) &&back_m(i,j)==Snet(k,2)
                    temp_index=k;
                    break;
                end
            end
            Bn(1,temp_index)=-1;%
        end
    end    
    if i<=Ns %
        for k =1:size(Snet,1)%
            if 0==Snet(k,1) &&i==Snet(k,2)
                temp_index=k;
                break;
            end
        end
        Bn(max_queue_len(i),temp_index)=1;
    else %
        for j =1:length(front_m(i,:)) %
            for k =1:size(Snet,1)%
                if front_m(i,j)==Snet(k,1) &&i==Snet(k,2)
                    temp_index=k;%
                    break;
                end
            end
            temp_index2=LTs(i,j);%
            Bn(temp_index2,temp_index)=beta(front_m(i,j));
        end
    end    
    if i==1
        B=Bn;
    else
        B=[B;Bn];
    end
end
% all_time=[];
%% 
parfor xpop=1:Xpop

%     t1=cputime;
%     t_inv=0;
%     t_ls=0;
    R=eye(N);
    for i=1:N
        R(i,i) = R(i,i) * (10 .^ round(X(xpop,3+i)));
    end
    Q=eye(N);
    for i=1:N
        Q(i,i) = Q(i,i) * (10 .^ round(X(xpop,11+i)));
    end    
    QR_NUM=size(Q,1)+size(R,1);
    
    argum_x_range=length(X_0)+length(y_target);
    argum_y_range=size(Snet,1);
    H1_11=eye(argum_x_range);
    H1_12=zeros(argum_x_range,argum_y_range);
    H1_21=zeros(argum_y_range,argum_x_range);
    H1_22=eye(argum_y_range);    
    

    
    TT=HORIZON_ALL;
    y_cycle=zeros(N,TT);
    u=zeros(size(Snet,1),TT);
    offline_train=10;
    
    gamma=X(xpop,20);
    Q1=[C'*Q*C -C'*Q;-Q*C Q];
    G=[Q1 zeros(length(Q1),length(R));zeros(length(R),length(Q1)) R];
    T=[A zeros(length(A),length(F));zeros(length(F),length(A)) F];
    B1=[B;zeros(length(F),length(R))];
    xx=X_0;
    r=y_target;
    
    H1=[H1_11 H1_12;
        H1_21 H1_22];%P
    H1yy=H1(argum_x_range+1:argum_x_range+argum_y_range,argum_x_range+1:argum_x_range+argum_y_range);%
    H1yx=H1(argum_x_range+1:argum_x_range+argum_y_range,1:argum_x_range);%
    L1=-inv(H1yy)*H1yx;%
    L_old=L1;
    H_old=H1;
    for i=1:offline_train   %
        H1=G+gamma*[T B1;L1*T L1*B1]'*H1*[T B1;L1*T L1*B1];% 
        H1yy=H1(argum_x_range+1:argum_x_range+argum_y_range,argum_x_range+1:argum_x_range+argum_y_range);%
        H1yx=H1(argum_x_range+1:argum_x_range+argum_y_range,1:argum_x_range);%
        L1=-inv(H1yy)*H1yx;% 
        L_old=L1;
        H_old=H1;
    end
    
    %% 
    breakflag=0;
    TT=HORIZON_ALL;
    y_cycle=zeros(N,TT);%
    XX=zeros(argum_x_range,TT);
    u=zeros(size(Snet,1),TT);%
    
    %===============�������=================
    data_num=round(X(xpop,1));%
    noise_period=data_num*round(X(xpop,2));%
    %=======================================
    
    learning_period=noise_period;%
    Memory_size=data_num;%
    H1_scale=argum_x_range+argum_y_range;
    H=H1*0.9;%
    Hyy=H(argum_x_range+1:argum_x_range+argum_y_range,argum_x_range+1:argum_x_range+argum_y_range);
    Hyx=H(argum_x_range+1:argum_x_range+argum_y_range,1:argum_x_range);
    L=-inv(Hyy)*Hyx;
    
    
    
    zbar_memory=[];
    d_target_memory=[];
    kk=0;
    
    for i=1:TT
        if i>learning_period
           break; 
        end
        
        if rem(i,data_num)==1
            xx(:,i)=X_0;
            r(:,i)=y_target;
        end
        XX(:,i)=[xx(:,i);r(:,i)];%
        r(:,i+1)=F*r(:,i);
        
        
        a2=0.97;% 
        if i>=noise_period% 
            a2=0;
        end
        noise=zeros(8,1);
        noise(1,1)=a2*(0.5*sin(2.0*i)^2*cos(10.1*i)+0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2+0.5*cos(2.4*i)*sin(8*i)^2+0.3*sin(1.000*i)^1*cos(0.799999*i)^2+0.3*sin(4*i)^3+0.4*cos(2*i)*1*sin(5*i)^4+0.3*sin(10.00*i)^3);
        noise(2,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2+0.5*cos(2.4*i)*sin(8*i)^2+0.3*sin(1.000*i)^1*cos(0.799999*i)^2+0.3*sin(4*i)^3+0.4*cos(2*i)*1*sin(5*i)^4+0.3*sin(10.00*i)^3);
        noise(3,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2+0.5*cos(2.4*i)*sin(8*i)^2+0.3*sin(1.000*i)^1*cos(0.799999*i)^2+0.3*sin(4*i)^3+0.4*cos(2*i)*1*sin(5*i)^4);
        noise(4,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2+0.5*cos(2.4*i)*sin(8*i)^2+0.3*sin(1.000*i)^1*cos(0.799999*i)^2+0.3*sin(4*i)^3);
        noise(5,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2+0.5*cos(2.4*i)*sin(8*i)^2+0.3*sin(1.000*i)^1*cos(0.799999*i)^2);
        noise(6,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2+0.5*cos(2.4*i)*sin(8*i)^2);
        noise(7,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2+0.400*sin(1.12*i)^2);
        noise(8,1)=a2*(0.9*sin(1.102*i)^2*cos(4.001*i)+0.3*sin(1.99*i)^2*cos(7*i)+0.3*sin(10.0*i)^3+0.7*sin(3.0*i)^2*cos(4.0*i)+0.3*sin(3.00*i)*1*cos(1.2*i)^2);
        noise = noise * (10 .^ round(X(xpop,3)));
        
        
        u(:,i)=L*XX(:,i);
        u(:,i)=u(:,i)+noise;
        xx(:,i+1)=A*xx(:,i)+B*u(:,i);
        y_cycle(:,i)=C*xx(:,i);
        XX(:,i+1)=[xx(:,i+1);r(:,i+1)];
        
       
        if length(d_target_memory)<Memory_size
            d_target_memory=[d_target_memory;[XX(:,i); u(:,i)]'*G*[XX(:,i); u(:,i)]+gamma*[XX(:,i+1);L*XX(:,i+1)]'*H*[XX(:,i+1);L*XX(:,i+1)]];
        else
            for j=1:Memory_size-1
                d_target_memory(j,1)=d_target_memory(j+1,1);
            end
            d_target_memory(Memory_size,1)=[XX(:,i); u(:,i)]'*G*[XX(:,i); u(:,i)]+gamma*[XX(:,i+1);L*XX(:,i+1)]'*H*[XX(:,i+1);L*XX(:,i+1)];
        end
        
        zbar=zeros(H1_scale,1);
        zbar_index=1;
        for j=1:argum_x_range
            for k=j:argum_x_range
                zbar(zbar_index,1)=XX(j,i)*XX(k,i);
                zbar_index=zbar_index+1;
            end
            for k=1:argum_y_range
                zbar(zbar_index,1)=XX(j,i)*u(k,i);
                zbar_index=zbar_index+1;
            end
        end
        for j=1:argum_y_range
            for k=j:argum_y_range
                zbar(zbar_index,1)=u(j,i)*u(k,i);
                zbar_index=zbar_index+1;
            end
        end
        if size(zbar_memory,2)<Memory_size
            zbar_memory=[zbar_memory zbar];
        else
            for j=1:Memory_size-1
                zbar_memory(:,j)=zbar_memory(:,j+1);
            end
            zbar_memory(:,Memory_size)=zbar;
        end
        
       
        if mod(i,data_num)==0 %mod(a,b)
            kk=kk+1;
            if i<=learning_period
                sample_index=randperm(Memory_size,Memory_size)+(length(d_target_memory)-Memory_size);
                sample_index=sort(sample_index);
                zbar_batch=zeros(size(zbar_memory,1),Memory_size);
                d_target_batch=zeros(Memory_size,1);
                for j= 1:Memory_size
                    d_target_batch(j,1)=d_target_memory(sample_index(j),1);
                    zbar_batch(:,j)=zbar_memory(:,sample_index(j));
                end
                m=zbar_batch*zbar_batch';
                q=zbar_batch*d_target_batch;
                
                nan_num=sum(isnan(m(:)))+sum(isnan(q(:)));
                inf_num=sum(isinf(m(:)))+sum(isinf(q(:)));
                if nan_num+inf_num>0
                    breakflag=1;
                    break;
                end
                vh_test4=lsqminnorm(m,q);
                
                
                vH=vh_test4;
                vH_index=1;
                for j =1:H1_scale
                    for k=j:H1_scale
                        if j==k
                            H(k,j)=vH(vH_index,1);
                        else
                            H(k,j)=vH(vH_index,1)/2;
                        end
                        vH_index=vH_index+1;
                    end
                end
                H = tril(H,-1)+triu(H',0);
                Hyy=H(argum_x_range+1:argum_x_range+argum_y_range,argum_x_range+1:argum_x_range+argum_y_range);
                Hyx=H(argum_x_range+1:argum_x_range+argum_y_range,1:argum_x_range);                
                L=-inv(Hyy)*Hyx;
                
                
            end           
        end
     end
       

    J_tmp=zeros(1,M);
     if breakflag==0 
        
         T_test=30;
         x_test=X_0;
         
         X_test=zeros(size(X_0,1)+size(y_target,1),T_test+1);
         r_test=zeros(size(y_target,1),T_test+1);
         u_test=zeros(size(X_0,1),T_test);
         y_cycle_test=zeros(size(X_0,1),T_test);
         
         
         X_test(:,1)=[X_0;y_target];
         r_test(:,1)=y_target;
         
         for j=1:T_test       
             r_test(:,j+1)=F*r_test(:,j);
             u_test(:,j)=L*X_test(:,j);
             x_test(:,j+1)=A*x_test(:,j)+B*u_test(:,j);
             y_cycle_test(:,j)=C*x_test(:,j);
             X_test(:,j+1)=[x_test(:,j+1);r_test(:,j+1)];
         end
    
         %obj1 
         cost_steady=0;
         for j =1:size(y_cycle_test,1)
             cost_steady=cost_steady+abs(y_cycle_test(j,T_test)-r_test(j,T_test));
         end
         if isnan(cost_steady)||isinf(cost_steady)
            cost_steady=1e8; 
         end
         
         %obj2 
         cost_penalty=0;
         cost_extra_rent_1=0;
         cost_extra_rent_2=0;
         cost_extra_rent_3=0;
         for j=1:T_test%
             for k=1:size(y_cycle_test,1)%
                 if y_cycle_test(k,j)>INV_UP
                     cost_extra_rent_1=cost_extra_rent_1+(y_cycle_test(k,j)-INV_UP)*1;
                 end
                 if y_cycle_test(k,j)<INV_LOW
                     cost_extra_rent_2=cost_extra_rent_2+(INV_LOW-y_cycle_test(k,j))*1;
                 end
                 if u_test(k,j)<ORDER_LOW
                     cost_extra_rent_3=cost_extra_rent_3+(ORDER_LOW-u_test(k,j))*1;
                 end
             end
         end
         cost_penalty=cost_extra_rent_1+cost_extra_rent_2+cost_extra_rent_3;%
         if isnan(cost_penalty)||isinf(cost_penalty)
            cost_penalty=1e8; 
         end
         
         %obj3
         overshoot=0;
         for k=1:size(y_cycle_test,1)
             
             if y_target(k)>=y_initial(k)%
                 overgap=y_cycle_test(k,1:T_test)-r_test(k,1:T_test);
             else
                 overgap=r_test(k,1:T_test)-y_cycle_test(k,1:T_test);
             end
             over_value=max(max(overgap),0);
             overshoot=overshoot+abs(over_value);
             
         end
         if isnan(overshoot)||isinf(overshoot)
            overshoot=1e8; 
         end
         %obj4 
         rise_time=0;
         for k=1:size(y_cycle_test,1)
             rise_time_tmp=0;
             if isnan(y_cycle_test(k,T_test)) || isinf(y_cycle_test(k,T_test))|| (overshoot>1e4)||(cost_steady>1e3)%
                 rise_time_tmp=1e7;
             else
                  for j=1:T_test
                     if  abs((y_cycle_test(k,j)-r_test(k,j))/r_test(k,j))<0.05
                         rise_time_tmp=j;
                         break;
                     end
                 end
                 
             end
             rise_time=rise_time+rise_time_tmp;
         end
         
         if M==1
             J_tmp(1,1)=cost_steady;%
         elseif M==2
             J_tmp(1,1)=cost_steady;%
             J_tmp(1,2)=overshoot;%
         elseif M==3
             J_tmp(1,1)=cost_steady;%
             J_tmp(1,2)=overshoot;%
             J_tmp(1,3)=rise_time;%
         end
     elseif breakflag==1%
         y_break_punish=1e8;
         if M==1            
             J_tmp(1,1)=y_break_punish;%          
         elseif M==2
             J_tmp(1,1)=y_break_punish;%
             J_tmp(1,2)=y_break_punish;%           
         elseif M==3
             J_tmp(1,1)=y_break_punish;%
             J_tmp(1,2)=y_break_punish;%
             J_tmp(1,3)=y_break_punish;%
         end         
     end 
     J(xpop,:)=J_tmp;

end
f=J';
