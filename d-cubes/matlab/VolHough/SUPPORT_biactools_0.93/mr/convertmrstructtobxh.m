function newmrstruct = convertmrstructtobxh(mrstruct)
% CONVERTMRSTRUCTTOBXH -- Take an mr struct and convert what we can to BXH
%
%   newmrstruct = convertmrstructtobxh(mrstruct);
%
% This function converts an mrstruct to the BXH format.  Note that
% the original headers of the input data (if any) are NOT preserved
% in the conversion, and only some of this info will be extracted
% into the BXH header.

% CVSId = '$Id: convertmrstructtobxh.m,v 1.7 2005/02/03 16:58:38 michelich Exp $';
% CVSRevision = '$Revision: 1.7 $';
% CVSDate = '$Date: 2005/02/03 16:58:38 $';
% CVSRCSFile = '$RCSfile: convertmrstructtobxh.m,v $';


if strcmp(mrstruct.info.hdrtype, 'BXH')
  newmrstruct = mrstruct;
  return
end

% This is a basic, empty BXH file
newmrstruct = mrstruct;
newmrstruct.info.hdrtype = 'BXH';
newmrstruct.info.hdr = [];
newmrstruct.info.hdr.COMMENTS(1).VALUE = ' This is a BXH (BIAC XML Header) file. ';
newmrstruct.info.hdr.bxh{1}.ATTRS.version.VALUE = '1.0';
newmrstruct.info.hdr.bxh{1}.NAMESPACE = 'http://www.biac.duke.edu/bxh';
newmrstruct.info.hdr.bxh{1}.NSDEFS.DEFAULT = 'http://www.biac.duke.edu/bxh';
newmrstruct.info.hdr.bxh{1}.NSDEFS.bxh = 'http://www.biac.duke.edu/bxh';

% $Log: convertmrstructtobxh.m,v $
% Revision 1.7  2005/02/03 16:58:38  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.6  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.5  2003/07/02 16:49:25  gadde
% Keep everything except hdr in newmrstruct.
%
% Revision 1.4  2003/04/18 16:34:25  gadde
% New COMMENT structure.
%
% Revision 1.3  2003/04/01 19:01:04  gadde
% Make this work.
%
