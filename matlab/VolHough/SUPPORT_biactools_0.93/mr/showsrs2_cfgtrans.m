function outputFig_h=showsrs2_cfgtrans(varargin)
%SHOWSRS2_CFGTRANS - GUI to control transparency of each overlay in showsrs2
%
%    gui_h = showsrs2_cfgtrans(h)
%      Launch GUI for showsrs2 figure h.  Or if GUI already exists, make
%      it the current figure.  gui_h is the handle of the transparency GUI.
%
%    showsrs2_cfgtrans('callback_name', ...) invoke the named callback.
%
%  This function is intended for internal use by showsrs2.
%
% See also: SHOWSRS2

% CVS ID and authorship of this code
% CVSId = '$Id: showsrs2_cfgtrans.m,v 1.8 2005/02/03 16:58:44 michelich Exp $';
% CVSRevision = '$Revision: 1.8 $';
% CVSDate = '$Date: 2005/02/03 16:58:44 $';
% CVSRCSFile = '$RCSfile: showsrs2_cfgtrans.m,v $';

if nargin == 0 
  error('Insufficient number of input arguments');
  
elseif ~ischar(varargin{1})  % LAUNCH GUI
  % Check input arguments
  if nargin ~= 1
    error('Incorrect number of input arguments for launching showsrs2_cfgtrans GUI!');
  end
  showsrs2_h = varargin{1}; % Arguement is handle of showsrs2 figure to be controlled
  
  % Check handle
  if length(showsrs2_h(:)) ~= 1 | ~ishandle(showsrs2_h) | ~strcmp('figure', get(showsrs2_h,'type')) ...
      | ~strcmp(get(showsrs2_h,'Tag'),'showsrs2()')
    error('Invalid showsrs2 handle!');
  end

  % Check to see a transslider GUI is already open for this showsrs2 figure
  gui_h=local_find_showsrs2_childGUI('showsrs2_cfgtransFig',showsrs2_h);
  
  if ~isempty(gui_h)
    % GUI found, bring to front
    figure(gui_h);
  else
    % GUI not found, Open GUI (this also generates handles array to pass to callbacks)
    handles = local_initializegui(showsrs2_h);
    
    % There are no overlays if handles is empty;  Tell user.
    if isempty(handles)
      uiwait(msgbox('There are no overlays.  Unable to adjust transparencies.','No overlays','modal'));
      if nargout > 0, outputFig_h = []; end
      return;
    end

    % Store handles in figure UserData.  Use get(getparentfigure(h),'UserData') to retreive them.
    set(handles.showsrs2_cfgtransFig,'UserData',handles);
        
    % Check to see a showsrs2_cfg GUI is open for this showsrs2 figure
    showsrs2_cfg_h=local_find_showsrs2_childGUI('showsrs2_cfgFig',handles.showsrs2);
    if ~isempty(showsrs2_cfg_h),
      % Update showsrs2_cfg GUI for new transparency settings 
      % (Disabling transslider and show overlays checkboxes).
      showsrs2_cfg('updateTransSettings_Callback',showsrs2_cfg_h,[]);
    end
    
    % Update GUI for current transparency settings.
    showsrs2_cfgtrans('updateTransSettings_Callback',handles.showsrs2_cfgtransFig,[]);
    
    % Set gui_h for return argument.
    gui_h = handles.showsrs2_cfgtransFig;
  end

  % Return GUI handle if requested
  if nargout > 0
    outputFig_h = gui_h;
  end

elseif ischar(varargin{1}) % INVOKE NAMED SUBFUNCTION OR CALLBACK
  % Append handles to function arguments
  try
    if nargout ~= 0
      error('Output arguments not supported in callbacks!');
    end
    handles = get(getparentfigure(varargin{2}),'UserData');
    feval(varargin{:},handles); % FEVAL switchyard
  catch
    disp(lasterr);
  end
end

%| ABOUT CALLBACKS:
%| Callbacks are handled through subfunctions and the FEVAL switchyard
%| above. This comment describes that mechanism.
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
%| HANDLES is automatically retreived and appended to the list of Callback
%| arguments in the FEVAL switchyard.

% --------------------------------------------------------------------
function updateTransSettings_Callback(h, eventdata, handles)
% Update the GUI for the current transparency settings.
%   This handles setting the transparency sliders and checkboxes to the
%   correct values based on the current AlphaMap.

