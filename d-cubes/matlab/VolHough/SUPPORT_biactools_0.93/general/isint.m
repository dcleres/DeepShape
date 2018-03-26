function TF=isint(A)
%ISINT  True for integer elements.
%   Returns logical array the same size as A containing true (1)
%   where the elements of A are integers, false (0) otherwise.
%
%   TF=isint(A);

% CVS ID and authorship of this code
% CVSId = '$Id: isint.m,v 1.3 2005/02/03 16:58:34 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:34 $';
% CVSRCSFile = '$RCSfile: isint.m,v $';

if isempty(A)
  TF=[];
elseif isnumeric(A)
  TF=imag(A)==0 & [A-floor(A)]==0;
else
  TF=logical(zeros(size(A)));
end

% Modification History:
%
% $Log: isint.m,v $
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
% Francis Favorini, 1998/11/03. Return [] for empty input.
% Francis Favorini, 1998/09/30. Return false for non-numeric elements.
%                               Return false for imaginary elements.
% Francis Favorini, 1998/09/17.

