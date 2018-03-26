function figureh=showsrs2(varargin)
%SHOWSRS2 Display MR series in a window with a scroll bar.
%
%   % Display with overlays
%   h=showsrs2(baseSrs,overlaySrs, ...);  % Uses default configuration.
%   h=showsrs2(baseSrs,baseCfg,overlaySrs,overlayCfg, ...);
%
%   % Display just a base image
%   h=showsrs2(baseSrs,baseCfg);
%   h=showsrs2(baseSrs);          % Uses default baseCfg
%
%   baseSrs is a 2, 3, or 4 dimensional series, where the fourth
%     dimension is time.  Base series for overlays
%   baseCfg is a structure containing the fields (optional)
%       baseCfg.cmap is the colormap (default gray(256))
%       baseCfg.cmapLim is a vector containing the upper and lower 
%         clipping limits for the base image (default minmax(baseSrs))
%       baseCfg.voxelSize is a vector containing the voxel size of the baseSrs [mm]
%       baseCfg.slicePlane is the slice plane of the input series ('Axial','Coronal','Sagittal').
%       baseCfg.showTimePlot is a 0 or 1 indicating if the base image should
%         be shown on the time series (4th dimension) plot (default 1 if
%         there are no overlays, otherwise 0) 
%   overlaySrs is a 2, 3, or 4 dimensional series, where the fourth
%     dimension is time.  Overlay this series on the base series.
%   overlayCfg is a structure containing the fields (optional)
%     overlayCfg.cmap is the colormap 
%       default: first overlay = redpos(256)
%                second overlay = blupos(256)
%                third overlay = greengrad(256,0.5,1.0)
%                additional overlays = redpos(256)
%     overlayCfg.cmapLim is a vector containing the upper and lower 
%       clipping limits for the overlay image (default [3.6 8.0])
%     overlayCfg.transLim is the cutoff for transparency (default overlayCfg.cmapLim(1))
%         (overlaySrs < translim is transparent)
%     overlayCfg.transLevel is the amount of transparency (default 1.0)
%         (0 is translucent, 1 is opaque)
%     overlayCfg.showTimePlot is a 0 or 1 indicating if this overlay should
%       be shown on the time series (4th dimension) plot (default 1)
%
%   Multiple overlays can be added by passing additional overlaySrs.
%     Additional overlays stack in the order passed such that the last 
%     overlay passed in on top.  Optional overlayCfg structures are
%     applied to the image immediately preceeding the overlayCfg.  If not
%     specified, the default configuration is used.
%
%   h is the handle to the figure opened
%
%   Note: baseSrs and overlaySrs can either be the data array itself or a
%         structure with the data array in the "data" field.
%
%   If the baseSrs or overlaySrs has a 4th dimension, you can use 
%     VCR-like controls to animate the series in this dimension.
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
%   Pressing "m" displays the coordinates of the current point in the
%   MATLAB command window.
%
%   The spatial cursors of two or more showsrs2 figures with can be linked
%   using the following:
%     showsrs2('LinkCursors', figuresToLink)
%       figuresToLink - vector of 2 or more showsrs2 figure handles to link
%
%   Class Support:
%     baseSrs and overlaySrs may be any non-sparse, numeric array.
%
%   Examples:
%     >> baseSrs = readmr;
%     >> baseCfg.cmapLim = [200 1000];
%     >> overlaySrs = readmr;
%     >> showsrs2(baseSrs,baseCfg,overlaySrs);
%     OR 
%     >> showsrs2(baseSrs,overlaySrs,-overlaySrs); % To show pos and neg overlays
%     OR 
%     >> showsrs2(baseSrs,struct('cmapLim',[200 1000],'cmap',gray(256)), ...
%          overlaySrs,struct('cmapLim',[3.6 8.0],'cmap',redpos(256),'transLim',3.6));

% Other features:
%
%  These are other features that can be accessed from the command line or within functions & scripts
%
%  showsrs2('Resize_Callback',handle) - Call the resize figure function manually (Useful if you change the 'Position' using set)
%       handle - showsrs2 figure handle of figure to update.
%
%  showsrs2('Refresh_Callback',handle) - Refresh the image on the display.
%       handle - showsrs2 figure handle of figure to update.
%
%  showsrs2('RefreshPlotTimeSrs_Callback',handle) - Refresh the time series plot manually using 
%                                                   (Allows refreshing the time series plot from an external function)
%       handle - showsrs2 figure handle of figure to update.

% CVS ID and authorship of this code
% CVSId = '$Id: showsrs2.m,v 1.99 2005/08/09 17:45:33 gadde Exp $';
% CVSRevision = '$Revision: 1.99 $';
% CVSDate = '$Date: 2005/08/09 17:45:33 $';
% CVSRCSFile = '$RCSfile: showsrs2.m,v $';

%TODO: Fix interruptibility for Play callback.  currently cannot stop a Play callback initiated with keyboard

if nargout > 1, error('Too many output arguments.'); end

