function [args,workspaceVar]=readmrgui(varargin)
%READMRGUI Determine readmr arguments using a GUI
%
%  Determine READMR arguments using a GUI
%
%   [args,workspaceVar] = readmrgui(options);
%     args - cell array of arguments to readmr
%            empty cell array if the user cancels or a workspace variable.
%            The first element of args is an mrinfo structure.  Make sure
%            that you cleanup any temporary files by calling
%               readmr(args{1},'=>CLEANUP')
%            when you are done with the mrinfo structure.
%     workspaceVar - If user choses a workspace variable instead of a
%            filename, args = {} and workspaceVar is the workspace 
%            variable name.
%     options - initialization options for the GUI (to be defined).
%
% See Also: READMR

% CVSId = '$Id: readmrgui.m,v 1.20 2005/02/22 20:18:25 michelich Exp $';
% CVSRevision = '$Revision: 1.20 $';
% CVSDate = '$Date: 2005/02/22 20:18:25 $';
% CVSRCSFile = '$RCSfile: readmrgui.m,v $';

% Major TODO's remaining:
% TODO: Support adding and removing dimensions.
% TODO: Cleanup behavior of wildcard checkbox.

if nargin == 0 | ~ischar(varargin{1}) | length(varargin{1}) <= 8 ...
    | ~strcmp(varargin{1}(end-8:end),'_Callback'); % LAUNCH GUI
  % Launch GUI is there are no input arguments or if the first input
  % argument is not a string ending in  '_Callback'.
  
  % Initialize GUI (include initial setup from varargin).
  gui_h = local_initgui(varargin{:});
  
  % Generate and store a structure of the handles in the GUI.
  handles = guihandles(gui_h);
  guidata(gui_h,handles);
  
  % Arrange GUI elements and make it visible
  local_resizegui(handles);
  set(gui_h,'Visible','On');
  
  % For fully specified formats, keep a copy of the mrinfo structure so
  % that we don't need to read the header mulitple times.
  setappdata(handles.readmrgui,'currMRinfo',''); % Initialize
  
  % Wait for callbacks to complete 
  %  Changing gui_h UserData or deleting gui_h will unblock function.
  %
  %  Delete gui_h to issue error (store error message in lasterr)
  %  Change gui_h UserData
  %    if 'args' appdata is empty, User Cancelled.
  %    otherwise 'args' appdata is used to read the data
  waitfor(gui_h,'UserData');
  
  % Delete gui_h to issue error (store error message in lasterr) 
  if ~ishandle(gui_h)
    emsg = lasterr; % Check for error messages in lasterr
    if isempty(emsg), emsg = 'An unidentified error occurred!'; end
    error(emsg);
  end
  
  % Get reading arguments from GUI
  args = getappdata(gui_h,'args');
  workspaceVar = getappdata(gui_h,'workspaceVar');
  
  % Delete GUI (NOT close since this would call CloseRequestFcn recursively)
  delete(gui_h);
  
else % INVOKE NAMED SUBFUNCTION OR CALLBACK
  % Check input arguments.
  if nargin < 4, 
    error('Incorrect number of inputs for readmrgui callback!');
  end
  if ~ischar(varargin{1})
    error('First input argument for GUI callbacks must be a string!');
  end
  if ~ishandle(varargin{2})
    error('Second input argument for GUI callbacks is not a valid handle!');
  end
  if ~isempty(varargin{3})
    error('Third input argument for GUI callbacks must be a empty!');
  end
  if ~isstruct(varargin{4})
    error('Fourth input argument for GUI callbacks must be a strucure!');
  end
  
  % Get the gui_h from the handles structure (confirming that this handles
  % structure is for a readmrgui GUI).
  if ~isfield(varargin{4},'readmrgui'), 
    error('Fourth input argument for GUI callbacks must be a strucure of handles for a readmrgui GUI!');
  else
    gui_h = varargin{4}.readmrgui;
  end  
  
  % TODO: Catch error before determining gui_h ???
  
  % Use a try-catch to handle errors, now that we have a handle for a
  % readmrgui GUI.
  try
    if (nargout)
      [varargout{1:nargout}] = feval(varargin{:}); % FEVAL switchyard
    else
      feval(varargin{:}); % FEVAL switchyard
    end
  catch
    % Update error messages and unblock waitfor(gui_h,'UserData')
    % The code after the unblock will issue an error if the GUI is missing.
    
    % GUI is still open, unblock.
    if ishandle(gui_h), delete(gui_h); end
  end
end

% --------------------------------------------------------------------
% -----------------------Callback Functions---------------------------
% --------------------------------------------------------------------
%| ABOUT CALLBACKS:
%| CALLBACK are each implemented as local functions and are called 
%| through the FEVAL switchyard above. This comment describes that 
%| mechanism.
%|
%| Each callback subfunction declaration has the following form:
%| <SUBFUNCTION_NAME>(hObject, eventdata, handles, ...)
%|
%| hObject is the callback object's handle (obtained using GCBO).
%|
%| eventdata is empty, but reserved for future use.
%|
%| handles is a structure containing handles of components in GUI using
%| tags as fieldnames, e.g. handles.figure1, handles.slider2. This
%| structure is created at GUI startup using GUIHANDLES and stored in
%| the figure's application data using GUIDATA. A copy of the structure
%| is passed to each callback.
%|
%| ... contains any extra arguments you have passed to the
%| callback. Specify the extra arguments by editing the callback.
%|
%| VARARGIN contains any extra arguments you have passed to the
%| callback. Specify the extra arguments by editing the callback
%| property in the inspector. By default, GUIDE sets the property to:
%| 
%| Add any extra arguments after the last argument, before the final
%| closing parenthesis.
%|
%| Specify the callback in the CALLBACK tag of objects using the following
%| readmrgui('<SUBFUNCTION_NAME>', gcbo, [], guidata(gcbo))
%|
%| Add any extra arguments after the last argument, before the final
%| closing parenthesis.
%|

% --------------------------------------------------------------------
function ChooseFileButton_Callback(hObject, eventdata, handles)
% Allow user to choose file to open

% Determine directory of current file
currDir = fileparts(get(handles.FileEdit,'String'));

filterSpec = { ...
    '*.bxh','BIAC XML Header (*.bxh)'; ...
    '*.dcm','DICOM Images (*.dcm)'; ...
    '*.hdr','Analyze7.5_SPM (*.hdr)'; ...
    '*.img','Raw, Volume, Float Images (*.img)'; ...
    '*','All Files (*)'};
uigetfileTitle = 'Choose an image or header file';

if isempty(currDir)
  % No starting directory. Use current directory
  [filename, pathname] = uigetfile(filterSpec,uigetfileTitle);
else
  % There is a starting directory.  Handle for different MATLAB versions.
  [majorVer, minorVer] = strtok(strtok(version),'.');
  majorVer = str2double(majorVer);
  minorVer = str2double(strtok(minorVer,'.'));
  if majorVer < 6 | (majorVer == 6 & minorVer < 5)
    % MATLAB 6.1 and earlier
    oldpwd=pwd; cd(currDir);
    [filename, pathname] = uigetfile(filterSpec,uigetfileTitle);
    cd(oldpwd);
  else
    % MATLAB 6.5 and later
    [filename, pathname] = uigetfile(filterSpec,uigetfileTitle,[currDir,filesep]);
  end
  clear majorVer minorVer
end

% Return without changing current file if user does not pick a file
if isequal(filename,0)|isequal(pathname,0), return; end

% Uncheck the checkbox and clear the past data
% Is this behavoir appropriate?  Perhaps this should be a button instead?
set(handles.WildcardCheckbox,'Value',0,'UserData','');

% Add the path to the filename
filename = fullfile(pathname,filename);

% Update the current filename in the File Edit box
set(handles.FileEdit,'String',filename);

% Call FileEdit_Callback to do any updates necessary
FileEdit_Callback(handles.readmrgui,[],handles);

% --------------------------------------------------------------------
function OkayButton_Callback(hObject, eventdata, handles)
% User pushed okay, check current arguments and tell user problems or
% read the data.

% Get input locations (filenames)
inputloc = get(handles.FileEdit,'String'); % Single file (possibly with wildcard)
inputlocs = get(handles.FileEdit,'UserData'); % Cell array of files (wildcard expanded)

if isempty(inputloc)  % No filenames specifed
  errorbox('No input files specified','No input files specified');
  return;
end

if isempty(inputlocs)  % No filenames successfully expanded into wildcard
  errorbox(sprintf('File or variable does not exist'),'No inputs specified');
  return;
end

