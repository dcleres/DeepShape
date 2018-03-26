function hout=progbar(arg1,arg2,arg3)
%PROGBAR Create/update progress bar.
%
%   h=progbar(x,caption,pos);
%   progbar(h,x,caption);
%
%   The first form creates the progress bar.
%   The second form updates it.
%
%   h is the handle to the progress bar figure.
%   x is the fraction (from 0 to 1) of the bar to fill in.
%     If omitted on create, the default is 0.
%     If omitted on update, the bar remains unchanged.
%   caption is the caption to put above the progress bar.
%     If omitted on create, the figure has no caption.
%     If omitted on update, the caption remains unchanged.
%     If it is a cellstr, each element is printed on a separate line.
%   pos specifies the size and location of the figure,
%     using a four-element vector: [left bottom width height].
%     Units are pixels except for elements between 0 and 1,
%     which are normalized to the screen size.
%     If left or bottom is -1, the figure is centered on that axis.
%     If width is -1, 0.35 of the screen width is used.
%     If height is -1, 0.10 of the screen height is used.
%     Default is [-1 -1 -1 -1].
%
%   Notes: If the caption is too big to fit, the figure will be enlarged.
%     This check only occurs when the progress bar is created.
%     If the figure is closed, a confirmation dialog appears.
%     To delete the figure, use delete(h).
%     Bar fraction must monotonically increase.  If x is set to a value
%       less than the current value, the progress bar will not change.
%
%   PROGBAR is based on WAITBAR by The Mathworks.
%   See also WAITBAR.

% CVS ID and authorship of this code
% CVSId = '$Id: progbar.m,v 1.9 2005/02/03 16:58:35 michelich Exp $';
% CVSRevision = '$Revision: 1.9 $';
% CVSDate = '$Date: 2005/02/03 16:58:35 $';
% CVSRCSFile = '$RCSfile: progbar.m,v $';

% Process arguments
argsin=nargin;
argsout=nargout;
if argsout>1, error('Too many output arguments.'); end
create=argsout==1 | argsin==0;
if ~create, create=~(length(arg1)==1 & ishandle(arg1)); end
if create
  % Create progress bar
  x=0;
  caption='';
  pos=[-1 -1 -1 -1];
  switch argsin
    case 1
      if ischar(arg1) | iscellstr(arg1)
        caption=arg1;
      elseif length(arg1)==4
        pos=arg1;
      else
        x=arg1;
      end
    case 2
      if ischar(arg1) | iscellstr(arg1)
        caption=arg1; pos=arg2;
      elseif ischar(arg2) | iscellstr(arg2)
        x=arg1; caption=arg2;
      else
        x=arg1; pos=arg2;
      end
    case 3, x=arg1; caption=arg2; pos=arg3;
    otherwise, error(nargchk(0,3,argsin));
  end
  if length(pos)~=4 | ~isreal(pos)
    error('pos must be [left bottom width height] in pixels.');
  end
else
  % Update progress bar
  ignoreX=0;
  ignoreCaption=0;
  switch argsin
    case 2
      if isreal(arg2) & ~ischar(arg2)
        x=arg2; caption=''; ignoreCaption=1;
      else
        caption=arg2; x=0; ignoreX=1;
      end
    case 3, x=arg2; caption=arg3;
    otherwise, error(nargchk(2,3,argsin));
  end
  h=arg1;
end
if ~isreal(x) | x<0 | x>1
  error('x must be between 0 and 1.');
end
if ~ischar(caption) & ~iscellstr(caption)
  error('caption must be a string.');
end