externalTasks = {'LinkCursors'};  % Tasks that bypass normal callback argument parsing code
emsg=''; task='';
try
  if nargin == 0 
    % Load a base image by default
    base = readmr;
    if isempty(base) % Just exit if user cancelled.
      if nargout == 1, figureh = []; end
      return;
    end
    
    % Load overlays if requested
    overlays = {};
    quest = 'Load an overlay?';
    while 1
      % Check if user want to load an overlay
      if strcmp(questdlg(quest,'Load an overlay','Yes','No','No'),'No')
        break;
      end
      
      % Read an overlay
      overlays{end+1} = readmr;
      
      % If readmr cancelled, assume that they are done.
      if isempty(overlays{end}),
        overlays(end) = []; % Remove last entry
        break;
      end
      
      % Set new question string for additional overlays.
      quest = 'Load another overlay?';
    end        
     
    % Open a showsrs2 window
    h = showsrs2(base,overlays{:});
    
    % Return the figure handle if asked for
    if nargout == 1, figureh = h; end
    
  elseif ~ischar(varargin{1})  % LAUNCH GUI
    % Warn user if using MATLAB before 6.0
    if str2double(strtok(strtok(version),'.')) < 6
      waitfor(warndlg('showsrs2 has not been tested with versions of MATLAB before 6.0 (R12).  Use with caution!', ...
        'Not tested','modal'));
    end
    
    % Should higher bit depth be required to avoid dithering?
    % - 24-bits are necessary for truecolor images to display without color dithering
    % - 32-bit depths use 8-bits to store transparency data (alpha channel)
    % TODO: Check transparency with 24-bit display.
    
    % If the user passes a single empty argument, return with no error.
    % (i.e. showsrs2(readmr) when user cancels)
    if nargin==1 & isempty(varargin{1}), if nargout == 1, figureh = []; end, return; end
        
    % Parse inputs for error checking and to handle defaults
    [baseInfo,overlayInfo,otherInfo]=local_parseInputs(varargin{:});
    
    % Initialize the showsrs2 figure
    handles = local_initializegui; % Bring up GUI and generate & store handles structure.
        
    if isempty(overlayInfo)
      % Disable the Transparency configuration menu when there are no overlays.
      set(handles.showsrs2_cfgtransMenu,'Enable','off');
      % Turn off use image colormap the time series colors menu
      set(handles.UseImageColorsMenu,'Checked','Off');
    end
    
    % Get number of slices and time points and initialize current value
    imgs=size(baseInfo.srs,3);              % Number of slices
    timePts(1) = size(baseInfo.srs,4);      % Determine number of time points in base & each overlay
    for n = 1:length(overlayInfo)
      timePts(n+1) = size(overlayInfo(n).srs,4);
    end
    maxTimePts=max(timePts);                % Determine maximum number of time points
    slice=1;  				                      % Initially display slice 1
    t=1;							                      % Initially display time point 1 (must be valid index for base and overlay (i.e. 1)
    
    % Setup the slice slider and image number display
    if imgs>1
      set(handles.Slider,'Min',-imgs,'Max',-1,'Value',-slice,'SliderStep',[min(0.999,1/(imgs-1)) max(0.1,min(1,2/(imgs-1)))]);
    else
      set(handles.Slider,'Min',-1.001,'Max',-0.999,'Value',-1,'SliderStep',[0 0.001],'Enable','off');
    end
    set(handles.ImgNum,'String',num2str(slice));
    
    % Setup the time slider and image number display
    if maxTimePts>1
      set(handles.TimeSlider,'Min',1,'Max',maxTimePts,'Value',t,'SliderStep',[min(0.999,1/(maxTimePts-1)) max(0.1,min(1,2/(maxTimePts-1)))]);
    else
      set(handles.TimeSlider,'Min',0.999,'Max',1.001,'Value',1,'SliderStep',[0 0.001],'Enable','off');
      set([handles.ToStartButton,handles.RevPlayButton,handles.StopButton,handles.PlayButton, ...
          handles.ToEndButton,handles.LoopCheckbox,handles.DelayBox],'Enable','off');
    end
    set(handles.TimePt,'String',num2str(t));
    
    % Set up axes limits
    set(handles.imgAx,'XLim',[0.5 size(baseInfo.srs,1)+0.5],'YLim',[0.5 size(baseInfo.srs,2)+0.5]);
    
    % Initialize the histogram information to [] (showsrs2_cfg will calculate them when needed)
    %   The histogram is stored in with the image userdata for so that it does not need to be 
    %   calculated several times (for increase performance when switching between images to configure
    baseInfo.histCount = [];
    baseInfo.histBins = [];
    for n = 1:length(overlayInfo)
      overlayInfo(n).histCount = [];
      overlayInfo(n).histBins = [];
    end
    
    % Set alphamap for figure
    % Images use direct AlphaDataMapping.  First entry is transparent (for clear parts of overlays)
    %  Each additional entry is for each overlay.  Default to opaque for all overlays. (see local_parseInputs)
    if isempty(overlayInfo) % Just the base image
      amap = [0];
    else % There are overlays
      amap = [0 overlayInfo.transLevel];
      % Remove unnecessary transLevel field (this info stored in alphamap)
      overlayInfo=rmfield(overlayInfo,'transLevel');
    end
    % Keep master copy of AlphaMap in UseTransMenu UserData, so that it
    % transLim's can be handled in versions of MATLAB that do not support
    % transparency (UseTransMenu_Callback will setup initial AlphaMap)
    set(handles.UseTransMenu,'UserData',amap);
    
    % Set additional fields in "Info" structs
    % NONE currently necessary
    
    % Create images for base and each overlay image
    % Note: Put corresponding "Info" struct in UserData of each image
    axes(handles.imgAx);  % Make image axes current axes
    baseImage_h=image(zeros(64,64),'Tag','baseImage','CDataMapping','Direct', ...
      'EraseMode','Normal','ButtonDownFcn','showsrs2(''Click_Callback'',gcbo);','UserData',baseInfo);
    if length(overlayInfo) == 0
      % No overlays, just initalize overlayImage_h to []
      overlayImage_h=[];
    else
      % Generate image for each overlay
      for n = 1:length(overlayInfo)
        overlayImage_h(n)=image(zeros(64,64),'Tag','overlayImage','CDataMapping','Direct', ...
          'EraseMode','Normal','ButtonDownFcn','showsrs2(''Click_Callback'',gcbo);','UserData',overlayInfo(n));
      end
    end
    
    % Generate a label for each image (for use in showsrs_cfg)
    % Add name of variable passed to showsrs2 if possible
    if isempty(inputname(1)), 
      image_names{1} = 'Base';
    else
      image_names{1} = sprintf('Base - %s',inputname(1));
    end
    for n=1:length(overlayInfo)
      inName = inputname(otherInfo.overlayArgIndex(n));
      if isempty(inName)
        image_names{n+1} = sprintf('Overlay %d',n);
      else
        image_names{n+1} = sprintf('Overlay %d - %s',n,inName);
      end
    end
    
    % Label the figure with the names of the file, variables, or unknown
    for c=1:length(otherInfo.imageNames)
      currLabel = '';
      if ~isempty(otherInfo.imageNames{c})
        % Use the filename if it is known
        [pathstr,name,ext,versn] = fileparts(otherInfo.imageNames{c});
        currLabel = [name,ext,versn];
        if ~isempty(pathstr)
          % If there is another element in the path, include the prior element too.
          [pathstr,name,ext,versn] = fileparts(pathstr);
          currLabel = fullfile(name,currLabel);
        end
        % Put filenames in quotes
        currLabel = sprintf('''%s''',currLabel);
        clear('pathstr','name','ext','versn');
      else
        % Use the inputname if the filename is not known
        if c == 1 % Base
          currLabel = inputname(1);
        else % Overlay
          currLabel = inputname(otherInfo.overlayArgIndex(c-1));
        end
      end
      % Otherwise, use Unknown
      if isempty(currLabel), currLabel = 'Unknown'; end
      if c == 1,
        figLabel = currLabel;
      else
        figLabel = sprintf('%s, %s',figLabel,currLabel);
      end
    end
    set(handles.fig,'Name',figLabel);
    
    % Setup the contents of the Figure GUI for the current data set
    % 'UserData' - struct with fields:
    %                image_h is a vector of handles to the images (1st is always base handle)
    %                image_h_otherImages is a cell array of vectors of image handles
    %                    The images in each cell array element are handles of other images that need to 
    %                    have their data filled in with the same data as image_h using the 'getImageString'
    %                    in the image's axis handle.  This is used to draw other orientations, slices, etc.
    %                image_names is a cell array of strings with a name for each handle in image_h
    %                imageSize3D is the matrix size of the images (without the 4th dimension))
    %                orient3DOrig2Native is the permutation necessary to get from the original orientation 
    %                    to the native orientation (Axial)
    %                timepts is the number of time points in base and each overlay (size of 4th dimension)
    %                timePlotAxes is the axes handle for the time series plot. 
    %                showTimePlot is a boolean vector of length image_h indicating if this image's data 
    %                    should be shown in the timePlotAxes.
    %                handles is a structure containing the handles of the GUI. (Set in local_initializegui)
    %                resizeInfo is a structure containing information for resizing the GUI. (Set in local_initializegui)
    %                linkedFigIDs is a list of handles from linked showsrs2
    %                  windows.  Do NOT set to figure handle because they
    %                  are reusable.  Use primary imgAx handle instead.
    %              
    % NOTE: Update figure UserData using local_setUserDataField or be VERY
    %       careful to make sure that other code has not change the UserData
    %       between the get and set.
    figUD = get(handles.fig,'UserData'); % Grab structure already created by local_initializegui
    figUD.image_h = [baseImage_h overlayImage_h];
    figUD.image_h_otherImages = cell(1,length(overlayImage_h)+1);
    figUD.image_names = image_names;
    figUD.imageSize3D = [size(baseInfo.srs,1),size(baseInfo.srs,2),size(baseInfo.srs,3)];
    figUD.orient3DOrig2Native = otherInfo.orient3DOrig2Native;
    figUD.voxelSize = otherInfo.voxelSize;
    figUD.timePts = timePts;
    figUD.timePlotAxes = [];
    figUD.showTimePlot = otherInfo.showTimePlot;
    figUD.linkedFigIDs = [];
    set(handles.fig,'UserData',figUD);
    
    % Setup the contents of the Axis GUI for the current data set
    % 'UserData' - struct with fields:
    %                getImageString is the string to be evaluated to extract the current image data
    %                toScreenPlane is a vector of the mapping of the dimensions in the stored image 
    %                     to the dimensions in the displayed image.   Note that the toScreenPlane 
    %                     field in handles.imgAx is used for slice slider.
    %
    % NOTE: Default orientation is the orientation of baseSrs as returned by local_parseInputs
    %       (i.e. Native orientation if voxel size or slice plane not specified, 
    %              Axial orientation if voxel size and slice plance speicifed.
    set(handles.imgAx,'UserData',struct(...
      'getImageString','permute(image_ud.srs(:,:,z,timePts(n)),[2 1 3 4])', ...
      'toScreenPlane',[1 2 3]));
    
    % Store current point in 'UserData' of Slice Slider
    % TODO: Set this so that the current point is in the middle of the default slice plane
    set(handles.Slider,'UserData',[1,1,1]);
    
    % Determine if OpenGL transparency can be used.
    UseTransState = 'off'; % Default to off
    if str2double(strtok(strtok(version),'.')) < 6
      % MATLAB versions before 6.0 cannot use OpenGL transparency
      % (Check version number using 'version' function form from MATLAB 5.3)
      UseTransState = 'off';
    elseif ~any(strcmp(set(handles.fig,'Renderer'),'OpenGL'))
      % Check if OpenGL renderer available
      waitfor(warndlg('Disabling OpenGL transparency.  OpenGL renderer not available.', ...
        'Disabling OpenGL transparency','modal'));
      UseTransState = 'off';
    elseif get(0,'ScreenDepth') < 16
      % Screen depth is less than 16-bit.  OpenGL does not work for 8-bits
      % displays (MATLAB 5.2 to 6.5)
      waitfor(warndlg('Disabling OpenGL transparency.  showsrs2 requires 16-bit or greater screen depth for OpenGL transparency!', ...
        'Disabling OpenGL transparency','modal'));
      UseTransState = 'off';
    end
    % Update figure for transparency use choice.
    UseTransMenu_Callback(handles,[],UseTransState); 
        
    % Set initial orientation to original slice plane
    if otherInfo.enableReorient
      % Disable the the specify orientation menu (cannot specify orientation twice!).
      set(handles.SpecifyOrientMenu,'Enable','off');
      % Enable the flip menu
      set(handles.FlipMenu,'Enable','on');
      % Enable the reorient items in the menu and set all items to off
      set([handles.AxialOrientMenu,handles.CoronalOrientMenu, ...
          handles.SagittalOrientMenu,handles.ThreePlaneOrientMenu], ...
        'Enable','on','Checked','Off');
      % Find the menu item for the original slice plane & check it
      currOrientMenu_h=findobj(handles.OrientMenu,'Tag',[otherInfo.origSlicePlane,'OrientMenu']); 
      if isempty(currOrientMenu_h), error('Unable to find original slice plane in orientation menu!'); end
      set(currOrientMenu_h,'Checked','On');
      % Update orientation (includes displaying images)
      local_changeOrientation(handles);    
    else
      % Just Display the images
      showsrs2('Refresh_Callback',handles.fig);
    end
    
    % Set flip checkboxes as requested (base and overlay images should
    % be flipped already in local_parseInputs)
    for n=1:length(otherInfo.flipTag)
      cbo=findobj(handles.fig,'Tag',otherInfo.flipTag{n});
      if strcmp(get(cbo,'Checked'),'off'), state='on'; else state='off'; end
      set(cbo,'Checked',state);
    end
    
    if nargout == 1 % Return the figure handle if asked for
      figureh = handles.fig;
    end
    
  elseif ischar(varargin{1}) % INVOKE NAMED SUBFUNCTION OR CALLBACK
    task = varargin{1}; % Assign for catch error handling

    % Don't support return arguments on callbacks
    if nargout ~= 0
      emsg='No output arguments allowed for callbacks in showsrs2!'; error(emsg);
    end
    
    if any(strcmp(varargin{1},externalTasks))
      % Bypass the standard callback argument handing and just feval.     
      % Execute callback function
      % varargin{1} - Function name (as string)
      % varargin{2:end} - Arguments
      feval(varargin{:}); % FEVAL switchyard
    else
      % Check number of input arguments
      corrNumArgs = 2; % Default
      if any(strcmp(varargin{1},{'ChangeTimePoint_Callback','Play_Callback','ShowMarkersMenu_Callback','ShowTimePlot_Callback'}))
        corrNumArgs = 3;
      elseif any(strcmp(varargin{1},{'Refresh_Callback','UseTransMenu_Callback'}))
        corrNumArgs = 2:3;
      end
      if ~any(nargin == corrNumArgs)
        emsg=sprintf('Incorrect number of arguments for callback %s',varargin{1}); error(emsg);
      end

      % Get handles structure (make sure it is a valid showsrs2 figure)
      if ~ishandle(varargin{2})
        emsg='Invalid showsrs2 figure handle!'; error(emsg);
      end
      showsrs2_h = getparentfigure(varargin{2});
      if ~strcmp(get(showsrs2_h,'Tag'),'showsrs2()')
        emsg='Invalid showsrs2 figure handle!'; error(emsg);
      end
      handles = subsref(get(showsrs2_h,'UserData'),struct('type','.','subs','handles'));

      % Execute callback function
      % varargin{1} - Function name (as string)
      % varargin{2} - callback object handle
      % handles structure always passed as first argument to callback
      feval(varargin{1},handles,varargin{2:end}); % FEVAL switchyard
    end
  end
  
catch
  % Check for error messages in emsg and lasterr
  if isempty(emsg)
    emsg=lasterr;
    if isempty(emsg)
      emsg='An unidentified error occurred!';
    end
  end
  
  % If the user closes the window during a callback
  if any(strcmp(task,externalTasks))
    % Just issue error on external tasks
    error(emsg);
  elseif nargin >= 2 & ischar(varargin{1}) & ~ishandle(varargin{2})
    % If an error occurs during a callback and the handle to the callback
    % is not valid (i.e. the user closes the window), assume a user abort.
    disp('User abort');
  else
    % Otherwise issue error
    
    % Close GUI (if we have a valid handle for it)
    if exist('handles','var') & isstruct(handles) & isfield(handles,'fig') & ishandle(handles.fig)
      delete(handles.fig)
    end    
    error(emsg);
  end
end

%|--------------------------------------------------------------------
%| ABOUT CALLBACKS:
%| CALLBACK are each implemented as local functions and are called 
%| through the FEVAL switchyard above. This comment describes that 
%| mechanism.
%|
%| Each callback subfunction declaration has the following form:
%| <SUBFUNCTION_NAME>(HANDLES,CBO,...)
%|
%| CBO is the callback object's handle (obtained using GCBO).
%|
%| HANDLES is a structure containing handles of components in GUI using
%| tags as fieldnames, e.g. handles.figure1, handles.slider2. This
%| structure is created at GUI startup using GUIHANDLES and stored in the
%| 'handles' field of a structure in the figure UserData.
%|
%| ... contains any extra arguments you have passed to the
%| callback. Specify the extra arguments by editing the callback.
%|
%| Specify the callback in the CALLBACK tag of objects using the
%| the following form showsrs2('<SUBFUNCTION_NAME>', gcbo)
%|
%| Add any extra arguments after the last argument, before the final
%| closing parenthesis.
%|
%| The HANDLES argument will automatically be added as the first
%| argument in the FEVAL switchyard using the parent figure of CBO.
%|--------------------------------------------------------------------

% --------------------------------------------------------------------
function Refresh_Callback(handles,cbo,speedFlag)
% Callback refresh the display.
%
%    Refresh_Callback(handles,cbo)
%    - Refresh all images
%    Refresh_Callback(handles,cbo,speedFlag)
%    - See local_updatedisplay for explanation of speedFlag

% Stop the playing if it is going
set(handles.PlayButton,'UserData','Stop');

% Get the current point (x,y,z) and time point to display
currPoint=get(handles.Slider,'UserData');
t=round(get(handles.TimeSlider,'Value'));

% Show selected image
if nargin < 3
  local_updatedisplay(handles,[currPoint,t]);
else
  local_updatedisplay(handles,[currPoint,t],speedFlag);
end
drawnow;

% --------------------------------------------------------------------
function KeyPress_Callback(handles,cbo)
% Callback to handle when a key is pressed
k=get(handles.fig,'CurrentCharacter');
switch k
case {'1','2','3','4','5','6','7','8','9',28,29}
  % Time related keypresses
  if max(subsref(get(handles.fig,'UserData'),struct('type','.','subs','timePts')))~=1  
    % Only excute time keypresses if there is more than one time point
    switch k
    case '1', showsrs2('ToEnd_Callback',handles.fig);
    case {'2',29}, showsrs2('ChangeTimePoint_Callback',handles.fig,'Next');  % Right arrow (29) or '2'
    case '3', showsrs2('ChangeTimePoint_Callback',handles.fig,'PgDn');
    case '4',
      disp('Keyboard shortcut for Reverse Play not working!  Use button instead'); return;
      showsrs2('Play_Callback',handles.fig,'RevPlay');
    case '5', showsrs2('Stop_Callback',handles.fig);
    case '6', 
      disp('Keyboard shortcut for Play not working!  Use button instead'); return;
      showsrs2('Play_Callback',handles.fig,'Play');
    case '7', showsrs2('ToStart_Callback',handles.fig);
    case {'8',28}, showsrs2('ChangeTimePoint_Callback',handles.fig,'Prev');  % Left arrow (28) or '8'
    case '9', showsrs2('ChangeTimePoint_Callback',handles.fig,'PgUp');
    end
  end
case {'a','s','d','w','q','e',30,31} % Catch up arrow (30) and down arrow (31)
  % Space related keypresses
  % Display the time series for the point in the direction the person pushed.  
  
  % Get current point & size of images 
  currPoint=get(handles.Slider,'UserData');
  imsize=subsref(get(handles.fig,'UserData'),struct('type','.','subs','imageSize3D'));
  toScreenPlane=subsref(get(handles.imgAx,'UserData'),struct('type','.','subs','toScreenPlane'));
  
  % Convert coordinates & sizes to screen plane coordinates
  currPointScreen=currPoint(toScreenPlane);
  imsizeScreen=imsize(toScreenPlane);
  
  % Set new point based on key pressed (Don't move out of image)
  switch k
  case 'a',          % Move left
    if currPointScreen(1) > 1, currPointScreen(1)=currPointScreen(1)-1; end
  case 'd',          % Move right
    if currPointScreen(1) < imsizeScreen(1), currPointScreen(1)=currPointScreen(1)+1; end
  case 'w',          % Move up
    if currPointScreen(2) > 1, currPointScreen(2)=currPointScreen(2)-1; end
  case 's',          % Move down
    if currPointScreen(2) < imsizeScreen(2), currPointScreen(2)=currPointScreen(2)+1; end
  case {'q',30}      % Move up one slice
    if currPointScreen(3) > 1, currPointScreen(3)=currPointScreen(3)-1; end 
  case {'e',31}      % Move down one slice
    if currPointScreen(3) < imsizeScreen(3), currPointScreen(3)=currPointScreen(3)+1; end	
  end
  % Convert back to plane of stored data
  currPoint(toScreenPlane)=currPointScreen;
  
  % Determine if the time series plot should be updated
  %   If the sliceUp or SliceDown keys are pushed during single slice mode,
  %   only update the time series if it is already open (so that you can
  %   change slices without causing time series window to appear) 
  % Also turn on markers if you are moving in-plane or are in the 3-plane
  %   view (All cases except changing slice in single plane mode)
  plotTimeSrsFlag=1; % If flag TRUE, plot time series
  if strcmp(get(handles.Slider,'Enable'),'on') & any(k==['q','e',30,31])
    % single slice mode, pushed sliceUp or sliceDown
    fig_ud = get(handles.fig,'UserData');
    if isempty(fig_ud.timePlotAxes) | ~ishandle(fig_ud.timePlotAxes)
      plotTimeSrsFlag = 0;
    end
    clear fig_ud
  else
    showsrs2('ShowMarkersMenu_Callback',handles.fig,'on');
  end

  % Update display for current time point
  local_updatepoint(handles, currPoint, plotTimeSrsFlag);

case 'm'
  % Display current space and time point to command window.
  currPoint=get(handles.Slider,'UserData');
  maxTimePts = max(subsref(get(handles.fig,'UserData'),struct('type','.','subs','timePts')));
  if maxTimePts == 1 % Only display x,y,z if there is only one time point
    disp(sprintf('%d,%d,%d',currPoint(1),currPoint(2),currPoint(3)));
  else % Otherwise display x,y,z,t
    t=str2num(get(handles.TimePt,'String'));
    disp(sprintf('%d,%d,%d,%d',currPoint(1),currPoint(2),currPoint(3),t));
  end
end

% --------------------------------------------------------------------
function Play_Callback(handles,cbo,task)
% Callback to cycle through the images in time (forward or reverse)
%   task = 'Play' for forward play or 'RevPlay' for reverse playing
figure(handles.fig);
if ~strcmp(task,get(handles.PlayButton,'UserData'))
  set(handles.PlayButton,'UserData',task);
  t=str2num(get(handles.TimePt,'String'));
  timePts=get(handles.TimeSlider,'Max');     
  currPoint=get(handles.Slider,'UserData'); % Get current point
  while ismember(get(handles.PlayButton,'UserData'),{'Play','RevPlay'})
    set(handles.TimeSlider,'Value',t);
    set(handles.TimePt,'String',num2str(t));
    local_updatedisplay(handles,[currPoint,t],1); % Update images (time point changes only) 
    drawnow;
    if ismember(get(handles.PlayButton,'UserData'),{'Play','RevPlay'})
      if strcmp(get(handles.PlayButton,'UserData'),'Play'), step=1; else step=-1; end
      t=t+step;
      if t<1 | t>timePts
        if get(handles.LoopCheckbox,'Value')==1
          t=mod(t-1,timePts)+1;
        else
          set(handles.PlayButton,'UserData','Stop');
        end
      end
      delay=str2num(get(handles.DelayBox,'String'));
      t0=clock; while etime(clock,t0)<delay, end
    end
  end   
end

% --------------------------------------------------------------------
function Stop_Callback(handles,cbo)
% Callback to stop cycling through the images in time (forward or reverse)
set(handles.PlayButton,'UserData','Stop');
figure(handles.fig);

% --------------------------------------------------------------------
function ToStart_Callback(handles,cbo)
% Callback to set the current time image to the first image in time
t = get(handles.TimeSlider,'Min');
set(handles.TimeSlider,'Value',t);
set(handles.TimePt,'String',num2str(t));
showsrs2('Refresh_Callback',handles.fig);
figure(handles.fig);

% --------------------------------------------------------------------
function ToEnd_Callback(handles,cbo)
% Callback to set the current time image to the lase image in time
t = get(handles.TimeSlider,'Max');
set(handles.TimeSlider,'Value',t);
set(handles.TimePt,'String',num2str(t));
showsrs2('Refresh_Callback',handles.fig);
figure(handles.fig);

% --------------------------------------------------------------------
function ChangeTimePoint_Callback(handles,cbo,task)
% Callback to change the current time point
t=get(handles.TimeSlider,'Value');
sMax=get(handles.TimeSlider,'Max');
switch task
case 'Prev', step=-1;
case 'PgUp', step=-sMax/10;
case 'Next', step=1;
case 'PgDn', step=sMax/10;
end
t=t+step;
if t<1, t=1; elseif t>sMax, t=sMax; end
set(handles.TimeSlider,'Value',t);
set(handles.TimePt,'String',num2str(t));
showsrs2('Refresh_Callback',handles.fig);
figure(handles.fig);

% --------------------------------------------------------------------
function TimeSlider_Callback(handles,cbo)
% Callback to update the image displayed to match the current time slider
% position

% Stop the playing if it is going
set(handles.PlayButton,'UserData','Stop');

% Find out which time point to show
t = round(get(handles.TimeSlider,'Value'));
set(handles.TimeSlider,'Value',t);
set(handles.TimePt,'String',num2str(t));

% Refresh display
showsrs2('Refresh_Callback',handles.fig);

% --------------------------------------------------------------------
function Delay_Callback(handles,cbo)
% Callback to change the current delay when playing movies
set(handles.DelayBox,'String',num2str(str2num(get(handles.DelayBox,'String'))));
figure(handles.fig);

% --------------------------------------------------------------------
function SliceSlider_Callback(handles,cbo)
% Callback to update the image displayed to match the current slice slider
% position

% Stop the playing if it is going
set(handles.PlayButton,'UserData','Stop');

if strcmp(get(handles.Slider,'Enable'),'on')
  % Slider enabled, find out which slice to show from slice slider
  slice=round(abs(get(handles.Slider,'Value')));
  
  % Update the slice in the currPoint
  % Note: the primary image axis (handles.imgAx) contains a vector
  %       of the mapping of the stored plane to the displayed image
  %       in the structure field toScreenPlane.  The third value is 
  %       the dimension which is slice in the displayed image
  currPoint=get(handles.Slider,'UserData');
  ax_ud=get(handles.imgAx,'UserData');
  currPoint(ax_ud.toScreenPlane(3))=slice;
  
  % Update display to current point
  local_updatepoint(handles, currPoint);
end

% --------------------------------------------------------------------
function Click_Callback(handles,cbo)
% User clicked on image to show time series plot for that point
% Create plot figure, if needed
%

% Get axis & coords clicked on
imgAx=get(cbo,'Parent');      % Get axis clicked on
if ~strcmp(get(imgAx,'type'),'axes'),
  % Check that imgAx is an axes
  emsg='Click_Callback requires a child of an axes!';
  error(emsg);
end
pt=get(imgAx,'CurrentPoint'); % Get coords clicked on

% Get the stored current point (x,y,z) & update
% - Use toScreenPlane mapping in clicked axis UserData to determine
%   which dimensions are shown on the screen plane
ax_ud = get(imgAx,'UserData');
currPoint = get(handles.Slider,'UserData');
currPoint(ax_ud.toScreenPlane(1:2)) = round(pt(1,1:2));

% Update display to current point (create time series axis)
local_updatepoint(handles, currPoint, 1)

% Turn on markers when you click
showsrs2('ShowMarkersMenu_Callback',handles.fig,'on');

% --------------------------------------------------------------------
function CloseRequestFcn_Callback(handles,cbo)
% This function handles closing the window.  
% (1) Close configuration windows
% (2) Close showsrs window

% 
% NOTE: Set cbo to the current figure when calling this callback because gcbo
% is NOT updated because the close function calls the 'CloseRequestFcn' 
% directly instead of as a callback.

% Close any open configuration GUIs for this figure
try
  % Find & delete showsrs2_cfgtrans figures for this showsrs2
  gui_h=local_find_showsrs2_childGUI('showsrs2_cfgFig',handles.fig);
  if ~isempty(gui_h), delete(gui_h), end
catch
  % If this fails, issue a warning and continue on to close finish close request function
  warning(sprintf('Failure attempting to automatically close configuration windows.\nError was:\n%s',lasterr));      
end

% Close any open transparency configuration GUIs for this figure
try
  % Find & delete showsrs2_cfgtrans figures for this showsrs2
  gui_h=local_find_showsrs2_childGUI('showsrs2_cfgtransFig',handles.fig);
  if ~isempty(gui_h), delete(gui_h), end
catch
  % If this fails, issue a warning and continue on to close finish close request function
  warning(sprintf('Failure attempting to automatically close transparency adjustment window.\nError was:\n%s',lasterr));      
end

try
  fig_ud=get(handles.fig,'UserData');
  if ~isempty(fig_ud) & ~isempty(fig_ud.timePlotAxes) & ishandle(fig_ud.timePlotAxes)
    % Include ~isempty(fig_ud) in case showsrs2 errors before set the figure UserData.
    timeSrsFig_h = getparentfigure(fig_ud.timePlotAxes);
    if timeSrsFig_h ~= handles.fig,
      % Don't delete the timeSrsFig_h if it is the showsrs2 window
      delete(timeSrsFig_h);
    end
  end
catch
  % If this fails, issue a warning and continue on to close finish close request function
  warning(sprintf('Failure attempting to automatically close time plot axes.\nError was:\n%s',lasterr));
end

% Close showsrs figure
delete(getparentfigure(cbo));

% --------------------------------------------------------------------
function SpecifyOrientMenu_Callback(handles,cbo)
% Specify the orientation and voxel size in a GUI.  Then enable the
% orientation menu items.
%
% Note: Updates fig_ud.voxelSize &  image_ud.srs (all layers)!

% Get figure UserData
fig_ud = get(handles.fig,'UserData'); 

% Make sure there is more than one slice
if fig_ud.imageSize3D(3) < 2
  waitfor(warndlg('Cannot reorient single slice data!', ...
                  'Cannot reorient','modal'));
  return
end
  
% --- Get slicePlane and voxelSize from user. ---
% (Assume a 240 mm FOV for default voxel sizes in-plane)
defSize = [240./fig_ud.imageSize3D(1), 240./fig_ud.imageSize3D(2), 0];
[origSlicePlane,origVoxelSize] = local_getorientgui([],defSize);
if isempty(origSlicePlane), return; end % User cancelled.

% --- Reorient the images to axial ---
% TODO: Check that base and overlay have the same orientation.
for n = 1:length(fig_ud.image_h);
  image_ud = get(fig_ud.image_h(n),'UserData');
  image_ud.srs = orthosrs(image_ud.srs,origSlicePlane);
  set(fig_ud.image_h(n),'UserData',image_ud);
end
% Determine the permuation necessary to get from the current data
% orientation to the native data orientation (Axial)
switch origSlicePlane
  case 'Axial'
    fig_ud.orient3DOrig2Native = [1 2 3]; % Axial->Axial
  case 'Coronal'
    fig_ud.orient3DOrig2Native = [1 3 2]; % Coronal->Axial
  case 'Sagittal'
    fig_ud.orient3DOrig2Native = [3 1 2]; % Sagittal->Axial
  otherwise
    emsg=sprintf('Slice plane %s unknown.  Please chose Axial, Sagittal or Coronal!',baseInfo.origSlicePlane); error(emsg)
end
% Permute the voxelSize and imageSize for the store orientation (Axial)
fig_ud.voxelSize = origVoxelSize(fig_ud.orient3DOrig2Native); 
fig_ud.imageSize3D = fig_ud.imageSize3D(fig_ud.orient3DOrig2Native);

% --- Store the updated figure UserData ---
set(handles.fig,'UserData',fig_ud);

% --- Setup the Orientation Menu and change the orientation ---
% Disable the this menu (cannot specify orientation twice!).
set(handles.SpecifyOrientMenu,'Enable','off');
% Enable the flip menu
set(handles.FlipMenu,'Enable','on');
% Enable the reorient items in the menu and set all items to off
set([handles.AxialOrientMenu,handles.CoronalOrientMenu, ...
    handles.SagittalOrientMenu,handles.ThreePlaneOrientMenu], ...
  'Enable','on','Checked','Off');
% Find the menu item for the original slice plane & check it
currOrientMenu_h=findobj(handles.OrientMenu,'Tag',[origSlicePlane,'OrientMenu']); 
if isempty(currOrientMenu_h), error('Unable to find original slice plane in orientation menu!'); end
set(currOrientMenu_h,'Checked','On');
% Update orientation (includes displaying images)
local_changeOrientation(handles);    

% --------------------------------------------------------------------
function ChangeOrientMenu_Callback(handles,cbo)
% Handle changes in the image orientation menu

% Turn all menu checks off except item just selected
set(handles.AxialOrientMenu,'Checked','Off');
set(handles.CoronalOrientMenu,'Checked','Off');
set(handles.SagittalOrientMenu,'Checked','Off');
set(handles.ThreePlaneOrientMenu,'Checked','Off');
set(cbo,'Checked','On');

% Update the orientation based on the current menu selection
local_changeOrientation(handles);      

% --------------------------------------------------------------------
function FlipMenu_Callback(handles,cbo)
% Flip base and overlay images as requested.

% Determine dim to flip
switch get(cbo,'Tag');
  case 'FlipMenuRL', dim=1;
  case 'FlipMenuAP', dim=2;
  case 'FlipMenuSI', dim=3;
  otherwise, error('Invalid menu item for FlipMenu_Callback');
end

% Toggle check box
if strcmp(get(cbo,'Checked'),'off'), state='on'; else state='off'; end
set(cbo,'Checked',state);

% --- Flip base and all overlays ----
figUD=get(handles.fig,'UserData');
for n=1:length(figUD.image_h)
  imageUD=get(figUD.image_h(n),'UserData');
  imageUD.srs=flipdim(imageUD.srs,dim);
  set(figUD.image_h(n),'UserData',imageUD);
end
clear('figUD','imageUD');

% Refresh display
showsrs2('Refresh_Callback',handles.fig);

% If there is a time series plot, refresh it
showsrs2('RefreshPlotTimeSrs_Callback',handles.fig);

% --------------------------------------------------------------------
function SaveAsJPEGMenu_Callback(handles,cbo)
% Save current axes as a JPEG image
[fName,savepath]=uiputfile('*.jpg','Save as JPEG File'); % Get filename to save
if ~(isequal(fName,0)|isequal(savepath,0))
  f=getframe(handles.imgAx); % Get picture of current axis
  if isempty(f.colormap)
    % True-color, just save the colordata
    imwrite(f.cdata,fullfile(savepath,fName),'jpeg','Quality',80);
  else
    % Indexed-color, use associated colormap
    imwrite(f.cdata,f.colormap,fullfile(savepath,fName),'jpeg','Quality',80);
  end
end

% --------------------------------------------------------------------
function SaveAsTIFFMenu_Callback(handles,cbo)
% Save current axes as a TIFF image
[fName,savepath]=uiputfile('*.tif','Save as TIFF File'); % Get filename to save
if ~(isequal(fName,0)|isequal(savepath,0))
  f=getframe(handles.imgAx); % Get picture of current axis
  if isempty(f.colormap)
    % True-color, just save the colordata
    imwrite(f.cdata,fullfile(savepath,fName),'tiff');
  else
    % Indexed-color, use associated colormap
    imwrite(f.cdata,f.colormap,fullfile(savepath,fName),'tiff');
  end
end

% --------------------------------------------------------------------
function ShowMarkersMenu_Callback(handles,cbo,state)
% Show or hide crosshair markers
%
%    state =   [] - Toggle
%           'off' - Not visible
%            'on' - Visible
if isempty(state)
  % If empry, toggle showing markers
  if strcmp(get(handles.ShowMarkersMenu,'Checked'),'off'), state='on'; else state='off'; end
elseif ~any(strcmp(state,{'on','off'}))
  % Check for valid state
  emsg='Invalid state for ShowMarkersMenu!  Must be on or off'; error(emsg);
end
set(handles.ShowMarkersMenu,'Checked',state);
set(findobj(handles.fig,'Type','Line','Tag','HorzMarker'),'Visible',state);
set(findobj(handles.fig,'Type','Line','Tag','VertMarker'),'Visible',state);

% --------------------------------------------------------------------
function ShowFigureMenuBarMenu_Callback(handles,cbo)
% Show or hide figure menu bar (toggle based on current state)
if strcmp(get(handles.ShowFigureMenuBarMenu,'Checked'),'off'), 
  % Turn on
  set(handles.ShowFigureMenuBarMenu,'Checked','on');

  % Get showsrs2 specific menu handles
  showsrs2_menu_h=findobj(get(handles.fig,'Children'),'flat','type','uimenu');
  
  % Add standard menubar handles
  set(handles.fig,'MenuBar','figure');
  
  % --- Move showsrs2 menus to the right ---
  
  % Show hidden handles & save previous state (since figure uimenus use hidden handles)
  currState=get(0,'ShowHiddenHandles');
  set(0,'ShowHiddenHandles','on');
  
  % Move showsrs2 menus to beginning of children 
  % (menu's display right to left in 'Children' order)
  child_h=get(handles.fig,'Children');
  for n=length(showsrs2_menu_h):-1:1
    showsrs2_menu_i(n)=find(child_h==showsrs2_menu_h(n));
  end
  set(handles.fig,'Children',child_h([showsrs2_menu_i,setxor(1:length(child_h),showsrs2_menu_i)]));

  % Return hidden handles to previous state
  set(0,'ShowHiddenHandles',currState);
else
  % Turn off
  set(handles.ShowFigureMenuBarMenu,'Checked','off');
  set(handles.fig,'MenuBar','none');
end

% --------------------------------------------------------------------
function ShowLegendMenu_Callback(handles,cbo)
% Show or hide legend on time series plot (toggle)

% Toggle menu item checkbox
if strcmp(get(handles.ShowLegendMenu,'Checked'),'off'), state='on'; else state='off'; end
set(handles.ShowLegendMenu,'Checked',state);

% If there is a time series plot, refresh it
% (this will handle legend creation/deletion)
showsrs2('RefreshPlotTimeSrs_Callback',handles.fig);

% --------------------------------------------------------------------
function UseImageColorsMenu_Callback(handles,cbo)
% Use overlay colors to generate time series plot (toggle)

% Toggle menu item checkbox
if strcmp(get(handles.UseImageColorsMenu,'Checked'),'off'), state='on'; else state='off'; end
set(handles.UseImageColorsMenu,'Checked',state);

% If there is a time series plot, refresh it
% (this will handle updating the line colors if necessary)
showsrs2('RefreshPlotTimeSrs_Callback',handles.fig);

% --------------------------------------------------------------------
function UseTransMenu_Callback(handles,cbo,state)
% Use OpenGL transparency to generate overlays
%
%  UseTransMenu_Callback(handles,cbo,state) - Set to state
%  UseTransMenu_Callback(handles,cbo) - Toggle
%

if nargin < 3  % Toggle menu item checkbox
  if strcmp(get(handles.UseTransMenu,'Checked'),'off'), state='on'; else state='off'; end
end

if strcmp(state,'on')
  % Don't allow MATLAB versions before 6.0 to use OpenGL transparency.
  if str2double(strtok(strtok(version),'.')) < 6
    waitfor(warndlg('Cannot use OpenGL transparency with MATLAB versions earlier than 6.0 (R12).', ...
      'Cannot use OpenGL transparency','modal'));
    return
  end
  % Check if OpenGL Renderer is available
  if ~any(strcmp(set(handles.fig,'Renderer'),'OpenGL'))
    waitfor(warndlg('Cannot use OpenGL transparency.  OpenGL renderer not available.', ...
      'Cannot use OpenGL transparency','modal'));
    return
  end
  % Don't allow screen depths less than 16-bit (8-bit OpenGL doesn't work).
  if get(0,'ScreenDepth') < 16
    waitfor(warndlg('Cannot use OpenGL transparency with less than 16-bit screen depth (Thousands of colors)', ...
      'Cannot use OpenGL transparency','modal'));
    return
  end
end

% Update state of 'Checked' box
set(handles.UseTransMenu,'Checked',state);

if strcmp(state,'on') % Using OpenGL transparency
  % Set alphamap to current values.
  set(handles.fig,'AlphaMap',get(handles.UseTransMenu,'UserData'));
  
  % Setup AlphaDataMapping for all images.
  fig_ud = get(handles.fig,'UserData');
  % Turn off on base images.
  set([fig_ud.image_h(1), fig_ud.image_h_otherImages{1}],'AlphaDataMapping','none');
  if length(fig_ud.image_h) > 1 % Use direct on overlays
    set([fig_ud.image_h(2:end), fig_ud.image_h_otherImages{2:end}],'AlphaDataMapping','Direct');
  end
  
  % Make all images other than the Base images visible since we are be using them.
  if length(fig_ud.image_h) > 1
    set(fig_ud.image_h(2:length(fig_ud.image_h)),'Visible','on');
    set([fig_ud.image_h_otherImages{2:length(fig_ud.image_h)}],'Visible','on');
  end
  clear fig_ud % We are done with it.
  
  % Set Renderer to OpenGL and turn double buffering off since OpenGL
  % transparency doesn't work with double buffering.
  % TODO: Double buffering appears to work in MATLAB 6.5.  Check in 6.1.
  set(handles.fig,'Renderer','OpenGL','DoubleBuffer','off');
else % Not using OpenGL transparency
  % If using MATLAB 6.0 or greater, turn off AlphaDataMapping on all images
  %   Since all overlays are not visible, this probably isn't necessary,
  %   but doesn't hurt either!
  fig_ud = get(handles.fig,'UserData');
  if str2double(strtok(strtok(version),'.')) >= 6
    set([fig_ud.image_h,fig_ud.image_h_otherImages{:}],'AlphaDataMapping','none');
  end    
  
  % Make all images other than the Base images invisible since we won't be using them.
  if length(fig_ud.image_h) > 1
    set(fig_ud.image_h(2:length(fig_ud.image_h)),'Visible','off');
    set([fig_ud.image_h_otherImages{2:length(fig_ud.image_h)}],'Visible','off');
  end
  clear fig_ud % We are done with it.

  % Use painters renderer and turn double buffering on for smoother display.
  set(handles.fig,'Renderer','painters','DoubleBuffer','on');
end

% If a showsrs2_cfg window is open, force it to save it's current settings
% so that the image displays properly.
cfg_h=local_find_showsrs2_childGUI('showsrs2_cfgFig',handles.fig);
if ~isempty(cfg_h), showsrs2_cfg('saveCurrSettings_Callback',cfg_h,[]); end

% Update the display
showsrs2('Refresh_Callback',handles.fig);

% --------------------------------------------------------------------
function Resize_Callback(handles,cbo)
% RESIZE_CALLBACK - This function resizes the window
%
%   Resize_Callback(handles,cbo)
%      handles = structure of handles in showsrs2 window
%          cbo = handles of figure to resize
%
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

% Get the resizing information from the 'resizeInfo' field of the figure UserData
resizeInfo = subsref(get(handles.fig,'UserData'),struct('type','.','subs','resizeInfo'));

% Get the new size of the figure
figure_pos = get(handles.fig,'Position');

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
  set(handles.fig,'Position',figure_pos); % Only set once so that window doesn't jitter when both minimums reached
end

%--- Set the axes to the new width and height ---
% Calculate maximum box size for all axes
axesBox = [resizeInfo.marginWidth, ...  % Left
    resizeInfo.marginHeight+resizeInfo.horControlHeight+resizeInfo.sliderOffsetHeight, ... % Bottom
    figure_pos(3)- (resizeInfo.marginWidth*2 + resizeInfo.sliderOffsetWidth+resizeInfo.verControlWidth), ... % Width
    figure_pos(4)- (resizeInfo.marginHeight*2+ resizeInfo.sliderOffsetHeight+resizeInfo.horControlHeight)]; % Height

% Force the axes square (NEED TO ADD MIN SIZE CHECK HERE AGAIN FOR THIS TO WORK)
% NOTE: MUST BE MODIFIED FOR MULTIPLE AXES!!!!
%if axesBox(3)*resizeInfo.width2height > axesBox(4)
%  axesBox(3) = axesBox(4)*resizeInfo.height2width;
%  figure_pos(3) = resizeInfo.marginWidth*2+resizeInfo.sliderOffsetWidth+...
%    axesBox(3)+resizeInfo.verControlWidth;
%else
%  axesBox(4) = axesBox(3)*resizeInfo.width2height;
%  figure_pos(4) = resizeInfo.marginHeight*2+resizeInfo.sliderOffsetHeight+...
%    axesBox(4)+resizeInfo.horControlHeight;
%end
%set(handles.fig,'Position',figure_pos); % Set new position

% Calculated width & height of each axes (leaving marginWidth & marginHeight between each axes)
axMarginWidth = resizeInfo.marginWidth;
axMarginHeight = resizeInfo.marginHeight;
axWidth= (axesBox(3)-(resizeInfo.axesMatrix(1)-1)*axMarginWidth)/resizeInfo.axesMatrix(1);
axHeight= (axesBox(4)-(resizeInfo.axesMatrix(2)-1)*axMarginHeight)/resizeInfo.axesMatrix(2);

% Force all axes to be square
% if axWidth*resizeInfo.width2height > axHeight
%   axWidth=axHeight*resizeInfo.height2width;
% else
%   axHeight=axWidth*resizeInfo.width2height;
% end
  
% Set the position of each axis
% Primary image axes ALWAYS in upper right hand corner
% Other image axes filled in sorted handle order columnwise (see reshape)
allAxes_h=[handles.imgAx;sort(findobj(handles.fig,'Type','Axes','Tag','otherAx'))];
if length(allAxes_h(:))~=prod(resizeInfo.axesMatrix)
  emsg='axesMatrix does not match the number of axes!'; error(emsg);
end
allAxes_h=reshape(allAxes_h,resizeInfo.axesMatrix);

for col=1:resizeInfo.axesMatrix(1)
  for row=1:resizeInfo.axesMatrix(2)
    set(allAxes_h(col,row),'Position', [...
        axesBox(1)+(col-1)*(axWidth+axMarginWidth)+resizeInfo.axesLeftMargin(col,row), ...
        axesBox(2)+axesBox(4)-row*axHeight-(row-1)*axMarginHeight+resizeInfo.axesBottomMargin(col,row), ...
        axWidth-resizeInfo.axesLeftMargin(col,row)-resizeInfo.axesRightMargin(col,row), ...
        axHeight-resizeInfo.axesTopMargin(col,row)-resizeInfo.axesBottomMargin(col,row)]);
  end
end

%--- Set the time slider to the proper width (no height changes) ---
timePt_pos = get(handles.TimePt,'Position');
timeSlider_pos = get(handles.TimeSlider,'Position');
timeSlider_pos(3) = (axesBox(1) + axesBox(3)) - (timePt_pos(1)+timePt_pos(3));
set(handles.TimeSlider,'Position',timeSlider_pos);

%--- Set the slice slider and label to the proper height and position ---
sliceSlider_pos = get(handles.Slider,'Position');
sliceImgNum_pos = get(handles.ImgNum,'Position');

% Set horizontal positions
sliceSlider_pos(1) = timeSlider_pos(1)+timeSlider_pos(3)+resizeInfo.sliderOffsetWidth;
sliceImgNum_pos(1) = sliceSlider_pos(1);

% Set slice slider height
sliceSlider_pos(4) = axesBox(4) - sliceImgNum_pos(4);

% Set slice label vertical position
sliceImgNum_pos(2) = axesBox(2)+sliceSlider_pos(4);

% Set results
set(handles.Slider,'Position',sliceSlider_pos);
set(handles.ImgNum,'Position',sliceImgNum_pos);

% --------------------------------------------------------------------
function RefreshPlotTimeSrs_Callback(handles,cbo)
% Refresh time series plot (if it is open).
%
% RefreshPlotTimeSrs_Callback(handles,cbo)
%      handles = structure of handles in showsrs2 window
%          cbo - handle of object which initiated the callback (Unused)
%
% This callback was written to allow other functions (e.g. showsrs2_cfg) to
% refresh the time series plot.
%

% If there is a time series plot, refresh it
fig_ud=get(handles.fig,'UserData');
if ~isempty(fig_ud.timePlotAxes) & ishandle(fig_ud.timePlotAxes)
  currPoint=get(handles.Slider,'UserData');
  local_plottimesrs(handles,currPoint(1),currPoint(2),currPoint(3));
end

% --------------------------------------------------------------------
function ShowTimePlot_Callback(handles,showsrs2_h,cbo)
% Toogle display of time series plot for indicated image
%
% ShowTimePlot_Callback(handles,showsrs2_h,cbo)
%      handles - structure of handles in showsrs2 window
%   showsrs2_h - handle of showsrs2 figure.  Included so that callback 
%                switchyard works when cbo is not in showsrs2_h
%          cbo - handle of object which initiated the callback
%                (plot uicontextual menu item)
%

% Toogle checkbox
if strcmp(get(cbo,'Checked'),'off')
  set(cbo,'Checked','on');
  state = logical(1);
else
  set(cbo,'Checked','off');
  state = logical(0);
end

% Update showTimePlot for this image in figure UserData
% Note: Index into showTimePlot in UserData of contextual menu item cbo
fig_ud=get(handles.fig,'UserData');
fig_ud.showTimePlot(get(cbo,'UserData')) = state;
set(handles.fig,'UserData',fig_ud);

% Refresh time series plot
showsrs2('RefreshPlotTimeSrs_Callback',handles.fig);

%|--------------------------------------------------------------------
%| ABOUT EXTERNAL TASKS
%|
%| These functions bypass the standard callback argument parsing and are
%| handled as described below.  This is useful for implementing methods
%| that need different arguments than standard CALLBACKS.
%|
%| EXTERNAL TASKS are each implemented as local functions and are called 
%| through a FEVAL switchyard. This comment describes that mechanism.
%|
%| Each callback subfunction declaration has the following form
%|   <SUBFUNCTION_NAME>(...)
%|
%| Execute these callbacks using the following form
%|   showsrs2('<SUBFUNCTION_NAME>', ...)
%|
%| where ... contains any arguments passed to the external task function.
%|
%| External task function are responsible for all argument checking
%|--------------------------------------------------------------------

%---------------------------------------------------------------------
function LinkCursors(figuresToLink)
% LinkCursors - Link showsrs2 spatial cursors
%
%  LinkCursors(figuresToLink)
%    figuresToLink - Two or more showsrs2 figure handles to link
%

% Check arguments
error(nargchk(1,1,nargin));
if ~any(isa(figuresToLink,'double')) | ndims(figuresToLink) > 2 ...
    | min(size(figuresToLink)) ~= 1 | any(~ishandle(figuresToLink)) ...
    | length(figuresToLink) < 2 ...
    | length(figuresToLink) ~= length(unique(figuresToLink))
  error('figuresToLink must be a vector of two or more unique showsrs2 handles!');
end

% Check each figure & grab figIDs
figIDs = zeros(size(figuresToLink));
for n = 1:length(figuresToLink)
  % Must be showsrs2 figure handle
  if ~strcmp(get(figuresToLink(n),'Tag'),'showsrs2()')
    error(sprintf('%g is not a showsrs2 figure.  Figures NOT linked!', ...
      figuresToLink(n)));
  end

  % Make sure all showsrs2 figures have the same base size
  figUD = get(figuresToLink(n), 'UserData');
  if n == 1
    refFig = figuresToLink(n);
    refImageSize3D = figUD.imageSize3D;
  else
    currImageSize3D = figUD.imageSize3D;
    if ~isequal(currImageSize3D, refImageSize3D)
      error(sprintf(['Image size of showsrs2 figure %d [%d,%d,%d] does ', ...
        'not match showsrs2 figure %d [%d,%d,%d].  Figures NOT linked!'], ...
        figuresToLink(n), currImageSize3D(1), currImageSize3D(2), ...
        currImageSize3D(3), refFig, refImageSize3D(1), ...
        refImageSize3D(2), refImageSize3D(3)));
    end
  end
  
  % Use primary axis figure handle as figID so that it is not a reusable
  % handle (e.g. another figure that the user opens will not end up being
  % linked unintentionally)
  figIDs(n) = figUD.handles.imgAx;
  
  clear figUD
end

% Set links for each figure
for n = 1:length(figuresToLink)
  figUD = get(figuresToLink(n), 'UserData');
  figUD.linkedFigIDs = setdiff(figIDs,figIDs(n));
  set(figuresToLink(n), 'UserData', figUD);
end

%|--------------------------------------------------------------------
%|  Non-Callback local functions
%|--------------------------------------------------------------------

%------------------------LOCAL_PLOTTIMESRS----------------------------
function local_plottimesrs(handles,x,y,z,regenerateFlag)
% LOCAL_PLOTTIMESRS - Show time series plot for the point specified
%                   - Create plot figure, if needed
%
% local_plottimesrs(handles,x,y,z)
% local_plottimesrs(handles,x,y,z,regenerateFlag)
%    handles = structure of handles in showsrs2 window
%      x,y,z = x,y,z point to plot
%    regenerateFlag = force regeneration of all lines (default = 0); 
%

% TODO: Make turning lines on/off more efficient 
%       (i.e. don't grab or plot lines that are hidden)
% TODO: Store on/off status between plot figure locations.
%       (perhaps include this status as a field in the imageUD)

% Check number of input arguments
error(nargchk(4,5,nargin));
if nargin < 5, regenerateFlag=0; end

% Get figure UserData
figUD=get(handles.fig,'UserData');

% Get the data for base and each overlay
srs=cell(1,length(figUD.image_h));
srs_linecolor=cell(1,length(figUD.image_h));
srs_names = figUD.image_names;  % Grab the image names
for n=1:length(srs)
  imageUD=get(figUD.image_h(n),'UserData');  % Get the image info for the srs
  srs{n} = double(squeeze(imageUD.srs(x,y,z,:))'); % Extract current series to plot (make sure it is doubles)
  srs_linecolor{n} = imageUD.cmap(ceil(size(imageUD.cmap,1)/2),:); % Use the middle entry in the colormap for the line color
end
clear('imageUD');  % Done with imageUD so clear it

pltAxes=figUD.timePlotAxes;
showTimePlot = figUD.showTimePlot; % Keep this in case we need to create plot lines
%clear('figUD');  % Done with figUD so clear it (need for orig slice coords)
if isempty(pltAxes) | ~ishandle(pltAxes)
  % If there is not a plot axes already, make one in a new figure
  
  % Initialize plot figure (keyPress will make showsrs2 figure active)
  pltFig=figure('DoubleBuffer','on','Tag','pltFig',...
    'UserData',{handles.fig},'KeyPressFcn','figure(subsref(get(gcbf,''UserData''),struct(''type'',''{}'',''subs'',{{1}})));', ...
    'Name',sprintf('Plot for Figure %d',handles.fig),'DefaultTextInterpreter','none');
  colordef(pltFig,'none');   % Set default colors to 'none' scheme for this figure
  clear('pltFig');  % Clear it so that I don't use it later
  pltAxes=axes;  % Make a default axes filling the window
  
  % Store plot axes handle
  local_setUserDataField(handles.fig,'timePlotAxes',pltAxes);
end

% Get line handles from plot axes UserData
pltLine=get(pltAxes,'UserData');

% If regenerate flag set, delete current lines to force recreating them.
if regenerateFlag & ~isempty(pltLine)
  delete(pltLine); pltLine=[];
end

if isempty(pltLine)
  % There are no lines in the plot axes. Make them.
  axes(pltAxes); % Make pltAxes current axes
  
  % Make a line for base and each overlay
  lineColors={'w','r','b','g','m','c'};  % Colors to cycle through for lines
  pltLine=zeros(length(srs),1);
  for n=1:length(srs)
    % Generate a contextual menu to allow actions on line data
    contextMenu_h=uicontextmenu('Tag','IndividualLineMenu');

    % Create a line on the time series figure
    currColor=lineColors{mod(n-1,length(lineColors))+1};
    pltLine(n)=line(0,0,'Tag','timeSrs','Color',currColor,'uicontextmenu',contextMenu_h);
    
    % Generate contextual menu items to copy data to clipboard or to sent to Excel.
    % - Start with a menu item to identify which overlay you clicked on
    uimenu('Parent',contextMenu_h,'UserData',pltLine(n),'Label',['-- ' srs_names{n} ' --']);
    if ~isunix % toexcel only works on PCs
      uimenu('Parent',contextMenu_h,'UserData',pltLine(n),'Label','Send time series to Excel', ...
        'Callback','toexcel(get(get(gcbo,''UserData''),''YData'')'')');
    end
    uimenu('Parent',contextMenu_h,'UserData',pltLine(n),'Label','Copy time series to clipboard', ...
      'Callback','clipboard(''copy'',sprintf(''%.15g\n'',get(get(gcbo,''UserData''),''YData'')''))');
    
    set(pltLine(n),'XData',1:length(srs{n}));        % Set XData for line
    if length(srs{n}) == 1
      set(pltLine(n),'Marker','s','MarkerSize',4);
    end
  end
  
  % Store the handles to the lines in the plot axes UserData (to preserve the order)
  set(pltAxes,'UserData',pltLine);
  
  % Add a contextual menu to enable and disable lines
  % Store the showsrs2 figure handle in the UserData for plotLineMenuCallback
  contextMenu_h=uicontextmenu('Tag','PlotLineMenu','UserData',handles.fig);
  set(pltAxes,'uicontextmenu',contextMenu_h);
  
  % Use showTimePlot from figUD to determine which lines to display initially
  checkedArray = repmat({'Off'},length(pltLine),1);
  checkedArray(showTimePlot) = {'On'};
 
  % Callback toogles checkbox and refreshes time series plot.
  for n=1:length(srs)
    % Store the index into pltLine in the UserData to match menu items to images.
    uimenu('Parent',contextMenu_h,'Callback','showsrs2(''ShowTimePlot_Callback'',get(get(gcbo,''Parent''),''UserData''),gcbo);', ...
      'Label',srs_names{n},'Checked',checkedArray{n},'UserData',n);
  end
end

% Turn on/off the pltLines according to what is checked in the contextual menu
% Find the menu items that are checked
pltLineOn_i=get(findobj(get(pltAxes,'uicontextmenu'),'Checked','On'),'UserData');
if iscell(pltLineOn_i), pltLineOn_i=[pltLineOn_i{:}]; end % Pull values out of cell array.
pltLineOn_i=sort(pltLineOn_i);  % Put them in ascending order.
set(pltLine(pltLineOn_i),'visible','on');
set(pltLine(setxor(1:length(pltLine),pltLineOn_i)),'visible','off');

% Update time series plot
if strcmp(get(handles.UseImageColorsMenu,'Checked'),'on')
  for n=1:length(srs)
    set(pltLine(n),'YData',srs{n},'Color',srs_linecolor{n});
  end
else
  for n=1:length(srs)
    set(pltLine(n),'YData',srs{n});
  end
end  
% Update title with current point
% - Generate coordinates in original data
%   - Unflip
%   - Undo original reorient
origCoords = [x,y,z];
if strcmp(get(handles.FlipMenuRL,'Checked'),'on')
  origCoords(1) = figUD.imageSize3D(1) - x + 1;
end
if strcmp(get(handles.FlipMenuAP,'Checked'),'on')
  origCoords(2) = figUD.imageSize3D(2) - y + 1;
end
if strcmp(get(handles.FlipMenuSI,'Checked'),'on')
  origCoords(3) = figUD.imageSize3D(3) - z + 1;
end
origCoords(figUD.orient3DOrig2Native) = origCoords;

set(get(pltAxes,'title'),'String', ...
  sprintf('Disp (%d,%d,%d)  Orig (%d,%d,%d)',x,y,z,origCoords(1),origCoords(2),origCoords(3)));

% TODO: Don't call this every time.  It is slow
% Generate a legend if there are any overlays
% Place legend where it will least interfere with the data (last argument=0)
if length(pltLine) > 1 & strcmp(get(handles.ShowLegendMenu,'Checked'),'on') & ~isempty(pltLineOn_i)
  legend_h = legend(pltAxes,pltLine(pltLineOn_i),srs_names(pltLineOn_i),0);
  set(findobj(legend_h,'type','text'), 'Color', [1 1 1]);
  clear('legend_h');
else
  legend(pltAxes,'off');
end

%-----------------LOCAL_INITALIZEGUI----------------------------------
function handles = local_initializegui
% LOCAL_INITIALIZEGUI - Initialize showsrs2 GUI
%
% Brings up showsrs2 figure and returns a structure of handles to elements
% in the GUI.  The struct is similar to that returned by guihandles() in
% MATLAB 6 and later except it only includes some of the GUI elements.
%
% The handles structure and important resizing informaiton (resizeInfo) are
% stored in a structure in the figure UserData.  Use the following code to
% get the handles structure (where h is the handle of anything in the
% showsrs2 window of interest).
%   handles = subsref(get(getparentfigure(h),'UserData'),struct('type','.','subs','handles'));
%

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
handles.fig = colordef('new','none');
set(handles.fig,'Units','Characters','Position',pos,'DefaultUIControlInterruptible','Off',...
  'DoubleBuffer','off','KeyPressFcn','showsrs2(''KeyPress_Callback'',gcbo);','Tag','showsrs2()', ...
  'CloseRequestFcn','showsrs2(''CloseRequestFcn_Callback'',gcf)','Color',[0.3 0.3 0.3], ...
  'Interruptible','Off','MenuBar','Figure','DefaultTextInterpreter','none','visible','on');

% Create Axes for image
axesPos=[marginWidth, marginHeight+horControlHeight+sliderOffsetHeight, axesWidth, axesHeight];
imgAx_h=axes('Units','Characters','Position',axesPos,'Visible','off','YDir','reverse',...
  'XTick',[],'YTick',[],'NextPlot','Add','Layer','top','Tag','imgAx');
handles.imgAx = imgAx_h;

% Create base and overlay images on axes  - Moved to initialization section to handle n overlays

% Set DataAspectRatio of axis image
% NOTE: Default voxel size is isotropic.  Updated during the main initialization after the images put on the axis.
set(imgAx_h,'DataAspectRatio',[1 1 1]);

% Add the VCR buttons
handles.ToStartButton = uicontrol('Units','Characters','Style','PushButton','String','|<',...
  'Position',[marginWidth marginHeight vcrButtonWidth horControlHeight],...
  'Tag','ToStartButton','ToolTipString','To First Image','CallBack','showsrs2(''ToStart_Callback'',gcbo);');
handles.RevPlayButton = uicontrol('Units','Characters','Style','PushButton','String','<',...
  'Position',[marginWidth+vcrButtonWidth marginHeight vcrButtonWidth horControlHeight],...
  'Tag','RevPlayButton','ToolTipString','Reverse Play',...
  'CallBack','showsrs2(''Play_Callback'',gcbo,''RevPlay'');','Interruptible','On');
handles.StopButton = uicontrol('Units','Characters','Style','PushButton','String','[]',...
  'Position',[marginWidth+vcrButtonWidth*2 marginHeight vcrButtonWidth horControlHeight],...
  'Tag','StopButton','ToolTipString','Stop','CallBack','showsrs2(''Stop_Callback'',gcbo);');
handles.PlayButton = uicontrol('Units','Characters','Style','PushButton','String','>',...
  'Position',[marginWidth+vcrButtonWidth*3 marginHeight vcrButtonWidth horControlHeight],...
  'Tag','PlayButton','ToolTipString','Play','UserData','stop',...
  'CallBack','showsrs2(''Play_Callback'',gcbo,''Play'');','Interruptible','On');
handles.ToEndButton = uicontrol('Units','Characters','Style','PushButton','String','>|',...
  'Position',[marginWidth+vcrButtonWidth*4 marginHeight vcrButtonWidth horControlHeight],...
  'Tag','ToEndButton','ToolTipString','To Last Image','CallBack','showsrs2(''ToEnd_Callback'',gcbo);');
handles.LoopCheckbox = uicontrol('Units','Characters','Style','Checkbox','String','Loop',...
  'Position',[marginWidth+vcrButtonWidth*5+elementMarginWidth marginHeight loopBoxWidth horControlHeight],...
  'Tag','LoopCheckbox','ToolTipString','Loop around at ends during playback','Value',1,'CallBack','figure(gcbf);');
handles.DelayBox = uicontrol('Units','Characters','Style','Edit','String','0.0',...
  'Position',[marginWidth+vcrButtonWidth*5+2*elementMarginWidth+loopBoxWidth marginHeight loopTimeWidth horControlHeight],...
  'FontName','Arial Narrow','HorizontalAlignment','Left',...
  'Tag','DelayBox','ToolTipString','Interframe delay in seconds during playback','CallBack','showsrs2(''Delay_Callback'',gcbo);');

% Add Window and Level Button
%  UserData contains a cell array with the cmapLim and transLim for a
%  specifed layer.  This allows rapid updating of a single cmapLim and
%  transLim for a specified layer. (i.e. instead of having to update
%  the large image UserData.
%  Cell array contains: {layerNum, clim, translim}
%    layerNum - layer to update (index into figUD.image_h), [] for none.
%    cmapLim - two element clipping limits vector.
%    transLim - transparency limit
pos=get(findobj(handles.fig,'Tag','DelayBox'),'Position');
pos=[pos(1)+pos(3)+elementMarginWidth, pos(2), winlevButtonWidth, pos(4)];
%pos=[posTimeSlider(1)+posTimeSlider(3)+3, posSlider(2)-imgNumHeight-3, 22, imgNumHeight];
handles.WinlevButton = uicontrol('Units','Characters','Style','pushbutton','String','W+L','Position',pos,... %'FontName','Arial Narrow', ...
  'Tag','WinlevButton','ToolTipString','Window and level the image', ...
  'Callback','showsrs2_cfg(gcbf)','ButtonDownFcn','showsrs2_cfgtrans(gcbf)',...
  'UserData',{[],[0 1],1});

% Add the time slider and image number display
pos=[pos(1)+pos(3)+elementMarginWidth, pos(2), timePtWidth, horControlHeight];
handles.TimePt = uicontrol('Style','Text','FontName','Arial Narrow','Tag','TimePt',...
  'Units','Characters','Position',pos,'ToolTipString','Currently displayed time point');
pos=[pos(1)+pos(3), pos(2), axesWidth+marginWidth-pos(1)-pos(3), pos(4)];
handles.TimeSlider = uicontrol('Style','Slider','Tag','TimeSlider',...
  'Units','Characters','Position',pos,...
  'ToolTipString','Time point selection slider','CallBack','showsrs2(''TimeSlider_Callback'',gcbo);');

% Add the slice slider and image number display
pos=[axesPos(1)+axesPos(3)+sliderOffsetWidth, axesPos(2), verControlWidth, axesHeight-imgNumHeight];
handles.Slider = uicontrol('Style','Slider','Tag','Slider',...
  'Units','Characters','Position',pos,...
  'ToolTipString','Slice selection slider','CallBack','showsrs2(''SliceSlider_Callback'',gcbo);');
pos=[pos(1), pos(2)+pos(4), verControlWidth, imgNumHeight];
handles.ImgNum = uicontrol('Style','Text','FontName','Arial Narrow','Tag','ImgNum',...
  'Units','Characters','Position',pos,'ToolTipString','Currently displayed slice');

% Add Configuration menu
handles.ConfigMenu = uimenu('Parent',handles.fig,'Label','&Config','Tag','ConfigMenu');
handles.showsrs2_cfgMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2_cfg(gcbf)','Label','Adjust Colormaps and Clipping', ...
  'Checked','Off', 'Tag','showsrs2_cfgMenu');
handles.showsrs2_cfgtransMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2_cfgtrans(gcbf)','Label','Adjust Transparency', ...
  'Checked','Off', 'Tag','showsrs2_cfgtransMenu');
handles.ShowMarkersMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2(''ShowMarkersMenu_Callback'',gcbo,[])','Label','Show Crosshairs', ...
  'Checked','Off', 'Tag','ShowMarkersMenu','Separator','On');
handles.ShowLegendMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2(''ShowLegendMenu_Callback'',gcbo)','Label','Show Legend on Time Series Plot', ...
  'Checked','On', 'Tag','ShowLegendMenu');
handles.UseImageColorsMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2(''UseImageColorsMenu_Callback'',gcbo)','Label','Use Image Colors on Time Series Plot', ...
  'Checked','On', 'Tag','UseImageColorsMenu');
handles.UseTransMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2(''UseTransMenu_Callback'',gcbo)','Label','Use OpenGL Transparency', ...
  'Checked','On', 'Tag','UseTransMenu','Separator','On');
