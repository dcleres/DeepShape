clc
clear 
close all


%%
[X,Y]=meshgrid(1:11);
figure; hold on;
plot(X,Y,'k');
plot(Y,X,'k');axis off

% draw binary shape
N=zeros(10,10);
N(2:5,2:8) = 1;
N(2:8,5:8) = 1;
% where to write text
x=linspace(1.5,10.5,10);
y=linspace(1.5,10.5,10);

% voting
I = zeros(11,11);
for n=2:9
    for p=2:9
        mask = N(n-1:n+1,p-1:p+1);
        if (sum(mask(:)) ~= 9 && N(n,p) == 1)
            %is boundary
            I(n,:) = I(n,:)+1;
            I(:,p) = I(:,p)+1;
        end
    end
end


surface(I);
h=linspace(0.5,1,64);
h=[h',h',h'];
%set(gcf,'Colormap',h);

for n=1:10
    for p=1:10
        text(y(n),x(p),num2str( I(n,p) ),'FontWeight','bold');
    end
end
% fill up cells 


view(0,-90)