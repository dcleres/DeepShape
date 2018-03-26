function [retvals,messages]=grablocation(method,URIs,base,methodargs)
%GRABLOCATION Return file ids or local filenames corresponding to given URI(s)
%
%   [retvals,messages]=grablocation(method,URIs);
%   [retvals,messages]=grablocation(method,URIs,base);
%   [retvals,messages]=grablocation(method,URIs,base,methodargs);
%
%   method is either 'load' or 'fopen'.
%   URIs is a single URI (Uniform Resource Identifier) or a cell array of URIs
%   base is a string specifying the base URI for relative URIs
%     (default = current directory)
%     base may also be relative to current directory
%   methodargs are specific to the method:
%     'fopen': cell array of additional arguments to fopen
%   retvals will contain either a number or a string, or a cell array
%     of numbers or strings, one for each URI, depending on the method
%     ('fopen' will return file identifiers, 'load' will return filenames)
%     If there is an error, the return value will be -1 for 'fopen' and
%     '' for 'load'.
%   messages is a cell array of error messages for each URI.  A cells will be
%     an empty string if there was not an error for that URI.
%
%   Note: most users will want to use fopenlocation or loadlocation instead.
%
%   GRABLOCATION "grabs" one or more URIs (Uniform Resource Identifiers).
%
%   If the method is 'load', the data corresponding to the URI(s) are copied
%   or downloaded to temporary file(s), and the name of the file(s) are
%   returned.  It is the caller's responsibility to delete the temporary file.
%
%   If the method is 'fopen', remote files are downloaded, opened, and marked
%   for deletion on close; local files are merely opened.  A file identifier
%   is returned for each URI.
%
%   See Also: FOPENLOCATION, LOADLOCATION

% CVS ID and authorship of this code
% CVSId = '$Id: grablocation.m,v 1.22 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.22 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: grablocation.m,v $';

% Handle input arguments
error(nargchk(2,4,nargin));

% Defaults
if nargin < 4, methodargs = {}; end
if nargin < 3, base = ''; end

% Check inputs
if ~ischar(URIs) & ~isa(URIs, 'url') & ~iscell(URIs), error('URIs must be a string or a cell array of strings or URL objects!'); end
if ~iscell(methodargs), error('methodargs must be a cell array of strings!'); end
if ~ischar(base) & ~isa(base, 'url'), error('base must be a string or URL object!'); end
if ~strcmp(method,'load') & ~strcmp(method,'fopen')
  error(sprintf('Method "%s" not supported', method));
end

% Put a single URI into a cell array for uniform handling
if ~iscell(URIs), URIs={URIs}; end

% Initialize output arrays
retvals = cell(length(URIs),1);
messages = cell(length(URIs),1);

% Handle each URI
for uriNum = 1:length(URIs)
  emsg='';
  tempfilename='';  % Initialize to empty.  This file is deleted automatically by catch.
  try
    % Use try-catch block to handle setting output arguments and continue
    % through the URIs in the case of an error.
    
    % Determine current URL 
    % (If a protocol is specified by URIs{uriNum}, then the base will be ignored)
    curfile = URIs{uriNum};
    if ~isa(curfile, 'url') & ~isempty(base)
      curfile = filename2url(curfile, base);
    end
    if isa(curfile, 'url')
      proto = get(curfile, 'Scheme');
      if strcmp(proto, 'file')
        curfile = get(curfile, 'Path');
      end
    end
    if ~isa(curfile, 'url')
      % Local file, get location (translating file separators properly)
      filepath = curfile;
      % java.net.URL keeps '/' as part of all non-relative paths
      if filepath(1) == '/' & ~strcmp(filesep, '/') % get rid of it on Windows
        filepath = filepath(2:length(filepath));
      end
      % opening locally, so replace standard file separators with local ones
      if ~strcmp(filesep,'/')
        filepath = strrep(filepath, '/', filesep);
      end

      % Check that file exists
      if ~exist(filepath,'file')
        emsg=sprintf('The file "%s" does not exist!',filepath); error(emsg);
      end

      % Open the file
      if strcmp(method,'fopen')
        [retvals{uriNum},messages{uriNum}] = fopen(filepath, methodargs{:});
      elseif strcmp(method,'load')
        tempfilename = getvalidtempfile;
        [success,message]=copyfile(filepath, tempfilename);
        if ~success, emsg=message; error(emsg); end

        % Success, return temporary file
        retvals{uriNum}=tempfilename;
        messages{uriNum}='';
      end
    else
      % Remote file, download and open the file using Java
      % Check that whollyInputStream class is available
      proto = get(curfile, 'Scheme');
      
      if ~exist('edu/duke/biac/whollyInputStream','class')
        emsg=sprintf('Can''t find edu.duke.biac.whollyInputStream.class\nTo open URLs, you need to compile this class\nand add the directory to the MATLAB classpath.');
        error(emsg);
      end
      
      is = openStream(java.net.URL(toString(curfile)));
      
      tempfilename = getvalidtempfile;
      fid = fopen(tempfilename, 'w');
      
      % whollyInputStream allows us to read in chunks rather than bytes
      % (matlab doesn't pass byte arrays by reference, which is how all
      %  standard bulk transfer methods in Java I/O classes work)
      if strcmp(proto, 'srb')
        bufsize = 1048576;
      else
        bufsize = 32768;
      end
      hr = edu.duke.biac.whollyInputStream(is);
      buf = readBuf(hr,bufsize);
      while length(buf) > 0
        bytesread = length(buf);
        byteswritten = fwrite(fid, buf, 'int8');
        if byteswritten ~= bytesread
          emsg = sprintf('grablocation: error while writing to file %s (wrote %d out of %d bytes)', tempfilename, byteswritten, bytesread);
          error(emsg);
        end
        buf = readBuf(hr,bufsize);
      end
      
      close(is);
      fclose(fid);
      if strcmp(method,'fopen')
        temphandle=deleteoncloseacq(tempfilename);
        retvals{uriNum} = fopen(tempfilename, methodargs{:});
        deleteoncloserel(temphandle);
      elseif strcmp(method,'load')
        retvals{uriNum} = tempfilename;
      end
    end
  catch
    % Set return value to failure for each method
    if strcmp(method,'fopen'), 
      retvals{uriNum}=-1;
    elseif strcmp(method,'load'), 
      retvals{uriNum}='';
    end
    
    % Set messages to current error message
    if isempty(emsg)
      if isempty(lasterr)
        emsg='An unidentified error occurred!';
      else
        emsg=lasterr;
      end
    end
    messages{uriNum}=emsg;
    
    % Delete temporary file if it was created.
    if exist(tempfilename,'file')
      delete(tempfilename); 
    end
  end % End try-catch