handles.ShowFigureMenuBarMenu = uimenu('Parent',handles.ConfigMenu,'Callback','showsrs2(''ShowFigureMenuBarMenu_Callback'',gcbo)','Label','Show Standard Figure Menus', ...
  'Checked','On', 'Tag','ShowFigureMenuBarMenu');

% Add Orientation menu
% Callback sets current menu item and refreshes display
% NOTE: Default orientation is Axial.  Updated during the main initialization after the images put on the axis.
cb='showsrs2(''ChangeOrientMenu_Callback'',gcbo);';
% Disable orientation menu by default (only enabled when a valid slice plane and voxel size are specified)
handles.OrientMenu = uimenu('Parent',handles.fig,'Label','&Orientation','Tag','OrientMenu','Enable','On');
handles.SpecifyOrientMenu = uimenu('Parent',handles.OrientMenu, ...
  'Callback','showsrs2(''SpecifyOrientMenu_Callback'',gcbo);', ...
  'Label','Specify Orientation','Checked','Off','Tag','SpecifyOrientMenu');
handles.AxialOrientMenu = uimenu('Parent',handles.OrientMenu,'Callback',cb,'Label','Axial','Checked','Off','Tag','AxialOrientMenu','Enable','Off');
handles.CoronalOrientMenu = uimenu('Parent',handles.OrientMenu,'Callback',cb,'Label','Coronal','Checked','Off','Tag','CoronalOrientMenu','Enable','Off');
handles.SagittalOrientMenu = uimenu('Parent',handles.OrientMenu,'Callback',cb,'Label','Sagittal','Checked','Off','Tag','SagittalOrientMenu','Enable','Off');
handles.ThreePlaneOrientMenu = uimenu('Parent',handles.OrientMenu,'Callback',cb,'Label','3 Orthogonal Planes','Checked','Off','Tag','ThreePlaneOrientMenu','Enable','Off');
cb='showsrs2(''FlipMenu_Callback'',gcbo);';
handles.FlipMenu = uimenu('Parent',handles.OrientMenu,'Label','Flip Images ...','Checked','Off','Tag','FlipMenu','Separator','On','Enable','off');
handles.FlipMenuRL = uimenu('Parent',handles.FlipMenu,'Callback',cb,'Label','Flip R-L','Tag','FlipMenuRL');
handles.FlipMenuAP = uimenu('Parent',handles.FlipMenu,'Callback',cb,'Label','Flip A-P','Tag','FlipMenuAP');
handles.FlipMenuSI = uimenu('Parent',handles.FlipMenu,'Callback',cb,'Label','Flip S-I','Tag','FlipMenuSI');

