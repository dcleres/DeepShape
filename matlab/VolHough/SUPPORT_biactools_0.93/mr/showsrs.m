function figureh=showsrs(srs,cmap)
%SHOWSRS Display MR series in a window with a scroll bar.
%
%   h=showsrs(srs);
%   h=showsrs(srs,cmap);
%
%   srs is a 2, 3, or 4 dimensional series, where the fourth
%     dimension is time.  srs can either be the data array itself
%     or a structure with the data array in the "data" field.
%   cmap is a colormap to use.
%   h is the handle to the figure opened
%
%   If the srs has a time dimension, you can use VCR-like controls
%     to animate the series in this dimension.
%
%   Keyboard controls:
%     7=ToStart, 8=Prev, 9=PgUp
%     4=RevPlay, 5=Stop, 6=Play
%     1=ToEnd,   2=Next, 3=PgDn
%   Note: Numlock must be on if you want to use the numeric keypad.
%
%   Click on a point to display the time series of that point
%     Keyboard controls to move this point:
%        q=UpSlice, w=Up,   e=DownSlice
%        a=Left,    s=Down, d=Right
%
%   Arrow Keys:
%     left arrow = Prev,  right arrow = Next
%     up arrow = UpSlice, down arrow = DownSlice
%
%   Examples:
%   To be prompted for series info: 
%     >>showsrs(readmr);
%   To manually specify series info:
%     >>tsv=readmr('\\broca\data2\study\raw\run01\V*.img',{'Volume',[128,128,12,200]});
%     >>showsrs(tsv);

% Other features:
%
%  These are other features that can be accessed from the command line or within functions & scripts
%
%  showsrs('LinkWinlev',handles) - Link the window and level of several showsrs figures
%       handles - any valid showsrs figure handle
%
%  showsrs('Resize',handle) - Call the resize figure function manually (Useful if you change the 'Position' using set)
%       handle - showsrs figure handle of figure to update.
%

% CVS ID and authorship of this code
% CVSId = '$Id: showsrs.m,v 1.9 2005/02/03 16:58:44 michelich Exp $';
% CVSRevision = '$Revision: 1.9 $';
% CVSDate = '$Date: 2005/02/03 16:58:44 $';
% CVSRCSFile = '$RCSfile: showsrs.m,v $';

%TODO: CHECK EXPONENTIAL FIT ALGORITHM (works fine for pure exponentials, but not well with noise)
%TODO: Add logarithmic and power fit

error(nargchk(1,2,nargin));
error(nargchk(0,1,nargout));

