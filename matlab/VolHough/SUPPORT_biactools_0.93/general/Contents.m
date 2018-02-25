% BIAC General Toolbox
% Version 3.0 2004-02-12
%
% Duke-UNC Brain Imaging and Analysis Center General MATLAB Tools
%
% Colormaps.
%   bluneg      - Bright cyan fading to dark blue color map.
%   blupos      - Dark blue fading to bright cyan color map.
%   redneg      - Bright yellow fading to dark red color map.
%   redpos      - Dark red fading to bright yellow color map.
%   bluegrad    - Blue with increasing intensity color map.
%   greengrad   - Green with increasing intensity color map.
%   redgrad     - Red with increasing intensity color map.
%   cyangrad    - Cyan with increasing intensity color map.
%   magentagrad - Magenta with increasing intensity color map.
%   yellowgrad  - Yellow with increasing intensity color map.
%   emap        - Erik's color map of size 211.
%
% Experiment management.
%   findexp     - Find the experiment path for given experiment name.
%   chexp       - Change experiment (setup path & current directories).
%   pwe         - Present working experiment.
%   addscriptspath - Add scripts paths related to current experiment.
%   rmexppath   - Remove paths related to current experiment.
%   rmscriptspath - Remove scripts paths related to current experiment.
%
% Interpolation functions.
%   movavg      - Calculate symmetric moving average.
%   trilinear   - Trilinear interpolation of 3-D array.
%   scale3      - Scale 3-D array in X, Y, and Z.
%
% Data I/O functions.
%   mac2eeg     - Convert Mac .DAT files (from Margot) to EEG files.
%   pgm2pcx     - Convert PGM files to PCX files.
%   pgmread     - Read a PGM (portable graymap) file from disk.
%   dcmtkdic2matlabdic - Translate DCMTK DICOM Dictionary into 
%                        MATLAB DICOM Dictionary
% 
% File system functions.
%   fileroot    - Determine the root directory from a file name.
%   finddirs    - Recursively search for directories.
%   isrelpath   - Determine if the file name base on a relative path.
%   makedir     - Create a directory and any parents that don't exist.
%   unc2unix    - Convert Windows UNC filename/path to a UNIX filename/path
%
% XML functions
%   readxml     - XML reader, using libxml2.
%   writexml    - XML writer, using libxml2.
%   xpathquery  - Query an XML structure for a field using XPath
%
% URL Class and related functions
%   @url\eq     - == for urls
%   @url\get    - get properties of URL.
%   @url\toString - Convert URL to canonical string representation
%   @url\url    - an alternative to java.net.URL
%   filename2url - get valid URL from rel. or abs. filename or URI
%   fopenlocation - Return open file identifiers corresponding to given URI(s)
%   loadlocation  - Return local filename corresponding to given URI(s)
%
% Other functions.
%   alphasort   - Sort string array or cell array alphabetically using
%                 sortrows.
%   arefresh    - Refresh axes.
%   beep        - Ring the bell.
%   buildmex    - Build MEX files for this toolbox
%   cellfun2    - Extended cell array functions.
%   centroid    - Calculate centroid of array.
%   checkfiles  - Read list of files and make sure they exist.
%   cindex      - Return values of cell array at subscripts.
%   cmapmenu    - Add a color map menu to the current figure.
%   cmass       - Calculate center of mass of array.
%   errorbox    - Display error message in dialog box.
%   evalif      - Conditional eval.
%   facehilo    - Generate high & low pass filtered versions of PCX images
%   getparentfigure - Return the parent figures for the passed handles.
%   getstrs     - Read lines from text file and put into cell array.
%   guigets     - Display question and get answer from user.
%   guiline     - Display line, allow user to change attributes, and 
%                 pass to function.
%   guistrf     - Display question, get answer from user, and pass to 
%                 function.
%   hcoords     - Return homogeneous coordinate array from X, Y, and Z
%                 coordinates.
%   ifactor     - Return integer factors.
%   index       - Return values of matrix at subscripts.
%   isint       - True for integer elements.
%   listgui     - Choose an item from a list using a GUI
%   minmax      - Return min and max of noncomplex, nonsparse array
%                 of doubles.
%   normaliz    - Normalize data to specified range.
%   numlist     - Return delimited list of numbers.
%   overlay     - Overlay one image over another.
%   pnmgetc     - Get character from PBM/PGM/PPM file.
%   pnmgeti     - Get integer PBM/PGM/PPM file.
%   progbar     - Create/update progress bar.
%   readkvf     - Read keyword/value pair file.
%   remduprows  - Sort and remove duplicates from matrix.
%   remdups     - Sort and remove duplicates from vector.
%   scaled2rgb  - Convert scaled image to RGB image.
%   sigchg      - Calculate signal change of values in x.
%   spacejam    - Collapse consecutive spaces to one in string.
%   splitstr    - Split string into a cell array of string.
%   strlist     - Return delimited list of strings.
%   toexcel     - Export data variable to new Excel worksheet.
%   trim        - Remove leading and trailing blanks.
%

% Private functions:
% private\deleteonclose - Immediately marks a file for deletion when it is closed.
% private\deleteoncloseacq - Acquire a handle for marking a file "delete on close"
% private\deleteoncloserel - Release a handle used for marking a file "delete on close"
% private\grablocation  - Return file ids or local filenames corresponding to given URI(s)

% CVS ID and authorship of this code
% $Id: Contents.m,v 1.13 2004/08/19 20:15:55 michelich Exp $