% Add save as JPEG and TIFF to file menu
handles.ImageToolsMenu = uimenu('Parent',handles.fig,'Label','&ImageTools','Tag','ImageToolsMenu');
handles.SaveAsJPEGMenu = uimenu('Parent',handles.ImageToolsMenu,'Callback','showsrs2(''SaveAsJPEGMenu_Callback'',gcbo)','Label','Save As JPEG','Tag','SaveAsJPEGMenu');
handles.SaveAsTIFFMenu = uimenu('Parent',handles.ImageToolsMenu,'Callback','showsrs2(''SaveAsTIFFMenu_Callback'',gcbo)','Label','Save As TIFF','Tag','SaveAsTIFFMenu');

% Find figure size minimums
% Note: Pad minimums by 15 (width character units) so that the sliders are still accessable
pos=get(findobj(handles.fig,'Tag','TimeSlider'),'Position');
minFigureWidth = pos(1)+15;
minFigureHeight = marginHeight*2+sliderOffsetHeight+horControlHeight+15*width2height;

% Save the resizing information in a structure 
% Note: axesMatrix is the number of rows and columns of axes
%       axesTopMargin,axesBottomMargin,axesLeftMargin,axesRightMargin are the
%         margins on each of the axes.
resizeInfo = struct('marginWidth',marginWidth,'marginHeight',marginHeight, ...
  'sliderOffsetWidth',sliderOffsetWidth,'sliderOffsetHeight',sliderOffsetHeight, ...
  'verControlWidth',verControlWidth,'horControlHeight',horControlHeight, ...
  'minFigureWidth',minFigureWidth,'minFigureHeight',minFigureHeight, ...
  'width2height',width2height,'height2width',height2width,'axesMatrix',[1 1], ...
  'axesTopMargin',[0],'axesBottomMargin',[0],'axesLeftMargin',[0],'axesRightMargin',[0]);

% Store the handles and resizeInfo structures in the figure UserData.
% Additional fields will be added during the rest of initialization.
set(handles.fig,'UserData',struct('handles',handles,'resizeInfo',resizeInfo));

% Set resize function for figure now that the 'UserData' necessary for the resize has been stored
set(handles.fig,'ResizeFcn','showsrs2(''Resize_Callback'',gcbf)');

%----------------------LOCAL_PARSEINPUTS-----------------------------------
function [baseInfo,overlayInfo,otherInfo]=local_parseInputs(varargin)
% local_parseInputs - Parse inputs into base and overlays
%
% This function parses the inputs to handle the various combinations of input 
% possibilities.
%
%   input: varargin for main function
%   output:
%     baseInfo is a structure containing the fields
%       baseInfo.cmap is the colormap (default gray(256))
%       baseInfo.srs is the base series for overlays
%       baseInfo.cmapLim is a vector containing the upper and lower 
%         clipping limits for the base image (default minmax(baseSrs))
%     overlayInfo is a structure containing the fields
%       overlayInfo.srs is the series to be overlaid on the base series
%       overlayInfo.cmap is the colormap (default determined by cmapDefaults)
%       overlayInfo.cmapLim is a vector containing the upper and lower 
%         clipping limits for the overlay image (default [3.6 8.0])
%       overlayInfo.transLim is the cutoff for transparency (default overlayInfo.cmapLim(1))
%         (overlaySrs < translim is transparent)
%       overlayInfo.transLevel is the amount of transparency (default 1.0)
%         (0 is translucent, 1 is opaque)
%       If no overlays were requested, overlayInfo = [];
%     otherInfo is a structure containing the fields
%       otherInfo.enableReorient is a boolean indicating if reorienting is enabled
%       otherInfo.origSlicePlane is a string indicating the original slice plane (empty if not specified)
%       otherInfo.orient3DOrig2Native is the permutation necessary to get from
%         the original orientation to the native orientation (Axial).
%       otherInfo.voxelSize is a vector of the voxel size of the image
%         (empty if not specified) the voxel size is for the reoriented images.
%       otherInfo.overlayArgIndex is the indicies into the argument array
%         of each overlay (for use in getting inputname of each overlay)
%       otherInfo.flipTag is a cell array of the tags from the flip menu
%         that should be checked.
%       otherInfo.imageNames is a cell array of the image names of each overlay (if available)
%       otherInfo.showTimePlot is a boolean vector of length overlayInfo + 1
%        indicating if this image's data should be shown in the timePlotAxes.
%
%   If baseInfo.enableOrient is true, then all the images are reoriented to Axial format (using orthosrs)
%

% Defaults colormaps
%  Applied in order to each passed overlay.
%  Any overlays greater than the number of defaults will use the first default
%  Cell array of cell arrays to be evaluated using feval
%
% TODO: Find colormaps for 4 and higher overlays
cmapDefaults = {{'redpos',256},{'blupos',256},{'greengrad',256,0.5,1.0}};

% Check number of input arguments
emsg = nargchk(1,inf,nargin); error(emsg);

% Initialize output structures baseInfo, overlayInfo, otherInfo
baseInfo = struct('srs',[],'cmap',[],'cmapLim',[]);
overlayInfo = struct('srs',[],'cmap',[],'cmapLim',[],'transLim',[],'transLevel',[]);
otherInfo = struct('enableReorient',0,'origSlicePlane','','voxelSize',[], ...
  'overlayArgIndex',[],'flipTag',{{}},'imageNames',{{}},'showTimePlot',{{}});

% --- Parse arguments ---
% First argument is the base series
if isstruct(varargin{1}) & isfield(varargin{1},'data')
  % Extract image data from data field.
  baseInfo.srs = varargin{1}.data;
  if isfield(varargin{1},'info')
    baseInfo.info = varargin{1}.info;
    otherInfo.imageNames{1} = baseInfo.info.displayname;
  else
    otherInfo.imageNames{1} = '';
  end
else
  baseInfo.srs = varargin{1};
  otherInfo.imageNames{1} = '';
end

% Check for baseCfg (empty or a structure) in second argument
origVoxelSize = [];
currArg = 2;
otherInfo.showTimePlot{1} = [];  % Set default showTimePlot
if nargin == 1 | isempty(varargin{currArg})
  % If there is only one input, then just a base image was passed (use defaults)  
  % If baseCfg is empty use defaults.
  currArg = currArg + 1;