% Update sliders & checkboxes for current AlphaMap settings.
sliders_h=findobj(handles.showsrs2_cfgtransFig,'Tag','transSlider','Style','slider');
amap=get(handles.showsrs2_UseTransMenu,'UserData'); % Get current AlphaMap
for n=1:length(sliders_h)
  % Index of respective overlay stored in slider UserData.overlayNum
  % Handle of respective checkbox stored in slider UserData.checkbox_h
  transLim = amap(local_getUserDataField(sliders_h(n),'overlayNum')+1);
  checkbox_h = local_getUserDataField(sliders_h(n),'checkbox_h');
  
  if transLim > 0
    % Overlay is on.  Update the value and turn of the checkbox
    set(sliders_h(n),'Value',transLim);
    set(checkbox_h,'Value',1);
  else
    % Overlay is off.  Turn checkbox off and set storedTransLim to 1 so that
    % unchecking turns the overlay on.
    set(checkbox_h,'Value',0);
    local_setUserDataField(checkbox_h,'storedTransLim',1);
  end
end
% TODO: Decide how to handle the behavior of the following situation:
%   Set transLim to a fraction. Turn off overlay.
%   Execute updateTransSettings_Callback.  Turn on overlay.
%   transLim will be 1 instead of old setting.
%  Could keep old setting but this would not discard old setting
%    even if you wanted to (e.g. only 0/1 without transparency.)

% --------------------------------------------------------------------
function showOverlaysCheckbox_Callback(h, eventdata, handles)
% Toggle the transparency between off and on setting from transSlider

% Slider for this checkbox in application data
slider_h = local_getUserDataField(h,'slider_h');

if get(h,'Value')
  % If enabled, set the transparency level to the stored value
  set(slider_h,'Value',local_getUserDataField(h,'storedTransLim')); % Set transslider
else
  % If disabled, store the current transparency setting in the checkbox 
  % application data and set the transparency to 0
  local_setUserDataField(h,'storedTransLim',get(slider_h,'Value'));
  set(slider_h,'Value',0);  % Set transslider
end

% Update AlphaMap (respective overlay stored in slider UserData.overlayNum)
amap=get(handles.showsrs2_UseTransMenu,'UserData'); % Get current AlphaMap
amap(local_getUserDataField(slider_h,'overlayNum')+1)=get(slider_h,'Value');
set(handles.showsrs2_UseTransMenu,'UserData',amap);

% Update display
if strcmp(get(handles.showsrs2_UseTransMenu,'Checked'),'on')
  % Update AlphaMap in figure if we are using OpenGL transparency
  set(handles.showsrs2,'AlphaMap',amap);
else
  % Refresh display if not using OpenGL transparency
  showsrs2('Refresh_Callback',handles.showsrs2);
end

% --------------------------------------------------------------------
function transSlider_Callback(h, eventdata, handles)
% Update AlphaMap for value of slider pressed

% Update AlphaMap (respective overlay stored in slider UserData.overlayNum)
transLim = get(h,'Value');
amap=get(handles.showsrs2_UseTransMenu,'UserData'); % Get current AlphaMap
amap(local_getUserDataField(h,'overlayNum')+1) = transLim;
set(handles.showsrs2_UseTransMenu,'UserData',amap);

% Update the show overlays checkbox for the current setting.
checkbox_h=local_getUserDataField(h,'checkbox_h');  % Matching checkbox handle
if transLim == 0
  % Overlay turned off with slider, turn checkbox off and set
  % storedTransLim to 1 so that unchecking turns the overlay on.
  set(checkbox_h,'Value',0);
  local_setUserDataField(checkbox_h,'storedTransLim',1);
else
  % Overlay NOT turned off with slider.  Turn checkbox on if necessary
  if ~get(checkbox_h,'Value')
    set(checkbox_h,'Value',1);
  end
end

% Update display
if strcmp(get(handles.showsrs2_UseTransMenu,'Checked'),'on')
  % Update AlphaMap in figure if we are using OpenGL transparency
  set(handles.showsrs2,'AlphaMap',amap);
else
  % Refresh display if not using OpenGL transparency
  showsrs2('Refresh_Callback',handles.showsrs2);
end

% --------------------------------------------------------------------
function AllEqualPushButton_Callback(h, eventdata, handles)
% Set all sliders to equal (mean of current values)

% Set all sliders to mean of current slider values
sliders_h=findobj(handles.showsrs2_cfgtransFig,'Tag','transSlider','Style','slider');
values = get(sliders_h,'Value');
set(sliders_h,'Value',mean([values{:}]));

% Update the alphamap for each slider adjusted.
for n=1:length(sliders_h)
  showsrs2_cfgtrans('transSlider_Callback',sliders_h(n),[]);
end