end % End of loop through URIs

% END GRABLOCATION
%%%

function tempfilename=getvalidtempfile
% GETVALIDTEMPFILE - Get a non-existent temporary filename
tempfilename = '';
while strcmp(tempfilename,'')
  trythis = tempname;
  fid = fopen(trythis);
  if fid == -1
    % make sure it's not a directory
    if ~exist(trythis,'dir')
      tempfilename = trythis;
    end
  else
    fclose(fid);
  end
end


% Modification History:
%
% $Log: grablocation.m,v $
% Revision 1.22  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.21  2004/02/23 18:18:45  michelich
% Use exist for directory existance check.
%
% Revision 1.20  2004/02/23 14:55:16  gadde
% Make sure temp file is not a directory.
%
% Revision 1.19  2003/10/22 15:54:35  gadde
% Make some CVS info accessible through variables
%
% Revision 1.18  2003/10/14 14:58:53  gadde
% Name change: geturlfromfile => filename2url
%
% Revision 1.17  2003/07/16 14:54:41  gadde
% Oops, errant ~.
%
% Revision 1.16  2003/06/16 17:28:59  gadde
% Change URL to lowercase (to avoid problems on Win32 Matlab).
%
% Revision 1.15  2003/06/13 15:30:22  gadde
% Use base URL in all cases if not empty.
%
% Revision 1.14  2003/03/25 15:15:35  gadde
% Make sure relative filenames are interpreted within context of base.
%
% Revision 1.13  2003/03/20 16:58:05  gadde
% Big commit:
%   * introduction of new URL class to replace java.net.URL
%   * old-style readmr() arguments supported
%   * many, many performance enhancements
%   * 'NOPROGRESSBAR' can now be last argument of readmrtest()
%   * readtsv() uses readmrtest()
%
% Revision 1.12  2003/03/14 19:59:23  gadde
% Cut down extra opaque/char calls.
%
% Revision 1.11  2003/03/14 19:36:39  gadde
% Accept java.net.URLs as input.
%
% Revision 1.10  2003/01/10 15:32:00  gadde
% Changed logical operators from short-circuit to element-wise
%
% Revision 1.9  2003/01/09 20:25:38  gadde
% *** empty log message ***
%
% Revision 1.8  2003/01/08 17:27:07  gadde
% New method for deleteonclose -- still doesn't work on Windows yet :(
%
% Revision 1.7  2002/12/10 15:37:16  michelich
% Catch errors and return the error messages in an output argument.
% Added exist check for location files and error checking on copyfile.
%
% Revision 1.6  2002/10/07 20:44:37  gadde
% Got rid of special-case SRB support, and now depend on SRB support
% using the classes in the edu.duke.biac.srb package.
%
% Revision 1.5  2002/10/04 20:47:35  gadde
% First checkin of SRB support
%
% Revision 1.4  2002/10/03 14:26:04  gadde
% grablocation always returns cell array
%
% Revision 1.3  2002/10/02 22:15:51  michelich
% Corrected URL variable name.
%
% Revision 1.2  2002/10/02 21:24:41  gadde
% Get rid of tabs
%
% Revision 1.1  2002/10/02 21:04:16  gadde
% Consolidated common code from fopenlocation and loadlocation into grablocation.
%