% Determine number of active dimensions based on how many size boxes are
% visible.
activeDims = strcmp(get(get(handles.SizeEditBox,'UserData'),'Visible'),'on');
% Make sure that active dimensions are first in the list of handles.
nDims = length(find(activeDims));
if ~all(activeDims(1:nDims))
  error(['Error in READMRGUI code.  Active dimensions must be ', ...
      'contiguous and begin with dimension 1.']);
end
clear activeDims.

% Construct selector
selector_h = get(handles.SelectorEditBox,'UserData');
selector = repmat({''},[1,nDims]); % Default to everything.
for n = 1:nDims
  currSelectorString = get(selector_h(n),'String');
  if ~isempty(currSelectorString)
    % Try to use what the user selected
    try
      selector{n}=eval(currSelectorString);
    catch
      errorbox(sprintf('Invalid Selector in dimension %d',n),'Invalid Selector');
      return;
    end
    % TODO: Check that selector does not exceed size
    if any(~isint(selector{n})) | any(selector{n} < 1)
      errorbox(sprintf('Invalid Selector in dimension %d',n), ...
        'Selector must be valid indexes');
      return;
    end
  end
end

% Handle each different format.
fileFormat = local_getFormats(get(handles.FormatListPopupMenu,'Value'));

if strcmp(fileFormat.name,'WorkspaceVar')
  % Handle workspace variables
  if( length(inputlocs) > 1  | inputlocs{1}(1) ~= '=')
    errorbox('Workspace variables must begin with =','Not a Workspace Variable');
    return
  end
  workspaceVar=inputlocs{1}(2:end);
  % Check that variable exists.
  % TODO: Do we need to do this since FileEdit_Callback already does this?
  %   if ~ismember(workspaceVar,evalin('base','who'))
  %     errorbox(sprintf('The variable "%s" does not exist!',workspaceVar),'Not a Workspace Variable');
  %     return
  %   end
  % --- Everything is okay! add to recent files and store reading args ---
  local_manageRecentFiles('AddFileOnly',inputloc); % Add current file to recent files list.
  setappdata(handles.readmrgui,'args',{});
  setappdata(handles.readmrgui,'workspaceVar',workspaceVar);
else
  % Handle non-workspace formats
  
  % Check that files exist.
  % TODO: Do we need to check every file (or check at all?)
  % since FileEdit_Callback already does this?
  %   for n=1:length(inputlocs)
  %     if ~exist(inputlocs{n},'file')
  %       errorbox(sprintf('File %s does not exist',inputlocs{n}), ...
  %         'File does not exist');
  %       return;
  %     end
  %   end
  
  % If header did not have voxel size or orientation and user specified any
  % of them, use a modifed info struct to pass the data back.
  readInfoStruct = 0;
  voxelSize_h = get(handles.VoxelSizeEditBox,'UserData');
  for n = 1:nDims
    if (strcmp(get(voxelSize_h(n),'Enable'),'on') & ...
        ~isempty(get(voxelSize_h(n), 'String')))
      % If enabled and not empty, user specified a voxelSize.
      readInfoStruct = 1;
      break;
    end
  end
  if (~readInfoStruct & strcmp(get(handles.OrientationPopupMenu,'Enable'),'on') ...
      & get(handles.OrientationPopupMenu,'Value') ~= 1)
    % Orientation popup menu is enabled and not unspecifed.
    readInfoStruct = 1;
  end
  % If there is a cached info struct, use it.
  if ~isempty(getappdata(handles.readmrgui,'currMRinfo'))
    readInfoStruct = 1;
  end
  
  % For each format, check inputs and then create an mrstruct if there are
  % no problems.
  if any(strcmp(fileFormat.name,{'Raw','Volume','Float'}))
    % Handle Raw formats.
    
    % Read sizes
    size_h=get(handles.SizeEditBox,'UserData');
    dims = zeros(1,nDims);
    for n = 1:nDims
      currSizeString = get(size_h(n),'String');
      if isempty(currSizeString) 
        errorbox('Must specify size!',sprintf('Invalid Size (dimension %d)',n));
        return
      end
      dims(n) = str2double(currSizeString);
      if isnan(dims(n)) | dims(n) < 1 | ~isint(dims(n))
        errorbox('Size must be an integer greater than zero!', ...
          sprintf('Invalid Size (dimension %d)',n));
        return
      end
    end
    
    % Read header size
    hdrSzString = get(handles.HdrSize,'String');
    if isempty(hdrSzString)
      errorbox('Must specify header size!','Invalid Header Size');
      return
    end
    hdrSz = str2double(hdrSzString);
    if isnan(hdrSz) | hdrSz < 0 | ~isint(hdrSz)
      errorbox('Header size must be a positive integer!','Invalid Header Size');
      return
    end
    
    % Read pixel type and byte order
    datatypes = local_getDatatypes([]);
    pixelType = datatypes.type{get(handles.PixelTypePopup,'Value')};
    byteorders = local_getByteorders([]);
    byteOrder = byteorders.codes{get(handles.ByteOrderPopup,'Value')};
    
    % --- Everything is okay! Setup args array and read mrinfo ---
    if strcmp('Raw',fileFormat.name)
      args = {inputlocs,{'Raw',dims,pixelType,byteOrder,hdrSz}};
    else % Volume and Float
      args = {inputlocs,{fileFormat.name,dims}};
    end
    
    % Create an mrinfo structure
    try
      set(handles.statusText,'String','Reading image information ...'); drawnow;
      mrinfo = readmr(args{:},'=>INFOONLY');
      set(handles.statusText,'String','');
    catch
      set(handles.statusText,'String','');
      emsg = lasterr;
      if isempty(emsg)
        emsg = 'Unknown error occured attempting to read information for files';
      end
      errorbox(emsg,'Error attempting to read information for file');
      return
    end
    clear args 
  else
    % Handle the fully specified formats
    % TODO: Should we include any format error checking here???
    % --- Everything is okay! Setup args array ---      
    % Just grab the cached mrinfo.
    mrinfo = getappdata(handles.readmrgui,'currMRinfo');
    if isempty(mrinfo) % This should never happen
      error(['There is not a valid mrinfo structure for format %s! '...
          'Why wasn''t it created! Look at FormatListPopupMenu_Callback']);
    end
  end % End if fileFormat.name
  
  % Fill is any information the user specifed that was not in the header (mrinfo)
  % (e.g. The voxel size and/or orientation)
        
  % Add any specified voxel sizes to info struct
  units = {'mm','mm','mm','ms'}; % TODO: Tell users about these in GUI.
  voxelSize_h = get(handles.VoxelSizeEditBox,'UserData');
  for n = 1:nDims
    if strcmp(get(voxelSize_h(n),'Enable'),'on')
      % Enabled (i.e. not specifed in header already)
      voxelSizeString = get(voxelSize_h(n), 'String');
      if ~isempty(voxelSizeString)
        % User specified something, try to convert it 
        % (use str2num to allow uesr to divide in field).
        voxelSize = str2num(voxelSizeString);
        if isempty(voxelSize) | voxelSize <= 0
          errorbox('Voxel size must be a number greater than zero!', ...
            sprintf('Invalid Voxel Size (dimension %d)',n));
          readmr(mrinfo,'=>CLEANUP');
          return
        end
        mrinfo.info.rawdimensions(n).spacing = voxelSize;
        if n < length(units)
          % TODO: Do I want to override the values in the mrinfo???
          mrinfo.info.rawdimensions(n).units = units{n};
        end
      end
    end
  end
    
  % Add orientation to info struct if specified
  if strcmp(get(handles.OrientationPopupMenu,'Enable'),'on')
    % Enabled (i.e. not specifed in header already)
    if (get(handles.OrientationPopupMenu,'Value') ~= 1)
      % User specified an orientation
      try
        directions = ras2direction(get(handles.RASFlagEditBox, 'String'));
      catch
        emsg = lasterr;
        if isempty(emsg)
          emsg = 'Unknown error occured determining orientation';
        end
        errorbox('Error determining orientation',emsg);
        readmr(mrinfo,'=>CLEANUP');
        return
      end
      % Copy direction vectors to info struct.
      [mrinfo.info.rawdimensions(1:3).direction] = deal(directions{:});
      
      % Check to see if the oblique box is checked for a "fuzzy direction"
      if(get(handles.ObliqueCheckbox,'Value') == 1)
        [mrinfo.info.rawdimensions(1:3).directionprecision]=deal(0,0,0);
      end
    end
  end
  
  % --- Everything is okay! add to recent files and store reading args ---
  local_manageRecentFiles('Add',inputloc); % Add current file to recent files list.
  setappdata(handles.readmrgui,'args',{mrinfo,selector});
  setappdata(handles.readmrgui,'workspaceVar','');