elseif isnumeric(varargin{currArg}) | islogical(varargin{currArg}) | ...
    (isstruct(varargin{currArg}) & isfield(varargin{currArg},'data'))
  % Argument is an image.
  currArg = currArg; % Purely here for readability.
elseif isstruct(varargin{2}) % A structure, assign relevant fields to baseCfg
  if isfield(varargin{currArg},'cmap'), baseInfo.cmap = varargin{currArg}.cmap; end
  if isfield(varargin{currArg},'cmapLim'), baseInfo.cmapLim = varargin{currArg}.cmapLim; end
  if isfield(varargin{currArg},'voxelSize'), origVoxelSize = varargin{currArg}.voxelSize; end
  if isfield(varargin{currArg},'slicePlane'), otherInfo.origSlicePlane = varargin{currArg}.slicePlane; end
  if isfield(varargin{currArg},'showTimePlot'), otherInfo.showTimePlot{1} = varargin{currArg}.showTimePlot; end
  currArg = currArg + 1;
else
  emsg = sprintf('Argument %d must be an overlaySrs or baseCfg structure!',currArg);
  error(emsg);
end

% Grab overlays
if nargin < currArg
  % No more arguments left, just a base image was requested (no overlays)
  overlayInfo = [];
else
  % Additional arguments are overlaySrs's optionally followed by overlayCfg's
  nOverlays = 0;  % Counter for the number of overlays
  
  while currArg <= nargin 
    nOverlays = nOverlays + 1; % Increment number of overlays
    
    % Current argument should be overlaySrs
    if isstruct(varargin{currArg}) & isfield(varargin{currArg},'data')
      % Extract image data from data field.
      overlayInfo(nOverlays).srs = varargin{currArg}.data;
      if isfield(varargin{currArg},'info')
        otherInfo.imageNames{nOverlays+1} = varargin{currArg}.info.displayname;
      else
        otherInfo.imageNames{nOverlays+1} = '';
      end
    elseif isnumeric(varargin{currArg}) | islogical(varargin{currArg})
      % Just the image data
      overlayInfo(nOverlays).srs = varargin{currArg};
      otherInfo.imageNames{nOverlays+1} = '';
    else
      % Not an image.
      emsg = sprintf('Argument %d must be an overlaySrs!',currArg);
      error(emsg);
    end
    % Store index to current overlay (for getting inputname)
    otherInfo.overlayArgIndex(end+1) = currArg;
    
    % Initialize showTimePlot to empty (to indicate default should be used)
    otherInfo.showTimePlot{nOverlays+1} = [];
    
    % Initialize current overlayInfo structure to empties.
    % Note: I believe that this is actually already taken care of by the overlayInfo(nOverlays).srs array extension
    overlayInfo(nOverlays).cmap = [];
    overlayInfo(nOverlays).cmapLim = [];
    overlayInfo(nOverlays).transLim = [];
    overlayInfo(nOverlays).transLevel = [];
    
    % Next argument is a structure of overlay configuration parameters (optional if it is the last argument)
    if currArg == nargin | isempty(varargin{currArg+1})  
      % Last argument or cfg structure is empty, use defaults
      currArg = currArg + 2;  % Move to next argument pair
    elseif isnumeric(varargin{currArg+1}) | islogical(varargin{currArg+1}) | ...
        (isstruct(varargin{currArg+1}) & isfield(varargin{currArg+1},'data'))
      % Next argument is an image.  No cfg structure, use defaults
      currArg = currArg + 1;  % Move to next argument.
    elseif isstruct(varargin{currArg+1})
      % overlayCfg structure, extract any relevant fields
      if isfield(varargin{currArg+1},'cmap'),
        overlayInfo(nOverlays).cmap = varargin{currArg+1}.cmap; 
      end
      if isfield(varargin{currArg+1},'cmapLim'), 
        overlayInfo(nOverlays).cmapLim = varargin{currArg+1}.cmapLim; 
      end
      if isfield(varargin{currArg+1},'transLim'), 
        overlayInfo(nOverlays).transLim = varargin{currArg+1}.transLim;
      end
      if isfield(varargin{currArg+1},'transLevel'),
        overlayInfo(nOverlays).transLevel = varargin{currArg+1}.transLevel;
      end
      if isfield(varargin{currArg+1},'showTimePlot'),
        otherInfo.showTimePlot{nOverlays+1} = varargin{currArg+1}.showTimePlot;
      end
      currArg = currArg + 2;  % Move to next argument pair
    else
      emsg = sprintf('Argument %d must be an overlaySrs or overlayCfg structure',currArg+1);
      error(emsg);
    end  
  end
end

% --- Set defaults ---
if isempty(baseInfo.cmapLim),
  if isa(baseInfo.srs,'double'),
    % Use minmax if data are doubles
    baseInfo.cmapLim = minmax(baseInfo.srs);
  else
    % Otherwise use Mathworks min & max functions.
    baseInfo.cmapLim = double([min(baseInfo.srs(:)) max(baseInfo.srs(:))]);
  end
end
if isempty(baseInfo.cmap), baseInfo.cmap = gray(256); end
for n = 1:length(overlayInfo)
  if isempty(overlayInfo(n).cmapLim), overlayInfo(n).cmapLim = [3.6 8.0]; end
  if isempty(overlayInfo(n).cmap),
    if n > length(cmapDefaults)
      % Use the first cmapDefault if all have already been used
      overlayInfo(n).cmap = feval(cmapDefaults{1}{:});
    else
      % Use the nth colormap from cmapDefaults
      overlayInfo(n).cmap = feval(cmapDefaults{n}{:}); 
    end
  end
  if isempty(overlayInfo(n).transLim), 
    overlayInfo(n).transLim = overlayInfo(n).cmapLim(1); 
  end
  if isempty(overlayInfo(n).transLevel), 
    overlayInfo(n).transLevel = 1.0; % Default to opaque
  end
end

% Handle showTimePlot defaults and error checking
newShowTimePlot = logical(ones(1,length(overlayInfo)+1));
for n=1:length(overlayInfo)+1
  if isempty(otherInfo.showTimePlot{n})
    % Show overlays by default
    % Only show base if there are no overlays by default
    if n == 1 & length(overlayInfo) ~= 0
      newShowTimePlot(n) = logical(0);
    end
  else
    % User specified something.  Check it and make it logical
    if ~(isnumeric(otherInfo.showTimePlot{n}) | islogical(otherInfo.showTimePlot{n})) | ...
        length(otherInfo.showTimePlot{n}) > 1 | ~any(otherInfo.showTimePlot{n} == [0 1])
      error('showTimePlot option must be either 0 or 1!');
    end
    newShowTimePlot(n) = logical(otherInfo.showTimePlot{n});
  end
end
otherInfo.showTimePlot = newShowTimePlot;
clear newShowTimePlot

% --- Check input arguments ---
% Check base image
if ~any(ndims(baseInfo.srs) == [2 3 4]) | ~(isnumeric(baseInfo.srs) | islogical(baseInfo.srs)) | issparse(baseInfo.srs)
  emsg='base image must a 2,3,or 4D non-sparse numeric or logical array'; error(emsg);
end
% Check base configuration
if ~(isequal(size(baseInfo.cmapLim), [1 2]) | isequal(size(baseInfo.cmapLim), [2 1]) ...
    | (baseInfo.cmapLim(2) - baseInfo.cmapLim(1)) <= 0)
  emsg = 'base colormap limits must be [min max]'; error(emsg);
end
if ~(size(baseInfo.cmap,2) == 3 & isnumeric(baseInfo.cmap))
  emsg = 'base colormap must be n x 3 elements'; error(emsg);
end
% Loop through each overlay
for curr = 1:length(overlayInfo)
  % Check overlay image
  if ~any(ndims(overlayInfo(curr).srs) == [2 3 4]) | ~(isnumeric(overlayInfo(curr).srs) | islogical(overlayInfo(curr).srs)) ...
      | issparse(overlayInfo(curr).srs)
    emsg='overlay image must a 2,3,or 4D non-sparse numeric or logical array'; error(emsg);
  end
  
  % Check to make sure that base and overlay have same 4th dimension or 4th dimension is singular on one series
  if (size(baseInfo.srs,4)~=1) & (size(overlayInfo(curr).srs,4)~=1) & (size(baseInfo.srs,4) ~= size(overlayInfo(curr).srs,4))
    emsg='Overlay and Base must have the size in the 4th dimension or one of them must be 3D'; error(emsg);
  end
  
  % Check overlay configuration
  if ~(isequal(size(overlayInfo(curr).cmapLim), [1 2]) | isequal(size(overlayInfo(curr).cmapLim), [2 1]) ...
      | (overlayInfo(curr).cmapLim(2) - overlayInfo(curr).cmapLim(1)) <= 0)
    emsg = 'overlay colormap limits must be [min max]'; error(emsg);
  end
  if ~(size(overlayInfo(curr).cmap,2) == 3 & isnumeric(overlayInfo(curr).cmap))
    emsg = 'overlay colormap must be n x 3 elements'; error(emsg);
  end
  if ~((ndims(overlayInfo(curr).transLim) == 2) & all(size(overlayInfo(curr).transLim) == [1 1]) & isnumeric(overlayInfo(curr).transLim))
    emsg = 'overlay transparency limit must be a single number'; error(emsg)
  end
  if overlayInfo(curr).transLim < overlayInfo(curr).cmapLim(1) | overlayInfo(curr).transLim > overlayInfo(curr).cmapLim(2)
    emsg = 'overlay transparency limit must be in the range: cmapLim(1) <= transLim <= cmapLim(2)'; error(emsg);
  end
  if overlayInfo(curr).transLevel < 0 | overlayInfo(curr).transLevel > 1
    emsg = 'overlay transparency level must be in the range: 0 <= transLevel <= 1'; error(emsg);
  end
end

% Check that all overlays have the same size in the 4th dimension or be 3D
if ~isempty(overlayInfo)
  for curr = 1:length(overlayInfo), nTimePts(curr) = size(overlayInfo(curr).srs,4); end
  if ~all((nTimePts==max(nTimePts)) | (nTimePts==1))
    emsg='All 4D overlays must have a the same size in the 4th dimension'; error(emsg); 
  end
end

% If base image has .info & it has more than one slice, try and determine orientation and voxel size from it 
if isfield(baseInfo,'info') & size(baseInfo.srs,3) > 1
  % --- Attempt to determine orientation of base ---
  % Try to get RAS flag for base.
  try
    rasflag=getorientation(baseInfo);
  catch
    % TODO: Figure out better user feedback mechanism.  This is just annoying!
    %     waitfor(warndlg(sprintf(['Unable to determine orientation from base image header.  \n', ...
    %         'getorientation returned:\n %s'],lasterr) , ...
    %       'Unable to determine orientation','modal'));
    rasflag='';
  end
  if ~isempty(rasflag)
    % Convert RAS flag to 'Axial','Coronal','Sagittal'
    simpleflag=rasflag;
    simpleflag(find(simpleflag=='l'))='r';
    simpleflag(find(simpleflag=='p'))='a';
    simpleflag(find(simpleflag=='i'))='s';
    infoFlipTag = {}; % Default to no flips
    switch simpleflag(1:2)
      case 'ra'
        infoSlicePlane = 'Axial';
        if rasflag(3) == 's'
          infoFlipTag = {'FlipMenuSI'}; 
        end
      case 'rs'
        infoSlicePlane = 'Coronal';
        if rasflag(3) == 'a'
          infoFlipTag = {'FlipMenuAP'}; 
        end
      case 'as'
        infoSlicePlane = 'Sagittal';
        if rasflag(3) == 'r'
          infoFlipTag = {'FlipMenuRL'}; 
        end
      otherwise
        infoSlicePlane = '';
        waitfor(warndlg(sprintf(['Unable to determine orientation from base image header.  \n', ...
            'Unrecognized RAS Flag %s'],rasflag) , ...
          'Unable to determine orientation','modal'));
    end
    clear simpleflag
    % Compare against specified slicePlane
    if ~isempty(infoSlicePlane)
      % Found a slice plane from info field, compare it against specified slicePlane
      if ~isempty(otherInfo.origSlicePlane) & ~strcmp(otherInfo.origSlicePlane,infoSlicePlane)
        waitfor(warndlg(sprintf(['Specifed slice plane (%s) does not match automatically determined slice plane (%s).  Using %s'], ...
          otherInfo.origSlicePlane,infoSlicePlane,otherInfo.origSlicePlane), ...
          'Orientation mismatch','modal'));
      else
        otherInfo.origSlicePlane=infoSlicePlane;
      end
    end
    clear infoSlicePlane
    % Store the flipTag
    otherInfo.flipTag = infoFlipTag;
  end % determined rasflag
  clear rasflag

  % --- Attempt to determine voxelSize of base ---
  try
    infoVoxelSize=[baseInfo.info.dimensions(1:3).spacing];
  catch
    waitfor(warndlg(sprintf(['Unable to determine voxel size from base image header.  \n', ...
        'voxelSize=[baseInfo.info.dimensions(1:3).spacing; Failed']), ...
      'Unable to determine voxel size','modal'));
    infoVoxelSize=[];
  end
  if ~isempty(infoVoxelSize) & any(isnan(infoVoxelSize)) 
    if ~all(isnan(infoVoxelSize))
      % Only display feedback if at least one spacing was specified. (Otherwise it is just annoying)
      waitfor(warndlg(sprintf(['Unable to determine voxel size from base image header.  \n', ...
          'Spacing must be specifed for x, y, and z dimensions']), ...
        'Unable to determine voxel size','modal'));
    end
    infoVoxelSize=[];
  end
  if ~isempty(infoVoxelSize) & any(infoVoxelSize <= 0) 
    waitfor(warndlg(sprintf(['Unable to determine voxel size from base image header.  \n', ...
        'Spacing must be positive for x, y, and z']), ...
      'Unable to determine voxel size','modal'));
    infoVoxelSize=[];
  end  
  % Compare against specified voxelSize
  if ~isempty(infoVoxelSize)
    % Found a voxel size from info field, compare it against specified voxelSize
    if ~isempty(origVoxelSize) & ~all(origVoxelSize==infoVoxelSize)
      waitfor(warndlg(sprintf(['Specifed voxel size [%g, %g, %g] does not match ', ...
          'automatically determined voxelsize [%g, %g, %g].  Using [%g, %g, %g]'], ...
        origVoxelSize(1),origVoxelSize(2),origVoxelSize(3),...
        infoVoxelSize(1),infoVoxelSize(2),infoVoxelSize(3),...
        origVoxelSize(1),origVoxelSize(2),origVoxelSize(3)), ...
        'Voxel size mismatch','modal'));
    else
      origVoxelSize=infoVoxelSize;
    end
  end
  clear infoVoxelSize
end

% If the voxelSize & slicePlane were passed and are valid, reorient all of the images to Axial
% NOTE: Make both orientation and voxel size empty if either are missing or invalid.
% TODO: Check them independently and use as defaults in GUI specification of orientation.
otherInfo.enableReorient = 0;  % Disable reorientation by default
otherInfo.voxelSize = [];      % Set voxel size to empty by default
otherInfo.orient3DOrig2Native = [1 2 3]; % No permutation by default
if isempty(origVoxelSize) & ~isempty(otherInfo.origSlicePlane)
  % Has slice plane but not voxel size
  % TODO: Do we need this anymore since user can specify after launch?
  waitfor(warndlg(sprintf(['Unable to determine voxel size.  \n', ...
      'Please specify using orientation menu.']), ...
    'Unable to determine voxel size','modal'));
  otherInfo.origSlicePlane = '';  % Return empty unless both are valid.
elseif ~isempty(origVoxelSize) & isempty(otherInfo.origSlicePlane)
  % Has voxel size but not slice plane
  % TODO: Do we need this anymore since user can specify after launch?
  waitfor(warndlg(sprintf(['Unable to determine slice plane.  \n', ...
      'Please specify using orientation menu.']), ...
    'Unable to determine slice plane','modal'));
elseif ~isempty(origVoxelSize) & ~isempty(otherInfo.origSlicePlane)
  % Both specified, check them
  if any(sort(size(origVoxelSize)) ~= [1 3]) | ~isnumeric(origVoxelSize) | ...
      ~isreal(origVoxelSize) | any(origVoxelSize <= 0)
    % Bad voxel size
    waitfor(warndlg(sprintf(['Voxel size must be a three element vector of positive real numbers!  \n', ...
        'Please specify using orientation menu.']), ...
      'Unable to determine voxel size','modal'));
    otherInfo.voxelSize = []; % Invalid, return empty.
    otherInfo.origSlicePlane = ''; % Return empty unless both are valid.
  elseif ~any(strcmp(otherInfo.origSlicePlane,{'Axial','Sagittal','Coronal'}))
    % Bad orientation.
    waitfor(warndlg(sprintf(['Slice plane %s unknown.  \n', ...
        'Valid slice planes are Axial, Sagittal, or Coronal.  \n', ...
        'Please specify using orientation menu.'],otherInfo.origSlicePlane), ...
      'Unable to determine slice plane','modal'));
    otherInfo.voxelSize = []; % Return empty unless both are valid.
    otherInfo.origSlicePlane = ''; % Invalid, return empty.
  else
    % Everything is okay
    otherInfo.enableReorient = 1;  % Enable reorientation
    % Reorient the images to axial
    % TODO: Check that base and overlay have the same orientation.
    baseInfo.srs = orthosrs(baseInfo.srs,otherInfo.origSlicePlane);
    for n = 1:length(overlayInfo)
      overlayInfo(n).srs = orthosrs(overlayInfo(n).srs,otherInfo.origSlicePlane);
    end
    % Determine the permuation necessary to get from the current data
    % orientation to the native data orientation (Axial)
    switch otherInfo.origSlicePlane
      case 'Axial'
        otherInfo.orient3DOrig2Native = [1 2 3]; % Axial->Axial
      case 'Coronal'
        otherInfo.orient3DOrig2Native = [1 3 2]; % Coronal->Axial
      case 'Sagittal'
        otherInfo.orient3DOrig2Native = [3 1 2]; % Sagittal->Axial
      otherwise
        emsg=sprintf('Slice plane %s unknown.  Please chose Axial, Sagittal or Coronal!',baseInfo.origSlicePlane); error(emsg)
    end
    % Reorient the voxel size so that it is correct for the reoriented images
    otherInfo.voxelSize = origVoxelSize(otherInfo.orient3DOrig2Native);
  end
end

% flip all images before scale (if necessary)
for flip = otherInfo.flipTag
  flip = flip{1};
  switch flip
   case 'FlipMenuRL', dim=1;
   case 'FlipMenuRL', dim=1;
   case 'FlipMenuAP', dim=2;
   case 'FlipMenuSI', dim=3;
   otherwise, error('Invalid menu item for FlipMenu_Callback');
  end
  baseInfo.srs = flipdim(baseInfo.srs,dim);
  for n=1:length(overlayInfo)
    overlayInfo(n).srs = flipdim(overlayInfo(n).srs,dim);
  end
end

for curr = 1:length(overlayInfo)
  % Interpolate overlay up to base image size (if necessary)
  scale=[size(baseInfo.srs,1)/size(overlayInfo(curr).srs,1), ...
      size(baseInfo.srs,2)/size(overlayInfo(curr).srs,2), ...
      size(baseInfo.srs,3)/size(overlayInfo(curr).srs,3)];
  if scale(1) ~= scale(2)
    % Warn user if there are different scale factors in x & y to avoid
    % inadvertant mistakes
    waitfor(warndlg('Interpolation factor different in x & y dimensions!  Did you really mean to do this???', ...
      'Interpolation factor different in x & y dimensions','modal'));
  end
  if any(scale~=1)
    if any(~isint(scale)) % Only allow integer scale factors (scale3 & zeros expects this)
      emsg='Overlay interpolation must use an integer scale factor'; error(emsg);
    end
    % Save original.  Convert to a double if necessary because scale3
    % (trilinear) only works with doubles.
    if isa(overlayInfo(curr).srs, 'double')
      overlaySrsOrig = overlayInfo(curr).srs;
    else
      overlaySrsOrig = double(overlayInfo(curr).srs);
    end
    overlayInfo(curr).srs = zeros(size(overlayInfo(curr).srs,1).*scale(1), ...
      size(overlayInfo(curr).srs,2).*scale(2), ...
      size(overlayInfo(curr).srs,3).*scale(3),size(overlayInfo(curr).srs,4)); % Initialize output array
    for n=1:size(overlayInfo(curr).srs,4) % Scale each time Pt
      overlayInfo(curr).srs(:,:,:,n)=scale3(overlaySrsOrig(:,:,:,n),scale(1),scale(2),scale(3));
    end
  end
end