% -------------------showsrs2_cfgtransFig_CloseRequestFcn------------------
function showsrs2_cfgtransFig_CloseRequestFcn(h, eventdata, handles)
% Close Request Function for Configuration GUI
%
% (1) Delete GUI
% (2) Enable transslider in showsrs2_cfg GUI if all transparencies the same
%

try
  % Delete the showsrs2_cfgtrans figure
  delete(handles.showsrs2_cfgtransFig);

  % Check to see a showsrs2_cfg GUI is open for this showsrs2 figure
  showsrs2_cfg_h=local_find_showsrs2_childGUI('showsrs2_cfgFig',handles.showsrs2);

  % Update showsrs2_cfg GUI for new transparency settings.
  % (Do not let it open another showsrs2_cfgtrans GUI automatically.)
  % (Enables transslider and show overlays checkboxes as appropriate).
  if ~isempty(showsrs2_cfg_h),
    showsrs2_cfg('updateTransSettings_Callback',showsrs2_cfg_h,[],1);
  end
catch
  % Something failed.  Just delete the cfg GUI and issue a warning!
  delete(handles.showsrs2_cfgtransFig);
  % If this fails, issue a warning and continue on to close finish close request function
  warning(sprintf('Failure while closing transparency adjustment GUI.\nError was:\n%s',lasterr));      
end

% --------------------------------------------------------------------
function handles = local_initializegui(showsrs2_h)
% Initialize new transslider GUI
%
%   handles == [] if there are no overlays
% 
%   In addition to initializing the GUI, this function sets up a structure
%   of handles to element in the GUI.  The struct is similar to that
%   returned by guihandles() in MATLAB 6 and later except it only includes
%   some of the GUI elements.
%  
%    Additionally, handles includes handles from showsrs2 GUI
%      handles.showsrs2 = handle of the controlled showsrs2 fig
%      handles.showsrs2_UseTransMenu = handle of the "Use OpenGL Transparency"
%        menu in handles.showsrs2
%          'Checked' determines if transparency is being used
%          'UserData' contains the AlphaMap
%        This is stored for fast access (findobj is slow).

% Get names and number of images from showsrs2 figure UserData
fig_ud=get(showsrs2_h,'UserData');
nOverlays = length(fig_ud.image_h)-1;
overlayNames = fig_ud.image_names(2:end);
clear('fig_ud')

% If there are no overlays, return with handles = [];
if nOverlays == 0, handles = []; return, end

% Save some showsrs2 GUI handles
handles.showsrs2 = showsrs2_h;
handles.showsrs2_UseTransMenu = findobj(showsrs2_h,'Tag','UseTransMenu','Type','uimenu');

% Initialize display
figPos = [10 10];
figMargin = [2 1 5 5]; % Top, Bottom, Left, Right
sliderSize = [30 1.2];
sliderCheckboxMargin = 0.3;
checkboxSize = [30 1];
allEqualButtonSize = [20 1.2];
allEqualButtonMargin = 0.8;
blockHeight = sliderSize(2)+sliderCheckboxMargin+checkboxSize(2)+0.5;
figSize = [40 blockHeight*nOverlays+figMargin(1)+figMargin(2)+...
    allEqualButtonSize(2)+allEqualButtonMargin];

% Make figure
handles.showsrs2_cfgtransFig = figure('IntegerHandle','off', ...
  'Resize','off','Units','Characters','Position',[figPos figSize], ...
  'MenuBar','none','Tag','showsrs2_cfgtransFig', ...
  'Color',get(0,'defaultUicontrolBackgroundColor'), ...
  'Name',sprintf('Transparency Figure %d',showsrs2_h), ...
  'NumberTitle','off', ...
  'CloseRequestFcn','showsrs2_cfgtrans(''showsrs2_cfgtransFig_CloseRequestFcn'',gcbo,[])');
% Build GUI from bottom up

% Add buttons
pos = [figMargin(3),figMargin(2),allEqualButtonSize];
handles.AllEqualPushButton = uicontrol('Units','Characters','Tag','AllEqualPushButton', ...
  'Style','pushbutton','Position',pos, ...
  'String','Set all limits equal', ...
  'Callback','showsrs2_cfgtrans(''AllEqualPushButton_Callback'',gcbo,[])');