end % End ~workspaceVar

% Unblock function execution. 
set(handles.readmrgui,'UserData','Done');

% --------------------------------------------------------------------
function CancelButton_Callback(hObject, eventdata, handles)
% User pushed cancel. 

% Cleanup any cached mrinfo
currMRinfo = getappdata(handles.readmrgui,'currMRinfo');
if ~isempty(currMRinfo)
  readmr(currMRinfo,'=>CLEANUP');
end

% Set 'args' & 'workspaceVar' appdata to empty to indictate user cancel.
setappdata(handles.readmrgui,'args',{});
setappdata(handles.readmrgui,'workspaceVar','');

% Unblock function execution.
set(handles.readmrgui,'UserData','Cancel');

% --------------------------------------------------------------------
function FileListPopupMenu_Callback(hObject, eventdata, handles)
% User chose item from popupmenu.  Make it the current file.
%

% Update the current filename in the File Edit box
fileList=get(handles.FileListPopupMenu,'String');
set(handles.FileEdit,'String',fileList{get(handles.FileListPopupMenu,'Value')});

% Call FileEdit_Callback to do any updates necessary
FileEdit_Callback(handles.readmrgui,[],handles);

% --------------------------------------------------------------------
function FileEdit_Callback(hObject, eventdata, handles)
% User typed something into the File edit field.
%
% NOTE: Do not use hObject so that this function can be called directly in
% addition to being called as a callback.

% Copy the filename to the Tooltip string
filename = get(handles.FileEdit,'String');
set(handles.FileEdit,'TooltipString',filename);

% FileEdit UserData will contain a list of all filenames/variable matching
% current name in FileEdit string.  Set to {} until we verify that this
% filename/variable is valid.
set(handles.FileEdit,'UserData',{});

% If user didn't type anything just return
% TODO: Is this behavior okay?
if isempty(filename), return; end

% This is a new filename, change default "Last successful format" to Raw
set(handles.FormatListPopupMenu,'UserData',local_getFormats('Raw'));

% --- Attempt to detect file format ----
if(filename(1) == '=')
  % Workspace variable
  
  % If it is not a valid workspace variable, tell user and return
  if length(filename) < 2
    errorbox('Must specify variable name after =','Invalid Workspace Variable');
    return;
  end
  if ~ismember(filename(2:end),evalin('base','who'))
    errorbox(sprintf('The variable "%s" does not exist!',filename(2:end)),'Not a Workspace Variable');
    return
  end
  formatIndex = local_getFormats('WorkspaceVar');
  % Store full list of filenames in FileEdit UserData
  set(handles.FileEdit,'UserData',{filename});