if create
  % Create progress bar
  % Position figure according to user or in center of screen
  oldRootUnits=get(0,'Units');
  set(0,'Units','pixels');
  scr=get(0,'ScreenSize');
  set(0,'Units',oldRootUnits);
  if all(scr(3:4) == [1 1]), 
    % If there is no display, pretend that it is 640x480 to avoid calculation problems
    % and don't include the question in the close request function.
    scr(3:4) = [640 480];
    abort='closereq';
  else
    % Setup abort function
    abort=['if strcmp(''No'',questdlg(''Abort current operation?'',''Abort Dialog'',''Yes'',''No'',''Yes'')); ' ...
      'return; end, delete(gcbf);'];
  end
  fpos=pos;
  if pos(3)==-1, fpos(3)=scr(3)*0.35; elseif pos(3)>=0 & pos(3)<=1, fpos(3)=pos(3)*scr(3); end
  if pos(4)==-1, fpos(4)=scr(4)*0.10; elseif pos(4)>=0 & pos(4)<=1, fpos(4)=pos(4)*scr(4); end
  if pos(1)==-1, fpos(1)=(scr(3)-fpos(3))/2; elseif pos(1)>=0 & pos(1)<=1, fpos(1)=pos(1)*scr(3); end
  if pos(2)==-1, fpos(2)=(scr(4)-fpos(4))/2; elseif pos(2)>=0 & pos(2)<=1, fpos(2)=pos(2)*scr(4); end
  % Create the figure and contents
  h=figure('Units','pixels','Position',fpos,'Resize','off','NumberTitle','off','MenuBar','none',...
    'IntegerHandle','off','Colormap',[],'Name','Progress Bar','Tag','ProgressBarFigure',...
    'Renderer','painters','WindowStyle','modal','CloseRequestFcn',abort,'Color',[0 0 0]);
  % Create the axes
  barPos=[.05 .2 .9 .25];
  ax=axes('Position',barPos,'Box','On','DrawMode','Fast',...
    'XLim',[0 1],'YLim',[0 1],'XTickMode','manual','YTickMode','manual','XTick',[],'YTick',[],...
    'XTickLabelMode','manual','XTickLabel',[],'YTickLabelMode','manual','YTickLabel',[],...
    'DataAspectRatio',[1 1 1],'PlotBoxAspectRatio',[1 1 1],...
    'Color',[0 0 0],'XColor',[1 1 1],'YColor',[1 1 1]);
  % Make sure figure is big enough to hold title
  th=text('string',caption,'EraseMode','Background','Interpreter','none','Color',[1 1 1],'Units','Pixels');
  set(gca,'title',th);
  tExt=get(th,'Extent');
  xSpc=barPos(3);                    % Current % space for title in x (same as bar width)
  ySpc=1-(2*barPos(2)+barPos(4));    % Current % space for title in y
  if tExt(3)>xSpc*fpos(3) | tExt(4)>ySpc*fpos(4)
    if tExt(3)>xSpc*fpos(3)
      % Fig is too narrow, make wider
      fpos(3)=min(tExt(3)/xSpc,scr(3));
      if pos(1)==-1, fpos(1)=(scr(3)-fpos(3))/2; elseif pos(1)>=0 & pos(1)<=1, fpos(1)=pos(1)*scr(3); end
    end
    if tExt(4)>ySpc*fpos(4)
      % Fig is too short, make taller
      fpos(4)=min(tExt(4)/ySpc,scr(4));
      if pos(2)==-1, fpos(2)=(scr(4)-fpos(4))/2; elseif pos(2)>=0 & pos(2)<=1, fpos(2)=pos(2)*scr(4); end
    end
    % Resize figure
    set(h,'Position',fpos);
  end
  % Add the bar
  %  Note: If axis is created as width by height, the lower left corner of the axis box is (0,0)
  %  and the upper right corner is (width,height).  Also, rectangle is in *data* units.
  set(ax,'Units','pixels');
  barPix=round(get(ax,'position'));
  set(ax,'position',barPix,'XLim',[0 barPix(3)],'YLim',[0 barPix(4)]);
  barHeight=barPix(4)-2; % Leave one pixel on the top and bottom for the axes border
  barWidth=barPix(3)-2;	 % Leave one pixel on the left and right for the axes border
  x=x.*barWidth;         % Scale the width to the fraction requested.
  if x<=0, visible='off'; x=eps; else visible='on'; end % Cannot have a 0 width rectangle.
  ph=rectangle('Position',[1 1 x barHeight],'FaceColor','r','EdgeColor','r','EraseMode','none','visible',visible);
  set(h,'HandleVisibility','callback','UserData',[ph th barWidth barHeight]);
  hout=h;
else   
  % Update progress bar
  ud=get(h,'UserData');
  if ~ignoreX
    ph=ud(1);
    barWidth=ud(3);
    barHeight=ud(4);
    x=x.*barWidth;
    if x<=0, visible='off'; x=eps; else visible='on'; end
    set(ph,'Position',[1 1 x barHeight],'visible',visible);
  end
  if ~ignoreCaption
    th=ud(2);
    set(th,'String',caption);
  end 
end
drawnow;

% Modification History:
%
% $Log: progbar.m,v $
% Revision 1.9  2005/02/03 16:58:35  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.8  2004/11/01 03:32:02  michelich
% Backout Mathworks tech support suggested fix.  It is not reliable.  Revision
% 1.6 fix appears to work well, though the reason it works is still unclear.
%
% Revision 1.7  2004/08/04 22:23:52  michelich
% Based on Mathworks tech support reponse, the MATLAB 7 centering "bug" is
% expected behavior.  Units need to be normalized when setting 'XLim' and
% 'YLim' to keep title centered.  Modified code to do this.
%
% Revision 1.6  2004/08/04 00:57:07  michelich
% Added note about moving progbar backwards.
%
% Revision 1.5  2004/08/04 00:49:04  michelich
% MATLAB 7 has bug(s) in keeping text centered.  Appears to work if text
% 'units' changed before setting axis 'title' property, instead of after.
%
% Revision 1.4  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.3  2003/09/24 20:29:09  michelic
% Added support for operation without a display.
% - Pretend screen is 640x480 for calculations.
% - Don't ask question when closing progbar.
%
% Revision 1.2  2003/06/19 19:11:18  michelich
% Changes made by Francis Favorini.
% Use rectangle instead of patch and to calculations in pixesls to fix
%   overwriting axes (again!).
% Removed use of DEAL for better performance.
%
% Revision 1.1  2002/08/27 22:24:17  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini,  2001/07/11. Got rid of useless line.
%                                Adjusted patch size so it doesn't overwrite axes.
%                                Store handles in UserData instead of using FindObj.
%                                Made some other tweaks, and now it's a little faster.
% Charles Michelich, 2001/04/27. Added color arguments for correct behavior when colordef ~= none
% Francis Favorini,  1998/11/04. Added abort confirmation.
% Francis Favorini,  1998/11/11. Made figure modal.
% Francis Favorini,  1998/10/30. Added auto-expand figure to fit caption.
% Francis Favorini,  1998/10/16.
