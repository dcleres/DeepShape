function [filenames,messages]=loadlocation(URIs,base)
%LOADLOCATION Return local filename corresponding to given URI(s)
%
%   [filenames,messages]=loadlocation(URIs);
%   [filenames,messages]=loadlocation(URIs,base);
%
%   URIs is a single URI (Uniform Resource Identifier) or a cell array of URIs
%   base is a string specifying the base URI for relative URIs
%     (default = current directory)
%     base may also be relative to current directory
%   filenames is a filename or cell array of filenames for each element in URIs
%     If there was an error loading a URIs that filename will be ''
%   messages is error message or cell array of error messages for each URI. 
%     messages will be empty strings if there was not an error.
%
%   LOADLOCATION takes one or more URIs (Uniform Resource Identifiers)
%     and, for each, returns the name of a (newly created) local
%     file that contains the same data pointed to by the URI.
%
%   If the URI is local (e.g. starts with 'file:'), the file is copied
%     to a new file, and the name of the new file is returned.
%
%   If the URI is remote, the data is stored in a temporary local file
%     and the name of that file is returned.
%
%   It is the caller's responsibility to delete the temporary file.
%
%   See Also: FOPENLOCATION

% CVS ID and authorship of this code
% CVSId = '$Id: loadlocation.m,v 1.12 2005/02/03 16:58:34 michelich Exp $';
% CVSRevision = '$Revision: 1.12 $';
% CVSDate = '$Date: 2005/02/03 16:58:34 $';
% CVSRCSFile = '$RCSfile: loadlocation.m,v $';

% Handle input arguments
error(nargchk(1,2,nargin));

% Default arguments
if nargin < 2, base = ''; end

% Check inputs
if ~ischar(URIs) & ~isa(URIs, 'url') & ~iscell(URIs), error('URIs must be a string or a cell array of strings or url objects!'); end
if ~ischar(base) & ~isa(base, 'url'), error('base must be a string or url object!'); end

[filenames,messages] = grablocation('load', URIs, base);

% Pull single value out of returned cell array
if length(filenames) == 1, filenames=filenames{1}; end
if length(messages)==1, messages=messages{1}; end

% Modification History:
%
% $Log: loadlocation.m,v $
% Revision 1.12  2005/02/03 16:58:34  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.11  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.10  2003/06/16 17:29:07  gadde
% Change URL to lowercase (to avoid problems on Win32 Matlab).
%
% Revision 1.9  2003/04/15 16:15:38  gadde
% Oops, allow URL.
%
% Revision 1.8  2003/03/20 16:58:05  gadde
% Big commit:
%   * introduction of new URL class to replace java.net.URL
%   * old-style readmr() arguments supported
%   * many, many performance enhancements
%   * 'NOPROGRESSBAR' can now be last argument of readmrtest()
%   * readtsv() uses readmrtest()
%
% Revision 1.7  2003/03/14 19:36:53  gadde
% Accept java.net.URLs as input
%
% Revision 1.6  2002/12/10 15:38:05  michelich
% Added returning error messages as supported by grablocation.
%
% Revision 1.5  2002/10/03 14:25:45  gadde
% grablocation always returns cell array
%
% Revision 1.4  2002/10/02 21:04:31  gadde
% Consolidated common code from fopenlocation and loadlocation into grablocation.
%
% Revision 1.3  2002/10/02 14:37:31  michelich
% Return filename as a string if there is only one URI.
%
% Revision 1.2  2002/10/01 16:37:45  michelich
% Changed syntax to pass URIs as a cell array rather than a list of arguments.
% Added comments and updated help.
% Added CVS Id and Log
%
