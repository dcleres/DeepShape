function [root,emsg]=fileroot(fName)
%FILEROOT Returns the root directory from a file name.
%
%   [root,emsg]=fileroot(fName);
%
%   fName is a file name.
%   root is the file name's root directory or '' for relative file names.
%
%   Notes
%     root will include a trailing FILESEP character, unless it's empty.
%     Returns '' in root and non-empty emsg for unsupported OS.
%     Handles UNC paths on PC.
%     Does not handle invalid file names.
%
%   Examples
%   >>fileroot('C:\data\file.txt')
%   ans =
%   C:\
%   >>fileroot('C:file.txt')
%   ans =
%        ''
%
%   See also ISRELPATH, FILESEP, FILEPARTS, FULLFILE, CD.

% CVS ID and authorship of this code
% CVSId = '$Id: fileroot.m,v 1.3 2005/02/03 16:58:33 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:33 $';
% CVSRCSFile = '$RCSfile: fileroot.m,v $';

root='';
err='';

% Handle various OSes
if ~isempty(fName)
  if strncmp(computer,'PC',2)
    if length(fName)>1 & strcmp(fName(1:2),'\\')
      % UNC directory '\\machine\share\'
      seps=findstr(fName,filesep);
      if length(seps)==3
        root=[fName '\'];
      elseif length(seps)>3
        root=fName(1:seps(4));
      end
    elseif length(fName)>2 & isletter(fName(1)) & fName(2)==':' & fName(3)=='\'
      % Drive letter 'C:\'
      root=fName(1:3);
    end
  elseif isunix
    if fName(1)=='/'
      root='/';
    end
  else
    err='fileroot: Unsupported operating system.  Returning empty string.';
  end
end

if nargout>1
  emsg=err;
else
  warning(err);
end

% Modification History:
%
% $Log: fileroot.m,v $
% Revision 1.3  2005/02/03 16:58:33  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:35  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:14  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2001/01/23. Change function name to lowercase
% Francis Favorini,  2000/04/14.

