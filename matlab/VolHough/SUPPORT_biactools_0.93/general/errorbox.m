function errorbox(errString,errTitle,errMode)
%ERRORBOX Display error message in dialog box.
%
%       errorbox(errString,errTitle,errMode);
%
%       errString is the error message.
%       errTitle is the title for the dialog box.  Default is 'Error'.
%       errMode is the 'WindowStyle' property for the dialog box.  Default is 'modal'.

% CVS ID and authorship of this code
% CVSId = '$Id: errorbox.m,v 1.3 2005/02/03 16:58:33 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:33 $';
% CVSRCSFile = '$RCSfile: errorbox.m,v $';

% Check args and setup defaults
if nargin<1, errString='No error string given!'; end
if nargin<2, errTitle='Error'; end
if nargin<3, errMode='modal'; end

beep;
if strcmpi(errMode,'modal')
  waitfor(msgbox(errString,errTitle,'error',errMode));
else
  msgbox(errString,errTitle,'error','non-modal');
end

% Modification History:
%
% $Log: errorbox.m,v $
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
% Francis Favorini, 1998/11/24. Added beep.
% Francis Favorini, 1998/10/17. Only waitfor modal dialog.
% Francis Favorini, 1998/09/28.
