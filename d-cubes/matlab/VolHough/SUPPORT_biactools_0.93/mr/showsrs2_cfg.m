function outputFig_h = showsrs2_cfg(varargin)
%SHOWSRS2_CFG Application M-file for showsrs2_cfg.fig
%    FIG = SHOWSRS2_CFG launch showsrs2_cfg GUI.
%    SHOWSRS2_CFG('callback_name', ...) invoke the named callback.

% Last Modified by GUIDE v2.0 10-Jan-2002 15:19:20

% CVS ID and authorship of this code
% CVSId = '$Id: showsrs2_cfg.m,v 1.25 2005/02/03 16:58:44 michelich Exp $';
% CVSRevision = '$Revision: 1.25 $';
% CVSDate = '$Date: 2005/02/03 16:58:44 $';
% CVSRCSFile = '$RCSfile: showsrs2_cfg.m,v $';

if nargin == 0 
  error('Insufficient number of input arguments');
  
elseif ~ischar(varargin{1})  % LAUNCH GUI
  % Check input arguments
  if nargin ~= 1
    error('Incorrect number of input arguments for launching showsrs2_cfg GUI!');
  end
  showsrs2_h = varargin{1}; % Argument is handle of showsrs2 figure to be controlled
  
  % Check handle
  if length(showsrs2_h(:)) ~= 1 | ~ishandle(showsrs2_h) | ~strcmp('figure', get(showsrs2_h,'type')) ...
      | ~strcmp(get(showsrs2_h,'Tag'),'showsrs2()')
    error('Invalid showsrs2 handle!');
  end
  
  % Check to see a showsrs2_cfg GUI is already open for this image
  gui_h=local_find_showsrs2_childGUI('showsrs2_cfgFig',showsrs2_h);
  
  if ~isempty(gui_h)
    % GUI found, bring to front
    figure(gui_h);
  else
    % GUI not found, Open GUI (and generate structure of handles in GUI).
    handles=local_initializegui;
    gui_h = handles.showsrs2_cfgFig;
     
    % Add some handles from the showsrs2 GUI.  Store the handles structure
    % in the figure UserData.  Use get(getparentfigure(h),'UserData') to
    % retrieve the handles. 
    %   Includes: handles from showsrs2_cfg GUI
    %     handles.showsrs2 = handle of primary controlled showsrs2 window
    %     handles.currImage = handle of primary current image
    %     handles.currImageIndex - index of current image (into figUD image_h)
    %     handles.currImageAxes = handle of primary current image axes
    %     handles.isBaseImage = flag indicating if current image is the base image
    %     handles.showsrs2_UseTransMenu = handle of the "Use OpenGL Transparency"
    %        menu in handles.showsrs2
    %          'Checked' determines if OpenGL transparency is being used
    %          'UserData' contains the AlphaMap
    %        This is stored for fast access (findobj is slow).
    %     handles.showsrs2_WinlevButton = handle of the W+L button where
    %        the "fast layer" layerNum, cmapLim, and transLim are stored.
    handles.showsrs2 = showsrs2_h;
    handles.showsrs2_UseTransMenu = findobj(showsrs2_h,'Tag','UseTransMenu','Type','uimenu');
    handles.showsrs2_WinlevButton = findobj(showsrs2_h,'Tag','WinlevButton','Type','uicontrol');
    set(handles.showsrs2_cfgFig,'UserData',handles);
    
    % --- Initialize GUI ---
    % Set the names for the drop down menu  
    showsrs2UD = get(handles.showsrs2,'UserData');
    set(handles.controlledImageMenu,'String',showsrs2UD.image_names);
    clear showsrs2UD % Clear immediately after using to prevent accidentally changing later
        
    % Initialize the Figure Title Bar
    set(handles.showsrs2_cfgFig,'Name',sprintf('Configure Figure %d',handles.showsrs2));
    
    % Update GUI for current transparency settings.
    showsrs2_cfg('updateTransSettings_Callback',handles.showsrs2_cfgFig,[]);
    
    % Bring showsrs2_cfg back to top
    figure(handles.showsrs2_cfgFig);

    % Use base image as default image to adjust
    local_switchimage(1,handles);
  end    
  % Return GUI handle if requested
  if nargout > 0, 
    outputFig_h = gui_h;
  end
elseif ischar(varargin{1}) % INVOKE NAMED SUBFUNCTION OR CALLBACK
  try
    % Check arguments
    if nargout ~= 0,
      error('Output arguments not supported in showsrs2_cfg callbacks!');
    end
    if nargin < 3,
      error('Not enough input arguments to showsrs2_cfg callback!'); 
    end
    if ~ishandle(varargin{2}),
      error('First argument to showsrs2_cfg callback must be a valid handle of an object in the showsrs2_cfg GUI!');
    end
    % Insert handles as the 3rd callback argument and evaluate
    handles = get(getparentfigure(varargin{2}),'UserData');
    if nargin < 4
      feval(varargin{:},handles); % FEVAL switchyard
    else
      feval(varargin{1:3},handles,varargin{4:end}); % FEVAL switchyard
    end
  catch
    disp(lasterr);
  end
end

%| ABOUT CALLBACKS:
%| GUIDE automatically appends subfunction prototypes to this file, and 
%| sets objects' callback properties to call them through the FEVAL 
%| switchyard above. This comment describes that mechanism.
%|
%| Each callback subfunction declaration has the following form:
%| <SUBFUNCTION_NAME>(H, EVENTDATA, HANDLES)
%|
%| The subfunction name is composed using the object's Tag and the 
%| callback type separated by '_', e.g. 'slider2_Callback',
%| 'figure1_CloseRequestFcn', 'axis1_ButtondownFcn'.
%|
%| H is the callback object's handle (obtained using GCBO).
%|
%| EVENTDATA is empty, but reserved for future use.
%|
%| HANDLES is a structure containing handles of components in GUI using
%| tags as fieldnames, e.g. handles.figure1, handles.slider2. This
%| structure is created at GUI startup and stored in the figure's UserData.
%| A copy of the structure is passed to each callback.  Call
%| get(getparentfigure(h),'UserData') to get the handles.
%|
%| By default, the Callback property should be:
%| <MFILENAME>('<SUBFUNCTION_NAME>', gcbo, [])
%|
%| HANDLES is automatically retreived and inserted as the third callback
%| argument in the FEVAL switchyard.