%------------------------local_updatedisplay----------------------------------
function local_updatedisplay(handles,loc,speedFlag)
% local_updatedisplay - Update the display to the passed x,y,z and timePt
%
% local_updatedisplay(handles,loc,speedInfo)
%
%  handles - structure of handles for each of the elements in the showsrs2 GUI
%      (returned by function guihandles)
%  loc - [x,y,z,t] coordinate to display (with respect to oritentation in imgAx)
%  speedFlag -> ==0 - Full refresh of all image. (default)
%            -> ==1 - Only the time point has changed.  Assume that the slice
%                   is unchanged, so only images with multiple time points
%                   need to be updated.  Can be used for efficient animation
%                   along time.
%            -> ==2 - Only one layer need to updated.  Only update the
%                   layer specified in the W+L button UserData cell array.
%                     {layerNum, clim, translim}
%                     layerNum - layer to update (index into figUD.image_h)
%                      cmapLim - two element clipping limits vector.
%                     transLim - transparency limit
%
% NOTE: This function is intended for use by showsrs2 and showsrs2_cfg callback only!
%

if nargin < 3, speedFlag = 0; end % Default to display everything.

% Extract the location to display
x = loc(1); y = loc(2); z = loc(3); timePt = loc(4);

% Get showsrs2 figure data
fig_ud=get(handles.fig,'UserData');

% Determine which time point to display for each image
% (Number of time points in each image cached in figure UserData for efficiency)
timePts = timePt*ones(size(fig_ud.image_h));
timePts(fig_ud.timePts == 1) = 1;  % Set all single time point images to display time point 1

% Grab fast layer {layerNum, cmapLim, transLim} stored in the W+L UserData 
% (see local_initializegui)
fastLayerInfo = get(handles.WinlevButton,'UserData');

if strcmp(get(handles.UseTransMenu,'Checked'),'on')
  % Use OpenGL transparency to generate overlays.
  %   The base image and each overlay are on separate images for each axes
  %   with AlphaData set such that images show through appropriately.
  
  % Determine image layers to display
  if speedFlag == 0
    % Update all layers
    layers2display = 1:length(fig_ud.image_h);
  elseif speedFlag == 1
    % Only update an image if it has more than one time point (assumes slices did not change)
    layers2display = find(fig_ud.timePts ~= 1);
  elseif speedFlag == 2
    % Just display layer from fastLayersInfo array.
    layers2display = fastLayerInfo{1};
  else
    error('Invalid speedFlag!');
  end
  
  % Loop through images to be displayed
  for n = layers2display
    image_ud = get(fig_ud.image_h(n),'UserData');  % Get image UserData
    
    % Determine transLim & cmapLim  (image_ud.cmap is always used)
    if isempty(fastLayerInfo{1}) | fastLayerInfo{1} ~= n
      % This is not a "fast layer", get the limits from the image_ud
      cmapLim = image_ud.cmapLim;
      if n ~= 1, transLim = image_ud.transLim; end % Overlays
    else
      % This is a "fast layer" get the transLim and cmapLim from the
      % fastLayerInfo array.
      cmapLim = fastLayerInfo{2};
      if n ~= 1, transLim = fastLayerInfo{3}; end % Overlays
    end
      
    % Generate a vector of all image handles which need to be updated using this data
    allImages_h = [fig_ud.image_h(n), fig_ud.image_h_otherImages{n}];
    
    % Loop through each image handle for this data
    for allImages_h_n = 1:length(allImages_h)
        
      % Get the current raw image data using the getImageString from the axis UserData
      % The getImageString expects the following variables to be defined:
      %   image_ud.srs - n-d image data
      %          x,y,z - currently selected spatial coordinates in first
      %                  three dimensions of image_ud.srs
      %     timePts(n) - currently selected time point to be displayed
      ax_ud = get(get(allImages_h(allImages_h_n),'Parent'),'UserData');
      currImageData = eval(ax_ud.getImageString);
      
      % Convert data to a double if it is not already.
      if ~isa(currImageData,'double'),
        currImageData=double(currImageData);
      end
      
      % Display image (convert to RGB & calculate transLim mask)
      if n == 1 % Base
        % Just display CData for base image
        set(allImages_h(allImages_h_n),'CData',scaled2rgb(currImageData,image_ud.cmap,cmapLim));
      else % Overlays
        % Display CData & AlphaData for overlays
        set(allImages_h(allImages_h_n),'CData',scaled2rgb(currImageData,image_ud.cmap,cmapLim), ...
          'AlphaData',(currImageData >= transLim).*n);
      end
    end % end for images_h
  end % End loop through images
