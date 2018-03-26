function [fids,messages]=fopenlocation(URIs,fopenargs,base)
%FOPENLOCATION Return open file identifiers corresponding to given URI(s)
%
%   [fids,messages] = fopenlocation(URIs);
%   [fids,messages] = fopenlocation(URIs,fopenargs);
%   [fids,messages] = fopenlocation(URIs,fopenargs,base);
%
%   URIs is a single URI (Uniform Resource Identifier) or a cell array of URIs
%   fopenargs is a cell array of arguments to pass to fopen (default = {})
%   base is a string specifying the base URI for relative URIs 
%     (default = current directory)
%   fids is a vector of MATLAB file identifiers for each element in URIs
%     fid will be -1 if there was an error.
%   messages is error message or cell array of error messages for each URI. 
%     messages will be empty strings if there was not an error.
%
%   FOPENLOCATION takes one or more URI (Uniform Resource Identifiers)
%     and, for each, returns an open file identifier pointing to a local
%     file that contains the same data pointed to by the URI.
%
%   If the URI is local (e.g. starts with 'file:', or is relative and
%     the base URI starts with 'file:') this is equivalent to an FOPEN
%     on that file.
%
%   If the URI is remote, the data is stored in a temporary local file
%     and the result of an FOPEN on that file is returned.  Any temporary
%     file created will be deleted when the file is closed.
%
%   See Also: FOPEN, LOADLOCATION

% CVS ID and authorship of this code
% CVSId = '$Id: fopenlocation.m,v 1.11 2005/02/03 16:58:33 michelich Exp $';
% CVSRevision = '$Revision: 1.11 $';
% CVSDate = '$Date: 2005/02/03 16:58:33 $';
% CVSRCSFile = '$RCSfile: fopenlocation.m,v $';

% Handle input arguments
error(nargchk(1,3,nargin));

% Default arguments
if nargin < 2, fopenargs = {}; end
if nargin < 3, base = ''; end

% Check inputs
if ~ischar(URIs) & ~isa(URIs, 'url') & ~iscell(URIs), error('URIs must be a string, a url object, or a cell array of strings or url objects!'); end
if ~iscellstr(fopenargs), error('fopenargs must be a cell array of strings!'); end
if ~ischar(base) & ~isa(base, 'url'), error('base must be a string or url object!'); end

[fids,messages] = grablocation('fopen', URIs, base, fopenargs);

% grablocation returns cell array, we return scalar array
fids = [ fids{:} ];
if length(messages)==1, messages=messages{1}; end

% Modification History:
%
% $Log: fopenlocation.m,v $
% Revision 1.11  2005/02/03 16:58:33  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.10  2003/10/22 15:54:35  gadde
% Make some CVS info accessible through variables
%
% Revision 1.9  2003/06/16 17:29:03  gadde
% Change URL to lowercase (to avoid problems on Win32 Matlab).
%
% Revision 1.8  2003/03/20 16:58:05  gadde
% Big commit:
%   * introduction of new URL class to replace java.net.URL
%   * old-style readmr() arguments supported
%   * many, many performance enhancements
%   * 'NOPROGRESSBAR' can now be last argument of readmrtest()
%   * readtsv() uses readmrtest()
%
% Revision 1.7  2003/03/14 19:37:01  gadde
% Accept java.net.URLs as input.
%
% Revision 1.6  2002/12/10 15:38:05  michelich
% Added returning error messages as supported by grablocation.
%
% Revision 1.5  2002/10/02 21:46:47  gadde
% grablocation always returns cell array
%
% Revision 1.4  2002/10/02 21:04:21  gadde
% Consolidated common code from fopenlocation and loadlocation into grablocation.
%
% Revision 1.3  2002/10/02 00:58:29  gadde
% Fixed a relative baseURL bug/feature.
%
% Revision 1.2  2002/10/01 16:48:11  michelich
% Changed syntax to pass URIs as a cell array rather than a list of arguments.
% Changed syntax to pass base and fopenargs as separate arguments.
% Changed syntax to return fids in a single variable.
% If base specified, construct baseURL using only base (not current directory).
% Fixed exist check for whollyInputStream java class.
% Added comments and updated help.
% Added CVS Id and Log.
%
