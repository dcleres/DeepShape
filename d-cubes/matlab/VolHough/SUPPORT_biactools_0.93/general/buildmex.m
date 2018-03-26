function buildmex(externPath,libxml2VerWin32,iconvVerWin32)
% buildmex - Build MEX files for BIAC General Toolbox
%
% Build MEX files for BIAC General Toolbox
%
%   buildmex(externPath,libxml2VersionWin32,iconvVerWin32)
%     externPath - Path to external files (libraries & headers)
%          Windows Default: \\Gall\Source\external\win32\
%          UNIX Default:    /usr/
%          empty uses default
%     libxml2VerWin32 - libxml2 version to link to on Windows
%          Default = 2.5.10, empty uses default
%     iconvVerWin32 - iconv version to link to on Windows
%          Default = 1.9.1, empty uses default
%
%   Required external libraries:
%     - libxml2 (readxml, writexml)
%     - iconv (readxml, writexml) - Only necessary for Windows
%
% See Also: MEX

% CVS ID and authorship of this code
% CVSId = '$Id: buildmex.m,v 1.27 2005/02/22 20:18:24 michelich Exp $';
% CVSRevision = '$Revision: 1.27 $';
% CVSDate = '$Date: 2005/02/22 20:18:24 $';
% CVSRCSFile = '$RCSfile: buildmex.m,v $';

%TODO: Figure out better implementation for include & library directories
%TODO: Decide how to handle mex files for different MATLAB versions

% Set default paths to external files
if nargin<1 | isempty(externPath)
  if isunix
    externPath = '/usr/';
  else
    externPath = '\\Gall\Source\external\win32\';
  end
end
if nargin<2	| isempty(libxml2VerWin32)
  libxml2VerWin32 = '2.5.10';
end
if nargin<3	| isempty(iconvVerWin32)
  iconvVerWin32 = '1.9.1';
end

% Compile from the location of the buildmex file
origpwd=pwd;
cd(fileparts(which(mfilename)));

try % try-catch to put you back in your original directory on errors
  
  % Standard options should be fine
  for n={'minmax.c','scaled2rgb.c','trilinear.c'}
    disp(sprintf('Building %s',n{1}));
    mex(n{1});
  end
  
%  disp('Building cellfun2.c');
%  [majorVer, minorVer] = strtok(strtok(version),'.');
%  majorVer = str2double(majorVer);
%  minorVer = str2double(strtok(minorVer,'.'));
%  if majorVer < 6 | (majorVer == 6 & minorVer < 5)
%    % Need to built with no logical type support before MATLAB 6.5
%    mex -DNO_LOGICAL_TYPE -output cellfun2NLT cellfun2.c
%  else
%    mex -output cellfun2LT cellfun2.c
%  end
%  clear majorVer minorVer
  
  disp('Building readxml.c & writexml.c');
  if isunix
    % UNIX:
    % Include & Link to libxml2
    %   This typically requires libxml2, libz, and libglib
    libxmlIncludeDir = fullfile(externPath,'include','libxml2');
    externLibraryDir= fullfile(externPath,'lib');
    
    canbuild=1;
    for n={libxmlIncludeDir,externLibraryDir}
      if ~exist(n{1},'dir')
        warning(sprintf('Missing %s.  Cannot build readxml or writexml!',n{1}));
        canbuild=0;
      end
    end
    
    if canbuild
      mex(['-I',libxmlIncludeDir],['-L',externLibraryDir],'-lxml2','readxml.c');
      mex(['-I',libxmlIncludeDir],['-L',externLibraryDir],'-lxml2','writexml.c');
    end
  else
    % Windows:
    % Include libxml2 & iconv includes
    % Link to libxml2 (libxml2.dll links to iconv.dll)
    libxmlLibrary = fullfile(externPath,['libxml2-',libxml2VerWin32,'.win32'],'lib','libxml2.lib');
    libxmlIncludeDir = fullfile(externPath,['libxml2-',libxml2VerWin32,'.win32'],'include');
    iconvIncludeDir = fullfile(externPath,['iconv-',iconvVerWin32,'.win32'],'include');
    
    canbuild=1;
    for n={libxmlLibrary,libxmlIncludeDir,iconvIncludeDir}
      if ~any(exist(n{1})==[2 7])
        warning(sprintf('Missing %s.  Cannot build readxml or writexml!',n{1}));
        canbuild=0;
      end
    end
    
    if canbuild
      mex(['-I',libxmlIncludeDir],['-I',iconvIncludeDir],'readxml.c',libxmlLibrary);
      mex(['-I',libxmlIncludeDir],['-I',iconvIncludeDir],'writexml.c',libxmlLibrary);
    end
  end
  
  % Only need to build deleteonclose for PC
  if ~isunix
    disp('Building private\deleteonclose.c');
    cd('private')
    mex deleteonclose.c
    cd('..');
  end
  
  % Change back to the original directory
  cd(origpwd);
  