% --------------------------------------------------------------------
function updateTransSettings_Callback(h, eventdata, handles, noCfgTransFlag)
% Update the GUI for the current transparency settings.
%
%   noCfgTransFlag - if false (default), showsrs2_cfgtrans GUI will
%                    be launched/raised if the overlays have different
%                    transparency levels or there is already one open.
%                  - if ture, do NOT open a showsrs2_cfgtrans GUI
%                    (Useful for closeRequestFcn of showsrs2_cfgtrans)
%
%   This handles:
%   (1) Setting the transparency slider to the correct value.
%   (2) Enabling/Disabling the transSlider based on:
%       (a) Number of overlays.
%       (b) If all overlays have the same transparency value.
%       (c) Is a showsrs2_cfgtrans windows open for this showsrs2 fig
%

if nargin < 4, noCfgTransFlag = 0; end % Set defaults

amap=get(handles.showsrs2_UseTransMenu,'UserData'); % Get current AlphaMap.
if length(amap)>1
  % There are overlays
  if (length(amap) > 2 & any(diff(amap(2:end))~=0)) | ...
      ~isempty(local_find_showsrs2_childGUI('showsrs2_cfgtransFig',handles.showsrs2))
    % Elements in amap are not equal or showsrs2_cfgtrans GUI is open for this showsrs2 figure.
    % Disable transparency adjustment and open showsrs2_cfgtrans control
    % (or bring it closer to the top).
    set(handles.showOverlaysCheckbox,'Enable','off');
    set(handles.transSlider,'Enable','off');
    if ~noCfgTransFlag, showsrs2_cfgtrans(handles.showsrs2); end
  else
    % All elements in amap equal & there is no showsrs2_cfgtrans GUI open
    % for this showsrs2 figure. Enable checkbox and update value.
    set(handles.showOverlaysCheckbox,'Enable','on','Value',ceil(amap(2)));
    if get(handles.showOverlaysCheckbox,'Value') == 0
      % If the checkbox is off, set stored transparency setting in checkbox
      % UserData to 1 so that checking the box turns on the overlay.
      set(handles.showOverlaysCheckbox,'UserData',1);
    end
    set(handles.transSlider,'Enable','On');
    set(handles.transSlider,'Value',amap(2));
  end
else
  % Only a base image, disable transparency slider & checkbox
  set(handles.showOverlaysCheckbox,'Enable','off');
  set(handles.transSlider,'Enable','off');
end

% Diable update images while moving checkbox by default if not using
% OpenGL transparency.
if strcmp(get(handles.showsrs2_UseTransMenu,'Checked'),'off')
  set(handles.updateImageCheckbox,'Value',0);
end

