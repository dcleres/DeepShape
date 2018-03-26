function val = get(url, prop_name)

%GET - get properties of URL.
%   Valid properies are 'Scheme', 'User', 'Host', 'Port', 'Path',
%   'Dir', 'File', 'Query', 'Fragment'
%

% CVSId = '$Id: get.m,v 1.4 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.4 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: get.m,v $';

switch prop_name
 case 'Scheme'
  val = url.scheme;
 case 'User'
  val = url.user;
 case 'Host'
  val = url.host;
 case 'Port'
  val = url.port;
 case 'Path'
  val = url.path;
 case 'Dir'
  slashes = findstr(url.path, '/');
  if isempty(slashes)
    val = [];
  else
    val = url.path(1:slashes(end));
  end
 case 'File'
  slashes = findstr(url.path, '/');
  if isempty(slashes)
    val = url.path;
  else
    val = url.path(slashes(end)+1:end);
  end
 case 'Query'
  val = url.query;
 case 'Fragment'
  val = url.frag;
end

% $Log: get.m,v $
% Revision 1.4  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.3  2004/05/06 14:47:02  gadde
% Replace all uses of strfind with findstr (strfind doesn't exist before
% Matlab 6.1).
%
% Revision 1.2  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2003/03/20 16:58:22  gadde
% *** empty log message ***
%