else
  % Filename
  
  % Don't do anything if this is just a directory.
  % TODO: Perhaps switch to Raw???
  [filepath,name] = fileparts(filename);
  if isempty(name), return; end

  % If the the filename is a wildcard, expand wildcard
  if any(filename == '*')
    set(handles.statusText,'String','Looking for matching files ...'); drawnow;
    d = dir(filename);
    set(handles.statusText,'String','');
    % If nothing matches, tell user and return
    % TODO: Handle this better.
    if isempty(d)
      errorbox(sprintf('No files found matching %s',filename),'No files found!');
      return;
    end
    fNames = sort({d.name}');
    filepath = fileparts(filename);
    if ~isempty(filepath)
      filename = strcat([filepath,filesep],fNames);
    else % User typed a relative path
      filename = fNames;
    end
  else
    % Handle a single file
    
    % If file does not exist, tell user and return
    % TODO: Handle this better
    if ~exist(filename,'file')
      errorbox(sprintf('File %s does not exist',filename), ...
        'File does not exist');
      return;
    end
    
    % Put in a cell array for uniform handling.
    filename = {filename};
  end
  % Store full list of filenames in FileEdit UserData
  set(handles.FileEdit,'UserData',filename);
    
  % Detect format.  (Only check first file ... )
  % TODO: Check all files (EXIST check in autodetectmr is slow) 
  format = autodetectmr(filename{1});
  
  % If format cannot be detected, default to Float.
  if isempty(format), format = 'Float'; end
  
  % Use DICOM_Volume for single slices by default.
  if strcmp(format,'DICOM_Slice'), format = 'DICOM_Volume'; end

  % Find index for current format.
  formatIndex = local_getFormats(format);
  
  % Is we don't recognize the format returned by the autodetect,
  % default to Float.
  if isempty(formatIndex)
    formatIndex = local_getFormats('Float');
  end
end

% Update the GUI
set(handles.FormatListPopupMenu, 'Value', formatIndex);
FormatListPopupMenu_Callback([],eventdata,handles);

% --------------------------------------------------------------------
function WildcardCheckbox_Callback(hObject, eventdata, handles)
% User toggled the "Read Timeseries" box

if get(handles.WildcardCheckbox,'Value')
  % User checked the "Read Timeseries" box
  filename = get(handles.FileEdit,'String');
  if ~isempty(filename)
    set(handles.WildcardCheckbox, 'UserData', filename);
    filename = name2spec(filename);
    set(handles.FileEdit,'String',filename);
  else
    % Don't allow user to check this until they have chosen a file.
    set(handles.WildcardCheckbox,'Value',0);
  end
else
  % User unchecked the "Read Timeseries box
  % TODO: What if it is empty.  What if you switch to a different item.
  set(handles.FileEdit,'String',get(handles.WildcardCheckbox, 'UserData'));
end

% notify that something was typed in the FileEdit field
FileEdit_Callback([],eventdata,handles);

% --------------------------------------------------------------------
function FormatListPopupMenu_Callback(hObject, eventdata, handles)
% User chose a file format from the format list

% TODO: Handle updating GUI when user changes format when filename is
% empty.  Is is particularly important if user clears filename after
% selecting a file successfully.
if(~isempty(get(handles.FileEdit,'UserData')))
  fileFormat = local_getFormats(get(handles.FormatListPopupMenu,'Value'));
  
  % Cleanup and clear cached mrinfo
  % TODO: Handle user selecting the same format twice without rereading info.
  currMRinfo = getappdata(handles.readmrgui,'currMRinfo');
  if ~isempty(currMRinfo)
    readmr(currMRinfo,'=>CLEANUP');
    setappdata(handles.readmrgui,'currMRinfo','');
  end
  
  switch fileFormat.name
    case {'BXH','DICOM','DICOM_Search','DICOM_Volume','DICOM_Slice','Signa5','Signa4','SignaXIMG',...
          'ScreenSave','ANMR','EP','CORITechs','Analyze7.5_SPM'}
      % Completely specified data formats.
      % Try to get header info using readmr, otherwise revert to last sucessful format.
      mrinfo = [];
      try
        set(handles.statusText,'String','Reading image information ...'); drawnow;
        mrinfo = readmr(get(handles.FileEdit,'UserData'),fileFormat.name,'=>INFOONLY');
        set(handles.statusText,'String','');
        local_setDefinedFormat(mrinfo,handles);
      catch
        set(handles.statusText,'String','');
        if strcmp(fileFormat.name, 'BXH')
          errorbox(sprintf('Error reading BXH format file!\n(do you have the XML libraries installed?)\n%s', lasterr),'Error reading file');
        else
          errorbox(sprintf('Error reading %s format file:\n%s',fileFormat.name,lasterr),'Error reading file');
        end
        if ~isempty(mrinfo), readmr(mrinfo,'=>CLEANUP'); end
        set(handles.FormatListPopupMenu,'Value',get(handles.FormatListPopupMenu,'UserData'));
        FormatListPopupMenu_Callback(hObject, eventdata, handles);
      end;
      % Store the mrinfo structure.
      setappdata(handles.readmrgui,'currMRinfo',mrinfo);
      
    case 'Raw'
      % Enable the pixelType, byteOrder, and header size.
      set(handles.PixelTypePopup,'Enable','on');
      set(handles.ByteOrderPopup,'Enable','on');
      set(handles.HdrSize,'Enable','on');
      
      % Set the dimensions
      size_h = get(handles.SizeEditBox,'UserData');
      selector_h = get(handles.SelectorEditBox,'UserData');
      voxSize_h = get(handles.VoxelSizeEditBox,'UserData');
      label_h = get(handles.DimensionLabel,'UserData');
      labels = {'x','y','z','t'};
      set(size_h(1:4),'Enable','on','Visible','on');
      defSizes = [64 64 1 1];
      for n=1:4
        % Only use the default value if there is nothing there yet
        if isempty(get(size_h(n),'String'))
          set(size_h(n),'String',num2str(defSizes(n)));
        end
        % Set labels to standad order (see readmr)
        set(label_h(n),'String',labels{n},'Visible','on');
      end
      set(selector_h(1:4),'Enable','on','Visible','on');    
      set(voxSize_h(1:4),'Enable','on','Visible','on');    
      
      % Enable orientation stuff
      set(handles.OrientationPopupMenu,'Enable','On');
      set(handles.RASFlagEditBox,'Enable','On');
      set(handles.ObliqueCheckbox,'Enable','On');

      % TODO: Disable/Hide additional dimensions
      local_calcNumSlices(handles)
      local_calcNumTimePts(handles)
      
    case {'Float','Volume'}
      % Get defaults\parameters for each
      if strcmp(fileFormat.name,'Float')
        pixelType = 'float32';
        defSizes = [64 64 1 1];
      else % Volume
        pixelType = 'int16';
        defSizes = [64 64 1 1];
      end
      
      % Set the data type
      datatypes = local_getDatatypes([]);
      datatypeIndex = find(strcmp(pixelType,datatypes.type));
      set(handles.PixelTypePopup,'Value',datatypeIndex,'Enable','off');
      
      % Set the byte order
      byteOrders = local_getByteorders([]);
      byteOrderIndex = find(strcmp('l', byteOrders.codes));
      set(handles.ByteOrderPopup,'Value',byteOrderIndex,'Enable','off');
      
      % Set the header size
      set(handles.HdrSize,'String','0','Enable','off');

      % Set the dimensions
      size_h = get(handles.SizeEditBox,'UserData');
      selector_h = get(handles.SelectorEditBox,'UserData');
      voxSize_h = get(handles.VoxelSizeEditBox,'UserData');
      label_h = get(handles.DimensionLabel,'UserData');
      labels = {'x','y','z','t'};
      set(size_h(1:2),'Enable','on','Visible','on');
      for n = 1:2
        % Only use the default value if there is nothing there yet
        if isempty(get(size_h(n),'String'))
          set(size_h(n),'String',num2str(defSizes(n)));
        end
        % Set labels to standad order (see readmr)
        set(label_h(n),'String',labels{n},'Visible','on');
      end
      for n = 3:4
        % Disable z & t since they will be automatically calculated.
        set(size_h(n),'String','','Enable','off','Visible','on');
        % Set labels to standad order (see readmr)
        set(label_h(n),'String',labels{n},'Visible','on');
      end
        
      set(selector_h(1:4),'Enable','on','Visible','on');    
      set(voxSize_h(1:4),'Enable','on','Visible','on');    

      % Enable orientation stuff
      set(handles.OrientationPopupMenu,'Enable','On');
      set(handles.RASFlagEditBox,'Enable','On');
      set(handles.ObliqueCheckbox,'Enable','On');
      
      % TODO: Disable/Hide additional dimensions
      local_calcNumSlices(handles)
      local_calcNumTimePts(handles)

    case 'WorkspaceVar'
      % Clear and disable everything
      % TODO: Fill stuff out more intelligently based on variable
      set(handles.PixelTypePopup,'Enable','off','Value',1);
      set(handles.ByteOrderPopup,'Enable','off','Value',1);
      set(handles.HdrSize,'Enable','off','String','N/A');
      set(handles.WildcardCheckbox,'Value',0,'UserData','');
      size_h = get(handles.SizeEditBox,'UserData');
      selector_h = get(handles.SelectorEditBox,'UserData');
      voxSize_h = get(handles.VoxelSizeEditBox,'UserData');
      set(size_h,'Enable','off','Visible','on','String','');
      set(selector_h,'Enable','off','Visible','on','String','');
      set(voxSize_h,'Enable','off','Visible','on','String','');
      set(handles.OrientationPopupMenu,'Enable','Off','Value',1);
      set(handles.RASFlagEditBox,'Enable','Off','String','');
      set(handles.ObliqueCheckbox,'Enable','Off','Value',0);
    otherwise
      emsg = sprintf('FormatListPopupMenu_Callback does not handle format %s', ...
        fileFormat.name);
      error(emsg);
  end
  % Determine if wildcard checkbox is appropriate for this format
  if fileFormat.allowMultipleFiles
    set(handles.WildcardCheckbox, 'Enable', 'on');
  else
    %TODO: Should we uncheck the checkbox here?
    set(handles.WildcardCheckbox,'Enable','off');
  end
  
  % Format change was successful, set "Last successful format" to current format
  set(handles.FormatListPopupMenu,'UserData',get(handles.FormatListPopupMenu,'Value'));
end

% --------------------------------------------------------------------
function PixelTypePopup_Callback(hObject, eventdata, handles)
% User chose a pixel type from the popup menu

% Auto calculate the number of slices (if appropriate for current format)
local_calcNumSlices(handles);

% --------------------------------------------------------------------
function ByteOrderPopup_Callback(hObject, eventdata, handles)
% User chose a byte order format from the popup menu

% --------------------------------------------------------------------
function HdrSize_Callback(hObject, eventdata, handles)
% User entered a header size

% Auto calculate the number of slices (if appropriate for current format)
local_calcNumSlices(handles);

% --------------------------------------------------------------------
function SizeEditBox_Callback(hObject, eventdata, handles)
% User entered a matrix size

% Figure out which dimension this is
dim = find(get(handles.SizeEditBox,'UserData') == hObject);

% Auto calculate the number of slices (if appropriate for current format
% and user changed the X or Y dimensions).
if any(dim == [1 2])
  local_calcNumSlices(handles);
end

% --------------------------------------------------------------------
function SelectorEditBox_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function OrientationPopupMenu_Callback(hObject, eventdata, handles)
% Update RAS flag for item chosen from list.

orientations = local_getOrientations;
set(handles.RASFlagEditBox,'String',orientations.rasFlags{get(hObject,'Value')});

% --------------------------------------------------------------------
function RASFlagEditBox_Callback(hObject, eventdata, handles)
% Select correct item from list if user types an RAS flag.

% Get current rasFlag
rasFlag = get(handles.RASFlagEditBox,'String');

% Determine which pull down item to specify
if isempty(rasFlag)
  % User cleared select, set back to not specifed
  ii = 1;
else
  % User entered a RAS flag
  orientations = local_getOrientations;
  ii = find(strcmp(rasFlag,orientations.rasFlags));
  % Use custom RAS flag if not in list.
  if isempty(ii), ii = length(orientations.rasFlags); end
end

% Update GUI
set(handles.OrientationPopupMenu,'Value',ii);

% --------------------------------------------------------------------
function ResizeFcn_Callback(hObject, eventdata, handles)
% Execute local resize function for GUI 
%
local_resizegui(handles);

% --------------------------------------------------------------------
% --------------------------Local Functions---------------------------
% --------------------------------------------------------------------

% --------------------------------------------------------------------
function gui_h=local_initgui(varargin)
% LOCAL_INITGUI - Initialize GUI
%
% gui_h=local_initgui(...)
%
%   No input arguments are specified yet, but the intention here is to 
%   provide a mechanism to specify GUI defaults when launching the GUI
%   (e.g. default to a 3D image, default directory, etc...)
%
% gui_h - handle of GUI created.
%
% NOTE: Do NOT position GUI items in this function.  Do positioning in
%       local_resizegui so that resize function works properly!
%
% NOTE: Items in GUI are not arranged and GUI is not visible initially.
%   Do the following:
%     handles = guihandles(gui_h);
%     guidata(gui_h,handles);
%     local_resizegui(handles);
%     set(gui_h,'Visible','On');

% Get size of screen in Character Units
oldRootUnits=get(0,'Units');
set(0,'Units','Characters');
scrChars=get(0,'ScreenSize');
set(0,'Units',oldRootUnits);

% Initial figure size and position
figureWidth=70;
figureHeight=28.5;

% Initialize figure
pos=[0,0,figureWidth,figureHeight];
pos(1:2)=[(scrChars(3)-pos(3))/2 (scrChars(4)-pos(4))/2];
gui_h=figure('Visible','Off','Units','Characters','MenuBar','None','Position',pos, ...
  'NumberTitle','Off', ...%'IntegerHandle','Off', ... % Uncomment this on after finished debugging
  'Name','Open MR Data File', 'Resize','on', ...
  'Tag','readmrgui', ... % For identifying the GUI
  'CloseRequestFcn','readmrgui(''CancelButton_Callback'',gcbo,[],guidata(gcbo))', ... 
  ... % Closing the window is like clicking 'Cancel'
  'ResizeFcn','readmrgui(''ResizeFcn_Callback'',gcbo,[],guidata(gcbo))', ...
  'UserData','', ... % UserData used to block function until done with GUI
  'Color', get(0,'defaultUicontrolBackgroundColor') ...
  );

% Generate buttons
uicontrol('Units','Characters','Style','PushButton','String','Browse', ...
  'Tag','ChooseFileButton', ...
  'CallBack','readmrgui(''ChooseFileButton_Callback'',gcbo,[],guidata(gcbo));');
uicontrol('Units','Characters','Style','PushButton','String','Okay',...
  'Tag','OkayButton', ...
  'CallBack','readmrgui(''OkayButton_Callback'',gcbo,[],guidata(gcbo));');
uicontrol('Units','Characters','Style','PushButton','String','Cancel',...
  'Tag','CancelButton', ...
  'CallBack','readmrgui(''CancelButton_Callback'',gcbo,[],guidata(gcbo));');

% Generate Recent File list
recentStruct=local_manageRecentFiles('Get');
uicontrol('Units','Characters','Style','PopupMenu','String',recentStruct.RecentCombined, ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','FileListPopupMenu',...
  'Callback','readmrgui(''FileListPopupMenu_Callback'',gcbo,[],guidata(gcbo));');

% Generate Edit field to enter filename in
%   Store a cell array the wildcard expanded and exist checked filenames
%   and variables in the UserData so that we don't have to do multiple
%   directory listings or exist checks.
uicontrol('Units','Characters','Style','Edit','String','', ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','FileEdit','UserData',{}, ...
  'Callback','readmrgui(''FileEdit_Callback'',gcbo,[],guidata(gcbo));');

% Generate File Format list
% UserData contains the index of the last formats to successfully load for
% the current file.  Default to Raw.
formats = local_getFormats(-1);
defFormatIndex = local_getFormats('Raw');
uicontrol('Units','Characters','Style','PopupMenu','String',{formats.displayName}, ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','FormatListPopupMenu','UserData',defFormatIndex, ...
  'Callback','readmrgui(''FormatListPopupMenu_Callback'',gcbo,[],guidata(gcbo));');

% Generate Wildcard Checkbox
uicontrol('Units','Characters','Style','Checkbox','String','Use Wildcard Read', ...
  'Value',0,'HorizontalAlignment','Left', ...
  'Tag','WildcardCheckbox','UserData','', ...
  'Callback','readmrgui(''WildcardCheckbox_Callback'',gcbo,[],guidata(gcbo));');

% Generate the FILE FORMAT FRAME
uicontrol('Units','Characters','Style','Frame','Tag','FileFormatFrame');

% Generate File Format boxes
uicontrol('Units','Characters','Style','PopupMenu','String',{'uchar', 'schar','int8', 'int16', 'int32', 'int64','uint8', 'uint16', 'uint32', 'uint64','single', 'float32', 'double', 'float64'}, ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','PixelTypePopup',...
  'Callback','readmrgui(''PixelTypePopup_Callback'',gcbo,[],guidata(gcbo));');
uicontrol('Units','Characters','Style','text','String','Pixel Type:',...
  'Tag','PixelTypePopupLabel', ...
  'CallBack','readmrgui(''PixelTypeLabel_Callback'',gcbo,[],guidata(gcbo));');

uicontrol('Units','Characters','Style','PopupMenu','String',{'Little-endian', 'Big-endian'}, ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','ByteOrderPopup',...
  'Callback','readmrgui(''ByteOrderPopup_Callback'',gcbo,[],guidata(gcbo));');
uicontrol('Units','Characters','Style','text','String','Byte Order:',...
  'Tag','ByteOrderPopupLabel', ...
  'CallBack','readmrgui(''ByteOrderPopupLabel_Callback'',gcbo,[],guidata(gcbo));');

uicontrol('Units','Characters','Style','Edit','String','0', ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','HdrSize',...
  'Callback','readmrgui(''HdrSize_Callback'',gcbo,[],guidata(gcbo));');
uicontrol('Units','Characters','Style','text','String','Hdr Size:',...
  'Tag','HdrSizeLabel', ...
  'CallBack','readmrgui(''HdrSizeLabel_Callback'',gcbo,[],guidata(gcbo));');

% Generate dimension Labels
dimNames = local_getDimensionNames;
for n=1:length(dimNames)
  h(n)=uicontrol('Units','Characters','Style','Text','String',dimNames{n}, ...
    'HorizontalAlignment','Center', ...
    'Tag','DimensionLabelExtra');
end
set(h(1),'Tag','DimensionLabel','UserData',h);

% Generate size boxes
uicontrol('Units','Characters','Style','text','String','Matrix Size:',...
  'Tag','DimensionsLabel','HorizontalAlignment','Right', ...
  'CallBack','readmrgui(''DimensionsLabel'',gcbo,[],guidata(gcbo));', ...
  'Tooltip','Specify the size of each dimension of the image matrix.');

% Create size boxes
nDims = 4;
for n=1:nDims
  h(n)=uicontrol('Units','Characters','Style','Edit','String','', ...
    'BackgroundColor',[1 1 1],'HorizontalAlignment','Left', ...
    'Tag','SizeEditBoxExtra',...
    'Callback','readmrgui(''SizeEditBox_Callback'',gcbo,[],guidata(gcbo));');
end
% Store the handles for all the size boxes in the UserData of the 1st dimension.
set(h(1),'Tag','SizeEditBox','UserData',h);

% Generate voxel size boxes
uicontrol('Units','Characters','Style','text','String','Voxel Size:',...
  'Tag','VoxelSizeLabel', 'FontAngle', 'Italic','HorizontalAlignment','Right', ...
  'CallBack','readmrgui(''SelectorLabel'',gcbo,[],guidata(gcbo));', ...
  'Tooltip',['Specify the spacing between the centers of each element in each dimension.  ', ...
      'This value includes the gap between slices such that 5 skip 3 will give a spacing of 8.']);
for n=1:nDims
  h(n)=uicontrol('Units','Characters','Style','Edit','String','', ...
    'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
    'Tag','VoxelSizeEditBoxExtra', ...
    'Callback','readmrgui(''SelectorEditBox_Callback'',gcbo,[],guidata(gcbo));');
end
% Store the handles for all the selector boxes in the UserData of the 1st dimension.
set(h(1),'Tag','VoxelSizeEditBox','UserData',h);

% Generate selector boxes
uicontrol('Units','Characters','Style','text','String','Selector:',...
  'Tag','SelectorLabel', 'FontAngle', 'Italic','HorizontalAlignment','Right', ...
  'CallBack','readmrgui(''SelectorLabel'',gcbo,[],guidata(gcbo));', ...
  'Tooltip',['Specify the indcies of the elements of the matrix you want to read.  ', ...
      'Use empty to specify all elements.']);
for n=1:nDims
  h(n)=uicontrol('Units','Characters','Style','Edit','String','', ...
    'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
    'Tag','SelectorEditBoxExtra', ...
    'Callback','readmrgui(''SelectorEditBox_Callback'',gcbo,[],guidata(gcbo));');
end
% Store the handles for all the selector boxes in the UserData of the 1st dimension.
set(h(1),'Tag','SelectorEditBox','UserData',h);

% Generate an orientation pull down menu
uicontrol('Units','Characters','Style','text','String','Orientation:',...
  'Tag','OrientationPopupMenuLabel', 'FontAngle', 'Italic', ...
  'HorizontalAlignment','Right', ...
  'CallBack','readmrgui(''OrientationPopupMenuLabel'',gcbo,[],guidata(gcbo));');
orientations = local_getOrientations;
uicontrol('Units','Characters','Style','PopupMenu','String',orientations.displayNames, ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','OrientationPopupMenu',...
  'Callback','readmrgui(''OrientationPopupMenu_Callback'',gcbo,[],guidata(gcbo));');

% Generate an orientation RAS flag box
uicontrol('Units','Characters','Style','text','String','RAS Flag:',...
  'Tag','RASFlagEditBoxLabel', 'FontAngle', 'Italic', ...
  'CallBack','readmrgui(''RASFlagEditBoxLabel'',gcbo,[],guidata(gcbo));');
uicontrol('Units','Characters','Style','Edit','String','', ...
  'BackgroundColor',[1 1 1],'Value',1,'HorizontalAlignment','Left', ...
  'Tag','RASFlagEditBox',...
  'Callback','readmrgui(''RASFlagEditBox_Callback'',gcbo,[],guidata(gcbo));');

% Generate an Oblique check box
uicontrol('Units','Characters','Style','Checkbox','String','Oblique',...
  'Tag','ObliqueCheckbox', 'Value',0,'FontAngle', 'Italic');

% Generate a string to show current status of GUI
uicontrol('Units','Characters','Style','text','String','', ...
  'HorizontalAlignment','Left','Tag','statusText','ForegroundColor','Red');

% --------------------------------------------------------------------
function local_resizegui(handles)
% LOCAL_RESIZEGUI - Resize GUI

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

% Get size of GUI
figurePos = get(handles.readmrgui,'Position');
figureWidth=figurePos(3);
figureHeight=figurePos(4);

% GUI Element sizes (all in Character units)
figureMarginWidth=1.5;
figureMarginHeight=figureMarginWidth*width2height;
buttonMarginWidth=1;
buttonMarginHeight=buttonMarginWidth*width2height;
okayButtonWidth=8;
cancelButtonWidth=10; 
browseButtonWidth=10;
buttonHeight=1.5;
listboxArrowWidth=3.75;
formatPopupWidth = 25;
wildcardCheckboxWidth = 23;
statusTextWidth = 30;
statusTextHeight = 1.5;

pixelTypeLabelWidth  = 11;
pixelTypeWidth = 13;
byteOrderLabelWidth = 13;
byteOrderWidth = 18;
hdrSizeLabelWidth = 11;
hdrSizeWidth = 10;

formatSpecificHeight = 0;
dimensionsLabelWidth = 14;
dimensionWidth = 10;
selectorLabelWidth = dimensionsLabelWidth;
selectorWidth = dimensionWidth;

orientationPopupMenuLabelWidth = 14;
orientationPopupMenuWidth = 23;
RASFlagEditBoxLabelWidth = 14;
RASFlagEditBoxWidth = 7;
obliqueCheckboxWidth = 25;

% Position Buttons
pos=[figureMarginWidth figureHeight-figureMarginHeight-2*buttonHeight-buttonMarginHeight browseButtonWidth buttonHeight];
set(handles.ChooseFileButton,'Position',pos);

pos=[figureMarginWidth figureMarginHeight okayButtonWidth buttonHeight];
set(handles.OkayButton,'Position',pos);

pos=[figureMarginWidth+buttonMarginWidth+okayButtonWidth figureMarginHeight cancelButtonWidth buttonHeight];
set(handles.CancelButton,'Position',pos);

pos=[figureMarginWidth+5*buttonMarginWidth+okayButtonWidth+cancelButtonWidth, figureMarginHeight ...
    statusTextWidth, statusTextHeight];
set(handles.statusText,'Position',pos);

% Position Recent File list
pos=[figureMarginWidth figureHeight-figureMarginHeight-buttonHeight figureWidth-2*figureMarginWidth buttonHeight];
set(handles.FileListPopupMenu,'Position',pos);

% Position edit field to enter filename in
pos=[figureMarginWidth, figureHeight-figureMarginHeight-buttonHeight, ...
    figureWidth-2*figureMarginWidth-listboxArrowWidth, buttonHeight];
set(handles.FileEdit,'Position',pos);

% Position the wildcard checkbox
pos=[figureMarginWidth+browseButtonWidth+buttonMarginWidth, figureHeight-figureMarginHeight-2*buttonHeight-buttonMarginHeight, ...
    wildcardCheckboxWidth, buttonHeight];
set(handles.WildcardCheckbox,'Position',pos);


% Position the Format List
pos=[figureWidth-figureMarginWidth-formatPopupWidth, figureHeight-figureMarginHeight-2*(buttonHeight+buttonMarginHeight), ...
    formatPopupWidth, buttonHeight];
set(handles.FormatListPopupMenu,'Position',pos);


% FILE FORMAT FRAME
pos=[figureMarginWidth, figureHeight-figureMarginHeight-5.5*(buttonHeight+buttonMarginHeight), ...
    figureWidth-(figureMarginWidth*2), buttonHeight*3+buttonMarginHeight*1];
set(handles.FileFormatFrame,'Position',pos);


% Position the data type buttons
pos=[2*figureMarginWidth, figureHeight-figureMarginHeight-4*(buttonHeight+buttonMarginHeight), ...
    pixelTypeWidth, buttonHeight];
set(handles.PixelTypePopupLabel,'Position',pos);

pos=[2*figureMarginWidth, figureHeight-figureMarginHeight-5*(buttonHeight+buttonMarginHeight), ...
    pixelTypeWidth, buttonHeight];
set(handles.PixelTypePopup,'Position',pos);

pos=[2*figureMarginWidth+pixelTypeWidth+2*buttonMarginWidth, figureHeight-figureMarginHeight-4*(buttonHeight+buttonMarginHeight), ...
    byteOrderWidth, buttonHeight];
set(handles.ByteOrderPopupLabel,'Position',pos);

pos=[2*figureMarginWidth+pixelTypeWidth+2*buttonMarginWidth, figureHeight-figureMarginHeight-5*(buttonHeight+buttonMarginHeight), ...
    byteOrderWidth, buttonHeight];
set(handles.ByteOrderPopup,'Position',pos);

pos=[2*figureMarginWidth+pixelTypeWidth+byteOrderWidth+4*buttonMarginWidth, figureHeight-figureMarginHeight-4*(buttonHeight+buttonMarginHeight), ...
    hdrSizeLabelWidth, buttonHeight];
set(handles.HdrSizeLabel,'Position',pos);

pos=[2*figureMarginWidth+pixelTypeWidth+byteOrderWidth+4*buttonMarginWidth, figureHeight-figureMarginHeight-5*(buttonHeight+buttonMarginHeight), ...
    hdrSizeWidth, buttonHeight];
set(handles.HdrSize,'Position',pos);

% Position the dimension labels
label_h=get(handles.DimensionLabel,'UserData');
for n=1:length(label_h)
  pos=[figureMarginWidth+dimensionsLabelWidth+n*buttonMarginWidth+(n-1)*dimensionWidth, figureHeight-figureMarginHeight-7*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
      dimensionWidth, buttonHeight];
  set(label_h(n),'Position',pos);
end

% Position the dimension boxes
pos=[figureMarginWidth, figureHeight-figureMarginHeight-8*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    dimensionsLabelWidth, buttonHeight];
set(handles.DimensionsLabel,'Position',pos);

size_h=get(handles.SizeEditBox,'UserData');
for n=1:length(size_h)
  pos=[figureMarginWidth+dimensionsLabelWidth+n*buttonMarginWidth+(n-1)*dimensionWidth, figureHeight-figureMarginHeight-8*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
      dimensionWidth, buttonHeight];
  set(size_h(n),'Position',pos);
end

% Position the voxel size boxes
pos=[figureMarginWidth, figureHeight-figureMarginHeight-9*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    selectorLabelWidth, buttonHeight];
set(handles.VoxelSizeLabel,'Position',pos);

voxel_size_h=get(handles.VoxelSizeEditBox,'UserData');
for n=1:length(voxel_size_h)
  pos=[figureMarginWidth+selectorLabelWidth+n*buttonMarginWidth+(n-1)*selectorWidth, figureHeight-figureMarginHeight-9*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
      selectorWidth, buttonHeight];
  set(voxel_size_h(n),'Position',pos);
end

% Position the selector boxes
pos=[figureMarginWidth, figureHeight-figureMarginHeight-10*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    selectorLabelWidth, buttonHeight];
set(handles.SelectorLabel,'Position',pos);

size_h=get(handles.SelectorEditBox,'UserData');
for n=1:length(size_h)
  pos=[figureMarginWidth+selectorLabelWidth+n*buttonMarginWidth+(n-1)*selectorWidth, figureHeight-figureMarginHeight-10*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
      selectorWidth, buttonHeight];
  set(size_h(n),'Position',pos);
end

% Position the orientation menu
pos=[figureMarginWidth, figureHeight-figureMarginHeight-12*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    orientationPopupMenuLabelWidth, buttonHeight];
set(handles.OrientationPopupMenuLabel,'Position',pos);
pos=[figureMarginWidth+buttonMarginWidth+orientationPopupMenuLabelWidth, figureHeight-figureMarginHeight-12*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    orientationPopupMenuWidth, buttonHeight];
set(handles.OrientationPopupMenu,'Position',pos);

% Position the RAS flag box
pos=[figureMarginWidth+orientationPopupMenuLabelWidth+buttonMarginWidth+orientationPopupMenuWidth, ...
    figureHeight-figureMarginHeight-12*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    RASFlagEditBoxLabelWidth, buttonHeight];
set(handles.RASFlagEditBoxLabel,'Position',pos);
pos=[figureMarginWidth+orientationPopupMenuLabelWidth+orientationPopupMenuWidth+RASFlagEditBoxLabelWidth, figureHeight-figureMarginHeight-12*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    RASFlagEditBoxWidth, buttonHeight];
set(handles.RASFlagEditBox,'Position',pos);

% Position the Oblique checkbox
pos=[figureMarginWidth+orientationPopupMenuLabelWidth+buttonMarginWidth, ...
    figureHeight-figureMarginHeight-13*(buttonHeight+buttonMarginHeight)-formatSpecificHeight, ...
    obliqueCheckboxWidth, buttonHeight];
set(handles.ObliqueCheckbox,'Position',pos);


% --------------------------------------------------------------------
function datatypes=local_getDatatypes(arg)

datatypes.type =  ...
  {'uchar', 'schar', ...
    'int8', 'int16', 'int32', 'int64', ...
    'uint8', 'uint16', 'uint32', 'uint64', ...
    'single', 'float32', 'double', 'float64'};
datatypes.size =  ...
  {1, 1, ...
    1, 2, 4, 8, ...
    1, 2, 4, 8, ...
    4, 4, 8, 8 };

% --------------------------------------------------------------------
function byteorders = local_getByteorders(arg)

byteorders.names = {'Little-endian','Big-endian'};
byteorders.codes = {'l','b'};

% --------------------------------------------------------------------
function out = local_getFormats(arg)
%LOCAL_GETFORMATS - Get formats
%
%  % Return all formats
%  formats = local_getFormats(-1);
%
%  % Return index'th format in list
%  format = local_getFormats(index); 
%
%  % Return index of specifed format name
%  index = local_getFormats(formatName);
%
%  format/formats is a structure will properties of each format.

% Construct formats structure.
%  Column 1: Format name  (.name)
%  Column 2: Display name (.displayName)
%  Column 3: Allow multiple files (.allowMultipleFiles)
formats = { ...
    'BXH','BXH',0; ...
    'DICOM','DICOM',1; ...
    'DICOM_Search','DICOM_Search',0; ...
    'DICOM_Volume','DICOM_Volume',1; ...
    'DICOM_Slice','DICOM_Slice',0; ...
    'Volume','Volume',1; ...
    'Float','Float',1; ...
    'Raw','Raw',1; ...
    'Analyze7.5_SPM','Analyze7.5_SPM',1; ...
    'Signa5','Signa 5',1; ...
    'SignaXIMG','Signa XIMG',1; ...
    'WorkspaceVar','Workspace Variable',0; ...
  };
% Convert columns into a structure.
formats = struct( ...
  'name', formats(:,1), ...
  'displayName', formats(:,2), ...
  'allowMultipleFiles', formats(:,3))'; 

if isnumeric(arg)
  if arg == -1  % Return whole requested list.
    out = formats;
  else % Return requested item
    out = formats(arg);
  end
else
  % Look for specifed item in list.
  out = find(strcmp(arg,{formats.name}));
end

% --------------------------------------------------------------------
function orientations = local_getOrientations

orientations.displayNames = {'Unspecified', 'Axial I=>S', 'Axial S=>I', 'Coronal A=>P', 'Coronal P=>A', 'Sagittal L=>R', 'Sagittal R=>L', 'Custom RAS Flag'};
orientations.rasFlags     = {'',            'lps',        'lpi',        'lip',          'lia',          'pir',           'pil',           ''};

% --------------------------------------------------------------------
function dimNames = local_getDimensionNames

dimNames = {'x','y','z','t'};

% --------------------------------------------------------------------
function local_calcNumSlices(handles)
%LOCAL_CALCNUMSLICES - Calculate number of slices.
%
% Calculate the number of slices assuming that the data consists of the
% entire file after the header.  Update the GUI if this number is an
% integer.

% Get current format
fileFormat = local_getFormats(get(handles.FormatListPopupMenu,'Value'));

% Only attempt this for "Raw" formats:
if any(strcmp(fileFormat.name,{'Volume','Float','Raw'}));
  % Determine the file size (1st file if wildcard)
  filenames = get(handles.FileEdit,'UserData');
  % User size from 1st file in list.
  d = dir(filenames{1});
  if isempty(d), return; end   % If nothing matches, just return
  fileSize = d.bytes;

  % Determine number of bytes per element for this pixelType
  datatypes = local_getDatatypes([]);
  voxelBytes = datatypes.size{get(handles.PixelTypePopup,'Value')};

  % Get handles to size boxes
  size_h=get(handles.SizeEditBox,'UserData');
  
  % Determine header and in-plane matrix size
  hdrSize = str2double(get(handles.HdrSize,'String'));
  xSz = str2double(get(size_h(1),'String'));
  ySz = str2double(get(size_h(2),'String'));
  if ~all(isnan([hdrSize,xSz,ySz]))
    zSz = (fileSize - hdrSize) ./ (voxelBytes .* xSz .* ySz);
    if isint(zSz)
      % It is an integer, update GUI
      set(size_h(3),'String',num2str(zSz));
    else
      % Otherwise clear current setting (TODO: okay for raw???)
      set(size_h(3),'String','');
    end
  end
end

% --------------------------------------------------------------------
function local_calcNumTimePts(handles)
%LOCAL_CALCNUMTIMEPTS - Calculate number of time points
%
% Calculate the number of time points to equal the number of files
% specified.

% Get current format
fileFormat = local_getFormats(get(handles.FormatListPopupMenu,'Value'));

% Get handles to size boxes
size_h=get(handles.SizeEditBox,'UserData');

% Only attempt this for "Raw" formats:
if any(strcmp(fileFormat.name,{'Volume','Float','Raw'}));
  % Determine the file size (1st file if wildcard)
  filenames = get(handles.FileEdit,'UserData');
  if isempty(filenames), % If no files, set to ''
    set(size_h(4),'String','');
  else
    set(size_h(4),'String',num2str(length(filenames)));
  end
end

% --------------------------------------------------------------------
function local_setDefinedFormat(mrinfo,handles)
%LOCAL_SETDEFINEDFORMAT - Setup GUI for specified mrinfo structure.
%

% Set the data type
datatypes = local_getDatatypes([]);
datatypeIndex = strmatch(mrinfo.info.rawelemtype, datatypes.type);
set(handles.PixelTypePopup,'Value',datatypeIndex,'Enable','off');

% Set the byte order
byteOrders = local_getByteorders([]);
byteOrderIndex = strmatch(mrinfo.info.byteorder, byteOrders.codes);
set(handles.ByteOrderPopup,'Value',byteOrderIndex,'Enable','off');

% Set the header size
set(handles.HdrSize,'String','N/A','Enable','off');

% Set the dimensions
ndims = 4;
label_h = get(handles.DimensionLabel,'UserData');
size_h = get(handles.SizeEditBox,'UserData');
selector_h = get(handles.SelectorEditBox,'UserData');
voxelSize_h = get(handles.VoxelSizeEditBox,'UserData');
labels = {mrinfo.info.dimensions.type};
dimSz = [mrinfo.info.dimensions.size];
voxSz = [mrinfo.info.dimensions.spacing];

% TODO: Create additional dimensions as necessary!
if length(dimSz) > ndims
  waitfor(warndlg('More than 4 dimensions not supported (but may work)', ...
    'More than 4 dimensions'));
end

for n = 1:length(dimSz)
  % Update dimension label and size (always in mrinfo)
  set(label_h(n),'Visible','on','String',labels{n});
  set(size_h(n),'String',num2str(dimSz(n)),'Enable','off','Visible','on');
  % Enable selectors for dimensions present.
  set(selector_h(n),'Enable','on','Visible','on');
  % Handle voxel size
  if ~isnan(voxSz(n))
    % Voxel size defined, display it and don't let user change.
    set(voxelSize_h(n),'String',num2str(voxSz(n)),'Enable','off','Visible','on');
  else
    % Voxel size not defined, allow user to specify it.
    set(voxelSize_h(n),'String','','Enable','on','Visible','on');
  end
end
% Turn off extra dimensions
if(length(dimSz)<ndims)
  for n = length(dimSz)+1:ndims
    set(label_h(n),'Visible','off');
    set(size_h(n),     'String','1','Enable','off','Visible','off');
    set(selector_h(n),  'String','', 'Enable','off','Visible','off');
    set(voxelSize_h(n),'String','', 'Enable','off','Visible','off');
  end
end

% Handle orientation
orientDefined = 1;
try % Try to determine orientation
  [rasFlag,obliqueFlag] = getorientation(mrinfo);
catch
  orientDefined = 0;
end
if orientDefined
  % Determined orientation, display it and don't let user change.
  
  % Determine which pull down item to specify
  orientations = local_getOrientations;
  ii = find(strcmp(rasFlag,orientations.rasFlags));
  % Use custom RAS flag if not in list.
  if isempty(ii), ii = length(orientations.rasFlags); end
  
  % Setup GUI
  set(handles.OrientationPopupMenu,'Enable','Off','Value',ii);
  set(handles.RASFlagEditBox,'Enable','Off','String',rasFlag);
  set(handles.ObliqueCheckbox,'Enable','Off','Value',obliqueFlag);
else
  % Unable to determine orientation, allow user to specify it.
  set(handles.OrientationPopupMenu,'Enable','On','Value',1);
  set(handles.RASFlagEditBox,'Enable','On','String','');
  set(handles.ObliqueCheckbox,'Enable','On','Value',0);
end  

% --------------------------------------------------------------------
function RecentStruct=local_manageRecentFiles(action,arg)
% local_manageRecentFiles - Function to maintain list of recent
%   files/directories across all instances of readmr.
%
%   RecentStruct=local_manageRecentFiles(action,arg)
%     Actions: 
%       'Get' - Get current RecentFiles cell array
%       'Add' - Add arg file(s) and their directory(s) to list
%       'AddFileOnly' - Add arg file(s) to lis
%       'Clear' - Clear all entries
%     RecentStruct - Struct of recent files & directories with fields
%        RecentFiles - cell array of strings of recent files.
%        RecentDirs  - cell array of strings of recent directories.
%        RecentCombined - cell array of strings combining file and
%                         direcotory listing

persistent RecentFiles RecentDirs
% Initialize to empty cell arrays for cat'ing with other cell arrays
if isempty(RecentFiles), RecentFiles={}; end
if isempty(RecentDirs), RecentDirs={}; end

% Maximum number of files and directories in list.
FileListMaxFiles=5;
FileListMaxDirs=5;

switch action
case 'Get'
  % Return current RecentFiles (always returns if output requested)
  if nargout==0, error('Must have output argument for ''Get'' action!'); end
  
case 'Clear'
  % Clear list of recent files and directories
  RecentFiles={};
  RecentDirs={};
  
case 'Add'
  % Add specified file(s) & their directory(s) to list.
  
  % Put single filename is a cell array for uniform handling.
  if ~iscell(arg), arg={arg}; end 
  
  % Loop through each file
  for nArg=1:length(arg) 
    % Add current file entry (if not already there)
    if ~any(strcmp(RecentFiles,arg{nArg}))
      RecentFiles=cat(2,arg(nArg),RecentFiles);
    end
    
    % Add directory entry for current file if one exists (& is not already there)
    currDir=fileparts(arg{nArg});
    if ~isempty(currDir) & ~any(strcmp(RecentDirs,[currDir filesep]))
      RecentDirs=cat(2,{[currDir filesep]},RecentDirs);
    end
  end
  
  % Remove extra file entries (from end)
  if length(RecentFiles) > FileListMaxFiles
    RecentFiles=RecentFiles(1:FileListMaxFiles);
  end
  
  % Remove extra directory entries (from end)
  if length(RecentDirs) > FileListMaxDirs
    RecentDirs=RecentDirs(1:FileListMaxDirs);
  end
  
case 'AddFileOnly'
  % Add specified file(s) 
  
  % Put single filename is a cell array for uniform handling.
  if ~iscell(arg), arg={arg}; end 
  
  % Loop through each file
  for nArg=1:length(arg) 
    % Add current file entry (if not already there)
    if ~any(strcmp(RecentFiles,arg{nArg}))
      RecentFiles=cat(2,arg(nArg),RecentFiles);
    end
  end
  
  % Remove extra file entries (from end)
  if length(RecentFiles) > FileListMaxFiles
    RecentFiles=RecentFiles(1:FileListMaxFiles);
  end
  
otherwise
  error('local_manageRecentFiles: Unknown action!');
end

if nargout > 0,
  % Construct Recent files and directories combined view.
  % {'',Files,'',Dirs} | if no Dirs -> {'',Files} | if no Files -> {'',Dirs}
  if ~isempty(RecentFiles);
    RecentCombined=cat(2,{''},RecentFiles);
    areFiles={''};
  else
    RecentCombined={''}; % Empty first line
    areFiles={};
  end
  if ~isempty(RecentDirs)
    RecentCombined=cat(2,RecentCombined,areFiles,RecentDirs);
  end
  
  % Generate output structures
  RecentStruct=struct('RecentFiles',{RecentFiles},'RecentDirs',{RecentDirs}, ...
    'RecentCombined',{RecentCombined});
end

% Modification History:
%
% $Log: readmrgui.m,v $
% Revision 1.20  2005/02/22 20:18:25  michelich
% Use more robust version parsing code.
%
% Revision 1.19  2005/02/03 19:17:55  michelich
% Removed incorrect (and unnecessary) sprintf when creating error box title.
%
% Revision 1.18  2005/02/03 16:58:42  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.17  2004/08/09 20:04:06  gadde
% Add DICOM and DICOM_Search to file types.
%
% Revision 1.16  2004/02/24 20:20:23  gadde
% Update error messages.
%
% Revision 1.15  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.14  2003/08/12 15:56:38  gadde
% Give more useful error message for BXH.
%
% Revision 1.13  2003/07/31 03:39:48  michelich
% Pass wildcard expanded inputlocs to readmr.
%
% Revision 1.12  2003/07/03 20:22:13  gadde
% Use more consistent elemtype description in info by adding
% rawelemtype (input) and outputelemtype (output).
%
% Revision 1.11  2003/07/03 01:54:58  michelich
% Always return an mrinfo structure as first argument.
% Cache mrinfo for better performance.
%
% Revision 1.10  2003/07/02 15:28:49  michelich
% Bug Fix: Don't return information for inactive dimensions.
%
% Revision 1.9  2003/07/01 18:31:07  gadde
% Move hdrSz to end of Raw parameters and add opt_recSz to allow for footers.
%
% Revision 1.8  2003/07/01 16:05:41  michelich
% Adjusted layout.
%
% Revision 1.7  2003/07/01 04:37:12  michelich
% Remove Legacy formats.
%
% Revision 1.6  2003/06/30 19:19:43  michelich
% Changed label of wildcard checkbox and added tooltip strings.
%
% Revision 1.5  2003/06/30 16:54:30  michelich
% Updated for readmr name change.
%
% Revision 1.4  2003/06/30 06:20:35  michelich
% Updated for readmrgui name change.
%
% Revision 1.3  2003/06/30 06:14:10  michelich
% Renamed readmrtestgui.m to readmrgui.m (overwriting old version which had
%   been merged into readmr.m)
%
% --- All revisions listed below are in readmrtestgui.m,v ---
% Revision 1.6  2003/06/30 05:24:03  michelich
% Store wildcard expanded and exist verified filename in FileEdit UserData
%   for better performance.
% Notify user if they type and invalid filename or workspace variable.
%
% Revision 1.5  2003/06/29 22:37:05  michelich
% Allow user to specify information which is not in header of fully specified formats.
% Notify user and revert to last successful format if user selects incorrect format.
% Added status line for steps which can take a long time (e.g. =>INFOONLY, dir).
% Updated local_getFormats to return a structure of information on current format.
% Separated functions to calculate zSz and tSz from file size and number of files.
% Updated orientation list when user enters a RAS flag.
% Pass all files matching wildcard to autodetectmr.
% Check that file exists before allowing Okay.
% Handle user clearing filename string without error.
% Repositioned Oblique checkbox and changed to italic.
% Update dimension labels.
% Enable/Disable Wildcard checkbox depending on current format.
% Updated behavior of wildcard checkbox.
% Misc readability changes in whitespace.
%
% Revision 1.4  2003/06/28 18:12:40  michelich
% Fix using directory of current file on browse.
% Add lots more error checking.
% Add DICOM_Slice and DICOM_Volume support.
% Only return mrinfo if necessary to specify orientation and/or voxel size.
% Remove unnecessary "Null" callbacks.
% Don't use size defaults on Raw, Volume, Float if already specified.
% Implemented more functionality in local_getFormats().
% Auto calculate slice when xSz,ySz,elementType change for Float and Volume.
% Reorder GUI creation for more intuitive tab order.
% Use '' for default sizes.
% Don't attempt autodetect on directories or non-existant files.
% Misc performance enhancements.
%
% Revision 1.3  2003/06/27 20:46:30  mack
% Added support for non-BXH format files, interactive selection of data type,
% dimensionality, and orientation meta-information.
%
% Revision 1.2  2003/05/30 03:01:42  michelich
% Added FileEdit box for typing and modifying filenames.
% Added ability to chose workspace variable like the old readmr.
% Implemented resize function.
% local_manageRecentFiles- Added addFileOnly action
% local_manageRecentFiles- Don't remove extra entries until all have been added.
%
% Revision 1.1  2003/05/30 02:48:24  michelich
% Moved GUI code from readmrtest.m to readmrtestgui.m
%