% Same Logic... Perhaps clearer
% % Is there a showsrs2_transcfg GUI for this showsrs2 window?
% isCfgTrans = ~isempty(local_find_showsrs2_childGUI('showsrs2_cfgtransFig',handles.showsrs2));
% % Get current AlphaMap
% amap=get(handles.showsrs2_UseTransMenu,'UserData');
% % Check if all AlphaMap elements for overlays are equal (true if just a base image)
% allAmapEqual = length(amap) < 3 | all(diff(amap(2:end) == 0);
% if length(amap) < 2 | isCfgTrans | ~allAmapEqual
%   % Elements in amap are not equal, a showsrs2_cfgtrans is open, or there
%   % is only a base image.  Disable slider & checkbox
%   set(handles.transSlider,'Enable','off');
%   set(handles.showOverlaysCheckbox,'Enable','off');
% else
%   % Enable checkbox, transSlider and update value
%   set(handles.showOverlaysCheckbox,'Enable','on','Value',ceil(amap(2)));
%   if get(handles.showOverlaysCheckbox,'Value') == 0
%     % If the checkbox is off, set stored transparency setting in checkbox
%     % UserData to 1 so that checking the box turns on the overlay.
%     set(handles.showOverlaysCheckbox,'UserData',1);
%   end
%   set(handles.transSlider,'Enable','On');
%   set(handles.transSlider,'Value',amap(2));
% end
% if ~noCfgTransFlag & length(amap) > 1 & (~allAmapEqual | isCfgTrans)
%   % Raise\Open showsrs2_cfgtrans is there are overlays and one is already
%   % open or all transLim are equal.
%   showsrs2_cfgtrans(handles.showsrs2);
% end

% --------------------------------------------------------------------
function saveCurrSettings_Callback(h, eventdata, handles)
% Save current settings.
%
% This is called by showsrs2 when switching transparency modes so that the
% image will be drawn correctly.
%
local_updateImageUserData(handles);

% --------------------------------------------------------------------
function controlledImageMenu_Callback(h, eventdata, handles)
% Configure image chosen in menu
local_switchimage(get(handles.controlledImageMenu,'Value'),handles);

% --------------------------------------------------------------------
function changeColormapMenu_Callback(h, eventdata, handles)
% Change colormap to that shown in the menu
%
%  NOTE: Changes UserData for current image (updates cmap field)
cmap_i = get(h,'Value');

% Make sure that they didn't just chose the description item
if cmap_i > 1
  cmaps = get(h,'String');
  cmapParams = get(h,'UserData');
  cmapParams = cmapParams{cmap_i}; % Get colormap parameters for current entry
  try
    success = 1;  % Variable to track if feval sucessful
    cmap = feval(cmaps{cmap_i},cmapParams{:});  % Make a colormap with specified options
  catch
    warning(sprintf('Unable to generate colormap %s. Colormap unchanged.\n%s',cmaps{cmap_i},lasterr));
    success = 0;
  end
  
  % Update colorbar if cmap generation sucessful
  if success
    % Update colorbar
    local_updateColorbar(handles.colorbarImage,cmap);
    
    % Update colormap in current image UserData
    imageUD=get(handles.currImage,'UserData');
    imageUD.cmap=cmap;
    set(handles.currImage,'UserData',imageUD);
  end

  % Set colormap menu back to description
  set(h,'Value',1);
  
  % Refresh display
  showsrs2('Refresh_Callback',handles.showsrs2);
  
  % Update the time series plot for the new colormap
  showsrs2('RefreshPlotTimeSrs_Callback',handles.showsrs2);
end

% --------------------------------------------------------------------
function linkToCmapLimitCheckbox_Callback(h, eventdata, handles)
% Link/unlink the transparency limit to the lower clim

if get(handles.linkToCmapLimitCheckbox,'Value')
  % Link
  set(handles.transLimitEdit,'Enable','off'); % Disable editing the transparency limit by the user
  set(handles.transLimLine,'Visible','off');  % Hide the line on the GUI
  
  % Get clim settings from edit boxes
  clim(1) = str2num(get(handles.lowerClimEdit,'String'));
  clim(2) = str2num(get(handles.upperClimEdit,'String')); 
  
  % Set transLim equal to clim
  transLim = clim(1);  % Copy clim(1)
  set(handles.transLimLine,'XData',transLim*ones(1,11));  % Update translim line on GUI
  % Update transLim text box using clim string directly to avoid losing
  % precision with num2str.
  set(handles.transLimitEdit,'String',get(handles.lowerClimEdit,'String'));
  
  % Update the clipping limits on the image
  local_applyLimits(handles,clim,transLim);  
else
  % Unlink
  set(handles.transLimitEdit,'Enable','on'); % Enable editing the transparency limit by the user
  set(handles.transLimLine,'Visible','on');  % Show the line in the GUI
end

% --------------------------------------------------------------------
function flipLimitsCheckbox_Callback(h, eventdata, handles)
disp('Not implemented!');

% --------------------------------------------------------------------
function showOverlaysCheckbox_Callback(h, eventdata, handles)
% Toggle the transparency between off and setting from transSlider

% Determine number of overlays
nOverlays=length(subsref(get(handles.showsrs2,'UserData'),struct('type','.','subs','image_h')))-1;

if get(handles.showOverlaysCheckbox,'Value')
  % If checked, set the transparency level to the stored value
  set(handles.transSlider,'Value',get(handles.showOverlaysCheckbox,'UserData')); % Set trans slider
else
  % If unchecked, store the current transparency setting in the checkbox userdata and set the transparency to 0
  set(handles.showOverlaysCheckbox,'UserData',get(handles.transSlider,'Value'));
  set(handles.transSlider,'Value',0);  % Set trans slider
end

% Set the transparency to the current slider value (for all overlays)
amap=[0 get(handles.transSlider,'Value').*ones(1,nOverlays)];
set(handles.showsrs2_UseTransMenu,'UserData',amap);

if strcmp(get(handles.showsrs2_UseTransMenu,'Checked'),'on')
  % Update AlphaMap in figure if we are using OpenGL transparency
  set(handles.showsrs2,'AlphaMap',amap);
else
  % Refresh display if not using OpenGL transparency
  showsrs2('Refresh_Callback',handles.showsrs2);
end

% --------------------------------------------------------------------
function transSlider_Callback(h, eventdata, handles)
% Adjust transparency of all overlays to slider value.

% Determine number of overlays
nOverlays=length(subsref(get(handles.showsrs2,'UserData'),struct('type','.','subs','image_h')))-1;

% Get current transparency limit from slider.
transLim = get(handles.transSlider,'Value');

% Update the show overlays checkbox for the current setting.
if transLim == 0
  % Overlay turned off with slider, turn checkbox off and set transparency
  % value stored in checkbox UserData to 1 so that unchecking turns the
  % overlay on.
  set(handles.showOverlaysCheckbox,'Value',0,'UserData',1);
else
  % Overlay NOT turned off with slider.  Turn checkbox on if necessary
  if ~get(handles.showOverlaysCheckbox,'Value')
    set(handles.showOverlaysCheckbox,'Value',1);
  end
end

% Set the transparency to the current slider value (for all overlays)
amap=[0 transLim.*ones(1,nOverlays)];
set(handles.showsrs2_UseTransMenu,'UserData',amap);

if strcmp(get(handles.showsrs2_UseTransMenu,'Checked'),'on')
  % Update AlphaMap in figure if we are using OpenGL transparency
  set(handles.showsrs2,'AlphaMap',amap);
else
  % Refresh display if not using OpenGL transparency
  showsrs2('Refresh_Callback',handles.showsrs2);
end

% --------------------------------------------------------------------
function startUpperClim_Callback(h, eventdata, handles)   
% Set the callbacks appropriately
set(handles.showsrs2_cfgFig,'WindowButtonMotionFcn','showsrs2_cfg(''moveUpperClim_Callback'',gcbo,[])');
set(handles.showsrs2_cfgFig,'WindowButtonUpFcn','showsrs2_cfg(''stopMotion_Callback'',gcbo,[])');

% --------------------------------------------------------------------
function startLowerClim_Callback(h, eventdata, handles)
% Set the callbacks appropriately
set(handles.showsrs2_cfgFig,'WindowButtonMotionFcn','showsrs2_cfg(''moveLowerClim_Callback'',gcbo,[])');
set(handles.showsrs2_cfgFig,'WindowButtonUpFcn','showsrs2_cfg(''stopMotion_Callback'',gcbo,[])');

% --------------------------------------------------------------------
function startTransLim_Callback(h, eventdata, handles)
% Set the callbacks appropriately
set(handles.showsrs2_cfgFig,'WindowButtonMotionFcn','showsrs2_cfg(''moveTransLim_Callback'',gcbo,[])');
set(handles.showsrs2_cfgFig,'WindowButtonUpFcn','showsrs2_cfg(''stopMotion_Callback'',gcbo,[])');

% --------------------------------------------------------------------
function moveUpperClim_Callback(h, eventdata, handles)
currPt=get(gca,'CurrentPoint');             % Get the cursor Position
clim = [str2num(get(handles.lowerClimEdit,'String')), currPt(1,1)]; % Set new clim

% Don't allow user to move Upper limit past lower limit
if clim(2) <= clim(1)
  clim(2) = clim(1)+0.001;
end

% If image is an overlay, handle transparency limits
if ~handles.isBaseImage
  transLim = str2num(get(handles.transLimitEdit,'String')); % Get current transparency limit from edit box
  % Don't allow user to move lower limit past transLim
  if clim(2) <= transLim, clim(2) = transLim; end
else
  transLim = -Inf;  % TransLim not relevant for base image, but need to pass something to local_applyLimits
end

% Draw a new upper clim line at that level
set(handles.upperClimLine,'XData',clim(2)*ones(1,11));

% Update the upper clim Text box
% TODO: Handle precision loss in num2str.
set(handles.upperClimEdit,'String',num2str(clim(2),8));

% Update the clipping limits on the image
if get(handles.updateImageCheckbox,'Value') == 1
  local_applyLimits(handles,clim,transLim);
end  

% --------------------------------------------------------------------
function moveLowerClim_Callback(h, eventdata, handles)
currPt=get(gca,'CurrentPoint');      % Get the cursor Position
clim = [currPt(1,1), str2num(get(handles.upperClimEdit,'String'))]; % Set new clim

% Don't allow user to move lower limit past upper limit
if clim(1) >= clim(2)
  clim(1) = clim(2)-0.001;
end

% If image is an overlay, handle transparency limits
if ~handles.isBaseImage
  % Check if transLim is linked to the lowerClim
  if get(handles.linkToCmapLimitCheckbox,'Value')
    % Transparency limit linked to the lowerClim
    % TODO: Handle precision loss in num2str (the same as lower Clim string)
    transLim = clim(1);  % Copy clim(1)
    set(handles.transLimitEdit,'String',num2str(transLim,8)); % Update transLim text box
    set(handles.transLimLine,'XData',transLim*ones(1,11));  % Update translim line on GUI
  else
    % Transparency limit not linked to the lowerClim
    transLim = str2num(get(handles.transLimitEdit,'String')); % Get current transparency limit from edit box
    % Don't allow user to move lower limit past transLim
    if clim(1) >= transLim, clim(1) = transLim; end
  end
else
  transLim = -Inf;  % TransLim not relevant for base image, but need to pass something to local_applyLimits
end

% Draw a new Lower Clim line at that level
set(handles.lowerClimLine,'XData',clim(1)*ones(1,11));

% Update the Lower Clim limit Text boxes
% TODO: Handle precision loss in num2str
set(handles.lowerClimEdit,'String',num2str(clim(1),8));

% Update the clipping limits on the image
if get(handles.updateImageCheckbox,'Value') == 1
  local_applyLimits(handles,clim,transLim);
end  

% --------------------------------------------------------------------
function moveTransLim_Callback(h, eventdata, handles)
% Handle motion of transparency limit line on histogram.  
% Note: This line will only be present for overlay images which are
%       not linked to the clim.
currPt=get(gca,'CurrentPoint');         % Get the cursor Position
clim = [str2num(get(handles.lowerClimEdit,'String')), ...
    str2num(get(handles.upperClimEdit,'String'))]; % Get current Clim settings.

% Calculate new transLim
transLim = currPt(1,1);

% Don't allow user to move transLim past upper or lower clim
if transLim <= clim(1), transLim = clim(1); end
if transLim >= clim(2), transLim = clim(2); end

% Draw a new TransLim line at that level
set(handles.transLimLine,'XData',transLim*ones(1,11));

% Update the TransLim line text boxes
% TODO: Handle precision loss in num2str
set(handles.transLimitEdit,'String',num2str(transLim,8));

% Update the clipping limits on the image
if get(handles.updateImageCheckbox,'Value') == 1
  local_applyLimits(handles,clim,transLim);
end  

% --------------------------------------------------------------------
function stopMotion_Callback(h, eventdata, handles)
% Set the callbacks appropriately
set(handles.showsrs2_cfgFig,'WindowButtonMotionFcn','');
set(handles.showsrs2_cfgFig,'WindowButtonUpFcn','');

% Get current line positions
clim(1) = max(get(handles.lowerClimLine,'XData'));
clim(2) = max(get(handles.upperClimLine,'XData'));

% Update text boxes
% TODO: Handle precision loss in num2str
set(handles.lowerClimEdit,'String',num2str(clim(1),8));
set(handles.upperClimEdit,'String',num2str(clim(2),8));

% If image is an overlay, handle transparency limits
if ~handles.isBaseImage
  % Get transLim
  if get(handles.linkToCmapLimitCheckbox,'Value')
    % Transparency limit linked to the lowerClim
    transLim = clim(1);  % Copy clim(1)
    set(handles.transLimLine,'XData',transLim*ones(1,11));  % Update translim line on GUI
  else  
    % Transparency limit not linked to the lowerClim
    transLim = max(get(handles.transLimLine,'XData')); % Get location from Line
  end
  % TODO: Handle precision loss in num2str
  set(handles.transLimitEdit,'String',num2str(transLim,8)); % Update transLim text box
else
  transLim = -Inf;  % TransLim not relevant for base image, but need to pass something to local_applyLimits
end

% Update the clipping limits on the image
local_applyLimits(handles,clim,transLim);

% --------------------------------------------------------------------
function setLimits_Callback(h, eventdata, handles)
% This callback handles updating the colormap and transparency limits to reflect the values in the
% user modified text boxes.

% Get setting from edit boxes
try
  clim(1) = str2num(get(handles.lowerClimEdit,'String'));
catch % Catch invalid strings
  waitfor(warndlg('Invalid lower colormap limit!  Reverting to previous value.', ...
    'Invalid limit','modal'));
  clim(1) = max(get(handles.lowerClimLine,'XData')); 
  set(handles.lowerClimEdit,'String',num2str(clim(1),8));
end
try
  clim(2) = str2num(get(handles.upperClimEdit,'String'));
catch % Catch invalid strings
  waitfor(warndlg('Invalid upper colormap limit!  Reverting to previous value.', ....
    'Invalid limit','modal'));
  clim(2) = max(get(handles.upperClimLine,'XData'));
  set(handles.upperClimEdit,'String',num2str(clim(2),8));  
end

% If the user tries to enter an invalid clim, return to values of lines.
if clim(1) >= clim(2)
  waitfor(warndlg(['Upper colormap limit must be greater than lower colormap', ... 
    ' limit! Reverting to previous value.'],'Invalid limit','modal'));
  clim = [max(get(handles.lowerClimLine,'XData')), ...
      max(get(handles.upperClimLine,'XData'))]; % Get current Clim settings.
  set(handles.lowerClimEdit,'String',num2str(clim(1),8));
  set(handles.upperClimEdit,'String',num2str(clim(2),8));
end

% Update lines on GUI
set(handles.lowerClimLine,'XData',clim(1)*ones(1,11));
set(handles.upperClimLine,'XData',clim(2)*ones(1,11));

% If image is an overlay, handle transparency limits
if ~handles.isBaseImage
  % Check if transLim is linked to the lowerClim
  if get(handles.linkToCmapLimitCheckbox,'Value')
    % Transparency limit linked to the lowerClim
    % NOTE: Transparency limit cannot be edited when linked to the lowerClim
    % Set transLim equal to clim
    transLim = clim(1);  % Copy clim(1)
    % Update transLim text box using clim string directly to avoid losing
    % precision with num2str.
    set(handles.transLimitEdit,'String',get(handles.lowerClimEdit,'String'));
  else  
    % Transparency limit not linked to the lowerClim
    
    % Get transLim from edit box
    transLim = str2num(get(handles.transLimitEdit,'String'));
    if isempty(transLim) % Catch invalid strings.
      waitfor(warndlg('Invalid transparency limit!  Reverting to previous value.', ...
        'Invalid limit','modal'));
      transLim = max(get(handles.transLimLine,'XData')); 
      set(handles.transLimitEdit,'String',num2str(transLim,8));
    end
    
    % If the user tries to enter an invalid transLim, set it the line value.
    if transLim < clim(1) | transLim > clim(2)
      waitfor(warndlg(['Transparency limit must be between the upper and lower ', ...
          'colormap limits!  Reverting to previous value.'],'Invalid limit','modal'));
      transLim = max(get(handles.transLimLine,'XData')); 
      set(handles.transLimitEdit,'String',num2str(transLim,8));
    end  
  end   
  % Update translim line on GUI
  set(handles.transLimLine,'XData',transLim*ones(1,11));    
else
  transLim = -Inf;  % TransLim not relevant for base image, but need to pass something to local_applyLimits
end

% Update the clipping limits on the image
local_applyLimits(handles,clim,transLim);

% -------------------- local_switchimage -----------------------------
function local_switchimage(handle_index,handles)
% local_switchimage - switch GUI to adjust new image
%
% local_switchimage(handle_index)
%      
%    handle_index - index into the showsrs2 image handles array
%    handles - structure of handles for showsrs2_cfg GUI
%
%  'UserData' use:  showsrs2 Image UserData - generates histCount if necessary
%                   calls local_updateImageUserData
%                   Updates handles.currImage,
%                           handles.currImageIndex,
%                           handles.currImageAxes
%                           handles.isBaseImage
%                           handles.lowerClimLine
%                           handles.upperClimLine
% 

if isfield(handles,'currImage')
  % This function has been called before, store info for previous image
  local_updateImageUserData(handles);
end

% Get the handle for the current image (showsrs2UD.image_h(handle_index))
handles.currImage = subsref(subsref(get(handles.showsrs2,'UserData'), ...
  struct('type','.','subs','image_h')),struct('type','()','subs',{{handle_index}}));
%showsrs2UD = get(handles.showsrs2,'UserData'); handles.currImage = showsrs2UD.image_h(handle_index); clear showsrs2UD;
handles.currImageIndex = handle_index;
handles.currImageAxes = get(handles.currImage,'Parent');
handles.isBaseImage = (handle_index == 1); % Base image is always first image

% Get the image information from the userdata of the current image
imageUD = get(handles.currImage,'UserData');

% Check for valid cmapLim and transLim
% TODO: Handle these more gracefully
if imageUD.cmapLim(1) >= imageUD.cmapLim(2)
  error('Invalid colormap limits');
end
if ~handles.isBaseImage % Don't do this for base images
  if imageUD.transLim > imageUD.cmapLim(2) | imageUD.transLim < imageUD.cmapLim(1)
    error('Invalid transparency limit');
  end
end

% Generate a histogram of the image data
axes(handles.histAxes)
if isempty(imageUD.histCount) | isempty(imageUD.histBins)
  % If a histogram has not been generated for this image, make it and store it
  %   The histogram is stored in with the image userdata for so that it does not need to be 
  %   calculated several times (for increase performance when switching between images to configure)

  % Use histc directly since it supports all numeric types (similar to hist)
  dataMin = double(min(imageUD.srs(:)));
  dataMax = double(max(imageUD.srs(:)));
  nBins = 100;
  if dataMin == dataMax
    % Only one value, make nBins of width one centered at value
    dataMin = dataMin - floor(nBins/2) - 0.5;
    dataMax = dataMin + nBins;
  end
  % Calculate bins
  binWidth = (dataMax-dataMin)/nBins;
  binEdges = dataMin + binWidth*[0:nBins];
  binEdges(end) = dataMax; % To avoid precision errors
  imageUD.histBins = binEdges(1:end-1) + binWidth/2; % Bin centers
  % Calculate counts (see histc for the handling of edges)
  if islogical(imageUD.srs) & ~isa(imageUD.srs,'double')
    % HISTC does not handle logical type inputs.  For MATLAB 6.1 and
    % earlier, I don't think that this is a problem because logical arrays
    % are actually doubles (hense the isa double qualification).
    count = histc(uint8(imageUD.srs(:)), binEdges);
  else
    count = histc(imageUD.srs(:), binEdges);
  end
  % Combine last two bins since last bin only includes == histEdges(end)
  count = [count(1:end-2); count(end-1)+count(end)];
  % Plot the log of count rather than count (turn of warnings to supress log zero warning)
  % NOTE: Should the -Inf's be replaced/removed???
  warning('off'); imageUD.histCount = log10(count); warning('on');
  % Save the results
  set(handles.currImage,'UserData',imageUD);
end
% Plot the histogram
bar(imageUD.histBins,imageUD.histCount,'hist');
% Make axes and labels black with a size 8 font.  Turn off shading of bars
% (they are too close together for shading) and label y axes
% NOTE: These properties are reset by bar, so we have to set them everytime.
set(handles.histAxes,'XColor',[0 0 0],'YColor',[0 0 0],'FontSize',8,'Color','none');
shading(handles.histAxes,'Flat');
ylabel('log(# voxels)','FontSize',8);

% Find the limits of the Y axis of the histogram and plot lines at the 
% upper and lower clipping limits
ylim = get(gca,'YLim');

handles.lowerClimLine=line(imageUD.cmapLim(1)*ones(1,11),ylim(1):(ylim(2)-ylim(1))/10:ylim(2), ...
  'Tag','lowerClimLine', ...
  'ButtonDownFcn','showsrs2_cfg(''startLowerClim_Callback'',gcbo,[])', ...
  'LineWidth',2);

handles.upperClimLine=line(imageUD.cmapLim(2)*ones(1,11),ylim(1):(ylim(2)-ylim(1))/10:ylim(2), ...
  'Tag','upperClimLine', ...
  'ButtonDownFcn','showsrs2_cfg(''startUpperClim_Callback'',gcbo,[])', ...
  'LineWidth',2);

if ~handles.isBaseImage % Don't do this for base images
  handles.transLimLine = line(imageUD.transLim*ones(1,11),ylim(1):(ylim(2)-ylim(1))/10:ylim(2), ...
    'Tag','transLimLine', 'LineWidth', 2, 'Color','green', ...
    'ButtonDownFcn','showsrs2_cfg(''startTransLim_Callback'',gcbo,[])');
  
  % If transLim and cmapLim(1) are the same, assume that they are linked
  if imageUD.cmapLim(1) == imageUD.transLim
    set(handles.linkToCmapLimitCheckbox,'Value',1,'Enable','on');
    set(handles.transLimitEdit,'Enable','off'); % Disable editing the transparency limit by the user
    set(handles.transLimLine,'Visible','off');
  else
    set(handles.linkToCmapLimitCheckbox,'Value',0,'Enable','on');
    set(handles.transLimitEdit,'Enable','on'); % Enable editing the transparency limit by the user
    set(handles.transLimLine,'Visible','on');
  end
  
  % Update the Transparency Limit Text boxes in the GUI
  set(handles.transLimitEdit,'String',imageUD.transLim);
  set(handles.transLimitText,'Enable','on');  % Enable label for box since it is relevant

else % Base image doesn't have transparency
  % Disable the Transparency related items in the GUI
  set(handles.transLimitEdit,'String','','Enable','off');
  set(handles.transLimitText,'Enable','off');  % Disable label for box since it is not relevant
  set(handles.linkToCmapLimitCheckbox,'Value',0,'Enable','off');
  
  % Delete the transparency line if it exists
  if isfield(handles,'transLimLine') & ishandle(handles.transLimLine), delete(handles.transLimLine), end 
end

% Update the Upper and Lower Limit Text boxes in the GUI
set(handles.lowerClimEdit,'String',imageUD.cmapLim(1));
set(handles.upperClimEdit,'String',imageUD.cmapLim(2));
if ~handles.isBaseImage
  % Update the transparency limit text box in the GUI
  set(handles.transLimitEdit,'String',imageUD.transLim);
end

% TODO: Handle flipping images

% Update colorbar
local_updateColorbar(handles.colorbarImage,imageUD.cmap);

set(handles.showsrs2_cfgFig,'UserData',handles); % Store updated handles

% --- Update showsrs2 window ---

% Update clipping and transparency levels
% TransLim not relevant for base image, but need to pass something to local_applyLimits
if handles.isBaseImage, transLim = -Inf; else transLim = imageUD.transLim; end
local_applyLimits(handles,imageUD.cmapLim,transLim);

% Refresh display
showsrs2('Refresh_Callback',handles.showsrs2); % Do a full refresh.
figure(handles.showsrs2_cfgFig); % Bring config figure back to front

% -------------------- local_updateImageUserData -----------------------------
function local_updateImageUserData(handles)
% local_updateImageUserData - update image userdata for current settings
%
%  Updates cmapLim & transLim fields in current image UserData to 
%  reflect the setting in the showsrs_cfg GUI.
%      
%  local_updateImageUserData(handles)
%    handles - structure of handles for showsrs2_cfg GUI
%
%  Inputs:   UserData for current image and current GUI fields
%  Changes:  UserData for current image
%
% Note: Does not update cmap! imageUD.cmap updated in changeColormapMenu_Callback()
%

% Get current image UserData 
imageUD = get(handles.currImage,'UserData');

% Update UserData structure for image
%   Fields to update:
%     In base and overlays: cmapLim
%     Only in overlays:     transLim
imageUD.cmapLim(1) = str2num(get(handles.lowerClimEdit,'String'));
imageUD.cmapLim(2) = str2num(get(handles.upperClimEdit,'String')); 

if ~handles.isBaseImage
  % Overlay only fields
  imageUD.transLim = str2num(get(handles.transLimitEdit,'String'));
end

% Store updates
set(handles.currImage,'UserData',imageUD);

% -------------------showsrs2_cfgFig_CloseRequestFcn----------------------
function showsrs2_cfgFig_CloseRequestFcn(h, eventdata, handles)
% Close Request Function for Configuration GUI
%
% (1) Store info for current image
% (2) Switch all images back to RGB mode
% (3) Delete GUI
%

try
  % Store info for current image
  local_updateImageUserData(handles);

  % Update FastInfo array {layerNum,cmapLim,transLim
  % -> Turn off layerNum and set cmapLim and transLim to dummy values (for
  %    no particular reason)
  set(handles.showsrs2_WinlevButton,'UserData',{[],[0 1],1});
  
  % Refresh display
  showsrs2('Refresh_Callback',handles.showsrs2);
  
  % Delete the showsrs2_cfg figure
  delete(handles.showsrs2_cfgFig);
catch
  % Something failed.  Just delete the cfg GUI and issue an error!
  delete(handles.showsrs2_cfgFig);
  error('Unable to update showsrs2 figure properly!  Please configure showsrs2 window again!');
end

% -------------------- local_applyLimits -----------------------------
function local_applyLimits(handles,cmapLim,transLim)
% local_applyLimits - Update display for current cmapLim and transLim
%
%  Update display using current cmapLim and transLim on currently select
%  layer.
%      
%  local_applyLimits(handles,clim,transLim);
%    handles - structure of handles for showsrs2_cfg GUI
%    clim - Clipping limits for colormap
%    transLim - transparency limit
%

% Set transLim to -Inf for base image since it is not relevant.
if handles.isBaseImage, transLim = -Inf; end

% Update FastInfo array {layerNum,cmapLim,transLim}
set(handles.showsrs2_WinlevButton,'UserData',{handles.currImageIndex,cmapLim,transLim});

% Refresh display (current layer only)
showsrs2('Refresh_Callback',handles.showsrs2,2);

% -------------------- local_updateColorbar ---------------------------
function local_updateColorbar(colorbar_h,cmap)
% local_updateColorbar - update the colorbar to the passed colormap
%
%  local_updateColorbar(colorbar_h,cmap)
%
%        colorbar_h - handle for colorbar image
%        cmap - desired colormap
%

% Check that it is a valid colormap
if size(cmap,2) ~= 3 | min(cmap(:)) < 0 | max(cmap(:)) > 1
  error('Colormap must have n x 3 elements between 0 and 1');
end

% Generate a RGB image of the colormap (convert to uint8 (8 bits per color) for better performance)
rgbColorbar = uint8(round(ind2rgb([1:size(cmap,1)]',cmap)*255));

% Update colorbar image
set(colorbar_h,'CData',rgbColorbar);
set(get(colorbar_h,'Parent'),'YLim',[0.5,size(cmap,1)+0.5]);  % Update limits for different length colormaps

% --------------------------------------------------------------------
function handles=local_initializegui
% Initialize new transslider GUI
% 
%   In addition to initializing the GUI, this function sets up a structure
%   of handles to element in the GUI.  The struct is similar to that
%   returned by guihandles() in MATLAB 6 and later except it only includes
%   some of the GUI elements.

% Use system color scheme for figure
fig = figure('Units','Characters', ...
  'IntegerHandle','off','Tag','showsrs2_cfgFig','MenuBar','none', ...
  'NumberTitle','off','Resize','off','Visible','off', ...
  'Color',get(0,'defaultUicontrolBackgroundColor'), ...
  ... %'HandleVisibility','callback', ...
  'CloseRequestFcn','showsrs2_cfg(''showsrs2_cfgFig_CloseRequestFcn'',gcbo,[])');
handles.showsrs2_cfgFig=fig;

% Use MATLAB's auto figure positioning, but set size.
pos=get(fig,'Position'); pos(3:4)=[40,36]; set(fig,'Position',pos);

% --- Setup current base/overlay controls ---
% Menu to select which image to adjust
handles.controlledImageMenu = uicontrol(fig,'Units','Characters','Style','popupmenu', ...
  'Position',[5 32.5 30 1.5],'Tag','controlledImageMenu','String',{'Popup Menu'}, ...
  'Callback','showsrs2_cfg(''controlledImageMenu_Callback'',gcbo,[])');
handles.image2cfgText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[5 34 30 1],'Tag','image2cfgText','String','Image To Configure');

% Generate histogram axes.
handles.histAxes = axes('Units','Characters', ...
  'Position',[5 25 30 7],'Tag','histAxes');

% Colormap and Transparency Clipping Label and Edit Boxes
handles.upperClimEdit = uicontrol(fig,'Units','Characters','Style','edit', ...
  'Position',[12 21 23 1.5],'Tag','upperClimEdit','String','', ...
  'Callback','showsrs2_cfg(''setLimits_Callback'',gcbo,[])');
handles.transLimitEdit = uicontrol(fig,'Units','Characters','Style','edit', ...
  'Position',[12 18 23 1.5],'Tag','transLimitEdit','String','', ...
  'Callback','showsrs2_cfg(''setLimits_Callback'',gcbo,[])');
handles.lowerClimEdit = uicontrol(fig,'Units','Characters','Style','edit', ...
  'Position',[12 14 23 1.5],'Tag','lowerClimEdit','String','', ...
  'Callback','showsrs2_cfg(''setLimits_Callback'',gcbo,[])');
handles.lowerClimText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[12 15.5 23 1],'Tag','lowerClimText','String','Colormap Lower Limit');
handles.transLimitText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[12 19.5 23 1],'Tag','transLimitText','String','Transparency Limit');
handles.upperClimText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[12 22.5 23 1],'Tag','upperClimText','String','Colormap Upper Limit');

% Checkbox to control Linking of colormap limit and trans limit
handles.linkToCmapLimitCheckbox = uicontrol(fig,'Units','Characters','Style','checkbox', ...
  'Position',[12 17 25 1],'Tag','linkToCmapLimitCheckbox','String','Link to Colormap Limit', ...
  'Callback','showsrs2_cfg(''linkToCmapLimitCheckbox_Callback'',gcbo,[])', ...
  'Value',1);

% Checkbox to reverse the limits
handles.flipLimitsCheckbox = uicontrol(fig,'Units','Characters','Style','checkbox', ...
  'Position',[12 10 14 1],'Tag','flipLimitsCheckbox','String','Flip Limits', ...
  'Callback','showsrs2_cfg(''flipLimitsCheckbox_Callback'',gcbo,[])', ...
  'Value',0,'Visible','off');

% Generate the colormap axes, image, and menu
handles.colorbarAxes = axes('Units','Characters', ...
  'Position',[5 10 5 13.5],'Tag','colorbarAxes', ...
  'XTick',[],'YTick',[],'Units','Characters', ...
  'XLim',[0.5 1.5],'YLim',[0.5 256.5]);
handles.colorbarImage = image('Tag','colorbarImage','CData',uint8(zeros(256,1,3)));
handles.changeColormapMenu = uicontrol(fig,'Units','Characters','Style','popupmenu', ...
  'Position',[12 11.5 23 1.5],'Tag','changeColormapMenu','String','Change Colormap', ...
  'Callback','showsrs2_cfg(''changeColormapMenu_Callback'',gcbo,[])');

% Initialize the colormap listbox (1st item is description)
% Initialized cmapParams to values to pass each colormap function using feval
%  STORE cmapParams in listbox UserData
cmapOptions = {'Change Colormap ...','redpos','blupos','gray','redneg','bluneg', ...
    'redgrad','greengrad','bluegrad','yellowgrad','cyangrad','magentagrad', ...
    'autumn','bone','colorcube','cool','copper','hot', ...
    'hsv','jet','pink','prism','spring','summer', ...
    'white','winter','redblue'};
cmapLength=256;  % Set a default colormap length
defGradParams = {cmapLength,0.5,1.0};  % Colormap parameters for grad* colormaps
% NOTE: 1st entry is dummy entry for menu description item
cmapParams = {{},{cmapLength},{cmapLength},{cmapLength},{cmapLength},{cmapLength}, ...
    defGradParams,defGradParams,defGradParams,defGradParams,defGradParams,defGradParams ...
  {cmapLength},{cmapLength},{cmapLength},{cmapLength},{cmapLength},{cmapLength}, ...
    {cmapLength},{cmapLength},{cmapLength},{cmapLength},{cmapLength},{cmapLength}, ...
    {cmapLength},{cmapLength},{cmapLength}};
clear('defGradParams','cmapLength');
if length(cmapParams) ~= length(cmapOptions)
  % Check that I entered a cmapParams for each menu item
  emsg='Different number of colormap menu items and parameters!'; error(emsg);
end
% Only include colormap choices that exist
toRemove = [];
for n=2:length(cmapOptions)
  if ~exist(cmapOptions{n},'file')
    toRemove = [toRemove n];
  end
end
cmapParams(toRemove) = [];
cmapOptions(toRemove) = [];
set(handles.changeColormapMenu,'String',cmapOptions);
set(handles.changeColormapMenu,'UserData',cmapParams);

% --- Setup Figure options section ---
% Create Frame and title for this section
handles.transFrame = uicontrol(fig,'Units','Characters','Style','frame', ...
  'Position',[-0.1 -0.1 40.2 9.1],'Tag','transFrame','String',{''}, ...
  'Callback','');
handles.figureSettingsText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[5 7 30 1],'Tag','figureSettingsText','String','Figure Settings', ...
  'BackgroundColor',[1 1 1]);

