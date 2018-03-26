function ret=isrelpath(fName)
%ISRELPATH Is file name base on a relative path?
%
%   ret=isrelpath(fName);
%
%   fName is a file name.
%   ret is 0 if fName is fully qualified,
%     1 if fName is empty or relative to the current directory,
%     2 if on a PC and fName starts with '\'
%       ('\dir' is relative to the root of the current directory),
%     3 if on a PC and fName starts with a drive letter and colon,
%       but no backslash immediately thereafter
%       ('C:dir' is relative to the current directory on C:).
%
%   Notes
%     Returns -1 and prints warning for unsupported OS.
%     Handles UNC paths on PC.
%     Does not handle invalid file names.
%
%   Example
%     if isrelpath(fName), fName=fullfile(defPath,fName); end
%
%   See also FILEROOT, FILESEP, FILEPARTS, FULLFILE, CD.

% CVS ID and authorship of this code
% CVSId = '$Id: isrelpath.m,v 1.3 2005/02/03 16:58:34 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:34 $';
% CVSRCSFile = '$RCSfile: isrelpath.m,v $';

% TODO: Optionally return root.

if isempty(fName)
  ret=1;
else
  [root,emsg]=fileroot(fName);
  if isempty(root)
    if ~isempty(emsg)
      ret=-1;
      warning(emsg);
    elseif strncmp(computer,'PC',2)
      if isletter(fName(1)) & strncmp(fName(2:end),':',1) & ~strncmp(fName(2:end),':\',2)
        % C: or C:whatever
        ret=3;
      elseif fName(1)=='\'
        % \whatever
        ret=2;
      else
        ret=1;
      end
    else
      ret=1;
    end
  else
    ret=0;
  end
end

% Modification History:
%
% $Log: isrelpath.m,v $
% Revision 1.3  2005/02/03 16:58:34  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:16  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2001/01/23 Changed function name to lowercase. 
%                               Changed fileroot() to lowercase.
% Francis Favorini,  2000/04/14.