catch
  % Change back to original directory
  cd(origpwd);
  
  % Throw error
  emsg=lasterr;
  if isempty(emsg), emsg='Unknown error occurred!'; end
  error(emsg);
end

% Modification History:
%
% $Log: buildmex.m,v $
% Revision 1.27  2005/02/22 20:18:24  michelich
% Use more robust version parsing code.
%
% Revision 1.26  2005/02/03 16:58:32  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.25  2005/01/07 00:02:44  michelich
% UNIX build: dynamically link to libxml2, libz, libglib like buildmex.sh
%
% Revision 1.24  2004/05/06 16:41:26  michelich
% Swapped order of code to remove negation.
%
% Revision 1.23  2004/05/06 16:34:54  michelich
% Compile cellfun2 with and without logical type support using two different
% output names instead of placing the MEX files into the fix directories.
% Modify cellfun2.m to handle calling the correct MEX file.
%
% Revision 1.22  2004/05/06 15:15:27  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.21  2004/02/12 22:08:40  michelich
% Use libxml version 2.5.10 by default. (2.6.* was not working on WinNT)
% Added iconv version argument.
%
% Revision 1.20  2003/11/20 15:10:10  michelich
% Updated libxml2 to 2.6.2 and iconv to 1.9.1 (newest versions).
%
% Revision 1.19  2003/10/22 15:54:34  gadde
% Make some CVS info accessible through variables
%
% Revision 1.18  2003/10/22 15:31:35  gadde
% Add support for outputselect attribute
%
% Revision 1.17  2003/10/14 21:21:55  michelich
% Build deleteonclose in private subdirectory.
%
% Revision 1.16  2003/10/08 23:09:36  michelich
% Use separate MATLAB 6.0 and 6.1 fix directories.
% Changed default libxml version on Windows to 2.5.10
%
% Revision 1.15  2003/07/22 20:05:19  michelich
% Don't need to link against libz on UNIX.
% Code simplification & comment changes.
%
% Revision 1.14  2003/06/27 18:40:05  gadde
% Not exactly sure what happened, but put back half of Chuck's
% commit that got inadvertently erased.
%
% Revision 1.13  2003/06/26 19:57:07  gadde
% Compile writexml.c instead of writexml.cpp
%
% Revision 1.12  2003/05/16 14:08:16  michelich
% Change default path for external libraries to \\Gall\Source
% Added ability to specify libxml2 version on Windows.
%
% Revision 1.11  2003/04/08 15:50:42  michelich
% Added catch to move back to original directory on error.
%
% Revision 1.10  2003/04/08 14:12:08  michelich
% Use libxml2-2.5.6 on Windows.
%
% Revision 1.9  2003/01/14 15:47:05  michelich
% Added building deleteonclose.c
%
% Revision 1.8  2003/01/14 15:45:34  michelich
% Do not build deleteonclose.c for Version 2.2 since this file is not
%   included in this release.
%
% Revision 1.7  2002/12/17 01:22:03  michelich
% Changed to fully qualified UNC path.
%
% Revision 1.6  2002/10/27 04:26:28  crm
% Added better handling of missing libraries
%
% Revision 1.5  2002/10/10 22:04:36  michelich
% minmax, trilinear, hcoords are now C functions.
%
% Revision 1.4  2002/10/09 20:44:25  crm
% Changed readxml.cpp to readxml.c
%
% Revision 1.3  2002/10/08 23:07:28  michelich
% Added deleteonclose.c
%
% Revision 1.2  2002/09/30 20:33:04  crm
% Changes for UNIX support.
%
% Revision 1.1  2002/09/30 17:59:16  michelich
% Initial version
%
