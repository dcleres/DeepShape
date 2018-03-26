function bxhabsorb(varargin)
%BXHABSORB - Creates BXH file from input data files and optional format info
%
%  bxhabsorb;                % Specify everything from a GUI
%  bxhabsorb(outputbxhfile); % Specify READMR arguments from a GUI.
%  bxhabsorb(outputbxhfile, readmrparams...)
%  bxhabsorb(outputbxhfile, readmrparams..., 'OVERWRITE')
%
% Send arguments just like you would to READMR, but prepend with the name
% with path of a BXH file (outputbxhfile).  It will then "encapsulate" the
% data by producing a BXH file that points to the data.  The OVERWRITE flag
% causes the outputbxhfile to be overwritten if it already exists.
% You are strongly encouraged to use the command-line C/C++ version of
% bxhabsorb rather than this Matlab version.  The command-line version
% is faster, has more features, and is tested more thoroughly.
%
% See Also: READMR

% CVSId = '$Id: bxhabsorb.m,v 1.16 2005/02/03 16:58:38 michelich Exp $';
% CVSRevision = '$Revision: 1.16 $';
% CVSDate = '$Date: 2005/02/03 16:58:38 $';
% CVSRCSFile = '$RCSfile: bxhabsorb.m,v $';

% TODO: Deal with selectors??? (they are currently ignored).
% TODO: Request infoonly when reading parameters from GUI.

% Handle arguments
if nargin == 0
  % User didn't specify anything
  outputfile = ''; % Prompt for output filename
  readmrArgs = {}; % Prompt for readmr arguments.
  overwrite = [];  % Prompt for overwrite.
else
  % User specifed output file
  outputfile = varargin{1};
  if ~ischar(outputfile)
    error('First argument must be output BXH file!');
  end

  if nargin == 1,
    % User ONLY specifed output file
    readmrArgs = {}; % Prompt for readmr arguments.
    overwrite = [];  % Prompt for overwrite.
  else
    % User specifed everything
    
    % Overwrite option is last argument (if present)
    if ischar(varargin{end}) & strcmp(varargin{end},'OVERWRITE');
      overwrite = 1;
      if nargin == 2, 
        error('You must specify the READMR arguments!');
      end
      readmrArgs = varargin(2:end-1);
    else
      overwrite = 0;
      readmrArgs = varargin(2:end);
    end
    % Remove '=>INFOONLY' if user included it
    if strcmp(readmrArgs{end}, '=>INFOONLY')
      if length(readmrArgs) == 1
        error('You must specify the READMR arguments (=>INFOONLY is not enough)!');
      end
      readmrArgs = readmrArgs(1:end-1);
    end
  end
end

if isempty(readmrArgs)
  % Use GUI to get options
  [readmrArgs,workspaceVar] = readmrgui;
  if isempty(readmrArgs)
    if ~isempty(workspaceVar)
      error('Cannot create a header for a workspace variable');
    else
      disp('User cancelled'); return;
    end
  end
end

% Get MR struct from the given parameters, but don't read data
if isstruct(readmrArgs{1}) & isfield(readmrArgs{1},'inputfiles')
  % Already is an infoonly mrstruct.  Just use it.
  if length(readmrArgs) > 1 & ~(iscell(readmrArgs{2}) & all(cellfun('isempty',readmrArgs{2})))
    % Warn user if additional arguments passed (except empty selector).
    warning('Only using mrinfo structure.  Ignoring additional readmr arguments.');
  end
  mrstruct = readmrArgs{1};
else
  mrstruct = readmr(readmrArgs{:}, '=>INFOONLY');
end

% Cleanup immediately since we don't need to read the files.
readmr(mrstruct,'=>CLEANUP'); 

% Make sure this isn't already BXH format.
if strcmp(mrstruct.info.hdrtype,'BXH')
  error('Chosen file is already in BXH format!');
end

if isempty(outputfile)
  % Prompt user for output file (& overwrite)

  % Determine default filename & path based on first inputloc
  [pathstr,name,ext,versn] = fileparts(mrstruct.inputlocs{1});
  defaultName = fullfile(pathstr,[name,'.bxh',versn]);
  clear pathstr name ext versn
  
  okay = 0;
  overwrite = 0; % Don't overwrite by default.
  while ~okay
    [filename,pathname] = uiputfile(defaultName,'Please choose an output filename');
    if isequal(filename,0) | isequal(pathname,0)
      disp('User cancelled'); return;
    end
    outputfile = fullfile(pathname,filename);
    
    % Add a .bxh to the filename if there is no extension
    [pathstr,name,ext,versn] = fileparts(outputfile);
    if isempty(ext), outputfile = fullfile(pathstr,[name,'.bxh',versn]); end
    clear pathstr name ext versn
    
    % TODO: This may not be necessary (uiputfile already asks on windows).
    %       Always necessary if we added the extension.
    if exist(outputfile,'file')
      % Overwrite existing file?
      button = questdlg(sprintf('Overwrite file %s',outputfile),'Overwrite File','Yes','No','Yes');
      if strcmp(button,'No');
        continue;  % Ask for another filename
      else
        overwrite = 1; % Overwrite the file.
      end
    end
    okay = 1;    % Use the file chosen.
  end