% Setup Transparency slider, labels, and checkbox
%   Set transSlider button down function to launch showsrs2_cfgtrans 
%   if transSlider is disabled or on a right click.
handles.transSlider = uicontrol(fig,'Units','Characters','Style','slider', ...
  'Position',[5 4 30 1.2],'Tag','transSlider','String',{''}, ...
  'Callback','showsrs2_cfg(''transSlider_Callback'',gcbo,[])', ...
  'SliderStep',[0.01 0.1],'Value',1,'ButtonDownFcn', ...
  'showsrs2_cfgtrans(subsref(get(getparentfigure(gcbf),''UserData''),struct(''type'',''.'',''subs'',''showsrs2'')));');
handles.opaqueText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[25 5.5 10 1],'Tag','opaqueText','String','Opaque');
handles.translucentText = uicontrol(fig,'Units','Characters','Style','text', ...
  'Position',[5 5.5 14 1],'Tag','translucentText','String','Translucent');
handles.showOverlaysCheckbox = uicontrol(fig,'Units','Characters','Style','checkbox', ...
  'Position',[5 2.5 20 1],'Tag','showOverlaysCheckbox','String','Show Overlays', ...
  'Callback','showsrs2_cfg(''showOverlaysCheckbox_Callback'',gcbo,[])', ...
  'Value',1);

