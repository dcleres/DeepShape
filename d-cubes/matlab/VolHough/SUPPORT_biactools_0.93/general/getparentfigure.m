function fig = getparentfigure(handle)
% getparentfigure - return the parent figure for the passed handle
%
%   fig=getparentfigure(handle)
%
%   Returns the parents figure for the specified handle(s)
%

% CVS ID and authorship of this code
% CVSId = '$Id: getparentfigure.m,v 1.3 2005/02/03 16:58:33 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:33 $';
% CVSRCSFile = '$RCSfile: getparentfigure.m,v $';

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
% $Log: getparentfigure.m,v $
% Revision 1.3  2005/02/03 16:58:33  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:35  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:15  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002/01/09. extracted from showsrs2 into it's own function
% Charles Michelich, 2001/09/21. copied from guidata.m
%                                modified to handle a vector of handles & added error checking