end

% If user hasn't told us if they want to overwrite, ask.
if isempty(overwrite)
  overwrite = 0;
  if exist(outputfile,'file')
    button = questdlg(sprintf('Overwrite file %s',outputfile),'Overwrite File','Yes','No','Yes');
    if strcmp(button,'Yes'), overwrite = 1; end
  end
end

% Check for overwrite.
if ~overwrite & exist(outputfile, 'file')
  error(['Output file ' outputfile ' already exists']);
end

% XXX HACK XXX
% Copy rawdimensions to dimensions -- updated fields in GUI
% may only be in rawdimensions.
mrstruct.info.dimensions = mrstruct.info.rawdimensions;

% Convert native header (if it exists) in mrstruct.info to a BXH header
% so we'll have a template for the BXH header with as much data as
% convertmrstructtobxh gives us (currently not that much).
newmrstruct = convertmrstructtobxh(mrstruct);

% Grab this header template
outhdr = newmrstruct.info.hdr;

% Create an easy-to-manipulate datarec structure from the info.
% (writemrtest would do this too, but it would also create its
% own data files -- we just want to point to the existing ones)
newdatarec = mrinfo2datarec(mrstruct.info, 'image');

% Use relative filenames for files that are in the same directory as the
% BXH file.  Otherwise, use absolute filenames.
[pathstr, name, ext, ver] = fileparts(outputfile);
if isrelpath(pathstr)
  pathstr = fullfile(pwd, pathstr);
end
caseSensitive = ~any(strcmp(computer,{'PCWIN','MAC','MAC2'})); % Case insensitive filesystem on PC and Mac
if isfield(mrstruct, 'inputfiles')
  for fnnum = 1:length(newdatarec.filename)
    [filePath,fileName,fileExt,fileVer] = fileparts(newdatarec.filename{fnnum}.VALUE);
    if (caseSensitive & strcmp(filePath,pathstr)) ...
        | (~caseSensitive & strcmpi(filePath,pathstr))
      % Same directory, just keep the filename.
      newdatarec.filename{fnnum}.VALUE = [fileName,fileExt,fileVer];
    end
  end
end

% If BXH file is in current directory and input locations are
% relative, fix filenames so they are relative too.
% If you are writing to a BXH file in another directory,
% then filenames inside it will be absolute.
[pathstr, name, ext, ver] = fileparts(outputfile);
if isfield(mrstruct, 'inputfiles') & isempty(pathstr)
  for fnnum = 1:length(newdatarec.filename)
    for locnum = 1:length(mrstruct.inputfiles)
      if strcmp(mrstruct.inputfiles{locnum}, newdatarec.filename{fnnum}.VALUE)
        newdatarec.filename{fnnum}.VALUE = mrstruct.inputlocs{locnum};
        break
      end
    end
  end
end

% Add this datarec to the template header (which doesn't have any datarecs).
outhdr.bxh{1}.datarec{1} = newdatarec;

% Write out the template header (which is now complete).
writexml(outhdr, outputfile);

% Modification History:
%
% $Log: bxhabsorb.m,v $
% Revision 1.16  2005/02/03 16:58:38  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.15  2004/07/26 19:51:27  gadde
% Added note to help.
%
% Revision 1.14  2004/05/06 15:47:33  michelich
% Assume case-insensitve filesystem on Macs.
%
% Revision 1.13  2004/05/06 15:15:34  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.12  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.11  2003/10/13 20:05:59  gadde
% Fix relative filename processing.
%
% Revision 1.10  2003/09/12 15:10:00  michelich
% Check if file is already a BXH file.
% Use first inputloc to generate default filename and path.
% Use path and filename in file exists dialog.
%
% Revision 1.9  2003/09/09 17:15:19  gadde
% Hack to get GUI fields to work bxhabsorb.
%
% Revision 1.8  2003/07/08 15:48:12  michelich
% Don't attempt to get INFOONLY on info structs.
% Fixed bug is overwrite file prompt.
%
% Revision 1.7  2003/07/02 20:29:34  michelich
% Use relative filenames if BXH header and files are in the same directory.
%
% Revision 1.6  2003/07/02 20:06:37  michelich
% Cleanup mrstruct.
%
% Revision 1.5  2003/07/02 19:11:38  michelich
% Added support for using GUI to specify arguments.
%
% Revision 1.4  2003/06/30 16:58:22  michelich
% Updated for readmr name change.
%
% Revision 1.3  2003/06/04 22:27:16  gadde
% *** empty log message ***
%
% Revision 1.2  2003/05/29 20:17:27  gadde
% Use relative filenames in some cases.
%
% Revision 1.1  2003/05/29 18:44:59  gadde
% Initial import
%