% Make GUI block for each overlay (slider & checkbox)
startPos=[pos(1),pos(2)+pos(4)+allEqualButtonMargin];
for n=1:nOverlays
  currOverlay = nOverlays-n+1;  % Index to current overlay (work from bottom up)

  % Make checkbox
  % UserData is a structure with the following fields: (set below)
  %   slider_h is the handle of the slider corresponding to this checkbox
  %   storedTransLim is the previous value of the slider before the checkbox
  %     was unchecked (i.e. overlay turned off).  Use 1 as default
  %     storedTransLim so that if transLim started as 0 (off) checking it will
  %     turn it on.
  ud = struct('storedTransLim',1,'slider_h',[]);
  pos = [startPos(1),startPos(2)+blockHeight*(n-1), checkboxSize];
  checkbox_h=uicontrol('Units','Characters','Tag','transCheckbox', ...
    'Style','Checkbox','Position',pos, ...
    'String',overlayNames{currOverlay},'Min',0,'Max',1,...
    'Callback','showsrs2_cfgtrans(''showOverlaysCheckbox_Callback'',gcbo,[])');

  % Make slider 
  % UserData is a structure with the following fields:
  %   overlayNum is the number of the overlay for this slider
  %   checkbox_h is the handle of the checkbox corresponding to this slider
  ud = struct('overlayNum',currOverlay,'checkbox_h',checkbox_h);
  pos = [startPos(1),startPos(2)+blockHeight*(n-1)+sliderCheckboxMargin+checkboxSize(2), sliderSize];
  slider_h=uicontrol('Units','Characters','Tag','transSlider','UserData',ud, ...
    'Style','Slider','Position',pos,'Min',0,'Max',1,'SliderStep',[0.01 0.1],...
    'Callback','showsrs2_cfgtrans(''transSlider_Callback'',gcbo,[])');

  % Store slider_h in corresponding checkbox UserData.
  local_setUserDataField(checkbox_h,'slider_h',slider_h);
  
  % Note: Run updateTransSettings_Callback() to setup the default "Value" field of
  %       the checkbox and slider.
end

% Add slider labels
pos=[pos(1),pos(2)-sliderCheckboxMargin-checkboxSize(2)+blockHeight,12,1];
uicontrol('Units','Characters','Tag','TranslucentString','String','Translucent',...
  'Style','text','Position',pos, ...
  'HorizontalAlignment','left');
pos(1)=pos(1)+sliderSize(1)-12;
uicontrol('Units','Characters','Tag','OpaqueString','String','Opaque',...
  'Style','text','Position',pos, ...
  'HorizontalAlignment','right');

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
% $Log: showsrs2_cfgtrans.m,v $
% Revision 1.8  2005/02/03 16:58:44  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.7  2003/10/22 15:54:39  gadde
% Make some CVS info accessible through variables
%
% Revision 1.6  2003/06/17 14:02:53  michelich
% Instead of disabling transparency without OpenGL, calculate merged image:
% - Don't disable transparency controls when not using OpenGL transparency.
%
% Revision 1.5  2003/06/16 13:56:16  michelich
% showsrs2_cfgtrans changes for MATLAB 5.3 support:
% - Removed all guidata calls (Store handles in figure UserData)
% - Removed all guihandles calls (Generated handles in local_initializegui)
% - Added updateTransSettings_Callback to update GUI for current
%   transparency settings (transLims, UseTransMenu state)
% - Use showsrs2_cfg updateTransSettings_Callback to update showsrs2_cfg
%   GUI for showsrs2_cfgtrans GUI at GUI launch and exit.
% - Automatically add handles to callback arguments.
% - Keep master copy of alphamap in showsrs2_h UseTransMapMenu.
% - Only update figure 'AlphaMap' property when transparency being used.
% - Replaced getappdata/setappdata with storing info in UserData fields and
%   using local_getUserDataField/local_setUserDataField to access them.
% - Use Refresh_Callback instead of Slider_Callback to refresh showsrs2 fig
% Other changes:
% - Removed varargin from callbacks (not used)
% - Only enable/disable showsrs2_cfg if opening a new cfgtrans GUI.
% - Update show overlay checkbox & stored value when slider dragged to off.
% - Set default "stored" value if overlay off on launch.
% - Explicitly delete showsrs2_cfgtransFig handle on closeRequest catch to
%   avoid deleting a file passed to the "h" variable.
%
% Revision 1.4  2003/06/13 17:40:11  michelich
% Refresh display when AlphaMap changes and transparency is not being used.
%
% Revision 1.3  2002/10/09 20:12:30  michelich
% Changed name to showsrs2_cfgtrans.
% Moved check for configuration GUIs into a local function.
% Handle launching with no overlays.
% Removed varargouts from local callback functions.
% Added pushbutton to set all transparency limits equal.
% Add interaction with showsrs2_cfg figure. (at launch and close).
% Updated comments.
%
% Revision 1.2  2002/09/27 20:16:51  michelich
% Added figure title.  Use non-integer handle.  Make figure non resizeable.
%
% Revision 1.1  2002/09/27 15:38:43  michelich
% Initial version.
%