else
  % Do NOT use OpenGL transparency to generate image.
  %   Merge the images "by hand" into a single image for each axes.
  %   Calculate transparency effects "by-hand"
  %   Loop through images to be displayed
  %
  % Note: speedFlag flag is irrelevant for this case.  Since the layers are
  %       merged, all layers must be regenerated to create the new image.

  % Determine transLim & cmapLim for base and each overlay (image_ud.cmap is always used)
  cmapLim=zeros(length(fig_ud.image_h),2);
  transLim=zeros(length(fig_ud.image_h),1);
  for n = 1:length(fig_ud.image_h)
    if isempty(fastLayerInfo{1}) | fastLayerInfo{1} ~= n
      % This is not a "fast layer", get the limits from the image_ud
      image_ud = get(fig_ud.image_h(n),'UserData');  % Get image UserData
      cmapLim(n,:) = reshape(image_ud.cmapLim,[1,2]);
      if n ~= 1, transLim(n) = image_ud.transLim; end % Overlays
    else
      % This is a "fast layer" get the transLim and cmapLim from the
      % fastLayerInfo array.
      cmapLim(n,:) = reshape(fastLayerInfo{2},[1,2]);
      if n ~= 1, transLim(n) = fastLayerInfo{3}; end % Overlays
    end
  end
  
  % Only show images with a transparency greater than zero.
  amap=get(handles.UseTransMenu,'UserData');  % [0, one entry for each overlay]
  amap(1) = 1;  % Always show base image
  layers2display = find(amap > 0);
  
  % Generate a vector of all image handles which need to be updated using this data
  % image_h(1) - Base image of main axes
  % image_h_otherImages{1} - Base image of other axes
  allImages_h = [fig_ud.image_h(1), fig_ud.image_h_otherImages{1}];
  
  % Loop through each image handle to be updated
  for allImages_h_n = 1:length(allImages_h)
    % Get axis UserData (contains string to generate desired orientation).
    ax_ud = get(get(allImages_h(allImages_h_n),'Parent'),'UserData'); % Get axis UserData

    % Compose the image to be displayed
    for n = layers2display % Loop through layers to be displayed.
      image_ud = get(fig_ud.image_h(n),'UserData');  % Get image UserData
      
      % The getImageString expects the following variables to be defined:
      %   image_ud.srs - n-d image data
      %          x,y,z - currently selected spatial coordinates in first
      %                  three dimensions of image_ud.srs
      %     timePts(n) - currently selected time point to be displayed
      currImageData = eval(ax_ud.getImageString);  % Get the current raw image data
      
      % Convert data to a double if it is not already.
      if ~isa(currImageData,'double'),
        currImageData=double(currImageData);
      end
      
      % Create RGB image of data
      currImageDataRGB = scaled2rgb(currImageData,image_ud.cmap,cmapLim(n,:));
      
      % Merge data
      if n == 1
        mergedImage = currImageDataRGB;
      else
        % Find visibile voxels
        mask = repmat(currImageData >= transLim(n),[1 1 3]);
        % Do two pixel Alpha blending
        % (http://www.gamedev.net/reference/articles/article320.asp)
        % TODO: Determine if this is the proper way to combine multiple
        % layers, or if another method is better/correct???
        mergedImage(mask) = uint8(round(double(mergedImage(mask)).*(1-amap(n)) +  ...
          double(currImageDataRGB(mask)).*amap(n)));
      end
    end % end for images_h
    
    % Display image
    set(allImages_h(allImages_h_n),'CData',mergedImage);  
  end % end for allImages_h
end

% --------------------------------------------------------------------
function local_updatepoint(handles, newPoint, createTimeSeriesPlot, updateLinkedFigures)
% Set displayed point to specified point and update display
%
%  Updates current point, set slice slider, refreshes all images, updates
%  time series plot (if it exists or createTimeSeriesPlot), and updates
%  markers 
%
%  local_updatepoint(handles, newPoint, createTimeSeriesPlot)
%    handles - structure of handles for each of the elements in the showsrs2 GUI
%      (returned by function guihandles)
%    newPoint - a 3 element vector specifying point to set display to
%               (Order of elements based on stored orientation of data)
%    createTimeSeriesPlot - create a time series plot if one does not
%      already exist. (default = 0)
%    updateLinkedFigures - Update current point on linked figures also.
%      (default = 1)
%
% NOTE: This should be the ONLY place that the current point (stored in
%       handles.Slider UserData) should be changed!
%
% NOTE: Does not check arguments!  Check before calling function!

% Set defaults
if nargin < 3, createTimeSeriesPlot = 0; end
if nargin < 4, updateLinkedFigures = 1; end

% Updated stored point
set(handles.Slider,'UserData',newPoint);
 
% If using a slider, update the slice slider for newPoint
if strcmp(get(handles.Slider,'Enable'),'on')
  % Note: the primary image axis (handles.imgAx) contains a vector
  %       of the mapping of the stored plane to the displayed image
  %       in the structure field toScreenPlane.  The third value is
  %       the dimension which is slice in the displayed image
  ax_ud = get(handles.imgAx, 'UserData');
  slice = newPoint(ax_ud.toScreenPlane(3));
  set(handles.Slider, 'Value', -slice);
  set(handles.ImgNum, 'String', num2str(slice));
  clear ax_ud slice
end

% Refresh display
showsrs2('Refresh_Callback',handles.fig);

% Plot time series if requested or it already exists
figUD = get(handles.fig,'UserData');
if createTimeSeriesPlot | (~isempty(figUD.timePlotAxes) & ishandle(figUD.timePlotAxes))
  local_plottimesrs(handles,newPoint(1),newPoint(2),newPoint(3));
end
clear figUD

% Update markers
local_updatemarker(handles,newPoint(1),newPoint(2),newPoint(3));

% Update linked showsrs2 figures
if updateLinkedFigures
  % Grab info for this figure
  figUD = get(handles.fig,'UserData');
  linkedFigIDs = figUD.linkedFigIDs;
  refImageSize3D = figUD.imageSize3D;
  clear figUD
  
  % Use primary axis figure handle as figID so that it is not a reusable
  % handle (e.g. another figure that the user opens will not end up being
  % linked unintentionally)
  badFigures = [];
  for linkedFigID = linkedFigIDs
    if ~ishandle(linkedFigID)
      % Primary axes handle does not exist, therefore user closed window
      % sliently remove from list and continue
      badFigures(end+1) = linkedFigID;
      continue
    end
    
    % Grab showsrs2 figure handle
    linkedFig = getparentfigure(linkedFigID);
    
    if ~strcmp(get(linkedFig,'Tag'),'showsrs2()')
      % This is NOT a showsrs2 window.  This should never happen...
      warning(sprintf(['linkedFigIDs %g from %g is not from showsrs2 figure!\n', ...
        'There is a bug in the code.  Please send this warning to a showsrs2 developer!\n', ...
        'Removing link to this figure'], linkedFigID, linkedFig));
      get(linkedFigID)  % Display the info on this handle
      badFigures(end+1) = linkedFigID;
      continue
    end
    
    linkedFigUD = get(linkedFig, 'UserData');
    linkedImageSize3D = linkedFigUD.imageSize3D;
    
    % Make sure the showsrs2 figure has the same base size
    if ~isequal(linkedImageSize3D, refImageSize3D)
      warndlg(sprintf(['Image size of showsrs2 figure %d [%d,%d,%d] ', ...
        'does not match showsrs2 figure %d [%d,%d,%d].  Removing link ', ...
        'between figures.  This may happen if you use the "Specify ', ...
        'Orientation" menu on one, but no the other figure.'], ...
        linkedFig, linkedImageSize3D(1), linkedImageSize3D(2), ...
        linkedImageSize3D(3), handles.fig, refImageSize3D(1), ...
        refImageSize3D(2), refImageSize3D(3)), 'Removing link');
      badFigures(end+1) = linkedFigID;
      continue
    end
    
    % Update the linked figure
    local_updatepoint(linkedFigUD.handles, newPoint, createTimeSeriesPlot, 0);
    clear linkedFigUD
    
    % TODO: Turn on cursors???
    
  end % for linkedFigIDs
  
  % Remove any bad figures found
  % TODO: Remove bad figures in all showsrs2 windows linked also.
  if ~isempty(badFigures)
    figUD = get(handles.fig,'UserData');
    figUD.linkedFigIDs = setdiff(figUD.linkedFigIDs, badFigures);
    set(handles.fig,'UserData',figUD);
  end
  
  % Return focus to original figure
  figure(handles.fig)
  
end % if updateLinkedFigures

%------------------------local_changeOrientation-------------------------------
function local_changeOrientation(handles)
% local_changeOrientation - Change the image orientation
%
%  local_changeOrientation(handles)
%
%  handles - structure of handles for each of the elements in the showsrs2 GUI
%      (returned by function guihandles)
%  orientation is changed to the checked item in the handles.OrientMenu
%
% NOTE: This function changes the axes UserData
%

% Make sure that orientation is not disabled
if strcmp(get(handles.AxialOrientMenu,'Enable'),'Off')
  error('Unable to change orientation! Orientation menu is disabled!');
end

% Determine orientation to be displayed & update display strings
currOrientMenuCnt=0;
if strcmpi(get(handles.AxialOrientMenu,'Checked'),'On'),
  currOrientMenuTag='AxialOrientMenu';
  currOrientMenuCnt=currOrientMenuCnt+1;
end
if strcmpi(get(handles.CoronalOrientMenu,'Checked'),'On')
  currOrientMenuTag='CoronalOrientMenu';
  currOrientMenuCnt=currOrientMenuCnt+1;
end
if strcmpi(get(handles.SagittalOrientMenu,'Checked'),'On')
  currOrientMenuTag='SagittalOrientMenu';
  currOrientMenuCnt=currOrientMenuCnt+1;
end
if strcmpi(get(handles.ThreePlaneOrientMenu,'Checked'),'On')
  currOrientMenuTag='ThreePlaneOrientMenu';
  currOrientMenuCnt=currOrientMenuCnt+1;
end
if currOrientMenuCnt ~= 1
  error('Unable to determine current orientation!');
end

% Get showsrs2 primary image axis UserData
ax_ud=get(handles.imgAx,'UserData');

% Handle menu options
if any(strcmp(currOrientMenuTag,{'AxialOrientMenu','CoronalOrientMenu','SagittalOrientMenu'}))
  % Handle single axis views
  
  local_changeNumberAxes(handles,1,1); % Set to single axes
  currPoint=get(handles.Slider,'UserData'); % Find current point

  % Get showsrs2 figure data 
  % NOTE: Figure UserData must be loaded after local_changeNumberAxes since
  %       this function changes the UserData.
  fig_ud=get(handles.fig,'UserData');
  
  switch currOrientMenuTag
  case 'AxialOrientMenu'
    %disp('Displaying Axial: [1 2 3]');
    ax_ud.getImageString='permute(image_ud.srs(:,:,z,timePts(n)),[2 1 3 4])';
    ax_ud.toScreenPlane=[1 2 3];
  case 'CoronalOrientMenu'
    %disp('Displaying Coronal: [1 3 2]');
    ax_ud.getImageString='permute(image_ud.srs(:,y,:,timePts(n)),[3 1 2 4])';
    ax_ud.toScreenPlane=[1 3 2];
  case 'SagittalOrientMenu'
    %disp('Displaying Sagittal: [2 3 1]');
    ax_ud.getImageString='permute(image_ud.srs(x,:,:,timePts(n)),[3 2 1 4])';
    ax_ud.toScreenPlane=[2 3 1];
  end

  % Determine data aspect ratio, 3D size, and current slice for current orientation
  voxelDataAspect=fig_ud.voxelSize(ax_ud.toScreenPlane);
  currImageSize3D=fig_ud.imageSize3D(ax_ud.toScreenPlane);
  currSlice=currPoint(ax_ud.toScreenPlane(3));
  
  % Store the updated display ax_ud, set DataAspectRatio, update axis limits
  set(handles.imgAx,'UserData',ax_ud, ...
    'DataAspectRatio',voxelDataAspect([2 1 3]), ...
    'XLim',[0.5,currImageSize3D(1)+0.5],'YLim',[0.5,currImageSize3D(2)+0.5]);
  
  % Move the image to currSlice & update the slice slider limits
  set(handles.ImgNum,'String',num2str(currSlice));
  if currImageSize3D(3) > 1
    set(handles.Slider,'Min',-currImageSize3D(3),'Max',-1,'Value',-currSlice,'SliderStep',[min(0.999,1/(currImageSize3D(3)-1)) max(0.1,min(1,2/(currImageSize3D(3)-1)))]);
  else
    set(handles.Slider,'Min',-1.001,'Max',-0.999,'Value',-1,'SliderStep',[0 0.001],'Enable','off');
  end
  set(handles.Slider,'Enable','on'); % Enable slider
  
  % Update figure UserData 'image_h_otherImages' to indicate the that there are no other images
  local_setUserDataField(handles.fig,'image_h_otherImages',cell(size(fig_ud.image_h)));
    
elseif strcmp(currOrientMenuTag,'ThreePlaneOrientMenu')
  % Handle 3-plane orthogonal view
  
  % Set to 2x2 axes
  ax_h=local_changeNumberAxes(handles,2,2,[0 0; 0 1.8],[0 0; 0 1.8],[0 0; 0 8],[0 0; 0 0]);
  timePlotAxes = ax_h(3); % Use four axes for plotting time series
  ax_h=ax_h(1:2);   % Only plotting on first three axes (Note: Also need to include handles.imgAx)

  % Get showsrs2 figure data 
  % NOTE: Figure UserData must be loaded after local_changeNumberAxes since
  %       this function changes the UserData.
  fig_ud=get(handles.fig,'UserData');

  % Generate images on each axes (base + number of overlays)
  % Note: AlphaDataMapping will be setup by ShowMarkersMenu_Callback
  image_h=zeros(length(ax_h),length(fig_ud.image_h));
  for ax_h_n=1:length(ax_h)
    axes(ax_h(ax_h_n));
    for image_h_n=1:length(fig_ud.image_h)
      image_h(ax_h_n,image_h_n)=image([],'CDataMapping','Direct', ...
        'EraseMode','Normal', ...
        'ButtonDownFcn','showsrs2(''Click_Callback'',gcbo);');
    end
  end
  
  % Plot the time series in the fourth axes
  if ~isempty(fig_ud.timePlotAxes) & ishandle(fig_ud.timePlotAxes)
    delete(getparentfigure(fig_ud.timePlotAxes));
  end
  % Set the axes up for displaying time series
  set(timePlotAxes,'Visible','on','YDir','normal',...
    'XTickLabelMode', 'auto','XTickMode','auto', ...
    'YTickLabelMode', 'auto','YTickMode','auto', ...
    'NextPlot','replace','Layer','bottom','Color','black');  
  local_setUserDataField(handles.fig,'timePlotAxes',timePlotAxes);
  
  % Store image handles for each base & overlay in otherImages
  image_h_otherImages = cell(size(fig_ud.image_h));
  for image_h_n=1:length(fig_ud.image_h)
    image_h_otherImages{image_h_n} = image_h(:,image_h_n)';
  end
  local_setUserDataField(handles.fig,'image_h_otherImages',image_h_otherImages);
  
  % Set the getImageString, voxelDataAspect, axis limits, toScreenPlane, and ButtonDownFcn in each axis
  % Axial view (lower left)
  voxelDataAspect=fig_ud.voxelSize([1 2 3]);
  currImageSize3D=fig_ud.imageSize3D([1 2 3]);
  set(ax_h(2),'DataAspectRatio',voxelDataAspect([2 1 3]), ...
    'XLim',[0.5,currImageSize3D(1)+0.5],'YLim',[0.5,currImageSize3D(2)+0.5], ...
    'UserData',struct('getImageString','permute(image_ud.srs(:,:,z,timePts(n)),[2 1 3 4])', ...
    'toScreenPlane',[1 2 3]));
  % Corononal view (upper left)
  voxelDataAspect=fig_ud.voxelSize([1 3 2]); 
  currImageSize3D=fig_ud.imageSize3D([1 3 2]);
  set(handles.imgAx,'DataAspectRatio',voxelDataAspect([2 1 3]), ...
    'XLim',[0.5,currImageSize3D(1)+0.5],'YLim',[0.5,currImageSize3D(2)+0.5], ...
    'UserData',struct('getImageString','permute(image_ud.srs(:,y,:,timePts(n)),[3 1 2 4])', ...
    'toScreenPlane',[1 3 2]));
  % Saggittal view (upper right)
  voxelDataAspect=fig_ud.voxelSize([2 3 1]);
  currImageSize3D=fig_ud.imageSize3D([2 3 1]);
  set(ax_h(1),'DataAspectRatio',voxelDataAspect([2 1 3]), ...
    'XLim',[0.5,currImageSize3D(1)+0.5],'YLim',[0.5,currImageSize3D(2)+0.5], ...
    'UserData',struct('getImageString','permute(image_ud.srs(x,:,:,timePts(n)),[3 2 1 4])', ...
    'toScreenPlane',[2 3 1]));   
  
  % Disable slider
  set(handles.Slider,'Enable','off');
  set(handles.ImgNum,'String','');
  
  % Plot time series
  currPoint=get(handles.Slider,'UserData');
  local_plottimesrs(handles,currPoint(1),currPoint(2),currPoint(3));
  
  % Turn on markers
  showsrs2('ShowMarkersMenu_Callback',handles.fig,'on');

  % Update new axes and images for current transparency use.
  % TODO: Do I need to do this for other orientations???
  showsrs2('UseTransMenu_Callback',handles.fig,get(handles.UseTransMenu,'Checked'));
else
  % Unrecognized tag
  emsg=sprintf('Orientation %s is unsupported!',currOrientMenuTag); error(emsg);
end

% Update the image
% TODO: Find out why the reorient leaves little junk on the screen (& Fix it)
% If EraseMode is set to 'none' on the base image (i.e. there is only a base image), 
%  set it to normal for the redraw to erase the entire image properly
eraseModeNone = strcmp(get(fig_ud.image_h(1),'EraseMode'),'none');
if eraseModeNone, set(fig_ud.image_h(1),'EraseMode','normal'); end
showsrs2('Refresh_Callback',handles.fig);
if eraseModeNone, set(fig_ud.image_h(1),'EraseMode','none'); end

% Update markers
local_updatemarker(handles,currPoint(1),currPoint(2),currPoint(3));

%------------------------local_changeNumberAxes----------------------------
function ax_h=local_changeNumberAxes(handles,columns,rows,topMargin,bottomMargin,leftMargin,rightMargin)
% local_changeNumberImages - Change the number of axes to display images on
%
%  ax_h=local_changeNumberAxes(handles,columns,rows)
%
%  handles - structure of handles for each of the elements in the showsrs2 GUI
%      (returned by function guihandles)
%  columns - number of columns of axes
%  rows - number of rows of axes
%  axesTopMargin    - top margin on each of the axes (columns x rows) - defaults to zeros
%  axesBottomMargin - bottom margin on each of the axes (columns x rows) - defaults to zeros
%  axesLeftMargin   - left margin on each of the axes (columns x rows) - defaults to zeros
%  axesRightMargin  - right margin on each of the axes (columns x rows) - defaults to zeros
%
%  ax_h - handles of the ADDITIONAL image axes generated (does NOT include handles.imgAx)
% Note: Updates 'resizeInfo' field of figure UserData

% Default all margins to zeros
if nargin < 4 , topMargin = zeros(columns,rows); end
if nargin < 5 , bottomMargin = zeros(columns,rows); end
if nargin < 6, leftMargin = zeros(columns,rows); end
if nargin < 7, rightMargin = zeros(columns,rows); end

% Check that sizes are correct
if any(size(topMargin)~=[columns,rows]) | any(size(topMargin)~=[columns,rows]) | ...
    any(size(topMargin)~=[columns,rows]) | any(size(topMargin)~=[columns,rows]) 
  emsg='topMargin, bottomMargin, leftMargin, and rightMargin must be columns by rows!';
  error(emsg);
end

% Delete all axes except primary axes
delete(findobj(handles.fig,'Type','Axes','Tag','otherAx'));

% Generate all the additional axes handles
ax_h=[];
for n=1:(columns*rows-1);
  ax_h(n)=axes('Units','Characters','Visible','off','YDir','reverse',...
    'XTick',[],'YTick',[],'NextPlot','Add','Layer','top','Tag','otherAx');
end

% Update axesMatrix, axes*Margin fields in resizeInfo used by local_resizewindows
% Note: axesMatrix is the number of rows and columns of axes
%       axesTopMargin,axesBottomMargin,axesLeftMargin,axesRightMargin are the
%         margins on each of the axes.
figUD = get(handles.fig,'UserData');
figUD.resizeInfo.axesMatrix = [columns,rows];
figUD.resizeInfo.axesTopMargin = topMargin;
figUD.resizeInfo.axesBottomMargin = bottomMargin;
figUD.resizeInfo.axesLeftMargin = leftMargin;
figUD.resizeInfo.axesRightMargin = rightMargin;
set(handles.fig,'UserData',figUD);
clear figUD

% Resize window to set axes positions
showsrs2('Resize_Callback',handles.fig)

%------------------------LOCAL_UPDATEMARKER------------------------------------------
function local_updatemarker(handles,x,y,z)
% LOCAL_UPDATEMARKER Update the marker to the current point specified
%
%   local_updatemarker(imgFig,x,y,z)
%     handles - structure of handles for each of the elements in the showsrs2 GUI
%      (returned by function guihandles)
%     x,y,z  = x,y,z point to plot                 
%

% Point to plot
currPoint=[x y z];

% Get figure UserData
fig_ud=get(handles.fig,'UserData');
imsize=fig_ud.imageSize3D;

% Get the handles of the image axes
imageAxes_h=get([fig_ud.image_h(1), fig_ud.image_h_otherImages{1}],'parent');
if iscell(imageAxes_h), imageAxes_h=[imageAxes_h{:}]; end  % Convert from cell to numeric array

clear('fig_ud'); % Done with Figure UserData, clear it.

% Loop through each axes
for ax=1:length(imageAxes_h)
  % Get mapping to screen plane for each axes
  toScreenPlane=subsref(get(imageAxes_h(ax),'UserData'),struct('type','.','subs','toScreenPlane'));
  currPointScreen=currPoint(toScreenPlane);
  imsizePlane=imsize(toScreenPlane);
  
  % Make axes current
  axes(imageAxes_h(ax));

  % Find horizontal & vertical lines
  xLine_h=findobj(imageAxes_h(ax),'Type','Line','Tag','HorzMarker');
  yLine_h=findobj(imageAxes_h(ax),'Type','Line','Tag','VertMarker');
  
  % Setup contextual menu, callback, marker color, marker style if a line
  % needs to be created.
  if isempty(xLine_h) | ~ishandle(xLine_h) | isempty(yLine_h) | ~ishandle(yLine_h)
    % Generate contextual menu items to change cross hair style
    contextMenu_h=uicontextmenu('Tag','MarkerLineMenu');
    uimenu('Parent',contextMenu_h,'Label','-- Cross Hair Style --');
    uimenu('Parent',contextMenu_h,'Label','Solid','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''LineStyle'',''-'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''LineStyle'',''-'');']);
    uimenu('Parent',contextMenu_h,'Label','Dashed','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''LineStyle'',''--'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''LineStyle'',''--'');']);
    uimenu('Parent',contextMenu_h,'Label','Dash-Dotted','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''LineStyle'',''-.'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''LineStyle'',''-.'');']);
    uimenu('Parent',contextMenu_h,'Label','Dotted','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''LineStyle'','':'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''LineStyle'','':'');']);
    uimenu('Parent',contextMenu_h,'Label','-- Cross Hair Color --');
    uimenu('Parent',contextMenu_h,'Label','Red','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''Color'',''r'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''Color'',''r'');']);
    uimenu('Parent',contextMenu_h,'Label','Green','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''Color'',''g'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''Color'',''g'');']);
    uimenu('Parent',contextMenu_h,'Label','Blue','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''Color'',''b'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''Color'',''b'');']);
    uimenu('Parent',contextMenu_h,'Label','White','Callback', ...
      [ 'set(findobj(gcbf,''Type'',''Line'',''Tag'',''HorzMarker''),''Color'',''w'');' ...
        'set(findobj(gcbf,''Type'',''Line'',''Tag'',''VertMarker''),''Color'',''w'');']);
    
    % If you click on the line, execute button down function for the image
    cb='eval(get(index(findobj(get(gcbo,''Parent''),''Type'',''image''),1),''ButtonDownFcn''));';
    
    % Take line color and style from any lines that exist
    anyLine_h=[findobj(handles.fig,'Type','Line','Tag','HorzMarker'); ...
        findobj(handles.fig,'Type','Line','Tag','VertMarker')];
    if isempty(anyLine_h), % Defaults
      markerLineColor='r';
      markerLineStyle='-';
    else % Take from first line
      markerLineColor=get(anyLine_h(1),'Color');
      markerLineStyle=get(anyLine_h(1),'LineStyle');
    end
  end
  
  % Make (if necessary) & update horizontal line
  if isempty(xLine_h) | ~ishandle(xLine_h)
    line([0.5 imsizePlane(1)+0.5],[currPointScreen(2),currPointScreen(2)], ...
      'Color',markerLineColor,'LineStyle',markerLineStyle,'Tag','HorzMarker','ButtonDownFcn',cb, ...
      'Visible',get(handles.ShowMarkersMenu,'Checked'),'uicontextmenu',contextMenu_h);
  else
    set(xLine_h,'XData',[0.5 imsizePlane(1)+0.5],'YData',[currPointScreen(2),currPointScreen(2)]);
  end
  
  % Make (if necessary) & update vertical line
  if isempty(yLine_h) | ~ishandle(yLine_h)
    line([currPointScreen(1),currPointScreen(1)],[0.5 imsizePlane(2)+0.5], ...
      'Color',markerLineColor,'LineStyle',markerLineStyle,'Tag','VertMarker','ButtonDownFcn',cb, ...
      'Visible',get(handles.ShowMarkersMenu,'Checked'),'uicontextmenu',contextMenu_h);
  else
    set(yLine_h,'XData',[currPointScreen(1),currPointScreen(1)],'YData',[0.5 imsizePlane(2)+0.5]);
  end
end

function [slicePlane,voxelSize] = local_getorientgui(defPlane,defSize)
%LOCAL_GETORIENTGUI - Get slicePlane and voxelSize using a GUI
%
%   [slicePlane,voxelSize] = local_getorientgui(defPlane,defSize);
%       defPlane - string containing plane ('Axial','Coronal','Sagittal')
%                  to start with in GUI.  Invalid strings, empty, or not
%                  specified will default to Axial.
%        defSize - three element vector specifying initial voxelSizes
%                  Invalid empty, or not specified defSize will default to
%                  all blanks.  Use 0 for any dimension you do not want to
%                  specify a default for (e.g. [3.75 3.75 0] will
%                  initialize X to '3.75', Y to '3.75' and Z to ''.
%

% Slice planes to display in list
slicePlanes = {'Axial','Coronal','Sagittal'};

% Setup default plane
if nargin < 1 | isempty(defPlane) | ~ischar(defPlane)
  defPlane = 1; % Default to first in list
else
  defPlane = find(strcmp(defPlane,slicePlanes));
  if isempty(defPlane), defPlane = 1; end % No match.
end
% Setup default voxelSize
if nargin < 2 | isempty(defSize) | ... % Not specified
    ~isnumeric(defSize) | ndims(defSize) ~= 2 | any(size(defSize) ~= [1 3]) % Invalid
  defSize = {'','',''};
else
  defSizeNumeric = defSize;
  defSize = cell(1,3);
  for n=1:3, 
    if defSizeNumeric(n) <= 0
      defSize{n} = ''; % Use '' for 0 or less (allow user to specify only some sizes).
    else
      defSize{n} = num2str(defSizeNumeric(n));
    end
  end
  clear defSizeNumeric
end

% --- Initialize GUI ---
% Get relationship between Character and Pixel Units
oldRootUnits=get(0,'Units');
set(0,'Units','pixels');
scrPixels=get(0,'ScreenSize');
set(0,'Units','Characters');
scrChars=get(0,'ScreenSize');
set(0,'Units',oldRootUnits);
pixs2char=scrPixels(3:4)./scrChars(3:4);
width2height = pixs2char(1)/pixs2char(2);

% Set GUI size parameters
borderW = 2.5; % Figure border (in width units)
borderH = borderW.*width2height; % (in height units)
marginH = 1.2; marginW = 2;           % Margin between GUI elements.
buttonH = 1.8; buttonW = 10;          % Okay and Cancel buttons.
voxelEditH = 1.8; voxelEditW = 10;    % Voxel Size edit boxes & labels
voxelDimLabelH = 1.5; voxelDimLabelW = 3; voxelDimLabelMarginW = 1;
voxelLabelH = 1.5;  % Voxel Size label string.
orientListW = 20; orientListH = 1.8;  % Slice plane list
orientLabelH = 1.5; % Slice plane label.

% Create GUI
figPos(3:4) = [ 2.*borderW + 2.*marginW + 3.*(voxelEditW + voxelDimLabelMarginW + voxelDimLabelW)  ...
    2.*borderH + buttonH + 2.*marginH + voxelEditH + voxelLabelH + orientListH + orientLabelH];
figPos(1:2) = scrChars(3:4)./2 - figPos(3:4)./2; % Center on screen.
h.fig = figure('Units','Characters','MenuBar','none', ...
  'Color',get(0,'defaultUicontrolBackgroundColor'), ...
  'Position',figPos,'resize','off','WindowStyle','modal', ...
  'IntegerHandle','off','handlevisibility','off','number','off',...
  'Name','Please specify ...');

% Create Cancel and Okay buttons
pos = [ borderW + (figPos(3)-2*borderW - 2*buttonW)/3, borderH, buttonW, buttonH];
uicontrol(h.fig,'Units','Characters','Style','pushbutton',...
  'Position',pos,'Tag','OkayButton','String','Okay', ...
  'Callback','set(gcbf,''UserData'',''okay'')');
pos(1) = 2*(pos(1) - borderW) + pos(3);
uicontrol(h.fig,'Units','Characters','Style','pushbutton',...
  'Position',pos,'Tag','OkayButton','String','Cancel', ...
  'Callback','set(gcbf,''UserData'',''cancel'')');

% Create voxelSize buttons and labels
labels = {'X:','Y:','Z:'};
pos = [ borderW, pos(2) + pos(4) + marginH, voxelDimLabelW, voxelDimLabelH];
for n=1:3
  uicontrol(h.fig,'Units','Characters','Style','Text','Position',pos,'String',labels{n});
  pos = [pos(1) + pos(3) + voxelDimLabelMarginW, pos(2), voxelEditW, voxelEditH];
  h.voxelSize(n) = uicontrol(h.fig,'Units','Characters','Style','Edit', ...
    'Position',pos,'Tag',sprintf('VoxelSize%d',n),'String',defSize{n},'BackgroundColor','w');
  pos = [pos(1) + pos(3) + marginW, pos(2), voxelDimLabelW, voxelDimLabelH];
end
pos = [borderW, pos(2) + voxelEditH, figPos(3)-marginW.*2, voxelEditH]; % Full width
uicontrol(h.fig,'Units','Characters','Style','Text','Position',pos, ...
  'String','Voxel Size (Specify in the same units for X,Y,Z)','HorizontalAlignment','Left');
  
% Create slicePlane label & list
pos = [borderW, pos(2) + orientLabelH + marginH, orientListW, orientListH];
h.orientList = uicontrol(h.fig,'Units','Characters','Style','popupmenu', ...
  'Position',pos,'Tag','orientationList','String',slicePlanes,...
  'Value',defPlane,'BackgroundColor','w');
pos = [borderW, pos(2) + pos(4), figPos(3)-marginW.*2, orientLabelH]; % Full Width
uicontrol(h.fig,'Units','Characters','Style','Text','Position',pos, ...
  'String','Slice plane (Orientation)','HorizontalAlignment','Left');

% --- User Interaction Loop ---
valid = 0;
while ~valid
  % Wait for user to finish
  waitfor(h.fig,'UserData');
  
  if ~ishandle(h.fig) | strcmp(get(h.fig,'UserData'),'cancel')
    % User pushed cancel, return empties
    slicePlane = [];
    voxelSize = [];
    valid = 1;
  else
    % User pushed okay

    % Get all of the voxel sizes and check that they are valid
    voxelSize = zeros(1,3);
    for n=1:3
      tmpSize = str2num(get(h.voxelSize(n),'String'));
      if ~isempty(tmpSize) & length(tmpSize) == 1 & tmpSize > 0 & isreal(tmpSize)
        voxelSize(n) = tmpSize;
      end
    end
    if any(voxelSize == 0)
      % Voxel size is not valid.  Let them keep trying
      waitfor(errordlg('Please specify positive real numbers for the voxel size.', ...
        'Error','modal'));
      set(h.fig,'UserData','');
    else
      % Voxel size if valid.  Continue.
      valid = 1;
    end
    
    % Get selected slice plane.
    slicePlane = slicePlanes{get(h.orientList,'Value')};
  end
end
% Close the figure if it is still around.
if ishandle(h.fig), delete(h.fig); end

% --------------------local_find_showsrs2_childGUI-----------------------
function gui_h=local_find_showsrs2_childGUI(type,showsrs2_h)
% local_find_showsrs2_childGUI - Find showsrs2_* GUI for specified showsrs2 figure
%
%   gui_h=local_find_showsrs2_childGUI(type,showsrs2_h)
%              type - Tag of showsrs2 child GUI indicating gui type
%        showsrs2_h - Handle of showsrs2 figure
%             gui_h - Handle of showsrs2_child GUI for showsrs2_h figure
%                     gui_h = [] if there are no showsrs2_child GUIs for 
%                       the showsrs2_h figure.
%
%   GUI matches if:
%   (1) Figure 'Tag' matches type (passed to this function)
%   (2) UserData is a structure
%   (3) Structure has a field called showsrs2 whos values matches
%       showsrs2_h (passed to this function)
%
% Examples
% > gui_h=local_find_showsrs2_childGUI('showsrs2_cfgFig',showsrs2_h)
% > gui_h=local_find_showsrs2_childGUI('showsrs2_cfgtransFig',showsrs2_h)

% Show all hidden handles to allow us to check for showsrs2_child handles
currState = get(0,'ShowHiddenHandles'); % Read current state
set(0,'ShowHiddenHandles','on');        % Make all handles visible
showsrs2_child_h = findobj('Tag',type); % Check for gui's for this image
set(0,'ShowHiddenHandles',currState);   % Set back to previous state

% Check if any of these figures control showsrs2_h
gui_h = [];
for n = 1:length(showsrs2_child_h)
  h = get(showsrs2_child_h(n),'UserData');
  if isfield(h,'showsrs2') & h.showsrs2 == showsrs2_h
    gui_h = showsrs2_child_h(n);
    break;
  end
end

%------------------local_getUserDataField-----------------------
function val = local_getUserDataField(h,field)
% local_getUserDataField - Get the value of a field in UserData structure
%   
%   Get the 'UserData' of the specified handle, h, and return the value of
%   the requested field.  The UserData of the specified handle must be a
%   structure.
%
%   val = local_getUserDataField(h,field)
%
%          h - handle of object to get UserData from
%      field - name of desired field.
%        val - value of desired field ([] if field is not present).
%
% See Also: GETAPPDATA 

% Check input arguments
error(nargchk(2,2,nargin));
if length(h) > 1 | ~ishandle(h), error('h must be a single handle!'); end
if ~ischar(field), error('field must be a string!'); end

% Get UserData for specifed object
ud = get(h,'UserData');
if ~isempty(ud) & ~isstruct(ud)
  error('UserData for specifed handle is not a structure');
end

if isempty(ud) | ~isfield(ud,field)
  % Return empty if the field does not exist.
  val = [];
else
  % Otherwise, get the value.
  val = subsref(ud,struct('type','.','subs',field));
end

%------------------local_setUserDataField-----------------------
function local_setUserDataField(h,field,val)
% local_setUserDataField - Set the value of a field in UserData structure
%   
%   Set specified field (field) of the 'UserData' of the specified handle
%   (h) to the specified value (val). The UserData of the specified handle
%   must be empty or a structure.
%
%   local_setUserDataField(h,field,val)
%
%          h - handle of object to get UserData from
%      field - name of desired field to set.
%        val - value of desired field
%
% See Also: SETAPPDATA 

% Check input arguments
error(nargchk(3,3,nargin));
if length(h) > 1 | ~ishandle(h), error('h must be a single handle!'); end
if ~ischar(field), error('field must be a string!'); end

% Get UserData for specifed object
ud = get(h,'UserData');
if ~isempty(ud) & ~isstruct(ud)
  error('UserData for specifed handle is not a structure');
end

% Set the field and store updated UserData
ud=subsasgn(ud,struct('type','.','subs',field),val);
%ud=setfield(ud,field,val); % setfield is deprecated.
set(h,'UserData',ud); % Store the updated 'UserData'

% Modification History:
%
% $Log: showsrs2.m,v $
% Revision 1.99  2005/08/09 17:45:33  gadde
% Do automatic reorientation and flips before scaling/displaying
% to save memory and annoyance (out-of-memory errors should now
% happen before image is displayed).
%
% Revision 1.98  2005/03/31 20:10:28  michelich
% Automatically convert overlays to doubles before scaling.
%
% Revision 1.97  2005/02/22 20:18:25  michelich
% Use more robust version parsing code.
%
% Revision 1.96  2005/02/16 15:42:04  michelich
% Fix argument parsing syntax error introduced in rev 1.94.
%
% Revision 1.95  2005/02/16 02:53:45  michelich
% Use more robust version parsing code.
%
% Revision 1.94  2005/02/03 19:16:27  michelich
% Changed argument checking to be more clear and robust.
%
% Revision 1.93  2005/02/03 17:16:52  michelich
% M-lint: Add missing commas.
%
% Revision 1.92  2005/02/03 16:58:44  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.91  2005/01/08 05:20:22  michelich
% Added TODO.
%
% Revision 1.90  2005/01/08 05:12:56  michelich
% Fix LinkCursors error checking and error handling.
%
% Revision 1.89  2005/01/08 04:13:04  michelich
% Added support for linking cursors.
% Renamed refreshPlotTimeSrs_Callback to RefreshPlotTimeSrs_Callback.
% Renamed showTimePlot_Callback to ShowTimePlot_Callback.
% Confirm that handle passed to callback is from a showsrs2 figure.
%
% Revision 1.88  2005/01/05 23:19:43  michelich
% Use Refresh_Callback instead of Slider_Callback to refresh display.
%   Refresh_Callback function simpler.  The only other functionality used
%   was updating the time text to match the slider value.  Modified all
%   code that changes time slider to update text also.
% Remove Slider_Callback and created separate (simpler) callback functions
%   for time and slice sliders.
% Removed unused function ChangeSlice_Callback
% Added local_updatemarker to handle changing the current spatial point in a
%   single location.  Modified KeyPress_Callback, SliceSlider_Callback, and
%   Click_Callback to use this function.
% If user changes slices using keyboard after turning off markers with time
%   series plot on, do not reenable markers.
%
% Revision 1.87  2005/01/05 16:59:47  michelich
% Added missing error call.
%
% Revision 1.86  2004/12/14 15:19:58  michelich
% Explicitly round on transparency calculations to avoid warning messages on
%   MATLAB 7.  Note: This change may decrease performance.
%
% Revision 1.85  2004/09/20 20:16:09  michelich
% Prompt user to load input if none specified.
%
% Revision 1.84  2004/09/13 18:35:44  michelich
% Set legend text color to white (MATLAB 7 sets it to black by default).
%
% Revision 1.83  2004/07/21 16:30:33  michelich
% Don't show option to send time series data to Excel except on PCs.
%
% Revision 1.82  2004/05/12 18:11:26  michelich
% Bug Fix: Set default orient3DOrig2Native when no orientation specified.
% Use errordlg instead of errorbox.
%
% Revision 1.81  2004/05/10 23:10:44  michelich
% Backout accidental commit.
%
% Revision 1.79  2004/05/10 22:52:39  michelich
% Display coordinates of current point in original data.
%
% Revision 1.78  2004/05/06 15:15:34  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.77  2004/03/02 22:14:28  michelich
% Default to not use OpenGL. (Due to performance and rendering problems for
%   several graphics cards used at BIAC)
%
% Revision 1.76  2004/01/13 17:32:24  michelich
% Added config option "showTimePlot".
% Remember which lines are shown on time plot when axis deleted and recreated.
%
% Revision 1.75  2003/10/22 15:54:39  gadde
% Make some CVS info accessible through variables
%
% Revision 1.74  2003/10/15 15:43:16  michelich
% Updated help to use new readmr.
%
% Revision 1.73  2003/09/23 00:35:50  michelich
% Be less agressive with warning dialogs.
%
% Revision 1.72  2003/09/22 17:02:34  michelic
% Handle single slice data with .info fields more gracefully.
%
% Revision 1.71  2003/09/05 15:16:09  michelich
% Fixed automatic handling of flips in the 3rd dimension.
%
% Revision 1.70  2003/08/27 22:02:07  michelich
% Check that OpenGL renderer is available.
%
% Revision 1.69  2003/08/26 14:36:40  michelich
% Fixed handling of image names in figure title.
%
% Revision 1.68  2003/08/25 21:10:25  michelich
% Include one element of each path in figure title label.
%
% Revision 1.67  2003/08/25 21:00:16  michelich
% Label figure with image names when available.
%
% Revision 1.66  2003/08/23 19:23:20  michelich
% Remove debugging code.
%
% Revision 1.65  2003/08/23 19:12:31  michelich
% Apply flips in the 3rd dimension automatically for 'lpi' orientation.
%
% Revision 1.64  2003/08/23 18:01:18  michelich
% Label figure with variable names.
%
% Revision 1.63  2003/07/22 19:05:01  michelich
% Made configuration input arguments optional.
% Removed support for passing base cmapLim as a simple vector (not a struct).
%
% Revision 1.62  2003/07/07 20:43:46  michelich
% Check that voxel size is positive.
% Use warndlg for most warnings to make them more apparent to user.
% Close GUI on error if possible.
% Warn user if voxelSize or slicePlane are invalid (instead of an error).
% local_parseInputs: Don't return voxelSize or slicePlane unless both are valid.
%
% Revision 1.61  2003/07/03 04:25:51  michelich
% Bug Fix: Slice change now updates time series plot in single axes view
%
% Revision 1.60  2003/06/23 18:33:08  michelich
% Added "m" key to echo current point to command window.
%
% Revision 1.59  2003/06/22 21:21:14  michelich
% Don't plot time series in refreshPlotTimeSrs_Callback if user closed plot.
%
% Revision 1.58  2003/06/22 03:45:40  michelich
% Disable SpecifyOrientMenu if specified at launch.  Added missing semicolon.
%
% Revision 1.57  2003/06/22 03:32:21  michelich
% Add ability to specify slicePlane and voxelSize after data is loaded in GUI.
%
% Revision 1.56  2003/06/20 17:18:39  michelich
% Use feval to generate default colormaps.  Comment updates.
%
% Revision 1.55  2003/06/18 19:27:54  michelich
% Fixed enabling/disabling time series plot in separate figure.
%
% Revision 1.54  2003/06/18 15:57:31  michelich
% Implemented FastInfo array to handle storing limits for layer currently
%   being modified (so that other refreshes use the proper limits).
% Misc comment corrections.
%
% Revision 1.53  2003/06/17 13:59:31  michelich
% Instead of disabling transparency without OpenGL, calculate merged image:
% - Update local_updatedisplay to calculate merged image using transparency.
% - Use painters renderer and double buffering when not using OpenGL Transparency.
% - Change UseTransMenu label to "Use OpenGL Transparency".
% - Don't set AlphaMap to all ones when unchecking UseTransMenu.
% - Don't update showsrs2_cfg* GUI using UseTransMenu_Callback since the
%   AlphaMap is no longer changed by UseTransMenu_Callback.
% - Save showsrs2_cfg settings (saveCurrSettings_Callback) when switching
%   transparency modes so that images are properly displayed.
% - Added separator in config menu.
%
% Revision 1.52  2003/06/16 13:53:08  michelich
% showsrs2 changes for MATLAB 5.3 support:
% - Restrict transparency use based on MATLAB version and screen bit depth.
% - Removed all guihandles calls (Generate handles in local_initializegui).
% - Removed use of getappdata and setappdata. Store 'handles' and
%   'resizeInfo' in figure UserData and 'currPoint' in Slider UserData.
%   Update all code for new locations.
% - Keep master copy of AlphaMap in showsrs2_h UseTransMapMenu.
% - Updated UseTransMenu_Callback to handle changes necessary when choosing
%   a transparency use state. (e.g. Update AlphaMap, AlphaDataMapping,
%   Renderer, showing/hiding images, updating cfg GUIs)
% - Only explicitly use OpenGL if using transparency, otherwise let MATLAB pick.
% - Updated local_updateimagedisplay to support refreshing a single layer.
% - Added Refresh_Callback for showsrs2_cfg* to use instead of Slider_Callback.
%   Includes support for now local_updatedisplay functionality.
% - Removed image_rgbflag since this functinality is in Refresh_Callback.
% Other changes:
% - Changed image_h_otherImages to a row vector for easier concatenation.
% - Implemented local_getUserDataField and local_setUserDataField to more
%   cleanly and savely update fields in structures stored in UserData.
%
% Revision 1.51  2003/06/13 17:37:58  michelich
% Initial work for MATLAB 5.3 support.
% Added menu to turn off/on transparency.
% Implemented support no transparency in local_updatedisplay.
%
% Revision 1.50  2003/04/24 15:04:43  michelich
% Attempt to automatically determe voxel size even if orientation cannot be
% determined automatically.
%
% Revision 1.49  2003/04/24 14:45:16  dias
% Skip auto orientation if cannot determine rasflag.
%
% Revision 1.48  2003/04/19 03:20:39  michelich
% Added menu to flipdim after data are loaded.
%
% Revision 1.47  2003/04/18 15:51:52  michelich
% Change numbering of X-axis time series plot to start at one to match the
%   time series numbering in the main window.
%
% Revision 1.46  2003/04/11 04:11:49  michelich
% Added auto detection of slicePlane and voxelSize from info field.
%
% Revision 1.45  2003/04/11 03:00:48  michelich
% Fixed check for data field in overlays.
%
% Revision 1.44  2003/03/22 05:54:28  michelich
% Added contextual menu to change color and style of crosshairs.
%
% Revision 1.43  2003/03/06 16:35:14  michelich
% Change line style on current point markers to dash.
%
% Revision 1.42  2003/03/06 14:04:13  michelich
% Allow logical overlays (since these are not numeric in MATLAB 6.5).
% Set default line style on current point markers.
%
% Revision 1.41  2003/02/24 22:51:38  michelich
% Added contextual menus to copy data from time series plot lines.
%
% Revision 1.40  2003/02/14 20:51:57  michelich
% Make right-click on W+L button open transparency adjust tool.
%
% Revision 1.39  2003/02/11 22:13:10  michelich
% Minor fix in error checking of local_changeNumberImages.
%
% Revision 1.38  2003/02/07 20:07:24  michelich
% Allow logical arrays (since these are not numeric in MATLAB 6.5).
% Changed Tag of three plane orientation menu to be a valid field name.
% Added option to local_plottimesrs to force regeneration of lines.
%
% Revision 1.37  2003/02/04 23:05:05  michelich
% Handle showsrs2([]) gracefully.
%
% Revision 1.36  2003/01/07 05:19:38  michelich
% Removed repeated line color.
%
% Revision 1.35  2003/01/07 05:18:29  michelich
% Disable VCR controls when there is only one time point.
%
% Revision 1.34  2003/01/07 05:12:01  michelich
% Start default line colors with white (for base image).
% Do not use colormap for time series line colors by default for only base srs.
%
% Revision 1.33  2003/01/07 04:49:47  michelich
% Added menu to turn plotting each time series on/off.
% Fixed time series plot keypress function to store generating imgFig
%   variable the user's in workspace.
% Clear figUD local_plottimesrs when I am done with it.
%
% Revision 1.32  2003/01/07 00:45:35  michelich
% Added support for non-double numeric arrays.
% Added input check to exclude sparse arrays (unsupported).
%
% Revision 1.31  2003/01/06 20:20:12  michelich
% Use colormap for time series line colors by default.
% Disabled use Tex interpreter in figures (making variable names look odd in
%   in time series plots)
% Use colordef none for figures.
%
% Revision 1.30  2002/12/30 20:29:09  michelich
% Changed to use middle color of colormap for time series line color.
%
% Revision 1.29  2002/12/30 20:18:55  michelich
% Changed the name of the time series line color config menu option.
%
% Revision 1.28  2002/12/30 20:02:57  michelich
% Fixed alphamap generation when there is only a base image.
%
% Revision 1.27  2002/12/30 19:41:04  michelich
% Added overlay configuration field transLevel to set initial alpha values.
%
% Revision 1.26  2002/12/30 19:11:31  michelich
% Added option to use last colormap color for time series plot line color.
%
% Revision 1.25  2002/12/20 19:38:51  michelich
% Extract images from data field of input
%
% Revision 1.24  2002/12/03 20:48:45  michelich
% Bug Fix: Don't check number of time points on overlays if there are no overlays.
%
% Revision 1.23  2002/11/26 21:17:33  michelich
% Added semicolon
%
% Revision 1.22  2002/11/26 21:16:07  michelich
% Added support for interpolating along the slice dimension.
% Simplified logic for comparing 4D size of overlays to base.
% Added check that all 4D overlays have the size 4th dimension size.
%
% Revision 1.21  2002/11/03 04:02:13  michelich
% Set default voxel size and slice plane if only cmapLim passed as a vector
%
% Revision 1.20  2002/10/09 20:00:55  michelich
% Added showsrs2_cfgtrans support.
% Moved check for configuration GUIs into a local function.
% Added ability to turn standard figure menus on and off.
% Added ability to turn time series plot legend on and off.
%
% Revision 1.19  2002/09/30 19:29:22  crm
% Fixed bug that skipped display of first image in Play & RevPlay callbacks.
%
% Revision 1.18  2002/09/27 20:06:10  michelich
% Don't store figure handle in W+L button (leftover from showsrs linkwinlev)
%
% Revision 1.17  2002/09/25 22:39:46  michelich
% Added bit depth check.
% Added variable name passed to showsrs2 to description of base & overlays.
% Handle crash during initialization more gracefully.
% Added code to force axes square (works, but is commented out).
%
% Revision 1.16  2002/09/11 14:31:12  michelich
% Fixed extracting srs in local_plottimesrs when there is only a base.
% Widened space for y axis label on time series plot in ortho view.
%
% Revision 1.15  2002/09/11 14:18:04  michelich
% Fixed assigment of srs_names for multiple overlays
%
% Revision 1.14  2002/09/11 14:03:37  michelich
% Don't plot base time series if there are overlays.
%
% Revision 1.13  2002/09/10 21:09:01  michelich
% Changed order of line colors for better consistency with default overlays colormaps.
% Changed difference scale size in-plane to a warning.
%
% Revision 1.12  2002/09/05 14:32:43  michelich
% Misc capitalization and syntax fixes.
% Explicitly set Renderer to OpenGL to remove flashing
%   during base only display with EraseMode "normal".
% Disabled Play and RevPlay keyboard shortcuts until handle
%   interruptibility issues can be resolved.
%
% Revision 1.11  2002/09/04 15:53:37  michelich
% Fixed bug with multiple keypresses.
% Removed extra error(emsg) from main catch.
% Ignore time related keypresses when there is only one time point.
% Use cbo in closeRequestFcn to allow closing figure if handles not initialized.
% Always use cmap from image UserData (Not figure colormap).
%
% Revision 1.10  2002/09/04 13:08:33  michelich
% Updated help comments
% Consolidated orientation variables into toScreenPlane in axes UserData
% Added number of time points in each overlay to figure UserData
% Fixed 'Click_Callback' in overlay images
% Updated 'Click_Callback' to get axis using cbo instead of gca
% Changed figure background color
% Updated greengrad default colormap to match showsrs2_cfg
% Implemented different transparencies for each overlay
%
% Revision 1.9  2002/09/03 18:09:06  michelich
% Added try-catch to main code block
% Fixed Play button
% Corrected variable name for case when no orientation specified
%
% Revision 1.8  2002/09/03 14:13:52  michelich
% Numerous fixes for new callback style
% Added ability to show/hide crosshairs
%
% Revision 1.7  2002/09/03 14:00:38  michelich
% Converted all callbacks to use MATLAB 6 style FEVAL switchyard
% Use handles instead of findobj throughout for improved performance
%
% Revision 1.6  2002/08/28 18:00:16  michelich
% Fixed margins on time series plot in 3-plane view
% Fixed support for keyboard navigation
% Added display of crosshairs at current point
%
% Revision 1.5  2002/08/21 15:27:53  michelich
% Initial implementation of 3 plane view
%
% Revision 1.4  2002/07/20 00:19:24  michelich
% Changed display to calculate RGB images at display time to save memory.
% Use RGB (instead of scaled) when actively updating an image to remove
%   limitations of scaled and allow for new features such as different
%   transparencies for each overlay.
%
% Revision 1.3  2002/07/19 23:13:19  michelich
% Removed all LinkWinLev support code (was disabled)
% local_plottimesrs does not work for reoriented volumes.  Added message to indicate this.
% local_plottimesrs bug fix: Was attempting to plot overlay even when there was only a base
% Added greengrad(256) as the default third colormap.
%
% Revision 1.2  2002/07/02 14:15:32  michelich
% Added better error handling when invalid baseCfg passed.
%
% Revision 1.1.1.1  2002/06/20 18:30:41  michelich
% Imported into CVS
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002/06/13. Fixed bug in error when invalid slicePlane specified
% Charles Michelich, 2002/05/08. Fixed bug in handling reorientation of multiple overlays.
% Charles Michelich, 2002/05/07. Merged in begining of code for changing of orientation from 2002/04/28 work
%                                Update image axes limits when orientation changes
%                                Added support for passing voxel size and slice plane
%                                Reorient all images to axial if a valid slice plane and voxel size specified
%                                Added ability to save current axes as JPEG or TIFF files
% Charles Michelich, 2002/04/30. Added initialization of histBins & histCount for histogram cacheing (to increase performance).
% Charles Michelich, 2002/04/29. Changed reference to uninitialized nOverlay to length(overlayInfo)
% Charles Michelich, 2002/04/25. Added support for just displaying a base image.
% Charles Michelich, 2002/04/25. Mapped arrow keys to next, previous, sliceup, and slicedown
% Charles Michelich, 2002/01/10. Added support for multiple overlays
%                                Modified resizeFcn to use handles in appdata for faster resizing
% Charles Michelich, 2002/01/10. Eliminated unnecessary fields in showsrs2 figure UserData 
%                                Fixed local_plottimesrs to work with Phase 2 & added more descriptive figure title
%                                Added automatically closing showsrs2_cfg windows for current GUI in closeRequestFcn
% Charles Michelich, 2002/01/09. Continued implementing "Phase 2" - GUI Control
%                                Moved getparentfigure and showsrs2_convert2rgb (local_convert2rgb) to external functions
%                                Fixed catch to properly display error message during initialization
%                                Removed Configuration menu (transslider no longer necessary)
% Charles Michelich, 2002/01/08. Started implementing "Phase 2" - GUI Control
%                                Started implementing support for multiple overlays
% Charles Michelich, 2002/01/02. Changed to use variable 't' to determine first time point displayed on base and overlay images
% Charles Michelich, 2001/11/15. Changed to plot overlaySrs instead of baseSrs time courses.
%                                Changed to only check first for showsrs2_calcalim using first time point to conserve memory
% Charles Michelich, 2001/11/14. Use showsrs2_calcalim to calculate AlphaMap limits (also used by showsrs_winlev)
%                                General code cleanup.
%                                Implemented plotting of baseImage time series
%                                Implemented LinkWinlev for transparency
% Charles Michelich, 2001/11/13. Add transparency support
%                                Use guihandles to speed up display
% Charles Michelich, 2001/11/12. Finished implementing interface to pass configuration variables.
% Charles Michelich, 2001/10/30. Renamed showsrs2. (MATLAB 6.0 transparency overlays in 4D)
%                                Begin implementing interface to pass configuration varables.
% Charles Michelich, 2001/10/24. Changed behavior of 'q' and 'w' (sliceUp and sliceDown) so that they do not open a new time series window
% Charles Michelich, 2001/09/27. Updated case of readtsv in comments
% Charles Michelich, 2001/09/21. Added 'TheImage' tag to the image object. (to make searching for image easier)
%                                Changed 'LinkWinlev' to store image handles instead of image axis handles (to support winlev fix)
%                                Changed 'CloseRequestFcn' to use delete to destroy winlev GUI to avoid recursive during 'close all'.
% Charles Michelich, 2001/09/21. Added CloseRequestFcn to handle closing & relinking W&L GUIs
%                                Added error when callback task is not recognized.
%                                Changed initialization of winlev button userdata to imgAx_h instead of figure_h
% Charles Michelich, 2001/09/14. Added ability to link the Window & Level for multiple showsrs using showsrs2('LinkWinlev',figures2link)
%                                Added tag to showsrs figure ('showsrs2()') to allow easy identification of showsrs figures.
%                                Changed catch to properly handle non-callback showsrs calls to 'LinkWinlev' and 'Resize'
%                                Added documentation for 'LinkWinlev' and 'Resize' to below help comments
% Charles Michelich, 2001/09/13. Changed default callback argument to []
%                                Added ability to call showsrs2('Resize',handle) directly (instead of just as a callback) to 
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
%                                  to avoid an error when rapidly pressing the key.
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
