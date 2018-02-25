function newURL=filename2url(fileorurl,base)
%FILENAME2URL - get valid URL from rel. or abs. filename or URI
%
% urlobj = filename2url(fileOrURL);
% urlobj = filename2url(fileOrURL, baseFileOrURL);
%
%   Use this function to get a new URL object that describes the
%   relative or absolute location described by 'fileOrURL'.  If
%   'baseFileOrURL' is given, that will also be converted (if
%   needed) to a URL, and will then be used as the base for
%   'fileOrURL' if it is a relative pathname or URL.

% CVSId = '$Id: filename2url.m,v 1.22 2005/02/03 16:58:33 michelich Exp $';
% CVSRevision = '$Revision: 1.22 $';
% CVSDate = '$Date: 2005/02/03 16:58:33 $';
% CVSRCSFile = '$RCSfile: filename2url.m,v $';

error(nargchk(1,2,nargin));

myfilesep = filesep;

if nargin == 1
  base = '';
end

% see if it's already a valid fully-qualified URL
newURL = isfqurl(fileorurl);
if ~isempty(newURL)
  return
end
newURL = '';

[inproto, inhost, inport, indir, infile] = breakfileorurl(fileorurl);
[defdir, deffile, defext, defvers] = fileparts([pwd filesep]);
if ~isempty(base)
  [baseproto, basehost, baseport, basedir, basefile] = breakfileorurl(base);
  if isempty(baseproto)
    baseproto = 'file';
  end
  if ~(strcmp(baseproto, 'file') | strcmp(baseproto, 'srb')) & ...
        isempty(basehost)
    emsg = sprintf('Base non-file URLs ("%s") must have a host!', base); error(emsg);
  end
  if isempty(basedir)
    if strcmp(baseproto, 'file') | strcmp(baseproto, 'srb')
      basedir = [defdir filesep];
    elseif ~isempty(basehost)
      basedir = '/';
    end
  end
elseif isempty(inproto) | strcmp('file', inproto)
  baseproto = 'file';
  basehost = '';
  baseport = -1;
  basedir = [defdir filesep];
  basefile = deffile;
else
  emsg = sprintf('File or URL "%s" is relative, but no base specified!', fileorurl); error(emsg);
end

if isempty(inproto)
  inproto = baseproto;
end

if ~strcmp(baseproto, inproto)
  % we have a "relative" input file name, but don't have a base to
  % make it fully-qualified.
  emsg = sprintf('Can''t make fully-qualified name from file "%s" and base "%s"', fileorurl, base); error(emsg);
end

% if non-file, then copy host if needed.
% also do this if proto is file, but base is UNC and input file is relative.
if ~strcmp('file', inproto) | isempty(indir) | isrelpath(indir)
  if isempty(inhost) & ~isempty(basehost)
    inhost = basehost;
    if inport == -1 & baseport ~= -1
      inport = baseport;
    end
  end
end

if isempty(indir) | ...
      (~strcmp('file', inproto) & indir(1) ~= '/') | ...
      (strcmp('file', inproto) & isrelpath(indir) == 1)
  % directory is relative -- make it absolute
  indir = [ basedir indir ];
end

if strcmp('file', inproto)
  % file URL
  if ~isempty(inhost)
    % UNC path
    newURL = url(['file:/\\' inhost indir infile ]);
  else
    if filesep == '/'
      newURL = url(['file:' indir infile]);
    else
      newURL = url(['file:/' indir infile]);
    end
  end
else
  % network URL
  if isempty(indir), indir = '/'; end
  if inport == -1
    newURL = url([inproto '://' inhost indir infile]);
  else
    newURL = url([inproto '://' inhost ':' inport indir infile]);
  end
end

return

function outurl=isfqurl(str)
%ISFQURL - convert string to URL object if valid fully-qualified URL, otherwise return ''
try
  outurl = url(str);
  proto = get(outurl, 'Scheme');
  path = get(outurl, 'Path');
  if strcmp('file', proto) & ~isrelpath(path)
    return
  elseif ~strcmp('file', proto) & (isempty(path) | strncmp('/', path, 1))
    return
  end
  outurl = '';
catch
  outurl = '';
end
return

function [proto, host, port, bdir, file] = breakfileorurl(fileorurl)
%BREAKFILEORURL - break filename or URL into parts
%
%   [proto, host, port, bdir, file] = breakfileorurl(fileorurl);

proto = '';
host = '';
port = -1;
bdir = '';
file = '';

% bdir + file
path = '';

myispc = ~isunix;

tryurl = '';
if isa(fileorurl, 'url')
  tryurl = fileorurl;
else
  try tryurl = url(fileorurl);
  catch tryurl = ''; end
  if ~isempty(tryurl) & myispc & strncmp(fileorurl, 'file:/', 6)
    % Windows path inside URL -- Java does not do what we want
    tryurl = '';
    fileorurl = fileorurl(7:end);
  end
end

if ~isempty(tryurl)
  proto = get(tryurl, 'Scheme');
  host = get(tryurl, 'Host');
  port = get(tryurl, 'Port');
  path = get(tryurl, 'Path');
end

