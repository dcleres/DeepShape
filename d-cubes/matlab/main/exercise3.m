%Code for problem 3.2
clc; 
clf;

%Defines constants, functions, and preallocates variables.
M=2.^(5:9);
alpha=1;
sigma=3/2;
beta=-sin(sigma)^2;
F=@(x) 4*sigma^2*cos(sigma*x).^2;
sol=@(x) cos(sigma*x).^2-tan(sigma*x)/tan(sigma);
leg=cell(length(M)+1,1);
er=zeros(length(M),1);
t=zeros(length(M),1);
t_thomas=zeros(length(M),1);
t_g=zeros(length(M),1);
r=@(x) 2*sigma^2*sec(sigma*x).^2;
%Starts main loop to obtain error and time estimates
%---------------------------------------------------------------------------------
for i=1:length(M)
N=M(i);
h=1/N;
x=0:h:1;
%Builds the matrix
B=(1/h^2)*(diag(2*ones(N-1,1))-diag(1*ones(N-2,1),-1)-diag(1*ones(N-2,1),1));
B=B+diag(r(x(2:end-1)));
B=sparse(B);
%builds the RHS
f=F(x(2:end-1));
f(1)=f(1)+alpha/h^2;
f(end)=f(end)+beta/h^2;
tic;
%solves using \
u_int=B\f';
t(i)=toc;
%Includes BC and finds the error
u=[alpha;u_int;beta];
er(i)=max(abs(u'-sol(x)));
%Solves and takes time for Thomas and GE
tic;
u_int_thomas=Thomas(diag(B,-1),diag(B),diag(B,1),f);
t_thomas(i)=toc;
tic;
u_int_gauss=gaussian_elimination(B,f);
t_g(i)=toc;
subplot(131);
hold on
plot(x,u);
%for the plot legend
leg{i}=['h=1/',num2str(N)];
end
%---------------------------------------------------------------------------------
%Plots some additional results
h=1./M;
plot(x,sol(x),'--r'); %Plots solution
hold off
grid on
leg{end}='True';
legend(leg{1:end});
subplot(132);
%Plots error
loglog(h,er); hold on
loglog(h,h.^2,'--r');
title('error');
legend('error','h^2')
grid on
hold off
subplot(133);
%Plots time to solution
loglog(h,t,h,t_thomas,h,t_g);
hold on;
loglog(h,(10^-6)*1./h,'--r',h,(10^-8)*(1./h).^3,'--b')
grid on;
legend('\','Thomas','GE','h^{-1}','h^{-3}')
