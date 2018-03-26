function url = url(varargin)

%URL - an alternative to java.net.URL
%
%   url = url();
%   url = url(inurl);
%   url = url(urlstring, baseurl);
%   url = url(urlstring, baseurlstring);
%
%   uscheme = get(url, 'Scheme');
%   uuser   = get(url, 'User');
%   uhost   = get(url, 'Host');
%   uport   = get(url, 'Port');
%   upath   = get(url, 'Path');
%   udir    = get(url, 'Dir');
%   ufile   = get(url, 'File');
%   uquery  = get(url, 'Query');
%   ufrag   = get(url, 'Fragment');
%   urlstr  = toString(url);

% CVSId = '$Id: url.m,v 1.10 2005/06/08 16:00:31 gadde Exp $';
% CVSRevision = '$Revision: 1.10 $';
% CVSDate = '$Date: 2005/06/08 16:00:31 $';
% CVSRCSFile = '$RCSfile: url.m,v $';

error(nargchk(0,2,nargin));

url = struct([]);
url(1).scheme = [];
url.user = [];
url.host = [];
url.port = -1;
url.path = [];
url.query = [];
url.frag = [];
url = class(url, 'url');

if nargin == 0
  return;
end

if isa(varargin{1}, 'url')
  if nargin ~= 1
    error('Only one argument allowed for copy constructor');
  end
  inurl = varargin{1};
  url.scheme = inurl.scheme;
  url.user = inurl.user;
  url.host = inurl.host;
  url.port = inurl.port;
  url.path = inurl.path;
  url.query = inurl.query;
  url.frag = inurl.frag;
  return;
end

if ~ischar(varargin{1})
  error('Argument 1 must be URL or string');
end

baseurl = [];
if nargin == 2
  if ischar(varargin{2})
    baseurl = url(varargin{2});
  elseif ~isa(varargin{2}, 'url')
    error('Argument 2 (base url) must be URL or string');
  else
    baseurl = varargin{2};
  end
end

urlstr = varargin{1};
maxind = length(urlstr);
curind = 1;

colons = findstr(urlstr(curind:end), ':');
if ~isempty(colons)
  if isempty(findstr(urlstr(1:colons(1)), '/'))
    url.scheme = urlstr(1:colons(1)-1);
    curind = colons(1)+1;
    if ~isempty(baseurl)
      bscheme = baseurl.scheme;
      if strcmp(url.scheme, bscheme)
        % See RFC2396 5.2(3)
        url.scheme = [];
      end
    end
  end
end

if ~isempty(url.scheme)
  if ~any(strmatch(url.scheme, ['http'; 'ftp '; 'file'; 'srb '], 'exact'))
    error(sprintf('URL scheme "%s" not supported', url.scheme));
  end
end

if curind + 1 <= maxind & urlstr(curind) == '/' & urlstr(curind+1) == '/'
  curind = curind + 2;
  cursor = curind;
  while curind <= maxind & urlstr(curind) ~= '/' & urlstr(curind) ~= '?'
    curind = curind + 1;
  end
  auth = urlstr(cursor:curind-1);
  atsigns = findstr(auth, '@');
  colons = findstr(auth, ':');
  if length(atsigns) > 1 | length(colons) > 1
    error(sprintf('Bad authority component in URL "%s"', urlstr));
  end
  if isempty(atsigns)
    atsigns = 0;
  else
    url.user = auth(1:atsigns-1)
  end
  if isempty(colons)
    colons = length(auth) + 1;
  else
    url.port = str2num(auth(colons+1:end));
  end
  url.host = auth(atsigns+1:colons-1);
  if isempty(url.host)
    url.host = '';
  end
end

url.path = urlstr(curind:end);
if isempty(url.path)
  url.path = [];
end
inds = findstr(url.path, '#');
if ~isempty(inds)
  url.frag = url.path(inds(1)+1:end);
  url.path = url.path(1:inds(1)-1);
end
inds = findstr(url.path, '?');
if ~isempty(inds)
  url.query = url.path(inds(1)+1:end);
  url.path = url.path(1:inds(1)-1);
end

if isempty(url.path) & ~ischar(url.scheme) & ~ischar(url.host) & ~ischar(url.query)
  query = url.query;
  frag = url.frag;
  if isempty(baseurl)
    error('Relative URLs can''t be interpreted without a base URL');
  end
  url = baseurl;
  if ischar(query)
    url.query = query;
  end
  if ischar(frag)
    url.frag = frag;
  end
  return;
end

if ~ischar(url.scheme)
  if isempty(baseurl)
    error('Relative URLs can''t be interpreted without a base URL');
  end
  url.scheme = baseurl.scheme;
  if ~ischar(url.host)
    url.user = baseurl.user;
    url.host = baseurl.host;
    url.port = baseurl.port;
    if urlstr(curind) ~= '/'
      % relative path
      url.path = [get(baseurl,'Dir') url.path];
      segs = splitstr(url.path, '/');
      if ~isempty(segs{1})
        error(sprintf('Path "%s" does not start with slash?', url.path));
      end
      removeinds = strmatch('.', segs, 'exact');
      if ~isempty(removeinds)
        removelast = 0;
        if ismember(length(segs), removeinds)
          removelast = 1;
        end
        removeinds = setdiff(removeinds, [1 length(segs)]); % ignore dot as first or last component
        segs = {segs{setdiff(1:length(segs), removeinds)}};
        % deal with last component
        if removelast
          % this keeps the slash at the end
          segs{end} = '';
        end
      end
      while 1
        removeinds = strmatch('..', segs, 'exact');
        if isempty(removeinds), break; end
        removeinds = reshape(removeinds, 1, length(removeinds));
        % get rid of matched indexes which immediately follow another match
        putbackinds = removeinds(find(diff([-1 removeinds]) == 1));
        removeinds = [setdiff(removeinds, putbackinds)];
        removelast = 0;
        if ismember(length(segs), removeinds)
          removelast = 1;
        end
        removeinds = setdiff(removeinds, [1 2 length(segs)]); % ignore first 2 components and last
        segs = {segs{setdiff(1:length(segs), union(removeinds, removeinds-1))}};
        if removelast
          segs = {segs{1:end-2}, ''};
        end
      end
      if strcmp(segs{2}, '..')
        error(sprintf('Too many "../" components in path of URL "%s"', urlstr));
      end
      lastseg = segs{end};
      segs = strcat(segs, '/');
      segs{end} = lastseg;
      url.path = [segs{:}];
    end
  end
end

return

% $Log: url.m,v $
% Revision 1.10  2005/06/08 16:00:31  gadde
% Revert slash conversion -- do it in readmr.
%
% Revision 1.9  2005/06/08 14:42:06  gadde
% Convert input backslashes ('\') into foreslashes ('/').
%
% Revision 1.8  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.7  2004/05/06 14:47:10  gadde
% Replace all uses of strfind with findstr (strfind doesn't exist before
% Matlab 6.1).
%
% Revision 1.6  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.5  2003/06/30 22:22:41  michelich
% Use character array in strmatch for better performance.
%
% Revision 1.4  2003/06/16 17:28:17  gadde
% Change URL to lowercase (to avoid problems on Win32 Matlab).
%
% Revision 1.3  2003/03/26 19:59:54  gadde
% Force exact matching of schemes (not just prefixes)
%
% Revision 1.2  2003/03/20 19:56:05  gadde
% Only allow certain schemes (http, ftp, file, srb)
%
% Revision 1.1  2003/03/20 16:58:22  gadde
% *** empty log message ***
%