if isempty(proto) | strcmp('file', proto)
  % it's a file
  if isempty(path)
    path = fileorurl;
  end
  host = '';
  port = -1;
  if path(1) == '/' | ~isrelpath(path)
    % fileorurl is absolute file -- check for UNC path
    if myispc & ...
          ((length(path) > 1 & strncmp(path, '\\', 2)) | ...
           (strcmp('file', proto) & length(path) > 2 & ...
            strncmp(path, '/\\', 3)))
      % UNC path on Windows -- fileorurl was one of the following:
      %  \\host\share
      %  file:\\host\share
      %  file:/\\host\share
      seps = findstr(path, '\');
      if length(seps) < 3
        emsg = sprintf('UNC path "%s" is malformed?', path); error(emsg);
      end
      host = path(seps(2)+1:seps(3)-1);
      path = path(seps(3):end);
    elseif myispc & length(path) > 3 & path(1) == '/' & path(3) == ':' & ...
          ~isrelpath(path(2:end))
      % drive letter path on windows with preceding slash -- get rid of it
      path = path(2:end);
    end
  end
  slashdirend = max(findstr(path, '/'));
  if myispc, backslashdirend = max(findstr(path, '\'));
  else backslashdirend = '';
  end
  if isempty(backslashdirend), dirend = slashdirend;
  elseif isempty(slashdirend), dirend = backslashdirend;
  else dirend = max(slashdirend, backslashdirend);
  end
  if isempty(dirend)
    bdir = '';
    file = path;
  else
    bdir = path(1:dirend);
    if length(path) > dirend
      file = path(dirend+1:end);
    else
      file = '';
    end
  end
else
  % not a local file
  host = get(tryurl, 'Host');
  port = get(tryurl, 'Port');
  inds = findstr(path, '/');
  qinds = findstr(path, '?');
  if ~isempty(qinds)
    % only consider those slashes before query
    inds = inds(find(inds < qinds(1)));
  end
  if isempty(inds) | inds(1) ~= 1
    bdir = '';
    file = path;
  else
    bdir = path(1:inds(end));
    if length(path) > inds(end)
      file = path(inds(end)+1:end);
    else
      file = ''
    end
  end
end

% Modification History:
%
% $Log: filename2url.m,v $
% Revision 1.22  2005/02/03 16:58:33  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.21  2004/05/06 15:15:27  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.20  2003/11/16 16:53:01  gadde
% Fix relative path calculation.
%
% Revision 1.19  2003/10/22 15:54:35  gadde
% Make some CVS info accessible through variables
%
% Revision 1.18  2003/10/14 14:58:53  gadde
% Name change: geturlfromfile => filename2url
%
% Revision 1.17  2003/07/02 20:37:32  gadde
% Fix some UNC path bugs
%
% Revision 1.16  2003/06/16 17:32:42  gadde
% Change 'url' variable name to not conflict with classname
%
% Revision 1.15  2003/06/16 17:28:37  gadde
% Change URL to lowercase (to avoid problems on Win32 Matlab).
%
% Revision 1.14  2003/03/26 17:01:31  gadde
% Fix path calculation of drive letter paths on Windows that are
% encapsulated in file:/
%
% Revision 1.13  2003/03/25 15:12:36  gadde
% Make sure breakfileorurl works if you pass it a URL.
%
% Revision 1.12  2003/03/20 19:28:09  gadde
% Fix old URL vestiges
%
% Revision 1.11  2003/03/20 16:58:05  gadde
% Big commit:
%   * introduction of new URL class to replace java.net.URL
%   * old-style readmr() arguments supported
%   * many, many performance enhancements
%   * 'NOPROGRESSBAR' can now be last argument of readmrtest()
%   * readtsv() uses readmrtest()
%
% Revision 1.10  2003/03/14 20:26:37  gadde
% Get rid of extraneous toString calls.
%
% Revision 1.9  2003/02/11 16:41:06  gadde
% Fix absolute "drive letter" paths for Matlab 6.5 on Windows.
%
% Revision 1.8  2003/02/11 16:25:32  gadde
% Fix UNC paths for Matlab 6.5 on Windows.
%
% Revision 1.7  2003/01/21 21:43:41  gadde
% SRB URLs do not need hosts.
%
% Revision 1.6  2003/01/14 21:04:24  gadde
% UNC paths again, argh.
%
% Revision 1.5  2003/01/10 22:44:37  gadde
% Make relative paths work?
%
% Revision 1.4  2003/01/10 22:07:05  Administrator
% Random small fixes.  Generic random comment.
%
% Revision 1.3  2003/01/10 15:32:00  gadde
% Changed logical operators from short-circuit to element-wise
%
% Revision 1.2  2003/01/09 20:25:04  gadde
% OK, let's rewrite this.  Don't depend on java.net.URL for anything
% except the end result.
%
% Revision 1.1  2003/01/08 16:57:25  gadde
% Changed from geturifromfile, get rid of middleman and just return URL object.
%
% Revision 1.5  2002/11/08 15:59:37  gadde
% Fixed relative pathname bug?
%
% Revision 1.4  2002/10/09 00:21:28  michelich
% Removed extra carriage return from end of each line.
% Added CVS id & log.
%