% Create checkbox to control when images are updated.
handles.updateImageCheckbox = uicontrol(fig,'Units','Characters','Style','checkbox', ...
  'Position',[5 1 30 1],'Tag','updateImageCheckbox','String','Update Image while moving', ...
  'Callback','','Value',1);

% Make figure visible
set(fig,'Visible','on');

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

% Modification History:
%
% $Log: showsrs2_cfg.m,v $
% Revision 1.25  2005/02/03 16:58:44  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.24  2005/01/08 04:13:25  michelich
% Renamed refreshPlotTimeSrs_Callback to RefreshPlotTimeSrs_Callback.
%
% Revision 1.23  2004/10/11 20:05:37  michelich
% Fix calculating histogram for logical array on MATLAB 6.5 and later.
%
% Revision 1.22  2004/05/10 23:07:32  michelich
% Added missing semicolons.
%
% Revision 1.21  2004/05/05 23:08:21  michelich
% Calculate histogram using histc instead of hist.
%
% Revision 1.20  2003/10/22 15:54:39  gadde
% Make some CVS info accessible through variables
%
% Revision 1.19  2003/09/05 15:46:09  michelich
% Reordered uicontrol creation for more intuitive tab order.
%
% Revision 1.18  2003/06/18 17:06:04  michelich
% Use cmapLim and transLim text fields as "master" values.
% Increased precision of num2str to 8 digits.
% Copy cmapLim(1) string directly to transLim string when linked to avoid precision loss.
% Added better user feedback when entering invalid limits.
% Revert to old transLim instead of cmapLim(1) when transLim invalid.
%
% Revision 1.17  2003/06/18 15:55:43  michelich
% Implemented FastInfo array to handle storing limits for layer currently
%   being modified (so that other refreshes use the proper limits).
% Removed extra drawnow's since local_applyLimits handles this already.
%
% Revision 1.16  2003/06/17 14:02:24  michelich
% Instead of disabling transparency without OpenGL, calculate merged image:
% - Don't disable transparency controls when not using OpenGL transparency.
% - Default "Update Images While Moving" to off if not using OpenGL trans.
% - Created saveCurrSettings_Callback to save settings from showsrs2 callback.
%
% Revision 1.15  2003/06/16 13:54:37  michelich
% showsrs2_cfg changes for MATLAB 5.3 support:
% - Create GUI using local_initializegui instead of loading .fig file.
% - Removed all guihandles calls (Generated handles in local_initializegui)
% - Removed all guidata calls (Store handles in figure UserData)
% - Added updateTransSettings_Callback to update GUI for current
%   transparency settings (transLims, UseTransMenu state, showsrs2_cfgtrans
%   GUI open, etc.)
% - Automatically add handles to callback arguments in feval switchyard
% - Use Refresh_Callback instead of Slider_Callback to refresh showsrs2 fig
% - Keep master copy of alphamap in showsrs2_h UseTransMapMenu.
% - Only update figure 'AlphaMap' property when transparency being used.
% - local_applyLimits: Use new Refresh_Callback arguments to pass current
%   cmapLim and transLim instead of CLim and ALim.
% - Use limit line locations, instead of CLim for "master" clipping limits
%   since CLim and ALim are not being used to transfer cmapLim & transLim
%   to showsrs2().
% Other changes:
% - Changed main function to use a single output argument since varargout
%   not used.
% - Removed varargin and varargout from callbacks (not used)
% - Return gui_h even if GUI is already open.
% - Update show overlay checkbox & stored value when slider dragged to off.
% - Set default "stored" value if overlay off on launch.
% - Adjust colorbar axis YLim for the colormap length
% - Only include colormap options that exist in path.
%
% Revision 1.14  2003/02/14 20:53:59  michelich
% Don't create h variable in base workspace when right-clicking transparency slider.
%
% Revision 1.13  2002/12/30 19:12:02  michelich
% Added option to use last colormap color for time series plot line color.
%
% Revision 1.12  2002/10/28 03:54:21  michelich
% Set histogram axes background color for proper display without colordef('none').
%
% Revision 1.11  2002/10/09 20:04:50  michelich
% Added showsrs2_cfgtrans support.
% Moved check for configuration GUIs into a local function.
%
% Revision 1.10  2002/09/27 19:54:17  michelich
% Removed old references to message box since it is no longer used.
%
% Revision 1.9  2002/09/05 14:33:41  michelich
% Disable transparency controls when there is only a base image.
%
% Revision 1.8  2002/09/04 15:47:32  michelich
% Update cmap directly in image UserData instead of passing to showsrs through figure colormap
% Updated comments
%
% Revision 1.7  2002/09/04 13:07:50  michelich
% Implemented different transparencies for each overlay
%
% Revision 1.6  2002/09/03 14:08:12  michelich
% Changed all showsrs2 calls to new callback format for showsrs2
%
% Revision 1.5  2002/08/05 19:46:31  michelich
% When switching images, moved local_applyLimits() to after the colormap
% & RGB are updated to avoid temporarily displaying incorrect image limits.
%
% Revision 1.4  2002/07/20 00:20:15  michelich
% Changed display to calculate RGB images at display time to save memory.
% Use RGB (instead of scaled) when actively updating an image to remove
%   limitations of scaled and allow for new features such as different
%   transparencies for each overlay.
%
% Revision 1.3  2002/07/19 23:02:17  michelich
% Added better error checking on GUI launch.
% Explicitly only allow one showsrs2 window per showsrs2_cfg.
% Tested reading colormaps (works).
% Fixed alimRange to 2.
%
% Revision 1.2  2002/07/02 15:58:06  michelich
% Added grad* colormap and array to specify colormap parameters
%
% Revision 1.1.1.1  2002/06/20 18:30:42  michelich
% Imported into CVS
%
%
% Pre CVS History Entries:
% Charles Michelich 2002-06-19 Moved showsrs2_calcalim to local function of showsrs2_cfg (local_calcalim)
%                              since showsrs2_cfg is the only function to use this.  Updated help comments.
% Charles Michelich 2002-04-30 Changed to support histogram cacheing in image 'UserData'
%                              Changed histogram to plot log(count) instead of changing axes to log scale
%                              Added labels, adjusted colors, and turned of shading of histogram plot
% Charles Michelich 2002-01-15 Modified to support new showsrs_calcalim warning box
% Charles Michelich 2002-01-10 Implement more callbacks and initialization
% Charles Michelich 2002-01-09 Implement callbacks
% Charles Michelich 2002-01-08 original