emsg=''; task='';
try
  
  if nargin<2, cmap=gray(256); end
  if ischar(srs), 
    task=srs; 
    if nargin<2
      callbackArg=[];  % Set default callback arg to []
    else
      callbackArg=cmap; 
    end
  end
  
  if ~ischar(srs)
    % This is not a callback.  Initialize the showsrs window.      
    if isempty(srs), emsg='No image specified'; error(emsg); end
    if isstruct(srs) & isfield(srs,'data');
      % Extract image data from data field.
      srs=srs.data;
    end
    if ~isa(srs,'double')
      emsg='Input series must be an array of doubles!'; error(emsg);
    end
    if size(srs,1) <= 1 | size(srs,2) <= 1 | ndims(srs)>4
      emsg='Input series must have 2, 3, or 4 dimensions.'; error(emsg);
    end
    imgs=size(srs,3);     % Number of slices
    timePts=size(srs,4);  % Number of time points
    img=1;						    % Initially display slice 1
    t=1;							    % Initially display time point 1
    
    figure_h = local_initializegui;  % Bring up GUI
    
    % Find the handles objects in the GUI figure
    imgAx_h = findobj(figure_h,'Tag','imgAx');            % Image Axis
    sliceSlider_h = findobj(figure_h,'Tag','Slider');     % Slice slider
    sliceImgNum_h = findobj(figure_h,'Tag','ImgNum');     % Slice number label
    timeSlider_h = findobj(figure_h,'Tag','TimeSlider');  % Time slider
    timePt_h = findobj(figure_h,'Tag','TimePt');          % Time point label
    
    % Setup the contents of the GUI for the current data set
    set(figure_h,'UserData',{srs []})
    if nargout == 1 % Return the figure handle if asked for
      figureh = figure_h;
    end
    colormap(cmap);
    
    % Set up axes limits
    climDefault = minmax(srs); 
    % If the image is flat, tell the user and use a legal clim
    if diff(climDefault) == 0, 
      climDefault(2) = climDefault(1)+1; 
      warning('All voxels in the image(s) have same value!');
    end
    set(imgAx_h,'XLim',[0.5 size(srs,1)+0.5],'YLim',[0.5 size(srs,2)+0.5],'CLim',climDefault);
    
    % Display image
    set(findobj(gca,'Type','image'),'CData',srs(:,:,img)');
    
    % Setup the slice slider and image number display
    if imgs>1
      set(sliceSlider_h,'Min',-imgs,'Max',-1,'Value',-img,'SliderStep',[min(0.999,1/(imgs-1)) max(0.1,min(1,2/(imgs-1)))]);
    else
      set(sliceSlider_h,'Min',-1.001,'Max',-0.999,'Value',-1,'SliderStep',[0 0.001],'Enable','off');
    end
    set(sliceImgNum_h,'String',num2str(img));
    
    % Setup the time slider and image number display
    if timePts>1
      set(timeSlider_h,'Min',1,'Max',timePts,'Value',t,'SliderStep',[min(0.999,1/(timePts-1)) max(0.1,min(1,2/(timePts-1)))]);
    else
      set(timeSlider_h,'Min',0.999,'Max',1.001,'Value',1,'SliderStep',[0 0.001],'Enable','off');
    end
    set(timePt_h,'String',num2str(t));
    
  elseif strcmp(task,'KeyPress')
    % Callback to handle when a key is pressed
    k=get(gcbf,'CurrentCharacter');
    switch k
    case '1', showsrs('ToEnd');
    case {'2',29}, showsrs('Next');  % Right arrow (29) or '2'
    case '3', showsrs('PgDn');
    case '4', showsrs('RevPlay');
    case '5', showsrs('Stop');
    case '6', showsrs('Play');
    case '7', showsrs('ToStart');
    case {'8',28}, showsrs('Prev');  % Left arrow (28) or '8'
    case '9', showsrs('PgUp');
    case {'a','s','d','w','q','e',30,31} % Catch up arrow (30) and down arrow (31)
      % Display the time series for the point in the direction the person pushed.  
      imgFig=gcbf;
      imgAx=findobj(imgFig,'Tag','imgAx');
      pt=findobj(imgAx,'tag','Point');
      imsize=size(cindex(get(imgFig,'UserData'),1)); % Size of images 
      
      % Get current point if one exists otherwise start from center of image
      if isempty(pt)
        x=floor(imsize(1)./2);
        y=floor(imsize(2)./2);
      else
        x=get(pt,'XData');
        y=get(pt,'YData');            
      end
      
      z=str2num(get(findobj(imgFig,'Tag','ImgNum'),'String'));     
      
      % Set new point based on key pressed (Don't move out of image)
      switch k
      case 'w', if y > 1, y=y-1; end            % Move up
      case 's', if y < imsize(2), y=y+1; end    % Move down
      case 'a', if x > 1, x=x-1; end            % Move left
      case 'd', if x < imsize(1), x=x+1; end    % Move right
      case {'q',30}                             % Move up one slice
        showsrs('SliceUp');
        if z > 1, z=z-1; end 
      case {'e',31}                             % Move down one slice
        showsrs('SliceDown');
        if length(imsize)> 2  % If there is only a 2D image, don't check for # of slices
          if z < imsize(3), z=z+1; end	
        end
      end
      
      % Plot the current time series 
      % If the sliceUp or SliceDown keys are pushed, only update the time series if it is already open
      % (so that you can change slices without causing time series window to appear)
      ud=get(gcbf,'UserData');  pltFig=ud{2}; % Get plot figure handle
      if ~any(k==['q','e',30,31]) | (~isempty(pltFig) & ishandle(pltFig))
        local_plottimesrs(gcbf,x,y,z);
      end
    end
  elseif strcmp(task,'Play') | strcmp(task,'RevPlay')
    % Callback to cycle through the images in time (forward or reverse)
    figure(gcbf);
    playButton=findobj(gcbf,'Tag','PlayButton');
    if ~strcmp(task,get(playButton,'UserData'))
      set(playButton,'UserData',task);
      loopBox=findobj(gcbf,'Tag','LoopCheckbox');
      imgNum=findobj(gcbf,'Tag','ImgNum');
      timePt=findobj(gcbf,'Tag','TimePt');
      slider=findobj(gcbf,'Tag','TimeSlider');
      theImage=findobj(gca,'Type','image');
      delayBox=findobj(gcbf,'Tag','DelayBox');
      srs=cindex(get(gcbf,'UserData'),1);
      img=str2num(get(imgNum,'String'));
      t=str2num(get(timePt,'String'));
      timePts=size(srs,4);
      while ismember(get(playButton,'UserData'),{'Play','RevPlay'})
        set(slider,'Value',t);
        set(timePt,'String',num2str(t));
        set(theImage,'CData',srs(:,:,img,t)');
        drawnow;
        if ismember(get(playButton,'UserData'),{'Play','RevPlay'})
          if strcmp(get(playButton,'UserData'),'Play'), step=1; else step=-1; end
          t=t+step;
          if t<1 | t>timePts
            if get(loopBox,'Value')==1
              t=mod(t-1,timePts)+1;
            else
              set(playButton,'UserData','Stop');
            end
          end
          delay=str2num(get(delayBox,'String'));
          t0=clock; while etime(clock,t0)<delay, end
        end
      end   
    end
  elseif strcmp(task,'Stop')
    % Callback to stop cycling through the images in time (forward or reverse)
    set(findobj(gcbf,'Tag','PlayButton'),'UserData','Stop');
    figure(gcbf);
  elseif strcmp(task,'ToStart')
    % Callback to set the current time image to the first image in time
    slider=findobj(gcf,'Tag','TimeSlider');
    set(slider,'Value',get(slider,'Min'));
    showsrs('Slider');
    figure(gcbf);
  elseif strcmp(task,'ToEnd')
    % Callback to set the current time image to the lase image in time
    slider=findobj(gcf,'Tag','TimeSlider');
    set(slider,'Value',get(slider,'Max'));
    showsrs('Slider');
    figure(gcbf);
  elseif strcmp(task,'Prev') | strcmp(task,'PgUp') | strcmp(task,'Next') | strcmp(task,'PgDn')
    % Callback to change the current time point
    slider=findobj(gcf,'Tag','TimeSlider');
    t=get(slider,'Value');
    sMax=get(slider,'Max');
    switch task
    case 'Prev', step=-1;
    case 'PgUp', step=-sMax/10;
    case 'Next', step=1;
    case 'PgDn', step=sMax/10;
    end
    t=t+step;
    if t<1, t=1; elseif t>sMax, t=sMax; end
    set(slider,'Value',t);
    showsrs('Slider');
    figure(gcbf);
  elseif strcmp(task,'SliceUp') | strcmp(task,'SliceDown')
    % Callback to change the current slice
    slider=findobj(gcf,'Tag','Slider');
    z=-get(slider,'Value');
    zMax=-get(slider,'Min');
    switch task
    case 'SliceUp', if z > 1, z=z-1; end
    case 'SliceDown', if z+1 <= zMax, z=z+1; end
    end
    set(slider,'Value',-z);
    showsrs('Slider');
    figure(gcbf);
  elseif strcmp(task,'Delay')
    % Callback to change the current delay when playing movies
    delayBox=findobj(gcf,'Tag','DelayBox');
    set(delayBox,'String',num2str(str2num(get(delayBox,'String'))));
    figure(gcbf);
  elseif strcmp(task,'Slider')
    % Callback to update the image displayed to match the current slider positions
    set(findobj(gcbf,'Tag','PlayButton'),'UserData','Stop');
    % Find out which image to show
    img=round(abs(get(findobj(gcbf,'Tag','Slider'),'Value')));
    set(findobj(gcbf,'Tag','Slider'),'Value',-img);
    set(findobj(gcbf,'Tag','ImgNum'),'String',num2str(img));
    % Find out which time point to show
    t=round(get(findobj(gcbf,'Tag','TimeSlider'),'Value'));
    set(findobj(gcbf,'Tag','TimeSlider'),'Value',t);
    set(findobj(gcbf,'Tag','TimePt'),'String',num2str(t));
    % Show selected image
    srs=cindex(get(gcbf,'UserData'),1);
    set(findobj(gca,'Type','image'),'CData',srs(:,:,img,t)');
    figure(gcbf);
    drawnow;
  elseif strcmp(task,'Click')
    % User clicked on image to show time series plot for that point
    % Create plot figure, if needed
    imgFig=gcbf;
    imgAx=gca;
    
    imsize=size(cindex(get(imgFig,'UserData'),1)); % Size of images 
    
    % Get coords clicked on
    pt=get(imgAx,'CurrentPoint');
    x=round(pt(1,1));
    y=round(pt(1,2));
    z=str2num(get(findobj(imgFig,'Tag','ImgNum'),'String'));
    
    local_plottimesrs(gcbf,x,y,z);	% Plot time series 
  elseif strcmp(task,'LineMenu')
    % Callback when user toggles the any item in the line menu
    
    % Second argument in call to showsrs is the handle for the menu that was toggled
    menu_h = callbackArg;
    
    % Check to make sure that the handle returned is valid
    if ~ishandle(menu_h)
      error('Callback LineMenu was passed an invalid handle for the menu item');
    end
    
    % Find axis in plot
    pltLine= findobj(gcbf,'Tag','timeSrs');
    pltAxes=get(pltLine,'Parent');
    
    % Toggle the menu item and create or delete the appropriate line
    currState = get(menu_h,'Checked');
    if strcmp(currState,'off')
      % Turn on the checkmark on the menu
      set(menu_h,'Checked','on');
      
      % Get the UserData from the current menu item
      % ud{1} = a string function to be evaluated using eval which will update the line 
      % ud{2} = a color for the line
      % ud{3} = a string to be included in the legend
      ud = get(menu_h,'UserData');
      
      % Generate a tag for the line
      tag = 'fitline';  % To distinguish from other lines such as the legend lines
            
      % Create a line for the fit
      %   UserData for line
      %   ud{1} = a string function to be evaluated using eval which will update the line
      %   ud{2} = tag for menu item corresponding to this line
      %   ud{3} = a string to be included in the menu
      lineud = ud;                % Set ud{1} and ud{3} from the menu item ud
      lineud{2} = get(menu_h,'Tag');  % Set ud{2} 
      axes(pltAxes);                                                % Make plot axis current
      line_h=line(get(pltLine,'XData'),get(pltLine,'YData'), ...    % Create a line on the time series figure
        'Tag',tag,'UserData',lineud,'Color',ud{2});                 % Use the time series data as the default
      
    else
      % Turn off the checkmark on the menu
      set(menu_h,'Checked','off');
      
      % Delete the fit line from the axes
      % Find all current lines
      lines_h = findobj(pltAxes,'Type','Line','Tag','fitline');

      % Update all additional lines by evaluating the string in the first cell of UserData of each line
      for n = 1:length(lines_h)
        ud = get(lines_h(n),'UserData');        % Get the UserData from the current line
        if strcmp(ud{2},get(menu_h,'Tag'))      % If the line ud{2} matches the menu item just diabled
          delete(lines_h(n));                   % Delete the line
        end
      end
    end
    
    % Find current plot point
    ud = get(gcbf,'UserData');
    currPt = ud{2};
    
    % Replot time series with new changes
    local_plottimesrs(ud{1},currPt(1),currPt(2),currPt(3)); % Plot the time series again with the changed lines
    
  elseif strcmp(task,'Resize')
    % Resize window 
    local_resizewindow(callbackArg);
    
  elseif strcmp(task,'LinkWinlev')   
    % Link window and level button for all of the passed figure handles 
    %  callbackArg is an array of figure handles to link
    
    % Check to make sure that all handles are valid showsrs handles
    if any(~ishandle(callbackArg)) | any(~strcmp(get(callbackArg,'Tag'),'showsrs()'))
      emsg = 'showsrs(''LinWinlev'',handles) must be valid showsrs figure handles'; error(emsg);
    end
      
    img_h = findobj(callbackArg,'Tag','TheImage');
    if iscell(img_h), img_h=[img_h{:}]; end % Convert cell to numeric array

    % Put the figure handle(s) to update with winlev in UserData to allow linking of multiple showsrs window & levels.
    set(findobj(callbackArg,'Tag','WinlevButton'),'UserData',img_h);
  
  elseif strcmp(task,'CloseRequestFcn')
    % This function handles closing the window.  
    % (1) Relink any showsrs GUI linked to this figure
    % (2) Handle winlevs for this figure
    % (3) Close showsrs window
    %
    
    % Get figure to close.  Don't use gcbf because close function calls the 'CloseRequestFcn' directly
    % instead of as a callback.
    showsrs_h = get(0,'CurrentFigure');  
    try
      % Relink any showsrs GUIs linked (LinkWinlev) to this figure
      linked_image_h = get(findobj(showsrs_h,'Tag','WinlevButton'),'UserData');
      if length(linked_image_h) > 1
        linked_figure_h = getParentFigure(linked_image_h); % Find linked figures 
        linked_figure_h(find(linked_figure_h == showsrs_h)) = [];       % Remove current figure
        showsrs('LinkWinlev',linked_figure_h);             % Relink remaining figures
      end
      
      % Handle any winlev GUIs for this figure
      %   If winlev is for this figure only, close it
      %   If winlev is for this and other figure, reopen new winlev for just other figures.
      winlev_h = iswinlevforfig(showsrs_h);  % Check if this figure has any winlev windows open
      if ~isempty(winlev_h)
        ctr_image_h=iswinlev(winlev_h); % Get the handles of the images controlled by this winlev_h
        
        for winlev_h_n = 1:length(winlev_h)  % Loop through the winlev GUIs
          curr_ctr_image_h = ctr_image_h{winlev_h_n};         % Get current winlev controlled image handles
          curr_ctr_fig_h = getParentFigure(curr_ctr_image_h); % Find out which figure each image is associated with
          if all(curr_ctr_fig_h == showsrs_h)
            % Close the winlev GUI if it is only controlling the current figure
            delete(winlev_h(winlev_h_n));
          else
            % It is controlling this window and others, delete it
            % Open a new winlev gui with remaining handles &
            % put it back where it came from
            pos = get(winlev_h(winlev_h_n),'Position');      % Get current winlev position
            delete(winlev_h(winlev_h_n));                     % Close current winlev 
            curr_ctr_image_h(curr_ctr_fig_h == showsrs_h)=[];  % Remove any images associated with current figure
            newwinlev_h=winlev(curr_ctr_image_h);               % Call winlev
            set(newwinlev_h,'Position',pos);                    % Put the winlev GUI back where it was
          end
        end % End winlev_h loop
      end % End ~isempty(winlev_h)
      
    catch
      % If this fails, issue a warning and continue on to close finish close request function
      warning(sprintf('Unable to Re-''LinkWinLev'' and close winlev GUIs.\nError was:\n%s',lasterr));      
    end
          
    % Close showsrs figure
    delete(showsrs_h);
  else
    % Callback task not understood
    emsg = sprintf('Callback task ''%s'' not understood',task);
    error(emsg)
  end 
  
catch
  % Check for error messages in emsg and lasterr
  if isempty(emsg)
    if isempty(lasterr)
      emsg='An unidentified error occurred!';
    else
      emsg=lasterr;
    end
  end
  if ~isempty(get(0, 'CallbackObject')) ...
      &  all(~strcmp({'Resize','LinkWinlev'},task))...
      & (isempty(gcbf) | ~ishandle(gcbf))
    % Treat this as a user abort if the following coniditions are true:
    % (1) The error was generated during a callback (rather than an error during initialization)
    % (2) The callback was NOT Resize or LinkWinLev
    % (3) The callback figure (i.e. the showsrs window) was closed
    % Note: ~ishandle(gbcf) is necessary for MATLAB 5.3 support ???
    disp('User abort');
  else
    % Otherwise issue error
    error(emsg)
  end
end

%------------------------LOCAL_PLOTTIMESRS------------------------------------------
function local_plottimesrs(imgFig,x,y,z)
% Show time series plot for the point specified
% Create plot figure, if needed
%
% LOCAL_PLOTTIMESRS - Show time series plot for the point specified
%                   - Create plot figure, if needed
%
%   local_plottimesrs(imgFig,x,y,z)
%
%              imgFig = handle for showsrs figure associated with this plot
%              x,y,z  = x,y,z point to plot                 
%
% Charles Michelich,05/31/99.  Original. Moved to local function from main function
% Charles Michelich,04/07/00.  Added imgFig argument to handle callback from plot figure properly
%                              Removed making imgFig current figure when function is called
%                              Added support for trendlines
% Charles Michelich,04/18/00.  Added support for exponential trendlines

% TODO: Add legend for trendlines
% TODO: Implement logarithmic and power fits
% TODO: Handle errors in calculating fits

% Check number of input arguments
error(nargchk(4,4,nargin));

% Find image axis handle
imgAx=findobj(imgFig,'Tag','imgAx');

ud=get(imgFig,'UserData');
tsv=ud{1};
pltFig=ud{2};
if isempty(pltFig) | ~ishandle(pltFig)
  delete(findobj(imgAx,'tag','Point'));
  % Create Point on image showing place clicked
  axes(imgAx)
  line(0,0,'Color','r','LineStyle','none','Marker','s','MarkerEdgeColor','r','MarkerSize',4,'Tag','Point');
  
  % Initialize plot figure (keyPress will make imgFig active)
  pltFig=figure('DoubleBuffer','on','Tag','pltFig',...
    'UserData',{imgFig},'KeyPressFcn','imgFig=get(gcbf,''UserData'');, figure(imgFig{1})');
  colordef(pltFig,'none');  % Set default colors to 'none' scheme for this figure
  pltLine=line(0,0,'Tag','timeSrs','Color','r');		% Create a line on the time series figure
  set(pltLine,'XData',1:size(tsv,4));               % Set XData for line
  
  % Create Stats Text Box
  uicontrol('Parent',pltFig, ...
    'Units','points', ...
    'BackgroundColor',[0.75 0.75 0.75], ...
    'Position',[5 5 200 12], ...
    'String','Mean = ', ...
    'Style','text', ...
    'HorizontalAlignment','left',...
    'Tag','StatsText');
  
  % Create menu for extra calculated lines to add
  % NOTE:  Callback should be showsrs('LineMenu',findobj(gcbf,'Tag','MENUTAG'))
  %            where MENUTAG is the 'Tag' property for this menu
  %            The 'LineMenu' callback handles adding and removing lines.
  % NOTE:  UserData must contain a cell array with the following two cells
  %            ud{1} = a string function to be evaluated using eval which will update the line 
  %            ud{2} = a color for the line
  %            ud{3} = a string to be included in the legend
  %
  linesMenu_h = uimenu('Parent',pltFig, ...
    'Label','&Trend Lines', ...
    'Tag','LinesMenu');
  polyfitMenu_h = uimenu('Parent',linesMenu_h, ...
    'Label','Polynomial Fit', ...
    'Tag','LinearFitMenu');
  uimenu('Parent',polyfitMenu_h, ...
    'Callback','showsrs(''LineMenu'',findobj(gcbf,''Tag'',''polyfit1Menu''))', ...
    'Label','Linear Fit', ...
    'Checked','Off', ...
    'UserData',{'local_polyfitline(lines_h(n),t,srs,1)','b','Linear Fit',}, ...
    'Tag','polyfit1Menu');
  uimenu('Parent',polyfitMenu_h, ...
    'Callback','showsrs(''LineMenu'',findobj(gcbf,''Tag'',''polyfit2Menu''))', ...
    'Label','Quadratic Fit', ...
    'Checked','Off', ...
    'UserData',{'local_polyfitline(lines_h(n),t,srs,2)','g','Quadratic Fit'}, ...
    'Tag','polyfit2Menu');
  uimenu('Parent',polyfitMenu_h, ...
    'Callback','showsrs(''LineMenu'',findobj(gcbf,''Tag'',''polyfit3Menu''))', ...
    'Label','Order 3 Polynomial fit', ...
    'Checked','Off', ...
    'UserData',{'local_polyfitline(lines_h(n),t,srs,3)','y','Order 3 Polynomial fit'}, ...
    'Tag','polyfit3Menu');
  uimenu('Parent',polyfitMenu_h, ...
    'Callback','showsrs(''LineMenu'',findobj(gcbf,''Tag'',''polyfit4Menu''))', ...
    'Label','Order 4 Polynomial fit', ...
    'Checked','Off', ...
    'UserData',{'local_polyfitline(lines_h(n),t,srs,4)','c','Order 4 Polynomial Fit'}, ...
    'Tag','polyfit4Menu');
%  uimenu('Parent',polyfitMenu_h, ...
%    'Callback','showsrs(''LineMenu'',findobj(gcbf,''Tag'',''polyfit20Menu''))', ...
%    'Label','Order 20 Polynomial fit', ...
%    'Checked','Off', ...
%    'UserData',{'local_polyfitline(lines_h(n),t,srs,20)','c','Order 20 Polynomial Fit'}, ...
%    'Tag','polyfit20Menu');
  uimenu('Parent',linesMenu_h, ...
    'Callback','showsrs(''LineMenu'',findobj(gcbf,''Tag'',''expFitMenu''))', ...
    'Label','Exponential Fit', ...
    'Checked','Off', ...
    'UserData',{'local_expfitline(lines_h(n),t,srs)','m','Exponential Fit'}, ...
    'Tag','expFitMenu');
%  uimenu('Parent',linesMenu_h, ...
%    'Callback','disp(''Not Implemented Yet!'')', ...
%    'Label','Logarithmic Fit', ...
%    'Checked','Off', ...
%    'Tag','logFitMenu');
%  uimenu('Parent',linesMenu_h, ...
%    'Callback','disp(''Not Implemented Yet!'')', ...
%    'Label','Power Fit', ...
%    'Checked','Off', ...
%    'Tag','powerFitMenu');
  
  % Store plot figure handle
  ud{2}=pltFig;
  set(imgFig,'UserData',ud);
end

% Show point clicked
pt=findobj(imgAx,'Tag','Point');
set(pt,'XData',x,'YData',y);

% Find handles of time series line
pltLine=findobj(pltFig,'Tag','timeSrs');	% Find handle for line and axes
pltAxes=get(pltLine,'Parent');

% Extract current series to plot
srs = squeeze(tsv(x,y,z,:))';
t = get(pltLine,'XData');						% Get XData for line

% Display the Mean and Std
statsText_h=findobj(pltFig,'Tag','StatsText');
set(statsText_h,'String',sprintf('Mean = %0.5g     Std = %0.4g     Mean/Std = %0.4g',mean(srs),std(srs),mean(srs)./std(srs)));

%Update time series plot
set(pltLine,'YData',srs);
set(get(pltAxes,'title'),'String',sprintf('(%d,%d,%d)',x,y,z));

% Find all current fit lines
lines_h = findobj(pltAxes,'Type','Line','Tag','fitline');

% Update lines and add legend, if any fit lines are selected
if ~isempty(lines_h)
  % Update all additional lines by evaluating the string in the first cell of UserData of each line
  for n = 1:length(lines_h)
    % Get the UserData from the current line
    ud = get(lines_h(n),'UserData');
    
    % Evaluate function
    eval(ud{1});
  end
  
  % Generate a legend based on the contents of the UserData of each line
  legendLabel=cell(length(lines_h)+1,1);
  legendLabel{1} = 'Data';
  for n = 1:length(lines_h)
    ud = get(lines_h(n),'UserData'); % Get ther UserData from the current line
    legendLabel{n+1}=ud{3};          % Get legend label
  end
  
  % Place legend where it will least interfere with the data (last argument=0)
  legend(pltAxes,cat(1,pltLine,lines_h),legendLabel,0);  
else
  % If no fit lines are selected, turn off the legend.
  legend(pltAxes,'off');
end

% Get UserData from plot figure
% ud(1) = handle for showSrs figure
% ud(2) = vector of current point displayed [x,y,z]
plotUserData = get(pltFig,'UserData');

% Update UserData of figure to reflect new time point
plotUserData(2) = {[x,y,z]};
set(pltFig,'UserData',plotUserData);

%------------------------LOCAL_POLYFITLINE------------------------------------------
function YData = local_polyfitline(h,x,y,order)
% LOCAL_POLYFITLINE - This function calculates the polynomial fit line of order n
%
%   local_polyfitline(srs,order)
%
%        h = handle of line to update
%        x,y = vector of x & y data to polyfit
%        order = order of fit
%        YData = fit line

% Calculate the polynomial coefficients
polycoeff=polyfit(x,y,order);

% Calculate the fit line
powmat = (repmat([length(polycoeff)-1:-1:0]',[1,length(x)]));
xpow = (repmat(x,[length(polycoeff),1]).^powmat)';

% Update line on figure
set(h,'YData',xpow*polycoeff');

%------------------------LOCAL_EXPFITLINE------------------------------------------
function YData = local_expfitline(h,x,y)
% LOCAL_EXPFITLINE - This function calculates the exponential fit line
%
%   local_expfitline(srs,x,y)
%
%        h = handle of line to update
%        x,y = vector of x & y data to polyfit
%        order = order of fit
%        YData = fit line

% y=k1*exp(k2*x)      
% ln(y)=ln(k1)+k2*x
% y=mx+b ====>  k2 = m; k1 = exp(b)
% yfit = exp(b)*exp(m*x) = exp(b+mx);

% Calculate the polynomial coefficients
polycoeff=polyfit(x,log(y),1);

% Calculate the fit line
yfit = exp(polycoeff(2)+polycoeff(1).*x);

% Update line on figure
set(h,'YData',yfit);

% Put formula in legend (String copied from ud{3})
ud=get(h,'UserData');
ud{3} = sprintf('Exponetial fit: y = %4.4g exp(x/%4.4g)',exp(polycoeff(2)),1./polycoeff(1));
set(h,'UserData',ud);

%-----------------LOCAL_INITALIZEGUI------------------------
function figure_h = local_initializegui
% LOCAL_INITIALIZEGUI - Initialize showsrs GUI
%
% Brings up showsrs figure and returns figure handle
%
% NOTE: Important resizing information stored in 'UserData' of image axes
%
% Charles Michelich, 2001/07/05, moved from main function
%                                Changed to 'Characters' units for cross platform compatibility
%                                Moved W&L button to left side of slider.

% Get relationship between Character and Pixel Units
oldRootUnits=get(0,'Units');
set(0,'Units','pixels');
scrPixels=get(0,'ScreenSize');
set(0,'Units','Characters');
scrChars=get(0,'ScreenSize');
set(0,'Units',oldRootUnits);
pixs2char=scrPixels(3:4)./scrChars(3:4);
width2height = pixs2char(1)/pixs2char(2);
height2width = 1/width2height;

% GUI dimension constants
marginHeight = 0.8; % Margin Height 
marginWidth = marginHeight*height2width;  % Margin Width (Make it the same as the margin height)
sliderOffsetHeight = 0.8;  % Distance between slider and image (height)
sliderOffsetWidth = sliderOffsetHeight*height2width;  % Distance between slider and image (width)
elementMarginWidth = 1; % Distance between control elements (width)
elementMarginHeight = elementMarginWidth*width2height; % Distance between control elements (height)

% Horizontal control elements
vcrButtonWidth = 4;    % Width of VCR Button
winlevButtonWidth = 6; % Window and Level button width
loopBoxWidth = 10;      % Width of loop checkbox and label
loopTimeWidth = 5;     % Width of loop time edit box
timePtWidth = 4;       % Width of time point label
horControlHeight = vcrButtonWidth*width2height;  % Height of horizontal controls (Make square VCR controls)
tSliderWidth = 60;     % Width of time slider (VARIABLE WITH WINDOW RESIZE)

% Vertical control elements
imgNumHeight = horControlHeight; % Slice number label height (Make it the same as the horizontal buttons)
verControlWidth = timePtWidth;   % Width of vertical control (Make it the same as the time points label)
% Slice slider height is calculated (VARIABLE WITH WINDOW RESIZE)

% Create the axes and show first image
axesWidth = vcrButtonWidth*5 + elementMarginWidth + loopBoxWidth + elementMarginWidth + loopTimeWidth + ...
  elementMarginWidth + winlevButtonWidth + elementMarginWidth + timePtWidth + tSliderWidth;
axesHeight = axesWidth*width2height;

% Create Figure (in middle of screen)
pos=[0,0,marginWidth*2+sliderOffsetWidth+axesWidth+verControlWidth, ...
    marginHeight*2+sliderOffsetHeight+axesHeight+horControlHeight];
pos(1:2)=[(scrChars(3)-pos(3))/2 (scrChars(4)-pos(4))/2];
figure_h=figure('Units','Characters','Position',pos,'DefaultUIControlInterruptible','Off',...
  'DoubleBuffer','on','KeyPressFcn','showsrs(''KeyPress'');','Tag','showsrs()', ...
  'CloseRequestFcn','showsrs(''CloseRequestFcn'')');

% Create Axes for image
axesPos=[marginWidth, marginHeight+horControlHeight+sliderOffsetHeight, axesWidth, axesHeight];
imgAx_h=axes('Units','Characters','Position',axesPos,'Visible','off','YDir','reverse',...
  'XTick',[],'YTick',[],'NextPlot','Add','Layer','top','Tag','imgAx');

% Create image on axes
img_h=image(zeros(64,64),'CDataMapping','Scaled','EraseMode','None','ButtonDownFcn','showsrs(''Click'');', ...
  'Tag','TheImage');    

% Set DataAspectRatio of axis image is in (Parent of the image handle)
set(get(img_h,'Parent'),'DataAspectRatio',[1 1 1]);

% Add the VCR buttons
uicontrol('Units','Characters','Style','PushButton','String','|<',...
  'Position',[marginWidth marginHeight vcrButtonWidth horControlHeight],...
  'Tag','ToStartButton','ToolTipString','To First Image','CallBack','showsrs(''ToStart'');');
uicontrol('Units','Characters','Style','PushButton','String','<',...
  'Position',[marginWidth+vcrButtonWidth marginHeight vcrButtonWidth horControlHeight],...
  'Tag','RevPlayButton','ToolTipString','Reverse Play',...
  'CallBack','showsrs(''RevPlay'');','Interruptible','On');
uicontrol('Units','Characters','Style','PushButton','String','[]',...
  'Position',[marginWidth+vcrButtonWidth*2 marginHeight vcrButtonWidth horControlHeight],...
  'Tag','StopButton','ToolTipString','Stop','CallBack','showsrs(''Stop'');');
uicontrol('Units','Characters','Style','PushButton','String','>',...
  'Position',[marginWidth+vcrButtonWidth*3 marginHeight vcrButtonWidth horControlHeight],...
  'Tag','PlayButton','ToolTipString','Play','UserData','stop',...
  'CallBack','showsrs(''Play'');','Interruptible','On');
uicontrol('Units','Characters','Style','PushButton','String','>|',...
  'Position',[marginWidth+vcrButtonWidth*4 marginHeight vcrButtonWidth horControlHeight],...
  'Tag','ToEndButton','ToolTipString','To Last Image','CallBack','showsrs(''ToEnd'');');
uicontrol('Units','Characters','Style','Checkbox','String','Loop',...
  'Position',[marginWidth+vcrButtonWidth*5+elementMarginWidth marginHeight loopBoxWidth horControlHeight],...
  'Tag','LoopCheckbox','ToolTipString','Loop around at ends during playback','Value',1,'CallBack','figure(gcbf);');
uicontrol('Units','Characters','Style','Edit','String','0.0',...
  'Position',[marginWidth+vcrButtonWidth*5+2*elementMarginWidth+loopBoxWidth marginHeight loopTimeWidth horControlHeight],...
  'FontName','Arial Narrow','HorizontalAlignment','Left',...
  'Tag','DelayBox','ToolTipString','Interframe delay in seconds during playback','CallBack','showsrs(''Delay'');');

% Add Window and Level Button
% 
% Put the figure handle(s) to update with winlev in UserData to allow linking of multiple showsrs window & levels.
pos=get(findobj(figure_h,'Tag','DelayBox'),'Position');
pos=[pos(1)+pos(3)+elementMarginWidth, pos(2), winlevButtonWidth, pos(4)];
%pos=[posTimeSlider(1)+posTimeSlider(3)+3, posSlider(2)-imgNumHeight-3, 22, imgNumHeight];
uicontrol('Units','Characters','Style','pushbutton','String','W+L','Position',pos,... %'FontName','Arial Narrow', ...
  'Tag','WinlevButton','ToolTipString','Window and level the image', ...
  'UserData',img_h, ...
  'Callback','winlev(get(findobj(gcbf,''Tag'',''WinlevButton''),''UserData''))');

% Add the time slider and image number display
pos=[pos(1)+pos(3)+elementMarginWidth, pos(2), timePtWidth, horControlHeight];
uicontrol('Style','Text','FontName','Arial Narrow','Tag','TimePt',...
  'Units','Characters','Position',pos,'ToolTipString','Currently displayed time point');
pos=[pos(1)+pos(3), pos(2), axesWidth+marginWidth-pos(1)-pos(3), pos(4)];
uicontrol('Style','Slider','Tag','TimeSlider',...
  'Units','Characters','Position',pos,...
  'ToolTipString','Time point selection slider','CallBack','showsrs(''Slider'');');

% Add the slice slider and image number display
pos=[axesPos(1)+axesPos(3)+sliderOffsetWidth, axesPos(2), verControlWidth, axesHeight-imgNumHeight];
uicontrol('Style','Slider','Tag','Slider',...
  'Units','Characters','Position',pos,...
  'ToolTipString','Slice selection slider','CallBack','showsrs(''Slider'');');
pos=[pos(1), pos(2)+pos(4), verControlWidth, imgNumHeight];
uicontrol('Style','Text','FontName','Arial Narrow','Tag','ImgNum',...
  'Units','Characters','Position',pos,'ToolTipString','Currently displayed slice');

% Find figure size minimums
% Note: Pad minimums by 15 (width character units) so that the sliders are still accessable
pos=get(findobj(figure_h,'Tag','TimeSlider'),'Position');
minFigureWidth = pos(1)+15;
minFigureHeight = marginHeight*2+sliderOffsetHeight+horControlHeight+15*width2height;

% Store resizing information in axes UserData
resizeInfo = struct('marginWidth',marginWidth,'marginHeight',marginHeight, ...
  'sliderOffsetWidth',sliderOffsetWidth,'sliderOffsetHeight',sliderOffsetHeight, ...
  'verControlWidth',verControlWidth,'horControlHeight',horControlHeight, ...
  'minFigureWidth',minFigureWidth,'minFigureHeight',minFigureHeight, ...
  'width2height',width2height,'height2width',height2width);

set(imgAx_h,'UserData',resizeInfo);

% Set resize function for figure now that the 'UserData' necessary for the resize has been stored
set(figure_h,'ResizeFcn','showsrs(''Resize'',gcbf)');

%------------------------LOCAL_RESIZEWINDOW----------------------------------------
function local_resizewindow(figure_h)
% LOCAL_RESIZEWINDOW - This function resizes the window
%
%   local_resizewindow(figure_h)
%
%   figure_h is the handle of the showsrs figure to resize
%   Resizes function expands axes and sliders to fill resized window.
%   The dataAspectRatio property keeps the proper aspect ratio for the image displayed.
%   The figure will not shrink past minimum lengths defined by the GUI elements and a
%   minimum length specified for each of the sliders.
%
%   Note: Due to the implementation of figure position in MATLAB, when the minimum
%      figure size is reached, the figure may move around.  This is because there
%      is not a method to determine which edge/corner is being resized to properly
%      set the window size.  
%
% Charles Michelich, 2001/07/05, original
% Charles Michelich, 2001/09/13, pass figure handle as a variable (to all non-callback function calls)
%

% GUI constants

% Find the handles for each of the objects in the figure
imgAx_h = findobj(figure_h,'Tag','imgAx');            % Image Axis
sliceSlider_h = findobj(figure_h,'Tag','Slider');     % Slice slider
sliceImgNum_h = findobj(figure_h,'Tag','ImgNum');     % Slice number label
timeSlider_h = findobj(figure_h,'Tag','TimeSlider');  % Time slider
timePt_h = findobj(figure_h,'Tag','TimePt');      % Time point label

% Get the resizing information from the 'UserData' of the image axes
resizeInfo = get(imgAx_h,'UserData');

% Get the new size of the figure
figure_pos = get(figure_h,'Position');

% Check that minimum has not been exceeded
% TODO: MAKE SURE IT DOES NOT GO OFF THE SCREEN!!!!!
if figure_pos(3) < resizeInfo.minFigureWidth | figure_pos(4) < resizeInfo.minFigureHeight
  if figure_pos(3) < resizeInfo.minFigureWidth
    figure_pos(3) = resizeInfo.minFigureWidth; 
  end
  if figure_pos(4) < resizeInfo.minFigureHeight
    figure_pos(2) = figure_pos(2)+figure_pos(4)-resizeInfo.minFigureHeight; % Do not move window if resizing from bottom edge
    figure_pos(4) = resizeInfo.minFigureHeight;
  end
  set(figure_h,'Position',figure_pos); % Only set once so that window doesn't jitter when both minimums reached
end

%--- Set the axes to the new width and height ---
axes_pos = get(imgAx_h,'Position');

% Calculate maximum position
axes_pos(3) = figure_pos(3)- (resizeInfo.marginWidth*2 + ...
  resizeInfo.sliderOffsetWidth+resizeInfo.verControlWidth);
axes_pos(4) = figure_pos(4)- (resizeInfo.marginHeight*2+ ...
  resizeInfo.sliderOffsetHeight+resizeInfo.horControlHeight);

% Force the axes square (NEED TO ADD MIN SIZE CHECK HERE AGAIN FOR THIS TO WORK)
%if axes_pos(3)*resizeInfo.width2height > axes_pos(4)
%  axes_pos(3) = axes_pos(4)*resizeInfo.height2width;
%  figure_pos(3) = resizeInfo.marginWidth*2+resizeInfo.sliderOffsetWidth+...
%    axes_pos(3)+resizeInfo.verControlWidth;
%else
%  axes_pos(4) = axes_pos(3)*resizeInfo.width2height;
%  figure_pos(4) = resizeInfo.marginHeight*2+resizeInfo.sliderOffsetHeight+...
%    axes_pos(4)+resizeInfo.horControlHeight;
%end
%set(figure_h,'Position',figure_pos); % Set new position

% Set results
set(imgAx_h,'Position',axes_pos);

%--- Set the time slider to the proper width (no height changes) ---
timePt_pos = get(timePt_h,'Position');
timeSlider_pos = get(timeSlider_h,'Position');
timeSlider_pos(3) = (axes_pos(1) + axes_pos(3)) - (timePt_pos(1)+timePt_pos(3));
set(timeSlider_h,'Position',timeSlider_pos);

%--- Set the slice slider and label to the proper height and position ---
sliceSlider_pos = get(sliceSlider_h,'Position');
sliceImgNum_pos = get(sliceImgNum_h,'Position');

% Set horizontal positions
sliceSlider_pos(1) = timeSlider_pos(1)+timeSlider_pos(3)+resizeInfo.sliderOffsetWidth;
sliceImgNum_pos(1) = sliceSlider_pos(1);

% Set slice slider height
sliceSlider_pos(4) = axes_pos(4) - sliceImgNum_pos(4);

% Set slice label vertical position
sliceImgNum_pos(2) = axes_pos(2)+sliceSlider_pos(4);

% Set results
set(sliceSlider_h,'Position',sliceSlider_pos);
set(sliceImgNum_h,'Position',sliceImgNum_pos);

%------------------------GETPARENTFIGURE----------------------------------
function fig = getParentFigure(handle)
% getParentFigure - return the parent figure for the passed handle
%
%   fig=getParentFigure(handle)
%
%   Returns the parents figure for the specified handle(s)
%
% Charles Michelich, 2001/09/21, copied from guidata.m
%                                modified to handle a vector of handles & added error checking

% Make sure that input are valid, non-root handles
if any(~ishandle(handle(:))) | any(handle(:) == 0)
  emsg = 'getParentFigure requires valid handles other than root handle'; error(emsg)
end

% Loop through each handle passed
fig = handle;  % Start with handles passed;
for n = 1:length(handle(:))
  % if the object is a figure or figure descendent, return the
  % figure.  Otherwise return [].
  while ~isempty(fig(n)) & ~strcmp('figure', get(fig(n),'type'))
    fig(n) = get(fig(n),'parent');
  end
end

% Modification History:
%
% $Log: showsrs.m,v $
% Revision 1.9  2005/02/03 16:58:44  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.8  2004/02/12 20:54:57  michelich
% Added Mean/Std to time series plot stats.
%
% Revision 1.7  2003/10/22 15:54:39  gadde
% Make some CVS info accessible through variables
%
% Revision 1.6  2003/10/15 15:43:33  michelich
% Updated help to use new readmr.
%
% Revision 1.5  2003/07/01 19:23:30  michelich
% Updated example for new readmr function.
%
% Revision 1.4  2003/04/18 15:51:52  michelich
% Change numbering of X-axis time series plot to start at one to match the
%   time series numbering in the main window.
%
% Revision 1.3  2002/12/20 19:38:55  michelich
% Extract images from data field of input
%
% Revision 1.2  2002/09/05 15:13:07  michelich
% Mapped arrow keys to next, previous, sliceup, and slicedown.
% Added check that a callback is executing in 'User Abort' catch.
% Added check to handle images where all voxels are equal.
% Added better error message when isempty(srs).
%
% Revision 1.1  2002/08/27 22:24:25  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2001/10/24. Changed behavior of 'q' and 'w' (sliceUp and sliceDown) so that they do not open a new time series window
% Charles Michelich, 2001/09/27. Updated case of readtsv in comments
% Charles Michelich, 2001/09/21. Added 'TheImage' tag to the image object. (to make searching for image easier)
%                                Changed 'LinkWinlev' to store image handles instead of image axis handles (to support winlev fix)
%                                Changed 'CloseRequestFcn' to use delete to destroy winlev GUI to avoid recursive during 'close all'.
% Charles Michelich, 2001/09/21. Added CloseRequestFcn to handle closing & relinking W&L GUIs
%                                Added error when callback task is not recognized.
%                                Changed initialization of winlev button userdata to imgAx_h instead of figure_h
% Charles Michelich, 2001/09/14. Added ability to link the Window & Level for multiple showsrs using showsrs('LinkWinlev',figures2link)
%                                Added tag to showsrs figure ('showsrs()') to allow easy identification of showsrs figures.
%                                Changed catch to properly handle non-callback showsrs calls to 'LinkWinlev' and 'Resize'
%                                Added documentation for 'LinkWinlev' and 'Resize' to below help comments
% Charles Michelich, 2001/09/13. Changed default callback argument to []
%                                Added ability to call showsrs('Resize',handle) directly (instead of just as a callback) to 
%                                update the window after a set(h,'Position',pos) resize.  The showsrs figure handle is passed 
%                                in second argument.
% Charles Michelich, 2001/08/13. Remove legend when no fit lines are selected.
% Charles Michelich, 2001/08/10. Fixed return of figure handle (incorrect variable assigned to figureh)
% Charles Michelich, 2001/07/20. Moved setting figure resizeFcn to after the figure UserData is set (UserData needed for resize)
%                                (in MATLAB 6.1 resize was being called when the first VCR control was created generating an error)
% Charles Michelich, 2001/07/06. Fixed Bug in SliceDown function (would allow slice to change with keyboard for only one slice)
%                                Disabled slice and time sliders for only one image (SliderStep "disable" does not work in Linux)
%                                Set colordef of time series plot to none (to match color settings on BIAC computers)
%                                Added legend to time series plot
% Charles Michelich, 2001/07/05. Moved creating GUI to a local function
%                                Implemented custom resize function to allow proper resizing of the GUI
% Charles Michelich, 2001/07/05. Changed function name to lowercase.
%                                Updated comments
% Charles Michelich, 2000/08/09. Added returning figure handle (if asked for)
%                                Added nargout check
% Charles Michelich, 2000/04/18. Added support for exponential trendlines.
% Charles Michelich, 2000/04/07. Added support to send second argument to callback functions
%                                Added support for trendlines plot lines.
% Francis Favorini,  2000/03/31. Changed to set DataAspectRatio and allow MATLAB to calculate PlotBoxAspectRatio.
% Charles Michelich, 2000/03/26. Fixed check for less than two dimensions (ndims never returns below 2 dimensions)
%                                Fixed catch to correctly display error that occur before the figure is initialized
% Charles Michelich, 2000/03/25. Added support for non-square images by setting aspect ratio of image axis.
% Charles Michelich, 1999/11/12. Added a window and level button - There may be a better location for it
% Charles Michelich, 1999/11/11. Added keyPress callback to pltFig to switch to imgFig when key pressed
% Charles Michelich, 1999/09/03. Set XData for display of time series in plot initialization
%                                This allows the user to change the XData to desired vector and
%                                have the changes remain when another voxel is clicked.
%                                (i.e. change the scale on the graph) It also speeds up refresh.
%                                Added a Mean and Standard Deviation text box to time series figure
% Charles Michelich, 1999/05/31. Created local_plottimesrs function to plot time series on click
%                                Added ability to move displayed point using a,s,d,q,w,e
%                                Added tag 'ImgAx' to the image axes
%                                Added 'SliceUp' and 'SliceDown' tasks 
%                                Changed local_plottimesrs to use 'set' instead of 'plot' & 'title'
%                                to avoid an error when rapidly pressing the key.
% Francis Favorini,  1999/05/21. Call showsrs not showsrs2 on click.
% Francis Favorini,  1999/05/05. Added voxel time series plot when user clicks on a voxel.
% Francis Favorini,  1999/04/20. Minor mods.
% Francis Favorini,  1998/12/09. Added separate slider for time.
% Francis Favorini,  1998/12/08. Added movie playing with VCR style controls.
% Francis Favorini,  1998/11/19. Enlarged image to 512.
%                                Now creates new figure centered on screen.
% Francis Favorini,  1998/06/09. Added cmap param.
% Francis Favorini,  1998/02/03. Fixed bug in SliderStep usage.
% Francis Favorini,  1997/03/21.
